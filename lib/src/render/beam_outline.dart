import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/beam_options.dart';
import '../models/beam_segment.dart';

/// How far a superellipse corner reaches along each edge, in corner radii
/// (capped at half that side).
///
/// Flutter's rounded superellipse never runs exactly straight: its corner
/// eases into each edge over a long tail. Past this reach the tail is under
/// 1.4e-4 radii from the edge (0.004 px at a 28 px radius), so the outline
/// runs straight from there.
const double squircleReach = 2.5;

/// The outline every beam is drawn along, and the perimeter coordinate the
/// shader shades by — mirrored here in Dart so the CPU can place lights,
/// resolve anchors, and map a pointer to the border with the same numbers the
/// GPU uses (`shaders/beam.frag`, `outline()`).
///
/// The outline is a rectangle with four corners, each either a circular arc
/// or Flutter's rounded superellipse (`RSuperellipse`, as drawn by
/// `RoundedSuperellipseBorder`). The perimeter coordinate `u` runs over
/// `[0, 1)` from top-centre, clockwise, by arc length.
///
/// Each corner is two halves, each running from the middle of one edge to the
/// corner's diagonal. A circular half is a straight run and an eighth of a
/// circle. A superellipse half is Flutter's construction
/// (`impeller/geometry/round_superellipse_param.cc`): a superellipse whose
/// exponent and hand-over point come from Flutter's own table for the
/// ratio of that edge to the radius, then a circular arc to the diagonal, where
/// it meets the other half. So the outline sits on a child clipped or
/// decorated with `RoundedSuperellipseBorder` of the same radii at every
/// aspect ratio — a card, a pill, a circle.
@immutable
class BeamOutline {
  /// The outline of [rect] with [radii], scaled the way `RRect.scaleRadii`
  /// scales them when two radii on one side add up to more than that side.
  ///
  /// Elliptical radii are approximated by the mean of their two axes, and a
  /// corner's radius is capped at half the shorter side.
  ///
  /// Each corner keeps to its own quarter of the box. Flutter instead splits
  /// each side between its two corners in proportion to their radii, so with
  /// uneven superellipse radii the two shapes part slightly: within ~0.1 px
  /// for ordinary mixes, up to ~2% of the radius where a corner of half the
  /// short side meets a square corner across that side.
  factory BeamOutline(
    Rect rect,
    BorderRadius radii, {
    bool superellipse = false,
  }) {
    final scaled = _scaleRadii(rect, radii);
    return BeamOutline._(rect, scaled, superellipse);
  }

  BeamOutline._(this.rect, this.radii, this.superellipse) {
    final hx = rect.width / 2;
    final hy = rect.height / 2;
    final limit = math.min(hx, hy);
    final horizontal = <_Half>[];
    final vertical = <_Half>[];
    // Quadrant order used by the shader: 0 TR, 1 BR, 2 BL, 3 TL. Radii are
    // stored TL, TR, BR, BL.
    for (var quad = 0; quad < 4; quad++) {
      final r = math.min(radii[(quad + 1) % 4], limit);
      if (superellipse && r >= 0.5) {
        horizontal.add(_Half.superellipse(hx, r));
        vertical.add(_Half.superellipse(hy, r));
      } else {
        final size = math.max(r, 1e-3);
        horizontal.add(_Half.circular(hx, size));
        vertical.add(_Half.circular(hy, size));
      }
    }
    _horizontal = List.unmodifiable(horizontal);
    _vertical = List.unmodifiable(vertical);
    final lengths = [
      for (var quad = 0; quad < 4; quad++)
        _horizontal[quad].length + _vertical[quad].length,
    ];
    quadStarts = List<double>.unmodifiable([
      0.0,
      lengths[0],
      lengths[0] + lengths[1],
      lengths[0] + lengths[1] + lengths[2],
    ]);
    length = lengths[0] + lengths[1] + lengths[2] + lengths[3];
    double corner(int quad) =>
        math.max(_horizontal[quad].reach, _vertical[quad].reach);
    double arc(int quad) =>
        lengths[quad] -
        (hx - _horizontal[quad].reach) -
        (hy - _vertical[quad].reach);
    cornerSizes = List<double>.unmodifiable([
      corner(3),
      corner(0),
      corner(1),
      corner(2),
    ]);
    cornerArcs = List<double>.unmodifiable([arc(3), arc(0), arc(1), arc(2)]);
  }

