import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Synchronizes global Network Suite preferences (such as `theme_mode` in
/// `suite_settings`) with the shared SQLite database at
/// `~/.local/share/NetworkSuite/shared_devices.db`, while falling back safely
/// to in-memory state in CI or isolated test environments.
class SharedDeviceDatabase {
  SharedDeviceDatabase({
    this.customPath,
    this.pollInterval = const Duration(seconds: 1),
    this.enablePolling,
  }) {
    _changeController = StreamController<void>.broadcast(
      onListen: _ensurePolling,
      onCancel: _stopPolling,
    );
  }

  static SharedDeviceDatabase? _instance;
  static SharedDeviceDatabase get instance =>
      _instance ??= SharedDeviceDatabase();

  final String? customPath;
  final Duration pollInterval;
  final bool? enablePolling;
  late final StreamController<void> _changeController;

  String _inMemoryThemeMode = 'dark';
  Timer? _pollTimer;
  String? _lastThemeStamp;

  /// Broadcast stream notified whenever settings change locally or on disk.
  Stream<void> get onDatabaseChanged => _changeController.stream;

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Manually notify listeners of a database change.
  void notifyChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  /// Resolves the canonical shared database directory based on host OS.
  static String getDefaultDirectoryPath() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ??
          p.join(
            Platform.environment['USERPROFILE'] ?? 'C:',
            'AppData',
            'Local',
          );
      return p.join(localAppData, 'NetworkSuite');
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, 'Library', 'Application Support', 'NetworkSuite');
    } else {
      final xdg = Platform.environment['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        return p.join(xdg, 'NetworkSuite');
      }
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, '.local', 'share', 'NetworkSuite');
    }
  }

  /// Resolves the default shared database file path.
  static String getDefaultDatabasePath() {
    return p.join(getDefaultDirectoryPath(), 'shared_devices.db');
  }

  void _ensurePolling() {
    if (_pollTimer != null) return;
    final shouldPoll =
        enablePolling ?? !Platform.environment.containsKey('FLUTTER_TEST');
    final path = customPath ?? getDefaultDatabasePath();
    if (!shouldPoll || path == ':memory:') {
      return;
    }

    _lastThemeStamp = _readThemeStamp(path);
    _pollTimer = Timer.periodic(pollInterval, (_) {
      final stamp = _readThemeStamp(path);
      if (stamp != null && stamp != _lastThemeStamp) {
        _lastThemeStamp = stamp;
        notifyChanged();
      } else if (stamp == null && _lastThemeStamp != null) {
        _lastThemeStamp = null;
      }
    });
  }

  String? _readThemeStamp(String path) {
    if (path == ':memory:' || !File(path).existsSync()) return null;
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      db.execute('PRAGMA busy_timeout = 500;');
      final tableCheck = db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'suite_settings' LIMIT 1;",
      );
      if (tableCheck.isEmpty) return null;

      final rows = db.select(
        "SELECT value, updated_at FROM suite_settings WHERE key = 'theme_mode' LIMIT 1;",
      );
      if (rows.isEmpty) return null;
      return '${rows.first['value']}|${rows.first['updated_at']}';
    } catch (_) {
      return null;
    } finally {
      db?.close();
    }
  }

  /// Reads the global suite theme mode (`'dark'` or `'light'`), defaulting to
  /// `'dark'` when uninitialized or before the table exists.
  Future<String> getThemeMode({String? dbPath}) async {
    final targetPath = dbPath ?? customPath ?? getDefaultDatabasePath();
    if (targetPath == ':memory:' || !File(targetPath).existsSync()) {
      return _inMemoryThemeMode;
    }

    Database? db;
    try {
      db = sqlite3.open(targetPath, mode: OpenMode.readOnly);
      db.execute('PRAGMA busy_timeout = 1000;');
      final tableCheck = db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'suite_settings' LIMIT 1;",
      );
      if (tableCheck.isEmpty) return _inMemoryThemeMode;

      final rows = db.select(
        "SELECT value FROM suite_settings WHERE key = 'theme_mode' LIMIT 1;",
      );
      if (rows.isEmpty) return 'dark';
      final value = rows.first['value'] as String?;
      return value == 'light' ? 'light' : 'dark';
    } catch (_) {
      return _inMemoryThemeMode;
    } finally {
      db?.close();
    }
  }

  /// Sets the global suite theme mode (`'dark'` or `'light'`) and notifies
  /// listeners via [onDatabaseChanged].
  Future<void> setThemeMode(String mode, {String? dbPath}) async {
    if (mode != 'dark' && mode != 'light') {
      throw ArgumentError.value(mode, 'mode', "must be 'dark' or 'light'");
    }

    _inMemoryThemeMode = mode;

    final defaultTarget = customPath ?? getDefaultDatabasePath();
    final targetPath = dbPath ?? defaultTarget;
    final shouldPersist =
        dbPath != null ||
        customPath != null ||
        File(targetPath).existsSync() ||
        File(targetPath).parent.existsSync();

    var wroteToDb = false;
    if (targetPath != ':memory:' && shouldPersist) {
      Database? db;
      try {
        final parentDir = File(targetPath).parent;
        if (!parentDir.existsSync()) {
          parentDir.createSync(recursive: true);
        }
        db = sqlite3.open(targetPath);
        db.execute('PRAGMA busy_timeout = 5000;');
        db.execute(
          'CREATE TABLE IF NOT EXISTS suite_settings ('
          'key TEXT PRIMARY KEY NOT NULL, '
          'value TEXT NOT NULL, '
          'updated_at TEXT NOT NULL'
          ');',
        );
        db.execute(
          "INSERT OR REPLACE INTO suite_settings (key, value, updated_at) VALUES ('theme_mode', ?, ?);",
          [mode, DateTime.now().toUtc().toIso8601String()],
        );
        wroteToDb = true;
      } catch (_) {
        // Keep in-memory state if DB path is read-only or unavailable.
      } finally {
        db?.close();
      }
    }

    if (wroteToDb && targetPath == defaultTarget) {
      _lastThemeStamp = _readThemeStamp(targetPath);
    }

    notifyChanged();
  }

  /// Stops internal polling timer and closes the change stream controller.
  void dispose() {
    _stopPolling();
    if (!_changeController.isClosed) {
      _changeController.close();
    }
  }
}
