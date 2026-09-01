import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Path builders for the beam's shape: rounded rect or rounded superellipse,
/// plus the "ring" region every stroke layer is clipped to.
///
/// The React library paints stroke layers into a CSS mask ring —
/// padding-box minus content-box. Here that is the [ring] path: the outer
/// contour (the shape's corner radii over the full rect) minus the inner
/// contour (each radius shrunk by `borderWidth`, over the rect deflated by
/// `borderWidth`).
class BeamRingGeometry {
  /// Creates geometry for [rect] with the given corner [radius],
  /// [borderWidth], and shape family.
  BeamRingGeometry({
    required this.rect,
    required this.radius,
    required this.borderWidth,
    required this.useSuperellipse,
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

  /// Outer contour of the shape.
  late final Path outer = _shapePath(rect, radius);

  /// Inner contour (the content box: deflated by [borderWidth], every corner
  /// radius reduced by the same amount).
  ///
  /// A box thinner than twice the border width has no content box left, and
  /// the contour is empty — the ring is then the whole shape.
  late final Path inner = _shapePath(
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
  Path contour(Rect r, BorderRadius cornerRadii) => _shapePath(r, cornerRadii);

  // Shrinks every corner by [amount], flooring each axis at zero — the
  // content box's corners are the padding box's minus the border width.
  static BorderRadius _deflateRadius(BorderRadius radii, double amount) =>
      BorderRadius.only(
        topLeft: _shrink(radii.topLeft, amount),
        topRight: _shrink(radii.topRight, amount),
        bottomLeft: _shrink(radii.bottomLeft, amount),
        bottomRight: _shrink(radii.bottomRight, amount),
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
