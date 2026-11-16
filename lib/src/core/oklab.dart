import 'dart:math' as math;
import 'dart:ui';

/// A colour in OKLab: perceptual lightness [l] (0–1) and two opponent axes,
/// [a] (green → red) and [b] (blue → yellow).
///
/// Mixing in OKLab keeps neighbouring hues from passing through grey, which
/// is why the shaders that blend palette colours per pixel receive them in
/// this space.
final class Oklab {
  /// A colour with these coordinates.
  const Oklab(this.l, this.a, this.b);

  /// The OKLab coordinates of an sRGB [color]. Alpha is ignored.
  factory Oklab.fromColor(Color color) {
    final lr = _linear(color.r);
    final lg = _linear(color.g);
    final lb = _linear(color.b);
    final l = _cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
    final m = _cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
    final s = _cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
    return Oklab(
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    );
  }

  /// Lightness, 0 (black) to 1 (white).
  final double l;

  /// Green (negative) to red (positive).
  final double a;

  /// Blue (negative) to yellow (positive).
  final double b;

  /// The opaque sRGB colour nearest this one, clipped to the gamut.
  Color toColor() {
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    final l3 = l_ * l_ * l_;
    final m3 = m_ * m_ * m_;
    final s3 = s_ * s_ * s_;
    return Color.from(
      alpha: 1,
      red: _encode(4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3),
      green: _encode(
        -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
      ),
      blue: _encode(-0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3),
    );
  }

  /// The colour [t] of the way from this one to [other], mixed in OKLab.
  Oklab mix(Oklab other, double t) => Oklab(
    l + (other.l - l) * t,
    a + (other.a - a) * t,
    b + (other.b - b) * t,
  );

  @override
  bool operator ==(Object other) =>
      other is Oklab && other.l == l && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(l, a, b);

  @override
  String toString() =>
      'Oklab(${l.toStringAsFixed(4)}, ${a.toStringAsFixed(4)}, '
      '${b.toStringAsFixed(4)})';

  static double _linear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _encode(double linear) {
    final c = linear.clamp(0.0, 1.0);
    return c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  }

  static double _cbrt(double x) =>
      x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
}
