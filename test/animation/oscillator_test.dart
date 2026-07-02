import 'dart:ui';

import 'package:border_beam/src/animation/oscillator.dart';
import 'package:border_beam/src/constants/pulse_params.dart';
import 'package:border_beam/src/models/beam_variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pingPong', () {
    test('endpoints and midpoint', () {
      expect(pingPong(0), closeTo(0, 1e-12));
      expect(pingPong(0.5), closeTo(1, 1e-12));
      expect(pingPong(1), closeTo(0, 1e-12));
      expect(pingPong(0.25), closeTo(0.5, 1e-12));
    });

    test('negative phases are valid and symmetric (cosine is even)', () {
      expect(pingPong(-0.25), closeTo(pingPong(0.25), 1e-12));
      expect(pingPong(-1.5), closeTo(pingPong(1.5), 1e-12));
    });
  });

  group('PulseOscillator', () {
    test('hits a at phase 0 and b at half period, honoring delay', () {
      const osc = PulseOscillator(a: 2, b: 8, period: 4, delay: 1);
      expect(osc.sample(1), closeTo(2, 1e-9));
      expect(osc.sample(3), closeTo(8, 1e-9));
      expect(osc.sample(5), closeTo(2, 1e-9));
      // Before the delay: negative phase, still smooth and bounded.
      final early = osc.sample(0);
      expect(early, inInclusiveRange(2, 8));
    });

    test('delay desyncs otherwise identical oscillators', () {
      const a = PulseOscillator(a: 0, b: 1, period: 2);
      const b = PulseOscillator(a: 0, b: 1, period: 2, delay: 0.5);
      expect(a.sample(1), isNot(closeTo(b.sample(1), 1e-6)));
    });
  });

  group('PulseOscillatorBank', () {
    test('pulse-outside light theme has no opacity breathing (op = 0)', () {
      final p = PulseParams.resolve(
        BeamVariant.pulseOutside,
        Brightness.light,
        2.3,
      );
      expect(p.op, 0);
      final bank = PulseOscillatorBank(p);
      for (final t in [0.0, 0.7, 1.9, 3.4]) {
        final s = bank.sample(t);
        expect(s.bopTl, closeTo(1, 1e-9));
        expect(s.bopBr, closeTo(1, 1e-9));
      }
    });

    test(
      'dark pulse-inner breathes within [1-op, 1] and sizes within spec',
      () {
        final p = PulseParams.resolve(
          BeamVariant.pulseInside,
          Brightness.dark,
          2.3,
        );
        final bank = PulseOscillatorBank(p);
        for (var t = 0.0; t < 20; t += 0.37) {
          final s = bank.sample(t);
          expect(s.bopTl, inInclusiveRange(1 - p.op - 1e-9, 1 + 1e-9));
          // bw1 oscillates between 1-sp and 1+sp*1.1.
          expect(
            s.bw[0],
            inInclusiveRange(1 - p.sp - 1e-9, 1 + p.sp * 1.1 + 1e-9),
          );
          expect(s.bx[0], inInclusiveRange(-p.dr - 1e-9, p.dr * 0.9 + 1e-9));
        }
      },
    );

    test('durScale stretches periods with cycle duration', () {
      final base = PulseParams.resolve(
        BeamVariant.pulseInside,
        Brightness.dark,
        2.3,
      );
      final slow = PulseParams.resolve(
        BeamVariant.pulseInside,
        Brightness.dark,
        4.6,
      );
      expect(slow.bs, closeTo(base.bs * 2, 1e-9));
      expect(slow.ss, closeTo(base.ss * 2, 1e-9));
      // Hue period does NOT scale with duration (fixed 16s/14s).
      expect(slow.huePeriod, base.huePeriod);
    });
  });
}
