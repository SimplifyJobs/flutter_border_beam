import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/constants/line_keyframes.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_test/flutter_test.dart';

BeamConfig _config(
  BeamVariant v, {
  bool staticColors = false,
  double hueRange = 30,
}) => BeamConfig.resolve(
  variant: v,
  palette: BeamColors.colorful.resolve(),
  brightness: Brightness.dark,
  staticColors: staticColors,
  hueRange: hueRange,
);

void main() {
  group('sampleKeyframes', () {
    test('linear tables hit every stop exactly', () {
      for (final f in lineTravelX) {
        expect(sampleKeyframes(lineTravelX, f.t), closeTo(f.value, 1e-9));
      }
      // Linear midpoint between stops.
      expect(sampleKeyframes(lineTravelX, 0.05), closeTo(0.105, 1e-9));
    });

    test('eased tables hit stops and ease within segments', () {
      for (final f in lineBreatheH) {
        expect(
          sampleKeyframes(lineBreatheH, f.t, easedSegments: true),
          closeTo(f.value, 1e-9),
        );
      }
      // Just after a stop, an eased segment moves slower than linear.
      final eased = sampleKeyframes(lineSpike, 0.05, easedSegments: true);
      final linear = sampleKeyframes(lineSpike, 0.05);
      expect((eased - 0.8).abs(), lessThan((linear - 0.8).abs()));
    });

    test('clamps outside 0-1', () {
      expect(sampleKeyframes(lineEdgeFade, -0.5), 0);
      expect(sampleKeyframes(lineEdgeFade, 1.5), 0);
    });
  });

  group('BeamPhaseResolver', () {
    test('rotate: angle spins one turn per cycle', () {
      final r = BeamPhaseResolver(_config(BeamVariant.rotate));
      expect(r.sample(0, 1).angleRadians, closeTo(0, 1e-9));
      expect(r.sample(1.96 / 2, 1).angleRadians, closeTo(math.pi, 1e-6));
      expect(r.sample(1.96, 1).angleRadians, closeTo(0, 1e-6));
    });

    test('line: travel, edge fade, and hue cap', () {
      final config = _config(BeamVariant.line, hueRange: 30);
      expect(config.hueRange, 13, reason: 'line caps hueRange at 13°');
      final r = BeamPhaseResolver(config);
      final start = r.sample(0, 1);
      expect(start.lineX, closeTo(0.06, 1e-9));
      expect(start.edge, 0);
      final mid = r.sample(3.1 / 2, 1);
      expect(mid.lineX, closeTo(0.5, 1e-6));
      expect(mid.edge, 1);
    });

    test('hue modes: static, ping-pong, continuous', () {
      final staticR = BeamPhaseResolver(
        _config(BeamVariant.rotate, staticColors: true),
      );
      expect(staticR.sample(5, 1).hueDegrees, 0);

      final rotate = BeamPhaseResolver(_config(BeamVariant.rotate));
      expect(rotate.sample(0, 1).hueDegrees, closeTo(-30, 1e-6));
      expect(rotate.sample(6, 1).hueDegrees, closeTo(30, 1e-6));
      expect(rotate.sample(12, 1).hueDegrees, closeTo(-30, 1e-6));

      final pulse = BeamPhaseResolver(_config(BeamVariant.pulseInside));
      // Continuous sawtooth over 16s: quarter revolution at 4s.
      expect(pulse.sample(4, 1).hueDegrees, closeTo(90, 1e-6));
      expect(pulse.sample(16, 1).hueDegrees, closeTo(0, 1e-6));
    });

    test('mono palette forces static colors through config', () {
      final config = BeamConfig.resolve(
        variant: BeamVariant.rotate,
        palette: BeamColors.mono.resolve(),
        brightness: Brightness.dark,
      );
      expect(config.staticColors, isTrue);
      expect(BeamPhaseResolver(config).sample(3, 1).hueDegrees, 0);
    });

    test('static frame is full-opacity and hue-neutral', () {
      final pulse = BeamPhaseResolver(_config(BeamVariant.pulseOutside));
      final frame = pulse.staticFrame();
      expect(frame.fadeOpacity, 1);
      expect(frame.hueDegrees, 0);
      expect(frame.pulse.bgh, 1);
    });
  });

  group('BeamConfig.resolve', () {
    test('strength clamps and defaults resolve', () {
      final c = BeamConfig.resolve(
        variant: BeamVariant.small,
        palette: BeamColors.colorful.resolve(),
        brightness: Brightness.dark,
        strength: 1.7,
      );
      expect(c.strength, 1);
      expect(c.borderRadius, 32);
      expect(c.cycleSeconds, closeTo(1.96, 1e-9));
      expect(c.brightnessFactor, 1.3);
      expect(c.saturation, 1.2);
    });

    test('pulse presets carry brightness overrides', () {
      final c = BeamConfig.resolve(
        variant: BeamVariant.pulseInside,
        palette: BeamColors.colorful.resolve(),
        brightness: Brightness.dark,
      );
      expect(c.brightnessFactor, 0.75);
      expect(c.cycleSeconds, closeTo(2.3, 1e-9));
    });
  });
}
