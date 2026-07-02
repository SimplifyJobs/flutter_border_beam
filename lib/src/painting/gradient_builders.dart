import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

/// Shader/paint helpers translating the CSS gradient vocabulary of the source
/// library to Flutter canvas primitives.
abstract final class BeamGradients {
  /// A CSS `conic-gradient(from <angle> ...)` equivalent.
  ///
  /// CSS conic gradients start at 12 o'clock and run clockwise;
  /// [ui.Gradient.sweep] starts at 3 o'clock — a constant −90° rotation
  /// aligns them. [cssFromRadians] is the CSS `from` angle (the rotating
  /// beam angle).
  static Shader conic({
    required Rect rect,
    required double cssFromRadians,
    required List<Color> colors,
    required List<double> stops,
  }) {
    final center = rect.center;
    final rotation = cssFromRadians - math.pi / 2;
    final matrix = Matrix4Rotation.aboutPoint(rotation, center);
    return ui.Gradient.sweep(
      center,
      colors,
      stops,
      TileMode.clamp,
      0,
      2 * math.pi,
      matrix,
    );
  }

  /// Paints one radial ellipse blob: fades from [color] at the center to
  /// fully transparent at the ellipse edge (CSS
  /// `radial-gradient(ellipse Wpx Hpx at x y, color, transparent)` — W/H are
  /// the ellipse radii).
  ///
  /// [center] is in canvas coordinates; [radiusX]/[radiusY] in logical px.
  /// [alpha] scales the blob color's opacity (pulse quadrant breathing).
  static void paintBlob(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    double alpha = 1,
  }) {
    final rx = math.max(radiusX, 0.01);
    final ry = math.max(radiusY, 0.01);
    final c = alpha >= 1 ? color : color.withValues(alpha: color.a * alpha);
    if (c.a <= 0) return;
    // Circular gradient of radius rx, scaled vertically to ry about center.
    final matrix = Float64List.fromList([
      1, 0, 0, 0, //
      0, ry / rx, 0, 0, //
      0, 0, 1, 0, //
      0, center.dy - center.dy * (ry / rx), 0, 1,
    ]);
    final shader = ui.Gradient.radial(
      center,
      rx,
      [c, c.withValues(alpha: 0)],
      const [0, 1],
      TileMode.clamp,
      matrix,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      Paint()..shader = shader,
    );
  }

  /// The vertical edge-feather mask of the source's inner glow layers:
  /// opaque at the top/bottom edges, transparent [feather] px inward
  /// (CSS `linear-gradient(white, transparent 28px, transparent
  /// calc(100% - 28px), white)`).
  static Shader verticalEdgeFeather(Rect rect, {double feather = 28}) {
    final f = (feather / rect.height).clamp(0.0, 0.5);
    return ui.Gradient.linear(
      rect.topCenter,
      rect.bottomCenter,
      [
        _white,
        _white.withValues(alpha: 0),
        _white.withValues(alpha: 0),
        _white,
      ],
      [0, f, 1 - f, 1],
    );
  }

  /// The horizontal edge-feather mask (left/right edges).
  static Shader horizontalEdgeFeather(Rect rect, {double feather = 28}) {
    final f = (feather / rect.width).clamp(0.0, 0.5);
    return ui.Gradient.linear(
      rect.centerLeft,
      rect.centerRight,
      [
        _white,
        _white.withValues(alpha: 0),
        _white.withValues(alpha: 0),
        _white,
      ],
      [0, f, 1 - f, 1],
    );
  }

  /// A radial window mask (line variant): white at [center], fading through
  /// [midAlpha] at [midStop] to transparent at the ellipse edge.
  static Shader radialWindow({
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double midStop,
    required double midAlpha,
  }) {
    final rx = math.max(radiusX, 0.01);
    final ry = math.max(radiusY, 0.01);
    final matrix = Float64List.fromList([
      1, 0, 0, 0, //
      0, ry / rx, 0, 0, //
      0, 0, 1, 0, //
      0, center.dy - center.dy * (ry / rx), 0, 1,
    ]);
    return ui.Gradient.radial(
      center,
      rx,
      [_white, _white.withValues(alpha: midAlpha), _white.withValues(alpha: 0)],
      [0, midStop, 1],
      TileMode.clamp,
      matrix,
    );
  }

  static const Color _white = Color(0xFFFFFFFF);
}

/// Small helper building a rotation matrix (as the `Float64List` gradient
/// transform) about an arbitrary point.
abstract final class Matrix4Rotation {
  /// Rotation by [radians] about [point].
  static Float64List aboutPoint(double radians, Offset point) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    final dx = point.dx - point.dx * c + point.dy * s;
    final dy = point.dy - point.dx * s - point.dy * c;
    return Float64List.fromList([
      c, s, 0, 0, //
      -s, c, 0, 0, //
      0, 0, 1, 0, //
      dx, dy, 0, 1,
    ]);
  }
}
