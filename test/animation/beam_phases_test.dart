import 'dart:math' as math;
import 'dart:ui' show Brightness;

import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_palette.dart';
import 'package:flutter_test/flutter_test.dart';

BeamConfig _config({
  BeamEffect effect = const BeamEffect.rotate(),
  BeamPalette? palette,
  BeamHueMode? hueMode,
  double? hueShift,
  Duration? cycle = const Duration(seconds: 2),
  Duration? cycleGap,
  Duration? huePeriod,
  double? phaseOffset,
  BeamDirection? direction,
}) => BeamConfig.resolve(
  effect: effect,
  palette: palette ?? BeamColors.colorful.resolve(),
  brightness: Brightness.dark,
  style: BeamStyle(hueMode: hueMode, hueShift: hueShift),
  timing: BeamTiming(
    cycle: cycle,
    cycleGap: cycleGap,
    huePeriod: huePeriod,
    phaseOffset: phaseOffset,
    direction: direction,
  ),
);

BeamPhaseResolver _resolver({
  BeamEffect effect = const BeamEffect.rotate(),
  BeamPalette? palette,
  BeamHueMode? hueMode,
  double? hueShift,
  Duration? cycle = const Duration(seconds: 2),
  Duration? cycleGap,
  Duration? huePeriod,
  double? phaseOffset,
  BeamDirection? direction,
}) => BeamPhaseResolver(
  _config(
    effect: effect,
    palette: palette,
    hueMode: hueMode,
    hueShift: hueShift,
    cycle: cycle,
    cycleGap: cycleGap,
    huePeriod: huePeriod,
    phaseOffset: phaseOffset,
    direction: direction,
  ),
);

