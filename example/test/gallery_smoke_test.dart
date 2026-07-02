import 'package:border_beam_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery renders both tabs and the playground', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BorderBeamDemoApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Border beam'), findsOneWidget);
    expect(find.text('Build anything...'), findsWidgets);
    expect(find.text('Playground'), findsOneWidget);

    // Switch to the Pulse tab.
    await tester.tap(find.text('Pulse'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Working...'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);

    // Playground: switch variant and palette without errors.
    await tester.tap(find.text('Pulse Outside'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ocean'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