  /// The box the outline is inscribed in.
  final Rect rect;

  /// Resolved corner radii in clockwise order: top-left, top-right,
  /// bottom-right, bottom-left.
  final List<double> radii;

  /// Whether the corners are Flutter's rounded superellipse rather than
  /// circular arcs.
  final bool superellipse;

  // Each quadrant's two halves (0 TR, 1 BR, 2 BL, 3 TL): the one along the
  // horizontal edge and the one along the vertical edge.
  late final List<_Half> _horizontal;
  late final List<_Half> _vertical;

  /// How far each corner's curve reaches along the edges from the box's
  /// corner, in the order of [radii]: the radius for a circular corner,
  /// radius × [squircleReach] for a superellipse — each capped at half the
  /// side it runs along; where the two sides differ, the longer reach.
  late final List<double> cornerSizes;

  /// The arc length of each corner's curve between the straight runs it
  /// joins, in the order of [radii].
  late final List<double> cornerArcs;

  /// Arc length at which each quadrant starts: top-right, bottom-right,
  /// bottom-left, top-left.
  late final List<double> quadStarts;

  /// Total perimeter length in logical px.
  late final double length;

  Offset get _centre => rect.center;
  double get _hx => rect.width / 2;
  double get _hy => rect.height / 2;

  double _quadLength(int quad) =>
      _horizontal[quad].length + _vertical[quad].length;

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
    final ax = p.dx.abs();
    final ay = p.dy.abs();
    // The halves meet on the 45° line through the corner's diagonal.
    final c = _hx - _hy;
    final quadLength = _quadLength(quad);
    double d;
    double s;
    if (ax - ay <= c) {
      final hit = _horizontal[quad].locate(ax, ay + c);
      d = hit.d;
      s = hit.s;
    } else {
      final hit = _vertical[quad].locate(ay, ax - c);
      d = hit.d;
      s = quadLength - hit.s;
    }
    // TR and BL run horizontal edge → vertical edge clockwise; BR and TL run
    // the other way, so their local arc length is mirrored.
    final mirrored = quad == 1 || quad == 3;
    if (mirrored) s = quadLength - s;
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
    final quadLength = _quadLength(quad);
    final mirrored = quad == 1 || quad == 3;
    if (mirrored) s = quadLength - s;
    final c = _hx - _hy;
    double ax;
    double ay;
    double nx;
    double ny;
    final horizontal = _horizontal[quad];
    if (s <= horizontal.length) {
      final at = horizontal.sample(s);
      ax = at.x;
      ay = at.y - c;
      nx = at.nx;
      ny = at.ny;
    } else {
      final at = _vertical[quad].sample(quadLength - s);
      ax = at.y + c;
      ay = at.x;
      nx = at.ny;
      ny = at.nx;
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
    // Where each quadrant's run along its horizontal or vertical edge ends,
    // as arc length from the start of the quadrant.
    double horizontal(int quad) {
      final run = _hx - _horizontal[quad].reach;
      return quad == 1 || quad == 3 ? _quadLength(quad) - run : run;
    }

    double vertical(int quad) {
      final run = _hy - _vertical[quad].reach;
      return quad == 1 || quad == 3 ? run : _quadLength(quad) - run;
    }

    final (fromQuad, from, toQuad, to) = switch (edge) {
      BeamEdge.top => (3, horizontal(3), 0, horizontal(0)),
      BeamEdge.right => (0, vertical(0), 1, vertical(1)),
      BeamEdge.bottom => (1, horizontal(1), 2, horizontal(2)),
      BeamEdge.left => (2, vertical(2), 3, vertical(3)),
    };
    return (from: _fraction(fromQuad, from), to: _fraction(toQuad, to));
  }

