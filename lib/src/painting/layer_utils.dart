import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../models/beam_config.dart';
import 'gradient_builders.dart';
import 'ring_geometry.dart';

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
    double rotation = 0,
  }) {
    final rx = math.max(radiusX, 0.01);
    final ry = math.max(radiusY, 0.01);
    final matrix = BeamGradients.ellipseTransform(center, ry / rx, rotation);
    final shader = ui.Gradient.radial(
      center,
      rx,
      colors,
      stops,
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

  /// Clips an existing layer scope to the configured perimeter segment.
  ///
  /// Call this after `canvas.save()` and before `saveLayer`. A null segment
  /// deliberately performs no canvas operation, preserving the legacy paint
  /// path exactly.
  static void clipSegment(
    Canvas canvas,
    BeamRingGeometry geometry, {
    required double inward,
    required double outward,
  }) {
    if (geometry.segment == null) return;
    canvas.clipPath(
      segmentBandPath(geometry, inward: inward, outward: outward),
    );
  }

  /// The band covering [geometry]'s segment, reaching [inward] px toward the
  /// interior and [outward] px away from it.
  ///
  /// A contour offset inward by more than its local radius of curvature folds
  /// back through the centre of that curvature: at a rounded corner the
  /// offset arc reverses, sweeps across the far side of the segment, and — as
  /// one polygon under the non-zero fill rule — both loses the interior it
  /// was meant to cover and punches a spurious wedge where the two reversed
  /// arcs cross. Each sample's inward depth is therefore capped at that
  /// radius, which collapses a corner's inner boundary onto its own centre
  /// instead of past it, leaving a simple polygon.
  ///
  /// Only the inward direction can fold — growing a convex contour outward
  /// never does — so an [inward] of zero or less takes the perimeter's own
  /// sampler unchanged.
  static Path segmentBandPath(
    BeamRingGeometry geometry, {
    required double inward,
    required double outward,
  }) {
    final range = geometry.segmentRange;
    if (range == null || inward <= 0) {
      return geometry.segmentBand(inward: inward, outward: outward);
    }
    final perimeter = geometry.perimeter;
    final length = perimeter.length;
    if (length <= 0) return Path();

    final start = _fraction(range.from);
    var span = _fraction(range.to - start);
    if (span == 0) span = 1;
    // Matches BeamPerimeter.band's sampling: ~2 logical px between samples.
    final steps = math.max(8, (span * length / 2).ceil());
    final step = span * length / steps;

    final points = <Offset>[];
    final normals = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final fraction = start + span * i / steps;
      points.add(perimeter.pointAt(fraction));
      normals.add(perimeter.normalAt(fraction));
    }

    final result = Path()
      ..moveTo(
        points.first.dx + normals.first.dx * outward,
        points.first.dy + normals.first.dy * outward,
      );
    for (var i = 1; i < points.length; i++) {
      result.lineTo(
        points[i].dx + normals[i].dx * outward,
        points[i].dy + normals[i].dy * outward,
      );
    }
    for (var i = points.length - 1; i >= 0; i--) {
      final depth = math.min(inward, _curvatureRadius(normals, step, i));
      result.lineTo(
        points[i].dx - normals[i].dx * depth,
        points[i].dy - normals[i].dy * depth,
      );
    }
    return result..close();
  }

  // How far sample [i] may be offset inward before the offset curve reverses:
  // an outward normal turning by phi over an arc length [step] puts the centre
  // of curvature step/phi inward. A normal that turns the other way (a concave
  // stretch) curves away from the interior and never folds, so it is
  // unbounded.
  static double _curvatureRadius(List<Offset> normals, double step, int i) {
    var radius = double.infinity;
    for (final j in [i - 1, i + 1]) {
      if (j < 0 || j >= normals.length) continue;
      final (a, b) = i < j
          ? (normals[i], normals[j])
          : (normals[j], normals[i]);
      final turn = math.atan2(
        a.dx * b.dy - a.dy * b.dx,
        a.dx * b.dx + a.dy * b.dy,
      );
      if (turn > 1e-9) radius = math.min(radius, step / turn);
    }
    return radius;
  }

  static double _fraction(double value) {
    final result = value % 1;
    return result < 0 ? result + 1 : result;
  }

  /// Multiplies the current layer by the two configured endpoint feathers.
  ///
  /// Both masks are radial gradients from transparent at the endpoint to
  /// opaque at [BeamSegment.feather]. They are drawn into the layer that
  /// already composites the variant, so segment painting adds no layer.
  static void applySegmentFeather(
    Canvas canvas,
    Rect bounds,
    BeamRingGeometry geometry,
  ) {
    final segment = geometry.segment;
    final range = geometry.segmentRange;
    if (segment == null || range == null || segment.feather <= 0) return;
    final radius = math.max(segment.feather, 0.01);
    for (final fraction in [range.from, range.to]) {
      final center = geometry.perimeter.pointAt(fraction);
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.radial(
            center,
            radius,
            const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
            const [0, 1],
            TileMode.clamp,
          ),
      );
    }
  }

  /// The point where a ray leaving the centre of [rect] at [angle] crosses
  /// the rect's edge, in the CSS conic convention the beam angle uses: 0 is
  /// 12 o'clock and the angle grows clockwise.
  ///
  /// An approximation of the rounded contour — a corner radius pulls the true
  /// border in by a few px — which is all the sparkle scatter needs.
  static Offset edgePointAt(Rect rect, double angle) {
    if (rect.isEmpty) return rect.center;
    final dx = math.sin(angle);
    final dy = -math.cos(angle);
    final tx = dx.abs() < 1e-6 ? double.infinity : (rect.width / 2) / dx.abs();
    final ty = dy.abs() < 1e-6 ? double.infinity : (rect.height / 2) / dy.abs();
    final t = math.min(tx, ty);
    if (!t.isFinite) return rect.center;
    return rect.center + Offset(dx * t, dy * t);
  }

  /// Paints the twinkles of `BeamStyle.sparkle`: tiny radial blobs scattered
  /// in a disc of radius [spread] around [center], the beam's head.
  ///
  /// Every position, size, and brightness comes from a hash of the sparkle's
  /// index and [seed], so a frame is reproducible from its phases alone —
  /// there is no particle state to carry between frames. [seed] is quantised
  /// travel progress: it holds a scatter still for a fraction of a cycle and
  /// then re-rolls it, which is what makes the field twinkle instead of
  /// crawling along with the beam.
  ///
  /// The blobs are drawn straight onto the canvas with their opacity baked
  /// into each colour rather than into a group layer — they need no group
  /// mask, and the stroke layer they belong to is clipped to the ring, which
  /// would flatten them to hairlines. Either way they cost no `saveLayer`.
  static void paintSparkles(
    Canvas canvas, {
    required Offset center,
    required double density,
    required Color color,
    required double opacity,
    required double spread,
    required int seed,
  }) {
    if (density <= 0 || opacity <= 0 || spread <= 0) return;
    final count = (2 + 10 * density).round();
    for (var i = 0; i < count; i++) {
      final angle = _hash(i, seed) * 2 * math.pi;
      final distance = spread * math.sqrt(_hash(i + 91, seed));
      final radius = 0.8 + 2.4 * _hash(i + 173, seed) * (0.5 + density / 2);
      final twinkle = _hash(i + 379, seed * 31 + 7);
      final alpha = (opacity * density * (0.25 + 0.75 * twinkle)).clamp(
        0.0,
        1.0,
      );
      if (alpha <= 0) continue;
      BeamGradients.paintBlob(
        canvas,
        center: center + Offset(math.cos(angle), math.sin(angle)) * distance,
        radiusX: radius,
        radiusY: radius,
        color: color.withValues(alpha: alpha),
      );
    }
  }

  // A cheap integer hash in 0–1: deterministic across runs and platforms,
  // unlike Random(), whose stream the golden tests could not pin.
  static double _hash(int a, int b) {
    var h = a * 374761393 + b * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) & 0xFFFFFF) / 0xFFFFFF;
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
