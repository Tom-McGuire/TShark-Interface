import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/active_capture_session.dart';
import '../models/capture_config.dart';
import '../models/capture_history_item.dart';
import '../models/capture_preset.dart';

class CaptureStorageService {
  CaptureStorageService({this.baseDirectory});

  final Directory? baseDirectory;
  Future<void> _prefLock = Future.value();

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
    } catch (e, st) {
      debugPrint('Error getting app support directory: $e\n$st');
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

  /// Atomically writes JSON content via a temporary file to prevent corruption on crash or abrupt reboot.
  Future<void> _safeWriteJson(File file, dynamic data) async {
    final tempFile = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    final jsonStr = jsonEncode(data);
    await tempFile.writeAsString(jsonStr, flush: true);
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (e, st) {
      debugPrint('Atomic rename failed ($e), falling back to direct write\n$st');
      await file.writeAsString(jsonStr, flush: true);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Serializes preference read/write operations to prevent race conditions.
  Future<T> _serializePrefOp<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    _prefLock = _prefLock.then((_) async {
      try {
        final result = await op();
        completer.complete(result);
      } catch (e, st) {
        debugPrint('Preference operation error: $e\n$st');
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // Active session
  Future<void> saveActiveSession(ActiveCaptureSession session) async {
    final file = await _getFile('active_session.json');
    await _safeWriteJson(file, session.toJson());
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
    } catch (e, st) {
      debugPrint('Failed to load active session: $e\n$st');
    }
    return null;
  }

  Future<void> clearActiveSession() async {
    try {
      final file = await _getFile('active_session.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      debugPrint('Failed to clear active session: $e\n$st');
    }
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
    } catch (e, st) {
      debugPrint('Failed to load preferences: $e\n$st');
    }
    return {};
  }

  Future<void> _savePrefs(Map<String, dynamic> prefs) async {
    try {
      final file = await _getFile('preferences.json');
      await _safeWriteJson(file, prefs);
    } catch (e, st) {
      debugPrint('Failed to save preferences: $e\n$st');
    }
  }

  Future<void> saveDefaultOutputDirectory(String path) async {
    return _serializePrefOp(() async {
      final prefs = await _loadPrefs();
      prefs['defaultOutputDirectory'] = path;
      await _savePrefs(prefs);
    });
  }

  Future<String?> loadDefaultOutputDirectory() async {
    final prefs = await _loadPrefs();
    final saved = prefs['defaultOutputDirectory'] as String?;
    if (saved != null && saved.isNotEmpty && Directory(saved).existsSync()) {
      return saved;
    }

    // Default to a safe local directory outside cloud sync (e.g. OneDrive)
    try {
      if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null && localAppData.isNotEmpty) {
          final defaultCaptures = p.join(localAppData, 'TSharkCaptures');
          final dir = Directory(defaultCaptures);
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          return defaultCaptures;
        }
      }

      final docs = await getApplicationDocumentsDirectory();
      // If Documents path contains OneDrive, avoid saving captures there
      if (docs.path.toLowerCase().contains('onedrive')) {
        final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          final safeDir = p.join(home, 'TSharkCaptures');
          final dir = Directory(safeDir);
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          return safeDir;
        }
      }

      final defaultCaptures = p.join(docs.path, 'TSharkCaptures');
      final dir = Directory(defaultCaptures);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return defaultCaptures;
    } catch (e, st) {
      debugPrint('Error resolving default output directory: $e\n$st');
      return p.join(Directory.current.path, 'captures');
    }
  }

  Future<void> saveCustomTSharkPath(String path) async {
    return _serializePrefOp(() async {
      final prefs = await _loadPrefs();
      prefs['customTSharkPath'] = path;
      await _savePrefs(prefs);
    });
  }

  Future<String?> loadCustomTSharkPath() async {
    final prefs = await _loadPrefs();
    return prefs['customTSharkPath'] as String?;
  }

  Future<void> saveLastInterfaceIndex(String index) async {
    return _serializePrefOp(() async {
      final prefs = await _loadPrefs();
      prefs['lastInterfaceIndex'] = index;
      await _savePrefs(prefs);
    });
  }

  Future<String?> loadLastInterfaceIndex() async {
    final prefs = await _loadPrefs();
    return prefs['lastInterfaceIndex'] as String?;
  }

  Future<void> saveLastInterfaceName(String name) async {
    return _serializePrefOp(() async {
      final prefs = await _loadPrefs();
      prefs['lastInterfaceName'] = name;
      await _savePrefs(prefs);
    });
  }

  Future<String?> loadLastInterfaceName() async {
    final prefs = await _loadPrefs();
    return prefs['lastInterfaceName'] as String?;
  }

  Future<void> saveDefaultRecoveryPolicy(RecoveryPolicy policy) async {
    return _serializePrefOp(() async {
      final prefs = await _loadPrefs();
      prefs['defaultRecoveryPolicy'] = policy.name;
      await _savePrefs(prefs);
    });
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
    } catch (e, st) {
      debugPrint('Failed to load history: $e\n$st');
    }
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
      await _safeWriteJson(
        file,
        current.map((e) => e.toJson()).toList(),
      );
    } catch (e, st) {
      debugPrint('Failed to add history item: $e\n$st');
    }
  }

  Future<void> removeHistoryItem(String filePath) async {
    try {
      final current = await loadHistory();
      current.removeWhere((i) => i.filePath == filePath);
      final file = await _getFile('history.json');
      await _safeWriteJson(
        file,
        current.map((e) => e.toJson()).toList(),
      );
    } catch (e, st) {
      debugPrint('Failed to remove history item: $e\n$st');
    }
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
    } catch (e, st) {
      debugPrint('Failed to load custom presets: $e\n$st');
    }
    return [];
  }

  Future<void> saveCustomPreset(CapturePreset preset) async {
    try {
      final current = await loadCustomPresets();
      current.removeWhere((p) => p.id == preset.id);
      current.add(preset);
      final file = await _getFile('presets.json');
      await _safeWriteJson(
        file,
        current.map((e) => e.toJson()).toList(),
      );
    } catch (e, st) {
      debugPrint('Failed to save custom preset: $e\n$st');
    }
  }

  Future<void> deleteCustomPreset(String id) async {
    try {
      final current = await loadCustomPresets();
      current.removeWhere((p) => p.id == id);
      final file = await _getFile('presets.json');
      await _safeWriteJson(
        file,
        current.map((e) => e.toJson()).toList(),
      );
    } catch (e, st) {
      debugPrint('Failed to delete custom preset: $e\n$st');
    }
  }
}
