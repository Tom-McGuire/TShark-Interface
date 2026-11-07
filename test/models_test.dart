import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_history_item.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/models/capture_preset.dart';
import 'package:tshark_interface/models/remote_host.dart';

void main() {
  group('Models Tests', () {
    group('CaptureHistoryItem', () {
      test('formattedSize calculates B, KB, MB, GB accurately', () {
        final bItem = CaptureHistoryItem(
          filePath: '/captures/small.pcap',
          fileName: 'small.pcap',
          timestamp: DateTime(2026, 1, 1),
          fileSizeBytes: 512,
          interfaceName: 'eth0',
        );
        expect(bItem.formattedSize, equals('512 B'));

        final kbItem = CaptureHistoryItem(
          filePath: '/captures/med.pcap',
          fileName: 'med.pcap',
          timestamp: DateTime(2026, 1, 1),
          fileSizeBytes: 1024 * 15,
          interfaceName: 'eth0',
        );
        expect(kbItem.formattedSize, equals('15.0 KB'));

        final mbItem = CaptureHistoryItem(
          filePath: '/captures/large.pcap',
          fileName: 'large.pcap',
          timestamp: DateTime(2026, 1, 1),
          fileSizeBytes: (1024 * 1024 * 2.5).round(),
          interfaceName: 'eth0',
        );
        expect(mbItem.formattedSize, equals('2.5 MB'));

        final gbItem = CaptureHistoryItem(
          filePath: '/captures/huge.pcap',
          fileName: 'huge.pcap',
          timestamp: DateTime(2026, 1, 1),
          fileSizeBytes: (1024 * 1024 * 1024 * 3.75).round(),
          interfaceName: 'eth0',
        );
        expect(gbItem.formattedSize, equals('3.75 GB'));
      });

      test('toJson and fromJson serialize and deserialize accurately', () {
        final now = DateTime.now();
        final item = CaptureHistoryItem(
          filePath: '/tmp/test.pcapng',
          fileName: 'test.pcapng',
          timestamp: now,
          fileSizeBytes: 2048,
          interfaceName: 'wlan0',
          filter: 'tcp port 443',
        );

        final json = item.toJson();
        final decoded = CaptureHistoryItem.fromJson(json);

        expect(decoded.filePath, equals('/tmp/test.pcapng'));
        expect(decoded.fileName, equals('test.pcapng'));
        expect(decoded.timestamp.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
        expect(decoded.fileSizeBytes, equals(2048));
        expect(decoded.interfaceName, equals('wlan0'));
        expect(decoded.filter, equals('tcp port 443'));
      });

      test('fromJson falls back to defaults when optional fields are null', () {
        final json = {
          'filePath': '/tmp/fallback.pcapng',
          'fileName': 'fallback.pcapng',
          'timestamp': DateTime.now().toIso8601String(),
        };

        final decoded = CaptureHistoryItem.fromJson(json);
        expect(decoded.fileSizeBytes, equals(0));
        expect(decoded.interfaceName, equals('Interface'));
        expect(decoded.filter, isEmpty);
      });
    });

    group('CaptureInterface', () {
      test('displayName formats properly with or without friendlyName', () {
        const withFriendly = CaptureInterface(
          index: '1',
          name: r'\Device\NPF_{GUID}',
          friendlyName: 'Wi-Fi',
        );
        expect(withFriendly.displayName, equals('1. Wi-Fi'));
        expect(withFriendly.subtitle, equals(r'\Device\NPF_{GUID}'));
        expect(withFriendly.toString(), equals('1. Wi-Fi'));

        const withoutFriendly = CaptureInterface(
          index: '2',
          name: 'eth0',
          description: 'Ethernet Adapter',
        );
        expect(withoutFriendly.displayName, equals('2. eth0'));
        expect(withoutFriendly.subtitle, equals('Ethernet Adapter'));

        const minimal = CaptureInterface(index: '3', name: 'any');
        expect(minimal.subtitle, equals('Interface #3'));
      });

      test('equality and hashCode work as expected', () {
        const if1 = CaptureInterface(index: '1', name: 'eth0', friendlyName: 'Ethernet');
        const if2 = CaptureInterface(index: '1', name: 'eth0', friendlyName: 'Ethernet');
        const if3 = CaptureInterface(index: '2', name: 'eth1', friendlyName: 'Ethernet 2');

        expect(if1, equals(if2));
        expect(if1.hashCode, equals(if2.hashCode));
        expect(if1, isNot(equals(if3)));
      });

      test('toJson and fromJson roundtrip', () {
        const original = CaptureInterface(
          index: '4',
          name: 'ens192',
          friendlyName: 'LAN Connection',
          description: 'Intel Corporation 82545EM',
        );
        final json = original.toJson();
        final decoded = CaptureInterface.fromJson(json);

        expect(decoded.index, equals('4'));
        expect(decoded.name, equals('ens192'));
        expect(decoded.friendlyName, equals('LAN Connection'));
        expect(decoded.description, equals('Intel Corporation 82545EM'));
      });
    });

    group('CapturePreset', () {
      test('builtInPresets are properly defined and valid', () {
        final presets = CapturePreset.builtInPresets;
        expect(presets, isNotEmpty);
        expect(presets.any((p) => p.id == 'all_traffic'), isTrue);
        expect(presets.any((p) => p.id == 'web_traffic'), isTrue);
        expect(presets.any((p) => p.id == 'dns_only'), isTrue);

        for (final p in presets) {
          expect(p.id, isNotEmpty);
          expect(p.title, isNotEmpty);
          expect(p.iconName, isNotEmpty);
          expect(p.isBuiltIn, isTrue);
        }
      });

      test('toJson and fromJson roundtrip', () {
        const custom = CapturePreset(
          id: 'custom_voip',
          title: 'SIP / RTP',
          description: 'Captures voice over IP traffic',
          iconName: 'call',
          filter: 'port 5060 or portrange 10000-20000',
          mode: CaptureMode.ringBuffer,
          snaplen: 128,
          ringFilesCount: 8,
          ringRotateMinutes: 15,
          ringRotateFilesizeMb: 250,
          ringRotateBySize: true,
          isBuiltIn: false,
        );

        final json = custom.toJson();
        final decoded = CapturePreset.fromJson(json);

        expect(decoded.id, equals('custom_voip'));
        expect(decoded.title, equals('SIP / RTP'));
        expect(decoded.description, equals('Captures voice over IP traffic'));
        expect(decoded.filter, equals('port 5060 or portrange 10000-20000'));
        expect(decoded.mode, equals(CaptureMode.ringBuffer));
        expect(decoded.snaplen, equals(128));
        expect(decoded.ringFilesCount, equals(8));
        expect(decoded.ringRotateMinutes, equals(15));
        expect(decoded.ringRotateFilesizeMb, equals(250));
        expect(decoded.ringRotateBySize, isTrue);
        expect(decoded.isBuiltIn, isFalse);
      });
    });

    group('CaptureConfig & Enums', () {
      test('CaptureMode and RecoveryPolicy labels and descriptions', () {
        for (final mode in CaptureMode.values) {
          expect(mode.label, isNotEmpty);
          expect(mode.description, isNotEmpty);
        }

        for (final policy in RecoveryPolicy.values) {
          expect(policy.label, isNotEmpty);
          expect(policy.description, isNotEmpty);
        }

        expect(RecoveryPolicy.none.isNone, isTrue);
        expect(RecoveryPolicy.prompt.isPrompt, isTrue);
        expect(RecoveryPolicy.auto.isAuto, isTrue);
      });

      test('totalTimedSeconds converts hours and minutes to total seconds', () {
        const c1 = CaptureConfig(
          interface: CaptureInterface(index: '1', name: 'eth0'),
          outputDirectory: '/tmp',
          durationMinutes: 30,
          durationHours: 2,
        );
        expect(c1.totalTimedSeconds, equals(2 * 3600 + 30 * 60)); // 7200 + 1800 = 9000
      });

      test('copyWith preserves unchanged values', () {
        const original = CaptureConfig(
          interface: CaptureInterface(index: '1', name: 'eth0'),
          outputDirectory: '/tmp/original',
          mode: CaptureMode.manual,
          filePrefix: 'test',
          snaplen: 64,
        );

        final updated = original.copyWith(
          outputDirectory: '/tmp/updated',
          mode: CaptureMode.timed,
        );

        expect(updated.interface.name, equals('eth0'));
        expect(updated.outputDirectory, equals('/tmp/updated'));
        expect(updated.mode, equals(CaptureMode.timed));
        expect(updated.filePrefix, equals('test'));
        expect(updated.snaplen, equals(64));
      });
    });

    group('RemoteHost', () {
      test('displayLabel and copyWith', () {
        const host = RemoteHost(
          id: 'rh1',
          name: 'Gateway Router',
          host: '192.168.1.1',
          port: 2222,
          username: 'admin',
        );

        expect(host.displayLabel, equals('Gateway Router (192.168.1.1:2222)'));

        final modified = host.copyWith(
          port: 22,
          isReachable: true,
          useSudo: true,
        );

        expect(modified.port, equals(22));
        expect(modified.isReachable, isTrue);
        expect(modified.useSudo, isTrue);
        expect(modified.displayLabel, equals('Gateway Router (192.168.1.1)'));
      });
    });
  });
}
