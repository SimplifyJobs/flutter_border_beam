import 'dart:math' as math;
import 'dart:ui';

/// Color-matrix math for the CSS `hue-rotate() brightness() saturate()`
/// filter chain.
///
/// Two consumption modes:
/// - [BeamColorMatrix.toColorFilter] for layers that must be filtered after
///   compositing (the blurred blooms), and
/// - [BeamColorMatrix.transform] to fold the filter into gradient colors on
///   the CPU (9–14 colors per layer per frame), which lets the traveling
///   variants skip a per-layer `saveLayer` entirely.
///
/// Matrices are 4×5 row-major lists as accepted by [ColorFilter.matrix]
/// (RGBA in 0–255 space; the offset column is unused here).
class BeamColorMatrix {
  BeamColorMatrix._(this._m);

  /// Identity filter.
  factory BeamColorMatrix.identity() => BeamColorMatrix._(_identity());

  /// The CSS chain `hue-rotate(degrees) brightness(b) saturate(s)`, applied
  /// in that order (matching the source library's filter strings).
  factory BeamColorMatrix.beamFilter({
    required double hueDegrees,
    required double brightness,
    required double saturation,
  }) {
    var m = _hueRotate(hueDegrees);
    if (brightness != 1) m = _multiply(_brightness(brightness), m);
    if (saturation != 1) m = _multiply(_saturate(saturation), m);
    return BeamColorMatrix._(m);
  }

  final List<double> _m;

  /// Whether this matrix is a no-op.
  bool get isIdentity {
    const id = [
      1.0, 0.0, 0.0, 0.0, 0.0, //
      0.0, 1.0, 0.0, 0.0, 0.0, //
      0.0, 0.0, 1.0, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];
    for (var i = 0; i < 20; i++) {
      if ((_m[i] - id[i]).abs() > 1e-9) return false;
    }
    return true;
  }

  /// This matrix as a [ColorFilter].
  ColorFilter toColorFilter() => ColorFilter.matrix(_m);

  /// Applies the matrix to a single color on the CPU. Alpha is preserved
  /// (the matrix has an identity alpha row). Channels are clamped to 0–1,
  /// matching how the GPU filter saturates.
  Color transform(Color c) {
    final r = _m[0] * c.r + _m[1] * c.g + _m[2] * c.b;
    final g = _m[5] * c.r + _m[6] * c.g + _m[7] * c.b;
    final b = _m[10] * c.r + _m[11] * c.g + _m[12] * c.b;
    return Color.from(
      alpha: c.a,
      red: r.clamp(0.0, 1.0),
      green: g.clamp(0.0, 1.0),
      blue: b.clamp(0.0, 1.0),
    );
  }

  static List<double> _identity() => [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  // SVG feColorMatrix hueRotate (the same matrix CSS hue-rotate() is
  // specified against), luminance coefficients 0.213/0.715/0.072.
  static List<double> _hueRotate(double degrees) {
    final rad = degrees * math.pi / 180;
    final c = math.cos(rad);
    final s = math.sin(rad);
    return [
      0.213 + c * 0.787 - s * 0.213,
      0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928,
      0,
      0,
      0.213 - c * 0.213 + s * 0.143,
      0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283,
      0,
      0,
      0.213 - c * 0.213 - s * 0.787,
      0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static List<double> _saturate(double s) => [
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  static List<double> _brightness(double b) => [
    b, 0, 0, 0, 0, //
    0, b, 0, 0, 0, //
    0, 0, b, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  // 4×5 row-major multiply: result = a ∘ b (b applied first).
  static List<double> _multiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var v = 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[row * 5 + k] * b[k * 5 + col];
        }
        if (col == 4) v += a[row * 5 + 4];
        out[row * 5 + col] = v;
      }
    }
    return out;
  }
}
