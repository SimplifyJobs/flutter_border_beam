import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/border_beam/animation/beam_clock.dart';
import 'package:prismatic/src/border_beam/animation/beam_phases.dart';
import 'package:prismatic/src/border_beam/render/beam_painter.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: app!,
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

Iterable<BeamPainter> _painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>();

BeamPainter _painter(WidgetTester tester) => _painters(tester).first;

BeamClock _clock(WidgetTester tester) => _painter(tester).clock;

// The phases the mounted beam's resolver gives at [t] with a full fade.
BeamFramePhases _at(WidgetTester tester, double t) =>
    _painter(tester).resolver.sample(t, 1);

// The phases the painter would draw right now.
BeamFramePhases _now(WidgetTester tester) {
  final painter = _painter(tester);
  return painter.resolver.sample(
    painter.clock.elapsedSeconds,
    1,
    progress: painter.progress?.value,
  );
}

// The signed distance from [from] to [to] round the border, in (-0.5, 0.5].
double _wrapDelta(double from, double to) => ((to - from) + 0.5) % 1.0 - 0.5;

/// Sums the alpha channel of the beam's own repaint boundary. Rasterizing is
/// real async work, so it runs outside the fake clock.
Future<int> _alphaSum(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .descendant(
          of: find.byType(BorderBeam),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  final sum = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    var total = 0;
    for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
      total += bytes.getUint8(i);
    }
    return total;
  });
  return sum!;
}

