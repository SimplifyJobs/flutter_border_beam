import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import '../models/beam_config.dart';

/// Shared painting helpers used by every variant strategy.
abstract final class BeamLayerUtils {
  /// The final opacity of one decorative layer: the product of the fade
  /// envelope, the theme preset value, the mono multiplier, the consumer
  /// hook factor, and strength — clamped like CSS clamps effective opacity
  /// (the line/dark preset intentionally exceeds 1).
  static double layerOpacity(
    BeamConfig config, {
    required double fade,
    required double preset,
    required double hookFactor,
    double extra = 1,
  }) {
    final v =
        fade *
        preset *
        config.palette.opacityMultiplier *
        hookFactor *
        config.strength *
        extra;
    return v.clamp(0.0, 1.0);
  }

  /// The source's `attenuateSpike`: multiplies an existing alpha by
  /// [factor], or assigns [factor] as the alpha of an opaque color.
  static Color attenuateSpike(Color c, double factor) =>
      c.a < 1 ? c.withValues(alpha: c.a * factor) : c.withValues(alpha: factor);

  /// Sets [alpha] as the color's alpha (the source's `withAlpha`).
  static Color withAlpha(Color c, double alpha) => c.withValues(alpha: alpha);

  /// Paints a multi-stop radial ellipse (CSS
  /// `radial-gradient(ellipse RXpx RYpx at cx cy, ...stops)`).
  static void paintRadial(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required List<Color> colors,
    required List<double> stops,
  }) {
    final rx = math.max(radiusX, 0.01);
    final ry = math.max(radiusY, 0.01);
    final matrix = Float64List.fromList([
      1, 0, 0, 0, //
      0, ry / rx, 0, 0, //
      0, 0, 1, 0, //
      0, center.dy - center.dy * (ry / rx), 0, 1,
    ]);
    final shader = ui.Gradient.radial(
      center,
      rx,
      colors,
      stops,
      TileMode.clamp,
      matrix,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      Paint()..shader = shader,
    );
  }

  /// Approximates the CSS `box-shadow: inset 0 0 <blur>px 1px <color>` of
  /// the inner glow layers: the shape's contour stroked and blurred, clipped
  /// to the inside.
  static void paintInnerShadow(
    Canvas canvas, {
    required Path contour,
    required Color color,
    required double blur,
  }) {
    if (color.a <= 0) return;
    canvas.save();
    canvas.clipPath(contour);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // Blur + 1px spread: half the stroke falls inside the clip.
      ..strokeWidth = (blur + 1) * 2
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 0.5);
    canvas.drawPath(contour, paint);
    canvas.restore();
  }
}
