import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/painting.dart';

import '../models/beam_options.dart';
import '../models/beam_segment.dart';

/// Arc-length geometry for a closed beam contour.
///
/// Public fractions increase clockwise from the point nearest [Rect.topCenter]
/// regardless of the source path's winding direction.
class BeamPerimeter {
  /// Measures [outer] and aligns its coordinates to [rect].
  BeamPerimeter(Path outer, this.rect, {this.radii}) {
    final metrics = outer.computeMetrics().toList(growable: false);
    _metric = metrics.isEmpty ? null : metrics.first;
    length = _metric?.length ?? 0;
    if (length <= 0) {
      _s0 = 0;
      _clockwiseSource = true;
      return;
    }

    const samples = 128;
    var best = 0.0;
    var bestDistance = double.infinity;
    for (var i = 0; i < samples; i++) {
      final offset = length * i / samples;
      final distance =
          (_rawTangent(offset)!.position - rect.topCenter).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = offset;
      }
    }
    var low = best - length / samples;
    var high = best + length / samples;
    for (var i = 0; i < 8; i++) {
      final left = (2 * low + high) / 3;
      final right = (low + 2 * high) / 3;
      final leftDistance =
          (_rawTangent(left)!.position - rect.topCenter).distanceSquared;
      final rightDistance =
          (_rawTangent(right)!.position - rect.topCenter).distanceSquared;
      if (leftDistance <= rightDistance) {
        high = right;
      } else {
        low = left;
      }
    }
    _s0 = _wrapOffset((low + high) / 2);
    _clockwiseSource = _rawTangent(_s0)!.vector.dx >= 0;
  }

  /// The bounds used to identify top-center and rectangular edge anchors.
  final Rect rect;

  /// Resolved corner radii, or null for an arbitrary contour.
  final BorderRadius? radii;

  late final PathMetric? _metric;

  /// Total length of the first contour in logical pixels.
  late final double length;

  late final double _s0;
  late final bool _clockwiseSource;

  static double _fraction(double value) {
    final result = value % 1;
    return result < 0 ? result + 1 : result;
  }

  double _wrapOffset(double value) {
    if (length <= 0) return 0;
    final result = value % length;
    return result < 0 ? result + length : result;
  }

  Tangent? _rawTangent(double offset) =>
      _metric?.getTangentForOffset(_wrapOffset(offset));

  Tangent? _tangent(double fraction) {
    if (length <= 0) return null;
    final distance = _fraction(fraction) * length;
    return _rawTangent(_s0 + (_clockwiseSource ? distance : -distance));
  }

  /// The point at clockwise arc-length fraction [f].
  Offset pointAt(double f) => _tangent(f)?.position ?? rect.topCenter;

  /// The clockwise unit tangent at fraction [f].
  Offset tangentAt(double f) {
    final vector = _tangent(f)?.vector ?? Offset.zero;
    return _clockwiseSource ? vector : -vector;
  }

  /// The outward unit normal at fraction [f].
  Offset normalAt(double f) {
    final tangent = tangentAt(f);
    return Offset(tangent.dy, -tangent.dx);
  }

  /// The perimeter point moved [inward] logical pixels toward the interior.
  Offset offsetPointAt(double f, double inward) =>
      pointAt(f) - normalAt(f) * inward;

  /// Finds the clockwise fraction whose perimeter point is nearest [point].
  double nearestFraction(Offset point) {
    if (length <= 0) return 0;
    const samples = 64;
    var best = 0.0;
    var bestDistance = double.infinity;
    for (var i = 0; i < samples; i++) {
      final fraction = i / samples;
      final distance = (pointAt(fraction) - point).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = fraction;
      }
    }
    var low = best - 1 / samples;
    var high = best + 1 / samples;
    for (var i = 0; i < 12; i++) {
      final left = (2 * low + high) / 3;
      final right = (low + 2 * high) / 3;
      if ((pointAt(left) - point).distanceSquared <=
          (pointAt(right) - point).distanceSquared) {
        high = right;
      } else {
        low = left;
      }
    }
    return _fraction((low + high) / 2);
  }

  BorderRadius get _scaledRadii {
    final source = radii;
    if (source == null) return BorderRadius.zero;
    final half = rect.shortestSide / 2;
    Radius normalized(Radius radius) => Radius.elliptical(
      radius.x.isFinite ? math.max(0, radius.x) : half,
      radius.y.isFinite ? math.max(0, radius.y) : half,
    );
    final topLeft = normalized(source.topLeft);
    final topRight = normalized(source.topRight);
    final bottomRight = normalized(source.bottomRight);
    final bottomLeft = normalized(source.bottomLeft);
    var scale = 1.0;
    double limit(double side, double sum) =>
        sum <= 0 ? scale : math.min(scale, side / sum);
    scale = limit(rect.width, topLeft.x + topRight.x);
    scale = limit(rect.height, topRight.y + bottomRight.y);
    scale = limit(rect.width, bottomLeft.x + bottomRight.x);
    scale = limit(rect.height, topLeft.y + bottomLeft.y);
    Radius scaled(Radius radius) => radius * scale;
    return BorderRadius.only(
      topLeft: scaled(topLeft),
      topRight: scaled(topRight),
      bottomRight: scaled(bottomRight),
      bottomLeft: scaled(bottomLeft),
    );
  }

  (Offset, Offset) _cornerPoints(BeamCorner corner) {
    final r = _scaledRadii;
    return switch (corner) {
      BeamCorner.topLeft => (
        Offset(rect.left, rect.top + r.topLeft.y),
        Offset(rect.left + r.topLeft.x, rect.top),
      ),
      BeamCorner.topRight => (
        Offset(rect.right - r.topRight.x, rect.top),
        Offset(rect.right, rect.top + r.topRight.y),
      ),
      BeamCorner.bottomRight => (
        Offset(rect.right, rect.bottom - r.bottomRight.y),
        Offset(rect.right - r.bottomRight.x, rect.bottom),
      ),
      BeamCorner.bottomLeft => (
        Offset(rect.left + r.bottomLeft.x, rect.bottom),
        Offset(rect.left, rect.bottom - r.bottomLeft.y),
      ),
    };
  }

  (double, double) _cornerRange(BeamCorner corner) {
    final (start, end) = _cornerPoints(corner);
    return (nearestFraction(start), nearestFraction(end));
  }

  static double _clockwiseSpan(double from, double to) => _fraction(to - from);

  /// Resolves [t] along the straight part of [edge] in clockwise direction.
  double fractionOfEdge(BeamEdge edge, double t) {
    final (from, to) = switch (edge) {
      BeamEdge.top => (
        _cornerRange(BeamCorner.topLeft).$2,
        _cornerRange(BeamCorner.topRight).$1,
      ),
      BeamEdge.right => (
        _cornerRange(BeamCorner.topRight).$2,
        _cornerRange(BeamCorner.bottomRight).$1,
      ),
      BeamEdge.bottom => (
        _cornerRange(BeamCorner.bottomRight).$2,
        _cornerRange(BeamCorner.bottomLeft).$1,
      ),
      BeamEdge.left => (
        _cornerRange(BeamCorner.bottomLeft).$2,
        _cornerRange(BeamCorner.topLeft).$1,
      ),
    };
    return _fraction(from + _clockwiseSpan(from, to) * t.clamp(0.0, 1.0));
  }

  /// Resolves [t] through [corner]'s arc in clockwise direction.
  double fractionOfCorner(BeamCorner corner, double t) {
    final (from, to) = _cornerRange(corner);
    return _fraction(from + _clockwiseSpan(from, to) * t.clamp(0.0, 1.0));
  }

  /// Builds a closed sampled band from [from] clockwise to [to].
  ///
  /// Equal endpoints cover the full perimeter. [samplesPerUnit] is the
  /// approximate number of logical pixels between adjacent samples.
  Path band({
    required double from,
    required double to,
    required double inward,
    required double outward,
    int samplesPerUnit = 2,
  }) {
    final result = Path();
    if (length <= 0) return result;
    final start = _fraction(from);
    var span = _clockwiseSpan(start, _fraction(to));
    if (span == 0) span = 1;
    final spacing = math.max(1, samplesPerUnit);
    final steps = math.max(8, (span * length / spacing).ceil());
    final outside = <Offset>[];
    final inside = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final fraction = start + span * i / steps;
      final point = pointAt(fraction);
      final normal = normalAt(fraction);
      outside.add(point + normal * outward);
      inside.add(point - normal * inward);
    }
    result.moveTo(outside.first.dx, outside.first.dy);
    for (final point in outside.skip(1)) {
      result.lineTo(point.dx, point.dy);
    }
    for (final point in inside.reversed) {
      result.lineTo(point.dx, point.dy);
    }
    return result..close();
  }

  /// Returns the segment mask weight at [f].
  double weightAt(
    double f, {
    required double from,
    required double to,
    required double featherFraction,
  }) {
    final start = _fraction(from);
    var span = _clockwiseSpan(start, _fraction(to));
    if (span == 0) return 1;
    final position = _clockwiseSpan(start, _fraction(f));
    if (position > span) return 0;
    final feather = featherFraction.clamp(0.0, span / 2);
    if (feather == 0) return 1;
    double smoothstep(double value) => value * value * (3 - 2 * value);
    if (position < feather) return smoothstep(position / feather);
    final remaining = span - position;
    if (remaining < feather) return smoothstep(remaining / feather);
    return 1;
  }

  /// Converts a logical-pixel feather length into a perimeter fraction.
  double featherFractionFor(double featherPx) =>
      length <= 0 ? 0 : featherPx / length;

  /// Resolves [segment]'s anchors against this perimeter.
  ({double from, double to}) resolveSegment(BeamSegment segment) =>
      (from: segment.start.resolve(this), to: segment.end.resolve(this));
}

