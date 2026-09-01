import 'dart:ui' as ui;

import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_shape.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every variant × brightness × palette × shape paints without throwing and
  // produces pixels, sampled across the animation cycle. This catches shader
  // stop mismatches, invalid opacities, and geometry regressions cheaply;
  // exact appearance is covered by goldens.
  const size = ui.Size(350, 140);
  final palettes = {
    'colorful': BeamColors.colorful,
    'mono': BeamColors.mono,
    'ocean': BeamColors.ocean,
    'sunset': BeamColors.sunset,
    'custom': const BeamColors.custom([ui.Color(0xFFFF0080)]),
  };

  for (final variant in BeamVariant.values) {
    for (final brightness in ui.Brightness.values) {
      for (final MapEntry(key: name, value: colors) in palettes.entries) {
        for (final superellipse in [false, true]) {
          test('$variant/$brightness/$name'
              '${superellipse ? '/squircle' : ''} paints', () async {
            final config = BeamConfig.resolve(
              variant: variant,
              palette: colors.resolve(),
              brightness: brightness,
              shape: BeamShape(superellipse: superellipse),
            );
            final resolver = BeamPhaseResolver(config);
            final strategy = strategyFor(variant);
            // The line variant paints nothing at cycle edges (edge-fade
            // keyframe is 0 there), so pixels are required across the
            // samples, not at each one.
            var anyPixels = false;
            for (final t in [0.0, 0.5, 1.3, 7.9]) {
              final recorder = ui.PictureRecorder();
              final canvas = ui.Canvas(recorder);
              final phases = resolver.sample(t, 1);
              strategy.paintBehind(canvas, size, config, phases);
              strategy.paintAbove(canvas, size, config, phases);
              final picture = recorder.endRecording();
              final image = await picture.toImage(
                size.width.toInt(),
                size.height.toInt(),
              );
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
                if (bytes.getUint8(i) != 0) {
                  anyPixels = true;
                  break;
                }
              }
            }
            // The beam must produce non-transparent pixels somewhere in the
            // cycle.
            expect(anyPixels, isTrue, reason: 'no pixels painted');
          });
        }
      }
    }
  }
}
