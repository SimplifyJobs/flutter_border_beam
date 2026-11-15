import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/beam_options.dart';
import '../models/beam_segment.dart';

/// Corner inset of the superellipse fit: the corner curve spans `k · r` along
/// each edge for a corner radius `r`.
///
/// Fitted against Flutter's own `RSuperellipse` (`Path.addRSuperellipse`):
/// with [squircleInset] and [squircleExponent] the p-norm corner stays within
/// 0.006 · r of it (0.14 px at r = 24), so the beam's stroke sits on the edge
/// of a child clipped by `RoundedSuperellipseBorder`.
const double squircleInset = 1.42;

/// Exponent of the superellipse corner fit (see [squircleInset]).
const double squircleExponent = 3.04;

/// The outline every beam is drawn along, and the perimeter coordinate the
/// shader shades by — mirrored here in Dart so the CPU can place lights,
/// resolve anchors, and map a pointer to the border with the same numbers the
/// GPU uses (`shaders/beam.frag`, `outline()`).
///
/// The outline is a rectangle with four corners, each either a circular arc
/// or a superellipse curve. The perimeter coordinate `u` runs over `[0, 1)`
/// from top-centre, clockwise, by arc length.
@immutable
class BeamOutline {
  /// The outline of [rect] with [radii], scaled the way `RRect.scaleRadii`
  /// scales them when two radii on one side add up to more than that side.
  ///
  /// Elliptical radii are approximated by the mean of their two axes.
  factory BeamOutline(
    Rect rect,
    BorderRadius radii, {
    bool superellipse = false,
  }) {
    final scaled = _scaleRadii(rect, radii);
    return BeamOutline._(rect, scaled, superellipse);
  }

  BeamOutline._(this.rect, this.radii, this.superellipse)
    : inset = superellipse ? squircleInset : 1,
      exponent = superellipse ? squircleExponent : 2,
      arcFactor = superellipse ? _squircleArcFactor : math.pi / 2 {
    final hx = rect.width / 2;
    final hy = rect.height / 2;
    final limit = math.min(hx, hy);
    double size(double r) => math.max(math.min(r * inset, limit), 1e-3);
    cornerSizes = List<double>.unmodifiable([
      size(radii[0]),
      size(radii[1]),
      size(radii[2]),
      size(radii[3]),
    ]);
    double quad(double r) => (hx - r) + r * arcFactor + (hy - r);
    final tr = quad(cornerSizes[1]);
    final br = quad(cornerSizes[2]);
    final bl = quad(cornerSizes[3]);
    final tl = quad(cornerSizes[0]);
    quadStarts = List<double>.unmodifiable([0.0, tr, tr + br, tr + br + bl]);
    length = tr + br + bl + tl;
  }

  /// The box the outline is inscribed in.
  final Rect rect;

  /// Resolved corner radii in clockwise order: top-left, top-right,
  /// bottom-right, bottom-left.
  final List<double> radii;

  /// Whether the corners are superellipse curves rather than circular arcs.
  final bool superellipse;

  /// Corner inset factor: 1 for circular corners, [squircleInset] otherwise.
  final double inset;

  /// Corner curve exponent: 2 for circular corners, [squircleExponent]
  /// otherwise.
  final double exponent;

  /// Arc length of one corner curve divided by its corner size.
  final double arcFactor;

  /// The size of each corner curve along the edges (radius × [inset], capped
  /// at half the shorter side), in the order of [radii].
  late final List<double> cornerSizes;

  /// Arc length at which each quadrant starts: top-right, bottom-right,
  /// bottom-left, top-left.
  late final List<double> quadStarts;

  /// Total perimeter length in logical px.
  late final double length;

  Offset get _centre => rect.center;
  double get _hx => rect.width / 2;
  double get _hy => rect.height / 2;

  // Quadrant order used by the shader: 0 TR, 1 BR, 2 BL, 3 TL. Corner sizes
  // are stored TL, TR, BR, BL.
  double _quadSize(int quad) => cornerSizes[(quad + 1) % 4];

  double _quadLength(int quad) {
    final r = _quadSize(quad);
    return (_hx - r) + r * arcFactor + (_hy - r);
  }

  double _exponentFor(double r) => r < 0.5 ? 2 : exponent;

