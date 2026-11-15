import 'dart:math' as math;
import 'dart:ui';

/// Rotates [color]'s hue by [degrees] with the luminance-preserving matrix of
/// the CSS Filter Effects `hue-rotate()` definition, keeping alpha.
Color hueRotate(Color color, double degrees) {
  if (degrees == 0) return color;
  final rad = degrees * math.pi / 180;
  final c = math.cos(rad);
  final s = math.sin(rad);
  final r = color.r;
  final g = color.g;
  final b = color.b;
  final nr =
      r * (0.213 + c * 0.787 - s * 0.213) +
      g * (0.715 - c * 0.715 - s * 0.715) +
      b * (0.072 - c * 0.072 + s * 0.928);
  final ng =
      r * (0.213 - c * 0.213 + s * 0.143) +
      g * (0.715 + c * 0.285 + s * 0.140) +
      b * (0.072 - c * 0.072 - s * 0.283);
  final nb =
      r * (0.213 - c * 0.213 - s * 0.787) +
      g * (0.715 - c * 0.715 + s * 0.715) +
      b * (0.072 + c * 0.928 + s * 0.072);
  return Color.from(
    alpha: color.a,
    red: nr.clamp(0.0, 1.0),
    green: ng.clamp(0.0, 1.0),
    blue: nb.clamp(0.0, 1.0),
  );
}

/// Gamma-aware mix of two colours: squared channels (≈ linear light) are
/// interpolated, so the midpoint of two saturated colours stays bright.
///
/// The shader's `mixColor` does the same.
Color mixColor(Color a, Color b, double t) {
  double ch(double x, double y) =>
      math.sqrt(math.max(0, x * x + (y * y - x * x) * t));
  return Color.from(
    alpha: a.a + (b.a - a.a) * t,
    red: ch(a.r, b.r),
    green: ch(a.g, b.g),
    blue: ch(a.b, b.b),
  );
}

/// Samples a cyclic (or clamped) list of colour stops exactly the way the
/// shader's `paletteAt` does.
Color samplePalette(
  List<Color> colors,
  List<double> stops,
  double cu, {
  required bool wrap,
}) {
  final n = colors.length;
  if (n == 1) return colors.first;
  var prevC = wrap ? colors[n - 1] : colors[0];
  var prevS = wrap ? stops[n - 1] - 1 : stops[0] - 1;
  for (var i = 0; i < n; i++) {
    final s = stops[i];
    if (cu < s) {
      final span = math.max(s - prevS, 1e-5);
      return mixColor(prevC, colors[i], ((cu - prevS) / span).clamp(0.0, 1.0));
    }
    prevC = colors[i];
    prevS = s;
  }
  final nextC = wrap ? colors[0] : prevC;
  final nextS = wrap ? stops[0] + 1 : prevS + 1;
  final span = math.max(nextS - prevS, 1e-5);
  return mixColor(prevC, nextC, ((cu - prevS) / span).clamp(0.0, 1.0));
}
