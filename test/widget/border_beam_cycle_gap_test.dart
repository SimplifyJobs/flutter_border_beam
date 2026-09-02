import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

BeamPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first;

BeamPhaseResolver _resolver(WidgetTester tester) => _painter(tester).resolver;

// A resolver built straight from a config, for the instants the envelope is
// specified at — no clock, no widget.
BeamPhaseResolver _direct({
  required Duration cycle,
  required Duration gap,
  BeamVariant variant = BeamVariant.rotate,
}) => BeamPhaseResolver(
  BeamConfig.resolve(
    variant: variant,
    palette: BeamColors.colorful.resolve(),
    brightness: Brightness.dark,
    timing: BeamTiming(cycle: cycle, cycleGap: gap),
  ),
);

/// `BeamTiming.cycleGap` rests the traveling beam between sweeps: the sweep
/// still takes `cycle`, then the beam parks at the end of its travel and its
/// fade envelope eases to zero for the rest of the gap. Phases are sampled
/// directly off the mounted beam's resolver so the instants are exact.
void main() {
  const timing = BeamTiming(
    cycle: Duration(seconds: 1),
    cycleGap: Duration(seconds: 1),
  );

  testWidgets('rotate fades out through the gap and back in on the next '
      'sweep', (tester) async {
    await tester.pumpWidget(
      _host(const BorderBeam.rotate(timing: timing, child: SizedBox.expand())),
    );
    final resolver = _resolver(tester);
    expect(resolver.config.gapSeconds, closeTo(1, 1e-9));

    expect(resolver.sample(0.5, 1).fadeOpacity, 1, reason: 'mid sweep');
    expect(resolver.sample(1.5, 1).fadeOpacity, 0, reason: 'mid rest');
    expect(resolver.sample(2.5, 1).fadeOpacity, 1, reason: 'next sweep');
  });

  testWidgets('rotate parks its angle at the end of the sweep', (tester) async {
    await tester.pumpWidget(
      _host(const BorderBeam.rotate(timing: timing, child: SizedBox.expand())),
    );
    final resolver = _resolver(tester);
    // Progress is pinned to 1.0 for the whole rest, so the beam holds where
    // its sweep ended rather than drifting on.
    expect(resolver.sample(1.2, 1).angleRadians, closeTo(2 * 3.14159265, 1e-5));
    expect(resolver.sample(1.9, 1).angleRadians, closeTo(2 * 3.14159265, 1e-5));
  });

  testWidgets('the gap eases in and out rather than cutting', (tester) async {
    await tester.pumpWidget(
      _host(const BorderBeam.rotate(timing: timing, child: SizedBox.expand())),
    );
    final resolver = _resolver(tester);
    // gapFade = min(0.25, gap / 2) = 0.25s at each end of the rest.
    final entering = resolver.sample(1.125, 1).fadeOpacity;
    final leaving = resolver.sample(1.875, 1).fadeOpacity;
    expect(entering, greaterThan(0));
    expect(entering, lessThan(1));
    expect(leaving, closeTo(entering, 1e-9));
    expect(resolver.sample(1.0, 1).fadeOpacity, closeTo(1, 1e-9));
    expect(resolver.sample(2.0, 1).fadeOpacity, closeTo(1, 1e-9));
  });

  testWidgets('line parks invisible at the end of its travel', (tester) async {
    await tester.pumpWidget(
      _host(const BorderBeam.line(timing: timing, child: SizedBox.expand())),
    );
    final resolver = _resolver(tester);
    for (final t in [1.2, 1.5, 1.9]) {
      final phases = resolver.sample(t, 1);
      expect(phases.lineX, closeTo(0.94, 1e-9), reason: 'parked at t=$t');
      expect(phases.edge, 0, reason: 'edge fade is already 0 at t=$t');
    }
  });

  testWidgets('a zero gap leaves the sweep untouched', (tester) async {
    await tester.pumpWidget(
      _host(
        const BorderBeam.rotate(
          timing: BeamTiming(cycle: Duration(seconds: 1)),
          child: SizedBox.expand(),
        ),
      ),
    );
    final resolver = _resolver(tester);
    expect(resolver.config.gapSeconds, 0);
    for (final t in [0.0, 0.25, 0.5, 0.99, 1.5, 7.3]) {
      expect(resolver.sample(t, 1).fadeOpacity, 1, reason: 't=$t');
      expect(
        resolver.sample(t, 1).angleRadians,
        closeTo((t % 1.0) * 2 * 3.14159265358979, 1e-9),
        reason: 't=$t',
      );
    }
  });

  group('retiming across a gap', () {
    const twoPlusOne = BeamTiming(
      cycle: Duration(seconds: 2),
      cycleGap: Duration(seconds: 1),
    );

    testWidgets('a cycle change mid-sweep keeps travel progress continuous', (
      tester,
    ) async {
      Widget build(BeamTiming timing) => _host(
        BorderBeam.rotate(timing: timing, child: const SizedBox.expand()),
      );

      await tester.pumpWidget(build(twoPlusOne));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final before = _painter(tester);
      expect(before.clock.elapsedSeconds, closeTo(0.9, 1e-9));
      final angle = before.resolver.sample(0.9, 1).angleRadians;

      await tester.pumpWidget(
        build(
          const BeamTiming(
            cycle: Duration(seconds: 4),
            cycleGap: Duration(seconds: 1),
          ),
        ),
      );
      final after = _painter(tester);
      expect(after.config.cycleSeconds, closeTo(4, 1e-9));
      expect(after.config.gapSeconds, closeTo(1, 1e-9));
      expect(
        after.clock.elapsedSeconds,
        closeTo(1.8, 1e-9),
        reason: 'elapsed is rescaled by the cycle ratio, gap and all',
      );
      expect(
        after.resolver.sample(after.clock.elapsedSeconds, 1).angleRadians,
        closeTo(angle, 1e-6),
        reason: 'the sweep is at the same fraction of its travel',
      );
    });

    testWidgets('changing only the gap needs no retime', (tester) async {
      Widget build(Duration gap) => _host(
        BorderBeam.rotate(
          timing: BeamTiming(cycle: const Duration(seconds: 2), cycleGap: gap),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(seconds: 1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final before = _painter(tester);
      final angle = before.resolver.sample(0.9, 1).angleRadians;

      await tester.pumpWidget(build(const Duration(seconds: 2)));
      final after = _painter(tester);
      expect(after.config.gapSeconds, closeTo(2, 1e-9));
      expect(
        after.clock.elapsedSeconds,
        closeTo(0.9, 1e-9),
        reason: 'the timeline is untouched',
      );
      expect(
        after.resolver.sample(0.9, 1).angleRadians,
        closeTo(angle, 1e-9),
        reason: 'the sweep keeps its position; the rest appears later',
      );
    });

    testWidgets('a phase-offset beam resting in the gap stays in the gap', (
      tester,
    ) async {
      Widget build(Duration cycle) => _host(
        BorderBeam.rotate(
          timing: BeamTiming(
            cycle: cycle,
            cycleGap: const Duration(seconds: 1),
            phaseOffset: 0.5,
          ),
          child: const SizedBox.expand(),
        ),
      );

      // cycle 2 + gap 1 with a half-cycle offset: at 1.5s elapsed the beam is
      // 2.5s into its own 3s period — parked half a second into the rest.
      await tester.pumpWidget(build(const Duration(seconds: 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      final before = _painter(tester);
      final resting = before.resolver.sample(1.5, 1);
      expect(resting.fadeOpacity, closeTo(0, 1e-9));
      expect(resting.travelProgress, closeTo(1, 1e-9));

      await tester.pumpWidget(build(const Duration(seconds: 4)));
      final after = _painter(tester);
      final phases = after.resolver.sample(after.clock.elapsedSeconds, 1);
      expect(
        phases.fadeOpacity,
        closeTo(0, 1e-9),
        reason: 'the raw timeline says mid-sweep; the shifted one says gap',
      );
      expect(phases.travelProgress, closeTo(1, 1e-9));
    });

    testWidgets('a follow hand-back survives a cycle change', (tester) async {
      Widget build({required Duration cycle, Offset? follow}) => _host(
        BorderBeam.rotate(
          timing: BeamTiming(cycle: cycle),
          follow: follow,
          child: const SizedBox.expand(),
        ),
      );

      const short = Duration(seconds: 4);
      await tester.pumpWidget(build(cycle: short));
      await tester.pump();

      // Hand the sweep to a pointer parked most of a cycle behind the clock,
      // let it settle, then let go: the beam carries a large negative travel
      // offset from here on, which puts the shifted timeline behind zero.
      await tester.pumpWidget(
        build(cycle: short, follow: const Offset(0, 0.5)),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpWidget(build(cycle: short));
      final before = _painter(tester);
      final offset = before.resolver.travelTimeOffset;
      expect(
        offset,
        lessThan(-before.clock.elapsedSeconds),
        reason:
            'the hand-back must outweigh elapsed for the shift to go '
            'negative',
      );
      final progress = before.resolver
          .sample(before.clock.elapsedSeconds, 1)
          .travelProgress;

      await tester.pumpWidget(build(cycle: const Duration(seconds: 16)));
      final after = _painter(tester);
      expect(
        after.resolver.travelTimeOffset,
        closeTo(offset, 1e-9),
        reason: 'a rebuilt resolver keeps the hand-back',
      );
      expect(
        after.resolver.sample(after.clock.elapsedSeconds, 1).travelProgress,
        closeTo(progress, 1e-6),
        reason: 'the retime target is lifted by whole periods, not refused',
      );
    });

    testWidgets('the line breathe and spike tracks survive a retime', (
      tester,
    ) async {
      Widget build(Duration cycle) => _host(
        BorderBeam.line(
          timing: BeamTiming(
            cycle: cycle,
            cycleGap: const Duration(seconds: 1),
          ),
          child: const SizedBox.expand(),
        ),
      );

      // A gap bends the retime target away from a pure ratio rescale, and
      // these three tracks scale with the cycle, so only a rescaled timeline
      // holds their phase.
      await tester.pumpWidget(build(const Duration(seconds: 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
      final before = _painter(tester);
      final was = before.resolver.sample(before.clock.elapsedSeconds, 1);

      await tester.pumpWidget(build(const Duration(seconds: 4)));
      final after = _painter(tester);
      final now = after.resolver.sample(after.clock.elapsedSeconds, 1);

      expect(now.lineH, closeTo(was.lineH, 1e-9));
      expect(now.spike, closeTo(was.spike, 1e-9));
      expect(now.spike2, closeTo(was.spike2, 1e-9));
    });

    testWidgets('a restart drops the timeline corrections a retime left', (
      tester,
    ) async {
      Widget build({required Duration cycle, required bool active}) => _host(
        BorderBeam.line(
          active: active,
          timing: BeamTiming(
            cycle: cycle,
            cycleGap: const Duration(seconds: 1),
          ),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(
        build(cycle: const Duration(seconds: 2), active: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpWidget(
        build(cycle: const Duration(seconds: 4), active: true),
      );
      final retimed = _painter(tester);
      expect(retimed.resolver.hueTimeOffset, isNot(0));
      expect(retimed.resolver.breatheTimeOffset, isNot(0));

      // Off, let the fade finish, then on: activate() puts elapsed back to
      // zero, so every correction measured against the old timeline goes.
      await tester.pumpWidget(
        build(cycle: const Duration(seconds: 4), active: false),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(
        build(cycle: const Duration(seconds: 4), active: true),
      );
      final restarted = _painter(tester);
      expect(restarted.clock.elapsedSeconds, closeTo(0, 1e-9));
      expect(restarted.resolver.hueTimeOffset, 0);
      expect(restarted.resolver.breatheTimeOffset, 0);
      expect(restarted.resolver.travelTimeOffset, 0);
    });

    testWidgets('a synced group restart drops its members corrections', (
      tester,
    ) async {
      Widget build({required Duration cycle, required bool active}) => _host(
        BeamSync(
          active: active,
          child: BorderBeam.line(
            timing: BeamTiming(cycle: cycle),
            child: const SizedBox.expand(),
          ),
        ),
      );

      await tester.pumpWidget(
        build(cycle: const Duration(seconds: 2), active: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpWidget(
        build(cycle: const Duration(seconds: 4), active: true),
      );
      expect(_painter(tester).resolver.hueTimeOffset, isNot(0));

      // The group owns the clock, so the member is never told to restart —
      // it has to hear it from the clock itself.
      await tester.pumpWidget(
        build(cycle: const Duration(seconds: 4), active: false),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(
        build(cycle: const Duration(seconds: 4), active: true),
      );
      final restarted = _painter(tester);
      expect(restarted.clock.elapsedSeconds, closeTo(0, 1e-9));
      expect(restarted.resolver.hueTimeOffset, 0);
      expect(restarted.resolver.breatheTimeOffset, 0);
    });

    testWidgets('changing a track period re-phases only that track', (
      tester,
    ) async {
      Widget build(double breatheFactor) => _host(
        BorderBeam.line(
          timing: BeamTiming(
            cycle: const Duration(seconds: 2),
            breatheFactor: breatheFactor,
          ),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(1.3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final before = _painter(tester);
      final was = before.resolver.sample(before.clock.elapsedSeconds, 1);

      // Documented contract: a period change re-phases its own track and
      // leaves the timeline — and therefore every other track — alone.
      await tester.pumpWidget(build(2.6));
      final after = _painter(tester);
      expect(after.clock.elapsedSeconds, closeTo(0.9, 1e-9));
      final now = after.resolver.sample(after.clock.elapsedSeconds, 1);
      expect(now.travelProgress, closeTo(was.travelProgress, 1e-9));
      expect(now.spike, closeTo(was.spike, 1e-9));
      expect(now.spike2, closeTo(was.spike2, 1e-9));
      expect(now.lineH, isNot(closeTo(was.lineH, 1e-6)));
    });

    testWidgets('adding a gap to a running beam needs no retime either', (
      tester,
    ) async {
      Widget build(Duration gap) => _host(
        BorderBeam.rotate(
          timing: BeamTiming(cycle: const Duration(seconds: 2), cycleGap: gap),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(Duration.zero));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpWidget(build(const Duration(seconds: 1)));
      expect(_painter(tester).clock.elapsedSeconds, closeTo(0.9, 1e-9));
    });
  });

  group('the gap envelope', () {
    // cycle 1s + gap 1s: the fade at each end is min(0.25, gap / 2) = 0.25s,
    // and it is a smoothstep, so a quarter into the fade is 0.15625 and half
    // way is exactly 0.5.
    final resolver = _direct(
      cycle: const Duration(seconds: 1),
      gap: const Duration(seconds: 1),
    );

    test('it holds at 1 until the sweep ends', () {
      expect(resolver.sample(0.999, 1).fadeOpacity, 1);
      expect(resolver.sample(1, 1).fadeOpacity, closeTo(1, 1e-9));
    });

    test('it eases 1 to 0 over the first quarter second of the rest', () {
      expect(resolver.sample(1.0625, 1).fadeOpacity, closeTo(0.84375, 1e-9));
      expect(resolver.sample(1.125, 1).fadeOpacity, closeTo(0.5, 1e-9));
      expect(resolver.sample(1.1875, 1).fadeOpacity, closeTo(0.15625, 1e-9));
      expect(resolver.sample(1.25, 1).fadeOpacity, closeTo(0, 1e-9));
    });

    test('it stays at 0 through the middle of the rest', () {
      for (final t in [1.25, 1.4, 1.5, 1.6, 1.75]) {
        expect(resolver.sample(t, 1).fadeOpacity, 0, reason: 't=$t');
      }
    });

    test('it eases 0 back to 1 over the last quarter second', () {
      expect(resolver.sample(1.8125, 1).fadeOpacity, closeTo(0.15625, 1e-9));
      expect(resolver.sample(1.875, 1).fadeOpacity, closeTo(0.5, 1e-9));
      expect(resolver.sample(1.9375, 1).fadeOpacity, closeTo(0.84375, 1e-9));
      expect(resolver.sample(2, 1).fadeOpacity, closeTo(1, 1e-9));
    });

    test('a 100ms gap fades for 50ms at each side', () {
      final short = _direct(
        cycle: const Duration(seconds: 1),
        gap: const Duration(milliseconds: 100),
      );
      expect(short.sample(1, 1).fadeOpacity, closeTo(1, 1e-9));
      expect(short.sample(1.025, 1).fadeOpacity, closeTo(0.5, 1e-9));
      expect(
        short.sample(1.05, 1).fadeOpacity,
        closeTo(0, 1e-9),
        reason: 'the two fades meet in the middle, with no flat rest',
      );
      expect(short.sample(1.075, 1).fadeOpacity, closeTo(0.5, 1e-9));
      expect(short.sample(1.1, 1).fadeOpacity, closeTo(1, 1e-9));
    });

    test('it multiplies the beam own fade rather than replacing it', () {
      expect(resolver.sample(1.125, 0.5).fadeOpacity, closeTo(0.25, 1e-9));
      expect(resolver.sample(0.5, 0.5).fadeOpacity, closeTo(0.5, 1e-9));
    });

    test('the envelope repeats every cycle + gap', () {
      for (final t in [0.3, 1.1, 1.5, 1.9]) {
        expect(
          resolver.sample(t + 2, 1).fadeOpacity,
          closeTo(resolver.sample(t, 1).fadeOpacity, 1e-9),
          reason: 't=$t',
        );
      }
    });
  });

  group('the pulse variants ignore the gap', () {
    for (final variant in [BeamVariant.pulseInside, BeamVariant.pulseOutside]) {
      test('$variant breathes straight through it', () {
        final gapped = _direct(
          cycle: const Duration(seconds: 2),
          gap: const Duration(seconds: 1),
          variant: variant,
        );
        final plain = _direct(
          cycle: const Duration(seconds: 2),
          gap: Duration.zero,
          variant: variant,
        );
        expect(gapped.config.gapSeconds, closeTo(1, 1e-9));

        for (final t in [0.5, 2.0, 2.5, 3.0, 5.7]) {
          final a = gapped.sample(t, 1);
          final b = plain.sample(t, 1);
          expect(a.fadeOpacity, 1, reason: 'no gap envelope at t=$t');
          expect(a.hueDegrees, closeTo(b.hueDegrees, 1e-9), reason: 't=$t');
          for (var i = 0; i < 3; i++) {
            expect(a.pulse.bw[i], closeTo(b.pulse.bw[i], 1e-9), reason: 't=$t');
            expect(a.pulse.bh[i], closeTo(b.pulse.bh[i], 1e-9), reason: 't=$t');
            expect(a.pulse.bx[i], closeTo(b.pulse.bx[i], 1e-9), reason: 't=$t');
            expect(a.pulse.by[i], closeTo(b.pulse.by[i], 1e-9), reason: 't=$t');
          }
          expect(a.pulse.bgh, closeTo(b.pulse.bgh, 1e-9), reason: 't=$t');
          expect(a.pulse.bopTl, closeTo(b.pulse.bopTl, 1e-9), reason: 't=$t');
          expect(a.pulse.bopBr, closeTo(b.pulse.bopBr, 1e-9), reason: 't=$t');
        }
      });

      test('$variant passes the beam fade straight through', () {
        final gapped = _direct(
          cycle: const Duration(seconds: 2),
          gap: const Duration(seconds: 1),
          variant: variant,
        );
        expect(gapped.sample(2.5, 0.4).fadeOpacity, 0.4);
      });
    }
  });
}
