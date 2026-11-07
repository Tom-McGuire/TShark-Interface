import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/models/capture_preset.dart';
import 'package:tshark_interface/services/tshark_service.dart';

void main() {
  group('TSharkService CLI generation tests', () {
    late TSharkService service;
    const iface = CaptureInterface(index: '5', name: r'\Device\NPF_{...}', friendlyName: 'Wi-Fi');

    setUp(() {
      service = TSharkService();
    });

    test('buildArguments generates correct manual mode arguments using stable device name and quiet mode', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.manual,
        captureFilter: 'not port 22',
        snaplen: 96,
        promiscuous: true,
      );

      final args = service.buildArguments(config, r'C:\Captures\test.pcapng');
      expect(args, containsAllInOrder(['-i', r'\Device\NPF_{...}', '-q', '-s', '96', '-f', 'not port 22', '-w', r'C:\Captures\test.pcapng']));
    });

    test('buildArguments handles promiscuous mode disabled (-p)', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.manual,
        promiscuous: false,
      );

      final args = service.buildArguments(config, r'C:\Captures\test.pcapng');
      expect(args, contains('-p'));
    });

    test('buildArguments generates timed autostop arguments', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.timed,
        durationMinutes: 5,
        durationHours: 0,
      );

      final args = service.buildArguments(config, r'C:\Captures\test.pcapng');
      expect(args, containsAllInOrder(['-i', r'\Device\NPF_{...}', '-q', '-a', 'duration:300', '-w', r'C:\Captures\test.pcapng']));
    });

    test('buildArguments generates ring buffer arguments by time', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.ringBuffer,
        ringRotateMinutes: 10,
        ringFilesCount: 5,
        ringRotateBySize: false,
      );

      final args = service.buildArguments(config, r'C:\Captures\test.pcapng');
      expect(args, containsAllInOrder(['-i', r'\Device\NPF_{...}', '-q', '-b', 'duration:600', '-b', 'files:5', '-w', r'C:\Captures\test.pcapng']));
    });

    test('buildArguments generates ring buffer arguments by size', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.ringBuffer,
        ringRotateFilesizeMb: 50,
        ringFilesCount: 10,
        ringRotateBySize: true,
      );

      final args = service.buildArguments(config, r'C:\Captures\test.pcapng');
      expect(args, containsAllInOrder(['-i', r'\Device\NPF_{...}', '-q', '-b', 'filesize:51200', '-b', 'files:10', '-w', r'C:\Captures\test.pcapng']));
    });

    test('buildArguments includes packet limit count', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.packetCount,
        packetCountLimit: 5000,
      );

      final args = service.buildArguments(config, r'C:\Captures\test.pcapng');
      expect(args, containsAllInOrder(['-i', r'\Device\NPF_{...}', '-q', '-c', '5000', '-w', r'C:\Captures\test.pcapng']));
    });

    test('buildArguments falls back to interface index if interface name is empty', () {
      const fallbackIface = CaptureInterface(index: '7', name: '');
      const config = CaptureConfig(
        interface: fallbackIface,
        outputDirectory: '/tmp',
        mode: CaptureMode.manual,
      );

      final args = service.buildArguments(config, '/tmp/test.pcapng');
      expect(args, containsAllInOrder(['-i', '7', '-w', '/tmp/test.pcapng']));
    });

    test('buildDisplayCommandLine quotes arguments containing spaces or special characters', () {
      const config = CaptureConfig(
        interface: iface,
        outputDirectory: r'C:\Captures',
        mode: CaptureMode.manual,
        captureFilter: 'tcp port 80 or tcp port 443',
      );

      final cmd = service.buildDisplayCommandLine(
        tsharkPath: r'C:\Program Files\Wireshark\tshark.exe',
        config: config,
        fullOutputPath: r'C:\Captures Folder\test.pcapng',
      );

      expect(cmd, contains(r'"C:\Program Files\Wireshark\tshark.exe"'));
      expect(cmd, contains(r'-i "\Device\NPF_{...}"'));
      expect(cmd, contains(r'-f "tcp port 80 or tcp port 443"'));
      expect(cmd, contains(r'-w "C:\Captures Folder\test.pcapng"'));
    });

    test('Sanitizes file prefix safely', () {
      expect(TSharkService.sanitizeFilePrefix('test_123'), equals('test_123'));
      expect(TSharkService.sanitizeFilePrefix('../../bad_prefix'), equals('bad_prefix'));
      expect(TSharkService.sanitizeFilePrefix('capture:stream'), equals('capture_stream'));
      expect(TSharkService.sanitizeFilePrefix(';; rm -rf /'), equals('rm_rf'));
      expect(TSharkService.sanitizeFilePrefix(''), equals('capture'));
      expect(TSharkService.sanitizeFilePrefix('___'), equals('capture'));
    });

    test('Built-in presets are valid and non-empty', () {
      final presets = CapturePreset.builtInPresets;
      expect(presets.length, greaterThanOrEqualTo(6));
      expect(presets.any((p) => p.id == 'dns_only'), isTrue);
      expect(presets.any((p) => p.id == 'exclude_mgmt'), isTrue);
      expect(presets.any((p) => p.id == 'headers_only'), isTrue);
    });

    group('parseInterfacesOutput', () {
      test('parses Windows style interfaces with friendly names and GUIDs', () {
        const rawWindows = '''
1. \\Device\\NPF_{12345678-ABCD-EF01-2345-6789ABCDEF01} (Wi-Fi)
2. \\Device\\NPF_{87654321-DCBA-10FE-5432-10FEDCBA9876} (Ethernet)
3. \\Device\\NPF_Loopback (Npcap Loopback Adapter)
''';

        final ifaces = TSharkService.parseInterfacesOutput(rawWindows);
        expect(ifaces.length, equals(3));

        expect(ifaces[0].index, equals('1'));
        expect(ifaces[0].name, equals(r'\Device\NPF_{12345678-ABCD-EF01-2345-6789ABCDEF01}'));
        expect(ifaces[0].friendlyName, equals('Wi-Fi'));

        expect(ifaces[1].index, equals('2'));
        expect(ifaces[1].name, equals(r'\Device\NPF_{87654321-DCBA-10FE-5432-10FEDCBA9876}'));
        expect(ifaces[1].friendlyName, equals('Ethernet'));

        expect(ifaces[2].index, equals('3'));
        expect(ifaces[2].name, equals(r'\Device\NPF_Loopback'));
        expect(ifaces[2].friendlyName, equals('Npcap Loopback Adapter'));
      });

      test('parses Linux style interfaces including any pseudo-device', () {
        const rawLinux = '''
1. eth0
2. wlan0 (Wi-Fi Wireless Adapter)
3. any (Pseudo-device that captures on all interfaces)
4. lo (Loopback)
''';

        final ifaces = TSharkService.parseInterfacesOutput(rawLinux);
        expect(ifaces.length, equals(4));

        expect(ifaces[0].index, equals('1'));
        expect(ifaces[0].name, equals('eth0'));
        expect(ifaces[0].friendlyName, isNull);

        expect(ifaces[1].index, equals('2'));
        expect(ifaces[1].name, equals('wlan0'));
        expect(ifaces[1].friendlyName, equals('Wi-Fi Wireless Adapter'));

        expect(ifaces[2].index, equals('3'));
        expect(ifaces[2].name, equals('any'));
        expect(ifaces[2].friendlyName, equals('Pseudo-device that captures on all interfaces'));
      });

      test('ignores empty lines and unparseable noise', () {
        const messy = '''

1. eth0 (Primary Network)

Some random debug log from tshark
2. eth1

''';

        final ifaces = TSharkService.parseInterfacesOutput(messy);
        expect(ifaces.length, equals(2));
        expect(ifaces[0].name, equals('eth0'));
        expect(ifaces[1].name, equals('eth1'));
      });

      test('returns empty list on empty output', () {
        expect(TSharkService.parseInterfacesOutput(''), isEmpty);
        expect(TSharkService.parseInterfacesOutput('   \n\n  '), isEmpty);
      });
    });

    group('isValidTSharkExecutable', () {
      test('returns false for empty string or non-existent file', () {
        expect(TSharkService.isValidTSharkExecutable(''), isFalse);
        expect(TSharkService.isValidTSharkExecutable('/does/not/exist/tshark'), isFalse);
      });

      test('returns true only if file exists and has tshark basename', () {
        final tempDir = Directory.systemTemp.createTempSync('tshark_val_test');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final validFile = File('${tempDir.path}/tshark');
        validFile.writeAsStringSync('');

        final validWindowsFile = File('${tempDir.path}/tshark.exe');
        validWindowsFile.writeAsStringSync('');

        final invalidFile = File('${tempDir.path}/wireshark');
        invalidFile.writeAsStringSync('');

        expect(TSharkService.isValidTSharkExecutable(validFile.path), isTrue);
        expect(TSharkService.isValidTSharkExecutable(validWindowsFile.path), isTrue);
        expect(TSharkService.isValidTSharkExecutable(invalidFile.path), isFalse);
      });
    });
  });
}
