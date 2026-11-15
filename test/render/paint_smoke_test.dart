import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/render/beam_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render_utils.dart';

/// Every effect × theme × palette subset × shape family paints visible light
/// through the real shader. A path the renderer cannot handle — a uniform
/// packed wrong, a shape the outline collapses, a palette the colour map
/// chokes on — shows up here as a blank frame.
void main() {
  setUpAll(BorderBeam.precache);

  for (final MapEntry(key: name, value: effect) in effectsByName.entries) {
    group(name, () {
      for (final brightness in Brightness.values) {
        for (final MapEntry(key: palette, value: colors)
            in paletteSubset.entries) {
          test('${brightness.name} $palette on every shape', () async {
            final renderer = BeamRenderer();
            addTearDown(renderer.dispose);
            for (final MapEntry(key: shapeName, value: shape)
                in shapeVariety.entries) {
              final config = configFor(
                effect,
                brightness: brightness,
                colors: colors,
                shape: shape,
              );
              final frame = await renderFrame(
                config,
                phasesAt(config, litSeconds(effect)),
                renderer: renderer,
              );
              expect(
                frame.lit(threshold: 8),
                greaterThan(0),
                reason: '$name/${brightness.name}/$palette/$shapeName is blank',
              );
            }
          });
        }
      }
    });
  }

  test('a superellipse and a stadium paint the small chip size too', () async {
    const chip = Size(70, 36);
    for (final effect in BeamEffect.values) {
      for (final shape in [
        const BeamShape.all(18, superellipse: true),
        const BeamShape.stadium(),
      ]) {
        final config = configFor(effect, shape: shape);
        final frame = await renderFrame(
          config,
          phasesAt(config, litSeconds(effect)),
          size: chip,
        );
        expect(frame.lit(threshold: 8), greaterThan(0), reason: '$effect');
      }
    }
  });
}
