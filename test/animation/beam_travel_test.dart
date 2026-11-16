import 'dart:ui' show Brightness;

import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _cycle = Duration(seconds: 2);
const double _cycleSeconds = 2;

BeamPhaseResolver _resolver({
  BeamEffect effect = const BeamEffect.rotate(),
  BeamDirection? direction,
  double? phaseOffset,
  Duration? cycleGap = Duration.zero,
}) => BeamPhaseResolver(
  BeamConfig.resolve(
    effect: effect,
    palette: BeamColors.colorful.resolve(),
    brightness: Brightness.dark,
    timing: BeamTiming(
      cycle: _cycle,
      cycleGap: cycleGap,
      direction: direction,
      phaseOffset: phaseOffset,
    ),
  ),
);

/// Distance between two sweep positions around the ring.
double _ringDistance(double a, double b) => ((a - b + 0.5) % 1 - 0.5).abs();

/// The travel half of the phase resolver: where a travelling effect's sweep
/// sits, which way it runs, how it rests between sweeps, and how a driven
/// progress takes it over. All of it is a pure function of elapsed time, so
/// it is tested against the resolver directly.
void main() {
  final travelling = BeamEffect.values.where((e) => e.travels).toList();
  final ambient = BeamEffect.values.where((e) => !e.travels).toList();

  group('forward travel', () {
    for (final effect in travelling) {
      test('${effect.name}: runs 0 → 1 once per cycle', () {
        final r = _resolver(effect: effect);
        for (final (t, expected) in [
          (0.0, 0.0),
          (0.5, 0.25),
          (1.0, 0.5),
          (1.5, 0.75),
          (2.5, 0.25),
          (9.0, 0.5),
        ]) {
          final phases = r.sample(t, 1);
          expect(
            phases.travelProgress,
            closeTo(expected, 1e-9),
            reason: 't=$t',
          );
          expect(phases.travellers, [phases.travelProgress]);
          expect(phases.reversedNow, isFalse);
          expect(phases.driven, isFalse);
          expect(phases.fadeOpacity, 1, reason: 'no gap, no envelope');
        }
      });
    }

    test('the fade passes straight through without a gap', () {
      final r = _resolver();
      for (final fade in [0.0, 0.3, 1.0]) {
        expect(r.sample(0.7, fade).fadeOpacity, fade);
      }
    });
  });

  group('direction', () {
    for (final effect in travelling) {
      test('${effect.name}: reverse mirrors the forward sweep and flags the '
          'frame', () {
        final forward = _resolver(effect: effect);
        final reverse = _resolver(
          effect: effect,
          direction: BeamDirection.reverse,
        );
        for (final t in [0.1, 0.4, 1.1, 1.5, 5.3]) {
          expect(
            reverse.sample(t, 1).travelProgress,
            closeTo(1 - forward.sample(t, 1).travelProgress, 1e-9),
            reason: 't=$t',
          );
          expect(reverse.sample(t, 1).reversedNow, isTrue);
        }
      });
    }

    test('bounce alternates per cycle, starting forward', () {
      final r = _resolver(direction: BeamDirection.bounce);
      for (final (cycle, reversed) in [(0, false), (1, true), (2, false)]) {
        final phases = r.sample((cycle + 0.25) * _cycleSeconds, 1);
        expect(phases.reversedNow, reversed, reason: 'cycle $cycle');
        expect(
          phases.travelProgress,
          closeTo(reversed ? 0.75 : 0.25, 1e-9),
          reason: 'cycle $cycle',
        );
      }
    });

    test('bounce turns around where the last sweep ended', () {
      final r = _resolver(direction: BeamDirection.bounce);
      const eps = 1e-6;
      expect(
        r.sample(_cycleSeconds - eps, 1).travelProgress,
        closeTo(r.sample(_cycleSeconds + eps, 1).travelProgress, 1e-5),
      );
    });

    test('bounce counts the gap as part of the cycle', () {
      final r = _resolver(
        direction: BeamDirection.bounce,
        cycleGap: const Duration(seconds: 1),
      );
      // The sweep ends at 2s but the cycle only at 3s: the rest still
      // belongs to the forward cycle.
      expect(r.sample(2.5, 1).reversedNow, isFalse);
      expect(r.sample(3.5, 1).reversedNow, isTrue);
      expect(r.sample(6.5, 1).reversedNow, isFalse);
    });

    test('ambient effects report reverse but ignore bounce', () {
      for (final effect in ambient) {
        expect(
          _resolver(
            effect: effect,
            direction: BeamDirection.reverse,
          ).sample(1, 1).reversedNow,
          isTrue,
          reason: effect.name,
        );
        expect(
          _resolver(
            effect: effect,
            direction: BeamDirection.bounce,
          ).sample(_cycleSeconds * 1.5, 1).reversedNow,
          isFalse,
          reason: effect.name,
        );
      }
    });
  });

  group('cycle gap', () {
    const gap = Duration(seconds: 1);

    test('the sweep runs over the cycle, then parks at its end', () {
      final r = _resolver(cycleGap: gap);
      expect(r.sample(1, 1).travelProgress, closeTo(0.5, 1e-9));
      for (final t in [2.0, 2.1, 2.5, 2.9]) {
        expect(r.sample(t, 1).travelProgress, 1, reason: 't=$t');
      }
      // The next sweep starts one cycle + gap later.
      expect(r.sample(3, 1).travelProgress, closeTo(0, 1e-9));
      expect(r.sample(4, 1).travelProgress, closeTo(0.5, 1e-9));
    });

    test('reverse parks at the mirrored end', () {
      final r = _resolver(cycleGap: gap, direction: BeamDirection.reverse);
      expect(r.sample(2.5, 1).travelProgress, closeTo(0, 1e-9));
      expect(r.sample(2.5, 1).fadeOpacity, 0);
    });

    test('the envelope eases out, rests at 0, and eases back in', () {
      final r = _resolver(cycleGap: gap);
      double envelope(double t) => r.sample(t, 1).fadeOpacity;

      expect(envelope(1.9), 1, reason: 'full strength while sweeping');
      expect(envelope(2.5), 0, reason: 'dark mid-gap');
      // Eases out across the start of the gap, monotonically.
      var last = 1.0;
      for (var t = 2.0; t <= 2.5; t += 0.02) {
        final e = envelope(t);
        expect(e, inInclusiveRange(0, 1));
        expect(e, lessThanOrEqualTo(last + 1e-12), reason: 't=$t');
        last = e;
      }
      // And back in across its end.
      last = 0;
      for (var t = 2.5; t < 3.0; t += 0.02) {
        final e = envelope(t);
        expect(e, greaterThanOrEqualTo(last - 1e-12), reason: 't=$t');
        last = e;
      }
      expect(envelope(2.02), inExclusiveRange(0, 1));
      expect(envelope(2.98), inExclusiveRange(0, 1));
      expect(envelope(2.999), closeTo(1, 1e-3), reason: 'continuous at wrap');
      expect(envelope(3.0), 1);
      // The fade back in mirrors the fade out.
      for (final x in [0.05, 0.1, 0.2]) {
        expect(envelope(2 + x), closeTo(envelope(3 - x), 1e-9), reason: '$x');
      }
    });

    test('a short gap still goes dark in the middle', () {
      final r = _resolver(cycleGap: const Duration(milliseconds: 100));
      expect(r.sample(2.05, 1).fadeOpacity, closeTo(0, 1e-9));
      // The next sweep begins once the 100ms rest is over.
      expect(r.sample(2.2, 1).travelProgress, closeTo(0.05, 1e-9));
    });

    test('the envelope multiplies the fade it is given', () {
      final r = _resolver(cycleGap: gap);
      final full = r.sample(2.1, 1).fadeOpacity;
      expect(r.sample(2.1, 0.5).fadeOpacity, closeTo(full * 0.5, 1e-12));
    });

    test('ambient effects never rest', () {
      for (final effect in ambient) {
        final r = _resolver(effect: effect, cycleGap: gap);
        for (final t in [0.5, 2.5, 2.9, 7.4]) {
          final phases = r.sample(t, 0.8);
          expect(phases.fadeOpacity, 0.8, reason: '${effect.name} t=$t');
          expect(phases.travelProgress, 0);
          expect(phases.travellers, [0]);
          expect(
            phases.cycles,
            closeTo(t / r.config.cycleSeconds, 1e-9),
            reason: '${effect.name}: no pause at t=$t',
          );
        }
      }
    });
  });

  group('phaseOffset', () {
    test('starts the sweep that fraction of a cycle in', () {
      final r = _resolver(phaseOffset: 0.25);
      expect(r.sample(0, 1).travelProgress, closeTo(0.25, 1e-9));
      expect(r.sample(1, 1).travelProgress, closeTo(0.75, 1e-9));
    });

    test('a reversed sweep starts the same fraction into its cycle', () {
      final r = _resolver(phaseOffset: 0.25, direction: BeamDirection.reverse);
      expect(r.sample(0, 1).travelProgress, closeTo(0.75, 1e-9));
    });

    test('a whole-cycle offset is the identity', () {
      final plain = _resolver();
      final shifted = _resolver(phaseOffset: 1);
      for (final t in [0.3, 0.7, 1.9]) {
        expect(
          shifted.sample(t, 1).travelProgress,
          closeTo(plain.sample(t, 1).travelProgress, 1e-9),
        );
      }
    });

    test('leaves the hue alone', () {
      final plain = _resolver();
      final shifted = _resolver(phaseOffset: 0.5);
      expect(
        shifted.sample(1.3, 1).hueDegrees,
        plain.sample(1.3, 1).hueDegrees,
      );
    });
  });

  group('rotate count', () {
    BeamPhaseResolver counted(int n, {BeamDirection? direction}) => _resolver(
      effect: BeamEffect.rotate(count: n),
      direction: direction,
    );

    test('spaces the beams evenly, head first', () {
      final phases = counted(3).sample(0.2, 1);
      expect(phases.travellers, hasLength(3));
      expect(phases.travelProgress, phases.travellers.first);
      expect(phases.travellers[0], closeTo(0.1, 1e-9));
      expect(phases.travellers[1], closeTo(0.1 + 1 / 3, 1e-9));
      expect(phases.travellers[2], closeTo(0.1 + 2 / 3, 1e-9));
    });

    test('wraps trailing beams into [0, 1)', () {
      final phases = counted(4).sample(0.9 * _cycleSeconds, 1);
      for (final p in phases.travellers) {
        expect(p, inInclusiveRange(0, 1));
        expect(p, lessThan(1));
      }
      expect(phases.travellers[1], closeTo(0.15, 1e-9));
    });

    test('count 1 is a single beam', () {
      expect(counted(1).sample(0.3, 1).travellers, hasLength(1));
    });

    test('the spacing holds all the way round', () {
      for (var n = 2; n <= 4; n++) {
        final r = counted(n);
        for (final t in [0.0, 0.3, 1.1, 1.9, 4.4]) {
          final travellers = r.sample(t, 1).travellers;
          for (var i = 1; i < n; i++) {
            expect(
              (travellers[i] - travellers[i - 1]) % 1,
              closeTo(1 / n, 1e-9),
              reason: 'n=$n t=$t beam $i',
            );
          }
        }
      }
    });

    test('reverse spreads the beams the other way round', () {
      final phases = counted(
        2,
        direction: BeamDirection.reverse,
      ).sample(0.2, 1);
      expect(phases.travellers.first, closeTo(0.9, 1e-9));
      expect(phases.travellers[1], closeTo(0.4, 1e-9));
      final three = counted(3, direction: BeamDirection.reverse).sample(0.2, 1);
      for (var i = 1; i < 3; i++) {
        expect(
          (three.travellers[i - 1] - three.travellers[i]) % 1,
          closeTo(1 / 3, 1e-9),
        );
      }
    });

    test('other effects carry a single traveller', () {
      for (final effect in BeamEffect.values) {
        if (effect is RotateEffect) continue;
        expect(
          _resolver(effect: effect).sample(0.7, 1).travellers,
          hasLength(1),
          reason: effect.name,
        );
      }
    });
  });

  group('driven progress', () {
    test('replaces the sweep with the clamped value', () {
      final r = _resolver();
      for (final (p, expected) in [
        (0.25, 0.25),
        (0.0, 0.0),
        (1.0, 1.0),
        (1.4, 1.0),
        (-0.3, 0.0),
      ]) {
        final phases = r.sample(0.9, 1, progress: p);
        expect(phases.travelProgress, expected, reason: 'progress $p');
        expect(phases.driven, isTrue);
      }
    });

    test('holds at any time, through a gap, at full envelope', () {
      final r = _resolver(cycleGap: const Duration(seconds: 1));
      for (final t in [0.3, 2.5, 7.4]) {
        final phases = r.sample(t, 0.6, progress: 0.4);
        expect(phases.travelProgress, closeTo(0.4, 1e-12), reason: 't=$t');
        expect(phases.fadeOpacity, 0.6, reason: 'a readout never rests');
      }
    });

    test('keeps the hue and the ambient clock running', () {
      final r = _resolver();
      final early = r.sample(0.4, 1, progress: 0.5);
      final late = r.sample(3.4, 1, progress: 0.5);
      expect(early.hueDegrees, isNot(late.hueDegrees));
      expect(late.cycles - early.cycles, closeTo(1.5, 1e-9));
    });

    test('spreads several beams around the driven position', () {
      final phases = _resolver(
        effect: const BeamEffect.rotate(count: 2),
      ).sample(0, 1, progress: 0.25);
      expect(phases.travellers, hasLength(2));
      expect(phases.travellers[1], closeTo(0.75, 1e-12));
    });

    test('ambient effects ignore it', () {
      for (final effect in ambient) {
        final phases = _resolver(effect: effect).sample(1, 1, progress: 0.7);
        expect(phases.travelProgress, 0, reason: effect.name);
        expect(phases.driven, isFalse, reason: effect.name);
      }
    });
  });

  group('travelTimeOffset', () {
    test('shifts the sweep and nothing else', () {
      final plain = _resolver();
      final shifted = _resolver()..travelTimeOffset = 0.25 * _cycleSeconds;
      expect(shifted.sample(0, 1).travelProgress, closeTo(0.25, 1e-9));
      final a = shifted.sample(1.3, 1);
      final b = plain.sample(1.3, 1);
      expect(
        _ringDistance(a.travelProgress, b.travelProgress),
        closeTo(0.25, 1e-9),
      );
      expect(a.hueDegrees, b.hueDegrees);
      expect(a.cycles, b.cycles);
    });

    test('a negative offset runs the sweep behind', () {
      final r = _resolver()..travelTimeOffset = -0.25 * _cycleSeconds;
      expect(r.sample(1, 1).travelProgress, closeTo(0.25, 1e-9));
    });
  });
}
