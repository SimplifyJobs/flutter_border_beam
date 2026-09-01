import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../models/beam_options.dart';

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

  /// Outer contour of the shape.
  late final Path outer = rect.isEmpty
      ? Path()
      : (contour?.build(rect) ?? _shapePath(rect, radius));

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
