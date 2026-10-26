import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/remote_host.dart';
import 'package:tshark_interface/services/capture_storage_service.dart';
import 'package:tshark_interface/services/remote_ssh_service.dart';
import 'package:tshark_interface/services/tshark_service.dart';

void main() {
  group('Remote SSH Capture & Persistence Tests', () {
    test('RemoteHost serializes and deserializes accurately', () {
      const host = RemoteHost(
        id: 'host_1',
        name: 'Edge Router',
        host: '192.168.10.1',
        port: 2222,
        username: 'netadmin',
        password: 'secret_password',
        defaultOutputDirectory: '/var/captures',
        useSudo: true,
        osType: RemoteOsType.linux,
        detectedTSharkVersion: 'TShark (Wireshark) 4.2.5',
      );

      final json = host.toJson();
      final decoded = RemoteHost.fromJson(json);

      expect(decoded.id, equals('host_1'));
      expect(decoded.name, equals('Edge Router'));
      expect(decoded.host, equals('192.168.10.1'));
      expect(decoded.port, equals(2222));
      expect(decoded.username, equals('netadmin'));
      expect(decoded.password, equals('secret_password'));
      expect(decoded.defaultOutputDirectory, equals('/var/captures'));
      expect(decoded.useSudo, isTrue);
      expect(decoded.osType, equals(RemoteOsType.linux));
      expect(decoded.detectedTSharkVersion, equals('TShark (Wireshark) 4.2.5'));
      expect(decoded.displayLabel, equals('Edge Router (192.168.10.1:2222)'));
    });

    test('CaptureStorageService saves, updates, and clears remote hosts & remote sessions', () async {
      final tempDir = Directory.systemTemp.createTempSync('tshark_remote_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final storage = CaptureStorageService(baseDirectory: tempDir);

      const host1 = RemoteHost(
        id: 'h1',
        name: 'Probe 01',
        host: '10.0.0.11',
        username: 'root',
      );
      const host2 = RemoteHost(
        id: 'h2',
        name: 'Probe 02',
        host: '10.0.0.12',
        username: 'admin',
      );

      await storage.saveRemoteHost(host1);
      await storage.saveRemoteHost(host2);

      final loadedHosts = await storage.loadRemoteHosts();
      expect(loadedHosts.length, equals(2));
      expect(loadedHosts.first.name, equals('Probe 01'));

      // Save active remote sessions for both hosts
      final session1 = ActiveCaptureSession(
        pid: 4100,
        startedAt: DateTime.parse('2026-10-26T18:00:00Z'),
        outputDirectory: '/tmp/tshark_captures',
        targetFilePath: '/tmp/tshark_captures/capture_1.pcapng',
        mode: CaptureMode.manual,
        interfaceName: 'eth0',
        commandLine: 'ssh root@10.0.0.11 "tshark -i eth0"',
        isRemote: true,
        remoteHostId: 'h1',
        remoteHostName: 'Probe 01 (10.0.0.11)',
        lastKnownSizeBytes: 20480,
      );

      final session2 = ActiveCaptureSession(
        pid: 5200,
        startedAt: DateTime.parse('2026-10-26T18:05:00Z'),
        outputDirectory: '/tmp/tshark_captures',
        targetFilePath: '/tmp/tshark_captures/capture_2.pcapng',
        mode: CaptureMode.ringBuffer,
        interfaceName: 'ens192',
        commandLine: 'ssh admin@10.0.0.12 "tshark -i ens192"',
        isRemote: true,
        remoteHostId: 'h2',
        remoteHostName: 'Probe 02 (10.0.0.12)',
      );

      await storage.saveRemoteSession(session1);
      await storage.saveRemoteSession(session2);

      var loadedSessions = await storage.loadRemoteSessions();
      expect(loadedSessions.length, equals(2));
      expect(loadedSessions.first.isRemote, isTrue);
      expect(loadedSessions.first.remoteHostId, equals('h1'));
      expect(loadedSessions.first.lastKnownSizeBytes, equals(20480));

      // Clear h1 session (e.g. when remote host was turned off and user clicks Clear Session)
      await storage.removeRemoteSession('h1');
      loadedSessions = await storage.loadRemoteSessions();
      expect(loadedSessions.length, equals(1));
      expect(loadedSessions.first.remoteHostId, equals('h2'));

      // Delete host h2
      await storage.deleteRemoteHost('h2');
      expect((await storage.loadRemoteHosts()).length, equals(1));
    });

    test('TSharkService.parseInterfacesOutput parses Linux and Windows tshark -D output', () {
      const sampleOutput = '''
1. eth0
2. ens192 (VMware Virtual Ethernet)
3. any (Pseudo-device that captures on all interfaces)
4. lo (Loopback)
5. \\Device\\NPF_{D8FFFD59-6507-4BA4-8CBF-E10937211DDD} (Wi-Fi)
''';

      final interfaces = TSharkService.parseInterfacesOutput(sampleOutput);
      expect(interfaces.length, equals(5));
      expect(interfaces[0].index, equals('1'));
      expect(interfaces[0].name, equals('eth0'));
      expect(interfaces[0].friendlyName, isNull);
      expect(interfaces[1].name, equals('ens192'));
      expect(interfaces[1].friendlyName, equals('VMware Virtual Ethernet'));
      expect(interfaces[2].name, equals('any'));
      expect(interfaces[4].friendlyName, equals('Wi-Fi'));
    });

    test('RemoteSshService builds valid Linux and Windows detached start commands', () {
      final linuxCmd = RemoteSshService.buildLinuxStartCommand(
        tsharkBin: '/usr/bin/tshark',
        args: ['-i', 'eth0', '-q', '-f', 'port 53', '-w', '/tmp/cap.pcapng'],
        targetDir: '/tmp/captures',
        useSudo: true,
      );

      expect(linuxCmd, contains("mkdir -p '/tmp/captures'"));
      expect(linuxCmd, contains("nohup sudo -n '/usr/bin/tshark'"));
      expect(linuxCmd, contains("'-i' 'eth0' '-q' '-f' 'port 53' '-w' '/tmp/cap.pcapng'"));
      expect(linuxCmd, contains('PID:\$PID'));

      final winCmd = RemoteSshService.buildWindowsStartCommand(
        tsharkBin: r'C:\Program Files\Wireshark\tshark.exe',
        args: ['-i', r'\Device\NPF_{123}', '-q', '-w', r'C:\Temp\cap.pcapng'],
        targetDir: r'C:\Temp',
      );

      expect(winCmd, contains('Start-Process'));
      expect(winCmd, contains(r'C:\Program Files\Wireshark\tshark.exe'));
      expect(winCmd, contains('PID:'));
    });
  });
}
