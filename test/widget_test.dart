import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/main.dart';

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
}