/// Path builders for the beam's shape: rounded rect, rounded superellipse, or
/// an arbitrary [BeamContour], plus the "ring" region every stroke layer is
/// clipped to.
///
/// The React library paints stroke layers into a CSS mask ring —
/// padding-box minus content-box. Here that is the [ring] path: the outer
/// contour (the shape's corner radii over the full rect) minus the inner
/// contour (each radius shrunk by `borderWidth`, over the rect deflated by
/// `borderWidth`).
class BeamRingGeometry {
  /// Creates geometry for [rect] with the given corner [radius],
  /// [borderWidth], and shape family.
  ///
  /// A non-null [contour] replaces the rounded-rect family entirely: it
  /// builds [outer], and [radius]/[useSuperellipse] go unread.
  BeamRingGeometry({
    required this.rect,
    required this.radius,
    required this.borderWidth,
    required this.useSuperellipse,
    this.contour,
    this.segment,
  });

  /// The layer bounds.
  final Rect rect;

  /// Outer corner radii in logical px, per corner.
  final BorderRadius radius;

  /// Ring thickness in logical px.
  final double borderWidth;

  /// Whether contours are rounded superellipses (squircles) instead of
  /// circular-arc rounded rects.
  final bool useSuperellipse;

  /// An arbitrary outer contour replacing the rounded-rect family, or null.
  final BeamContour? contour;

