import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/services/capture_storage_service.dart';

void main() {
  group('RecoveryPolicy & Session Persistence Tests', () {
    const iface = CaptureInterface(index: '3', name: 'eth0', friendlyName: 'Ethernet');

    test('CaptureConfig serializes and deserializes recoveryPolicy correctly', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.ringBuffer,
        recoveryPolicy: RecoveryPolicy.auto,
      );

      final json = config.toJson();
      expect(json['recoveryPolicy'], equals('auto'));

      final decoded = CaptureConfig.fromJson(json);
      expect(decoded.recoveryPolicy, equals(RecoveryPolicy.auto));
      expect(decoded.recoveryPolicy.isAuto, isTrue);
      expect(decoded.recoveryPolicy.isPrompt, isFalse);
    });

    test('ActiveCaptureSession preserves embedded config and recoveryPolicy across serialization', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.timed,
        durationMinutes: 15,
        captureFilter: 'port 53',
        snaplen: 96,
        recoveryPolicy: RecoveryPolicy.prompt,
      );

      final session = ActiveCaptureSession(
        pid: 9999,
        startedAt: DateTime.parse('2026-10-24T08:00:00Z'),
        outputDirectory: r'C:\Captures',
        targetFilePath: r'C:\Captures\capture_20261024_080000.pcapng',
        mode: CaptureMode.timed,
        interfaceName: 'Ethernet',
        commandLine: 'tshark -i 3 -f "port 53" -s 96',
        filter: 'port 53',
        snaplen: 96,
        config: config,
        recoveryPolicy: RecoveryPolicy.prompt,
      );

      final json = session.toJson();
      expect(json['pid'], equals(9999));
      expect(json['recoveryPolicy'], equals('prompt'));
      expect(json['config'], isNotNull);

      final decoded = ActiveCaptureSession.fromJson(json);
      expect(decoded.pid, equals(9999));
      expect(decoded.recoveryPolicy, equals(RecoveryPolicy.prompt));
      expect(decoded.config, isNotNull);
      expect(decoded.config!.captureFilter, equals('port 53'));
      expect(decoded.config!.snaplen, equals(96));
      expect(decoded.config!.durationMinutes, equals(15));
      expect(decoded.config!.interface.name, equals('eth0'));
    });

    test('ActiveCaptureSession falls back gracefully if json config is absent', () {
      final legacyJson = {
        'pid': 1234,
        'startedAt': '2026-10-24T08:00:00Z',
        'outputDirectory': r'C:\Captures',
        'targetFilePath': r'C:\Captures\cap.pcapng',
        'mode': 'manual',
        'interfaceName': 'Wi-Fi',
        'commandLine': 'tshark -i 1',
        'filter': 'not port 22',
        'snaplen': 0,
        'isDetached': false,
      };

      final decoded = ActiveCaptureSession.fromJson(legacyJson);
      expect(decoded.pid, equals(1234));
      expect(decoded.recoveryPolicy, equals(RecoveryPolicy.prompt));
      expect(decoded.config, isNotNull);
      expect(decoded.config!.captureFilter, equals('not port 22'));
    });

    test('CaptureStorageService saves and loads default recovery policy', () async {
      final tempDir = Directory.systemTemp.createTempSync('tshark_storage_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final storage = CaptureStorageService(baseDirectory: tempDir);

      expect(await storage.loadDefaultRecoveryPolicy(), equals(RecoveryPolicy.prompt));

      await storage.saveDefaultRecoveryPolicy(RecoveryPolicy.auto);
      expect(await storage.loadDefaultRecoveryPolicy(), equals(RecoveryPolicy.auto));

      await storage.saveDefaultRecoveryPolicy(RecoveryPolicy.none);
      expect(await storage.loadDefaultRecoveryPolicy(), equals(RecoveryPolicy.none));
    });
  });
}
