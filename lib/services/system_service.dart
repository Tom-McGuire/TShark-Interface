import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class SystemService {
  static const List<String> allowedPcapExtensions = ['.pcap', '.pcapng', '.cap'];

  /// Validates that a file is an allowable packet capture before opening.
  static bool isValidPcapFile(String filePath) {
    if (filePath.isEmpty) return false;
    final ext = p.extension(filePath).toLowerCase();
    return allowedPcapExtensions.contains(ext);
  }

  /// Opens a folder in the native file explorer.
  static Future<bool> openFolder(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [folderPath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [folderPath]);
        return true;
      }
    } catch (e) {
      debugPrint('openFolder error: $e');
    }
    return false;
  }

  /// Opens a capture file in Wireshark or the default registered viewer.
  /// Enforces extension validation (S2) to prevent executing untrusted scripts/binaries.
  static Future<bool> openInWireshark(String filePath) async {
    try {
      if (!isValidPcapFile(filePath)) {
        debugPrint('Rejected opening file with non-pcap extension: $filePath');
        return false;
      }

      final file = File(filePath);
      if (!file.existsSync()) return false;

      if (Platform.isWindows) {
        const wiresharkPaths = [
          r'C:\Program Files\Wireshark\Wireshark.exe',
          r'C:\Program Files (x86)\Wireshark\Wireshark.exe',
        ];
        for (final path in wiresharkPaths) {
          if (File(path).existsSync()) {
            await Process.start(path, [filePath], mode: ProcessStartMode.detached);
            return true;
          }
        }
        // Fallback to default associated program for pcap files
        await Process.run('explorer.exe', [filePath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-a', 'Wireshark', filePath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('wireshark', [filePath]);
        return true;
      }
    } catch (e) {
      debugPrint('openInWireshark error: $e');
    }
    return false;
  }

  /// Copies text to the system clipboard.
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
