import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_suite_shared/network_suite_shared.dart'
    show
        CaptureBinaryLocator,
        CapturePermissionResult,
        CaptureTool;
import 'package:path/path.dart' as p;
import '../models/capture_config.dart';
import '../models/capture_interface.dart';

class CaptureProcessResult {
  const CaptureProcessResult({
    required this.pid,
    required this.targetDirectory,
    required this.targetFilePath,
    required this.commandLine,
    this.process,
    this.recentStderr = const [],
  });

  final int pid;
  final String targetDirectory;
  final String targetFilePath;
  final String commandLine;
  final Process? process;
  final List<String> recentStderr;
}

class TSharkService {
  TSharkService({
    this.customTSharkPath,
    CaptureBinaryLocator? binaryLocator,
  }) : _binaryLocator = binaryLocator ?? CaptureBinaryLocator();

  final String? customTSharkPath;
  final CaptureBinaryLocator _binaryLocator;
  List<String> _recentStderr = [];
  List<String> get recentStderr => List.unmodifiable(_recentStderr);

  /// Validates whether a given executable path is a genuine tshark binary.
  static bool isValidTSharkExecutable(String filePath) {
    if (filePath.isEmpty) return false;
    final file = File(filePath);
    if (!file.existsSync()) return false;
    return CaptureBinaryLocator.isExpectedExecutableName(
      filePath,
      CaptureTool.tshark,
    );
  }

  /// Returns `true` if [stderr] indicates an OS packet-capture permission failure.
  static bool isPermissionError(String stderr) =>
      CaptureBinaryLocator.isPermissionError(stderr);

  /// Sanitizes file prefixes to prevent path traversal, directory escape, and NTFS stream creation.
  static String sanitizeFilePrefix(String rawPrefix) {
    // Only allow alphanumeric characters, underscores, and hyphens
    var clean = rawPrefix.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    clean = clean.replaceAll(RegExp(r'[_\-]+'), '_');
    clean = clean.replaceAll(RegExp(r'^_+|_+$'), '');
    if (clean.isEmpty) {
      return 'capture';
    }
    return clean;
  }

  /// Attempts to locate the `tshark` executable on the host system via [CaptureBinaryLocator].
  Future<String?> findTSharkPath() {
    return _binaryLocator.findBinaryPath(
      CaptureTool.tshark,
      customPath: customTSharkPath,
    );
  }

  /// Attempts to locate the `dumpcap` executable on the host system via [CaptureBinaryLocator].
  Future<String?> findDumpcapPath({String? customPath}) {
    return _binaryLocator.findBinaryPath(
      CaptureTool.dumpcap,
      customPath: customPath,
    );
  }

  /// Checks OS packet capture privileges (`setcap` / `wireshark` group on Linux,
  /// Npcap on Windows, ChmodBPF on macOS) via [CaptureBinaryLocator].
  Future<CapturePermissionResult> checkCapturePermissions({
    String? binaryPath,
  }) {
    return _binaryLocator.checkCapturePermissions(
      CaptureTool.tshark,
      binaryPath: binaryPath,
      customPath: customTSharkPath,
    );
  }

  /// Queries tshark version string (e.g. "TShark (Wireshark) 4.2.4") via [CaptureBinaryLocator].
  Future<String?> getVersion(String tsharkPath) {
    return _binaryLocator.getVersion(CaptureTool.tshark, tsharkPath);
  }

  /// Parses raw `tshark -D` output into a list of [CaptureInterface] objects.
  static List<CaptureInterface> parseInterfacesOutput(String rawOutput) {
    final lines = rawOutput.split(RegExp(r'[\r\n]+'));
    final interfaces = <CaptureInterface>[];

    // Format:
    // 1. \Device\NPF_{...} (Wi-Fi)
    // 2. eth0
    // 3. any (Pseudo-device that captures on all interfaces) [Linux]
    final lineRegex = RegExp(r'^(\d+)\.\s+(.*?)(?:\s+\((.*?)\))?$');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = lineRegex.firstMatch(line);
      if (match != null) {
        final index = match.group(1)!;
        final name = match.group(2)!.trim();
        final friendly = match.group(3)?.trim();
        interfaces.add(
          CaptureInterface(
            index: index,
            name: name,
            friendlyName: (friendly != null && friendly.isNotEmpty) ? friendly : null,
          ),
        );
      }
    }

