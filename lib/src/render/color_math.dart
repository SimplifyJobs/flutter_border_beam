import 'dart:math' as math;
import 'dart:ui';

/// Gamma-aware mix of two colours: squared channels (≈ linear light) are
/// interpolated, so the midpoint of two saturated colours stays bright.
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

/// Samples a cyclic (or clamped) list of colour [stops] at [cu], blending
/// the two stops either side of it with [mixColor].
///
/// With [wrap] the ring is seamless: past the last stop the colour blends
/// back into the first. Palettes are blended here, on the CPU, when they are
/// sampled into blob tables — palette stops never reach the shader.
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
