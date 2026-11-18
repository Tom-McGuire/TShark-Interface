import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_interface.dart';
import 'package:tshark_interface/models/launch_adapter_config.dart';
import 'package:tshark_interface/models/remote_host.dart';
import 'package:tshark_interface/services/capture_storage_service.dart';
import 'package:tshark_interface/services/remote_ssh_service.dart';
import 'package:tshark_interface/services/tshark_service.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';

class _FakeTSharkService extends TSharkService {
  _FakeTSharkService({
    this.fakePath = '/usr/bin/tshark',
    this.fakeInterfaces = const [],
    this.fakeHostIpv4Map = const {},
  });

  final String? fakePath;
  List<CaptureInterface> fakeInterfaces;
  Map<String, List<String>> fakeHostIpv4Map;

  @override
  Future<String?> findTSharkPath() async => fakePath;

  @override
  Future<String?> getVersion(String tsharkPath) async =>
      'TShark (Wireshark) 4.2.0';

  @override
  Future<List<CaptureInterface>> getInterfaces(String tsharkPath) async =>
      fakeInterfaces;

  @override
  Future<Map<String, List<String>>> fetchHostIpv4Map() async => fakeHostIpv4Map;

  @override
  Future<bool> isProcessAlive(int pid) async => false;

  @override
  Future<int> getCaptureSizeBytes(String filePath) async => 0;

  @override
  Future<String?> findLatestPcapFile(String dirPath) async => null;
}

class _FakeRemoteSshService extends RemoteSshService {
  _FakeRemoteSshService() : super(tsharkService: _FakeTSharkService());

  @override
  Future<List<CaptureInterface>> getRemoteInterfaces(RemoteHost host) async =>
      const [
        CaptureInterface(index: '1', name: 'eth0', friendlyName: 'Remote Eth0'),
      ];

  @override
  Future<RemoteSessionCheckResult> checkRemoteSessionStatus(
    RemoteHost host,
    ActiveCaptureSession session,
  ) async {
    return const RemoteSessionCheckResult(
      isReachable: true,
      isAlive: false,
      sizeBytes: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LaunchAdapterConfig.fromArgs', () {
    test('parses space-separated --adapter-ip and --adapter-name flags', () {
      final config = LaunchAdapterConfig.fromArgs([
        '--adapter-ip',
        '192.168.1.50',
        '--adapter-name',
        'eth0',
      ]);

      expect(config.adapterIp, equals('192.168.1.50'));
      expect(config.adapterName, equals('eth0'));
      expect(config.hasAdapterOverride, isTrue);
      expect(config.hasOverride, isTrue);
    });

    test('parses equals-separated --adapter-ip= and --adapter-name= flags', () {
      final config = LaunchAdapterConfig.fromArgs([
        '--adapter-ip=10.0.0.5',
        '--adapter-name=Ethernet',
      ]);

      expect(config.adapterIp, equals('10.0.0.5'));
      expect(config.adapterName, equals('Ethernet'));
      expect(config.hasAdapterOverride, isTrue);
      expect(config.hasOverride, isTrue);
    });

    test('trims whitespace and treats empty values as null', () {
      final trimmed = LaunchAdapterConfig.fromArgs([
        '--adapter-ip',
        '  172.16.0.10  ',
        '--adapter-name=  Wi-Fi 2  ',
      ]);
      expect(trimmed.adapterIp, equals('172.16.0.10'));
      expect(trimmed.adapterName, equals('Wi-Fi 2'));
      expect(trimmed.hasAdapterOverride, isTrue);

      final empty = LaunchAdapterConfig.fromArgs([
        '--adapter-ip',
        '   ',
        '--adapter-name=',
      ]);
      expect(empty.adapterIp, isNull);
      expect(empty.adapterName, isNull);
      expect(empty.hasAdapterOverride, isFalse);
      expect(empty.hasOverride, isFalse);
    });

    test('ignores missing or unknown flags and trailing flag without value', () {
      final unknown = LaunchAdapterConfig.fromArgs([
        '--foo',
        'bar',
        '--verbose',
      ]);
      expect(unknown.adapterIp, isNull);
      expect(unknown.adapterName, isNull);
      expect(unknown.hasAdapterOverride, isFalse);
      expect(unknown.hasOverride, isFalse);

      final trailing = LaunchAdapterConfig.fromArgs(['--adapter-ip']);
      expect(trailing.adapterIp, isNull);
      expect(trailing.hasAdapterOverride, isFalse);
    });
  });