  /// The visible clockwise portion of the contour, or null for the full ring.
  final BeamSegment? segment;

  /// Outer contour of the shape.
  late final Path outer = rect.isEmpty
      ? Path()
      : (contour?.build(rect) ?? _shapePath(rect, radius));

  /// Arc-length coordinates for [outer].
  late final BeamPerimeter perimeter = BeamPerimeter(
    outer,
    rect,
    radii: contour == null ? radius : null,
  );

  /// Resolved segment endpoints, or null when the complete ring is visible.
  late final ({double from, double to})? segmentRange = segment == null
      ? null
      : perimeter.resolveSegment(segment!);

  /// A sampled band covering the configured segment at the given offsets.
  ///
  /// With no segment, a bounds-covering path keeps masking neutral.
  Path segmentBand({required double inward, required double outward}) {
    final range = segmentRange;
    return range == null
        ? (Path()..addRect(outer.getBounds()))
        : perimeter.band(
            from: range.from,
            to: range.to,
            inward: inward,
            outward: outward,
          );
  }

  /// The configured segment's feathered visibility at perimeter fraction [f].
  double segmentWeightAt(double f) {
    final range = segmentRange;
    final configured = segment;
    if (range == null || configured == null) return 1;
    return perimeter.weightAt(
      f,
      from: range.from,
      to: range.to,
      featherFraction: perimeter.featherFractionFor(configured.feather),
    );
  }

