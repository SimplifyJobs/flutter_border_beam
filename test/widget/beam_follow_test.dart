import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/render/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

// A 350x140 box with equal corners: the right-edge centre is a quarter of
// the way round from top-centre, the left-edge centre three quarters.
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

// The sweep the painter would draw right now: the driven value while one is
// set, else the clock's.
double _sweep(WidgetTester tester) {
  final painter = _painter(tester);
  return painter.resolver
      .sample(
        painter.clock.elapsedSeconds,
        1,
        progress: painter.progress?.value,
      )
      .travelProgress;
}

// The clock's own sweep, ignoring any driven value.
double _timed(WidgetTester tester) {
  final painter = _painter(tester);
  return painter.resolver
      .sample(painter.clock.elapsedSeconds, 1)
      .travelProgress;
}

double? _driven(WidgetTester tester) => _painter(tester).progress?.value;

// The signed distance from [from] to [to] round the border, in (-0.5, 0.5].
double _wrapDelta(double from, double to) => ((to - from) + 0.5) % 1.0 - 0.5;

const _frame = Duration(milliseconds: 16);

Future<List<double>> _frames(WidgetTester tester, int count) async {
  final seen = <double>[];
  for (var i = 0; i < count; i++) {
    await tester.pump(_frame);
    seen.add(_sweep(tester));
  }
  return seen;
}

