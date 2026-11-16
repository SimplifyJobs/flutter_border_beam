import 'dart:math' as math;

import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/animation/spring_curve.dart';
import 'package:flutter_test/flutter_test.dart';

/// A critically damped unit spring released from rest, at time [t] seconds
/// for a [response]: `1 − (1 + ω₀t)·e^(−ω₀t)`, ω₀ = 2π / response.
double _critical(double response, double t) {
  final u = 2 * math.pi / response * t;
  return 1 - (1 + u) * math.exp(-u);
}

List<double> _samples(BeamSpringCurve curve, [int n = 1000]) =>
    List<double>.generate(n + 1, (i) => curve.transform(i / n));

void main() {
  for (final (name, curve) in [
    ('fadeIn', BeamSpringCurve.fadeIn),
    ('fadeOut', BeamSpringCurve.fadeOut),
    ('pop', BeamSpringCurve.pop),
  ]) {
    test('$name pins both endpoints exactly', () {
      expect(curve.transform(0), 0.0);
      expect(curve.transform(1), 1.0);
    });

    test('$name starts from rest', () {
      // A spring released from rest eases in quadratically: its first
      // thousandth is a tiny fraction of an even pace's.
      expect(curve.transform(0.001), lessThan(0.001 * 0.1));
    });
  }

  group('the fades', () {
    for (final (name, curve) in [
      ('fadeIn', BeamSpringCurve.fadeIn),
      ('fadeOut', BeamSpringCurve.fadeOut),
    ]) {
      test('$name is critically damped: monotone, never past 1', () {
        final values = _samples(curve, 10000);
        for (var i = 1; i < values.length; i++) {
          expect(values[i], greaterThanOrEqualTo(values[i - 1]), reason: '$i');
          expect(values[i], lessThanOrEqualTo(1.0), reason: '$i');
        }
      });

      test('$name plays the spring in real time over its settling time', () {
        final seconds = curve.settlingSeconds;
        for (final f in [0.1, 0.25, 0.5, 0.75]) {
          final t = seconds * f;
          // Normalised by the 1% left at the settle phase.
          final expected =
              _critical(curve.response, t) / _critical(curve.response, seconds);
          expect(curve.transform(f), closeTo(expected, 1e-9), reason: '$f');
        }
      });
    }

    test('the clock runs each fade over its spring settling time', () {
      expect(
        BeamClock.fadeInSeconds,
        closeTo(BeamSpringCurve.fadeIn.settlingSeconds, 1e-3),
      );
      expect(
        BeamClock.fadeOutSeconds,
        closeTo(BeamSpringCurve.fadeOut.settlingSeconds, 1e-3),
      );
    });

    test('light leaves more gently than it arrives', () {
      expect(
        BeamSpringCurve.fadeOut.response,
        greaterThan(BeamSpringCurve.fadeIn.response),
      );
      expect(BeamClock.fadeOutSeconds, greaterThan(BeamClock.fadeInSeconds));
    });

    test('a fade-out eases away instead of snapping to nothing', () {
      // Opacity at each tenth of the fade-out: falling throughout, a gentle
      // first step, and still above zero until the very end.
      final opacity = [
        for (var i = 0; i <= 10; i++)
          1 - BeamSpringCurve.fadeOut.transform(i / 10),
      ];
      expect(opacity[1], greaterThan(0.75));
      for (var i = 1; i < 10; i++) {
        expect(opacity[i], lessThan(opacity[i - 1]), reason: '$i');
        expect(opacity[i], greaterThan(0), reason: '$i');
      }
      expect(opacity[10], 0);
    });
  });

  test('pop overshoots a little, once, and settles', () {
    final values = _samples(BeamSpringCurve.pop, 10000);
    final peak = values.reduce(math.max);
    final peakIndex = values.indexOf(peak);
    expect(peak, greaterThan(1.01));
    expect(peak, lessThan(1.05));
    expect(peakIndex / 10000, lessThan(0.6));
    // One rise, straight up to the peak.
    for (var i = 1; i <= peakIndex; i++) {
      expect(values[i], greaterThanOrEqualTo(values[i - 1]), reason: '$i');
    }
    // Then back down through 1...
    final back = values.indexWhere((v) => v <= 1, peakIndex);
    expect(back, greaterThan(peakIndex), reason: 'never came back to 1');
    for (var i = peakIndex + 1; i < back; i++) {
      expect(values[i], lessThan(values[i - 1]), reason: '$i');
    }
    // ...and settled: never over 1 again, and any undershoot within the 1%
    // a settled spring leaves.
    for (var i = back; i < values.length; i++) {
      expect(values[i], inInclusiveRange(0.99, 1 + 1e-9), reason: '$i');
    }
    expect(values.last, 1.0);
  });

  test('value-equal and described', () {
    final same = BeamSpringCurve(
      dampingRatio: double.parse('1'),
      response: double.parse('0.45'),
    );
    expect(identical(same, BeamSpringCurve.fadeIn), isFalse);
    expect(same, BeamSpringCurve.fadeIn);
    expect(same.hashCode, BeamSpringCurve.fadeIn.hashCode);
    expect(
      BeamSpringCurve(dampingRatio: double.parse('1'), response: 0.55),
      isNot(BeamSpringCurve.fadeIn),
    );
    expect(
      BeamSpringCurve.fadeIn.toString(),
      'BeamSpringCurve(dampingRatio: 1.0, response: 0.45s)',
    );
  });
}
