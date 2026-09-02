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
    double rotation = 0,
  }) {
    final rx = math.max(radiusX, 0.01);
    final ry = math.max(radiusY, 0.01);
    final c = alpha >= 1 ? color : color.withValues(alpha: color.a * alpha);
    if (c.a <= 0) return;
    // Circular gradient of radius rx, scaled vertically to ry about center.
    final matrix = ellipseTransform(center, ry / rx, rotation);
    final shader = ui.Gradient.radial(
      center,
      rx,
      [c, c.withValues(alpha: 0)],
      const [0, 1],
      TileMode.clamp,
      matrix,
    );
    final extent = rotation == 0 ? null : math.max(rx, ry);
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: (extent ?? rx) * 2,
        height: (extent ?? ry) * 2,
      ),
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
    double rotation = 0,
  }) {
    final rx = math.max(radiusX, 0.01);
    final ry = math.max(radiusY, 0.01);
    final matrix = ellipseTransform(center, ry / rx, rotation);
    return ui.Gradient.radial(
      center,
      rx,
      [_white, _white.withValues(alpha: midAlpha), _white.withValues(alpha: 0)],
      [0, midStop, 1],
      TileMode.clamp,
      matrix,
    );
  }

  /// A conic dash mask: [segments] evenly spaced dashes around the ring,
  /// drawn with [BlendMode.dstIn] to cut the gaps out of a layer.
  ///
  /// [duty] is the fraction of each dash period the dash occupies and
  /// [feather] the fraction faded at each of its two edges, so the dashes end
  /// in a soft taper rather than a hard chop. The mask is anchored at 12
  /// o'clock rather than at the beam angle: the dashes are a property of the
  /// ring, and the beam travels over them.
  static Shader segmentMask(
    Rect rect,
    int segments, {
    double duty = 0.6,
    double feather = 0.05,
  }) {
    final n = math.max(1, segments);
    final p = 1 / n;
    final stops = <double>[];
    final colors = <Color>[];
    void stop(double s, double alpha) {
      stops.add(s.clamp(0.0, 1.0));
      colors.add(_white.withValues(alpha: alpha));
    }

    for (var k = 0; k < n; k++) {
      final base = k * p;
      stop(base, 1);
      stop(base + (duty - feather) * p, 1);
      stop(base + (duty + feather) * p, 0);
      stop(base + (1 - feather) * p, 0);
    }
    stop(1, 1);
    return conic(rect: rect, cssFromRadians: 0, colors: colors, stops: stops);
  }

  static const Color _white = Color(0xFFFFFFFF);

  /// Scales a circular radial shader into an ellipse and rotates its width
  /// axis by [rotation] around [center].
  ///
  /// The zero-rotation matrix is intentionally the historical matrix byte
  /// for byte, so callers that do not opt into path-space painting retain
  /// their existing raster output.
  static Float64List ellipseTransform(
    Offset center,
    double yScale,
    double rotation,
  ) {
    if (rotation == 0) {
      return Float64List.fromList([
        1, 0, 0, 0, //
        0, yScale, 0, 0, //
        0, 0, 1, 0, //
        0, center.dy - center.dy * yScale, 0, 1,
      ]);
    }
    final c = math.cos(rotation);
    final s = math.sin(rotation);
    final m0 = c;
    final m1 = s;
    final m4 = -s * yScale;
    final m5 = c * yScale;
    return Float64List.fromList([
      m0, m1, 0, 0, //
      m4, m5, 0, 0, //
      0, 0, 1, 0, //
      center.dx - m0 * center.dx - m4 * center.dy,
      center.dy - m1 * center.dx - m5 * center.dy,
      0,
      1,
    ]);
  }
}

/// A conic gradient's stop table: parallel stop and alpha lists, as the
/// rotate/small variants transcribe them from the source's CSS.
typedef BeamConicTable = ({List<double> stops, List<double> alphas});