  /// Signed distance from [point] to the outline (negative inside) and the
  /// perimeter coordinate of the outline piece nearest to it.
  ///
  /// Matches the shader's `outline()` exactly, including the nearest-piece
  /// choice: inside the shape the coordinate jumps across the medial axis, so
  /// only use it on or near the border.
  ({double distance, double u}) locate(Offset point) {
    final p = point - _centre;
    final right = p.dx > 0;
    final bottom = p.dy > 0;
    final quad = right ? (bottom ? 1 : 0) : (bottom ? 2 : 3);
    final r = _quadSize(quad);
    final n = _exponentFor(r);
    final ax = p.dx.abs();
    final ay = p.dy.abs();
    final qx = ax - (_hx - r);
    final qy = ay - (_hy - r);
    final legX = _hx - r;
    final arc = r * arcFactor;
    double d;
    double s;
    if (qx > 0 && qy > 0) {
      final circle = math.sqrt(qx * qx + qy * qy) - r;
      if (n == 2) {
        d = circle;
      } else {
        final sq = _pnormDistance(qx, qy, r, n);
        d = _mix(sq, circle, _smoothstep(0.25, 0.6, -circle / r));
      }
      s = legX + arc * (math.atan2(qx, qy) / (math.pi / 2));
    } else {
      d = math.max(qx, qy) - r;
      s = qx > qy ? legX + arc + (_hy - r - ay) : ax;
    }
    final mirrored = quad == 1 || quad == 3;
    if (mirrored) s = _quadLength(quad) - s;
    final u = length <= 0 ? 0.0 : _wrap((quadStarts[quad] + s) / length);
    return (distance: d, u: u);
  }

  /// The perimeter coordinate nearest [point] (see [locate]).
  double nearestFraction(Offset point) => locate(point).u;

  /// The point on the outline at perimeter coordinate [u].
  Offset pointAt(double u) => _sample(u).point;

  /// The outward unit normal at perimeter coordinate [u].
  Offset normalAt(double u) => _sample(u).normal;

  ({Offset point, Offset normal}) _sample(double u) {
    if (length <= 0) {
      return (point: rect.topCenter, normal: const Offset(0, -1));
    }
    var s = _wrap(u) * length;
    var quad = 3;
    for (var i = 1; i < 4; i++) {
      if (s < quadStarts[i]) {
        quad = i - 1;
        break;
      }
    }
    s -= quadStarts[quad];
    final mirrored = quad == 1 || quad == 3;
    if (mirrored) s = _quadLength(quad) - s;
    final r = _quadSize(quad);
    final n = _exponentFor(r);
    final legX = _hx - r;
    final arc = r * arcFactor;
    double ax;
    double ay;
    double nx;
    double ny;
    if (s <= legX) {
      ax = s;
      ay = _hy;
      nx = 0;
      ny = 1;
    } else if (s < legX + arc) {
      final theta = (s - legX) / arc * (math.pi / 2);
      final dx = math.sin(theta);
      final dy = math.cos(theta);
      final norm = math
          .pow(math.pow(dx, n) + math.pow(dy, n), 1 / n)
          .toDouble();
      ax = (_hx - r) + r * dx / norm;
      ay = (_hy - r) + r * dy / norm;
      final gx = math.pow(dx / norm, n - 1).toDouble();
      final gy = math.pow(dy / norm, n - 1).toDouble();
      final gl = math.sqrt(gx * gx + gy * gy);
      nx = gl == 0 ? 0 : gx / gl;
      ny = gl == 0 ? 1 : gy / gl;
    } else {
      ax = _hx;
      ay = (_hy - r) - (s - legX - arc);
      nx = 1;
      ny = 0;
    }
    final right = quad == 0 || quad == 1;
    final bottom = quad == 1 || quad == 2;
    final sx = right ? 1.0 : -1.0;
    final sy = bottom ? 1.0 : -1.0;
    return (
      point: _centre + Offset(ax * sx, ay * sy),
      normal: Offset(nx * sx, ny * sy),
    );
  }

  /// The perimeter coordinates at which the straight run of [edge] starts and
  /// ends, clockwise.
  ({double from, double to}) edgeRange(BeamEdge edge) {
    final c = _centre;
    final tl = cornerSizes[0];
    final tr = cornerSizes[1];
    final br = cornerSizes[2];
    final bl = cornerSizes[3];
    final (a, b) = switch (edge) {
      BeamEdge.top => (
        Offset(c.dx - (_hx - tl), rect.top),
        Offset(c.dx + (_hx - tr), rect.top),
      ),
      BeamEdge.right => (
        Offset(rect.right, c.dy - (_hy - tr)),
        Offset(rect.right, c.dy + (_hy - br)),
      ),
      BeamEdge.bottom => (
        Offset(c.dx + (_hx - br), rect.bottom),
        Offset(c.dx - (_hx - bl), rect.bottom),
      ),
      BeamEdge.left => (
        Offset(rect.left, c.dy + (_hy - bl)),
        Offset(rect.left, c.dy - (_hy - tl)),
      ),
    };
    return (from: _onEdge(a, edge), to: _onEdge(b, edge));
  }

