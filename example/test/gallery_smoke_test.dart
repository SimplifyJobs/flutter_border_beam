import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam_example/main.dart';
import 'package:flutter_border_beam_example/src/mocks.dart';
import 'package:flutter_border_beam_example/src/playground/controls_panel.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the playground prints for a default configuration.
const String defaultSnippet =
    'BorderBeam(\n  effect: const BeamEffect.rotate(),\n  child: child,\n)';

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

/// Taps a playground control: labels are scoped to the [ControlsPanel],
/// since the gallery above it reuses several of them.
Future<void> tapControl(WidgetTester tester, String label) async {
  await tapFinder(
    tester,
    find.descendant(of: find.byType(ControlsPanel), matching: find.text(label)),
  );
}

/// Taps one of the gallery's Rotate/Pulse tabs.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tapFinder(
    tester,
    find.descendant(of: find.byType(PillTabBar), matching: find.text(label)),
  );
}

/// Scrolls [finder] into view and taps it — the demo is one long scroll
/// view, and a tap on an off-screen widget silently hits nothing.
Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  await settle(tester);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

/// Mounts the demo on a tall viewport — the gallery is one long page.
Future<void> pumpGallery(
  WidgetTester tester, {
  Size size = const Size(1200, 3600),
  double devicePixelRatio = 2,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const BorderBeamDemoApp());
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(BorderBeam.precache);

  testWidgets('gallery renders both tabs, the themed section, and the '
      'playground', (tester) async {
    await pumpGallery(tester);

    expect(find.text('Border beam'), findsOneWidget);
    expect(find.text('Build anything...'), findsWidgets);
    expect(find.text('Playground'), findsOneWidget);

    // The themed gallery: three effects under one BorderBeamTheme.
    expect(find.text('Themed'), findsOneWidget);
    for (final label in ['themed rotate', 'themed flow', 'themed pulse']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Rest between sweeps'), findsOneWidget);
    expect(find.text('Partial contours'), findsOneWidget);
    for (final label in [
      'Half phone',
      'Half phone · line',
      'Half phone · pulse',
      'Bottom edge · spin',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    // Switch to the Pulse tab, where the halo replaces pulse-outside.
    await tapTab(tester, 'Pulse');
    expect(find.text('Working...'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(
      tester
          .widgetList<BorderBeam>(find.byType(BorderBeam))
          .where((beam) => beam.effect is HaloEffect),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery: the new effects, every effect, and every preset '
      'render', (tester) async {
    await pumpGallery(tester);

    for (final title in [
      'Flow, spin, shimmer, charge',
      'Every effect',
      'Driven progress',
      'Palettes',
      'Surfaces',
      'Motion',
      'Sync',
    ]) {
      await tester.ensureVisible(find.text(title));
      await settle(tester);
      expect(find.text(title), findsOneWidget, reason: '$title section');
    }

    // The four newer effects on their own surfaces.
    for (final label in [
      'Listening…',
      'Get started',
      'Upgrade to Pro',
      'Saving draft',
      'flow · cosmic',
      'shimmer · gold',
      'charge · lagoon',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // One card per effect, named by BeamEffect.name.
    for (final effect in BeamEffect.values) {
      expect(find.text(effect.name), findsWidgets, reason: effect.name);
    }

    // One card per preset, named by its key; the eight new ones are tagged.
    for (final name in BeamColors.presets.keys) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('new'), findsNWidgets(8));

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
    for (final label in [
      'reverse',
      'bounce',
      'count 3',
      'dashes 8',
      'comet',
      'glow 2',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery: charge fills to a looping progress value', (
    tester,
  ) async {
    await pumpGallery(tester);

    BorderBeam charge() => tester
        .widgetList<BorderBeam>(find.byType(BorderBeam))
        .firstWhere(
          (beam) => beam.effect is ChargeEffect && beam.progress != null,
        );

    final first = charge().progress!;
    await tester.pump(const Duration(seconds: 1));
    final later = charge().progress!;
    expect(later, greaterThan(first));
    expect(find.textContaining('Uploading…'), findsOneWidget);
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

  testWidgets('playground: a default configuration prints the effect and '
      'the child', (tester) async {
    await pumpGallery(tester);
    expect(snippetText(tester), defaultSnippet);
  });

  testWidgets('playground: effect, palette, and shape changes reach the '
      'snippet', (tester) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Line');
    expect(snippetText(tester), contains('effect: const BeamEffect.line()'));
    await tapControl(tester, 'Top');
    expect(
      snippetText(tester),
      contains('BeamEffect.line(edge: BeamEdge.top)'),
    );

    await tapControl(tester, 'Ocean');
    expect(snippetText(tester), contains('colors: BeamColors.ocean'));
    await tapControl(tester, 'Lagoon');
    expect(snippetText(tester), contains('colors: BeamColors.lagoon'));

    await tapControl(tester, 'Shape');
    await tapControl(tester, 'Stadium');
    expect(snippetText(tester), contains('BeamShape.stadium('));
    await tapControl(tester, 'Squircle');
    expect(snippetText(tester), contains('superellipse: true'));
    await tapControl(tester, '8');
    expect(snippetText(tester), contains('dashes: 8'));

    await tapControl(tester, 'Halo');
    expect(snippetText(tester), contains('effect: const BeamEffect.halo()'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: per-effect parameters appear with their effect', (
    tester,
  ) async {
    await pumpGallery(tester);

    // Rotate is the default, so its parameters show from the start.
    await tapControl(tester, '3');
    await tapControl(tester, 'Comet tail');
    expect(
      snippetText(tester),
      contains('BeamEffect.rotate(count: 3, comet: true)'),
    );

    await tapControl(tester, 'Shimmer');
    expect(find.text('Comet tail'), findsNothing);
    expect(find.text('Angle'), findsOneWidget);
    expect(snippetText(tester), contains('effect: const BeamEffect.shimmer()'));

    await tapControl(tester, 'Charge');
    expect(find.text('Angle'), findsNothing);
    expect(snippetText(tester), contains('effect: const BeamEffect.charge()'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: segment chips reach the snippet', (tester) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Shape');
    await tapControl(tester, 'Bottom half');
    expect(snippetText(tester), contains('BeamSegment.bottomHalf'));

    await tapControl(tester, 'Right edge');
    expect(snippetText(tester), contains('BeamSegment.rightEdge'));

    // The palette's Custom chip comes first; the segment's is the last.
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
    expect(snippetText(tester), defaultSnippet);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: controller mode swaps in a controller and its '
      'transport', (tester) async {
    await pumpGallery(tester);

    expect(find.text('start()'), findsNothing);

    await tapControl(tester, 'Controller');
    expect(snippetText(tester), contains('final controller ='));
    expect(snippetText(tester), contains('controller: controller'));
    expect(snippetText(tester), contains('controller.pulse() / .flash()'));
    // The declarative scheduling fields are the controller's now.
    expect(snippetText(tester), isNot(contains('playback:')));

    for (final action in [
      'pause()',
      'resume()',
      'stop()',
      'start()',
      'pulse()',
      'flash()',
    ]) {
      await tapControl(tester, action);
    }

    await tapControl(tester, 'Controller');
    expect(snippetText(tester), isNot(contains('controller: controller')));
    expect(find.text('start()'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the theme toggle wraps the snippet in a '
      'BorderBeamTheme', (tester) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Theme & sync');
    await tapControl(tester, 'BorderBeamTheme');
    expect(snippetText(tester), startsWith('BorderBeamTheme('));
    expect(snippetText(tester), contains('BeamColors.ocean'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: Reset returns every control to its default', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Flow');
    await tapControl(tester, 'Cosmic');
    expect(snippetText(tester), isNot(defaultSnippet));

    // Reset sits in the toolbar above the panel.
    await tapFinder(tester, find.text('Reset'));
    expect(snippetText(tester), defaultSnippet);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the Drive section feeds progress, the pointer, '
      'and a signal', (tester) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Charge');
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

    // Ambient effects have no travel to drive or follow.
    await tapControl(tester, 'Spin');
    expect(snippetText(tester), isNot(contains('follow:')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the sync toggle swaps in a BeamSync group', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Theme & sync');
    await tapControl(tester, 'BeamSync');
    expect(snippetText(tester), startsWith('BeamSync('));
    // The group's three beams are labelled with the phase each one runs at.
    expect(find.text('phaseOffset 0.00'), findsWidgets);
    expect(find.text('phaseOffset 0.33'), findsWidgets);

    await tapControl(tester, 'BeamSync');
    expect(snippetText(tester), startsWith('BorderBeam('));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: controllers start when previews attach or return '
      'from sync mode', (tester) async {
    await pumpGallery(tester, size: const Size(519, 3600), devicePixelRatio: 1);

    await tapControl(tester, 'Controller');
    var controlled = tester
        .widgetList<BorderBeam>(find.byType(BorderBeam))
        .where((beam) => beam.controller != null)
        .toList();
    expect(controlled, hasLength(1));
    expect(controlled.single.controller!.isActive, isTrue);

    tester.view.physicalSize = const Size(1200, 3600);
    await settle(tester);
    controlled = tester
        .widgetList<BorderBeam>(find.byType(BorderBeam))
        .where((beam) => beam.controller != null)
        .toList();
    expect(controlled, hasLength(2));
    expect(controlled.every((beam) => beam.controller!.isActive), isTrue);

    await tapControl(tester, 'Theme & sync');
    await tapControl(tester, 'BeamSync');
    expect(
      tester
          .widgetList<BorderBeam>(find.byType(BorderBeam))
          .where((beam) => beam.controller != null),
      isEmpty,
    );

    await tapControl(tester, 'BeamSync');
    controlled = tester
        .widgetList<BorderBeam>(find.byType(BorderBeam))
        .where((beam) => beam.controller != null)
        .toList();
    expect(controlled, hasLength(2));
    expect(controlled.every((beam) => beam.controller!.isActive), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: the palette factories reach the snippet', (
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

    await tapControl(tester, 'Custom');
    expect(snippetText(tester), contains('const BeamColors([Color('));
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground: style fields reach a const BeamStyle', (
    tester,
  ) async {
    await pumpGallery(tester);

    await tapControl(tester, 'Style');
    await tapControl(tester, 'None');
    expect(snippetText(tester), contains('hueMode: BeamHueMode.none'));
    await tapControl(tester, 'Light');
    expect(snippetText(tester), contains('theme: BeamTheme.light'));
    expect(snippetText(tester), contains('style: const BeamStyle('));
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
}
