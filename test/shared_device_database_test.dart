import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:tshark_interface/services/shared_device_database.dart';

class _ChangeWatcher {
  _ChangeWatcher(Stream<void> stream) {
    _sub = stream.listen((_) {
      count++;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    });
  }

  late final StreamSubscription<void> _sub;
  final List<Completer<void>> _waiters = [];
  int count = 0;

  Future<void> waitForCount(
    int expectedCount, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    while (count < expectedCount) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future.timeout(timeout);
    }
  }

  Future<void> dispose() => _sub.cancel();
}

void _writeExternalThemeMode(String dbPath, String mode, String updatedAt) {
  final externalDb = sqlite3.open(dbPath);
  try {
    externalDb.execute(
      'CREATE TABLE IF NOT EXISTS suite_settings ('
      'key TEXT PRIMARY KEY NOT NULL, '
      'value TEXT NOT NULL, '
      'updated_at TEXT NOT NULL'
      ');',
    );
    externalDb.execute(
      "INSERT OR REPLACE INTO suite_settings (key, value, updated_at) VALUES ('theme_mode', ?, ?);",
      [mode, updatedAt],
    );
  } finally {
    externalDb.close();
  }
}

void main() {
  group('SharedDeviceDatabase cross-process polling', () {
    test('detects external updates when DB already exists before listening',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('shared_db_exists_');
      final dbPath = p.join(tempDir.path, 'shared_devices.db');

      _writeExternalThemeMode(dbPath, 'dark', '2026-11-19T00:00:00Z');

      final db = SharedDeviceDatabase(
        customPath: dbPath,
        pollInterval: const Duration(milliseconds: 30),
        enablePolling: true,
      );
      final watcher = _ChangeWatcher(db.onDatabaseChanged);

      addTearDown(() async {
        await watcher.dispose();
        db.dispose();
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(watcher.count, equals(0));
      expect(await db.getThemeMode(), equals('dark'));

      _writeExternalThemeMode(dbPath, 'light', '2026-11-19T00:00:01Z');
      await watcher.waitForCount(1);
      expect(await db.getThemeMode(), equals('light'));

      _writeExternalThemeMode(dbPath, 'dark', '2026-11-19T00:00:02Z');
      await watcher.waitForCount(2);
      expect(await db.getThemeMode(), equals('dark'));
    });

    test('detects external DB creation and updates when DB does not exist yet',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('shared_db_late_');
      final dbPath = p.join(tempDir.path, 'shared_devices.db');

      final db = SharedDeviceDatabase(
        customPath: dbPath,
        pollInterval: const Duration(milliseconds: 30),
        enablePolling: true,
      );
      final watcher = _ChangeWatcher(db.onDatabaseChanged);

      addTearDown(() async {
        await watcher.dispose();
        db.dispose();
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      expect(File(dbPath).existsSync(), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(watcher.count, equals(0));

      _writeExternalThemeMode(dbPath, 'light', '2026-11-19T00:00:01Z');
      await watcher.waitForCount(1);
      expect(await db.getThemeMode(), equals('light'));

      _writeExternalThemeMode(dbPath, 'dark', '2026-11-19T00:00:02Z');
      await watcher.waitForCount(2);
      expect(await db.getThemeMode(), equals('dark'));
    });

    test('does not double-notify after local setThemeMode write', () async {
      final tempDir = Directory.systemTemp.createTempSync('shared_db_local_');
      final dbPath = p.join(tempDir.path, 'shared_devices.db');

      final db = SharedDeviceDatabase(
        customPath: dbPath,
        pollInterval: const Duration(milliseconds: 30),
        enablePolling: true,
      );
      final watcher = _ChangeWatcher(db.onDatabaseChanged);

      addTearDown(() async {
        await watcher.dispose();
        db.dispose();
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      await db.setThemeMode('light');
      await watcher.waitForCount(1);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(watcher.count, equals(1));
      expect(await db.getThemeMode(), equals('light'));
    });
  });
}
