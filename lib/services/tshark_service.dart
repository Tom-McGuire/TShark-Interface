import 'dart:io';
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
  });

  final int pid;
  final String targetDirectory;
  final String targetFilePath;
  final String commandLine;
  final Process? process;
}

class TSharkService {
  TSharkService({this.customTSharkPath});

  final String? customTSharkPath;

  /// Attempts to locate the `tshark` executable on the host system.
  Future<String?> findTSharkPath() async {
    if (customTSharkPath != null && customTSharkPath!.isNotEmpty) {
      if (await File(customTSharkPath!).exists()) {
        return customTSharkPath;
      }
    }

    if (Platform.isWindows) {
      const candidates = [
        r'C:\Program Files\Wireshark\tshark.exe',
        r'C:\Program Files (x86)\Wireshark\tshark.exe',
      ];
      for (final path in candidates) {
        if (await File(path).exists()) {
          return path;
        }
      }

      // Check via where tshark
      try {
        final res = await Process.run('where', ['tshark']);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          final firstLine = res.stdout.toString().trim().split(RegExp(r'[\r\n]+')).first;
          if (await File(firstLine).exists()) {
            return firstLine;
          }
        }
      } catch (_) {}
    } else {
      const candidates = [
        '/usr/bin/tshark',
        '/usr/local/bin/tshark',
        '/opt/homebrew/bin/tshark',
      ];
      for (final path in candidates) {
        if (await File(path).exists()) {
          return path;
        }
      }

      try {
        final res = await Process.run('which', ['tshark']);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          final found = res.stdout.toString().trim().split(RegExp(r'[\r\n]+')).first;
          if (await File(found).exists()) {
            return found;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Queries tshark version string (e.g. "TShark (Wireshark) 4.2.4").
  Future<String?> getVersion(String tsharkPath) async {
    try {
      final res = await Process.run(tsharkPath, ['-v']);
      if (res.exitCode == 0) {
        final firstLine = res.stdout.toString().trim().split(RegExp(r'[\r\n]+')).first;
        return firstLine;
      }
    } catch (_) {}
    return null;
  }

  /// Queries system capture interfaces using `tshark -D`.
  Future<List<CaptureInterface>> getInterfaces(String tsharkPath) async {
    try {
      final res = await Process.run(tsharkPath, ['-D']);
      if (res.exitCode != 0) {
        return [];
      }

      final lines = res.stdout.toString().split(RegExp(r'[\r\n]+'));
      final interfaces = <CaptureInterface>[];

      // Format:
      // 1. \Device\NPF_{...} (Wi-Fi)
      // 2. eth0
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
    } catch (_) {
      return [];
    }
  }

  /// Builds command-line arguments for tshark based on the configuration.
  List<String> buildArguments(CaptureConfig config, String fullOutputPath) {
    final args = <String>[
      '-i',
      config.interface.index,
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
  String buildDisplayCommandLine({
    required String tsharkPath,
    required CaptureConfig config,
    required String fullOutputPath,
  }) {
    final args = buildArguments(config, fullOutputPath);
    final quotedArgs = args.map((arg) {
      if (arg.contains(' ') || arg.contains('\\') || arg.contains('"')) {
        return '"${arg.replaceAll('"', '\\"')}"';
      }
      return arg;
    }).toList();

    final exe = tsharkPath.contains(' ') ? '"$tsharkPath"' : tsharkPath;
    return '$exe ${quotedArgs.join(' ')}';
  }

  /// Starts the TShark capture process.
  Future<CaptureProcessResult> startCapture({
    required String tsharkPath,
    required CaptureConfig config,
    bool detached = false,
  }) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    var targetDir = config.outputDirectory;
    if (config.createSubfolder) {
      targetDir = p.join(targetDir, 'Capture_$timestamp');
    }

    final dir = Directory(targetDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final prefix = config.filePrefix.trim().isNotEmpty ? config.filePrefix.trim() : 'capture';
    final filename = '${prefix}_$timestamp.pcapng';
    final fullOutputPath = p.join(targetDir, filename);

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

    return CaptureProcessResult(
      pid: process.pid,
      targetDirectory: targetDir,
      targetFilePath: fullOutputPath,
      commandLine: cmdLine,
      process: detached ? null : process,
    );
  }

  /// Checks if a process with the given PID is currently active and belongs to tshark/dumpcap.
  Future<bool> isProcessAlive(int pid) async {
    try {
      if (Platform.isWindows) {
        final res = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH']);
        if (res.exitCode == 0) {
          final out = res.stdout.toString().toLowerCase();
          return out.contains(pid.toString()) && (out.contains('tshark') || out.contains('dumpcap'));
        }
        return false;
      } else {
        final res = await Process.run('kill', ['-0', pid.toString()]);
        return res.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
  }

  /// Terminates a running capture process cleanly, ensuring all child processes (dumpcap) stop.
  Future<bool> stopCapture(int pid) async {
    try {
      if (Platform.isWindows) {
        // Using taskkill /PID ... /T /F ensures dumpcap is also stopped.
        final res = await Process.run('taskkill', ['/PID', pid.toString(), '/T', '/F']);
        return res.exitCode == 0;
      } else {
        final res = await Process.run('kill', ['-15', pid.toString()]);
        return res.exitCode == 0;
      }
    } catch (_) {
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
          if (entity is File && entity.path.endsWith('.pcapng')) {
            total += await entity.length();
          }
        }
        return total;
      }
    } catch (_) {}
    return 0;
  }
}
