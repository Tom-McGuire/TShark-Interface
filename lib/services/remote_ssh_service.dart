import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/active_capture_session.dart';
import '../models/capture_config.dart';
import '../models/capture_interface.dart';
import '../models/remote_host.dart';
import 'tshark_service.dart';

class RemoteExecResult {
  const RemoteExecResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class RemoteConnectionTestResult {
  const RemoteConnectionTestResult({
    required this.success,
    required this.detectedOs,
    this.tsharkVersion,
    this.tsharkPath,
    this.interfaces = const [],
    this.errorMessage,
  });

  final bool success;
  final RemoteOsType detectedOs;
  final String? tsharkVersion;
  final String? tsharkPath;
  final List<CaptureInterface> interfaces;
  final String? errorMessage;
}

class RemoteSessionCheckResult {
  const RemoteSessionCheckResult({
    required this.isReachable,
    required this.isAlive,
    required this.sizeBytes,
    this.errorMessage,
  });

  final bool isReachable;
  final bool isAlive;
  final int sizeBytes;
  final String? errorMessage;
}

class RemoteSshService {
  RemoteSshService({TSharkService? tsharkService})
      : _tsharkService = tsharkService ?? TSharkService();

  final TSharkService _tsharkService;

  /// Escapes a single argument for POSIX shells (bash/sh) using single quotes.
  static String escapePosixArg(String arg) {
    return "'${arg.replaceAll("'", r"'\''")}'";
  }

  /// Escapes a single argument for PowerShell single-quoted strings.
  static String escapePowerShellArg(String arg) {
    return "'${arg.replaceAll("'", "''")}'";
  }