  // The coordinate of a point known to lie on [edge]'s straight run. A joint
  // point sits exactly where a straight piece meets a corner, and both pieces
  // give it the same coordinate, so no tie-break is needed.
  double _onEdge(Offset point, BeamEdge edge) => locate(point).u;

  /// The perimeter coordinates at which [corner]'s curve starts and ends,
  /// clockwise.
  ({double from, double to}) cornerRange(BeamCorner corner) => switch (corner) {
    BeamCorner.topLeft => (
      from: edgeRange(BeamEdge.left).to,
      to: edgeRange(BeamEdge.top).from,
    ),
    BeamCorner.topRight => (
      from: edgeRange(BeamEdge.top).to,
      to: edgeRange(BeamEdge.right).from,
    ),
    BeamCorner.bottomRight => (
      from: edgeRange(BeamEdge.right).to,
      to: edgeRange(BeamEdge.bottom).from,
    ),
    BeamCorner.bottomLeft => (
      from: edgeRange(BeamEdge.bottom).to,
      to: edgeRange(BeamEdge.left).from,
    ),
  };

  /// The coordinate [t] of the way along [edge]'s straight run, clockwise.
  double fractionOfEdge(BeamEdge edge, double t) {
    final range = edgeRange(edge);
    return _along(range.from, range.to, t);
  }

  /// The coordinate [t] of the way through [corner]'s curve, clockwise.
  double fractionOfCorner(BeamCorner corner, double t) {
    final range = cornerRange(corner);
    return _along(range.from, range.to, t);
  }

  static double _along(double from, double to, double t) {
    final span = _wrap(to - from);
    return _wrap(from + span * t.clamp(0.0, 1.0));
  }

  /// Wraps [x] into `[0, 1)`.
  static double wrapFraction(double x) => _wrap(x);

  static double _wrap(double x) {
    final r = x % 1;
    return r < 0 ? r + 1 : r;
  }

  static double _mix(double a, double b, double t) => a + (b - a) * t;

  static double _smoothstep(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double _pnormDistance(double qx, double qy, double r, double n) {
    final ax = math.max(qx / r, 1e-4);
    final ay = math.max(qy / r, 1e-4);
    final sum = math.pow(ax, n) + math.pow(ay, n);
    final norm = math.pow(sum, 1 / n).toDouble();
    final scale = math.pow(math.max(norm, 1e-4), n - 1).toDouble();
    final gx = math.pow(ax, n - 1) / scale;
    final gy = math.pow(ay, n - 1) / scale;
    final gl = math.max(math.sqrt(gx * gx + gy * gy), 1e-4);
    return r * (norm - 1) / gl;
  }

  // Arc length of the unit p-norm quarter curve (n = squircleExponent),
  // measured once.
  static final double _squircleArcFactor = () {
    const steps = 2048;
    const n = squircleExponent;
    var total = 0.0;
    Offset? prev;
    for (var i = 0; i <= steps; i++) {
      final theta = i / steps * (math.pi / 2);
      final dx = math.sin(theta);
      final dy = math.cos(theta);
      final norm = math.pow(math.pow(dx, n) + math.pow(dy, n), 1 / n);
      final point = Offset(dx / norm, dy / norm);
      if (prev != null) total += (point - prev).distance;
      prev = point;
    }
    return total;
  }();

  /// The `RRect.scaleRadii` clamp, then each corner's elliptical radius
  /// reduced to the mean of its axes. Order: TL, TR, BR, BL.
  static List<double> _scaleRadii(Rect rect, BorderRadius radii) {
    final half = rect.shortestSide / 2;
    double axis(double v) {
      final floored = math.max(0.0, v);
      return floored.isFinite ? floored : half;
    }

    final tl = Offset(axis(radii.topLeft.x), axis(radii.topLeft.y));
    final tr = Offset(axis(radii.topRight.x), axis(radii.topRight.y));
    final br = Offset(axis(radii.bottomRight.x), axis(radii.bottomRight.y));
    final bl = Offset(axis(radii.bottomLeft.x), axis(radii.bottomLeft.y));
    var scale = 1.0;
    double limit(double side, double sum) =>
        sum <= 0 ? scale : math.min(scale, side / sum);
    scale = limit(rect.width, tl.dx + tr.dx);
    scale = limit(rect.height, tr.dy + br.dy);
    scale = limit(rect.width, bl.dx + br.dx);
    scale = limit(rect.height, tl.dy + bl.dy);
    double mean(Offset r) => (r.dx + r.dy) / 2 * scale;
    return List<double>.unmodifiable([mean(tl), mean(tr), mean(br), mean(bl)]);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamOutline &&
          other.rect == rect &&
          other.superellipse == superellipse &&
          listEquals(other.radii, radii);

  @override
  int get hashCode => Object.hash(rect, superellipse, Object.hashAll(radii));
}
