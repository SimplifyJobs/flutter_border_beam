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
