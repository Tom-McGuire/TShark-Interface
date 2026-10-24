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
  });
}
