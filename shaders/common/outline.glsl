// Shared by every prismatic shader: the outline of a rounded box, as Flutter
// draws it — circular corners, or Flutter's rounded superellipse.
//
// Included, not compiled on its own: it is not listed under `flutter: shaders:`
// in pubspec.yaml. A shader that includes it declares nothing it uses here;
// everything arrives as arguments.

#ifndef PRISMATIC_OUTLINE_GLSL
#define PRISMATIC_OUTLINE_GLSL

const float OUTLINE_HALF_PI = 1.570796327;

// Flutter's rounded superellipse (RSuperellipse, as RoundedSuperellipseBorder
// draws it; impeller/geometry/round_superellipse_param.cc). Each corner is two
// halves, each running from the middle of one edge to the corner's diagonal:
// a superellipse |x/a|^n + |y/a|^n = 1 that hands over at a joint J to a
// circular arc ending on the diagonal. A half is evaluated in a frame where
// its edge runs along y = a, x is measured from the middle of that edge, and
// the diagonal is x = y. lib/src/border_beam/render/beam_outline.dart mirrors
// all of it.

const float SQUIRCLE_REACH = 2.5;  // past this many radii the edge is straight
const float GAP_FACTOR = 0.29289321881;

// Flutter's ComputeNAndXj: the exponent n and xJ / a for an edge [ratio]
// radii long (2a / r), piecewise linear through Flutter's table.
vec2 rseExponentAndJoint(float ratio) {
  vec2 nk;
  if (ratio > 5.0) {
    nk = vec2(6.43023796, 2.98020421) + (ratio - 5.0) * vec2(1.559599389, 0.522807185);
  } else {
    float c = clamp(ratio, 2.0, 5.0);
    float st = c < 2.5 ? (c - 2.0) * 10.0 : (c - 2.5) * 2.0 + 5.0;
    nk = vec2(2.00000000, 1.13276676) * max(1.0 - abs(st), 0.0)
       + vec2(2.18349805, 1.20311921) * max(1.0 - abs(st - 1.0), 0.0)
       + vec2(2.33888662, 1.28698796) * max(1.0 - abs(st - 2.0), 0.0)
       + vec2(2.48660575, 1.36351941) * max(1.0 - abs(st - 3.0), 0.0)
       + vec2(2.62226596, 1.44717976) * max(1.0 - abs(st - 4.0), 0.0)
       + vec2(2.75148990, 1.53385819) * max(1.0 - abs(st - 5.0), 0.0)
       + vec2(3.36298265, 1.98288283) * max(1.0 - abs(st - 6.0), 0.0)
       + vec2(4.08649929, 2.23811846) * max(1.0 - abs(st - 7.0), 0.0)
       + vec2(4.85481134, 2.47563463) * max(1.0 - abs(st - 8.0), 0.0)
       + vec2(5.62945551, 2.72948597) * max(1.0 - abs(st - 9.0), 0.0)
       + vec2(6.43023796, 2.98020421) * max(1.0 - abs(st - 10.0), 0.0);
  }
  return vec2(nk.x, 1.0 - 1.0 / nk.y);
}

// The unit superellipse of exponent n above x = t (0 < t < 1): its height,
// then its outward normal.
vec3 rseOnCurve(float t, float n) {
  float tn = pow(t, n);
  float y = pow(1.0 - tn, 1.0 / n);
  return vec3(y, normalize(vec2(tn / t, (1.0 - tn) / y)));
}

