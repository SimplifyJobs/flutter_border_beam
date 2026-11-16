import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/look/pulse_look.dart';

/// The pulse's breathing: the per-frame oscillator bank its emitter samples,
/// and the breath its corners swing on — a quicker swell and a slower fade.
///
/// These pin the shape of the motion (where it rests and peaks, which way it
/// moves, how it scales with the cycle), not its tuning, so retuning the look
/// in `lib/src/look/` leaves them standing.
void main() {
  group('breath', () {
    test('rests at the start of each cycle and peaks where the swell ends', () {
      expect(breath(0), 0);
      expect(breath(breathRise), closeTo(1, 1e-12));
      expect(breath(1), closeTo(0, 1e-12));
    });

    test('swells quicker than it fades back', () {
      expect(breathRise, greaterThan(0));
      expect(breathRise, lessThan(0.5));
    });

    test('rises steadily to the peak, then falls steadily back', () {
      const n = 2000;
      var previous = breath(0);
      for (var i = 1; i <= n; i++) {
        final phase = i / n;
        final value = breath(phase);
        expect(value, inInclusiveRange(0.0, 1.0), reason: '$phase');
        if (phase <= breathRise) {
          expect(value, greaterThanOrEqualTo(previous), reason: '$phase');
        } else {
          expect(value, lessThanOrEqualTo(previous), reason: '$phase');
        }
        previous = value;
      }
    });

    test('repeats every cycle, before zero too', () {
      // Shifting by whole cycles moves the phase's last bits, and the eased
      // curve is solved numerically, so equal means equal to well below a
      // visible step rather than bit for bit.
      for (final phase in [0.1, breathRise, 0.55, 0.93]) {
        for (final cycles in [-2, 1, 7]) {
          expect(
            breath(phase + cycles),
            closeTo(breath(phase), 1e-6),
            reason: '$phase + $cycles',
          );
        }
      }
    });

    test('eases into and out of rest and the peak, with no jump', () {
      // An even swing covers h / span of its travel in a step of h; an eased
      // one covers a small fraction of that next to each turning point.
      const h = 1e-3;
      const rise = h / breathRise;
      const fall = h / (1 - breathRise);
      expect(breath(h), lessThan(rise * 0.1), reason: 'leaving rest');
      expect(1 - breath(breathRise - h), lessThan(rise * 0.1), reason: 'peak');
      expect(1 - breath(breathRise + h), lessThan(fall * 0.1), reason: 'peak');
      expect(breath(1 - h), lessThan(fall * 0.1), reason: 'back to rest');
    });
  });

  group('PulseOscillator', () {
    test('an even swing reaches its far end half a period in', () {
      const swing = PulseOscillator(a: 0.25, b: 1, period: 2);
      expect(swing.sample(0), closeTo(0.25, 1e-12));
      expect(swing.sample(1), closeTo(1, 1e-12));
      expect(swing.sample(2), closeTo(0.25, 1e-12));
    });

    test('a breathing swing reaches it after the swell instead', () {
      const swing = PulseOscillator(a: 0.25, b: 1, period: 2, breathes: true);
      expect(swing.sample(0), closeTo(0.25, 1e-12));
      expect(swing.sample(2 * breathRise), closeTo(1, 1e-12));
      expect(swing.sample(2), closeTo(0.25, 1e-12));
      // Half a period in, the even swing is at its far end; the breath is
      // already on its way back.
      expect(swing.sample(1), lessThan(1));
      expect(swing.sample(1), greaterThan(0.25));
    });

    test('a delay plays the same swing later', () {
      const onTime = PulseOscillator(a: 0, b: 1, period: 3, breathes: true);
      const late = PulseOscillator(
        a: 0,
        b: 1,
        period: 3,
        delay: 0.5,
        breathes: true,
      );
      for (final t in [0.0, 0.7, 1.9, 4.2]) {
        expect(late.sample(t + 0.5), closeTo(onTime.sample(t), 1e-6));
      }
    });

    test('never leaves the span between its two ends', () {
      for (final breathes in [false, true]) {
        // b below a: the swing runs downward.
        final swing = PulseOscillator(
          a: 1,
          b: 0.4,
          period: 1.7,
          delay: 0.3,
          breathes: breathes,
        );
        for (var i = 0; i <= 1000; i++) {
          expect(
            swing.sample(i * 0.0137),
            inInclusiveRange(0.4 - 1e-12, 1 + 1e-12),
            reason: 'breathes: $breathes at ${i * 0.0137}',
          );
        }
      }
    });
  });

  group('PulseOscillatorBank', () {
    const cycle = 2.3;

    PulseFrame sampleAt(PulseOscillatorBank bank, double t) {
      final frame = PulseFrame();
      bank.sample(t, frame);
      return frame;
    }

    List<double> flatten(PulseFrame f) => [
      ...f.bw,
      ...f.bh,
      ...f.bx,
      ...f.by,
      f.bgh,
      ...f.bop,
    ];

    for (final dark in [true, false]) {
      final surface = dark ? 'dark' : 'light';
      final params = PulseParams.pulse(dark: dark, cycleSeconds: cycle);
      final bank = PulseOscillatorBank(params);

      test('$surface: every corner breathes between 1 − depth and full', () {
        final low = List<double>.filled(4, double.infinity);
        final high = List<double>.filled(4, double.negativeInfinity);
        for (var i = 0; i <= 20000; i++) {
          final frame = sampleAt(bank, i * 0.005);
          for (var c = 0; c < 4; c++) {
            final o = frame.bop[c];
            expect(o, inInclusiveRange(1 - params.op - 1e-9, 1 + 1e-9));
            if (o < low[c]) low[c] = o;
            if (o > high[c]) high[c] = o;
          }
        }
        for (var c = 0; c < 4; c++) {
          expect(low[c], closeTo(1 - params.op, 0.01), reason: 'corner $c');
          expect(high[c], closeTo(1, 0.01), reason: 'corner $c');
        }
      });

      test('$surface: the corners breathe out of step', () {
        var widest = 0.0;
        for (var i = 0; i <= 2000; i++) {
          final bop = sampleAt(bank, i * 0.01).bop;
          final spread =
              bop.reduce((a, b) => a > b ? a : b) -
              bop.reduce((a, b) => a < b ? a : b);
          if (spread > widest) widest = spread;
        }
        expect(widest, greaterThan(params.op / 2));
      });

      test('$surface: the frozen bloom holds the corners\' average', () {
        // The static bloom stands in for the breathing corners when the beam
        // cannot move; it must sit at their time average, so a frozen frame
        // is neither brighter nor dimmer than a moving one on the whole.
        const window = 1000.0;
        const step = 0.005;
        final sums = List<double>.filled(4, 0);
        var n = 0;
        for (var t = 0.0; t < window; t += step) {
          final bop = sampleAt(bank, t).bop;
          for (var c = 0; c < 4; c++) {
            sums[c] += bop[c];
          }
          n++;
        }
        for (var c = 0; c < 4; c++) {
          expect(
            sums[c] / n,
            closeTo(params.frozenBloomAlpha, 0.005),
            reason: 'corner $c',
          );
        }
      });

      test('$surface: a longer cycle plays the same breathing slower', () {
        final slow = PulseOscillatorBank(
          PulseParams.pulse(dark: dark, cycleSeconds: cycle * 2),
        );
        for (final t in [0.0, 0.37, 1.2, 3.9, 11.5]) {
          final fast = flatten(sampleAt(bank, t));
          final slowed = flatten(sampleAt(slow, t * 2));
          for (var i = 0; i < fast.length; i++) {
            expect(slowed[i], closeTo(fast[i], 1e-6), reason: 't=$t [$i]');
          }
        }
      });
    }

    test('sampling is pure: a time always gives the same frame', () {
      final bank = PulseOscillatorBank(
        PulseParams.pulse(dark: true, cycleSeconds: cycle),
      );
      final reused = PulseFrame();
      bank.sample(5.25, reused);
      final first = flatten(reused);
      bank
        ..sample(1, reused)
        ..sample(0, reused)
        ..sample(5.25, reused);
      expect(flatten(reused), first);
      expect(flatten(sampleAt(bank, 5.25)), first);
    });
  });
}
