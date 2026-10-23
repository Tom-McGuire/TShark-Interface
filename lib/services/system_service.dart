import 'dart:io';
import 'package:flutter/services.dart';

class SystemService {
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
    } catch (_) {}
    return false;
  }

  /// Opens a file in Wireshark or the default registered viewer.
  static Future<bool> openInWireshark(String filePath) async {
    try {
      if (!File(filePath).existsSync()) return false;

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
        // Fallback to default associated program
        await Process.run('explorer.exe', [filePath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-a', 'Wireshark', filePath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('wireshark', [filePath]);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Copies text to the system clipboard.
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