  /// Inner contour (the content box: deflated by [borderWidth], every corner
  /// radius reduced by the same amount).
  ///
  /// A box thinner than twice the border width has no content box left, and
  /// the contour is empty — the ring is then the whole shape. Under a custom
  /// [contour] the inner path is [outer] offset inward along its own normals
  /// by [borderWidth] (see [insetPath]), since an arbitrary path has no
  /// corner radii to shrink.
  late final Path inner = rect.isEmpty
      ? Path()
      : contour != null
      ? insetPath(outer, borderWidth)
      : _shapePath(
          rect.deflate(borderWidth),
          _deflateRadius(radius, borderWidth),
        );

  /// The border ring: [outer] minus [inner].
  late final Path ring = rect.isEmpty
      ? Path()
      : Path.combine(PathOperation.difference, outer, inner);

  Path _shapePath(Rect r, BorderRadius cornerRadii) {
    // A rect with no area (or an inverted one, from deflating past the
    // center) has no contour to describe.
    if (r.isEmpty) return Path();
    final c = _scaleRadii(r, cornerRadii);
    if (useSuperellipse) {
      return Path()..addRSuperellipse(
        RSuperellipse.fromRectAndCorners(
          r,
          topLeft: c.topLeft,
          topRight: c.topRight,
          bottomLeft: c.bottomLeft,
          bottomRight: c.bottomRight,
        ),
      );
    }
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        r,
        topLeft: c.topLeft,
        topRight: c.topRight,
        bottomLeft: c.bottomLeft,
        bottomRight: c.bottomRight,
      ),
    );
  }

  /// A standalone contour for an arbitrary rect/radius in the same shape
  /// family (used by pulse-outside's outward layers).
  Path shapeContour(Rect r, BorderRadius cornerRadii) =>
      _shapePath(r, cornerRadii);

  /// The halo a comet bloom fills: the shape grown by [reach], minus the
  /// content box, so the glow hugs the border and spills outward instead of
  /// washing across the child.
  Path halo(double reach) => rect.isEmpty
      ? Path()
      : Path.combine(PathOperation.difference, grown(reach), inner);

  /// [outer] grown outward by [reach], in the shape's own family.
  Path grown(double reach) => contour != null
      ? insetPath(outer, -reach)
      : _shapePath(rect.inflate(reach), _inflateRadius(radius, reach));

  /// [source] offset inward by [inset] along its own normals — a true
  /// polygonal offset, not a scale about the centre, so a lobed contour keeps
  /// an even border width all the way round.
  ///
  /// Each closed subpath is resampled at ~1px, its orientation read from the
  /// signed area (so a path drawn either way offsets inward), and every
  /// sample moved along the inward normal. A concave notch tighter than
  /// [inset] folds the offset over itself; the fold is a hairline at the
  /// border widths this is used at, and the non-zero fill rule swallows it.
  ///
  /// A negative [inset] offsets outward instead, which is how the comet halo
  /// grows an arbitrary contour.
  static Path insetPath(Path source, double inset) {
    final result = Path();
    if (inset == 0) return result..addPath(source, Offset.zero);
    for (final metric in source.computeMetrics()) {
      final length = metric.length;
      if (length <= 0) continue;
      final steps = math.max(8, length.round());
      final points = <Offset>[];
      final normals = <Offset>[];
      for (var i = 0; i < steps; i++) {
        final tangent = metric.getTangentForOffset(length * i / steps);
        if (tangent == null) continue;
        points.add(tangent.position);
        normals.add(Offset(tangent.vector.dx, tangent.vector.dy));
      }
      if (points.length < 3) continue;
      // Shoelace sign: positive for a path wound so that rotating the tangent
      // a quarter turn one way points inward, negative for the other.
      var area = 0.0;
      for (var i = 0; i < points.length; i++) {
        final a = points[i];
        final b = points[(i + 1) % points.length];
        area += a.dx * b.dy - b.dx * a.dy;
      }
      final sign = area >= 0 ? 1.0 : -1.0;
      for (var i = 0; i < points.length; i++) {
        final t = normals[i];
        final inward = Offset(-t.dy, t.dx) * sign;
        final p = points[i] + inward * inset;
        if (i == 0) {
          result.moveTo(p.dx, p.dy);
        } else {
          result.lineTo(p.dx, p.dy);
        }
      }
      result.close();
    }
    return result;
  }

  // Shrinks every corner by [amount], flooring each axis at zero — the
  // content box's corners are the padding box's minus the border width.
  static BorderRadius _deflateRadius(BorderRadius radii, double amount) =>
      BorderRadius.only(
        topLeft: _shrink(radii.topLeft, amount),
        topRight: _shrink(radii.topRight, amount),
        bottomLeft: _shrink(radii.bottomLeft, amount),
        bottomRight: _shrink(radii.bottomRight, amount),
      );

  // Grows every corner by [amount] — the mirror of [_deflateRadius], used by
  // the comet halo.
  static BorderRadius _inflateRadius(BorderRadius radii, double amount) =>
      BorderRadius.only(
        topLeft: _shrink(radii.topLeft, -amount),
        topRight: _shrink(radii.topRight, -amount),
        bottomLeft: _shrink(radii.bottomLeft, -amount),
        bottomRight: _shrink(radii.bottomRight, -amount),
      );

  static Radius _shrink(Radius r, double amount) =>
      Radius.elliptical(math.max(0, r.x - amount), math.max(0, r.y - amount));

  // The clamp `RRect.scaleRadii` applies: if the two radii on any side add up
  // to more than that side, all four shrink by the smallest offending ratio —
  // so the corners keep their relative proportions instead of being clipped
  // one at a time.
  static BorderRadius _scaleRadii(Rect r, BorderRadius radii) {
    final half = r.shortestSide / 2;
    var tl = _normalize(radii.topLeft, half);
    var tr = _normalize(radii.topRight, half);
    var bl = _normalize(radii.bottomLeft, half);
    var br = _normalize(radii.bottomRight, half);

    var scale = 1.0;
    scale = _limit(scale, r.width, tl.x + tr.x);
    scale = _limit(scale, r.height, tr.y + br.y);
    scale = _limit(scale, r.width, bl.x + br.x);
    scale = _limit(scale, r.height, tl.y + bl.y);
    if (scale < 1) {
      tl = tl * scale;
      tr = tr * scale;
      bl = bl * scale;
      br = br * scale;
    }
    return BorderRadius.only(
      topLeft: tl,
      topRight: tr,
      bottomLeft: bl,
      bottomRight: br,
    );
  }

  // Radii are floored at zero; an infinite one (BeamShape.stadium) becomes
  // half the shortest side, the largest a corner can hold, which is what
  // makes a pill track the box as it resizes.
  static Radius _normalize(Radius r, double half) =>
      Radius.elliptical(_finite(r.x, half), _finite(r.y, half));

  static double _finite(double value, double fallback) {
    final floored = math.max(0.0, value);
    return floored.isFinite ? floored : fallback;
  }

  static double _limit(double scale, double side, double sum) =>
      sum <= 0 ? scale : math.min(scale, side / sum);
}
