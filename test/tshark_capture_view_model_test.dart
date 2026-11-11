import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_history_item.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/models/remote_host.dart';
import 'package:tshark_interface/services/capture_storage_service.dart';
import 'package:tshark_interface/services/remote_ssh_service.dart';
import 'package:tshark_interface/services/tshark_service.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';

class FakeTSharkService extends TSharkService {
  FakeTSharkService({
    this.fakePath = '/usr/bin/tshark',
    this.fakeVersion = 'TShark (Wireshark) 4.2.0',
    this.fakeInterfaces = const [
      CaptureInterface(index: '1', name: 'eth0', friendlyName: 'Ethernet'),
      CaptureInterface(index: '2', name: 'wlan0', friendlyName: 'Wi-Fi'),
      CaptureInterface(index: '3', name: 'lo', friendlyName: 'Loopback'),
    ],
    this.shouldFailStart = false,
  });

  String? fakePath;
  String? fakeVersion;
  List<CaptureInterface> fakeInterfaces;
  bool shouldFailStart;
  int startCallCount = 0;
  int stopCallCount = 0;

  @override
  Future<String?> findTSharkPath() async => fakePath;

  @override
  Future<String?> getVersion(String tsharkPath) async => fakeVersion;

  @override
  Future<List<CaptureInterface>> getInterfaces(String tsharkPath) async => fakeInterfaces;

  @override
  Future<bool> isProcessAlive(int pid) async => false;

  @override
  Future<int> getCaptureSizeBytes(String filePath) async => 4096;

  @override
  Future<String?> findLatestPcapFile(String directoryPath) async => null;

  @override
  Future<CaptureProcessResult> startCapture({
    required String tsharkPath,
    required CaptureConfig config,
    bool detached = false,
    void Function(int exitCode)? onProcessExit,
  }) async {
    startCallCount++;
    if (shouldFailStart) {
      throw Exception('Mock process start failure');
    }
    return CaptureProcessResult(
      pid: 12345,
      targetDirectory: config.outputDirectory,
      targetFilePath: '${config.outputDirectory}/capture_test.pcapng',
      commandLine: 'tshark -i ${config.interface.name}',
    );
  }

  @override
  Future<bool> stopCapture(int pid) async {
    stopCallCount++;
    return true;
  }
}

class FakeRemoteSshService extends RemoteSshService {
  FakeRemoteSshService() : super(tsharkService: FakeTSharkService());

  List<CaptureInterface> remoteInterfaces = const [
    CaptureInterface(index: '1', name: 'eth0', friendlyName: 'Remote Eth0'),
  ];

  @override
  Future<List<CaptureInterface>> getRemoteInterfaces(RemoteHost host) async {
    return remoteInterfaces;
  }

  @override
  Future<CaptureProcessResult> startRemoteCapture({
    required RemoteHost host,
    required CaptureConfig config,
  }) async {
    return CaptureProcessResult(
      pid: 9988,
      targetDirectory: config.outputDirectory,
      targetFilePath: '${config.outputDirectory}/remote_capture.pcapng',
      commandLine: 'ssh tshark',
    );
  }

  @override
  Future<bool> stopRemoteCapture(RemoteHost host, int pid) async => true;

  @override
  Future<RemoteSessionCheckResult> checkRemoteSessionStatus(
    RemoteHost host,
    ActiveCaptureSession session,
  ) async {
    return const RemoteSessionCheckResult(
      isReachable: true,
      isAlive: true,
      sizeBytes: 1024,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TSharkCaptureViewModel Tests', () {
    late Directory tempDir;
    late CaptureStorageService storageService;
    late FakeTSharkService tsharkService;
    late FakeRemoteSshService remoteSshService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_test_');
      storageService = CaptureStorageService(baseDirectory: tempDir);
      await storageService.saveDefaultOutputDirectory(tempDir.path);
      tsharkService = FakeTSharkService();
      remoteSshService = FakeRemoteSshService();
    });

