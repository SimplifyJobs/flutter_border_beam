import 'package:flutter_border_beam/src/animation/spring_curve.dart';
import 'package:flutter_test/flutter_test.dart';

/// `FadeSpringCurve.transform(i * 0.05)` for i = 0..20, at full double
/// precision. The fade envelope's shape is visual API — goldens and the
/// documented ~3% overshoot both depend on these exact values.
const List<double> _oracle = <double>[
  0.0,
  0.15986030326692727,
  0.44896452311296503,
  0.7063666247249973,
  0.8815479259123428,
  0.9784616720631045,
  1.020016563364826,
  1.029814982804687,
  1.0252447161959004,
  1.016641057993826,
  1.0089117673752073,
  1.003622629972982,
  1.0006807812985246,
  0.999408629217683,
  0.9990992111048517,
  0.9992285492416089,
  0.9994836129267871,
  0.9997147812271953,
  0.9998735617828104,
  0.9999619578842425,
  1.0,
];

void main() {
  const curve = FadeSpringCurve.instance;

  test('matches the reference samples at 0.05 increments', () {
    for (var i = 0; i < _oracle.length; i++) {
      final t = i * 0.05;
      expect(
        curve.transform(t),
        closeTo(_oracle[i], 1e-9),
        reason: 'sample $i (t = $t)',
      );
    }
  });

  test('pins both endpoints exactly', () {
    expect(curve.transform(0), 0.0);
    expect(curve.transform(1), 1.0);
  });

  test('rises monotonically to its peak, then settles', () {
    const samples = 1000;
    var peakIndex = 0;
    var peak = 0.0;
    final values = List<double>.generate(
      samples + 1,
      (i) => curve.transform(i / samples),
    );
    for (var i = 0; i <= samples; i++) {
      if (values[i] > peak) {
        peak = values[i];
        peakIndex = i;
      }
    }

    // Under-damped: it overshoots once, near t = 0.35, by ~3%.
    expect(peak, closeTo(1.0298, 1e-3));
    expect(peakIndex / samples, closeTo(0.35, 0.02));

    for (var i = 1; i <= peakIndex; i++) {
      expect(
        values[i],
        greaterThanOrEqualTo(values[i - 1]),
        reason: 'dip before the peak at sample $i',
      );
    }
    // Past the peak the spring rings down and never climbs back to it.
    for (var i = peakIndex + 1; i <= samples; i++) {
      expect(values[i], lessThan(peak), reason: 'second peak at sample $i');
    }
  });

  test('overshoot stays within the documented bound', () {
    const samples = 100000;
    var max = 0.0;
    var min = 0.0;
    for (var i = 0; i <= samples; i++) {
      final v = curve.transform(i / samples);
      if (v > max) max = v;
      if (v < min) min = v;
    }
    expect(max, lessThan(1.03));
    expect(min, greaterThanOrEqualTo(0.0));
  });
}
