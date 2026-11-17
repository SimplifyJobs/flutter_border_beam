import 'dart:math' as math;
import 'dart:typed_data';

/// The lumps that make the colour on the view's edges uneven, as a border
/// beam's glow is: [count] of them round the perimeter, each with its own
/// length and depth, drifting along the edge and breathing. Worked out once a
/// frame here rather than for every pixel in the shader.
abstract final class WaveRim {
  /// How many lumps there are.
  static const int count = 7;

  /// Writes the lumps at [time] into [out], three floats each: centre along
  /// the perimeter (pt, clockwise from the top centre), length (pt) and depth
  /// (a share of the rim's width). [perimeter] is the view outline's length;
  /// [pulse], 0–1, makes them drift faster and breathe deeper.
  static void lumps(
    Float32List out, {
    required double time,
    required double perimeter,
    double pulse = 0,
  }) {
    assert(out.length >= count * 3, 'room for $count lumps');
    const n = count;
    for (var i = 0; i < count; i++) {
      final fi = i.toDouble();
      // Fixed per lump, so the pattern is the same on every run.
      final a = _hash(fi, 12.9898, 1.3);
      final b = _hash(fi, 78.233, 4.1);
      final c = _hash(fi, 39.425, 2.7);
      final centre =
          perimeter * (fi + 0.35 * a) / n +
          time * (-22 + 44 * b) * (1 + 2 * pulse);
      final length = perimeter / n * (0.2 + 0.25 * c);
      final breath =
          (0.25 + 0.3 * pulse) *
          math.sin(time * (1.1 + 1.2 * a) * (1 + pulse) + fi * 2.4);
      final depth = (0.2 + 2.6 * b) * (1 + breath);
      out[i * 3] = centre;
      out[i * 3 + 1] = length;
      out[i * 3 + 2] = depth;
    }
  }

  /// How thick the colour is at [s] along a perimeter of [perimeter], as a
  /// share of the rim's width, for the lumps in [lumps]. Averages 1; the
  /// thinnest stretch is about a tenth of that, the thickest almost three
  /// times. The Dart mirror of the shader's `waveRimThickness`.
  static double thickness(Float32List lumps, double s, double perimeter) {
    var t = 0.08;
    for (var i = 0; i < count; i++) {
      var ds = s - lumps[i * 3];
      ds -= perimeter * (ds / perimeter).roundToDouble();
      final q = ds / lumps[i * 3 + 1];
      t += lumps[i * 3 + 2] * math.exp(-q * q);
    }
    return t / 1.0498;
  }

  static double _hash(double i, double a, double b) {
    final x = math.sin(i * a + b) * 43758.5453;
    return x - x.floorToDouble();
  }
}