  group('CaptureInterface ipv4Addresses & TSharkService enrichment', () {
    test('CaptureInterface serializes and deserializes ipv4Addresses cleanly', () {
      const iface = CaptureInterface(
        index: '1',
        name: r'\Device\NPF_{1234}',
        friendlyName: 'Wi-Fi',
        ipv4Addresses: ['192.168.1.50', '10.0.0.2'],
      );

      final json = iface.toJson();
      expect(json['ipv4Addresses'], equals(['192.168.1.50', '10.0.0.2']));

      final decoded = CaptureInterface.fromJson(json);
      expect(decoded.ipv4Addresses, equals(['192.168.1.50', '10.0.0.2']));
      expect(decoded, equals(iface));

      final legacyDecoded = CaptureInterface.fromJson(const {
        'index': '2',
        'name': 'eth0',
      });
      expect(legacyDecoded.ipv4Addresses, isEmpty);
    });

    test('enrichInterfacesWithIpv4 matches name and friendlyName case-insensitively', () {
      final parsed = TSharkService.parseInterfacesOutput('''
1. \\Device\\NPF_{AAA} (Wi-Fi)
2. eth0
3. \\Device\\NPF_{BBB} (Local Area Connection* 1)
''');

      final enriched = TSharkService.enrichInterfacesWithIpv4(parsed, {
        'wi-fi': ['192.168.1.50'],
        'ETH0': ['10.0.0.15'],
        'Local Area Connection 1': ['172.16.5.4'],
      });

      expect(enriched[0].ipv4Addresses, equals(['192.168.1.50']));
      expect(enriched[1].ipv4Addresses, equals(['10.0.0.15']));
      expect(enriched[2].ipv4Addresses, equals(['172.16.5.4']));
    });

    test('getHostIpv4Map returns a valid map without throwing', () async {
      final hostMap = await TSharkService.getHostIpv4Map();
      expect(hostMap, isA<Map<String, List<String>>>());
    });
  });

  group('TSharkCaptureViewModel.matchLaunchAdapter', () {
    const npfWifi = CaptureInterface(
      index: '1',
      name: r'\Device\NPF_{1111}',
      friendlyName: 'Wi-Fi',
      ipv4Addresses: ['192.168.1.50'],
    );
    const npfEth = CaptureInterface(
      index: '2',
      name: r'\Device\NPF_{2222}',
      friendlyName: 'Ethernet',
      ipv4Addresses: ['10.0.0.5'],
    );
    const eth2 = CaptureInterface(
      index: '3',
      name: 'eth2',
      friendlyName: 'Ethernet 2',
      description: 'Management IP 172.16.10.9',
    );
    const available = [eth2, npfEth, npfWifi];

    test('Priority 1: IPv4 match in CaptureInterface.ipv4Addresses wins over conflicting name', () {
      const config = LaunchAdapterConfig(
        adapterIp: '192.168.1.50',
        adapterName: 'Ethernet',
      );

      final match = TSharkCaptureViewModel.matchLaunchAdapter(available, config);
      expect(match, equals(npfWifi));
    });

    test('Priority 1: IPv4 match via description token or interface name works', () {
      const descConfig = LaunchAdapterConfig(
        adapterIp: '172.16.10.9',
        adapterName: 'Wi-Fi',
      );
      expect(
        TSharkCaptureViewModel.matchLaunchAdapter(available, descConfig),
        equals(eth2),
      );
    });

    test('Priority 1: osInterfaceIps mapping resolves Windows NPF GUIDs even without ipv4Addresses', () {
      const npfOnlyWifi = CaptureInterface(
        index: '1',
        name: r'\Device\NPF_{AAAA}',
        friendlyName: 'Wi-Fi (Intel AX201)',
      );
      const npfOnlyEth = CaptureInterface(
        index: '2',
        name: r'\Device\NPF_{BBBB}',
        friendlyName: 'Ethernet',
      );

      const config = LaunchAdapterConfig(
        adapterIp: '192.168.50.12',
        adapterName: 'Ethernet',
      );

      final match = TSharkCaptureViewModel.matchLaunchAdapter(
        const [npfOnlyEth, npfOnlyWifi],
        config,
        osInterfaceIps: const {
          'Ethernet': ['10.0.0.2'],
          'Wi-Fi': ['192.168.50.12'],
        },
      );
      expect(match, equals(npfOnlyWifi));
    });

    test('Priority 2: case-insensitive exact match on friendlyName or name wins over substring', () {
      const exactFriendly = LaunchAdapterConfig(
        adapterIp: '203.0.113.99', // non-matching IP falls back to name
        adapterName: 'ethernet',
      );
      expect(
        TSharkCaptureViewModel.matchLaunchAdapter(available, exactFriendly),
        equals(npfEth),
      );

      const exactName = LaunchAdapterConfig(adapterName: 'ETH2');
      expect(
        TSharkCaptureViewModel.matchLaunchAdapter(available, exactName),
        equals(eth2),
      );
    });

    test('Priority 2: case-insensitive substring match on name, friendlyName, or displayName', () {
      const usbAdapter = CaptureInterface(
        index: '4',
        name: 'enx00e04c680123',
        friendlyName: 'Realtek USB GbE Family Controller',
      );

      const subFriendly = LaunchAdapterConfig(adapterName: 'usb gbe');
      expect(
        TSharkCaptureViewModel.matchLaunchAdapter(
          [...available, usbAdapter],
          subFriendly,
        ),
        equals(usbAdapter),
      );

      const subName = LaunchAdapterConfig(adapterName: '00e04c');
      expect(
        TSharkCaptureViewModel.matchLaunchAdapter(
          [...available, usbAdapter],
          subName,
        ),
        equals(usbAdapter),
      );
    });

    test('Priority 3: returns null when neither IP nor name matches', () {
      const unmatched = LaunchAdapterConfig(
        adapterIp: '198.51.100.42',
        adapterName: 'nonexistent0',
      );
      expect(
        TSharkCaptureViewModel.matchLaunchAdapter(available, unmatched),
        isNull,
      );
    });
  });

