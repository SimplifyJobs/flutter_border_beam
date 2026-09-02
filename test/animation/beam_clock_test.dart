import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TickerProvider vsync;

  BeamClock makeClock({double? maxFps, ValueChanged<bool>? onFadeComplete}) =>
      BeamClock(
        createTicker: vsync.createTicker,
        maxFps: maxFps,
        onFadeComplete: onFadeComplete,
      );

  testWidgets('activate fades in and completes', (tester) async {
    vsync = tester;
    final events = <bool>[];
    final clock = makeClock(onFadeComplete: events.add);

    expect(clock.fadeOpacity, 0);
    clock.activate();
    expect(clock.isRunning, isTrue);
    expect(clock.stage, BeamFadeStage.fadingIn);

    // First tick anchors the ticker's start time at elapsed zero.
    await tester.pump();
    // Sample early: the spring fade converges well before its nominal 0.6s.
    await tester.pump(const Duration(milliseconds: 80));
    expect(clock.fadeOpacity, greaterThan(0));
    expect(clock.fadeOpacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 620));
    expect(clock.stage, BeamFadeStage.none);
    expect(clock.fadeOpacity, 1);
    expect(events, [true]);
    clock.dispose();
  });

  testWidgets('deactivate fades out, stops, and resets the timeline', (
    tester,
  ) async {
    vsync = tester;
    final events = <bool>[];
    final clock = makeClock(onFadeComplete: events.add);

    clock.activate();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsedSeconds, greaterThan(0.9));

    clock.deactivate();
    expect(clock.stage, BeamFadeStage.fadingOut);
    await tester.pump(const Duration(milliseconds: 600));
    expect(clock.isRunning, isFalse);
    expect(clock.isVisible, isFalse);
    expect(clock.fadeOpacity, 0);
    expect(clock.elapsedSeconds, 0, reason: 'timeline resets after fade-out');
    expect(events, [true, false]);
    clock.dispose();
  });

  testWidgets('re-activation restarts the timeline from zero', (tester) async {
    vsync = tester;
    final clock = makeClock();

    clock.activate();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    clock.deactivate();
    await tester.pump(const Duration(seconds: 1));
    clock.activate();
    expect(clock.elapsedSeconds, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(clock.elapsedSeconds, lessThan(0.2));
    clock.dispose();
  });

  testWidgets('pause freezes and resume continues', (tester) async {
    vsync = tester;
    final clock = makeClock();

    clock.activate();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final at = clock.elapsedSeconds;
    expect(at, greaterThan(0.9));
    clock.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsedSeconds, at);
    clock.resume();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsedSeconds, greaterThan(at + 0.9));
    clock.dispose();
  });

  testWidgets('speed scales elapsed time', (tester) async {
    vsync = tester;
    final clock = makeClock();

    clock.activate();
    clock.speed = 2;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsedSeconds, closeTo(2, 0.1));
    clock.dispose();
  });

  testWidgets('seek jumps the timeline', (tester) async {
    vsync = tester;
    final clock = makeClock();

    clock.activate();
    clock.seek(42);
    expect(clock.elapsedSeconds, 42);
    clock.dispose();
  });

  testWidgets('maxFps caps steady-state notifications', (tester) async {
    vsync = tester;
    final clock = makeClock(maxFps: 30);
    var notifications = 0;
    clock.addListener(() => notifications++);

    clock.activate();
    await tester.pump();
    // Get past the fade (fade notifies at full rate).
    await tester.pump(const Duration(seconds: 1));
    notifications = 0;
    // 60 frames at ~8ms ≈ 0.48s of 120fps input.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 8));
    }
    // At a 30fps cap that window allows ~15-16 notifications; allow slack.
    expect(notifications, lessThan(25));
    expect(notifications, greaterThan(8));
    clock.dispose();
  });

  testWidgets('mid-fade-out re-activation resumes without opacity jump', (
    tester,
  ) async {
    vsync = tester;
    final clock = makeClock();

    clock.activate();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    clock.deactivate();
    await tester.pump(const Duration(milliseconds: 60));
    final midOpacity = clock.fadeOpacity;
    expect(midOpacity, lessThan(1));
    expect(midOpacity, greaterThan(0));

    clock.activate();
    expect(clock.stage, BeamFadeStage.fadingIn);
    // Fade resumes from the interrupted opacity, not from zero.
    expect(clock.fadeOpacity, closeTo(midOpacity, 0.05));
    await tester.pump(const Duration(milliseconds: 700));
    expect(clock.fadeOpacity, 1);
    clock.dispose();
  });
}
