@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_scene.dart';

/// The surface family — the shape options: superellipse corners, per-corner
/// radii, stadium, ring offset, segments, dashes, stroke width, and the line
/// on each edge.
///
/// Dark theme, colorful palette, t = 1.3s, so each image reads against the
/// plain `<effect>_dark_colorful` frame it varies.
void main() {
  setUpAll(BorderBeam.precache);

  Widget beam(
    BeamEffect effect,
    BeamShape shape, {
    Widget? surface,
    Size size = goldenCard,
    double? progress,
  }) => goldenScene(
    BorderBeam(
      effect: effect,
      shape: shape,
      progress: progress,
      style: const BeamStyle(theme: BeamTheme.dark),
      child: surface ?? mockSurface(Brightness.dark),
    ),
    size: size,
  );

  group('superellipse', () {
    for (final effect in const [BeamEffect.rotate(), BeamEffect.spin()]) {
      testWidgets(effect.name, (tester) async {
        await captureGolden(
          tester,
          'surface_${effect.name}_squircle',
          beam(
            effect,
            const BeamShape.all(28, superellipse: true),
            surface: mockSurface(
              Brightness.dark,
              radius: 28,
              superellipse: true,
            ),
          ),
        );
      });
    }
  });

  testWidgets('per-corner radii', (tester) async {
    const radii = BorderRadius.only(
      topLeft: Radius.circular(40),
      bottomRight: Radius.circular(8),
    );
    await captureGolden(
      tester,
      'surface_rotate_per_corner',
      beam(
        const BeamEffect.rotate(),
        const BeamShape(radius: radii),
        surface: mockSurface(Brightness.dark, radii: radii),
      ),
    );
  });

  testWidgets('stadium pill', (tester) async {
    await captureGolden(
      tester,
      'surface_rotate_stadium',
      beam(
        const BeamEffect.rotate(),
        const BeamShape.stadium(),
        surface: mockSurface(Brightness.dark, radius: 32),
        size: const Size(350, 64),
      ),
    );
  });

  testWidgets('stadium circle', (tester) async {
    await captureGolden(
      tester,
      'surface_spin_stadium_circle',
      beam(
        const BeamEffect.spin(),
        const BeamShape.stadium(),
        surface: mockSurface(Brightness.dark, radius: 60),
        size: const Size(120, 120),
      ),
    );
  });

  group('ring offset', () {
    for (final (label, offset) in [('8', 8.0), ('neg_6', -6.0)]) {
      testWidgets(label, (tester) async {
        await captureGolden(
          tester,
          'surface_rotate_ring_offset_$label',
          beam(
            const BeamEffect.rotate(),
            BeamShape.all(16 + offset, ringOffset: offset),
          ),
        );
      });
    }
  });

  group('segments', () {
    final scenes = <String, (BeamEffect, BeamSegment)>{
      'rotate_bottom_half': (const BeamEffect.rotate(), BeamSegment.bottomHalf),
      'pulse_top_half': (const BeamEffect.pulse(), BeamSegment.topHalf),
      'spin_right_edge': (const BeamEffect.spin(), BeamSegment.rightEdge),
      'rotate_hard_cut': (
        const BeamEffect.rotate(),
        const BeamSegment(
          start: BeamAnchor.fraction(0.1),
          end: BeamAnchor.fraction(0.9),
          feather: 0,
        ),
      ),
    };
    for (final MapEntry(key: name, value: (effect, segment))
        in scenes.entries) {
      testWidgets(name, (tester) async {
        await captureGolden(
          tester,
          'surface_segment_$name',
          beam(effect, BeamShape(segment: segment)),
        );
      });
    }

    // A charge fills its segment, not the whole border.
    testWidgets('charge in the bottom half', (tester) async {
      await captureGolden(
        tester,
        'surface_segment_charge_bottom_half_0_6',
        beam(
          const BeamEffect.charge(),
          const BeamShape(segment: BeamSegment.bottomHalf),
          progress: 0.6,
        ),
      );
    });
  });

  group('dashes', () {
    for (final effect in const [BeamEffect.spin(), BeamEffect.rotate()]) {
      testWidgets(effect.name, (tester) async {
        await captureGolden(
          tester,
          'surface_${effect.name}_dashes_12',
          beam(effect, const BeamShape(dashes: 12)),
        );
      });
    }
  });

  testWidgets('border width', (tester) async {
    await captureGolden(
      tester,
      'surface_rotate_border_width_3',
      beam(const BeamEffect.rotate(), const BeamShape(borderWidth: 3)),
    );
  });

  group('line edge', () {
    for (final edge in BeamEdge.values) {
      testWidgets(edge.name, (tester) async {
        await captureGolden(
          tester,
          'surface_line_${edge.name}',
          beam(BeamEffect.line(edge: edge), const BeamShape()),
        );
      });
    }
  });
}