// One half of a superellipse corner of radius r, for a point P on its side
// of the diagonal: signed distance, arc length from the middle of the edge,
// and outward normal. The run up to the joint is measured along x.
//
// The shape is convex, so the signed distance to any line it rests against
// never exceeds the signed distance to the shape. Off the arc the distance is
// the largest of a few such lines — the tangent above or below the point,
// the tangent at the joint, and the box's sides — exact on the curve and
// continuous across the joint, inside and out.
vec4 rseHalf(vec2 P, float a, float r) {
  if (P.x <= a - min(SQUIRCLE_REACH * r, a)) return vec4(P.y - a, P.x, 0.0, 1.0);
  vec2 nj = rseExponentAndJoint(2.0 * a / r);
  float n = nj.x;
  vec3 joint = rseOnCurve(nj.y, n);
  vec2 J = a * vec2(nj.y, joint.x);
  // Flutter sizes the arc by where the superellipse's normal at the joint
  // crosses the diagonal, then centres it on J and the diagonal point g in
  // from both sides.
  float tanPhi = joint.y / joint.z;
  float onDiagonal = (J.x - tanPhi * J.y) / (1.0 - tanPhi);
  float g = GAP_FACTOR * r;
  float R = (a - onDiagonal - g) * 1.41421356;
  vec2 chord = vec2(a - g) - J;
  float cl = length(chord);
  float rise = sqrt(max(R * R - 0.25 * cl * cl, 0.0));
  vec2 C = J + 0.5 * chord + rise * vec2(chord.y, -chord.x) / cl;

  float box = max(P.x - a, P.y - a);
  vec2 jc = J - C;
  vec2 pc = P - C;
  if (jc.x * pc.y - jc.y * pc.x <= 0.0) {
    // Past the joint, clockwise: the arc.
    float l = max(length(pc), 1e-4);
    float theta = atan(jc.y * pc.x - jc.x * pc.y, dot(jc, pc));
    return vec4(max(l - R, box), J.x + R * theta, pc / l);
  }
  // The superellipse: the tangent at the curve point straight above or
  // below, up to the joint.
  float xb = min(P.x, J.x);
  vec3 foot = rseOnCurve(max(xb / a, 1e-4), n);
  float along = dot(P - vec2(xb, foot.x * a), foot.yz);
  float atJoint = dot(P - J, joint.yz);
  return vec4(max(max(along, atJoint), box), P.x - along * foot.y, foot.yz);
}

// Signed distance to the outline (negative inside), arc length from top-centre
// clockwise, and the outward normal of the nearest piece of the outline.
//
//   p          the point, relative to the box's centre
//   b          the box's half-size
//   radii      corner radii: top-left, top-right, bottom-right, bottom-left
//   squircle   true for Flutter's rounded superellipse, false for circular
//   quads      arc length where each quadrant starts: TR, BR, BL, TL
//   perimeter  the outline's whole length
//
// With superellipse corners the quadrant lengths come from quads/perimeter,
// which the Dart side measures (BeamOutline); circular corners need neither.
vec4 outline(vec2 p, vec2 b, vec4 radii, bool squircle, vec4 quads, float perimeter) {
  bool right = p.x > 0.0;
  bool bottom = p.y > 0.0;
  float r = right ? (bottom ? radii.z : radii.y) : (bottom ? radii.w : radii.x);
  float R = min(r, min(b.x, b.y));
  vec2 a = abs(p);
  float d;
  float s; // arc length within the quadrant, starting on the vertical axis
  vec2 nrm;
  float quadLen;
  if (squircle && R >= 0.5) {
    // A superellipse corner. Its halves meet on the 45° line through the
    // corner's diagonal.
    quadLen = right ? (bottom ? quads.z - quads.y : quads.y - quads.x)
                    : (bottom ? quads.w - quads.z : perimeter - quads.w);
    float c = b.x - b.y;
    vec4 h;
    if (a.x - a.y <= c) {
      h = rseHalf(vec2(a.x, a.y + c), b.x, R);
    } else {
      h = rseHalf(vec2(a.y, a.x - c), b.y, R);
      h = vec4(h.x, quadLen - h.y, h.w, h.z);
    }
    d = h.x;
    s = h.y;
    nrm = h.zw;
  } else {
    // A circular corner.
    R = max(R, 1e-3);
    vec2 q = a - (b - R);
    float legX = b.x - R;
    float arc = R * OUTLINE_HALF_PI;
    quadLen = legX + arc + (b.y - R);
    if (q.x > 0.0 && q.y > 0.0) {
      d = length(q) - R;
      s = legX + arc * (atan(q.x, q.y) / OUTLINE_HALF_PI);
      nrm = q / max(length(q), 1e-4);
    } else {
      d = max(q.x, q.y) - R;
      bool side = q.x > q.y;
      s = side ? legX + arc + (b.y - R - a.y) : a.x;
      nrm = side ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    }
  }
  nrm *= vec2(right ? 1.0 : -1.0, bottom ? 1.0 : -1.0);
  // TR and BL run vertical axis → horizontal axis clockwise; BR and TL run the
  // other way, so their local arc length is mirrored.
  float start;
  if (right) {
    start = bottom ? quads.y : quads.x;
    if (bottom) s = quadLen - s;
  } else {
    start = bottom ? quads.z : quads.w;
    if (!bottom) s = quadLen - s;
  }
  return vec4(d, start + s, nrm);
}

#endif