    tearDown(() async {
      await pumpEventQueue();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<TSharkCaptureViewModel> createViewModel({
      TSharkService? tshark,
      CaptureStorageService? storage,
      RemoteSshService? remoteSsh,
    }) async {
      final vm = TSharkCaptureViewModel(
        tsharkService: tshark ?? tsharkService,
        storageService: storage ?? storageService,
        remoteSshService: remoteSsh ?? remoteSshService,
      );
      while (vm.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return vm;
    }

    test('Initializes correctly and selects preferred interface (Wi-Fi or Ethernet)', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      expect(vm.isLoading, isFalse);
      expect(vm.hasTShark, isTrue);
      expect(vm.hasLocalTShark, isTrue);
      expect(vm.tsharkPath, equals('/usr/bin/tshark'));
      expect(vm.tsharkVersion, equals('TShark (Wireshark) 4.2.0'));
      expect(vm.interfaces.length, equals(3));
      expect(vm.selectedInterface?.friendlyName, anyOf(equals('Wi-Fi'), equals('Ethernet')));
      expect(vm.presets, isNotEmpty);
      expect(vm.activePresetId, equals('all_traffic'));
      expect(vm.errorMessage, isNull);
    });

    test('Configuration setters update state and clamp within allowed ranges', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      vm.setMode(CaptureMode.timed);
      expect(vm.mode, equals(CaptureMode.timed));

      vm.setDurationMinutes(30);
      expect(vm.durationMinutes, equals(30));
      vm.setDurationMinutes(9999);
      expect(vm.durationMinutes, equals(1440));
      vm.setDurationMinutes(-5);
      expect(vm.durationMinutes, equals(1));

      vm.setDurationHours(5);
      expect(vm.durationHours, equals(5));
      vm.setDurationHours(500);
      expect(vm.durationHours, equals(168));

      vm.setPacketCountLimit(5000);
      expect(vm.packetCountLimit, equals(5000));
      vm.setPacketCountLimit(5);
      expect(vm.packetCountLimit, equals(10));

      vm.setRingRotateMinutes(20);
      expect(vm.ringRotateMinutes, equals(20));

      vm.setRingRotateFilesizeMb(200);
      expect(vm.ringRotateFilesizeMb, equals(200));

      vm.setRingFilesCount(15);
      expect(vm.ringFilesCount, equals(15));

      vm.setRingRotateBySize(true);
      expect(vm.ringRotateBySize, isTrue);

      vm.setSnaplen(128);
      expect(vm.snaplen, equals(128));

      vm.setPromiscuous(false);
      expect(vm.promiscuous, isFalse);

      vm.setFilePrefix('my_dump');
      expect(vm.filePrefix, equals('my_dump'));

      vm.setCreateSubfolder(false);
      expect(vm.createSubfolder, isFalse);

      vm.setRunDetached(true);
      expect(vm.runDetached, isTrue);
    });

    test('Applying presets updates filter and mode, while custom edit clears activePresetId', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      final webPreset = vm.presets.firstWhere((p) => p.id == 'web_traffic');
      vm.applyPreset(webPreset);

      expect(vm.activePresetId, equals('web_traffic'));
      expect(vm.captureFilter, equals(webPreset.filter));

      vm.setCaptureFilter('tcp port 8080');
      expect(vm.captureFilter, equals('tcp port 8080'));
      expect(vm.activePresetId, isNull);
    });