/// `BorderBeam.follow`: the sweep of a travelling effect eases toward the
/// border point nearest a normalized pointer, critically damped, and is
/// handed back to the clock without a snap when the pointer leaves.
void main() {
  Widget beam({
    BeamEffect? effect,
    Offset? follow,
    double? progress,
    BeamTiming? timing,
    BeamShape? shape,
    bool? active,
  }) => _host(
    BorderBeam(
      effect: effect,
      follow: follow,
      progress: progress,
      timing: timing,
      shape: shape,
      active: active,
      child: const SizedBox.expand(),
    ),
  );

  // Starts the beam and lets it run [lead] before the pointer arrives.
  Future<void> start(
    WidgetTester tester, {
    BeamEffect? effect,
    BeamTiming? timing,
    BeamShape? shape,
    Duration lead = const Duration(milliseconds: 100),
  }) async {
    await tester.pumpWidget(beam(effect: effect, timing: timing, shape: shape));
    await tester.pump();
    await tester.pump(lead);
  }

  group('rotate', () {
    testWidgets('eases to the border point nearest the pointer', (
      tester,
    ) async {
      await start(tester);
      final origin = _timed(tester);
      await tester.pumpWidget(beam(follow: const Offset(1, 0.5)));

      final early = await _frames(tester, 2);
      expect(early.last, greaterThan(origin));
      expect(
        early.last,
        lessThan(0.24),
        reason: 'the beam eases rather than snapping',
      );

      await _frames(tester, 29);
      expect(_driven(tester), closeTo(0.25, 0.005), reason: 'within ~0.5s');
      expect(_sweep(tester), closeTo(0.25, 0.005));
    });

    testWidgets('approaches without overshooting the target', (tester) async {
      await start(tester);
      await tester.pumpWidget(beam(follow: const Offset(1, 0.5)));
      var previous = _timed(tester);
      for (final now in await _frames(tester, 60)) {
        expect(now, lessThanOrEqualTo(0.25 + 1e-9), reason: 'no overshoot');
        expect(now, greaterThanOrEqualTo(previous - 1e-9), reason: 'no ring');
        previous = now;
      }
      expect(previous, closeTo(0.25, 1e-3));
    });

    testWidgets('takes the shortest way round', (tester) async {
      // Just past top-centre, the left-edge centre (0.75) is a short hop
      // backwards through 0, not three quarters of a lap forwards.
      await start(tester);
      await tester.pumpWidget(beam(follow: const Offset(0, 0.5)));
      // The first eased frame starts from wherever the clock had the beam.
      var previous = (await _frames(tester, 1)).single;
      for (final now in await _frames(tester, 40)) {
        expect(
          _wrapDelta(previous, now),
          lessThanOrEqualTo(1e-9),
          reason: 'every step runs backwards toward the target',
        );
        previous = now;
      }
      expect(previous, closeTo(0.75, 0.005));
    });

    testWidgets('a moved pointer is followed from where the beam is', (
      tester,
    ) async {
      await start(tester);
      await tester.pumpWidget(beam(follow: const Offset(1, 0.5)));
      await _frames(tester, 40);
      await tester.pumpWidget(beam(follow: const Offset(0.5, 1)));
      final first = (await _frames(tester, 1)).single;
      expect(
        first,
        closeTo(0.25, 0.02),
        reason: 'no jump when the target moves',
      );
      await _frames(tester, 40);
      expect(_driven(tester), closeTo(0.5, 0.005), reason: 'bottom centre');
    });
  });

  group('open sweeps: segments and the line', () {
    testWidgets('rotate on a segment follows the fraction along it', (
      tester,
    ) async {
      // The right half runs top-centre → bottom-centre, so the right-edge
      // centre sits halfway along it.
      const shape = BeamShape(segment: BeamSegment.rightHalf);
      await start(tester, shape: shape);
      await tester.pumpWidget(beam(shape: shape, follow: const Offset(1, 0.5)));
      await _frames(tester, 40);
      expect(_driven(tester), closeTo(0.5, 0.005));
    });

    testWidgets('line follows the coordinate along its edge', (tester) async {
      for (final (edge, follow, target) in [
        (BeamEdge.bottom, const Offset(0.8, 0.2), 0.8),
        (BeamEdge.top, const Offset(0.3, 0.9), 0.3),
        (BeamEdge.left, const Offset(0.9, 0.7), 0.7),
      ]) {
        final effect = BeamEffect.line(edge: edge);
        await start(tester, effect: effect);
        await tester.pumpWidget(beam(effect: effect, follow: follow));
        await _frames(tester, 40);
        expect(_driven(tester), closeTo(target, 0.005), reason: '$edge');
        // Unmount so the next edge starts on a fresh timeline.
        await tester.pumpWidget(_host(const SizedBox()));
      }
    });

    for (final (label, effect, shape, follow) in const [
      ('line', BeamEffect.line(), null, Offset(0.95, 0.5)),
      (
        'rotate on a segment',
        BeamEffect.rotate(),
        BeamShape(segment: BeamSegment.rightHalf),
        // On the bottom edge just short of its centre: near the segment's
        // far end.
        Offset(0.6, 1),
      ),
    ]) {
      testWidgets('$label eases along its travel without wrapping round', (
        tester,
      ) async {
        // Near the start of the sweep, a pointer at the far end is "closer"
        // backwards through 0 on a loop, but these sweeps are not loops.
        await start(tester, effect: effect, shape: shape);
        await tester.pumpWidget(
          beam(effect: effect, shape: shape, follow: follow),
        );
        var previous = _timed(tester);
        for (final now in await _frames(tester, 40)) {
          expect(
            (now - previous).abs(),
            lessThan(0.2),
            reason: 'the sweep jumped from $previous to $now',
          );
          previous = now;
        }
      });
    }
  });

  // Every ambient effect, derived so a new one is covered too.
  for (final effect in BeamEffect.values.where((e) => !e.travels)) {
    testWidgets('${effect.name} has no travel for it to steer', (tester) async {
      await start(tester, effect: effect);
      await tester.pumpWidget(
        beam(effect: effect, follow: const Offset(1, 0.5)),
      );
      await _frames(tester, 20);
      expect(_driven(tester), isNull);
      expect(_sweep(tester), 0);
    });
  }

  testWidgets('an explicit progress wins over it', (tester) async {
    await start(tester);
    await tester.pumpWidget(beam(progress: 0.5, follow: const Offset(1, 0.5)));
    for (final now in await _frames(tester, 30)) {
      expect(now, 0.5);
    }

    // Dropping the progress hands the sweep back to the pointer.
    await tester.pumpWidget(beam(follow: const Offset(1, 0.5)));
    await _frames(tester, 2);
    expect(_driven(tester), closeTo(0.25, 0.005));
  });

  group('release', () {
    // Follows [follow] until settled, lets go, and returns the sweep the
    // pointer left the beam at.
    Future<double> followThenRelease(
      WidgetTester tester, {
      BeamTiming? timing,
      BeamEffect? effect,
      Offset follow = const Offset(1, 0.5),
      int frames = 40,
    }) async {
      await tester.pumpWidget(
        beam(effect: effect, timing: timing, follow: follow),
      );
      await _frames(tester, frames);
      final held = _sweep(tester);
      expect(_driven(tester), held);
      await tester.pumpWidget(beam(effect: effect, timing: timing));
      expect(_driven(tester), isNull);
      return held;
    }

    testWidgets('hands the sweep back to the clock without a snap', (
      tester,
    ) async {
      await start(tester);
      final held = await followThenRelease(tester);
      expect(_sweep(tester), closeTo(held, 1e-6));
      expect(_painter(tester).resolver.travelTimeOffset, isNot(0));

      // And it travels on from there at the clock's pace (2.4s cycle).
      await tester.pump(const Duration(milliseconds: 120));
      expect(_sweep(tester), closeTo(held + 0.05, 1e-6));

      await tester.pumpWidget(_host(const SizedBox()));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a reversed beam carries on backwards from there', (
      tester,
    ) async {
      const timing = BeamTiming(direction: BeamDirection.reverse);
      await start(tester, timing: timing);
      final held = await followThenRelease(tester, timing: timing);
      expect(_sweep(tester), closeTo(held, 1e-6));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_sweep(tester), closeTo(held - 0.05, 1e-6));
    });

    testWidgets('a bouncing beam lets go inside a mirrored cycle', (
      tester,
    ) async {
      const timing = BeamTiming(
        cycle: Duration(seconds: 1),
        direction: BeamDirection.bounce,
      );
      await start(
        tester,
        timing: timing,
        lead: const Duration(milliseconds: 1100),
      );
      final held = await followThenRelease(tester, timing: timing, frames: 25);
      expect(_sweep(tester), closeTo(held, 1e-6));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sweep(tester), closeTo(held - 0.05, 1e-6), reason: 'mirrored');
    });

    testWidgets(
      'a hand-back that crosses a cycle end keeps the mirrored direction',
      (tester) async {
        const timing = BeamTiming(
          cycle: Duration(seconds: 1),
          direction: BeamDirection.bounce,
        );
        // 0.9s into the mirrored second cycle the sweep sits at 0.1, so the
        // left edge (0.75) is 0.35 further along the mirrored run — past the
        // end of this cycle.
        await start(
          tester,
          timing: timing,
          lead: const Duration(milliseconds: 1500),
        );
        final held = await followThenRelease(
          tester,
          timing: timing,
          follow: const Offset(0, 0.5),
          frames: 25,
        );
        expect(_sweep(tester), closeTo(held, 1e-6));
      },
    );

    testWidgets(
      'letting go during the rest between sweeps resumes where it was left',
      (tester) async {
        const timing = BeamTiming(
          cycle: Duration(seconds: 1),
          cycleGap: Duration(seconds: 2),
        );
        // Released 1.5s in: the clock's own sweep is resting in the gap.
        await start(
          tester,
          timing: timing,
          lead: const Duration(milliseconds: 900),
        );
        final held = await followThenRelease(tester, timing: timing);
        expect(_sweep(tester), closeTo(held, 1e-6));
        final painter = _painter(tester);
        expect(
          painter.resolver.sample(painter.clock.elapsedSeconds, 1).fadeOpacity,
          1,
          reason: 'the beam does not vanish into the rest it was pulled from',
        );
      },
    );

    testWidgets('the hand-back survives a cycle change', (tester) async {
      const short = BeamTiming(cycle: Duration(seconds: 4));
      await start(tester, timing: short, lead: Duration.zero);

      // A pointer parked most of a cycle behind the clock leaves a large
      // negative travel offset, which puts the shifted timeline behind zero.
      await followThenRelease(
        tester,
        timing: short,
        follow: const Offset(0, 0.5),
      );
      final before = _painter(tester);
      final offset = before.resolver.travelTimeOffset;
      expect(offset, lessThan(-before.clock.elapsedSeconds));
      final sweep = _sweep(tester);

      await tester.pumpWidget(
        beam(timing: const BeamTiming(cycle: Duration(seconds: 16))),
      );
      final after = _painter(tester);
      expect(
        after.resolver.travelTimeOffset,
        closeTo(offset, 1e-9),
        reason: 'a rebuilt resolver keeps the hand-back',
      );
      expect(_sweep(tester), closeTo(sweep, 1e-6));
    });

    testWidgets('a restart drops the hand-back', (tester) async {
      await start(tester);
      await followThenRelease(tester);
      expect(_painter(tester).resolver.travelTimeOffset, isNot(0));

      await tester.pumpWidget(beam(active: false));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(beam(active: true));
      final painter = _painter(tester);
      expect(painter.clock.elapsedSeconds, 0);
      expect(painter.resolver.travelTimeOffset, 0);
    });
  });
}