  double _fraction(int quad, double s) =>
      length <= 0 ? 0.0 : _wrap((quadStarts[quad] + s) / length);

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

/// Flutter's `kGapFactor`: the corner's diagonal point sits this many radii
/// in from both sides, where a circular corner of the same radius would.
const double _gapFactor = 0.29289321881;

/// Flutter's precomputed `(n, 1 / (1 - xJ / a))` for ratios `2a / radius` of
/// 2.0–2.5 in steps of 0.1, then 3.0–5.0 in steps of 0.5; linear beyond.
const List<(double, double)> _rseTable = [
  (2.00000000, 1.13276676),
  (2.18349805, 1.20311921),
  (2.33888662, 1.28698796),
  (2.48660575, 1.36351941),
  (2.62226596, 1.44717976),
  (2.75148990, 1.53385819),
  (3.36298265, 1.98288283),
  (4.08649929, 2.23811846),
  (4.85481134, 2.47563463),
  (5.62945551, 2.72948597),
  (6.43023796, 2.98020421),
];

/// Half of a corner, in a frame where its edge runs along `y = a`, `x` is
/// measured from the middle of that edge, and the corner's diagonal is the
/// line `x = y`.
///
/// Along the edge the outline runs straight to [a] − [reach], then curves —
/// for a superellipse half along `|x/a|ⁿ + |y/a|ⁿ = 1` to the joint `(xJ,
/// yJ)` — and finishes with a circular arc of [radius] about `(cx, cy)` through
/// [span] radians to the diagonal. A circular half is the straight run and an
/// eighth of a circle.
@immutable
class _Half {
  const _Half._({
    required this.a,
    required this.reach,
    required this.n,
    required this.xJ,
    required this.yJ,
    required this.nJx,
    required this.nJy,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.span,
  });

  /// A circular half of radius [r].
  factory _Half.circular(double a, double r) => _Half._(
    a: a,
    reach: r,
    n: 0,
    xJ: a - r,
    yJ: a,
    nJx: 0,
    nJy: 1,
    cx: a - r,
    cy: a - r,
    radius: r,
    span: math.pi / 4,
  );

  /// Flutter's superellipse half for radius [r] (`ComputeOctant`).
  factory _Half.superellipse(double a, double r) {
    final (n, xJOverA) = _exponentAndJoint(2 * a / r);
    final joint = _onCurve(xJOverA, n);
    final xJ = xJOverA * a;
    final yJ = joint.y * a;
    // Flutter sizes the arc by where the superellipse's normal at the joint
    // crosses the diagonal, then centres it on the joint and the diagonal
    // point `g` in from both sides.
    final tanPhi = joint.nx / joint.ny;
    final onDiagonal = (xJ - tanPhi * yJ) / (1 - tanPhi);
    final g = _gapFactor * r;
    final radius = (a - onDiagonal - g) * math.sqrt2;
    final mx = a - g;
    final chordX = mx - xJ;
    final chordY = mx - yJ;
    final chord = math.sqrt(chordX * chordX + chordY * chordY);
    final rise = math.sqrt(math.max(radius * radius - chord * chord / 4, 0));
    final cx = (xJ + mx) / 2 + rise * chordY / chord;
    final cy = (yJ + mx) / 2 - rise * chordX / chord;
    // The arc turns clockwise from the joint to the diagonal point.
    final jx = xJ - cx;
    final jy = yJ - cy;
    final ex = mx - cx;
    final ey = mx - cy;
    final span = math.atan2(jy * ex - jx * ey, jx * ex + jy * ey);
    return _Half._(
      a: a,
      reach: math.min(squircleReach * r, a),
      n: n,
      xJ: xJ,
      yJ: yJ,
      nJx: joint.nx,
      nJy: joint.ny,
      cx: cx,
      cy: cy,
      radius: radius,
      span: span,
    );
  }