  group('TSharkCaptureViewModel startup adapter pre-selection integration', () {
    late Directory tempDir;
    late CaptureStorageService storageService;
    late _FakeRemoteSshService remoteSshService;

    const eth0 = CaptureInterface(
      index: '1',
      name: 'eth0',
      friendlyName: 'Ethernet',
      ipv4Addresses: ['10.0.0.5'],
    );
    const wlan0 = CaptureInterface(
      index: '2',
      name: 'wlan0',
      friendlyName: 'Wi-Fi',
      ipv4Addresses: ['192.168.1.50'],
    );
    const usb0 = CaptureInterface(
      index: '3',
      name: 'usb0',
      friendlyName: 'USB Tether',
      ipv4Addresses: ['172.20.10.2'],
    );

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('launch_adapter_vm_');
      storageService = CaptureStorageService(baseDirectory: tempDir);
      await storageService.saveDefaultOutputDirectory(tempDir.path);
      remoteSshService = _FakeRemoteSshService();
    });

    tearDown(() async {
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<TSharkCaptureViewModel> createViewModel({
      required _FakeTSharkService tshark,
      LaunchAdapterConfig? initialAdapterConfig,
    }) async {
      final vm = TSharkCaptureViewModel(
        tsharkService: tshark,
        storageService: storageService,
        remoteSshService: remoteSshService,
        initialAdapterConfig: initialAdapterConfig,
      );
      while (vm.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return vm;
    }

    test('Priority 1: selects IP-matched adapter on startup even over saved interface and conflicting name', () async {
      await storageService.saveLastInterfaceName('eth0');
      final tshark = _FakeTSharkService(
        fakeInterfaces: const [eth0, wlan0, usb0],
      );

      final vm = await createViewModel(
        tshark: tshark,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterIp: '172.20.10.2',
          adapterName: 'Ethernet',
        ),
      );
      addTearDown(vm.dispose);

      expect(vm.selectedInterface, equals(usb0));
    });

    test('Priority 1: uses fetchHostIpv4Map when CaptureInterface.ipv4Addresses does not contain targetIp', () async {
      const npfEth = CaptureInterface(
        index: '1',
        name: r'\Device\NPF_{111}',
        friendlyName: 'Ethernet',
      );
      const npfUsb = CaptureInterface(
        index: '2',
        name: r'\Device\NPF_{222}',
        friendlyName: 'USB NIC',
      );
      final tshark = _FakeTSharkService(
        fakeInterfaces: const [npfEth, npfUsb],
        fakeHostIpv4Map: const {
          'Ethernet': ['10.0.0.5'],
          'USB NIC': ['192.168.77.88'],
        },
      );

      final vm = await createViewModel(
        tshark: tshark,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterIp: '192.168.77.88',
          adapterName: 'Ethernet',
        ),
      );
      addTearDown(vm.dispose);

      expect(vm.selectedInterface, equals(npfUsb));
    });

    test('Priority 2: selects adapter by name when IP does not match', () async {
      final tshark = _FakeTSharkService(
        fakeInterfaces: const [eth0, wlan0, usb0],
      );

      final vm = await createViewModel(
        tshark: tshark,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterIp: '203.0.113.10',
          adapterName: 'tether',
        ),
      );
      addTearDown(vm.dispose);

      expect(vm.selectedInterface, equals(usb0));
    });

