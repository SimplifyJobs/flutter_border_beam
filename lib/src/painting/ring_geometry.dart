import 'dart:math' as math;
import 'dart:ui';

/// Path builders for the beam's shape: rounded rect or rounded superellipse,
/// plus the "ring" region every stroke layer is clipped to.
///
/// The React library paints stroke layers into a CSS mask ring —
/// padding-box minus content-box. Here that is the [ring] path: the outer
/// contour (corner radius `R` over the full rect) minus the inner contour
/// (radius `R − borderWidth` over the rect deflated by `borderWidth`).
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

  /// Outer corner radius in logical px.
  final double radius;

  /// Ring thickness in logical px.
  final double borderWidth;

  /// Whether contours are rounded superellipses (squircles) instead of
  /// circular-arc rounded rects.
  final bool useSuperellipse;

  /// Outer contour of the shape.
  late final Path outer = _shapePath(rect, radius);

  /// Inner contour (the content box: deflated by [borderWidth], radius
  /// reduced accordingly).
  ///
  /// A box thinner than twice the border width has no content box left, and
  /// the contour is empty — the ring is then the whole shape.
  late final Path inner = _shapePath(
    rect.deflate(borderWidth),
    radius - borderWidth,
  );

  /// The border ring: [outer] minus [inner].
  late final Path ring = rect.isEmpty
      ? Path()
      : Path.combine(PathOperation.difference, outer, inner);

  Path _shapePath(Rect r, double cornerRadius) {
    // A rect with no area (or an inverted one, from deflating past the
    // center) has no contour to describe.
    if (r.isEmpty) return Path();
    final clamped = _clampRadius(r, cornerRadius);
    if (useSuperellipse) {
      return Path()..addRSuperellipse(
        RSuperellipse.fromRectAndRadius(r, Radius.circular(clamped)),
      );
    }
    return Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(clamped)));
  }

  /// A standalone contour for an arbitrary rect/radius in the same shape
  /// family (used by pulse-outside's outward layers).
  Path contour(Rect r, double cornerRadius) => _shapePath(r, cornerRadius);

  // Corner radii are clamped to half the shortest side (a larger one has no
  // room to draw) and never go below zero, which every rounded-rect
  // constructor rejects.
  static double _clampRadius(Rect r, double radius) =>
      math.max(0, math.min(radius, math.min(r.width, r.height) / 2));
}