  /// Flutter's `ComputeNAndXj`: the exponent and `xJ / a` for [ratio].
  static (double, double) _exponentAndJoint(double ratio) {
    double n;
    double k;
    if (ratio > 5) {
      final (n5, k5) = _rseTable.last;
      n = n5 + 1.559599389 * (ratio - 5);
      k = k5 + 0.522807185 * (ratio - 5);
    } else {
      final clamped = ratio.clamp(2.0, 5.0);
      final steps = clamped < 2.5
          ? (clamped - 2) * 10
          : (clamped - 2.5) * 2 + 5;
      final left = steps.floor().clamp(0, _rseTable.length - 2);
      final frac = steps - left;
      final (n0, k0) = _rseTable[left];
      final (n1, k1) = _rseTable[left + 1];
      n = n0 + (n1 - n0) * frac;
      k = k0 + (k1 - k0) * frac;
    }
    return (n, 1 - 1 / k);
  }

  /// The unit superellipse of exponent [n] above `x = t` (`0 < t < 1`): its
  /// height and outward normal.
  static ({double y, double nx, double ny}) _onCurve(double t, double n) {
    final tn = math.pow(t, n).toDouble();
    final y = math.pow(1 - tn, 1 / n).toDouble();
    final gx = tn / t;
    final gy = (1 - tn) / y;
    final gl = math.sqrt(gx * gx + gy * gy);
    return (y: y, nx: gx / gl, ny: gy / gl);
  }

  final double a;
  final double reach;

  /// The superellipse exponent, or 0 for a circular half.
  final double n;
  final double xJ;
  final double yJ;

  /// The superellipse's outward normal at the joint.
  final double nJx;
  final double nJy;
  final double cx;
  final double cy;
  final double radius;
  final double span;

  /// Arc length from the middle of the edge to the diagonal. The run up to
  /// the joint is measured along `x`: the superellipse there stays within a
  /// few degrees of level, so this is short of its true length by under
  /// 0.1 px.
  double get length => xJ + radius * span;

  /// Signed distance to this half, arc length from the middle of the edge,
  /// and outward normal, for a point `(x, y)` on its side of the diagonal.
  ///
  /// The shape is convex, so the signed distance to any line it rests
  /// against never exceeds the signed distance to the shape. Off the arc the
  /// distance is the largest of a few such lines: the tangent above or below
  /// the point, the tangent at the joint, and the box's two sides — exact on
  /// the curve, and continuous across the joint inside and out.
  ({double d, double s, double nx, double ny}) locate(double x, double y) {
    if (x <= a - reach) return (d: y - a, s: x, nx: 0, ny: 1);
    final box = math.max(x - a, y - a);
    final jx = xJ - cx;
    final jy = yJ - cy;
    final px = x - cx;
    final py = y - cy;
    if (n == 0 || jx * py - jy * px <= 0) {
      // Past the joint, clockwise: the arc.
      final l = math.max(math.sqrt(px * px + py * py), 1e-4);
      final theta = math.atan2(jy * px - jx * py, jx * px + jy * py);
      return (
        d: math.max(l - radius, box),
        s: xJ + radius * theta,
        nx: px / l,
        ny: py / l,
      );
    }
    // The superellipse: the tangent at the curve point straight above or
    // below, up to the joint.
    final xb = math.min(x, xJ);
    final b = _onCurve(math.max(xb / a, 1e-4), n);
    final along = (x - xb) * b.nx + (y - b.y * a) * b.ny;
    final atJoint = (x - xJ) * nJx + (y - yJ) * nJy;
    return (
      d: math.max(math.max(along, atJoint), box),
      s: x - along * b.nx,
      nx: b.nx,
      ny: b.ny,
    );
  }

  /// The point at arc length [s] from the middle of the edge, and the
  /// outward normal there.
  ({double x, double y, double nx, double ny}) sample(double s) {
    if (s <= xJ) {
      if (n == 0 || s <= a - reach) return (x: s, y: a, nx: 0, ny: 1);
      final b = _onCurve(math.max(s / a, 1e-4), n);
      return (x: s, y: b.y * a, nx: b.nx, ny: b.ny);
    }
    final theta = (s - xJ) / radius;
    final cos = math.cos(theta);
    final sin = math.sin(theta);
    final jx = (xJ - cx) / radius;
    final jy = (yJ - cy) / radius;
    // Rotate the joint's radius clockwise by theta.
    final vx = jx * cos + jy * sin;
    final vy = jy * cos - jx * sin;
    return (x: cx + radius * vx, y: cy + radius * vy, nx: vx, ny: vy);
  }
}