/// The non-travel half of the phase resolver: the hue drift, the ambient
/// cycle count, the per-track time offsets the widget uses to keep tracks
/// continuous, the repeat budget, and the reduced-motion static frame.
void main() {
  final ambient = BeamEffect.values.where((e) => !e.travels).toList();
  const huePeriod = Duration(seconds: 8);
  const period = 8.0;

  group('hue', () {
    test('none never drifts', () {
      final r = _resolver(hueMode: BeamHueMode.none);
      for (final t in [0.0, 1.3, 4.0, 99.9]) {
        expect(r.sample(t, 1).hueDegrees, 0);
      }
    });

    test('a fixed-hue palette never drifts', () {
      for (final colors in [BeamColors.mono, BeamColors.gold]) {
        final r = _resolver(
          palette: colors.resolve(),
          hueMode: BeamHueMode.continuous,
        );
        expect(r.sample(3.3, 1).hueDegrees, 0, reason: '$colors');
      }
    });

    test('continuous revolves through 360° once per hue period', () {
      final r = _resolver(
        hueMode: BeamHueMode.continuous,
        huePeriod: huePeriod,
      );
      expect(r.sample(0, 1).hueDegrees, 0);
      expect(r.sample(period / 4, 1).hueDegrees, closeTo(90, 1e-9));
      expect(r.sample(period / 2, 1).hueDegrees, closeTo(180, 1e-9));
      expect(r.sample(period * 0.999, 1).hueDegrees, greaterThan(359));
      expect(r.sample(period, 1).hueDegrees, closeTo(0, 1e-9));
      expect(r.sample(period * 1.25, 1).hueDegrees, closeTo(90, 1e-9));
    });

    test('continuous ignores hueShift', () {
      final narrow = _resolver(
        hueMode: BeamHueMode.continuous,
        hueShift: 5,
        huePeriod: huePeriod,
      );
      final wide = _resolver(
        hueMode: BeamHueMode.continuous,
        hueShift: 90,
        huePeriod: huePeriod,
      );
      expect(narrow.sample(3, 1).hueDegrees, wide.sample(3, 1).hueDegrees);
    });

    test('pingPong swings −shift → +shift → −shift over one period', () {
      final r = _resolver(
        hueMode: BeamHueMode.pingPong,
        hueShift: 20,
        huePeriod: huePeriod,
      );
      expect(r.sample(0, 1).hueDegrees, closeTo(-20, 1e-9));
      expect(r.sample(period / 2, 1).hueDegrees, closeTo(20, 1e-9));
      expect(r.sample(period, 1).hueDegrees, closeTo(-20, 1e-9));
      // Symmetric easing crosses zero at each quarter.
      expect(r.sample(period / 4, 1).hueDegrees, closeTo(0, 1e-6));
      expect(r.sample(period * 3 / 4, 1).hueDegrees, closeTo(0, 1e-6));
    });

    test('pingPong stays within ±hueShift and reaches both ends', () {
      for (final shift in [0.0, 13.0, 45.0]) {
        final r = _resolver(
          hueMode: BeamHueMode.pingPong,
          hueShift: shift,
          huePeriod: huePeriod,
        );
        var lo = double.infinity;
        var hi = double.negativeInfinity;
        for (var i = 0; i <= 800; i++) {
          final hue = r.sample(i * 0.01, 1).hueDegrees;
          expect(hue, inInclusiveRange(-shift - 1e-9, shift + 1e-9));
          if (hue < lo) lo = hue;
          if (hue > hi) hi = hue;
        }
        expect(lo, closeTo(-shift, 1e-9), reason: 'shift $shift');
        expect(hi, closeTo(shift, 1e-9), reason: 'shift $shift');
      }
    });

    test('the hue period moves the hue and nothing else', () {
      final fast = _resolver(huePeriod: const Duration(seconds: 3));
      final slow = _resolver(huePeriod: const Duration(seconds: 30));
      final a = fast.sample(1.2, 1);
      final b = slow.sample(1.2, 1);
      expect(a.hueDegrees, isNot(closeTo(b.hueDegrees, 1e-3)));
      expect(a.travelProgress, b.travelProgress);
      expect(a.cycles, b.cycles);
      expect(a.fadeOpacity, b.fadeOpacity);
    });

    test('the hue keeps drifting through a cycle gap', () {
      final r = _resolver(
        cycleGap: const Duration(seconds: 2),
        hueMode: BeamHueMode.continuous,
        huePeriod: huePeriod,
      );
      // 3s is mid-gap: the beam is dark, but the colours still move.
      expect(r.sample(3, 1).fadeOpacity, 0);
      expect(r.sample(3, 1).hueDegrees, isNot(r.sample(2.5, 1).hueDegrees));
    });

    for (final effect in BeamEffect.values) {
      test('${effect.name}: the default mode drifts as configured', () {
        final r = _resolver(effect: effect);
        final mode = r.config.hueMode;
        expect(mode, effect.defaultHueMode);
        final p = r.config.huePeriodSeconds;
        final shift = r.config.hueShift;
        final hues = <double>{};
        for (var i = 0; i < 50; i++) {
          final hue = r.sample(i * p / 37, 1).hueDegrees;
          hues.add(hue);
          switch (mode) {
            case BeamHueMode.none:
              expect(hue, 0);
            case BeamHueMode.continuous:
              expect(hue, inInclusiveRange(0, 360));
              expect(hue, lessThan(360));
            case BeamHueMode.pingPong:
              expect(hue, inInclusiveRange(-shift - 1e-9, shift + 1e-9));
          }
        }
        // A drifting mode actually moves: a hue stuck at 0 satisfies every
        // range above.
        if (mode != BeamHueMode.none) {
          expect(hues.length, greaterThan(10), reason: '$mode');
          final span = hues.reduce(math.max) - hues.reduce(math.min);
          final expected = mode == BeamHueMode.pingPong ? shift : 180.0;
          expect(span, greaterThan(expected), reason: '$mode: span $span');
        }
      });
    }
  });

  group('cycles', () {
    for (final effect in BeamEffect.values) {
      test('${effect.name}: counts elapsed cycles without wrapping', () {
        final r = _resolver(effect: effect, cycleGap: Duration.zero);
        expect(r.sample(0, 1).cycles, 0);
        expect(r.sample(1, 1).cycles, closeTo(0.5, 1e-12));
        expect(r.sample(7.3, 1).cycles, closeTo(3.65, 1e-12));
        expect(r.sample(1000, 1).cycles, closeTo(500, 1e-9));
      });
    }

    test('the gap does not stretch the ambient clock', () {
      final r = _resolver(cycleGap: const Duration(seconds: 1));
      expect(r.sample(6, 1).cycles, closeTo(3, 1e-12));
    });

    test('phaseOffset puts an ambient beam out of step', () {
      for (final effect in ambient) {
        final plain = _resolver(effect: effect);
        final shifted = _resolver(effect: effect, phaseOffset: 0.5);
        expect(
          shifted.sample(1, 1).cycles - plain.sample(1, 1).cycles,
          closeTo(0.5, 1e-12),
          reason: effect.name,
        );
      }
    });
  });

  group('time offsets', () {
    test('hueTimeOffset shifts only the hue', () {
      final plain = _resolver(effect: const BeamEffect.pulse());
      final shifted = _resolver(effect: const BeamEffect.pulse())
        ..hueTimeOffset = 2;
      final a = shifted.sample(3, 1);
      expect(a.hueDegrees, closeTo(plain.sample(5, 1).hueDegrees, 1e-9));
      expect(a.cycles, plain.sample(3, 1).cycles);

      final rotate = _resolver()..hueTimeOffset = -1.5;
      final rotatePlain = _resolver();
      expect(
        rotate.sample(4, 1).hueDegrees,
        closeTo(rotatePlain.sample(2.5, 1).hueDegrees, 1e-9),
      );
      expect(
        rotate.sample(4, 1).travelProgress,
        rotatePlain.sample(4, 1).travelProgress,
      );
    });

    test('breatheTimeOffset shifts only the ambient clock', () {
      final plain = _resolver();
      final shifted = _resolver()..breatheTimeOffset = 1;
      final a = shifted.sample(3, 1);
      final b = plain.sample(3, 1);
      expect(a.cycles, closeTo(b.cycles + 0.5, 1e-12));
      expect(a.travelProgress, b.travelProgress);
      expect(a.hueDegrees, b.hueDegrees);
    });

    test('travelTimeOffset shifts only the sweep and the repeat budget', () {
      final plain = _resolver()..repeatCycles = 1;
      final shifted = _resolver()
        ..repeatCycles = 1
        ..travelTimeOffset = 1;
      final a = shifted.sample(0.5, 1);
      final b = plain.sample(0.5, 1);
      expect(a.travelProgress, closeTo(b.travelProgress + 0.5, 1e-12));
      expect(a.hueDegrees, b.hueDegrees);
      expect(a.cycles, b.cycles);
      expect(plain.finishedAt(1.5), isFalse);
      expect(shifted.finishedAt(1.5), isTrue);
    });

    test('a retime with a hue correction holds every track', () {
      // What the widget does when the cycle changes mid-run: rescale
      // elapsed time by the cycle ratio, and shift the fixed-period hue
      // track back by the amount the timeline moved.
      for (final effect in BeamEffect.values) {
        final before = _resolver(
          effect: effect,
          cycleGap: Duration.zero,
          cycle: const Duration(seconds: 2),
        );
        final after = _resolver(
          effect: effect,
          cycleGap: Duration.zero,
          cycle: const Duration(milliseconds: 4500),
        );
        const t = 1.3;
        final scaled =
            t * after.config.cycleSeconds / before.config.cycleSeconds;
        after.hueTimeOffset = t - scaled;
        final a = before.sample(t, 1);
        final b = after.sample(scaled, 1);
        expect(b.travelProgress, closeTo(a.travelProgress, 1e-9));
        expect(b.cycles, closeTo(a.cycles, 1e-9), reason: effect.name);
        expect(b.hueDegrees, closeTo(a.hueDegrees, 1e-9), reason: effect.name);
      }
    });
  });

  group('repeat budget', () {
    test('no budget never finishes', () {
      final r = _resolver();
      expect(r.finishedAt(1e6), isFalse);
      expect(r.sample(1e6, 1).finished, isFalse);
    });

    test('a budget of n finishes at the n-th cycle boundary', () {
      for (final n in [1, 3]) {
        final r = _resolver()..repeatCycles = n;
        expect(r.finishedAt(n * 2 - 0.001), isFalse, reason: 'n=$n');
        expect(r.finishedAt(n * 2 + 0.001), isTrue, reason: 'n=$n');
        expect(r.sample(n * 2 + 0.001, 1).finished, isTrue);
        expect(r.sample(n * 2 - 0.001, 1).finished, isFalse);
      }
    });

    test('a travelling gap counts toward its cycle', () {
      final r = _resolver(cycleGap: const Duration(seconds: 1))
        ..repeatCycles = 1;
      expect(r.finishedAt(2.5), isFalse);
      expect(r.finishedAt(3.01), isTrue);
    });

    test('ambient effects ignore a configured gap', () {
      for (final effect in ambient) {
        final r = _resolver(
          effect: effect,
          cycleGap: const Duration(seconds: 1),
        )..repeatCycles = 2;
        expect(r.sample(3.99, 1).finished, isFalse, reason: effect.name);
        expect(r.sample(4.01, 1).finished, isTrue, reason: effect.name);
      }
    });

    test('a phase offset moves the finish with the timeline', () {
      final r = _resolver(phaseOffset: 0.5)..repeatCycles = 1;
      expect(r.finishedAt(0.9), isFalse);
      expect(r.finishedAt(1.1), isTrue);
    });

    test('sample and finishedAt agree', () {
      for (final effect in BeamEffect.values) {
        final r = _resolver(effect: effect)..repeatCycles = 2;
        for (var i = 0; i < 40; i++) {
          final t = i * 0.37;
          expect(r.sample(t, 1).finished, r.finishedAt(t), reason: '$t');
        }
      }
    });
  });

  group('staticFrame', () {
    for (final effect in BeamEffect.values) {
      test('${effect.name}: full opacity, hue-neutral, deterministic', () {
        final r = _resolver(effect: effect, hueMode: BeamHueMode.continuous);
        final a = r.staticFrame();
        final b = r.staticFrame();
        expect(a.fadeOpacity, 1);
        expect(a.hueDegrees, 0, reason: 'the palette as given');
        expect(a.hueTime, isNull, reason: "no time for an effect's own drift");
        expect(r.sample(2, 1).hueTime, 2, reason: 'a running frame has one');
        expect(a.driven, isFalse);
        expect(a.finished, isFalse);
        expect(a.travelProgress, b.travelProgress);
        expect(a.travellers, b.travellers);
        expect(a.cycles, b.cycles);
        expect(a.cycles.isFinite, isTrue);
      });
    }

    test('a travelling effect shows the sweep mid-border', () {
      for (final effect in BeamEffect.values.where((e) => e.travels)) {
        final frame = _resolver(effect: effect).staticFrame();
        expect(frame.travelProgress, inExclusiveRange(0, 1));
      }
      final three = _resolver(
        effect: const BeamEffect.rotate(count: 3),
      ).staticFrame();
      expect(three.travellers, hasLength(3));
      expect(three.travellers.first, three.travelProgress);
    });

    test('travels the way the beam does: partway through the first sweep', () {
      // Every direction, including a mirrored one, against the frame the
      // running beam paints at the same point of its first cycle: the head,
      // the order of the beams behind it, and which way it is facing.
      for (final effect in [
        ...BeamEffect.values.where((e) => e.travels),
        const BeamEffect.rotate(count: 3),
      ]) {
        for (final direction in BeamDirection.values) {
          final r = _resolver(effect: effect, direction: direction);
          final still = r.staticFrame();
          final timed = r.sample(0.35 * r.config.cycleSeconds, 1);
          final reason = '${effect.name} ${direction.name}';
          expect(still.reversedNow, timed.reversedNow, reason: reason);
          expect(still.travellers, hasLength(timed.travellers.length));
          for (var i = 0; i < timed.travellers.length; i++) {
            expect(
              still.travellers[i],
              closeTo(timed.travellers[i], 1e-9),
              reason: '$reason, beam $i',
            );
          }
        }
      }
      final reversed = _resolver(
        direction: BeamDirection.reverse,
      ).staticFrame();
      expect(reversed.reversedNow, isTrue);
      expect(reversed.travelProgress, closeTo(0.65, 1e-12));
    });

    test('a phase offset moves the ambient clock, as it does when running', () {
      for (final effect in BeamEffect.values) {
        final plain = _resolver(effect: effect);
        final shifted = _resolver(effect: effect, phaseOffset: 0.5);
        for (final progress in [null, 0.4]) {
          expect(
            shifted.staticFrame(progress: progress).cycles -
                plain.staticFrame(progress: progress).cycles,
            closeTo(0.5, 1e-12),
            reason: '${effect.name}, progress $progress',
          );
        }
        // The sweep stays where the frame is lit.
        expect(
          shifted.staticFrame().travelProgress,
          plain.staticFrame().travelProgress,
          reason: effect.name,
        );
      }
    });

    test('honours a driven progress, clamped', () {
      final r = _resolver();
      final frame = r.staticFrame(progress: 0.25);
      expect(frame.travelProgress, 0.25);
      expect(frame.driven, isTrue);
      expect(r.staticFrame(progress: 1.4).travelProgress, 1);
      expect(r.staticFrame(progress: -1).travelProgress, 0);
    });

    test('an ambient effect has no travel, driven or not', () {
      for (final effect in ambient) {
        final frame = _resolver(effect: effect).staticFrame(progress: 0.6);
        expect(frame.travelProgress, 0, reason: effect.name);
        expect(frame.travellers, [0]);
        expect(frame.driven, isFalse);
      }
    });
  });
}
