import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Playback beyond plain on/off: what reduced motion does to the four
/// behaviors, when a repeat budget ends a run, and the one-shot brightness
/// envelopes.
void main() {
  group('reducedMotion', () {
    testWidgets('animate ignores the platform request', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam.rotate(
            playback: BeamPlayback(reducedMotion: BeamReducedMotion.animate),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final clock = _clock(tester);
      expect(clock.isRunning, isTrue);
      expect(clock.elapsedSeconds, closeTo(0.5, 1e-9));
      expect(_painter(tester).staticMode, isFalse);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('staticFrame freezes on one frame', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam.rotate(
            playback: BeamPlayback(
              reducedMotion: BeamReducedMotion.staticFrame,
            ),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      final painter = _painter(tester);
      expect(painter.staticMode, isTrue);
      expect(painter.clock.isRunning, isFalse);
    });

    testWidgets('staticFrame is the default', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam.rotate(child: SizedBox.expand()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).staticMode, isTrue);
    });

    testWidgets('hide paints nothing and never ticks', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam.rotate(
            playback: BeamPlayback(reducedMotion: BeamReducedMotion.hide),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_painters(tester), isEmpty, reason: 'no painter is mounted');
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('hide paints the beam again once the request lifts', (
      tester,
    ) async {
      Widget build(bool reduced) => _host(
        disableAnimations: reduced,
        const BorderBeam.rotate(
          playback: BeamPlayback(reducedMotion: BeamReducedMotion.hide),
          child: SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(seconds: 1));
      expect(_painters(tester), isEmpty);

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painters(tester), isNotEmpty);
      expect(_clock(tester).isRunning, isTrue);
    });

    testWidgets('slow runs the clock at a quarter rate', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam.rotate(
            playback: BeamPlayback(reducedMotion: BeamReducedMotion.slow),
            child: SizedBox.expand(),
          ),
        ),
      );
      final clock = _clock(tester);
      expect(clock.speed, 0.25);
      expect(_painter(tester).staticMode, isFalse);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(clock.elapsedSeconds, closeTo(0.25, 1e-9));
    });

    testWidgets('slow scales the configured speed rather than replacing it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam.rotate(
            timing: BeamTiming(speed: 2),
            playback: BeamPlayback(reducedMotion: BeamReducedMotion.slow),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(_clock(tester).speed, 0.5);
    });

    testWidgets('slow restores the rate when the request lifts', (
      tester,
    ) async {
      Widget build(bool reduced) => _host(
        disableAnimations: reduced,
        const BorderBeam.rotate(
          timing: BeamTiming(speed: 2),
          playback: BeamPlayback(reducedMotion: BeamReducedMotion.slow),
          child: SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(true));
      final clock = _clock(tester);
      expect(clock.speed, 0.5);

      await tester.pumpWidget(build(false));
      expect(clock.speed, 2);

      await tester.pumpWidget(build(true));
      expect(clock.speed, 0.5);
    });
  });

  group('repeat', () {
    testWidgets('once fades out after a single cycle', (tester) async {
      var deactivated = 0;
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            playback: BeamPlayback(repeat: const BeamRepeat.once()),
            onDeactivate: () => deactivated++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      // The rotate cycle is 1.96s; nothing has expired before it.
      await tester.pump(const Duration(milliseconds: 1900));
      expect(_clock(tester).stage, isNot(BeamFadeStage.fadingOut));
      expect(deactivated, 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _clock(tester).stage,
        BeamFadeStage.fadingOut,
        reason: 'the last cycle ends on a fade, not a cut',
      );
      expect(deactivated, 0, reason: 'the fade has not finished yet');

      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);
      expect(_clock(tester).isVisible, isFalse);
    });

    testWidgets('count(3) runs three cycles', (tester) async {
      var deactivated = 0;
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            playback: BeamPlayback(repeat: const BeamRepeat.count(3)),
            onDeactivate: () => deactivated++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5800));
      expect(_clock(tester).stage, isNot(BeamFadeStage.fadingOut));

      await tester.pump(const Duration(milliseconds: 200));
      expect(_clock(tester).stage, BeamFadeStage.fadingOut);
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);
    });

    testWidgets('the gap counts toward the budget', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            timing: BeamTiming(cycleGap: Duration(seconds: 1)),
            playback: BeamPlayback(repeat: BeamRepeat.once()),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
      expect(
        _clock(tester).stage,
        isNot(BeamFadeStage.fadingOut),
        reason: 'the rest between sweeps is part of the cycle',
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(_clock(tester).stage, BeamFadeStage.fadingOut);
    });

    testWidgets('forever never stops on its own', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            playback: BeamPlayback(repeat: BeamRepeat.forever()),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      expect(_clock(tester).isVisible, isTrue);
      expect(_clock(tester).stage, isNot(BeamFadeStage.fadingOut));
    });

    testWidgets('a restart runs the budget again', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            controller: controller,
            playback: const BeamPlayback(repeat: BeamRepeat.once()),
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2000));
      expect(_clock(tester).stage, BeamFadeStage.fadingOut);
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.isActive, isFalse);

      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.isActive, isTrue);
      expect(_clock(tester).stage, isNot(BeamFadeStage.fadingOut));
    });
  });

  group('pulse and flash', () {
    testWidgets('pulse rises and settles back to rest', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final clock = _clock(tester);
      expect(clock.boost, 1);

      controller.pulse();
      expect(clock.isBoosting, isTrue);
      await tester.pump(const Duration(milliseconds: 240));
      expect(clock.boost, closeTo(BeamClock.pulsePeak, 1e-6));

      await tester.pump(const Duration(milliseconds: 180));
      expect(clock.boost, greaterThan(1));
      expect(clock.boost, lessThan(BeamClock.pulsePeak));

      await tester.pump(const Duration(milliseconds: 200));
      expect(clock.boost, 1);
      expect(clock.isBoosting, isFalse);
    });

    testWidgets('flash holds at the peak before decaying', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final clock = _clock(tester);

      controller.flash();
      expect(clock.boost, closeTo(BeamClock.flashPeak, 1e-9));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        clock.boost,
        closeTo(BeamClock.flashPeak, 1e-9),
        reason: 'the hold keeps it at full for 120ms',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock.boost, lessThan(BeamClock.flashPeak));
      await tester.pump(const Duration(milliseconds: 250));
      expect(clock.boost, 1);
    });

    testWidgets('cycle retiming preserves a pulse envelope in progress', (
      tester,
    ) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(Duration cycle) => _host(
        BorderBeam.rotate(
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

      await tester.pumpWidget(build(const Duration(seconds: 4)));
      expect(clock.boost, closeTo(before, 1e-9));
      await tester.pump(const Duration(milliseconds: 140));
      expect(clock.boost, closeTo(BeamClock.pulsePeak, 1e-6));
    });

    testWidgets('both are no-ops while the beam is hidden', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      final clock = _clock(tester);
      expect(clock.isVisible, isFalse);

      controller.pulse();
      expect(clock.isBoosting, isFalse);
      expect(clock.boost, 1);
      controller.flash();
      expect(clock.isBoosting, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a boost is dropped when the beam restarts', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final clock = _clock(tester);
      controller.flash();
      expect(clock.isBoosting, isTrue);

      controller.stop();
      await tester.pump(const Duration(milliseconds: 600));
      controller.start();
      await tester.pump();
      expect(clock.isBoosting, isFalse);
      expect(clock.boost, 1);
    });

    testWidgets('a paused beam takes no boost', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      controller.pause();
      await tester.pump();

      controller.pulse();
      expect(_clock(tester).isBoosting, isFalse);
    });
  });
}
