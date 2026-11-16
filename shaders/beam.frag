// prismatic — the whole effect in one fragment shader.
//
// A beam is up to three layers composited bottom to top, each evaluated per
// pixel in this one pass:
//
//   layer 0 — the inner glow,
//   layer 1 — the hairline stroke,
//   layer 2 — the bloom.
//
// A layer is an optional conic overlay (the white or black highlight at the
// head of a beam, or the bloom band) with a stack of soft radial colour blobs
// painted over it (premultiplied source-over, each over the ones before), an
// optional inset shadow, then masks — a geometry mask (the 1px ring, the filled shape, a
// blurred ring, or a glow outside the shape), a window (a rotating conic
// or a radial ellipse), and an edge fade — and finally a 3×3
// colour matrix (hue rotation, brightness, saturation) and the layer opacity.
//
// Every blur of the reference design is replaced by its analytic equivalent:
// a blurred 1px ring is a gaussian across the distance to the ring, and a
// blurred blob — cut where its layer's shape ends — is an energy-preserving
// gaussian. One draw, no offscreen passes, no filters.
//
// Uniforms are vec4s and vec4 arrays only, so the float layout is identical on
// every backend (Impeller Metal / Vulkan / GLES, and Skia's SkSL). The Dart
// packer (lib/src/render/beam_frame.dart) mirrors this order exactly;
// test/render/ parses this file to keep the two in step.

#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec4 uRect;   // outline box: left, top, width, height
uniform vec4 uRadii;  // corner radii: top-left, top-right, bottom-right, bottom-left
uniform vec4 uShape;  // x corners (0 circular, 1 rounded superellipse), y unused, z stroke width, w px per device px
uniform vec4 uPerim;  // x perimeter length, y unused, z dither on/off, w unused
uniform vec4 uQuads;  // arc length where each quadrant starts: TR, BR, BL, TL
uniform vec4 uMask;   // x segment start u, y segment span (0 or 1 = all), z feather (u), w dashes
uniform vec4 uConic;  // xy conic centre, z conic start (turns), w repeats around the turn
// Per layer, 9 vec4s:
//   0: x geometry kind, y blur sigma, z reach (glow), w opacity
//   1: x edge fade px, y window kind, z overlay table (0 none, 1 A, 2 B), w overlay ink (0 black, 1 white)
//   2: window parameters (radial: centre, radii)
//   3: x radial mid stop, y radial mid alpha, z blob mode (0 planar, 1 path,
//      2 blurred planar, 3 blurred path), w blob count
//   4: inset shadow colour (straight rgba)
//   5: x shadow solid depth, y shadow sigma, z dashes apply, w unused
//   6-8: colour matrix rows (xyz)
uniform vec4 uLayer[27];
uniform vec4 uWinA[8];  // conic window tables: (position, alpha) pairs, two per vec4
uniform vec4 uWinB[8];
uniform vec4 uOverA[8]; // conic overlay tables
uniform vec4 uOverB[8];
// Blobs, three vec4s each, in painting order (each over the ones before):
//   0: centre xy, radii xy (profile mode) or sigmas xy (gaussian mode)
//   1: straight rgb, a0 (alpha at the centre; peak in gaussian mode)
//   2: p1, a1, p2, a2 — the alpha profile 0:a0 → p1:a1 → p2:a2 → 1:0
uniform vec4 uBlobA[42]; // layer 0, 14 blobs
uniform vec4 uBlobB[30]; // layer 1, 10 blobs
uniform vec4 uBlobC[30]; // layer 2, 10 blobs

out vec4 fragColor;

const float TAU = 6.283185307;
const float HALF_PI = 1.570796327;
const float INV_SQRT_TAU = 0.3989422804;