    test('Priority 3: falls back to saved/preferred default interface when CLI config does not match', () async {
      await storageService.saveLastInterfaceName('eth0');
      final tshark = _FakeTSharkService(
        fakeInterfaces: const [wlan0, eth0, usb0],
      );

      final vm = await createViewModel(
        tshark: tshark,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterIp: '198.51.100.7',
          adapterName: 'missing0',
        ),
      );
      addTearDown(vm.dispose);

      expect(vm.selectedInterface, equals(eth0));
    });

    test('One-time override: manual interface selection is preserved across refreshInterfaces and host switches', () async {
      await storageService.saveLastInterfaceName('eth0');
      final tshark = _FakeTSharkService(
        fakeInterfaces: const [eth0, wlan0, usb0],
      );

      final vm = await createViewModel(
        tshark: tshark,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterIp: '172.20.10.2',
          adapterName: 'USB Tether',
        ),
      );
      addTearDown(vm.dispose);

      // Initial CLI override applied once
      expect(vm.selectedInterface, equals(usb0));

      // User manually switches to wlan0
      vm.setSelectedInterface(wlan0);
      expect(vm.selectedInterface, equals(wlan0));

      // Subsequent refreshInterfaces preserves manual choice
      await vm.refreshInterfaces();
      expect(vm.selectedInterface, equals(wlan0));

      // Switching to remote host and back to local does not re-apply CLI override
      const remoteHost = RemoteHost(
        id: 'remote_1',
        name: 'Lab Box',
        host: '10.10.10.1',
        username: 'tester',
      );
      await vm.saveRemoteHost(remoteHost);
      await vm.selectTargetHost(remoteHost);
      expect(vm.isRemoteTarget, isTrue);

      await vm.selectTargetHost(null);
      expect(vm.isRemoteTarget, isFalse);
      expect(vm.selectedInterface, equals(wlan0));
    });

    test('One-time override: switching target host and back does not re-apply CLI override even without manual change', () async {
      await storageService.saveLastInterfaceName('eth0');
      final tshark = _FakeTSharkService(
        fakeInterfaces: const [eth0, wlan0, usb0],
      );

      final vm = await createViewModel(
        tshark: tshark,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterIp: '172.20.10.2',
        ),
      );
      addTearDown(vm.dispose);

      expect(vm.selectedInterface, equals(usb0));

      const remoteHost = RemoteHost(
        id: 'remote_2',
        name: 'Edge Box',
        host: '10.10.10.2',
        username: 'tester',
      );
      await vm.saveRemoteHost(remoteHost);
      await vm.selectTargetHost(remoteHost);
      await vm.selectTargetHost(null);

      // Falls back to saved local preference (eth0), NOT CLI override (usb0)
      expect(vm.selectedInterface, equals(eth0));
    });

    test('Handles missing TShark on startup gracefully even with initialAdapterConfig', () async {
      final tshark = _FakeTSharkService(fakePath: null);
      final vm = await createViewModel(
        tshark: tshark,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterIp: '172.20.10.2',
          adapterName: 'usb0',
        ),
      );
      addTearDown(vm.dispose);

      expect(vm.hasLocalTShark, isFalse);
      expect(vm.interfaces, isEmpty);
      expect(vm.selectedInterface, isNull);
    });
  });
}
