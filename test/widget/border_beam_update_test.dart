import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/render/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

// The frame the painter would draw right now.
({BeamPainter painter, BeamFramePhases phases}) _frame(WidgetTester tester) {
  final painter = beamPainterOf(tester);
  return (
    painter: painter,
    phases: painter.resolver.sample(
      painter.clock.elapsedSeconds,
      painter.clock.fadeOpacity,
    ),
  );
}

/// `didUpdateWidget` and dependency changes: what re-resolves the painted
/// config (and only that), what retimes the running clock, and how the
/// scheduling inputs take effect on a beam that is already mounted.
void main() {
  group('config resolution', () {
    testWidgets('an effect change rebuilds the config and the resolver', (
      tester,
    ) async {
      Widget build(BeamEffect effect) =>
          beamHost(BorderBeam(effect: effect, child: const SizedBox.expand()));

      await tester.pumpWidget(build(const BeamEffect.rotate()));
      final before = beamPainterOf(tester);

      await tester.pumpWidget(build(const BeamEffect.line(edge: BeamEdge.top)));
      final after = beamPainterOf(tester);
      expect(after.config.effect, const BeamEffect.line(edge: BeamEdge.top));
      expect(identical(after.config, before.config), isFalse);
      expect(identical(after.resolver, before.resolver), isFalse);
      expect(identical(after.resolver.config, after.config), isTrue);

      // A parameter of the same effect is a different effect.
      await tester.pumpWidget(
        build(const BeamEffect.line(edge: BeamEdge.bottom)),
      );
      expect(
        beamPainterOf(tester).config.effect,
        const BeamEffect.line(edge: BeamEdge.bottom),
      );
    });

    testWidgets('a style change re-resolves the config', (tester) async {
      Widget build(BeamStyle style) =>
          beamHost(BorderBeam(style: style, child: const SizedBox.expand()));

      await tester.pumpWidget(
        build(const BeamStyle(colors: BeamColors.ocean, strength: 0.4)),
      );
      final ocean = beamPainterOf(tester).config;
      expect(ocean.palette, BeamColors.ocean.resolve());
      expect(ocean.strength, 0.4);

      await tester.pumpWidget(
        build(const BeamStyle(colors: BeamColors.sunset, strength: 0.8)),
      );
      final sunset = beamPainterOf(tester).config;
      expect(identical(sunset, ocean), isFalse);
      expect(sunset.palette, BeamColors.sunset.resolve());
      expect(sunset.strength, 0.8);
    });

    testWidgets('a shape change re-resolves the config', (tester) async {
      Widget build(BeamShape shape) =>
          beamHost(BorderBeam(shape: shape, child: const SizedBox.expand()));

      await tester.pumpWidget(build(const BeamShape(borderWidth: 1)));
      final thin = beamPainterOf(tester).config;

      await tester.pumpWidget(
        build(const BeamShape(borderWidth: 3, superellipse: true)),
      );
      final thick = beamPainterOf(tester).config;
      expect(identical(thick, thin), isFalse);
      expect(thick.borderWidth, 3);
      expect(thick.superellipse, isTrue);
    });

    testWidgets('a timing change re-resolves the config', (tester) async {
      Widget build(BeamTiming timing) =>
          beamHost(BorderBeam(timing: timing, child: const SizedBox.expand()));

      await tester.pumpWidget(build(const BeamTiming()));
      final forward = beamPainterOf(tester).config;
      expect(forward.direction, BeamDirection.forward);

      await tester.pumpWidget(
        build(
          const BeamTiming(
            direction: BeamDirection.reverse,
            huePeriod: Duration(seconds: 4),
          ),
        ),
      );
      final reverse = beamPainterOf(tester).config;
      expect(identical(reverse, forward), isFalse);
      expect(reverse.direction, BeamDirection.reverse);
      expect(reverse.huePeriodSeconds, closeTo(4, 1e-9));
    });

    testWidgets('equal but new value objects keep the resolved config', (
      tester,
    ) async {
      // Every argument is built at runtime, so each pump hands the widget
      // fresh instances that are merely equal to the last ones.
      Widget build(double strength, double radius, int cycleMs) => beamHost(
        BorderBeam(
          effect: BeamEffect.rotate(count: cycleMs ~/ 1000),
          colors: BeamColors([Color(0xFF00AAFF + 0 * cycleMs), Colors.pink]),
          style: BeamStyle(strength: strength, glow: strength * 2),
          shape: BeamShape.circular(radius, borderWidth: radius / 8),
          timing: BeamTiming(
            cycle: Duration(milliseconds: cycleMs),
            huePeriod: Duration(milliseconds: cycleMs * 4),
          ),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(0.5, 16, 2000));
      await tester.pump(const Duration(milliseconds: 100));
      final config = beamPainterOf(tester).config;
      final resolver = beamPainterOf(tester).resolver;

      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(build(0.5, 16, 2000));
        await tester.pump(const Duration(milliseconds: 100));
        expect(identical(beamPainterOf(tester).config, config), isTrue);
        expect(identical(beamPainterOf(tester).resolver, resolver), isTrue);
      }

      // And a real change still lands.
      await tester.pumpWidget(build(0.6, 16, 2000));
      expect(identical(beamPainterOf(tester).config, config), isFalse);
      expect(beamPainterOf(tester).config.strength, 0.6);
    });

    testWidgets('an ambient brightness change re-resolves an auto beam', (
      tester,
    ) async {
      Widget build(Brightness brightness, {BeamTheme? theme}) => beamHost(
        brightness: brightness,
        BorderBeam(
          style: BeamStyle(theme: theme),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(Brightness.dark));
      expect(beamPainterOf(tester).config.brightness, Brightness.dark);

      // MaterialApp animates a theme change; let it land.
      await tester.pumpWidget(build(Brightness.light));
      await tester.pump(const Duration(milliseconds: 300));
      expect(beamPainterOf(tester).config.brightness, Brightness.light);

      await tester.pumpWidget(build(Brightness.light, theme: BeamTheme.dark));
      expect(
        beamPainterOf(tester).config.brightness,
        Brightness.dark,
        reason: 'an explicit theme ignores the ambient brightness',
      );
    });
  });

  group('cycle change', () {
    testWidgets('retimes a travelling beam without snapping the sweep', (
      tester,
    ) async {
      Widget build(Duration cycle) => beamHost(
        BorderBeam(
          timing: BeamTiming(cycle: cycle),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(seconds: 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final before = _frame(tester);
      expect(before.painter.clock.elapsedSeconds, closeTo(0.9, 1e-9));
      expect(before.phases.travelProgress, closeTo(0.45, 1e-9));

      await tester.pumpWidget(build(const Duration(seconds: 4)));
      final after = _frame(tester);
      expect(after.painter.config.cycleSeconds, closeTo(4, 1e-9));
      expect(
        identical(after.painter.clock, before.painter.clock),
        isTrue,
        reason: 'the running clock is retimed, not replaced',
      );
      expect(
        after.phases.travelProgress,
        closeTo(before.phases.travelProgress, 1e-9),
      );
      expect(after.phases.hueDegrees, closeTo(before.phases.hueDegrees, 1e-6));

      // And from here it runs at the new rate: 0.4s more is a tenth of a
      // 4s cycle.
      await tester.pump(const Duration(milliseconds: 400));
      expect(_frame(tester).phases.travelProgress, closeTo(0.55, 1e-9));
    });

    // Rotate has its own test above; every other travelling effect here.
    for (final effect in BeamEffect.values.where(
      (e) => e.travels && e is! RotateEffect,
    )) {
      testWidgets('retimes ${effect.name} without snapping the sweep', (
        tester,
      ) async {
        Widget build(Duration cycle) => beamHost(
          BorderBeam(
            effect: effect,
            timing: BeamTiming(cycle: cycle, cycleGap: Duration.zero),
            child: const SizedBox.expand(),
          ),
        );

        await tester.pumpWidget(build(const Duration(seconds: 3)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1400));
        final before = _frame(tester);

        await tester.pumpWidget(build(const Duration(milliseconds: 1500)));
        final after = _frame(tester);
        expect(
          after.phases.travelProgress,
          closeTo(before.phases.travelProgress, 1e-9),
        );
        expect(
          after.phases.fadeOpacity,
          closeTo(before.phases.fadeOpacity, 1e-9),
        );
        expect(
          after.phases.hueDegrees,
          closeTo(before.phases.hueDegrees, 1e-6),
        );
      });
    }

    testWidgets('keeps an ambient beam breathing continuously', (tester) async {
      Widget build(Duration cycle) => beamHost(
        BorderBeam(
          effect: const BeamEffect.pulse(),
          timing: BeamTiming(cycle: cycle),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(milliseconds: 2300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
      final before = _frame(tester);

      await tester.pumpWidget(build(const Duration(seconds: 5)));
      final after = _frame(tester);
      expect(after.phases.cycles, closeTo(before.phases.cycles, 1e-9));
      expect(after.phases.hueDegrees, closeTo(before.phases.hueDegrees, 1e-6));
    });

    testWidgets('keeps the fade envelope continuous mid fade-in', (
      tester,
    ) async {
      var activated = 0;
      Widget build(Duration cycle) => beamHost(
        BorderBeam(
          timing: BeamTiming(cycle: cycle),
          onActivate: () => activated++,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(seconds: 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final clock = beamPainterOf(tester).clock;
      final opacity = clock.fadeOpacity;
      expect(opacity, inExclusiveRange(0, 1));
      expect(clock.stage, BeamFadeStage.fadingIn);

      await tester.pumpWidget(build(const Duration(seconds: 6)));
      expect(clock.fadeOpacity, closeTo(opacity, 1e-9));
      expect(clock.stage, BeamFadeStage.fadingIn);

      // The remaining fade time is unchanged too: the rest of the fade-in,
      // not that rest scaled by the cycle ratio.
      final left = Duration(
        microseconds: ((BeamClock.fadeInSeconds - 0.15) * 1e6).round(),
      );
      await tester.pump(left - const Duration(milliseconds: 50));
      expect(activated, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(activated, 1);
      expect(clock.fadeOpacity, 1);
    });

    testWidgets('an unchanged cycle leaves the timeline alone', (tester) async {
      Widget build(double strength) => beamHost(
        BorderBeam(
          style: BeamStyle(strength: strength),
          timing: const BeamTiming(cycle: Duration(seconds: 2)),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpWidget(build(0.5));
      expect(beamPainterOf(tester).clock.elapsedSeconds, closeTo(0.9, 1e-9));
    });
  });

  group('scheduling updates', () {
    testWidgets('enabling autoPlay applies startAfter from the new schedule', (
      tester,
    ) async {
      Widget build(bool autoPlay) => beamHost(
        BorderBeam(
          playback: BeamPlayback(
            autoPlay: autoPlay,
            startAfter: const Duration(milliseconds: 500),
          ),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(seconds: 1));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      await tester.pump(const Duration(milliseconds: 150));
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
    });

    testWidgets('changing a pending startAfter reschedules the start', (
      tester,
    ) async {
      Widget build(Duration delay) => beamHost(
        BorderBeam(
          playback: BeamPlayback(startAfter: delay),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(seconds: 2)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(build(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
    });

    testWidgets('changing duration starts a fresh budget from the update', (
      tester,
    ) async {
      Widget build(Duration? duration) => beamHost(
        BorderBeam(
          playback: BeamPlayback(duration: duration),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final clock = beamPainterOf(tester).clock;

      await tester.pumpWidget(build(const Duration(seconds: 1)));
      await tester.pump(const Duration(milliseconds: 900));
      expect(clock.stage, isNot(BeamFadeStage.fadingOut));
      await tester.pump(const Duration(milliseconds: 150));
      expect(clock.stage, BeamFadeStage.fadingOut);
    });

    testWidgets('re-activating mid fade-out resumes from the current opacity', (
      tester,
    ) async {
      var activated = 0;
      var deactivated = 0;
      Widget build(bool active) => beamHost(
        BorderBeam(
          active: active,
          onActivate: () => activated++,
          onDeactivate: () => deactivated++,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final clock = beamPainterOf(tester).clock;
      expect(clock.stage, BeamFadeStage.fadingIn);

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 80));
      expect(clock.stage, BeamFadeStage.fadingOut);
      final mid = clock.fadeOpacity;
      expect(mid, inExclusiveRange(0, 1));
      final elapsed = clock.elapsedSeconds;

      await tester.pumpWidget(build(true));
      expect(clock.stage, BeamFadeStage.fadingIn);
      expect(
        clock.fadeOpacity,
        closeTo(mid, 1e-9),
        reason: 'no jump back to zero',
      );
      expect(
        clock.elapsedSeconds,
        closeTo(elapsed, 1e-9),
        reason: 'a mid-fade re-activation keeps the timeline',
      );

      await tester.pump(pastFadeIn);
      expect(activated, 1);
      expect(deactivated, 0);
      expect(clock.fadeOpacity, 1);
    });

    testWidgets('a controller swap detaches the old and attaches the new', (
      tester,
    ) async {
      final first = BorderBeamController();
      final second = BorderBeamController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget build(BorderBeamController? controller) => beamHost(
        BorderBeam(controller: controller, child: const SizedBox.expand()),
      );

      await tester.pumpWidget(build(first));
      expect(first.isAttached, isTrue);
      expect(second.isAttached, isFalse);

      await tester.pumpWidget(build(second));
      expect(first.isAttached, isFalse);
      expect(second.isAttached, isTrue);

      // The detached controller no longer reaches the beam.
      first.start();
      await tester.pump(const Duration(milliseconds: 100));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);

      second.start();
      await tester.pump();
      await tester.pump(pastFadeIn);
      expect(second.isActive, isTrue);
      expect(beamPainterOf(tester).clock.isVisible, isTrue);

      await tester.pumpWidget(build(null));
      expect(second.isAttached, isFalse);
    });

    testWidgets('dropping the controller hands playback back to the widget', (
      tester,
    ) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(BorderBeamController? controller, {bool active = true}) =>
          beamHost(
            BorderBeam(
              controller: controller,
              active: active,
              child: const SizedBox.expand(),
            ),
          );

      await tester.pumpWidget(build(controller));
      await tester.pump(const Duration(milliseconds: 100));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);

      await tester.pumpWidget(build(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        beamPainterOf(tester).clock.isVisible,
        isTrue,
        reason: 'autoPlay takes over the beam that never started',
      );

      await tester.pumpWidget(build(null, active: false));
      await tester.pump(pastFadeOut);
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
    });
  });
}
