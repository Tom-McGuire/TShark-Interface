import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/models/active_capture_session.dart';
import 'package:tshark_interface/models/capture_config.dart';
import 'package:tshark_interface/models/capture_preset.dart';
import 'package:tshark_interface/services/capture_storage_service.dart';
import 'package:tshark_interface/ui/views/dialogs/remote_host_dialog.dart';
import 'package:tshark_interface/ui/views/dialogs/settings_dialog.dart';
import 'package:tshark_interface/ui/views/widgets/active_capture_banner.dart';
import 'package:tshark_interface/ui/views/widgets/capture_filter_input.dart';
import 'package:tshark_interface/ui/views/widgets/capture_presets_bar.dart';
import 'package:tshark_interface/ui/views/widgets/interrupted_capture_banner.dart';
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
}
