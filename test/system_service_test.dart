import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/services/system_service.dart';

void main() {
  group('SystemService Tests', () {
    group('isValidPcapFile', () {
      test('accepts valid pcap extensions', () {
        expect(SystemService.isValidPcapFile('capture.pcap'), isTrue);
        expect(SystemService.isValidPcapFile('test.pcapng'), isTrue);
        expect(SystemService.isValidPcapFile('dump.cap'), isTrue);
        expect(SystemService.isValidPcapFile('/path/to/capture.pcapng'), isTrue);
        expect(SystemService.isValidPcapFile(r'C:\Captures\trace.pcap'), isTrue);
      });

      test('is case insensitive', () {
        expect(SystemService.isValidPcapFile('capture.PCAP'), isTrue);
        expect(SystemService.isValidPcapFile('test.PCAPNG'), isTrue);
        expect(SystemService.isValidPcapFile('dump.Cap'), isTrue);
      });

      test('rejects empty or extensionless paths', () {
        expect(SystemService.isValidPcapFile(''), isFalse);
        expect(SystemService.isValidPcapFile('capture'), isFalse);
        expect(SystemService.isValidPcapFile('/var/log/capture'), isFalse);
      });

      test('rejects non-pcap and potentially dangerous extensions', () {
        expect(SystemService.isValidPcapFile('script.sh'), isFalse);
        expect(SystemService.isValidPcapFile('malware.exe'), isFalse);
        expect(SystemService.isValidPcapFile('batch.bat'), isFalse);
        expect(SystemService.isValidPcapFile('archive.tar.gz'), isFalse);
        expect(SystemService.isValidPcapFile('report.pdf'), isFalse);
        expect(SystemService.isValidPcapFile('image.png'), isFalse);
      });
    });

    group('openFolder', () {
      test('creates directory if not existing and handles call gracefully', () async {
        final tempDir = Directory.systemTemp.createTempSync('sys_service_test_');
        final targetSubdir = Directory('${tempDir.path}/subfolder_test');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        expect(targetSubdir.existsSync(), isFalse);
        // openFolder creates the dir if missing before attempting native process launch
        final res = await SystemService.openFolder(targetSubdir.path);
        // In headless test environments, process launch might fail or succeed, but dir is created
        expect(targetSubdir.existsSync(), isTrue);
        expect(res, isA<bool>());
      });
    });

    group('openInWireshark', () {
      test('rejects invalid extension without checking disk', () async {
        final res = await SystemService.openInWireshark('suspicious.exe');
        expect(res, isFalse);
      });

      test('returns false if pcap file does not exist', () async {
        final res = await SystemService.openInWireshark('/path/that/definitely/does/not/exist.pcapng');
        expect(res, isFalse);
      });
    });
  });
}
