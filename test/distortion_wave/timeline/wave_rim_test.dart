import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_rim.dart';

/// `WaveRim`: the drifting lumps that make the colour on the view's edges
/// uneven. Ported from DistortionWavesKit's `testRimLumpsAverageOut`, plus
/// determinism and the mirror of the shader's `rimThickness`.
void main() {
  // The reference's screen: 402 × 874 with a 62pt corner.
  const r = 62.0;
  const ex = 201 - r;
  const ey = 437 - r;
  const perimeter = 4 * (ex + ey + 0.5 * math.pi * r);

  Float32List lumpsAt(double time, {double pulse = 0}) {
    final out = Float32List(WaveRim.count * 3);
    WaveRim.lumps(out, time: time, perimeter: perimeter, pulse: pulse);
    return out;
  }

  /// The reference's thickness, written out as its test does.
  double referenceThickness(Float32List lumps, double s) {
    var thickness = 0.08;
    for (var i = 0; i < lumps.length; i += 3) {
      var ds = s - lumps[i];
      ds -= perimeter * (ds / perimeter).roundToDouble();
      thickness += lumps[i + 2] * math.exp(-math.pow(ds / lumps[i + 1], 2));
    }
    return thickness / 1.0498;
  }

  test('rim lumps average out', () {
    // The edge colour's thickness averages the rim's width, as if it were
    // even, and is strongly uneven: about a tenth as thick at its thinnest
    // and almost three times as thick at its thickest.
    final all = <double>[];
    for (var step = 0; step <= 8; step++) {
      final lumps = lumpsAt(step * 0.25);
      for (var k = 0; k < 500; k++) {
        all.add(WaveRim.thickness(lumps, perimeter * k / 500, perimeter));
      }
    }
    final mean = all.reduce((a, b) => a + b) / all.length;
    expect(mean, closeTo(1, 0.03));
    expect(all.reduce(math.min), lessThan(0.2));
    expect(all.reduce(math.max), greaterThan(2.5));
  });

  test('thickness mirrors the reference formula', () {
    for (final pulse in const [0.0, 0.6, 1.0]) {
      for (var step = 0; step <= 8; step++) {
        final lumps = lumpsAt(step * 0.25, pulse: pulse);
        for (var k = 0; k < 100; k++) {
          final s = perimeter * k / 100;
          expect(
            WaveRim.thickness(lumps, s, perimeter),
            closeTo(referenceThickness(lumps, s), 1e-9),
            reason: 'pulse $pulse step $step k $k',
          );
        }
      }
    }
  });

  test('the same time gives the same lumps', () {
    for (final time in const [0.0, 0.37, 1.5, 12.25]) {
      for (final pulse in const [0.0, 0.6]) {
        expect(
          lumpsAt(time, pulse: pulse),
          lumpsAt(time, pulse: pulse),
          reason: 't=$time pulse=$pulse',
        );
      }
    }
  });

  test('lumps drift and breathe over time; their lengths stay put', () {
    final early = lumpsAt(0);
    final later = lumpsAt(1);
    for (var i = 0; i < WaveRim.count; i++) {
      expect(later[i * 3], isNot(early[i * 3]), reason: 'lump $i drifts');
      expect(later[i * 3 + 1], early[i * 3 + 1], reason: 'lump $i length');
      expect(
        later[i * 3 + 2],
        isNot(early[i * 3 + 2]),
        reason: 'lump $i depth',
      );
      expect(early[i * 3 + 1], greaterThan(0), reason: 'lump $i length');
      expect(early[i * 3 + 2], greaterThan(0), reason: 'lump $i depth');
    }
  });

  test('pulse makes them drift faster', () {
    // At time 0 the pulse leaves the lumps as they are: each has the same
    // centre and length with or without it. A second on, the pulsed lumps
    // have drifted further from where they started.
    final start = lumpsAt(0);
    final pulsedStart = lumpsAt(0, pulse: 1);
    for (var i = 0; i < WaveRim.count; i++) {
      expect(pulsedStart[i * 3], start[i * 3], reason: 'lump $i centre');
      expect(pulsedStart[i * 3 + 1], start[i * 3 + 1], reason: 'lump $i');
    }
    final calm = lumpsAt(1);
    final lively = lumpsAt(1, pulse: 1);
    for (var i = 0; i < WaveRim.count; i++) {
      expect(
        (lively[i * 3] - start[i * 3]).abs(),
        greaterThan((calm[i * 3] - start[i * 3]).abs()),
        reason: 'lump $i',
      );
    }
  });

  test('writes nothing past its lumps', () {
    const room = WaveRim.count * 3 + 2;
    final out = Float32List(room)..fillRange(0, room, -1);
    WaveRim.lumps(out, time: 0.5, perimeter: perimeter);
    expect(out[WaveRim.count * 3], -1);
    expect(out[WaveRim.count * 3 + 1], -1);
  });

  test('asserts room for every lump', () {
    expect(
      () => WaveRim.lumps(
        Float32List(WaveRim.count * 3 - 1),
        time: 0,
        perimeter: perimeter,
      ),
      throwsAssertionError,
    );
  });
}
