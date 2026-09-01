import 'package:flutter/material.dart';
import 'package:flutter_border_beam_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the playground's generated snippet.
String snippetText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('playground-snippet'))).data!;

/// Advances past the demo's implicit animations. `pumpAndSettle` never
/// returns here: a running beam keeps its ticker scheduled forever.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scrolls [label] into view before tapping it — the demo is one long
/// scroll view, and a tap on an off-screen widget silently hits nothing.
Future<void> tapLabel(WidgetTester tester, String label) async {
  await settle(tester);
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  testWidgets('gallery renders both tabs, the themed section, and the '
      'playground', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BorderBeamDemoApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Border beam'), findsOneWidget);
    expect(find.text('Build anything...'), findsWidgets);
    expect(find.text('Playground'), findsOneWidget);

    // The themed gallery: three variants under one BorderBeamTheme.
    expect(find.text('Themed'), findsOneWidget);
    expect(find.text('rotate'), findsOneWidget);
    expect(find.text('small'), findsOneWidget);
    expect(find.text('pulseInside'), findsOneWidget);
    expect(find.text('Rest between sweeps'), findsOneWidget);

    // Switch to the Pulse tab.
    await tapLabel(tester, 'Pulse');
    expect(find.text('Working...'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: a default configuration prints the one-liner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BorderBeamDemoApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(snippetText(tester), 'BorderBeam.rotate(\n  child: child,\n)');
  });

  testWidgets('playground: variant, shape, and palette changes reach the '
      'snippet', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BorderBeamDemoApp());
    await tester.pump(const Duration(milliseconds: 300));

    final before = snippetText(tester);

    await tapLabel(tester, 'Line');
    expect(snippetText(tester), startsWith('BorderBeam.line('));
    expect(snippetText(tester), isNot(before));

    await tapLabel(tester, 'Ocean');
    expect(snippetText(tester), contains('colors: BeamColors.ocean'));

    await tapLabel(tester, 'Stadium');
    expect(snippetText(tester), contains('BeamShape.stadium('));

    await tapLabel(tester, 'Squircle');
    expect(snippetText(tester), contains('superellipse: true'));

    await tapLabel(tester, 'Pulse Outside');
    expect(snippetText(tester), startsWith('BorderBeam.pulseOutside('));

    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: controller mode swaps in a controller and its '
      'transport', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BorderBeamDemoApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Start'), findsNothing);

    await tapLabel(tester, 'Controller');
    expect(snippetText(tester), contains('final controller ='));
    expect(snippetText(tester), contains('controller: controller'));
    // The declarative scheduling fields are the controller's now.
    expect(snippetText(tester), isNot(contains('playback:')));
    expect(find.text('Start'), findsOneWidget);

    for (final action in ['Pause', 'Resume', 'Stop', 'Start']) {
      await tapLabel(tester, action);
    }

    await tapLabel(tester, 'Controller');
    expect(snippetText(tester), isNot(contains('controller: controller')));
    expect(find.text('Start'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the theme toggle wraps the snippet in a '
      'BorderBeamTheme', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BorderBeamDemoApp());
    await tester.pump(const Duration(milliseconds: 300));

    await tapLabel(tester, 'Theme');
    await tapLabel(tester, 'BorderBeamTheme');
    expect(snippetText(tester), startsWith('BorderBeamTheme('));
    expect(snippetText(tester), contains('BeamColors.ocean'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: Reset returns every control to its default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BorderBeamDemoApp());
    await tester.pump(const Duration(milliseconds: 300));

    await tapLabel(tester, 'Line');
    await tapLabel(tester, 'Stadium');
    expect(
      snippetText(tester),
      isNot('BorderBeam.rotate(\n  child: child,\n)'),
    );

    await tapLabel(tester, 'Reset');
    expect(snippetText(tester), 'BorderBeam.rotate(\n  child: child,\n)');
    expect(tester.takeException(), isNull);
  });
}