  /// Joins remote path segments using `/` for Linux or `\` for Windows.
  static String joinRemotePath(RemoteOsType os, String dir, String child) {
    final sep = os == RemoteOsType.windows ? r'\' : '/';
    final cleanDir = dir.endsWith('/') || dir.endsWith(r'\')
        ? dir.substring(0, dir.length - 1)
        : dir;
    return '$cleanDir$sep$child';
  }

  /// Builds the detached background start command for a Linux/Unix remote host.
  static String buildLinuxStartCommand({
    required String tsharkBin,
    required List<String> args,
    required String targetDir,
    required bool useSudo,
  }) {
    final escapedDir = escapePosixArg(targetDir);
    final errLog = escapePosixArg('$targetDir/tshark_stderr.log');
    final sudoPrefix = useSudo ? 'sudo -n ' : '';
    final escapedBin = escapePosixArg(tsharkBin);
    final escapedArgs = args.map(escapePosixArg).join(' ');

    return 'mkdir -p $escapedDir && '
        'nohup $sudoPrefix$escapedBin $escapedArgs > $errLog 2>&1 < /dev/null & '
        'PID=\$!; sleep 0.4; '
        'if ps -p \$PID > /dev/null 2>&1; then echo "PID:\$PID"; '
        'else echo "ERR:\$(cat $errLog 2>/dev/null)"; exit 1; fi';
  }

  /// Builds the detached background start command for a Windows OpenSSH remote host.
  static String buildWindowsStartCommand({
    required String tsharkBin,
    required List<String> args,
    required String targetDir,
  }) {
    final psDir = escapePowerShellArg(targetDir);
    final psBin = escapePowerShellArg(tsharkBin);
    final psArgsList = args.map(escapePowerShellArg).join(', ');

    final psScript = "\$ErrorActionPreference='Stop'; "
        "New-Item -ItemType Directory -Force -Path $psDir | Out-Null; "
        "\$p = Start-Process -FilePath $psBin -ArgumentList @($psArgsList) -WindowStyle Hidden -PassThru; "
        "Start-Sleep -Milliseconds 300; "
        "if (\$p.HasExited) { Write-Output 'ERR:Process exited immediately (code ' + \$p.ExitCode + ')'; exit 1 } "
        "else { Write-Output ('PID:' + \$p.Id) }";

    final escapedScript = psScript.replaceAll('"', r'\"');
    return 'powershell -NoProfile -NonInteractive -Command "$escapedScript"';
  }

  /// Builds a human-readable SSH CLI command preview for the UI studio.
  String buildRemoteDisplayCommandLine({
    required RemoteHost host,
    required CaptureConfig config,
    required String fullRemoteOutputPath,
  }) {
    final tsharkBin = (host.customTSharkPath != null && host.customTSharkPath!.trim().isNotEmpty)
        ? host.customTSharkPath!.trim()
        : (host.osType == RemoteOsType.windows
            ? r'C:\Program Files\Wireshark\tshark.exe'
            : 'tshark');
    final sudoPrefix = (host.osType != RemoteOsType.windows && host.useSudo) ? 'sudo ' : '';
    final args = _tsharkService.buildArguments(config, fullRemoteOutputPath);
    final formattedArgs = args.map((a) {
      if (a.contains(' ') || a.contains('(') || a.contains(')') || a.contains(r'\')) {
        return "'$a'";
      }
      return a;
    }).join(' ');

    final portFlag = host.port != 22 ? '-p ${host.port} ' : '';
    return 'ssh $portFlag${host.username}@${host.host} "$sudoPrefix$tsharkBin $formattedArgs"';
  }

  Future<SSHClient> _connect(
    RemoteHost host, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final socket = await SSHSocket.connect(
      host.host,
      host.port,
      timeout: timeout,
    );
    final client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: () => host.password,
    );
    await client.authenticated.timeout(timeout);
    return client;
  }

  Future<RemoteExecResult> _exec(
    SSHClient client,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final session = await client.execute(command).timeout(timeout);
    final stdoutBytes = await session.stdout
        .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk))
        .timeout(timeout);
    final stderrBytes = await session.stderr
        .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk))
        .timeout(timeout);
    await session.done.timeout(timeout);

    return RemoteExecResult(
      exitCode: session.exitCode ?? 0,
      stdout: utf8.decode(stdoutBytes, allowMalformed: true).trim(),
      stderr: utf8.decode(stderrBytes, allowMalformed: true).trim(),
    );
  }

  /// Auto-detects whether the remote host is running Linux/Unix or Windows.
  Future<RemoteOsType> _detectOs(SSHClient client, RemoteHost host) async {
    if (host.osType != RemoteOsType.auto) {
      return host.osType;
    }
    try {
      final res = await _exec(client, 'uname -s');
      final out = res.stdout.toLowerCase();
      if (res.exitCode == 0 &&
          (out.contains('linux') ||
              out.contains('darwin') ||
              out.contains('bsd') ||
              out.contains('unix'))) {
        return RemoteOsType.linux;
      }
    } catch (_) {}
    return RemoteOsType.windows;
  }

  /// Resolves the `tshark` binary path on the remote host.
  Future<String> _resolveTSharkBin(
    SSHClient client,
    RemoteHost host,
    RemoteOsType os,
  ) async {
    if (host.customTSharkPath != null && host.customTSharkPath!.trim().isNotEmpty) {
      return host.customTSharkPath!.trim();
    }

    if (os == RemoteOsType.linux) {
      final res = await _exec(
        client,
        'which tshark 2>/dev/null || command -v tshark 2>/dev/null || echo /usr/bin/tshark',
      );
      final line = res.stdout.split(RegExp(r'[\r\n]+')).first.trim();
      return line.isNotEmpty ? line : '/usr/bin/tshark';
    } else {
      final res = await _exec(
        client,
        r'powershell -NoProfile -NonInteractive -Command "if (Test-Path \"C:\Program Files\Wireshark\tshark.exe\") { Write-Output \"C:\Program Files\Wireshark\tshark.exe\" } else { (Get-Command tshark -ErrorAction SilentlyContinue).Source }"',
      );
      final line = res.stdout.split(RegExp(r'[\r\n]+')).first.trim();
      return line.isNotEmpty ? line : r'C:\Program Files\Wireshark\tshark.exe';
    }
  }

  /// Tests SSH connection, detects OS, locates TShark, and lists capture interfaces.
  Future<RemoteConnectionTestResult> testConnection(RemoteHost host) async {
    SSHClient? client;
    try {
      client = await _connect(host);
      final os = await _detectOs(client, host);
      final tsharkBin = await _resolveTSharkBin(client, host, os);

      // Query version
      final verCmd = os == RemoteOsType.linux
          ? '${escapePosixArg(tsharkBin)} -v'
          : '"$tsharkBin" -v';
      final verRes = await _exec(client, verCmd);
      if (verRes.exitCode != 0) {
        return RemoteConnectionTestResult(
          success: false,
          detectedOs: os,
          tsharkPath: tsharkBin,
          errorMessage:
              'Connected via SSH, but TShark was not found at "$tsharkBin": ${verRes.stderr.isNotEmpty ? verRes.stderr : verRes.stdout}',
        );
      }
      final versionLine = verRes.stdout.split(RegExp(r'[\r\n]+')).first.trim();

      // Query interfaces
      final sudoPrefix = (os == RemoteOsType.linux && host.useSudo) ? 'sudo -n ' : '';
      final ifaceCmd = os == RemoteOsType.linux
          ? '$sudoPrefix${escapePosixArg(tsharkBin)} -D'
          : '"$tsharkBin" -D';
      final ifaceRes = await _exec(client, ifaceCmd);
      final interfaces = TSharkService.parseInterfacesOutput(ifaceRes.stdout);

      if (interfaces.isEmpty && ifaceRes.stderr.isNotEmpty) {
        return RemoteConnectionTestResult(
          success: false,
          detectedOs: os,
          tsharkVersion: versionLine,
          tsharkPath: tsharkBin,
          errorMessage:
              'TShark found ($versionLine), but no interfaces could be listed: ${ifaceRes.stderr}',
        );
      }

      return RemoteConnectionTestResult(
        success: true,
        detectedOs: os,
        tsharkVersion: versionLine,
        tsharkPath: tsharkBin,
        interfaces: interfaces,
      );
    } catch (e) {
      debugPrint('Remote testConnection error (${host.host}): $e');
      return RemoteConnectionTestResult(
        success: false,
        detectedOs: host.osType == RemoteOsType.auto ? RemoteOsType.linux : host.osType,
        errorMessage: 'SSH connection failed: $e',
      );
    } finally {
      client?.close();
    }
  }

  /// Queries network interfaces on a remote machine using `tshark -D`.
  Future<List<CaptureInterface>> getRemoteInterfaces(RemoteHost host) async {
    SSHClient? client;
    try {
      client = await _connect(host);
      final os = await _detectOs(client, host);
      final tsharkBin = await _resolveTSharkBin(client, host, os);
      final sudoPrefix = (os == RemoteOsType.linux && host.useSudo) ? 'sudo -n ' : '';

      final cmd = os == RemoteOsType.linux
          ? '$sudoPrefix${escapePosixArg(tsharkBin)} -D'
          : '"$tsharkBin" -D';
      final res = await _exec(client, cmd);
      if (res.exitCode != 0 && res.stdout.isEmpty) {
        throw Exception(res.stderr.isNotEmpty ? res.stderr : 'tshark -D exited with ${res.exitCode}');
      }
      return TSharkService.parseInterfacesOutput(res.stdout);
    } finally {
      client?.close();
    }
  }

  /// Starts a detached TShark capture on the remote machine and returns the remote PID & paths.
  Future<CaptureProcessResult> startRemoteCapture({
    required RemoteHost host,
    required CaptureConfig config,
  }) async {
    SSHClient? client;
    try {
      client = await _connect(host);
      final os = await _detectOs(client, host);
      final tsharkBin = await _resolveTSharkBin(client, host, os);

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      var targetDir = config.outputDirectory.trim().isNotEmpty
          ? config.outputDirectory.trim()
          : host.defaultOutputDirectory.trim();
      if (targetDir.isEmpty) {
        targetDir = os == RemoteOsType.windows
            ? r'C:\Temp\TSharkCaptures'
            : '/tmp/tshark_captures';
      }

      if (config.createSubfolder || config.mode == CaptureMode.ringBuffer) {
        targetDir = joinRemotePath(os, targetDir, 'Capture_$timestamp');
      }

      final sanitizedPrefix = TSharkService.sanitizeFilePrefix(config.filePrefix);
      final filename = '${sanitizedPrefix}_$timestamp.pcapng';
      final fullRemoteOutputPath = joinRemotePath(os, targetDir, filename);

      final args = _tsharkService.buildArguments(config, fullRemoteOutputPath);
      final startCmd = os == RemoteOsType.linux
          ? buildLinuxStartCommand(
              tsharkBin: tsharkBin,
              args: args,
              targetDir: targetDir,
              useSudo: host.useSudo,
            )
          : buildWindowsStartCommand(
              tsharkBin: tsharkBin,
              args: args,
              targetDir: targetDir,
            );

      final res = await _exec(client, startCmd, timeout: const Duration(seconds: 12));
      final out = res.stdout;

      if (out.contains('PID:')) {
        final pidMatch = RegExp(r'PID:(\d+)').firstMatch(out);
        if (pidMatch != null) {
          final pid = int.parse(pidMatch.group(1)!);
          final displayCmd = buildRemoteDisplayCommandLine(
            host: host.copyWith(osType: os),
            config: config,
            fullRemoteOutputPath: fullRemoteOutputPath,
          );
          return CaptureProcessResult(
            pid: pid,
            targetDirectory: targetDir,
            targetFilePath: fullRemoteOutputPath,
            commandLine: displayCmd,
          );
        }
      }

      final errDetail = out.contains('ERR:')
          ? out.split('ERR:').last.trim()
          : (res.stderr.isNotEmpty ? res.stderr : out);
      throw Exception(
        errDetail.isNotEmpty ? errDetail : 'Remote TShark process failed to start.',
      );
    } finally {
      client?.close();
    }
  }

  /// Checks if a remote capture session is still running and queries its current capture file size.
  Future<RemoteSessionCheckResult> checkRemoteSessionStatus(
    RemoteHost host,
    ActiveCaptureSession session,
  ) async {
    SSHClient? client;
    try {
      client = await _connect(host, timeout: const Duration(seconds: 5));
      final os = await _detectOs(client, host);
      final pid = session.pid;
      final pathToMeasure = session.mode == CaptureMode.ringBuffer
          ? session.outputDirectory
          : session.targetFilePath;

      if (os == RemoteOsType.linux) {
        final escapedPath = escapePosixArg(pathToMeasure);
        final escapedDir = escapePosixArg(session.outputDirectory);
        final cmd = '(ps -p $pid -o comm= 2>/dev/null || true); '
            'echo "---SPLIT---"; '
            '(if [ -f $escapedPath ]; then stat -c %s $escapedPath 2>/dev/null; '
            'elif [ -d $escapedDir ]; then du -sb $escapedDir 2>/dev/null | cut -f1; '
            'else echo 0; fi)';
        final res = await _exec(client, cmd, timeout: const Duration(seconds: 6));
        final parts = res.stdout.split('---SPLIT---');
        final comm = parts.isNotEmpty ? parts[0].trim().toLowerCase() : '';
        final sizeStr = parts.length > 1 ? parts[1].trim().split(RegExp(r'\s+')).first : '0';

        final isAlive = comm.contains('tshark') || comm.contains('dumpcap') || comm.contains('sudo');
        final sizeBytes = int.tryParse(sizeStr) ?? session.lastKnownSizeBytes;
        return RemoteSessionCheckResult(
          isReachable: true,
          isAlive: isAlive,
          sizeBytes: sizeBytes,
        );
      } else {
        final psDir = escapePowerShellArg(session.outputDirectory);
        final psScript = "\$p = Get-Process -Id $pid -ErrorAction SilentlyContinue; "
            "if (\$p) { Write-Output \$p.ProcessName }; "
            "Write-Output '---SPLIT---'; "
            "if (Test-Path $psDir) { "
            "\$s = (Get-ChildItem $psDir -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; "
            "if (\$s) { Write-Output \$s } else { Write-Output 0 } "
            "} else { Write-Output 0 }";
        final escapedScript = psScript.replaceAll('"', r'\"');
        final res = await _exec(
          client,
          'powershell -NoProfile -NonInteractive -Command "$escapedScript"',
          timeout: const Duration(seconds: 8),
        );
        final parts = res.stdout.split('---SPLIT---');
        final procName = parts.isNotEmpty ? parts[0].trim().toLowerCase() : '';
        final sizeStr = parts.length > 1 ? parts[1].trim().split(RegExp(r'\s+')).first : '0';

        final isAlive = procName.contains('tshark') || procName.contains('dumpcap');
        final sizeBytes = int.tryParse(sizeStr) ?? session.lastKnownSizeBytes;
        return RemoteSessionCheckResult(
          isReachable: true,
          isAlive: isAlive,
          sizeBytes: sizeBytes,
        );
      }
    } catch (e) {
      debugPrint('checkRemoteSessionStatus error (${host.host}): $e');
      return RemoteSessionCheckResult(
        isReachable: false,
        isAlive: false,
        sizeBytes: session.lastKnownSizeBytes,
        errorMessage: e.toString(),
      );
    } finally {
      client?.close();
    }
  }

  /// Stops a running remote TShark capture cleanly.
  Future<bool> stopRemoteCapture(RemoteHost host, int pid) async {
    SSHClient? client;
    try {
      client = await _connect(host);
      final os = await _detectOs(client, host);

      if (os == RemoteOsType.linux) {
        final sudoPrefix = host.useSudo ? 'sudo -n ' : '';
        // Send SIGINT (-2) first so dumpcap flushes its packet buffer and closes PCAPNG cleanly
        await _exec(
          client,
          '${sudoPrefix}kill -2 $pid 2>/dev/null || ${sudoPrefix}kill -15 $pid 2>/dev/null || true',
        );
        await Future.delayed(const Duration(milliseconds: 1200));

        // Verify if still running; if so, force kill
        final check = await _exec(client, 'ps -p $pid -o comm= 2>/dev/null || true');
        if (check.stdout.trim().isNotEmpty) {
          await _exec(client, '${sudoPrefix}kill -9 $pid 2>/dev/null || true');
        }
        return true;
      } else {
        await _exec(client, 'taskkill /PID $pid /T');
        await Future.delayed(const Duration(milliseconds: 1200));
        await _exec(client, 'taskkill /PID $pid /T /F');
        return true;
      }
    } catch (e) {
      debugPrint('stopRemoteCapture error (${host.host}): $e');
      return false;
    } finally {
      client?.close();
    }
  }
}
