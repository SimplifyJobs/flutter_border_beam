import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_clock.dart';

/// A step comfortably below one display frame at 60Hz.
const Duration _frame = Duration(milliseconds: 16);

/// `WaveClock`: one ticker driving a wave's progress from wherever it is to
/// a target, at the speed of a full run. Driven by the test binding's fake
/// clock — the first tick after a ticker starts reports elapsed zero, so
/// each run pumps once before pumping durations.
void main() {
  // Clocks already disposed, so the tear-down never disposes one twice.
  final disposed = Expando<bool>('disposed');

  void disposeClock(WaveClock clock) {
    if (disposed[clock] ?? false) return;
    disposed[clock] = true;
    clock.dispose();
  }

  /// A clock on a test vsync. Each test still disposes its clock before it
  /// returns — flutter_test checks for live tickers before tear-downs run —
  /// and the tear-down disposes one a failed expectation left behind.
  WaveClock makeClock({double progress = 0}) {
    final clock = WaveClock(vsync: const TestVSync(), progress: progress);
    addTearDown(() => disposeClock(clock));
    return clock;
  }

  testWidgets('starts at rest where it is told, clamped to 0–1', (
    tester,
  ) async {
    final idle = makeClock();
    expect(idle.progress, 0);
    expect(idle.isRunning, isFalse);
    expect(idle.target, isNull);
    final past = makeClock(progress: 1.5);
    expect(past.progress, 1);
    final before = makeClock(progress: -1);
    expect(before.progress, 0);
    disposeClock(idle);
    disposeClock(past);
    disposeClock(before);
  });

  testWidgets('a full run takes fullSeconds', (tester) async {
    final clock = makeClock();
    clock.runTo(1, fullSeconds: 2);
    expect(clock.isRunning, isTrue);
    expect(clock.target, 1);

    await tester.pump();
    expect(clock.progress, 0, reason: 'the first tick is at elapsed 0');
    await tester.pump(const Duration(seconds: 1));
    expect(clock.progress, closeTo(0.5, 1e-9));
    await tester.pump(const Duration(milliseconds: 999));
    expect(clock.progress, lessThan(1));
    expect(clock.isRunning, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(clock.progress, 1);
    expect(clock.isRunning, isFalse);
    expect(clock.target, isNull);
    disposeClock(clock);
  });

  testWidgets('a half run takes half the time', (tester) async {
    final clock = makeClock(progress: 0.5);
    clock.runTo(1, fullSeconds: 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.progress, closeTo(0.75, 1e-9));
    await tester.pump(const Duration(milliseconds: 499));
    expect(clock.isRunning, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(clock.progress, 1);
    expect(clock.isRunning, isFalse);
    disposeClock(clock);
  });

  testWidgets('a run follows its curve', (tester) async {
    final clock = makeClock();
    clock.runTo(1, fullSeconds: 1, curve: Curves.easeIn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.progress, closeTo(Curves.easeIn.transform(0.5), 1e-9));
    disposeClock(clock);
  });

  testWidgets('interrupting reverses from the current progress with no jump', (
    tester,
  ) async {
    final clock = makeClock();
    final seen = <double>[];
    clock.addListener(() => seen.add(clock.progress));

    clock.runTo(1, fullSeconds: 2);
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(_frame);
    }
    final turn = clock.progress;
    expect(turn, closeTo(30 * 0.016 / 2, 1e-9));

    clock.runTo(0, fullSeconds: 2);
    expect(clock.progress, turn, reason: 'no jump on the turn');
    expect(clock.isRunning, isTrue);
    expect(clock.target, 0);
    final turnedAt = seen.length;

    await tester.pump();
    expect(clock.progress, turn, reason: 'the new run starts where it was');
    // Back from `turn` takes its share of a full run: 30 frames.
    for (var i = 0; i < 29; i++) {
      await tester.pump(_frame);
      expect(clock.isRunning, isTrue, reason: 'frame $i');
    }
    await tester.pump(_frame);
    expect(clock.progress, 0);
    expect(clock.isRunning, isFalse);

    // Every step, out and back, is at most one frame's worth.
    const step = 0.016 / 2 + 1e-9;
    var last = 0.0;
    for (final value in seen) {
      expect((value - last).abs(), lessThanOrEqualTo(step), reason: '$seen');
      last = value;
    }
    // And after the turn it only ever comes back.
    for (var i = turnedAt + 1; i < seen.length; i++) {
      expect(seen[i], lessThan(seen[i - 1]), reason: '$seen');
    }
    disposeClock(clock);
  });

  testWidgets('onDone fires once on arrival, not on interruption', (
    tester,
  ) async {
    final clock = makeClock();
    var forward = 0;
    var back = 0;
    clock.runTo(1, fullSeconds: 1, onDone: () => forward++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    clock.runTo(0, fullSeconds: 1, onDone: () => back++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 399));
    expect(back, 0, reason: 'not there yet');
    await tester.pump(const Duration(milliseconds: 1));
    expect(clock.progress, 0);
    expect(back, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(back, 1, reason: 'once');
    expect(forward, 0, reason: 'the interrupted run never arrived');
    disposeClock(clock);
  });

  testWidgets('a run to where it already is arrives at once', (tester) async {
    final clock = makeClock(progress: 0.4);
    var notified = 0;
    clock.addListener(() => notified++);
    var done = 0;
    clock.runTo(0.4, fullSeconds: 1, onDone: () => done++);
    expect(done, 1);
    expect(clock.isRunning, isFalse);
    expect(notified, 0, reason: 'nothing changed');

    // So does a run that takes no time.
    clock.runTo(1, fullSeconds: 0, onDone: () => done++);
    expect(done, 2);
    expect(clock.progress, 1);
    expect(clock.isRunning, isFalse);
    expect(notified, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(done, 2);
    disposeClock(clock);
  });

  testWidgets('jumpTo stops a run', (tester) async {
    final clock = makeClock();
    var done = 0;
    clock.runTo(1, fullSeconds: 2, onDone: () => done++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    clock.jumpTo(0.8);
    expect(clock.isRunning, isFalse);
    expect(clock.target, isNull);
    expect(clock.progress, 0.8);
    await tester.pump(const Duration(seconds: 3));
    expect(clock.progress, 0.8);
    expect(done, 0);

    clock.jumpTo(2);
    expect(clock.progress, 1, reason: 'clamped');
    disposeClock(clock);
  });

  testWidgets('stop holds the run where it is, without onDone', (tester) async {
    final clock = makeClock();
    var done = 0;
    clock.runTo(1, fullSeconds: 1, onDone: () => done++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    clock.stop();
    expect(clock.isRunning, isFalse);
    expect(clock.progress, closeTo(0.3, 1e-9));
    await tester.pump(const Duration(seconds: 2));
    expect(clock.progress, closeTo(0.3, 1e-9));
    expect(done, 0);
    disposeClock(clock);
  });

  testWidgets('dispose mid-run leaves no ticker behind', (tester) async {
    final clock = makeClock();
    var done = 0;
    clock.runTo(1, fullSeconds: 2, onDone: () => done++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    disposeClock(clock);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(done, 0, reason: 'a disposed clock never arrives');
  });
}
