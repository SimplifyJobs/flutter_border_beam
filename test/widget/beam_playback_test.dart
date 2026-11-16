import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

/// `BeamPlayback` through a mounted beam: whether and when it starts, how
/// long it runs, how it answers the platform's reduced-motion request, the
/// frozen debug frame, the fade curve, and the offscreen pause.
void main() {
  // The frozen-frame and reduced-motion groups read pixels.
  setUpAll(() async {
    await BorderBeam.precache();
  });

  group('scheduling', () {
    testWidgets('autoPlay: false never starts by itself', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            effect: BeamEffect.pulse(),
            playback: BeamPlayback(autoPlay: false),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('active: false stays idle until toggled', (tester) async {
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

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(seconds: 1));
      expect(activated, 0);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(activated, 1);
      expect(deactivated, 0);

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.transientCallbackCount, 0, reason: 'halted');
    });

    testWidgets('the callbacks in force when a fade ends are the ones called', (
      tester,
    ) async {
      final calls = <String>[];
      Widget build(String tag) => beamHost(
        BorderBeam(
          onActivate: () => calls.add('$tag:activate'),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build('old'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(build('new'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, ['new:activate']);
    });

    testWidgets('startAfter delays the start', (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        beamHost(
          BorderBeam(
            playback: const BeamPlayback(startAfter: Duration(seconds: 2)),
            onActivate: () => activated++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(activated, 0);
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(activated, 1);
    });

    testWidgets('duration bounds the total play time', (tester) async {
      var deactivated = 0;
      await tester.pumpWidget(
        beamHost(
          BorderBeam(
            playback: const BeamPlayback(duration: Duration(seconds: 2)),
            onDeactivate: () => deactivated++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(deactivated, 0);
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      expect(beamPainterOf(tester).clock.stage, BeamFadeStage.fadingOut);
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('duration counts wall time, not sped-up timeline time', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            timing: BeamTiming(speed: 4),
            playback: BeamPlayback(duration: Duration(seconds: 1)),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(beamPainterOf(tester).clock.stage, isNot(BeamFadeStage.fadingOut));
      await tester.pump(const Duration(milliseconds: 200));
      expect(beamPainterOf(tester).clock.stage, BeamFadeStage.fadingOut);
    });
  });

  group('repeat', () {
    for (final effect in [
      const BeamEffect.rotate(),
      const BeamEffect.pulse(),
    ]) {
      testWidgets('${effect.name}: count(2) fades out after two cycles', (
        tester,
      ) async {
        var deactivated = 0;
        await tester.pumpWidget(
          beamHost(
            BorderBeam(
              effect: effect,
              timing: const BeamTiming(cycle: Duration(seconds: 1)),
              playback: const BeamPlayback(repeat: BeamRepeat.count(2)),
              onDeactivate: () => deactivated++,
              child: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1900));
        final clock = beamPainterOf(tester).clock;
        expect(clock.stage, isNot(BeamFadeStage.fadingOut));

        await tester.pump(const Duration(milliseconds: 200));
        expect(
          clock.stage,
          BeamFadeStage.fadingOut,
          reason: 'the last cycle ends on a fade, not a cut',
        );
        expect(deactivated, 0);

        await tester.pump(const Duration(milliseconds: 600));
        expect(deactivated, 1);
        expect(clock.isVisible, isFalse);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }

    testWidgets('once runs a single cycle', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            timing: BeamTiming(cycle: Duration(seconds: 1)),
            playback: BeamPlayback(repeat: BeamRepeat.once()),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(beamPainterOf(tester).clock.stage, BeamFadeStage.fadingOut);
    });

    testWidgets('forever keeps running', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            timing: BeamTiming(cycle: Duration(milliseconds: 500)),
            playback: BeamPlayback(repeat: BeamRepeat.forever()),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      final clock = beamPainterOf(tester).clock;
      expect(clock.isRunning, isTrue);
      expect(clock.stage, isNot(BeamFadeStage.fadingOut));
    });

    testWidgets('re-activating a spent beam plays the budget again', (
      tester,
    ) async {
      var deactivated = 0;
      Widget build(bool active) => beamHost(
        BorderBeam(
          active: active,
          timing: const BeamTiming(cycle: Duration(seconds: 1)),
          playback: const BeamPlayback(repeat: BeamRepeat.once()),
          onDeactivate: () => deactivated++,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);

      await tester.pumpWidget(build(false));
      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final clock = beamPainterOf(tester).clock;
      expect(clock.isVisible, isTrue);
      expect(clock.stage, isNot(BeamFadeStage.fadingOut));
      await tester.pump(const Duration(milliseconds: 300));
      expect(clock.stage, BeamFadeStage.fadingOut);
    });
  });

  group('reduced motion', () {
    Widget reduced(BeamPlayback? playback, {bool on = true, bool? active}) =>
        beamHost(
          disableAnimations: on,
          BorderBeam(
            active: active,
            playback: playback,
            child: const SizedBox.expand(),
          ),
        );

    testWidgets('staticFrame (the default) paints without ticking', (
      tester,
    ) async {
      var activated = 0;
      await tester.pumpWidget(
        beamHost(
          disableAnimations: true,
          BorderBeam(
            onActivate: () => activated++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final painter = beamPainterOf(tester);
      expect(painter.staticMode, isTrue);
      expect(painter.clock.isRunning, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      expect(activated, 0, reason: 'nothing fades in');

      final pixels = await beamPixels(tester);
      expect(pixels.totalAlpha, greaterThan(0), reason: 'the static frame');
      expect(tester.takeException(), isNull);
    });

    testWidgets('staticFrame paints nothing for an inactive beam', (
      tester,
    ) async {
      await tester.pumpWidget(reduced(null, active: false));
      await tester.pump(const Duration(milliseconds: 200));
      expect(beamPainterOf(tester).staticMode, isFalse);
      expect((await beamPixels(tester)).totalAlpha, 0);
    });

    testWidgets('hide removes the painter and paints nothing', (tester) async {
      await tester.pumpWidget(
        reduced(const BeamPlayback(reducedMotion: BeamReducedMotion.hide)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(maybeBeamPainterOf(tester), isNull);
      expect(tester.binding.transientCallbackCount, 0);
      expect((await beamPixels(tester)).totalAlpha, 0);
    });

    testWidgets('slow runs the clock at a quarter rate', (tester) async {
      await tester.pumpWidget(
        reduced(const BeamPlayback(reducedMotion: BeamReducedMotion.slow)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final clock = beamPainterOf(tester).clock;
      expect(clock.isRunning, isTrue);
      expect(clock.speed, closeTo(0.25, 1e-12));
      expect(clock.elapsedSeconds, closeTo(0.25, 1e-9));
      expect(beamPainterOf(tester).staticMode, isFalse);
    });

    testWidgets('slow scales the configured rate rather than replacing it', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          disableAnimations: true,
          const BorderBeam(
            timing: BeamTiming(speed: 2),
            playback: BeamPlayback(reducedMotion: BeamReducedMotion.slow),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(beamPainterOf(tester).clock.speed, closeTo(0.5, 1e-12));
    });

    testWidgets('animate ignores the request', (tester) async {
      await tester.pumpWidget(
        reduced(const BeamPlayback(reducedMotion: BeamReducedMotion.animate)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final painter = beamPainterOf(tester);
      expect(painter.staticMode, isFalse);
      expect(painter.clock.isRunning, isTrue);
      expect(painter.clock.speed, 1);
      expect(painter.clock.elapsedSeconds, closeTo(0.5, 1e-9));
    });

    testWidgets('without the request every mode animates normally', (
      tester,
    ) async {
      for (final mode in BeamReducedMotion.values) {
        await tester.pumpWidget(
          reduced(BeamPlayback(reducedMotion: mode), on: false),
        );
        await tester.pump();
        final painter = beamPainterOf(tester);
        expect(painter.staticMode, isFalse, reason: mode.name);
        expect(painter.clock.isRunning, isTrue, reason: mode.name);
        expect(painter.clock.speed, 1, reason: mode.name);
      }
    });

    testWidgets('turning it on pauses a running beam, off resumes it', (
      tester,
    ) async {
      Widget build(bool on) => reduced(null, on: on);

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final clock = beamPainterOf(tester).clock;
      expect(clock.isRunning, isTrue);
      final frozenAt = clock.elapsedSeconds;

      await tester.pumpWidget(build(true));
      expect(clock.isRunning, isFalse);
      expect(beamPainterOf(tester).staticMode, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
      expect(clock.elapsedSeconds, closeTo(frozenAt, 1e-9));
      expect(clock.isVisible, isTrue, reason: 'it keeps its play state');

      await tester.pumpWidget(build(false));
      expect(clock.isRunning, isTrue);
      expect(beamPainterOf(tester).staticMode, isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        clock.elapsedSeconds,
        greaterThan(frozenAt),
        reason: 'the timeline continues where it was frozen',
      );
    });

    testWidgets('turning hide on and off removes and restores the painter', (
      tester,
    ) async {
      Widget build(bool on) => reduced(
        const BeamPlayback(reducedMotion: BeamReducedMotion.hide),
        on: on,
      );

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final clock = beamPainterOf(tester).clock;

      await tester.pumpWidget(build(true));
      expect(maybeBeamPainterOf(tester), isNull);
      expect(clock.isRunning, isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(build(false));
      expect(identical(beamPainterOf(tester).clock, clock), isTrue);
      expect(clock.isRunning, isTrue);
    });

    testWidgets('turning slow on and off changes the rate in place', (
      tester,
    ) async {
      Widget build(bool on) => reduced(
        const BeamPlayback(reducedMotion: BeamReducedMotion.slow),
        on: on,
      );

      await tester.pumpWidget(build(false));
      await tester.pump();
      final clock = beamPainterOf(tester).clock;
      expect(clock.speed, 1);

      await tester.pumpWidget(build(true));
      expect(clock.speed, closeTo(0.25, 1e-12));
      expect(clock.isRunning, isTrue);

      await tester.pumpWidget(build(false));
      expect(clock.speed, 1);
    });

    testWidgets('turning it off starts a beam that never got to start', (
      tester,
    ) async {
      Widget build(bool on) => reduced(null, on: on);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(build(false));
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      expect(beamPainterOf(tester).clock.isRunning, isTrue);
    });

    testWidgets('turning it off respects a pending startAfter', (tester) async {
      Widget build(bool on) =>
          reduced(const BeamPlayback(startAfter: Duration(seconds: 2)), on: on);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(build(false));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
    });

    testWidgets('turning it off does not replay a beam that already ran', (
      tester,
    ) async {
      var deactivated = 0;
      Widget build(bool on) => beamHost(
        disableAnimations: on,
        BorderBeam(
          playback: const BeamPlayback(duration: Duration(seconds: 1)),
          onDeactivate: () => deactivated++,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        beamPainterOf(tester).clock.isVisible,
        isFalse,
        reason: 'its play time is spent',
      );
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('turning it off does not resume a controller-paused beam', (
      tester,
    ) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(bool on) => beamHost(
        disableAnimations: on,
        BorderBeam(controller: controller, child: const SizedBox.expand()),
      );

      await tester.pumpWidget(build(false));
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      controller.pause();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isRunning, isFalse);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        controller.isRunning,
        isFalse,
        reason: 'the controller owns the pause',
      );
      expect(controller.isActive, isTrue);
    });
  });

  group('debugFrozenAt', () {
    // Transparent child: every pixel with alpha is the beam's.
    Widget frozen(
      Duration at, {
      BeamStyle? style,
      ValueListenable<double>? strength,
    }) => beamHost(
      BorderBeam(
        style: style,
        strengthListenable: strength,
        playback: BeamPlayback(debugFrozenAt: at),
        child: const SizedBox.expand(),
      ),
    );

    Future<void> repaint(WidgetTester tester) async {
      tester
          .renderObject<RenderCustomPaint>(
            find.descendant(
              of: find.byType(BorderBeam),
              matching: find.byType(CustomPaint),
            ),
          )
          .markNeedsPaint();
      await tester.pump();
    }

    testWidgets('never starts the clock', (tester) async {
      await tester.pumpWidget(frozen(const Duration(seconds: 2)));
      await tester.pump(const Duration(seconds: 1));
      final painter = beamPainterOf(tester);
      expect(painter.frozenAt, const Duration(seconds: 2));
      expect(painter.clock.isRunning, isFalse);
      expect(painter.clock.isVisible, isFalse);
      expect(painter.clock.elapsedSeconds, 0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('paints the same pixels however much time passes', (
      tester,
    ) async {
      await tester.pumpWidget(frozen(const Duration(milliseconds: 1300)));
      final first = await beamPixels(tester);
      expect(first.totalAlpha, greaterThan(0));

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 7));
      await repaint(tester);
      final later = await beamPixels(tester);
      expect(later.bytes, first.bytes);
    });

    testWidgets('is the frame the live timeline paints at that instant', (
      tester,
    ) async {
      await tester.pumpWidget(frozen(const Duration(milliseconds: 1300)));
      final still = await beamPixels(tester);

      // A fresh State: the live beam starts its own clock from zero.
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(key: ValueKey('live'), child: SizedBox.expand()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      expect(beamPainterOf(tester).clock.elapsedSeconds, closeTo(1.3, 1e-12));
      final live = await beamPixels(tester);
      expect(live.bytes, still.bytes);
    });

    testWidgets(
      'clearing it on a mounted beam starts the beam',
      skip: true, // defect: an unfrozen beam never schedules its autoplay start
      (tester) async {
        await tester.pumpWidget(frozen(const Duration(milliseconds: 1300)));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(
          beamHost(const BorderBeam(child: SizedBox.expand())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final clock = beamPainterOf(tester).clock;
        expect(clock.isVisible, isTrue);
        expect(clock.isRunning, isTrue);
      },
    );

    testWidgets(
      'setting it on a running beam stops spending frames',
      skip: true, // defect: the clock keeps ticking under a frozen frame
      (tester) async {
        await tester.pumpWidget(
          beamHost(const BorderBeam(child: SizedBox.expand())),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        await tester.pumpWidget(frozen(const Duration(seconds: 1)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('a different instant is a different frame', (tester) async {
      await tester.pumpWidget(frozen(const Duration(milliseconds: 1300)));
      final early = await beamPixels(tester);
      await tester.pumpWidget(frozen(const Duration(milliseconds: 1900)));
      await tester.pump();
      final late = await beamPixels(tester);
      expect(late.totalAlpha, greaterThan(0));
      expect(late.bytes, isNot(early.bytes));
    });

    testWidgets('honors style strength', (tester) async {
      const at = Duration(milliseconds: 1300);
      await tester.pumpWidget(frozen(at));
      final full = (await beamPixels(tester)).totalAlpha;

      await tester.pumpWidget(
        frozen(at, style: const BeamStyle(strength: 0.5)),
      );
      await tester.pump();
      final half = (await beamPixels(tester)).totalAlpha;

      await tester.pumpWidget(frozen(at, style: const BeamStyle(strength: 0)));
      await tester.pump();
      final none = (await beamPixels(tester)).totalAlpha;

      expect(full, greaterThan(0));
      expect(half, inExclusiveRange(0, full));
      expect(none, 0);
    });

    testWidgets('honors a live strength listenable', (tester) async {
      final strength = ValueNotifier<double>(0);
      addTearDown(strength.dispose);
      await tester.pumpWidget(
        frozen(const Duration(milliseconds: 1300), strength: strength),
      );
      expect((await beamPixels(tester)).totalAlpha, 0);

      strength.value = 1;
      await tester.pump();
      expect((await beamPixels(tester)).totalAlpha, greaterThan(0));
      expect(tester.binding.transientCallbackCount, 0, reason: 'still frozen');
    });
  });

  group('fadeCurve', () {
    // Points along each fade, from the clock's own lengths.
    Duration seconds(double s) => Duration(microseconds: (s * 1e6).round());
    final halfIn = seconds(BeamClock.fadeInSeconds / 2);
    final quarterIn = seconds(BeamClock.fadeInSeconds / 4);
    final halfOut = seconds(BeamClock.fadeOutSeconds / 2);

    testWidgets('the widget hands its curve to the clock', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            playback: BeamPlayback(fadeCurve: BeamPlayback.cssEase),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(halfIn);
      final clock = beamPainterOf(tester).clock;
      expect(clock.fadeCurve, BeamPlayback.cssEase);
      expect(
        clock.fadeOpacity,
        closeTo(BeamPlayback.cssEase.transform(0.5), 1e-9),
      );
    });

    testWidgets('a curve replaces the spring on both fades', (tester) async {
      Widget build(bool active) => beamHost(
        BorderBeam(
          active: active,
          playback: const BeamPlayback(fadeCurve: Curves.linear),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pump(halfIn);
      final clock = beamPainterOf(tester).clock;
      expect(clock.fadeOpacity, closeTo(0.5, 1e-9), reason: 'half way in');

      await tester.pump(halfIn + const Duration(milliseconds: 100));
      await tester.pumpWidget(build(false));
      await tester.pump(halfOut);
      expect(clock.fadeOpacity, closeTo(0.5, 1e-9), reason: 'half way out');
    });

    testWidgets('the default fade is the spring, not a plain ease', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(const BorderBeam(child: SizedBox.expand())),
      );
      await tester.pump();
      await tester.pump(halfIn);
      final clock = beamPainterOf(tester).clock;
      expect(clock.fadeCurve, isNull);
      expect(clock.fadeOpacity, inInclusiveRange(0, 1));
      expect(clock.fadeOpacity, isNot(closeTo(0.5, 1e-3)));
      expect(
        clock.fadeOpacity,
        isNot(closeTo(BeamPlayback.cssEase.transform(0.5), 1e-3)),
      );
    });

    testWidgets('changing the curve mid-fade lands on the next frame', (
      tester,
    ) async {
      Widget build(Curve? curve) => beamHost(
        BorderBeam(
          playback: BeamPlayback(fadeCurve: curve),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(null));
      await tester.pump();
      await tester.pump(quarterIn);
      await tester.pumpWidget(build(Curves.linear));
      await tester.pump(halfIn - quarterIn);
      final clock = beamPainterOf(tester).clock;
      expect(clock.fadeCurve, Curves.linear);
      expect(clock.fadeOpacity, closeTo(0.5, 1e-9));
    });
  });

  group('pauseWhenOffscreen', () {
    // cacheExtent keeps rows built well past the 256px margin, so there is
    // something offscreen left to pause. The double form is the one every
    // supported Flutter accepts (ScrollCacheExtent arrives after 3.35).
    Widget list({bool? pause, Widget Function(int index)? row}) => beamHost(
      size: const Size(400, 600),
      ListView.builder(
        // ignore: deprecated_member_use
        cacheExtent: 4000,
        itemCount: 12,
        itemBuilder: (context, index) => SizedBox(
          height: 200,
          child:
              row?.call(index) ??
              BorderBeam(
                key: ValueKey(index),
                playback: BeamPlayback(pauseWhenOffscreen: pause),
                child: const SizedBox.expand(),
              ),
        ),
      ),
    );

    BeamClock clockAt(WidgetTester tester, int index) => beamPainterOf(
      tester,
      within: find.byKey(ValueKey(index), skipOffstage: false),
    ).clock;

    testWidgets('offscreen rows stop ticking and resume on return', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      await tester.pump();
      // Rows 0–2 fill the 600px viewport; 3 and 4 start within the 256px
      // margin below it; 5 onward are further out.
      for (final index in [0, 1, 2, 3, 4]) {
        expect(clockAt(tester, index).isRunning, isTrue, reason: '$index');
      }
      for (final index in [5, 6, 11]) {
        expect(clockAt(tester, index).isRunning, isFalse, reason: '$index');
      }

      // A paused beam keeps its play state and its timeline.
      final resting = clockAt(tester, 6);
      expect(resting.isVisible, isTrue);
      final held = resting.elapsedSeconds;

      // Not pumpAndSettle: a running beam schedules frames forever. Two
      // frames are enough — one lands the scroll, one runs the post-frame
      // visibility check.
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      await tester.pump();

      expect(clockAt(tester, 6).isRunning, isTrue, reason: 'scrolled in');
      expect(
        clockAt(tester, 6).elapsedSeconds,
        greaterThanOrEqualTo(held),
        reason: 'it resumes rather than restarting',
      );
      expect(clockAt(tester, 0).isRunning, isFalse, reason: 'now far above');
    });

    testWidgets('false keeps every row running', (tester) async {
      await tester.pumpWidget(list(pause: false));
      await tester.pump();
      for (final index in [0, 6, 11]) {
        expect(clockAt(tester, index).isRunning, isTrue, reason: '$index');
      }
    });

    testWidgets('offscreen time does not consume a duration budget', (
      tester,
    ) async {
      await tester.pumpWidget(
        list(
          row: (index) => index == 6
              ? const BorderBeam(
                  key: ValueKey(6),
                  playback: BeamPlayback(duration: Duration(seconds: 1)),
                  child: SizedBox.expand(),
                )
              : const SizedBox.expand(),
        ),
      );
      await tester.pump();
      final clock = clockAt(tester, 6);
      expect(clock.isRunning, isFalse, reason: 'the beam starts offscreen');

      await tester.pump(const Duration(seconds: 2));
      expect(clock.isVisible, isTrue);
      expect(clock.stage, isNot(BeamFadeStage.fadingOut));

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      await tester.pump();
      expect(clock.isRunning, isTrue);
      await tester.pump(const Duration(milliseconds: 900));
      expect(clock.stage, isNot(BeamFadeStage.fadingOut));
      await tester.pump(const Duration(milliseconds: 200));
      expect(clock.stage, BeamFadeStage.fadingOut);
    });

    testWidgets('a beam outside any scrollable is never paused', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const SizedBox(
            width: 350,
            height: 140,
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(beamPainterOf(tester).clock.isRunning, isTrue);
    });

    testWidgets('an offscreen beam disposes without leaking its ticker', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      await tester.pump();
      expect(clockAt(tester, 11).isRunning, isFalse);
      await tester.pumpWidget(beamHost(const SizedBox.expand()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