/// How the mounted beam moves: that its timing reaches the live sweep
/// (direction, phase offset), the one-shot pulse and flash accents, and the
/// live strength listenable. The sweep maths itself — direction, bounce,
/// phase offset, several travellers, ambient effects — is the resolver's,
/// tested in `test/animation/beam_travel_test.dart`; reduced motion and
/// repeat budgets are in `beam_playback_test.dart`.
void main() {
  setUpAll(() async {
    await BorderBeam.precache();
  });

  // A one-second sweep with no rest, so instants map straight to progress.
  BeamTiming oneSecond([BeamDirection? direction]) => BeamTiming(
    cycle: const Duration(seconds: 1),
    cycleGap: Duration.zero,
    direction: direction,
  );

  group('direction', () {
    testWidgets('the live sweep runs the configured way', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            timing: oneSecond(BeamDirection.reverse),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final earlier = _now(tester).travelProgress;
      expect(earlier, closeTo(0.75, 1e-9));

      await tester.pump(const Duration(milliseconds: 100));
      final later = _now(tester).travelProgress;
      expect(
        _wrapDelta(earlier, later),
        closeTo(-0.1, 1e-9),
        reason: 'a reversed beam moves counter-clockwise',
      );
    });
  });

  group('phaseOffset', () {
    testWidgets('shifts where the sweep starts', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam(
            timing: BeamTiming(cycle: Duration(seconds: 1), phaseOffset: 0.25),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(_at(tester, 0).travelProgress, closeTo(0.25, 1e-9));
      expect(_at(tester, 0.5).travelProgress, closeTo(0.75, 1e-9));
      expect(_at(tester, 0.9).travelProgress, closeTo(0.15, 1e-9));
    });
  });

  group('pulse and flash', () {
    Future<BorderBeamController> runningBeam(WidgetTester tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(controller: controller, child: const SizedBox.expand()),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      return controller;
    }

    testWidgets('pulse lifts the boost and settles back to 1', (tester) async {
      final controller = await runningBeam(tester);
      final clock = _clock(tester);
      expect(clock.boost, 1);

      controller.pulse();
      expect(clock.isBoosting, isTrue);
      var peak = 1.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        // The rise is spring-eased, so it may crest a hair past the peak.
        expect(clock.boost, greaterThanOrEqualTo(1));
        expect(clock.boost, lessThan(BeamClock.pulsePeak * 1.1));
        if (clock.boost > peak) peak = clock.boost;
      }
      expect(peak, greaterThan(1.5), reason: 'the pulse visibly rises');

      await tester.pump(const Duration(milliseconds: 400));
      expect(clock.boost, 1);
      expect(clock.isBoosting, isFalse);
    });

    testWidgets('flash jumps to its peak, holds, and settles back to 1', (
      tester,
    ) async {
      final controller = await runningBeam(tester);
      final clock = _clock(tester);

      controller.flash();
      expect(clock.boost, greaterThan(1), reason: 'a flash has no rise');
      final peak = clock.boost;
      await tester.pump(const Duration(milliseconds: 60));
      expect(clock.boost, closeTo(peak, 1e-9), reason: 'held at the peak');

      await tester.pump(const Duration(milliseconds: 500));
      expect(clock.boost, 1);
      expect(clock.isBoosting, isFalse);
    });

    testWidgets('a boost brightens the painted frame', (tester) async {
      final controller = await runningBeam(tester);
      final rest = await _alphaSum(tester);
      expect(rest, greaterThan(0));

      controller.flash();
      // A zero-length pump repaints at the same instant: only the boost moved.
      await tester.pump();
      expect(await _alphaSum(tester), greaterThan(rest));
    });

    testWidgets('a cycle retime carries a boost in progress', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(Duration cycle) => _host(
        BorderBeam(
          controller: controller,
          timing: BeamTiming(cycle: cycle),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(seconds: 2)));
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final clock = _clock(tester);
      controller.pulse();
      await tester.pump(const Duration(milliseconds: 100));
      final before = clock.boost;
      expect(before, greaterThan(1));

      await tester.pumpWidget(build(const Duration(seconds: 4)));
      expect(clock.boost, closeTo(before, 1e-9));
      await tester.pump(const Duration(milliseconds: 700));
      expect(clock.boost, 1);
    });

    testWidgets('both are no-ops while the beam is hidden', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(controller: controller, child: const SizedBox.expand()),
        ),
      );
      final clock = _clock(tester);
      expect(clock.isVisible, isFalse);

      controller
        ..pulse()
        ..flash();
      expect(clock.isBoosting, isFalse);
      expect(clock.boost, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a paused beam takes no boost', (tester) async {
      final controller = await runningBeam(tester);
      controller.pause();
      await tester.pump();

      controller.pulse();
      expect(_clock(tester).isBoosting, isFalse);
    });
  });

  group('strengthListenable', () {
    testWidgets('scales the painted frame live, without a rebuild', (
      tester,
    ) async {
      final strength = ValueNotifier<double>(1);
      addTearDown(strength.dispose);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              builds++;
              return BorderBeam(
                strengthListenable: strength,
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final painter = _painter(tester);
      expect(identical(painter.strength, strength), isTrue);
      final full = await _alphaSum(tester);
      expect(full, greaterThan(0));

      strength.value = 0.4;
      await tester.pump();
      final dimmed = await _alphaSum(tester);
      expect(dimmed, greaterThan(0));
      expect(dimmed, lessThan(full));

      expect(builds, 1, reason: 'the value never goes through a rebuild');
      expect(identical(_painter(tester).config, painter.config), isTrue);
      expect(identical(_painter(tester).resolver, painter.resolver), isTrue);
    });

    testWidgets('zero paints nothing, and lifting it paints again', (
      tester,
    ) async {
      final strength = ValueNotifier<double>(0);
      addTearDown(strength.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(
            strengthListenable: strength,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(await _alphaSum(tester), 0);

      strength.value = 1;
      await tester.pump();
      expect(await _alphaSum(tester), greaterThan(0));

      await tester.pumpWidget(_host(const SizedBox.expand()));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a swapped listenable takes over, and removing it restores '
        'the style strength', (tester) async {
      final first = ValueNotifier<double>(1);
      addTearDown(first.dispose);
      final second = ValueNotifier<double>(0);
      addTearDown(second.dispose);
      Widget build(ValueNotifier<double>? strength) => _host(
        BorderBeam(
          strengthListenable: strength,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(first));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final clock = _painter(tester).clock;
      expect(await _alphaSum(tester), greaterThan(0));

      await tester.pumpWidget(build(second));
      expect(identical(_painter(tester).strength, second), isTrue);
      expect(await _alphaSum(tester), 0, reason: 'the new listenable is read');

      second.value = 1;
      await tester.pump();
      expect(await _alphaSum(tester), greaterThan(0));

      second.value = 0;
      await tester.pump();
      await tester.pumpWidget(build(null));
      expect(_painter(tester).strength, isNull);
      expect(
        await _alphaSum(tester),
        greaterThan(0),
        reason: 'without a listenable the style strength applies again',
      );
      expect(
        identical(_painter(tester).clock, clock),
        isTrue,
        reason: 'neither swap restarts the beam',
      );
    });

    testWidgets('scales a debug-frozen frame too', (tester) async {
      final strength = ValueNotifier<double>(0);
      addTearDown(strength.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(
            playback: const BeamPlayback(
              debugFrozenAt: Duration(milliseconds: 1300),
            ),
            strengthListenable: strength,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      expect(await _alphaSum(tester), 0);

      strength.value = 1;
      await tester.pump();
      expect(await _alphaSum(tester), greaterThan(0));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
