import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/active_capture_session.dart';
import '../models/capture_config.dart';
import '../models/capture_history_item.dart';
import '../models/capture_preset.dart';

class CaptureStorageService {
  CaptureStorageService({this.baseDirectory});

  final Directory? baseDirectory;

  Future<Directory> _getStorageDir() async {
    if (baseDirectory != null) {
      if (!baseDirectory!.existsSync()) {
        baseDirectory!.createSync(recursive: true);
      }
      return baseDirectory!;
    }
    try {
      final dir = await getApplicationSupportDirectory();
      final appDir = Directory(p.join(dir.path, 'TSharkInterface'));
      if (!appDir.existsSync()) {
        appDir.createSync(recursive: true);
      }
      return appDir;
    } catch (_) {
      final fallback = Directory('./.tshark_interface');
      if (!fallback.existsSync()) {
        fallback.createSync(recursive: true);
      }
      return fallback;
    }
  }

  Future<File> _getFile(String fileName) async {
    final dir = await _getStorageDir();
    return File(p.join(dir.path, fileName));
  }

  // Active session
  Future<void> saveActiveSession(ActiveCaptureSession session) async {
    final file = await _getFile('active_session.json');
    await file.writeAsString(jsonEncode(session.toJson()), flush: true);
  }

  Future<ActiveCaptureSession?> loadActiveSession() async {
    try {
      final file = await _getFile('active_session.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          return ActiveCaptureSession.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearActiveSession() async {
    try {
      final file = await _getFile('active_session.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  // Preferences
  Future<Map<String, dynamic>> _loadPrefs() async {
    try {
      final file = await _getFile('preferences.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> _savePrefs(Map<String, dynamic> prefs) async {
    try {
      final file = await _getFile('preferences.json');
      await file.writeAsString(jsonEncode(prefs), flush: true);
    } catch (_) {}
  }

  Future<void> saveDefaultOutputDirectory(String path) async {
    final prefs = await _loadPrefs();
    prefs['defaultOutputDirectory'] = path;
    await _savePrefs(prefs);
  }

  Future<String?> loadDefaultOutputDirectory() async {
    final prefs = await _loadPrefs();
    final saved = prefs['defaultOutputDirectory'] as String?;
    if (saved != null && saved.isNotEmpty && Directory(saved).existsSync()) {
      return saved;
    }

    // Default to user Documents/TSharkCaptures
    try {
      final docs = await getApplicationDocumentsDirectory();
      final defaultCaptures = p.join(docs.path, 'TSharkCaptures');
      final dir = Directory(defaultCaptures);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return defaultCaptures;
    } catch (_) {
      return p.join(Directory.current.path, 'captures');
    }
  }

  Future<void> saveCustomTSharkPath(String path) async {
    final prefs = await _loadPrefs();
    prefs['customTSharkPath'] = path;
    await _savePrefs(prefs);
  }

  Future<String?> loadCustomTSharkPath() async {
    final prefs = await _loadPrefs();
    return prefs['customTSharkPath'] as String?;
  }

  Future<void> saveLastInterfaceIndex(String index) async {
    final prefs = await _loadPrefs();
    prefs['lastInterfaceIndex'] = index;
    await _savePrefs(prefs);
  }

  Future<String?> loadLastInterfaceIndex() async {
    final prefs = await _loadPrefs();
    return prefs['lastInterfaceIndex'] as String?;
  }

  Future<void> saveDefaultRecoveryPolicy(RecoveryPolicy policy) async {
    final prefs = await _loadPrefs();
    prefs['defaultRecoveryPolicy'] = policy.name;
    await _savePrefs(prefs);
  }

  Future<RecoveryPolicy> loadDefaultRecoveryPolicy() async {
    final prefs = await _loadPrefs();
    final name = prefs['defaultRecoveryPolicy'] as String?;
    if (name != null) {
      return RecoveryPolicy.values.firstWhere(
        (p) => p.name == name,
        orElse: () => RecoveryPolicy.prompt,
      );
    }
    return RecoveryPolicy.prompt;
  }

  // History
  Future<List<CaptureHistoryItem>> loadHistory() async {
    try {
      final file = await _getFile('history.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final list = jsonDecode(content) as List<dynamic>;
          return list
              .map((e) => CaptureHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> addHistoryItem(CaptureHistoryItem item) async {
    try {
      final current = await loadHistory();
      // Keep most recent first, max 50 items
      current.removeWhere((i) => i.filePath == item.filePath);
      current.insert(0, item);
      if (current.length > 50) {
        current.removeRange(50, current.length);
      }
      final file = await _getFile('history.json');
      await file.writeAsString(
        jsonEncode(current.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> removeHistoryItem(String filePath) async {
    try {
      final current = await loadHistory();
      current.removeWhere((i) => i.filePath == filePath);
      final file = await _getFile('history.json');
      await file.writeAsString(
        jsonEncode(current.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (_) {}
  }

  // Custom Presets
  Future<List<CapturePreset>> loadCustomPresets() async {
    try {
      final file = await _getFile('presets.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final list = jsonDecode(content) as List<dynamic>;
          return list
              .map((e) => CapturePreset.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveCustomPreset(CapturePreset preset) async {
    try {
      final current = await loadCustomPresets();
      current.removeWhere((p) => p.id == preset.id);
      current.add(preset);
      final file = await _getFile('presets.json');
      await file.writeAsString(
        jsonEncode(current.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> deleteCustomPreset(String id) async {
    try {
      final current = await loadCustomPresets();
      current.removeWhere((p) => p.id == id);
      final file = await _getFile('presets.json');
      await file.writeAsString(
        jsonEncode(current.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (_) {}
  }
}