    test('Target host switching between local and remote targets', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      const host = RemoteHost(
        id: 'host_test',
        name: 'Remote Server',
        host: '10.0.0.5',
        username: 'admin',
        defaultOutputDirectory: '/remote/captures',
      );

      await vm.saveRemoteHost(host);
      expect(vm.remoteHosts.length, equals(1));

      await vm.selectTargetHost(host);
      expect(vm.isRemoteTarget, isTrue);
      expect(vm.selectedRemoteHost?.name, equals('Remote Server'));
      expect(vm.outputDirectory, equals('/remote/captures'));
      expect(vm.selectedInterface?.name, equals('eth0'));

      await vm.selectTargetHost(null);
      expect(vm.isRemoteTarget, isFalse);
      expect(vm.selectedRemoteHost, isNull);
    });

    test('Deleting a remote host switches target to local if currently selected', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      const host = RemoteHost(
        id: 'host_to_delete',
        name: 'Temp Host',
        host: '10.0.0.99',
        username: 'admin',
      );
      await vm.saveRemoteHost(host);
      await vm.selectTargetHost(host);
      expect(vm.isRemoteTarget, isTrue);

      await vm.deleteRemoteHost('host_to_delete');
      expect(vm.isRemoteTarget, isFalse);
      expect(vm.remoteHosts.any((h) => h.id == 'host_to_delete'), isFalse);
    });

    test('startCapture validates missing interface, missing directory, and missing tshark', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      // 1. Missing interface
      vm.setSelectedInterface(null);
      vm.setOutputDirectory(tempDir.path);
      var started = await vm.startCapture();
      expect(started, isFalse);
      expect(vm.errorMessage, contains('choose a network interface'));

      // 2. Missing output directory
      vm.setSelectedInterface(const CaptureInterface(index: '1', name: 'eth0'));
      vm.setOutputDirectory('');
      started = await vm.startCapture();
      expect(started, isFalse);
      expect(vm.errorMessage, contains('destination storage directory'));

      // 3. Missing local tshark
      final noTsharkService = FakeTSharkService(fakePath: null);
      final noTsharkVm = await createViewModel(tshark: noTsharkService);
      addTearDown(() => noTsharkVm.dispose());

      noTsharkVm.setSelectedInterface(const CaptureInterface(index: '1', name: 'eth0'));
      noTsharkVm.setOutputDirectory(tempDir.path);
      started = await noTsharkVm.startCapture();
      expect(started, isFalse);
      expect(noTsharkVm.errorMessage, contains('not detected'));
    });

    test('startCapture and stopCapture successfully manage active capture state and history', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      vm.setSelectedInterface(const CaptureInterface(index: '1', name: 'eth0', friendlyName: 'Ethernet'));
      vm.setOutputDirectory(tempDir.path);

      expect(vm.isCapturing, isFalse);
      final started = await vm.startCapture();
      expect(started, isTrue);
      expect(vm.isCapturing, isTrue);
      expect(vm.activeSession?.pid, equals(12345));
      expect(tsharkService.startCallCount, equals(1));

      await vm.stopCapture();
      expect(vm.isCapturing, isFalse);
      expect(tsharkService.stopCallCount, equals(1));
      expect(vm.statusMessage, contains('saved successfully'));
      expect(vm.history.length, equals(1));
      expect(vm.history.first.fileName, equals('capture_test.pcapng'));
    });

    test('Handling interrupted session recovery (dismiss and load settings)', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      const iface = CaptureInterface(index: '1', name: 'eth0');
      const interruptedConfig = CaptureConfig(
        interface: iface,
        outputDirectory: '/captures/prev',
        captureFilter: 'udp port 53',
        mode: CaptureMode.timed,
        durationMinutes: 45,
      );
      final session = ActiveCaptureSession(
        pid: 7777,
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        outputDirectory: '/captures/prev',
        targetFilePath: '/captures/prev/dns.pcapng',
        mode: CaptureMode.timed,
        interfaceName: 'eth0',
        commandLine: 'tshark',
        config: interruptedConfig,
        recoveryPolicy: RecoveryPolicy.prompt,
      );

      await storageService.saveActiveSession(session);
      await vm.checkExistingSession();
      expect(vm.interruptedSession, isNotNull);
      expect(vm.interruptedSession?.pid, equals(7777));

      vm.loadInterruptedSettings();
      expect(vm.interruptedSession, isNull);
      expect(vm.captureFilter, equals('udp port 53'));
      expect(vm.durationMinutes, equals(45));
      expect(vm.outputDirectory, equals('/captures/prev'));

      await storageService.saveActiveSession(session);
      await vm.checkExistingSession();
      expect(vm.interruptedSession, isNotNull);
      vm.dismissInterruptedSession();
      expect(vm.interruptedSession, isNull);
    });

    test('History management: removeHistoryItem deletes item from history', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      final item = CaptureHistoryItem(
        filePath: '${tempDir.path}/item1.pcapng',
        fileName: 'item1.pcapng',
        timestamp: DateTime.now(),
        fileSizeBytes: 2048,
        interfaceName: 'eth0',
      );
      await storageService.addHistoryItem(item);
      final reloaded = await storageService.loadHistory();
      expect(reloaded.length, equals(1));

      await vm.init();
      expect(vm.history.length, equals(1));

      await vm.removeHistoryItem(vm.history.first);
      expect(vm.history, isEmpty);
    });

    test('Helper formatting functions', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      expect(vm.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), equals('01:02:03'));
      expect(vm.formatDuration(const Duration(minutes: 5, seconds: 9)), equals('00:05:09'));

      expect(vm.formatBytes(500), equals('500 B'));
      expect(vm.formatBytes(2048), equals('2.0 KB'));
      expect(vm.formatBytes(1024 * 1024 * 5), equals('5.0 MB'));
      expect(vm.formatBytes(1024 * 1024 * 1024 * 2), equals('2.00 GB'));

      vm.clearError();
      expect(vm.errorMessage, isNull);
      vm.clearStatus();
      expect(vm.statusMessage, isNull);
    });

    test('previewCommandLine generates properly formatted strings or informational comments', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      vm.setSelectedInterface(null);
      expect(vm.previewCommandLine, contains('# Select a capture interface'));

      vm.setSelectedInterface(const CaptureInterface(index: '1', name: 'eth0'));
      vm.setOutputDirectory('/var/log/captures');
      expect(vm.previewCommandLine, contains('-i eth0'));
      expect(vm.previewCommandLine, contains('-w '));
    });

    test('loadDemoWalkthroughData loads demo preset and packets, and clearCapture resets state', () async {
      final vm = await createViewModel();
      addTearDown(() => vm.dispose());

      expect(vm.isDemoMode, isFalse);
      expect(vm.demoPackets, isEmpty);
      expect(vm.selectedDemoPacket, isNull);

      vm.loadDemoWalkthroughData();
      expect(vm.isDemoMode, isTrue);
      expect(vm.activePresetId, equals('web_traffic'));
      expect(vm.captureFilter, isNotEmpty);
      expect(vm.demoPackets, isNotEmpty);
      expect(vm.selectedDemoPacket, equals(vm.demoPackets.first));

      // Selecting another packet updates selectedDemoPacket
      vm.selectDemoPacket(vm.demoPackets.last);
      expect(vm.selectedDemoPacket, equals(vm.demoPackets.last));

      // Clearing capture resets demo mode, packets, and filter
      vm.clearCapture();
      expect(vm.isDemoMode, isFalse);
      expect(vm.demoPackets, isEmpty);
      expect(vm.selectedDemoPacket, isNull);
      expect(vm.captureFilter, isEmpty);
      expect(vm.activePresetId, equals('all_traffic'));
    });
  });
}
