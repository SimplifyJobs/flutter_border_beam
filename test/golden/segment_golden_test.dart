@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden scenes for partial-perimeter beams and corner-wrapped line travel.
///
/// Regenerate on the pinned macOS Flutter SDK with:
///   flutter test --update-goldens --tags golden
void main() {
  Widget surface() => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF1D1D1D),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0x14FFFFFF)),
    ),
  );

  Widget scene(Widget beam) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark),
    home: ColoredBox(
      color: const Color(0xFF070707),
      child: Center(child: SizedBox.square(dimension: 200, child: beam)),
    ),
  );

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget beam, {
    Duration freeze = const Duration(milliseconds: 1300),
  }) async {
    await tester.pumpWidget(scene(beam));
    await tester.pump();
    await tester.pump(freeze);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  const style = BeamStyle(theme: BeamTheme.dark);
  BeamShape shape(BeamSegment segment) => BeamShape(
    radius: const BorderRadius.all(Radius.circular(24)),
    segment: segment,
  );

  testWidgets('rotate bottom half', (tester) async {
    await capture(
      tester,
      'segment_rotate_bottom_half',
      BorderBeam.rotate(
        style: style,
        shape: shape(BeamSegment.bottomHalf),
        child: surface(),
      ),
    );
  });

  testWidgets('rotate bottom half late', (tester) async {
    await capture(
      tester,
      'segment_rotate_bottom_half_late',
      BorderBeam.rotate(
        style: style,
        shape: shape(BeamSegment.bottomHalf),
        child: surface(),
      ),
      freeze: const Duration(milliseconds: 2300),
    );
  });

  testWidgets('small bottom half', (tester) async {
    await capture(
      tester,
      'segment_small_bottom_half',
      BorderBeam.small(
        style: style,
        shape: shape(BeamSegment.bottomHalf),
        child: surface(),
      ),
    );
  });

  testWidgets('line bottom half', (tester) async {
    await capture(
      tester,
      'segment_line_bottom_half',
      BorderBeam.line(
        style: style,
        shape: shape(BeamSegment.bottomHalf),
        child: surface(),
      ),
    );
  });

  testWidgets('line bottom half late', (tester) async {
    await capture(
      tester,
      'segment_line_bottom_half_late',
      BorderBeam.line(
        style: style,
        shape: shape(BeamSegment.bottomHalf),
        child: surface(),
      ),
      freeze: const Duration(milliseconds: 2000),
    );
  });

  testWidgets('line wraps bottom corners', (tester) async {
    await capture(
      tester,
      'segment_line_wrap_corners',
      BorderBeam.line(
        style: style,
        shape: const BeamShape(
          radius: BorderRadius.all(Radius.circular(24)),
          edge: BeamEdge.bottom,
          wrapCorners: true,
        ),
        child: surface(),
      ),
    );
  });

  testWidgets('pulse inside bottom half', (tester) async {
    await capture(
      tester,
      'segment_pulse_inside_bottom_half',
      BorderBeam.pulseInside(
        style: style,
        shape: shape(BeamSegment.bottomHalf),
        child: surface(),
      ),
    );
  });

  testWidgets('pulse outside bottom half', (tester) async {
    await capture(
      tester,
      'segment_pulse_outside_bottom_half',
      BorderBeam.pulseOutside(
        style: style,
        shape: shape(BeamSegment.bottomHalf),
        child: surface(),
      ),
    );
  });

  testWidgets('rotate top edge', (tester) async {
    await capture(
      tester,
      'segment_rotate_top_edge',
      BorderBeam.rotate(
        style: style,
        shape: shape(BeamSegment.topEdge),
        child: surface(),
      ),
    );
  });

  testWidgets('rotate hard segment edge', (tester) async {
    await capture(
      tester,
      'segment_rotate_feather_0',
      BorderBeam.rotate(
        style: style,
        shape: shape(
          const BeamSegment(
            start: BeamAnchor.rightCenter,
            end: BeamAnchor.leftCenter,
            feather: 0,
          ),
        ),
        child: surface(),
      ),
    );
  });
}
