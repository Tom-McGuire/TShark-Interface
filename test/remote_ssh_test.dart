import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/models/remote_host.dart';
import 'package:tshark_interface/services/capture_storage_service.dart';
import 'package:tshark_interface/services/remote_ssh_service.dart';
import 'package:tshark_interface/services/tshark_service.dart';

void main() {
  group('Remote SSH Capture & Persistence Tests', () {
    test('RemoteHost serializes and deserializes accurately when savePassword is true', () {
      const host = RemoteHost(
        id: 'host_1',
        name: 'Edge Router',
        host: '192.168.10.1',
        port: 2222,
        username: 'netadmin',
        password: 'secret_password',
        privateKeyPath: '/home/netadmin/.ssh/id_ed25519',
        savePassword: true,
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
      expect(decoded.privateKeyPath, equals('/home/netadmin/.ssh/id_ed25519'));
      expect(decoded.savePassword, isTrue);
      expect(decoded.defaultOutputDirectory, equals('/var/captures'));
      expect(decoded.useSudo, isTrue);
      expect(decoded.osType, equals(RemoteOsType.linux));
      expect(decoded.detectedTSharkVersion, equals('TShark (Wireshark) 4.2.5'));
      expect(decoded.displayLabel, equals('Edge Router (192.168.10.1:2222)'));
    });

    test('RemoteHost omits plaintext password when savePassword is false and supports legacy JSON', () {
      const ephemeralHost = RemoteHost(
        id: 'host_ephem',
        name: 'Session Host',
        host: '10.0.0.5',
        username: 'ops',
        password: 'ephemeral_password',
      );

      final json = ephemeralHost.toJson();
      expect(json['savePassword'], isFalse);
      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('privateKeyPath'), isFalse);

      final decoded = RemoteHost.fromJson(json);
      expect(decoded.password, isEmpty);
      expect(decoded.savePassword, isFalse);
      expect(decoded.privateKeyPath, isNull);

      // Legacy saved profile without explicit savePassword key
      final legacyDecoded = RemoteHost.fromJson({
        'id': 'host_legacy',
        'name': 'Legacy',
        'host': '10.0.0.6',
        'username': 'root',
        'password': 'legacy_secret',
      });
      expect(legacyDecoded.password, equals('legacy_secret'));
      expect(legacyDecoded.savePassword, isTrue);
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

    test('RemoteSshService.expandKeyPath expands tilde prefixes and trims whitespace', () {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
      final expandedUnix = RemoteSshService.expandKeyPath('  ~/.ssh/id_ed25519  ');
      if (home.isNotEmpty) {
        expect(expandedUnix, endsWith('/.ssh/id_ed25519'));
        expect(expandedUnix.startsWith('~'), isFalse);
      }

      final expandedWin = RemoteSshService.expandKeyPath(r'~\.ssh\id_rsa');
      if (home.isNotEmpty) {
        expect(expandedWin, endsWith(r'\.ssh\id_rsa'));
        expect(expandedWin.startsWith('~'), isFalse);
      }

      expect(
        RemoteSshService.expandKeyPath('  /etc/ssh/custom_key  '),
        equals('/etc/ssh/custom_key'),
      );
    });

    test('RemoteSshService.buildRemoteDisplayCommandLine safely quotes binary, filters, output, and special chars', () {
      final service = RemoteSshService();

      const linuxHost = RemoteHost(
        id: 'h_lin',
        name: 'Linux Probe',
        host: '10.1.1.2',
        username: 'netops',
        customTSharkPath: '/opt/my tools/tshark',
        useSudo: true,
        osType: RemoteOsType.linux,
      );
      const linuxConfig = CaptureConfig(
        interface: CaptureInterface(index: '1', name: 'eth0'),
        outputDirectory: '/var/captures',
        captureFilter: r'tcp[tcpflags]&(tcp-syn|tcp-fin)!=0',
      );
      final linuxPreview = service.buildRemoteDisplayCommandLine(
        host: linuxHost,
        config: linuxConfig,
        fullRemoteOutputPath: '/var/captures/cap.pcapng',
      );
      expect(
        linuxPreview,
        contains(r'''sudo '/opt/my tools/tshark' '''),
      );
      expect(
        linuxPreview,
        contains(r'''-f 'tcp[tcpflags]&(tcp-syn|tcp-fin)!=0' '''),
      );
      expect(linuxPreview, contains("-w '/var/captures/cap.pcapng'"));

      // Filter containing double quotes and dollar sign inside outer ssh "..."
      const specialConfig = CaptureConfig(
        interface: CaptureInterface(index: '1', name: 'eth0'),
        outputDirectory: '/var/captures',
        captureFilter: r'tcp contains "foo$bar"',
      );
      final specialPreview = service.buildRemoteDisplayCommandLine(
        host: linuxHost,
        config: specialConfig,
        fullRemoteOutputPath: '/var/captures/cap.pcapng',
      );
      expect(specialPreview, contains(r'\"foo\$bar\"'));

      // Windows host binary quoting
      const winHost = RemoteHost(
        id: 'h_win',
        name: 'Win Probe',
        host: '10.1.1.3',
        username: 'admin',
        osType: RemoteOsType.windows,
      );
      const winConfig = CaptureConfig(
        interface: CaptureInterface(index: '1', name: r'\Device\NPF_{123}'),
        outputDirectory: r'C:\Temp',
        captureFilter: 'port80',
      );
      final winPreview = service.buildRemoteDisplayCommandLine(
        host: winHost,
        config: winConfig,
        fullRemoteOutputPath: r'C:\Temp\cap.pcapng',
      );
      expect(winPreview, contains(r"'C:\Program Files\Wireshark\tshark.exe'"));
      expect(winPreview, contains("-f 'port80'"));
      expect(winPreview, contains(r"-w 'C:\Temp\cap.pcapng'"));
    });

    test('RemoteSshService.buildWindowsExecCommand wraps command in PowerShell call operator', () {
      final cmd = RemoteSshService.buildWindowsExecCommand(
        r'C:\Program Files\Wireshark\tshark.exe',
        ['-D'],
      );
      expect(
        cmd,
        equals(
          'powershell -NoProfile -NonInteractive -Command "& \'C:\\Program Files\\Wireshark\\tshark.exe\' \'-D\'"',
        ),
      );
    });

    test('RemoteSshService.buildWindowsStatusCommand checks targetFilePath for manual mode and outputDirectory for ringBuffer', () {
      final manualSession = ActiveCaptureSession(
        pid: 4242,
        startedAt: DateTime(2026, 1, 1),
        outputDirectory: r'C:\Temp\TSharkCaptures',
        targetFilePath: r'C:\Temp\TSharkCaptures\cap_1.pcapng',
        mode: CaptureMode.manual,
        interfaceName: 'Ethernet',
        commandLine: 'tshark',
      );
      final manualCmd = RemoteSshService.buildWindowsStatusCommand(manualSession);
      expect(manualCmd, contains(r"Test-Path 'C:\Temp\TSharkCaptures\cap_1.pcapng'"));
      expect(manualCmd, contains('Get-Item'));
      expect(manualCmd, isNot(contains('Get-ChildItem')));

      final ringSession = ActiveCaptureSession(
        pid: 4243,
        startedAt: DateTime(2026, 1, 1),
        outputDirectory: r'C:\Temp\TSharkCaptures\Capture_1',
        targetFilePath: r'C:\Temp\TSharkCaptures\Capture_1\cap.pcapng',
        mode: CaptureMode.ringBuffer,
        interfaceName: 'Ethernet',
        commandLine: 'tshark',
      );
      final ringCmd = RemoteSshService.buildWindowsStatusCommand(ringSession);
      expect(ringCmd, contains(r"Test-Path 'C:\Temp\TSharkCaptures\Capture_1'"));
      expect(ringCmd, contains('Get-ChildItem'));
      expect(ringCmd, contains('Measure-Object -Property Length -Sum'));
    });
  });
}
