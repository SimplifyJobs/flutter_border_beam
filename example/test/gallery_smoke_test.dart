import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_border_beam_example/main.dart';
import 'package:flutter_border_beam_example/src/mocks.dart';
import 'package:flutter_border_beam_example/src/playground/controls_panel.dart';
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
  await tapFinder(tester, find.text(label));
}

/// The same, for a label that also appears elsewhere on the page: the
/// playground's own controls are scoped to the [ControlsPanel].
Future<void> tapControl(WidgetTester tester, String label) async {
  await tapFinder(
    tester,
    find.descendant(of: find.byType(ControlsPanel), matching: find.text(label)),
  );
}

/// Scrolls [finder] into view and taps it.
Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  await settle(tester);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

/// Mounts the demo on a tall viewport — the gallery is one long page.
Future<void> pumpGallery(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const BorderBeamDemoApp());
  await tester.pump(const Duration(milliseconds: 300));
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
    expect(find.text('Partial contours'), findsOneWidget);
    expect(find.text('Half phone'), findsOneWidget);
    expect(find.text('Half phone · line'), findsOneWidget);
    expect(find.text('Half phone · pulse'), findsOneWidget);
    expect(find.text('Corner wrap'), findsOneWidget);

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

  testWidgets('playground: segment chips and corner wrap reach the snippet', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Bottom half');
    expect(snippetText(tester), contains('BeamSegment.bottomHalf'));

    await tapControl(tester, 'Top edge');
    expect(snippetText(tester), contains('BeamSegment.topEdge'));

    await tapFinder(
      tester,
      find
          .descendant(
            of: find.byType(ControlsPanel),
            matching: find.text('Custom'),
          )
          .last,
    );
    expect(
      snippetText(tester),
      contains(
        'BeamSegment(start: BeamAnchor.edge(BeamEdge.right), '
        'end: BeamAnchor.edge(BeamEdge.left), feather: 48)',
      ),
    );
    expect(find.text('Start edge'), findsOneWidget);
    expect(find.text('End edge'), findsOneWidget);
    expect(find.text('Feather'), findsOneWidget);

    await tapControl(tester, 'Off');
    await tapControl(tester, 'Line');
    await tapControl(tester, 'Wrap corners');
    expect(snippetText(tester), contains('wrapCorners: true'));
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

  testWidgets('gallery: the palette, surface, motion, progress, and sync '
      'sections all render', (tester) async {
    await pumpGallery(tester);

    for (final title in [
      'Palettes',
      'Surfaces',
      'Motion',
      'Driven progress',
      'Sync',
      'Partial contours',
    ]) {
      await tester.ensureVisible(find.text(title));
      await settle(tester);
      expect(find.text(title), findsOneWidget, reason: '$title section');
    }

    for (final label in ['Half phone', 'Half phone · line', 'Corner wrap']) {
      await tester.ensureVisible(find.text(label));
      await settle(tester);
      expect(find.text(label), findsOneWidget);
    }

    // One card per palette preset, named by the constant it uses.
    for (final preset in ['colorful', 'mono', 'gold', 'holographic']) {
      expect(find.text(preset), findsOneWidget);
    }

    // The four surface entry points.
    for (final label in [
      'BeamDecoration',
      'BeamFocusRing',
      'BeamHover',
      'BeamPress',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    // The motion cards.
    for (final label in ['reverse', 'bounce', 'beamCount 3', 'segments 8']) {
      expect(find.text(label), findsOneWidget);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery: the surface wrappers light on focus, hover, and '
      'press', (tester) async {
    await pumpGallery(tester);

    // Focus: the ring follows the field's own subtree.
    await tapFinder(tester, find.byType(MockFocusField));
    expect(
      Focus.of(tester.element(find.text('Tap to focus'))).hasFocus,
      isTrue,
    );

    // Hover: a mouse entering the card starts the beam and steers it.
    final card = find.text('BeamHover');
    await tester.ensureVisible(card);
    await settle(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(card));
    await settle(tester);
    await mouse.moveTo(Offset.zero);
    await settle(tester);

    // Press: pointer down lights it, and the release is held for the
    // minimum duration.
    final press = find.text('BeamPress');
    await tester.ensureVisible(press);
    await settle(tester);
    final finger = await tester.startGesture(tester.getCenter(press));
    await settle(tester);
    await finger.up();
    await settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the Drive section feeds progress, the pointer, '
      'and a signal', (tester) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Drive');
    await tapControl(tester, 'Progress');
    expect(snippetText(tester), contains('progress: 0.35'));

    await tapControl(tester, 'Strength from signal');
    expect(snippetText(tester), contains('strengthListenable: level'));

    // Follow loses to progress while both are on, so it reaches the snippet
    // only once progress is off again.
    await tapControl(tester, 'Follow pointer');
    expect(snippetText(tester), isNot(contains('follow: pointer')));
    await tapControl(tester, 'Progress');
    expect(snippetText(tester), contains('follow: pointer'));

    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the sync toggle swaps in a BeamSync group', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Theme');
    await tapControl(tester, 'BeamSync');
    expect(snippetText(tester), startsWith('BeamSync('));
    // The group's three beams are labelled with the phase each one runs at.
    expect(find.text('phaseOffset 0.00'), findsWidgets);
    expect(find.text('phaseOffset 0.33'), findsWidgets);

    await tapControl(tester, 'BeamSync');
    expect(snippetText(tester), startsWith('BorderBeam.rotate('));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the controller transport carries pulse and '
      'flash', (tester) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Controller');
    expect(snippetText(tester), contains('controller.pulse() / .flash()'));

    for (final action in ['Pulse', 'Flash', 'Pause', 'Resume', 'Start']) {
      await tapControl(tester, action);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the new palette modes reach the snippet', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Holographic');
    expect(snippetText(tester), contains('colors: BeamColors.holographic'));

    await tapControl(tester, 'Seed');
    expect(snippetText(tester), contains('BeamColors.fromSeed('));
    await tapControl(tester, 'Triadic');
    expect(snippetText(tester), contains('BeamSeedHarmony.triadic'));

    await tapControl(tester, 'Lerp');
    expect(snippetText(tester), contains('BeamColors.lerp('));

    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: reduced motion can be chosen and simulated', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Slow');
    expect(
      snippetText(tester),
      contains('reducedMotion: BeamReducedMotion.slow'),
    );

    // Simulating is a preview concern: the beam's fields do not change.
    final before = snippetText(tester);
    await tapControl(tester, 'Simulate reduced motion');
    expect(snippetText(tester), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the star contour and ring offset reach the '
      'shape', (tester) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Star contour');
    expect(
      snippetText(tester),
      contains("// contour: BeamPathContour(builder: yourPath, key: 'star')"),
    );
    expect(tester.takeException(), isNull);
  });
}
