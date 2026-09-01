import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

BeamPhaseResolver _resolver(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first
    .resolver;

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
}
