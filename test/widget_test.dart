import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tshark_interface/main.dart';
import 'package:tshark_interface/services/shared_device_database.dart';
import 'package:tshark_interface/ui/theme/app_theme.dart';

void main() {
  testWidgets('App smoke test builds cleanly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const TSharkInterfaceApp());
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.toLowerCase() == 't-shark interface' ||
                widget.textSpan?.toPlainText().toLowerCase() ==
                    't-shark interface'),
      ),
      findsOneWidget,
    );
    expect(find.text('Quick Presets'), findsOneWidget);
  });

  testWidgets('Demo Spotlight Walkthrough loads demo data, steps through tour, and clears on Finish & Clear',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const TSharkInterfaceApp());
    await tester.pump();

    // Initially not in demo mode: Load Demo button is visible and no demo packets
    expect(find.text('Load Demo'), findsWidgets);
    expect(find.text('Exit Demo'), findsNothing);
    expect(find.text('5 Packets'), findsNothing);

    // Click Load Demo in the top bar
    await tester.tap(find.text('Load Demo').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Demo data is loaded and Step 1 of 5 is active
    expect(find.text('Exit Demo'), findsOneWidget);
    expect(find.text('5 Packets'), findsOneWidget);
    expect(find.text('DEMO WALKTHROUGH • STEP 1 OF 5'), findsOneWidget);
    expect(find.text('Zone 2: Interface, Target & Remote Capture'), findsOneWidget);

    // Advance to Step 2
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DEMO WALKTHROUGH • STEP 2 OF 5'), findsOneWidget);
    expect(find.text('Zone 3: Start / Stop Live Capture'), findsOneWidget);

    // Advance to Step 3
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DEMO WALKTHROUGH • STEP 3 OF 5'), findsOneWidget);
    expect(find.text('Capture Presets & Display Filters'), findsOneWidget);

    // Advance to Step 4
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DEMO WALKTHROUGH • STEP 4 OF 5'), findsOneWidget);
    expect(find.text('Live Packet Stream Table'), findsOneWidget);

    // Advance to Step 5 (Final Step)
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DEMO WALKTHROUGH • STEP 5 OF 5'), findsOneWidget);
    expect(find.text('Packet Dissection & PCAP Export'), findsOneWidget);
    expect(find.text('Finish & Clear'), findsOneWidget);

    // Click Finish & Clear -> closes tour and clears demo data
    await tester.tap(find.text('Finish & Clear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('DEMO WALKTHROUGH • STEP 5 OF 5'), findsNothing);
    expect(find.text('Exit Demo'), findsNothing);
    expect(find.text('5 Packets'), findsNothing);
    expect(find.text('Load Demo'), findsWidgets);
  });

  testWidgets('Demo Spotlight Walkthrough clears demo data when End Demo or Escape is pressed',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const TSharkInterfaceApp());
    await tester.pump();

    // Start Demo
    await tester.tap(find.text('Load Demo').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DEMO WALKTHROUGH • STEP 1 OF 5'), findsOneWidget);
    expect(find.text('5 Packets'), findsOneWidget);

    // Click End Demo
    await tester.tap(find.text('End Demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DEMO WALKTHROUGH • STEP 1 OF 5'), findsNothing);
    expect(find.text('5 Packets'), findsNothing);
    expect(find.text('Exit Demo'), findsNothing);

    // Start Demo again and press Escape key
    await tester.tap(find.text('Load Demo').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DEMO WALKTHROUGH • STEP 1 OF 5'), findsOneWidget);
    expect(find.text('5 Packets'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DEMO WALKTHROUGH • STEP 1 OF 5'), findsNothing);
    expect(find.text('5 Packets'), findsNothing);
    expect(find.text('Exit Demo'), findsNothing);
  });

  test('AppTheme dynamic getters return Dark and Light palettes', () {
    addTearDown(() => AppTheme.isDark = true);

    AppTheme.isDark = true;
    expect(AppTheme.scaffoldBg, equals(const Color(0xFF141414)));
    expect(AppTheme.surface, equals(const Color(0xFF1E1E1E)));
    expect(AppTheme.surfaceHigh, equals(const Color(0xFF252526)));
    expect(AppTheme.border, equals(const Color(0xFF2C2C2C)));
    expect(AppTheme.textPrimary, equals(const Color(0xFFE0E0E0)));
    expect(AppTheme.textSecondary, equals(const Color(0xFF9E9E9E)));
    expect(AppTheme.textMuted, equals(const Color(0xFF6E6E6E)));

    // Calling lightTheme() / darkTheme() must not clobber AppTheme.isDark
    AppTheme.lightTheme();
    expect(AppTheme.isDark, isTrue);

    AppTheme.isDark = false;
    expect(AppTheme.scaffoldBg, equals(const Color(0xFFF3F4F6)));
    expect(AppTheme.surface, equals(const Color(0xFFFFFFFF)));
    expect(AppTheme.surfaceHigh, equals(const Color(0xFFF9FAFB)));
    expect(AppTheme.border, equals(const Color(0xFFE5E7EB)));
    expect(AppTheme.textPrimary, equals(const Color(0xFF111827)));
    expect(AppTheme.textSecondary, equals(const Color(0xFF4B5563)));
    expect(AppTheme.textMuted, equals(const Color(0xFF6B7280)));

    AppTheme.darkTheme();
    expect(AppTheme.isDark, isFalse);
  });

  testWidgets(
      'TSharkInterfaceApp syncs Light & Dark mode live from SharedDeviceDatabase',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;

    final tempDir = Directory.systemTemp.createTempSync('tshark_theme_test_');
    final dbPath = p.join(tempDir.path, 'shared_devices.db');
    final db = SharedDeviceDatabase(customPath: dbPath);

    addTearDown(() async {
      AppTheme.isDark = true;
      db.dispose();
      tester.view.resetPhysicalSize();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    AppTheme.isDark = true;
    expect(await db.getThemeMode(), equals('dark'));

    await tester.pumpWidget(TSharkInterfaceApp(sharedDatabase: db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(AppTheme.isDark, isTrue);
    expect(materialApp.themeMode, equals(ThemeMode.dark));
    expect(AppTheme.surface, equals(const Color(0xFF1E1E1E)));
    var scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(const Color(0xFF141414)));

    // Switch to light mode via SharedDeviceDatabase
    await db.setThemeMode('light');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(AppTheme.isDark, isFalse);
    expect(materialApp.themeMode, equals(ThemeMode.light));
    expect(AppTheme.surface, equals(const Color(0xFFFFFFFF)));
    scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(const Color(0xFFF3F4F6)));

    // Toggle back to dark mode
    await db.setThemeMode('dark');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(AppTheme.isDark, isTrue);
    expect(materialApp.themeMode, equals(ThemeMode.dark));
    expect(AppTheme.surface, equals(const Color(0xFF1E1E1E)));
    scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(const Color(0xFF141414)));
  });
}
