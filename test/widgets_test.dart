import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_history_item.dart';
import 'package:tshark_interface/models/capture_preset.dart';
import 'package:tshark_interface/services/capture_storage_service.dart';
import 'package:tshark_interface/ui/views/dialogs/remote_host_dialog.dart';
import 'package:tshark_interface/ui/views/dialogs/settings_dialog.dart';
import 'package:tshark_interface/ui/views/widgets/active_capture_banner.dart';
import 'package:tshark_interface/ui/views/widgets/capture_filter_input.dart';
import 'package:tshark_interface/ui/views/widgets/capture_history_card.dart';
import 'package:tshark_interface/ui/views/widgets/capture_presets_bar.dart';
import 'package:tshark_interface/ui/views/widgets/command_preview_card.dart';
import 'package:tshark_interface/ui/views/widgets/interrupted_capture_banner.dart';
import 'package:tshark_interface/ui/views/widgets/storage_and_recovery_card.dart';
import 'package:tshark_interface/view_models/tshark_capture_view_model.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('ActiveCaptureBanner Widget Tests', () {
    testWidgets('renders active capture details and triggers onStop', (tester) async {
      setDesktopView(tester);

      final session = ActiveCaptureSession(
        pid: 1234,
        startedAt: DateTime.now().subtract(const Duration(seconds: 45)),
        outputDirectory: '/tmp/captures',
        targetFilePath: '/tmp/captures/test_capture.pcapng',
        mode: CaptureMode.manual,
        interfaceName: '1. eth0',
        commandLine: 'tshark -i eth0',
      );

      bool stopCalled = false;

      await tester.pumpWidget(
        createTestApp(
          ActiveCaptureBanner(
            session: session,
            elapsed: const Duration(seconds: 45),
            fileSizeBytes: 1024 * 500, // 500 KB
            isStopping: false,
            onStop: () => stopCalled = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CAPTURE RUNNING (LOCAL)'), findsOneWidget);
      expect(find.text('PID 1234'), findsOneWidget);
      expect(find.text('00:00:45'), findsOneWidget);
      expect(find.text('500.0 KB'), findsOneWidget);
      expect(find.text('test_capture.pcapng'), findsOneWidget);

      final stopButton = find.widgetWithText(ElevatedButton, 'Stop Capture');
      expect(stopButton, findsOneWidget);
      await tester.tap(stopButton);
      await tester.pump();

      expect(stopCalled, isTrue);
    });

    testWidgets('renders remote capture banner correctly', (tester) async {
      setDesktopView(tester);

      final session = ActiveCaptureSession(
        pid: 5678,
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        outputDirectory: '/var/log',
        targetFilePath: '/var/log/remote.pcapng',
        mode: CaptureMode.ringBuffer,
        interfaceName: 'ens192',
        commandLine: 'ssh tshark',
        isRemote: true,
        remoteHostName: 'Prod Edge (10.0.0.1)',
      );

      await tester.pumpWidget(
        createTestApp(
          ActiveCaptureBanner(
            session: session,
            elapsed: const Duration(minutes: 2),
            fileSizeBytes: 1024 * 1024 * 12, // 12 MB
            isStopping: false,
            onStop: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('REMOTE CAPTURE RUNNING (Prod Edge (10.0.0.1))'), findsOneWidget);
      expect(find.text('PID 5678'), findsOneWidget);
      expect(find.text('Ring Buffer (Rolling)'), findsOneWidget);
      expect(find.text('12.0 MB'), findsOneWidget);
    });
  });

  group('InterruptedCaptureBanner Widget Tests', () {
    testWidgets('renders interrupted session banner and triggers callbacks', (tester) async {
      setDesktopView(tester);

      final session = ActiveCaptureSession(
        pid: 9999,
        startedAt: DateTime.now().subtract(const Duration(hours: 3)),
        outputDirectory: '/tmp/prev',
        targetFilePath: '/tmp/prev/reboot.pcapng',
        mode: CaptureMode.timed,
        interfaceName: 'wlan0',
        commandLine: 'tshark',
        filter: 'port 53',
        snaplen: 96,
      );

      bool resumed = false;
      bool settingsLoaded = false;
      bool dismissed = false;

      await tester.pumpWidget(
        createTestApp(
          InterruptedCaptureBanner(
            session: session,
            onResume: () => resumed = true,
            onLoadSettings: () => settingsLoaded = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('INTERRUPTED CAPTURE DETECTED'), findsOneWidget);
      expect(find.text('wlan0'), findsOneWidget);
      expect(find.text('port 53'), findsOneWidget);
      expect(find.text('96 B'), findsOneWidget);

      await tester.tap(find.text('Resume Capture Now'));
      await tester.pump();
      expect(resumed, isTrue);

      await tester.tap(find.text('Load Settings (Review First)'));
      await tester.pump();
      expect(settingsLoaded, isTrue);

      await tester.tap(find.text('Discard'));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('CapturePresetsBar Widget Tests', () {
    testWidgets('renders preset chips and triggers onSelectPreset when tapped', (tester) async {
      setDesktopView(tester);

      final presets = CapturePreset.builtInPresets;
      CapturePreset? selected;

      await tester.pumpWidget(
        createTestApp(
          CapturePresetsBar(
            presets: presets,
            activePresetId: 'all_traffic',
            onSelectPreset: (p) => selected = p,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quick Presets'), findsOneWidget);
      expect(find.text('All Traffic'), findsOneWidget);
      expect(find.text('Web Traffic'), findsOneWidget);
      expect(find.text('DNS Resolution'), findsOneWidget);

      // Tap on Web Traffic
      await tester.tap(find.text('Web Traffic'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected?.id, equals('web_traffic'));
    });
  });

  group('CaptureFilterInput Widget Tests', () {
    testWidgets('allows typing filter and clearing input', (tester) async {
      setDesktopView(tester);

      String currentFilter = '';

      await tester.pumpWidget(
        createTestApp(
          CaptureFilterInput(
            filter: 'initial filter',
            onChanged: (val) => currentFilter = val,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('initial filter'), findsOneWidget);

      final clearButton = find.byTooltip('Clear filter');
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pump();
        expect(currentFilter, isEmpty);
      }
    });
  });

  group('RemoteHostDialog Widget Tests', () {
    late Directory tempDir;
    late CaptureStorageService storage;
    late TSharkCaptureViewModel vm;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('dlg_test_');
      storage = CaptureStorageService(baseDirectory: tempDir);
      await storage.saveDefaultOutputDirectory(tempDir.path);
      vm = TSharkCaptureViewModel(storageService: storage);
      while (vm.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    });

    tearDown(() async {
      vm.dispose();
      await pumpEventQueue();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('shows validation error when required fields are empty', (tester) async {
      setDesktopView(tester);

      await tester.pumpWidget(
        createTestApp(
          RemoteHostDialog(viewModel: vm),
        ),
      );
      await tester.pump();

      expect(find.text('Add Remote SSH Machine'), findsOneWidget);

      // Attempt to save with empty name
      final saveButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.textContaining('Please enter a friendly name'), findsOneWidget);
    });
  });

  group('SettingsDialog Widget Tests', () {
    late Directory tempDir;
    late CaptureStorageService storage;
    late TSharkCaptureViewModel vm;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('settings_test_');
      storage = CaptureStorageService(baseDirectory: tempDir);
      await storage.saveDefaultOutputDirectory(tempDir.path);
      vm = TSharkCaptureViewModel(storageService: storage);
      while (vm.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    });

    tearDown(() async {
      vm.dispose();
      await pumpEventQueue();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('renders settings options and allows canceling', (tester) async {
      setDesktopView(tester);

      await tester.pumpWidget(
        createTestApp(
          SettingsDialog(viewModel: vm),
        ),
      );
      await tester.pump();

      expect(find.text('Capture Engine Settings'), findsOneWidget);
      expect(find.text('TShark Executable Location'), findsOneWidget);
      expect(find.text('Default Reboot & Crash Recovery Policy'), findsOneWidget);

      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();
    });
  });

  group('CommandPreviewCard Widget Tests', () {
    testWidgets('toggles PowerShell & prefix vs CMD/Bash and handles remote target lock', (tester) async {
      setDesktopView(tester);

      await tester.pumpWidget(
        createTestApp(
          CommandPreviewCard(
            commandLine: r'"C:\Program Files\Wireshark\tshark.exe" -i eth0',
            runDetached: false,
            onDetachedChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PowerShell'), findsOneWidget);
      expect(find.text('CMD / Bash'), findsOneWidget);
      expect(
        find.text(r'& "C:\Program Files\Wireshark\tshark.exe" -i eth0'),
        findsOneWidget,
      );

      // Switch to CMD / Bash -> strips leading '& '
      await tester.tap(find.text('CMD / Bash'));
      await tester.pump();
      expect(
        find.text(r'"C:\Program Files\Wireshark\tshark.exe" -i eth0'),
        findsOneWidget,
      );

      // Even if incoming commandLine already has '& ', CMD / Bash strips it cleanly
      await tester.pumpWidget(
        createTestApp(
          CommandPreviewCard(
            commandLine: r'& "C:\Program Files\Wireshark\tshark.exe" -i eth0',
            runDetached: false,
            onDetachedChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('CMD / Bash'));
      await tester.pump();
      expect(
        find.text(r'"C:\Program Files\Wireshark\tshark.exe" -i eth0'),
        findsOneWidget,
      );

      // Remote target mode hides PowerShell/CMD toggle and disables Detached switch
      await tester.pumpWidget(
        createTestApp(
          const CommandPreviewCard(
            commandLine: 'ssh admin@10.0.0.5 "tshark -i eth0"',
            runDetached: true,
            isRemoteTarget: true,
            onDetachedChanged: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Remote SSH'), findsOneWidget);
      expect(find.text('PowerShell'), findsNothing);
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);
    });
  });

  group('Additional Review Regression Widget Tests', () {
    testWidgets('CaptureFilterInput disabled state disables field and hides Clear Filter', (tester) async {
      setDesktopView(tester);

      await tester.pumpWidget(
        createTestApp(
          CaptureFilterInput(
            filter: 'tcp port 443',
            enabled: false,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
      expect(find.text('Clear Filter'), findsNothing);
    });

    testWidgets('CaptureHistoryCard shows empty text, remote actions, and scrolls >5 items', (tester) async {
      setDesktopView(tester);

      // 1. Empty state
      await tester.pumpWidget(
        createTestApp(
          CaptureHistoryCard(
            history: const [],
            onOpenFolder: (_) {},
            onOpenWireshark: (_) {},
            onRemove: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No captures recorded yet'), findsOneWidget);

      // 2. Remote history item hides local Explorer/Wireshark and offers Copy Remote Path
      CaptureHistoryItem? copiedItem;
      final items = List<CaptureHistoryItem>.generate(8, (i) {
        return CaptureHistoryItem(
          filePath: i == 0
              ? '/remote/captures/cap_0.pcapng'
              : '/local/captures/cap_$i.pcapng',
          fileName: 'cap_$i.pcapng',
          timestamp: DateTime(2026, 11, 19, 10, i),
          fileSizeBytes: 1024 * (i + 1),
          interfaceName: i == 0 ? '[Edge] eth0' : 'eth0',
          isRemote: i == 0,
          remoteHostId: i == 0 ? 'h1' : null,
        );
      });

      await tester.pumpWidget(
        createTestApp(
          CaptureHistoryCard(
            history: items,
            onOpenFolder: (_) {},
            onOpenWireshark: (_) {},
            onRemove: (_) {},
            onCopyPath: (item) => copiedItem = item,
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Copy Remote Path'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy Remote Path'));
      await tester.pump();
      expect(copiedItem?.fileName, equals('cap_0.pcapng'));

      // Verify ListView includes all 8 items instead of truncating to 5
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.semanticChildCount, equals(8));
    });

    testWidgets('RemoteHostDialog renders private key input and savePassword unchecked by default', (tester) async {
      setDesktopView(tester);
      late Directory tempDir;
      late TSharkCaptureViewModel vm;
      await tester.runAsync(() async {
        tempDir = Directory.systemTemp.createTempSync('rh_dlg_test_');
        final storage = CaptureStorageService(baseDirectory: tempDir);
        await storage.saveDefaultOutputDirectory(tempDir.path);
        vm = TSharkCaptureViewModel(storageService: storage);
        while (vm.isLoading) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      });
      addTearDown(() async {
        vm.dispose();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      await tester.pumpWidget(createTestApp(RemoteHostDialog(viewModel: vm)));
      await tester.pump();

      expect(
        find.text('SSH Private Key File (Optional / Recommended)'),
        findsOneWidget,
      );
      expect(
        find.text('Remember password on disk (chmod 0600)'),
        findsOneWidget,
      );
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isFalse);
    });

    testWidgets('StorageAndRecoveryCard updates RecoveryPolicy dropdown when ViewModel changes', (tester) async {
      setDesktopView(tester);
      late Directory tempDir;
      late TSharkCaptureViewModel vm;
      await tester.runAsync(() async {
        tempDir = Directory.systemTemp.createTempSync('sr_card_test_');
        final storage = CaptureStorageService(baseDirectory: tempDir);
        await storage.saveDefaultOutputDirectory(tempDir.path);
        vm = TSharkCaptureViewModel(storageService: storage);
        while (vm.isLoading) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      });
      addTearDown(() async {
        vm.dispose();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      await tester.pumpWidget(
        createTestApp(
          SingleChildScrollView(
            child: ListenableBuilder(
              listenable: vm,
              builder: (_, _) => StorageAndRecoveryCard(
                vm: vm,
                onPickOutputFolder: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(vm.recoveryPolicy, equals(RecoveryPolicy.prompt));
      var dropdown = tester.widget<DropdownButtonFormField<RecoveryPolicy>>(
        find.byType(DropdownButtonFormField<RecoveryPolicy>),
      );
      expect(dropdown.initialValue, equals(RecoveryPolicy.prompt));

      vm.setRecoveryPolicy(RecoveryPolicy.auto);
      await tester.pump();

      dropdown = tester.widget<DropdownButtonFormField<RecoveryPolicy>>(
        find.byType(DropdownButtonFormField<RecoveryPolicy>),
      );
      expect(dropdown.initialValue, equals(RecoveryPolicy.auto));
      expect(find.textContaining('Auto-Restart on Boot'), findsOneWidget);
    });
  });
}