/// Runtime transforms of the transcribed conic window tables.
///
/// The tables themselves are constants and never change; travel direction,
/// tail length, and beam count reshape them per frame instead.
abstract final class BeamConicWindow {
  /// Applies [tailLength], [reversed], and [beamCount] to a base table, in
  /// that order.
  ///
  /// Returns the base lists untouched at the defaults (tail 1, forward, one
  /// beam), so the common path allocates nothing.
  static BeamConicTable resolve(
    List<double> stops,
    List<double> alphas, {
    required bool reversed,
    required double tailLength,
    required int beamCount,
  }) {
    var table = scaleTail((stops: stops, alphas: alphas), tailLength);
    if (reversed) table = mirror(table);
    return repeat(table, beamCount);
  }

  /// Mirrors a table for a beam traveling the other way: every stop becomes
  /// `1 − stop` (which reverses their order, so the list is reversed to stay
  /// ascending) and the alphas reverse with them.
  ///
  /// The transcribed tables are asymmetric — a short falloff on the leading
  /// side, a long soft foot trailing — so a reversed beam that reused them
  /// verbatim would drag its tail in front of its head.
  static BeamConicTable mirror(BeamConicTable table) => (
    stops: [for (final s in table.stops.reversed) 1 - s],
    alphas: table.alphas.reversed.toList(growable: false),
  );

  /// Scales the angular width of the window about its head by [factor].
  ///
  /// The head is the leading edge of the bright core — the last stop holding
  /// the table's maximum alpha — so scaling about it stretches the trailing
  /// tail and the short leading falloff together while the beam's position
  /// stays put.
  ///
  /// [factor] is clamped to what the table can hold: a window may not grow
  /// past the full turn, or its two ends would collide at the seam and cut
  /// the beam in half. The rotate window saturates at ≈1.33×, its highlight
  /// and bloom bands (which start narrower) well past 2×.
  static BeamConicTable scaleTail(BeamConicTable table, double factor) {
    if (factor == 1 || table.stops.length < 3) return table;
    final head = _head(table);
    final (lo, hi) = _support(table);
    final backSpan = head - lo;
    final frontSpan = hi - head;
    var maxFactor = double.infinity;
    if (backSpan > 0) maxFactor = math.min(maxFactor, head / backSpan);
    if (frontSpan > 0) maxFactor = math.min(maxFactor, (1 - head) / frontSpan);
    final f = factor.clamp(0.05, math.max(0.05, maxFactor));
    return (
      stops: [
        for (final s in table.stops)
          (head + (s - head) * f).clamp(0.0, 1.0).toDouble(),
      ],
      alphas: table.alphas,
    );
  }

  /// Tiles a table [count] times around the circle, so one sweep shader
  /// carries every beam: each copy's stops are scaled by `1 / count` and
  /// offset into its own slot.
  static BeamConicTable repeat(BeamConicTable table, int count) {
    if (count <= 1) return table;
    final stops = <double>[];
    final alphas = <double>[];
    for (var k = 0; k < count; k++) {
      for (var i = 0; i < table.stops.length; i++) {
        stops.add((table.stops[i] + k) / count);
        alphas.add(table.alphas[i]);
      }
    }
    return (stops: stops, alphas: alphas);
  }

  // The last stop carrying the table's peak alpha: the leading edge of the
  // bright core.
  static double _head(BeamConicTable table) {
    var peak = table.alphas.first;
    for (final a in table.alphas) {
      if (a > peak) peak = a;
    }
    var head = table.stops.first;
    for (var i = 0; i < table.alphas.length; i++) {
      if (table.alphas[i] >= peak) head = table.stops[i];
    }
    return head;
  }

  // The zero-alpha stops flanking the lit band — the width the window
  // actually occupies, ignoring the table's 0 and 1 anchors.
  static (double lo, double hi) _support(BeamConicTable table) {
    var first = 0;
    while (first < table.alphas.length - 1 && table.alphas[first + 1] <= 0) {
      first++;
    }
    var last = table.alphas.length - 1;
    while (last > 0 && table.alphas[last - 1] <= 0) {
      last--;
    }
    return (table.stops[first], table.stops[last]);
  }
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