    return interfaces;
  }

  /// Discovers local host IPv4 addresses keyed by interface name (and lowercase name).
  static Future<Map<String, List<String>>> getHostIpv4Map() async {
    try {
      final osInterfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );
      final grouped = <String, Set<String>>{};
      for (final osIface in osInterfaces) {
        final ips = osIface.addresses
            .where((a) => a.type == InternetAddressType.IPv4 && a.address.isNotEmpty)
            .map((a) => a.address);
        if (ips.isEmpty) continue;
        grouped.putIfAbsent(osIface.name, () => <String>{}).addAll(ips);
        final lower = osIface.name.toLowerCase();
        grouped.putIfAbsent(lower, () => <String>{}).addAll(ips);
      }
      return {
        for (final entry in grouped.entries)
          entry.key: List.unmodifiable(entry.value),
      };
    } catch (e) {
      debugPrint('getHostIpv4Map error: $e');
      return {};
    }
  }

  /// Instance wrapper around [getHostIpv4Map] to support test overrides.
  Future<Map<String, List<String>>> fetchHostIpv4Map() => getHostIpv4Map();

  static String _normalizeInterfaceKey(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  /// Enriches parsed [CaptureInterface] objects with matching OS IPv4 addresses.
  static List<CaptureInterface> enrichInterfacesWithIpv4(
    List<CaptureInterface> interfaces,
    Map<String, List<String>> osInterfaceIps,
  ) {
    if (interfaces.isEmpty || osInterfaceIps.isEmpty) {
      return interfaces;
    }

    final exactLowerMap = <String, Set<String>>{};
    final normalizedMap = <String, Set<String>>{};
    for (final entry in osInterfaceIps.entries) {
      final ips = entry.value.map((e) => e.trim()).where((e) => e.isNotEmpty);
      if (ips.isEmpty) continue;

      final exactKey = entry.key.trim().toLowerCase();
      if (exactKey.isNotEmpty) {
        exactLowerMap.putIfAbsent(exactKey, () => <String>{}).addAll(ips);
      }

      final normKey = _normalizeInterfaceKey(entry.key);
      if (normKey.isNotEmpty) {
        normalizedMap.putIfAbsent(normKey, () => <String>{}).addAll(ips);
      }
    }

    return interfaces.map((iface) {
      final candidates = <String>[
        iface.name,
        if (iface.friendlyName != null && iface.friendlyName!.isNotEmpty)
          iface.friendlyName!,
      ];

      final matchedIps = <String>{...iface.ipv4Addresses};

      var foundExact = false;
      for (final candidate in candidates) {
        final key = candidate.trim().toLowerCase();
        final ips = exactLowerMap[key];
        if (ips != null && ips.isNotEmpty) {
          matchedIps.addAll(ips);
          foundExact = true;
        }
      }

      if (!foundExact) {
        for (final candidate in candidates) {
          final normKey = _normalizeInterfaceKey(candidate);
          final ips = normalizedMap[normKey];
          if (ips != null && ips.isNotEmpty) {
            matchedIps.addAll(ips);
          }
        }
      }

      if (matchedIps.isEmpty) {
        return iface;
      }
      return iface.copyWith(ipv4Addresses: List.unmodifiable(matchedIps));
    }).toList();
  }

  /// Queries system capture interfaces using `tshark -D`.
  Future<List<CaptureInterface>> getInterfaces(String tsharkPath) async {
    try {
      if (!isValidTSharkExecutable(tsharkPath)) return [];
      final res = await Process.run(tsharkPath, ['-D']);
      if (res.exitCode != 0) {
        return [];
      }

      final parsed = parseInterfacesOutput(res.stdout.toString());
      if (parsed.isEmpty) return parsed;
      final ipv4Map = await fetchHostIpv4Map();
      return enrichInterfacesWithIpv4(parsed, ipv4Map);
    } catch (e) {
      debugPrint('getInterfaces error: $e');
      return [];
    }
  }

  /// Builds command-line arguments for tshark based on the configuration.
  /// Uses stable interface device name (e.g. `\Device\NPF_{GUID}`) instead of volatile index numbers.
  List<String> buildArguments(CaptureConfig config, String fullOutputPath) {
    // Prefer stable device name if available, fallback to index
    final ifaceTarget = config.interface.name.isNotEmpty
        ? config.interface.name
        : config.interface.index;

    final args = <String>[
      '-i',
      ifaceTarget,
      '-q', // Quiet mode to avoid filling OS pipe buffers with packet counters
    ];

    if (!config.promiscuous) {
      args.add('-p');
    }

    if (config.snaplen > 0) {
      args.addAll(['-s', config.snaplen.toString()]);
    }

    if (config.captureFilter.trim().isNotEmpty) {
      args.addAll(['-f', config.captureFilter.trim()]);
    }

    switch (config.mode) {
      case CaptureMode.manual:
        args.addAll(['-w', fullOutputPath]);
        break;

      case CaptureMode.timed:
        final seconds = config.totalTimedSeconds > 0 ? config.totalTimedSeconds : 600;
        args.addAll([
          '-a',
          'duration:$seconds',
          '-w',
          fullOutputPath,
        ]);
        break;

      case CaptureMode.packetCount:
        final limit = config.packetCountLimit > 0 ? config.packetCountLimit : 10000;
        args.addAll([
          '-c',
          limit.toString(),
          '-w',
          fullOutputPath,
        ]);
        break;

      case CaptureMode.ringBuffer:
        if (config.ringRotateBySize) {
          final kb = (config.ringRotateFilesizeMb > 0 ? config.ringRotateFilesizeMb : 100) * 1024;
          args.addAll(['-b', 'filesize:$kb']);
        } else {
          final seconds = (config.ringRotateMinutes > 0 ? config.ringRotateMinutes : 10) * 60;
          args.addAll(['-b', 'duration:$seconds']);
        }
        final files = config.ringFilesCount > 1 ? config.ringFilesCount : 5;
        args.addAll([
          '-b',
          'files:$files',
          '-w',
          fullOutputPath,
        ]);
        break;
    }

    return args;
  }

  /// Generates a readable CLI command string for displaying and copying.
  /// When [forPowerShell] is true on Windows, prepends `& ` for quoted paths.
  String buildDisplayCommandLine({
    required String tsharkPath,
    required CaptureConfig config,
    required String fullOutputPath,
    bool forPowerShell = false,
  }) {
    final args = buildArguments(config, fullOutputPath);
    final shellMetaRegex = RegExp(r'[\s\\"&|;()<>`$]');
    final quotedArgs = <String>[];
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final isFilterOrOutput =
          i > 0 && (args[i - 1] == '-f' || args[i - 1] == '-w');
      if (isFilterOrOutput || shellMetaRegex.hasMatch(arg)) {
        quotedArgs.add('"${arg.replaceAll('"', r'\"')}"');
      } else {
        quotedArgs.add(arg);
      }
    }

    final exeNeedsQuotes = tsharkPath.contains(' ');
    final exe = exeNeedsQuotes ? '"$tsharkPath"' : tsharkPath;
    final prefix = (Platform.isWindows && forPowerShell && exeNeedsQuotes) ? '& ' : '';
    return '$prefix$exe ${quotedArgs.join(' ')}';
  }

  /// Starts the TShark capture process with pipe draining, quiet mode, and path traversal guards.
  Future<CaptureProcessResult> startCapture({
    required String tsharkPath,
    required CaptureConfig config,
    bool detached = false,
    void Function(int exitCode)? onProcessExit,
  }) async {
    if (!isValidTSharkExecutable(tsharkPath)) {
      throw ArgumentError('Invalid or missing tshark executable: $tsharkPath');
    }

    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    var targetDir = p.canonicalize(config.outputDirectory);
    // Ring buffers and subfolder options isolate files into dedicated timestamped directories
    if (config.createSubfolder || config.mode == CaptureMode.ringBuffer) {
      targetDir = p.join(targetDir, 'Capture_$timestamp');
    }

    final dir = Directory(targetDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final sanitizedPrefix = sanitizeFilePrefix(config.filePrefix);
    final filename = '${sanitizedPrefix}_$timestamp.pcapng';
    final fullOutputPath = p.canonicalize(p.join(targetDir, filename));

    // Security check S1: verify path has not escaped targetDir
    if (!p.isWithin(targetDir, fullOutputPath)) {
      throw SecurityException('Target capture path is outside the designated capture folder');
    }

    final args = buildArguments(config, fullOutputPath);
    final cmdLine = buildDisplayCommandLine(
      tsharkPath: tsharkPath,
      config: config,
      fullOutputPath: fullOutputPath,
    );

    final mode = detached ? ProcessStartMode.detached : ProcessStartMode.normal;
    final process = await Process.start(
      tsharkPath,
      args,
      mode: mode,
    );

    final stderrBuffer = <String>[];
    _recentStderr = stderrBuffer;

    if (!detached) {
      // Drain stdout to prevent pipe buffer stalls
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((_) {}, onError: (_) {});

      // Drain and buffer stderr to surface errors on failure
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isNotEmpty) {
          stderrBuffer.add(line.trim());
          if (stderrBuffer.length > 20) {
            stderrBuffer.removeAt(0);
          }
        }
      }, onError: (_) {});

      // Attach direct exit code notification
      if (onProcessExit != null) {
        process.exitCode.then((code) {
          onProcessExit(code);
        });
      }
    }

    return CaptureProcessResult(
      pid: process.pid,
      targetDirectory: targetDir,
      targetFilePath: fullOutputPath,
      commandLine: cmdLine,
      process: detached ? null : process,
      recentStderr: stderrBuffer,
    );
  }

  /// Checks if a process with the given PID is currently active and belongs strictly to tshark or dumpcap.
  Future<bool> isProcessAlive(int pid) async {
    try {
      if (Platform.isWindows) {
        final res = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH']);
        if (res.exitCode == 0) {
          final lines = res.stdout.toString().trim().split(RegExp(r'[\r\n]+'));
          for (final line in lines) {
            if (line.isEmpty) continue;
            // Parse CSV format: "Image Name","PID","Session Name","Session#","Mem Usage"
            final parts = line.split('","').map((s) => s.replaceAll('"', '').trim()).toList();
            if (parts.length >= 2) {
              final imgName = parts[0].toLowerCase();
              final linePid = parts[1];
              if (linePid == pid.toString() &&
                  (imgName == 'tshark.exe' || imgName == 'dumpcap.exe')) {
                return true;
              }
            }
          }
        }
        return false;
      } else {
        // Unix: verify /proc/$pid/comm or ps comm
        final res = await Process.run('ps', ['-p', pid.toString(), '-o', 'comm=']);
        if (res.exitCode == 0) {
          final comm = res.stdout.toString().trim().toLowerCase();
          return comm.contains('tshark') || comm.contains('dumpcap');
        }
        return false;
      }
    } catch (e) {
      debugPrint('isProcessAlive error: $e');
      return false;
    }
  }

  Future<bool> _waitForExit(int pid, int attempts) async {
    for (var i = 0; i < attempts; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!await isProcessAlive(pid)) {
        return true;
      }
    }
    return false;
  }

  /// Terminates a running capture cleanly, attempting graceful shutdown first, then force-kill.
  Future<bool> stopCapture(int pid) async {
    try {
      if (Platform.isWindows) {
        // 1. Attempt graceful shutdown first (without /F)
        await Process.run('taskkill', ['/PID', pid.toString(), '/T']);

        // 2. Wait up to 1.5 seconds for buffers to flush
        if (await _waitForExit(pid, 3)) {
          return true;
        }

        // 3. Fallback to force-kill if still active
        final forceRes = await Process.run('taskkill', ['/PID', pid.toString(), '/T', '/F']);
        return forceRes.exitCode == 0;
      } else {
        // 1. Send SIGINT first so dumpcap flushes its packet buffer and closes PCAPNG cleanly
        await Process.run('kill', ['-2', pid.toString()]);
        if (await _waitForExit(pid, 3)) {
          return true;
        }

        // 2. Fallback to SIGTERM
        await Process.run('kill', ['-15', pid.toString()]);
        if (await _waitForExit(pid, 2)) {
          return true;
        }

        // 3. Fallback to SIGKILL
        final killRes = await Process.run('kill', ['-9', pid.toString()]);
        return killRes.exitCode == 0;
      }
    } catch (e) {
      debugPrint('stopCapture error: $e');
      try {
        return Process.killPid(pid);
      } catch (_) {
        return false;
      }
    }
  }

  /// Gets current size of target capture file or directory in bytes.
  Future<int> getCaptureSizeBytes(String filePathOrDir) async {
    try {
      final file = File(filePathOrDir);
      if (await file.exists()) {
        return await file.length();
      }
      final dir = Directory(filePathOrDir);
      if (await dir.exists()) {
        var total = 0;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (ext == '.pcap' || ext == '.pcapng' || ext == '.cap') {
              total += await entity.length();
            }
          }
        }
        return total;
      }
    } catch (e) {
      debugPrint('getCaptureSizeBytes error: $e');
    }
    return 0;
  }

  /// Finds the latest modified pcap file in a directory (crucial for ring buffer captures).
  Future<String?> findLatestPcapFile(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return null;

      File? latestFile;
      DateTime? latestModified;

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.pcap' || ext == '.pcapng' || ext == '.cap') {
            final modified = await entity.lastModified();
            if (latestModified == null || modified.isAfter(latestModified)) {
              latestModified = modified;
              latestFile = entity;
            }
          }
        }
      }

      return latestFile?.path;
    } catch (e) {
      debugPrint('findLatestPcapFile error: $e');
      return null;
    }
  }
}

class SecurityException implements Exception {
  SecurityException(this.message);
  final String message;
  @override
  String toString() => 'SecurityException: $message';
}