// Flutter's rounded superellipse (RSuperellipse, as RoundedSuperellipseBorder
// draws it; impeller/geometry/round_superellipse_param.cc). Each corner is two
// halves, each running from the middle of one edge to the corner's diagonal:
// a superellipse |x/a|^n + |y/a|^n = 1 that hands over at a joint J to a
// circular arc ending on the diagonal. A half is evaluated in a frame where
// its edge runs along y = a, x is measured from the middle of that edge, and
// the diagonal is x = y. lib/src/render/beam_outline.dart mirrors all of it.

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
vec4 outline(vec2 p, vec2 b) {
  bool right = p.x > 0.0;
  bool bottom = p.y > 0.0;
  float r = right ? (bottom ? uRadii.z : uRadii.y) : (bottom ? uRadii.w : uRadii.x);
  float R = min(r, min(b.x, b.y));
  vec2 a = abs(p);
  float d;
  float s; // arc length within the quadrant, starting on the vertical axis
  vec2 nrm;
  float quadLen;
  if (uShape.x > 0.5 && R >= 0.5) {
    // A superellipse corner. Its halves meet on the 45° line through the
    // corner's diagonal.
    quadLen = right ? (bottom ? uQuads.z - uQuads.y : uQuads.y - uQuads.x)
                    : (bottom ? uQuads.w - uQuads.z : uPerim.x - uQuads.w);
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
    float arc = R * HALF_PI;
    quadLen = legX + arc + (b.y - R);
    if (q.x > 0.0 && q.y > 0.0) {
      d = length(q) - R;
      s = legX + arc * (atan(q.x, q.y) / HALF_PI);
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
    start = bottom ? uQuads.y : uQuads.x;
    if (bottom) s = quadLen - s;
  } else {
    start = bottom ? uQuads.z : uQuads.w;
    if (!bottom) s = quadLen - s;
  }
  return vec4(d, start + s, nrm);
}

// Standard normal CDF, logistic approximation (max error ~0.01).
float phi(float z) {
  return 1.0 / (1.0 + exp(-1.702 * z));
}

vec4 srcOver(vec4 src, vec4 dst) {
  return src + dst * (1.0 - src.a);
}

// Piecewise-linear table lookup over (position, alpha) pairs, two per vec4,
// ascending and padded with copies of the last stop. A table whose first
// position is past 1 is unused and costs one comparison.
#define TABLE_STEP(ST, T, PP, PA, OUT, DONE)                                  \
  if (!DONE) {                                                                \
    if (T <= ST.x) {                                                          \
      OUT = mix(PA, ST.y, clamp((T - PP) / max(ST.x - PP, 1e-5), 0.0, 1.0));  \
      DONE = true;                                                            \
    } else {                                                                  \
      PP = ST.x;                                                              \
      PA = ST.y;                                                              \
    }                                                                         \
  }

#define TABLE_LOOKUP(TABLE, T, OUT)                                           \
  {                                                                           \
    float pp = TABLE[0].x;                                                    \
    float pa = TABLE[0].y;                                                    \
    OUT = pa;                                                                 \
    if (T > pp && pp <= 1.0) {                                                \
      OUT = TABLE[7].w;                                                       \
      bool done = false;                                                      \
      for (int i = 0; i < 8; i++) {                                           \
        vec4 e = TABLE[i];                                                    \
        TABLE_STEP(e.xy, T, pp, pa, OUT, done)                                \
        TABLE_STEP(e.zw, T, pp, pa, OUT, done)                                \
        if (done) break;                                                      \
      }                                                                       \
    }                                                                         \
  }

// One blob's premultiplied colour at offset [o] from its centre.
vec4 blob(vec4 b0, vec4 b1, vec4 b2, vec2 o, bool gaussian) {
  vec2 q = o / max(b0.zw, vec2(1e-3));
  float t2 = dot(q, q);
  float alpha;
  if (gaussian) {
    if (t2 > 25.0) return vec4(0.0);
    alpha = b1.a * exp(-0.5 * t2);
  } else {
    if (t2 >= 1.0) return vec4(0.0);
    float t = sqrt(t2);
    if (t < b2.x) {
      alpha = mix(b1.a, b2.y, t / max(b2.x, 1e-5));
    } else if (t < b2.z) {
      alpha = mix(b2.y, b2.w, (t - b2.x) / max(b2.z - b2.x, 1e-5));
    } else {
      alpha = mix(b2.w, 0.0, (t - b2.z) / max(1.0 - b2.z, 1e-5));
    }
  }
  return vec4(b1.rgb * alpha, alpha);
}

// The offset from a blob centre [c] to the shaded point [p]: planar, or in
// path space (arc length along the outline, depth inward) wrapped around the
// perimeter.
vec2 blobOffset(vec2 p, vec2 c, bool path) {
  vec2 o = p - c;
  if (path) {
    float L = max(uPerim.x, 1e-3);
    o.x -= L * floor(o.x / L + 0.5);
  }
  return o;
}

#define BLOB_STACK(ARRAY, SLOTS, COUNT, P, MODE, OUT)                   \
  {                                                                     \
    bool path = MODE > 0.5 && (MODE < 1.5 || MODE > 2.5);               \
    bool gauss = MODE > 1.5;                                            \
    for (int i = 0; i < SLOTS; i++) {                                   \
      if (float(i) >= COUNT) break;                                     \
      vec4 b0 = ARRAY[i * 3];                                           \
      OUT = srcOver(                                                    \
          blob(b0, ARRAY[i * 3 + 1], ARRAY[i * 3 + 2], blobOffset(P, b0.xy, path), gauss), \
          OUT);                                                         \
    }                                                                   \
  }

// The visible track. Its ends soften with [spread] (px from the stroke), so a
// glow fades out toward the end of the track instead of stopping at a line.
// A track of a whole turn (a segment whose ends meet) has no ends to soften.
float segmentMask(float u, float spread) {
  if (uMask.y > 0.0 && uMask.y < 1.0) {
    float x = fract(u - uMask.x);
    if (x > uMask.y) return 0.0;
    float fe = max(uMask.z + spread / uPerim.x, 1e-5);
    return smoothstep(0.0, fe, x) * smoothstep(0.0, fe, uMask.y - x);
  }
  return 1.0;
}

// Dashes cover 60% of each period, softened the further light is from the
// stroke.
float dashMask(float u, float px, float spread) {
  if (uMask.w < 2.0) return 1.0;
  float t = abs(fract(u * uMask.w + 0.2) - 0.5); // distance from dash centre
  float aa = max((1.5 * px + spread) * uMask.w / uPerim.x, 1e-4);
  return 1.0 - smoothstep(0.3 - 0.5 * aa, 0.3 + 0.5 * aa, t);
}

// Everything about a layer except its colour: geometry, window, edge fade.
float layerMask(vec4 h0, vec4 h1, vec4 h2, vec4 h3, vec2 pos, vec2 pathP, float d,
                float tw, float px, vec4 winA, vec4 winB) {
  float kind = h0.x;
  if (kind < 0.5 || h0.w <= 0.0) return 0.0;
  float w = uShape.z;
  float inside = clamp(0.5 - d / px, 0.0, 1.0);
  float m;
  if (kind < 1.5) {
    // The hairline ring, just inside the outline.
    float c = d + 0.5 * w;
    m = clamp((0.5 * w - abs(c)) / px + 0.5, 0.0, 1.0);
  } else if (kind < 2.5) {
    m = inside;
  } else if (kind < 3.5) {
    // A blurred ring, clipped to the shape: the 1px band convolved with a
    // gaussian is the band's width times the normal density across it.
    float sigma = max(h0.y, 1e-3);
    float c = (d + 0.5 * w) / sigma;
    m = w / sigma * INV_SQRT_TAU * exp(-0.5 * c * c) * inside;
  } else {
    // A glow outside the outline that fades out: the shape grown by
    // [inflate] and blurred by [sigma].
    float sigma = max(h0.y, 1e-3);
    m = phi((h0.z - d) / sigma) * (1.0 - inside);
  }
  if (m <= 0.0) return 0.0;

  bool path = h3.z > 0.5 && (h3.z < 1.5 || h3.z > 2.5);
  // Edge fade: opaque at the outline, transparent [h1.x] px in. Planar
  // layers fade from each side of the box (the two directions screened);
  // path-space layers fade by depth.
  if (h1.x > 0.0) {
    float e;
    if (path) {
      e = clamp(1.0 + d / h1.x, 0.0, 1.0);
    } else {
      vec2 rel = pos - uRect.xy;
      vec2 near = min(rel, uRect.zw - rel);
      vec2 f = clamp(1.0 - near / h1.x, 0.0, 1.0);
      e = f.x + f.y - f.x * f.y;
    }
    m *= e;
  }

  float win = h1.y;
  if (win > 0.5) {
    if (win < 1.5) {
      m *= winA.x;
    } else if (win < 2.5) {
      m *= winB.x;
    } else {
      // Radial ellipse window: 1 at the centre, mid alpha at the mid stop,
      // 0 at the rim.
      vec2 o = blobOffset(path ? pathP : pos, h2.xy, path);
      float t = length(o / max(h2.zw, vec2(1e-3)));
      float r;
      if (t >= 1.0) {
        r = 0.0;
      } else if (t < h3.x) {
        r = mix(1.0, h3.y, t / max(h3.x, 1e-5));
      } else {
        r = mix(h3.y, 0.0, (t - h3.x) / max(1.0 - h3.x, 1e-5));
      }
      m *= r;
    }
  }
  return m;
}

// A layer's overlay, at the bottom of its stack.
vec4 overlay(vec4 h1, vec4 overA, vec4 overB) {
  if (h1.z > 0.5) {
    float a = h1.z < 1.5 ? overA.x : overB.x;
    return vec4(vec3(h1.w) * a, a);
  }
  return vec4(0.0);
}

// A layer's shadow over its overlay and blobs, then its matrix.
vec4 finishLayer(vec4 acc, vec4 h4, vec4 h5, vec4 h6, vec4 h7, vec4 h8, float d) {
  if (h4.a > 0.0) {
    // Inset shadow: solid to [h5.x] px in, blurred by [h5.y].
    float a = h4.a * phi((h5.x + d) / max(h5.y, 1e-3));
    acc = srcOver(vec4(h4.rgb * a, a), acc);
  }
  if (acc.a > 1e-4) {
    vec3 rgb = acc.rgb / acc.a;
    rgb = clamp(vec3(dot(h6.xyz, rgb), dot(h7.xyz, rgb), dot(h8.xyz, rgb)), 0.0, 1.0);
    acc = vec4(rgb * acc.a, acc.a);
  } else {
    acc = vec4(0.0);
  }
  return acc;
}

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 b = uRect.zw * 0.5;
  vec2 centre = uRect.xy + b;
  vec2 p = pos - centre;
  float px = uShape.w;

  vec4 o = outline(p, b);
  float d = o.x;
  float L = max(uPerim.x, 1e-3);
  float u = fract(o.y / L);
  vec2 pathP = vec2(o.y, -d);

  // Conic coordinate around the conic centre: 0 at 12 o'clock, clockwise.
  vec2 cd = pos - uConic.xy;
  float ct = fract(atan(cd.x, -cd.y) / TAU + 1.0);
  float tw = fract(ct - uConic.z);
  if (uConic.w > 1.5) tw = fract(tw * uConic.w);

  float spread = abs(d + 0.5 * uShape.z);
  float seg = segmentMask(u, spread);
  if (seg <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  float dash = dashMask(u, px, spread);

  float wa;
  float wb;
  float oa;
  float ob;
  TABLE_LOOKUP(uWinA, tw, wa)
  TABLE_LOOKUP(uWinB, tw, wb)
  TABLE_LOOKUP(uOverA, tw, oa)
  TABLE_LOOKUP(uOverB, tw, ob)
  vec4 winA = vec4(wa);
  vec4 winB = vec4(wb);
  vec4 overA = vec4(oa);
  vec4 overB = vec4(ob);

  vec4 colour = vec4(0.0);

  // ── Layer 0 ──
  {
    float m = layerMask(uLayer[0], uLayer[1], uLayer[2], uLayer[3], pos, pathP, d, tw, px, winA, winB);
    if (m > 0.0) {
      vec4 acc = overlay(uLayer[1], overA, overB);
      vec2 bp = uLayer[3].z > 0.5 && (uLayer[3].z < 1.5 || uLayer[3].z > 2.5) ? pathP : pos;
      BLOB_STACK(uBlobA, 14, uLayer[3].w, bp, uLayer[3].z, acc)
      acc = finishLayer(acc, uLayer[4], uLayer[5], uLayer[6], uLayer[7], uLayer[8], d);
      if (uLayer[5].z > 0.5) m *= dash;
      colour = srcOver(acc * (m * min(uLayer[0].w, 1.0)), colour);
    }
  }

  // ── Layer 1 ──
  {
    float m = layerMask(uLayer[9], uLayer[10], uLayer[11], uLayer[12], pos, pathP, d, tw, px, winA, winB);
    if (m > 0.0) {
      vec4 acc = overlay(uLayer[10], overA, overB);
      vec2 bp = uLayer[12].z > 0.5 && (uLayer[12].z < 1.5 || uLayer[12].z > 2.5) ? pathP : pos;
      BLOB_STACK(uBlobB, 10, uLayer[12].w, bp, uLayer[12].z, acc)
      acc = finishLayer(acc, uLayer[13], uLayer[14], uLayer[15], uLayer[16], uLayer[17], d);
      if (uLayer[14].z > 0.5) m *= dash;
      colour = srcOver(acc * (m * min(uLayer[9].w, 1.0)), colour);
    }
  }

  // ── Layer 2 ──
  {
    float m = layerMask(uLayer[18], uLayer[19], uLayer[20], uLayer[21], pos, pathP, d, tw, px, winA, winB);
    if (m > 0.0) {
      vec4 acc = overlay(uLayer[19], overA, overB);
      // A blurred ring samples its colour where the ring is, not where the
      // light spread to.
      vec2 ringPoint = pos - o.zw * d;
      vec2 bp = uLayer[21].z > 0.5 && (uLayer[21].z < 1.5 || uLayer[21].z > 2.5)
          ? pathP
          : (uLayer[18].x > 2.5 && uLayer[18].x < 3.5 ? ringPoint : pos);
      BLOB_STACK(uBlobC, 10, uLayer[21].w, bp, uLayer[21].z, acc)
      acc = finishLayer(acc, uLayer[22], uLayer[23], uLayer[24], uLayer[25], uLayer[26], d);
      if (uLayer[23].z > 0.5) m *= dash;
      colour = srcOver(acc * (m * min(uLayer[18].w, 1.0)), colour);
    }
  }

  colour *= seg;
  if (colour.a <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  // Interleaved-gradient dither on the soft tails, so 8-bit targets don't band.
  if (uPerim.z > 0.0 && colour.a > 0.004) {
    vec2 dev = pos / px;
    float ign = fract(52.9829189 * fract(dot(dev, vec2(0.06711056, 0.00583715))));
    float a = clamp(colour.a + (ign - 0.5) / 255.0, 0.0, 1.0);
    colour *= a / colour.a;
  }
  fragColor = colour;
}
