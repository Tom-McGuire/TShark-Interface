import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshark_interface/main.dart';

void main() {
  testWidgets('App smoke test builds cleanly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const TSharkInterfaceApp());
    await tester.pump();

    expect(find.text('T-Shark Interface'), findsOneWidget);
    expect(find.text('Quick Presets'), findsOneWidget);
  });
}
