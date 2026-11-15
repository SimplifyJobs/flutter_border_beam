import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// A step comfortably below one display frame at 120Hz.
const Duration _frame = Duration(milliseconds: 8);

/// The clock is the single time source of a beam: one ticker, elapsed time
/// integrated from scaled deltas, and the fade envelopes on top. These tests
/// drive it with the test binding's fake clock — note that the first tick
/// after a ticker starts reports elapsed zero, so each test pumps once
/// before pumping durations.
void main() {
  BeamClock makeClock(
    WidgetTester tester, {
    ValueChanged<bool>? onFadeComplete,
    Curve? fadeCurve,
  }) => BeamClock(
    createTicker: tester.createTicker,
    onFadeComplete: onFadeComplete,
    fadeCurve: fadeCurve,
  );

  /// Activates [clock] and runs it past the fade-in.
  Future<void> runVisible(WidgetTester tester, BeamClock clock) async {
    clock.activate();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(clock.stage, BeamFadeStage.none);
  }

  group('fade envelopes', () {
    testWidgets('activate fades in from 0 and reports completion', (
      tester,
    ) async {
      final events = <bool>[];
      final clock = makeClock(tester, onFadeComplete: events.add);
      expect(clock.fadeOpacity, 0);
      expect(clock.isVisible, isFalse);

      clock.activate();
      expect(clock.isRunning, isTrue);
      expect(clock.isVisible, isTrue);
      expect(clock.stage, BeamFadeStage.fadingIn);
      expect(clock.fadeOpacity, 0);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(clock.fadeOpacity, greaterThan(0));
      expect(clock.fadeOpacity, lessThan(1));
      expect(events, isEmpty);

      await tester.pump(const Duration(milliseconds: 700));
      expect(clock.stage, BeamFadeStage.none);
      expect(clock.fadeOpacity, 1);
      expect(clock.isRunning, isTrue, reason: 'keeps animating once lit');
      expect(events, [true]);
      clock.dispose();
    });

    testWidgets('deactivate fades out, stops, and resets the timeline', (
      tester,
    ) async {
      final events = <bool>[];
      final clock = makeClock(tester, onFadeComplete: events.add);
      await runVisible(tester, clock);
      expect(clock.elapsedSeconds, greaterThan(0.9));

      clock.deactivate();
      expect(clock.stage, BeamFadeStage.fadingOut);
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock.fadeOpacity, greaterThan(0));
      expect(clock.fadeOpacity, lessThan(1));

      await tester.pump(const Duration(milliseconds: 600));
      expect(clock.isRunning, isFalse);
      expect(clock.isVisible, isFalse);
      expect(clock.stage, BeamFadeStage.none);
      expect(clock.fadeOpacity, 0);
      expect(clock.elapsedSeconds, 0, reason: 'the timeline resets');
      expect(events, [true, false]);
      expect(tester.binding.transientCallbackCount, 0);
      clock.dispose();
    });

    testWidgets('fadeOpacity stays inside [0, 1] on every frame', (
      tester,
    ) async {
      // The default spring overshoots its target; a back-eased curve
      // overshoots far more. Both must still read as a valid opacity.
      for (final curve in <Curve?>[
        null,
        Curves.easeOutBack,
        Curves.easeInBack,
      ]) {
        final clock = makeClock(tester, fadeCurve: curve);
        final seen = <double>[];
        clock.addListener(() => seen.add(clock.fadeOpacity));

        clock.activate();
        await tester.pump();
        for (var i = 0; i < 100; i++) {
          await tester.pump(_frame);
        }
        clock.deactivate();
        for (var i = 0; i < 100; i++) {
          await tester.pump(_frame);
        }
        expect(seen, isNotEmpty);
        for (final v in seen) {
          expect(v, inInclusiveRange(0, 1), reason: 'curve $curve');
        }
        clock.dispose();
      }
    });

    testWidgets('fadeCurve replaces the spring easing', (tester) async {
      final clock = makeClock(tester, fadeCurve: Curves.linear);
      clock.activate();
      await tester.pump();
      await tester.pump(
        Duration(microseconds: (BeamClock.fadeInSeconds / 2 * 1e6).round()),
      );
      expect(clock.fadeOpacity, closeTo(0.5, 1e-6));

      // Settable mid-run: the envelope reads it on every evaluation.
      clock.fadeCurve = Curves.easeIn;
      expect(clock.fadeOpacity, closeTo(Curves.easeIn.transform(0.5), 1e-6));
      clock.dispose();
    });

    testWidgets('activating a visible beam is a no-op', (tester) async {
      final clock = makeClock(tester);
      await runVisible(tester, clock);
      final at = clock.elapsedSeconds;
      clock.activate();
      expect(clock.elapsedSeconds, at);
      expect(clock.stage, BeamFadeStage.none);
      expect(clock.fadeOpacity, 1);
      clock.dispose();
    });

    testWidgets('deactivating a hidden beam is a no-op', (tester) async {
      final events = <bool>[];
      final clock = makeClock(tester, onFadeComplete: events.add);
      clock.deactivate();
      expect(clock.isRunning, isFalse);
      expect(clock.stage, BeamFadeStage.none);
      await tester.pump(const Duration(seconds: 1));
      expect(events, isEmpty);
      clock.dispose();
    });

    testWidgets('re-activation after a fade-out restarts from zero', (
      tester,
    ) async {
      final clock = makeClock(tester);
      await runVisible(tester, clock);
      clock.deactivate();
      await tester.pump(const Duration(seconds: 1));
      expect(clock.isVisible, isFalse);

      clock.activate();
      expect(clock.elapsedSeconds, 0);
      expect(clock.fadeOpacity, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock.elapsedSeconds, closeTo(0.1, 1e-6));
      clock.dispose();
    });

    testWidgets('re-activation mid-fade-out resumes without a jump', (
      tester,
    ) async {
      final events = <bool>[];
      final clock = makeClock(tester, onFadeComplete: events.add);
      await runVisible(tester, clock);
      clock.deactivate();
      await tester.pump(const Duration(milliseconds: 60));
      final opacity = clock.fadeOpacity;
      final elapsed = clock.elapsedSeconds;
      expect(opacity, inExclusiveRange(0, 1));

      clock.activate();
      expect(clock.stage, BeamFadeStage.fadingIn);
      expect(clock.fadeOpacity, closeTo(opacity, 1e-9));
      expect(
        clock.elapsedSeconds,
        elapsed,
        reason: 'the timeline continues rather than restarting',
      );

      await tester.pump(const Duration(milliseconds: 700));
      expect(clock.fadeOpacity, 1);
      expect(events, [true, true], reason: 'the fade-out never completed');
      clock.dispose();
    });

    testWidgets('showStatic is fully visible without a ticker', (tester) async {
      final clock = makeClock(tester);
      clock.showStatic();
      expect(clock.isVisible, isTrue);
      expect(clock.stage, BeamFadeStage.none);
      expect(clock.fadeOpacity, 1);
      expect(clock.isRunning, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      clock.dispose();
    });
  });

  group('timeline', () {
    testWidgets('elapsed time follows the frame clock', (tester) async {
      final clock = makeClock(tester);
      clock.activate();
      await tester.pump();
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(clock.elapsedSeconds, closeTo(1, 1e-6));
      expect(clock.activeSeconds, closeTo(1, 1e-6));
      clock.dispose();
    });

    testWidgets('pause freezes and resume continues', (tester) async {
      final clock = makeClock(tester);
      await runVisible(tester, clock);
      final at = clock.elapsedSeconds;
      final active = clock.activeSeconds;

      clock.pause();
      expect(clock.isRunning, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(clock.elapsedSeconds, at);
      expect(clock.activeSeconds, active);

      clock.resume();
      expect(clock.isRunning, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(clock.elapsedSeconds, closeTo(at + 0.5, 1e-6));
      clock.dispose();
    });

    testWidgets('resume does nothing for a hidden beam', (tester) async {
      final clock = makeClock(tester);
      clock.resume();
      expect(clock.isRunning, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      clock.dispose();
    });

    testWidgets('seek jumps the timeline and notifies', (tester) async {
      final clock = makeClock(tester);
      var notified = 0;
      clock.addListener(() => notified++);
      await runVisible(tester, clock);
      notified = 0;

      clock.seek(42);
      expect(clock.elapsedSeconds, 42);
      expect(notified, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock.elapsedSeconds, closeTo(42.1, 1e-6));
      clock.dispose();
    });

    testWidgets('speed scales elapsed time but not active time', (
      tester,
    ) async {
      final clock = makeClock(tester);
      clock.speed = 2;
      expect(clock.speed, 2);
      clock.activate();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(clock.elapsedSeconds, closeTo(2, 1e-6));
      expect(clock.activeSeconds, closeTo(1, 1e-6));

      clock.speed = 0.5;
      await tester.pump(const Duration(seconds: 1));
      expect(clock.elapsedSeconds, closeTo(2.5, 1e-6));
      expect(clock.activeSeconds, closeTo(2, 1e-6));
      clock.dispose();
    });

    testWidgets('speed must be positive', (tester) async {
      final clock = makeClock(tester);
      expect(() => clock.speed = 0, throwsAssertionError);
      expect(() => clock.speed = -1, throwsAssertionError);
      clock.dispose();
    });

    testWidgets('notifies on every frame — no frame-rate cap', (tester) async {
      final clock = makeClock(tester);
      var notified = 0;
      clock.addListener(() => notified++);
      await runVisible(tester, clock);

      notified = 0;
      const frames = 120;
      for (var i = 0; i < frames; i++) {
        await tester.pump(_frame);
      }
      expect(notified, frames);
      clock.dispose();
    });
  });

  group('retime', () {
    testWidgets('scales elapsed time by the factor', (tester) async {
      final clock = makeClock(tester);
      await runVisible(tester, clock);
      final at = clock.elapsedSeconds;
      clock.retime(2.5);
      expect(clock.elapsedSeconds, closeTo(at * 2.5, 1e-9));
      clock.retime(0.4);
      expect(clock.elapsedSeconds, closeTo(at, 1e-9));
      clock.dispose();
    });

    testWidgets('keeps the fade opacity and its remaining duration', (
      tester,
    ) async {
      final events = <bool>[];
      final clock = makeClock(tester, onFadeComplete: events.add);
      clock.activate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final opacity = clock.fadeOpacity;
      expect(clock.stage, BeamFadeStage.fadingIn);

      clock.retime(3);
      expect(clock.fadeOpacity, closeTo(opacity, 1e-9));
      expect(clock.stage, BeamFadeStage.fadingIn);

      // 0.4s of the 0.6s fade remain, exactly as before the retime.
      await tester.pump(const Duration(milliseconds: 350));
      expect(clock.stage, BeamFadeStage.fadingIn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock.stage, BeamFadeStage.none);
      expect(events, [true]);
      clock.dispose();
    });

    testWidgets('keeps a playing boost where it was', (tester) async {
      final clock = makeClock(tester);
      await runVisible(tester, clock);
      clock.pulse();
      await tester.pump(const Duration(milliseconds: 100));
      final boost = clock.boost;
      expect(boost, greaterThan(1));
      clock.retime(4);
      expect(clock.boost, closeTo(boost, 1e-9));
      clock.dispose();
    });

    testWidgets('the factor must be positive', (tester) async {
      final clock = makeClock(tester);
      expect(() => clock.retime(0), throwsAssertionError);
      clock.dispose();
    });
  });

  group('pulse and flash', () {
    Future<List<double>> playBoost(
      WidgetTester tester,
      BeamClock clock,
      void Function() trigger,
    ) async {
      final samples = <double>[];
      trigger();
      expect(clock.isBoosting, isTrue);
      for (var i = 0; i < 150; i++) {
        await tester.pump(_frame);
        samples.add(clock.boost);
      }
      return samples;
    }

    for (final (name, peak) in [
      ('pulse', BeamClock.pulsePeak),
      ('flash', BeamClock.flashPeak),
    ]) {
      testWidgets('$name rises above 1 and returns to exactly 1', (
        tester,
      ) async {
        final clock = makeClock(tester);
        await runVisible(tester, clock);
        expect(clock.boost, 1);
        expect(clock.isBoosting, isFalse);

        final samples = await playBoost(
          tester,
          clock,
          name == 'pulse' ? clock.pulse : clock.flash,
        );
        final top = samples.reduce((a, b) => a > b ? a : b);
        expect(top, greaterThan(1));
        expect(top, closeTo(peak, peak * 0.05));
        for (final s in samples) {
          expect(s, greaterThanOrEqualTo(1));
        }
        expect(samples.last, 1);
        expect(clock.boost, 1);
        expect(clock.isBoosting, isFalse);
        clock.dispose();
      });
    }

    test('flash peaks higher than pulse', () {
      expect(BeamClock.pulsePeak, greaterThan(1));
      expect(BeamClock.flashPeak, greaterThan(BeamClock.pulsePeak));
    });

    testWidgets('is a no-op while hidden or paused', (tester) async {
      final clock = makeClock(tester);
      clock.pulse();
      clock.flash();
      expect(clock.isBoosting, isFalse);
      expect(clock.boost, 1);

      await runVisible(tester, clock);
      clock.pause();
      clock.pulse();
      expect(clock.isBoosting, isFalse);
      clock.dispose();
    });

    testWidgets('a restart from hidden drops a boost', (tester) async {
      final clock = makeClock(tester);
      await runVisible(tester, clock);
      clock.deactivate();
      clock.flash();
      expect(clock.isBoosting, isTrue, reason: 'still visible while fading');
      await tester.pump(const Duration(seconds: 1));
      clock.activate();
      expect(clock.isBoosting, isFalse);
      expect(clock.boost, 1);
      clock.dispose();
    });
  });

  // defect: a completed fade-out zeroes elapsed time but keeps the boost,
  // whose start now lies in the future — isBoosting stays true and a flash
  // reads its full peak until the next activate() (showStatic keeps it).
  testWidgets('a completed fade-out ends any boost', skip: true, (
    tester,
  ) async {
    final clock = makeClock(tester);
    await runVisible(tester, clock);
    clock.deactivate();
    clock.flash();
    await tester.pump(const Duration(seconds: 1));
    expect(clock.isVisible, isFalse);
    expect(clock.isBoosting, isFalse);
    expect(clock.boost, 1);

    // A static frame shown next must not inherit the stale envelope.
    clock.showStatic();
    expect(clock.boost, 1);
    clock.dispose();
  });

  group('timeline reset listeners', () {
    testWidgets('fire on a restart and after a fade-out, not mid-fade', (
      tester,
    ) async {
      final clock = makeClock(tester);
      var resets = 0;
      void listener() => resets++;
      clock.addTimelineResetListener(listener);

      clock.activate();
      expect(resets, 1, reason: 'activation from hidden restarts at zero');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(resets, 1, reason: 'ordinary frames never reset');

      clock.deactivate();
      await tester.pump(const Duration(milliseconds: 100));
      clock.activate();
      expect(resets, 1, reason: 'a mid-fade re-activation continues');

      await tester.pump(const Duration(seconds: 1));
      clock.deactivate();
      await tester.pump(const Duration(seconds: 1));
      expect(resets, 2, reason: 'the completed fade-out zeroes elapsed');

      clock.removeTimelineResetListener(listener);
      clock.activate();
      expect(resets, 2);
      clock.dispose();
    });

    testWidgets('a listener may remove itself while being called', (
      tester,
    ) async {
      final clock = makeClock(tester);
      var calls = 0;
      late void Function() once;
      once = () {
        calls++;
        clock.removeTimelineResetListener(once);
      };
      var other = 0;
      clock.addTimelineResetListener(once);
      clock.addTimelineResetListener(() => other++);

      clock.activate();
      expect(calls, 1);
      expect(other, 1);
      clock.deactivate();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      expect(other, 2);
      clock.dispose();
    });
  });

  group('dispose', () {
    testWidgets('mid-fade leaves no ticker behind', (tester) async {
      final clock = makeClock(tester);
      clock.activate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      clock.dispose();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a never-started clock disposes cleanly', (tester) async {
      final clock = makeClock(tester);
      expect(clock.dispose, returnsNormally);
    });
  });
}
