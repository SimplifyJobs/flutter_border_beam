// flutter_border_beam — the whole effect in one fragment shader.
//
// Light is emitted along the outline of a rounded rectangle (circular or
// superellipse corners). Each pixel derives, analytically:
//
//   d — signed distance to the outline in logical px (negative inside),
//   u — perimeter position in [0, 1): 0 at top-centre, growing clockwise.
//
// Two light sources are summed:
//
//   1. Border light — palette(u) × emission(u) × profile(d): the crisp stroke,
//      a gaussian bloom hugging it, and an outer halo. `u` is continuous on
//      and outside the outline, so this has no seams.
//   2. Point lights — up to 8 anisotropic gaussians anchored on the border in
//      their own tangent/normal frame, for every glow that reaches inside.
//      (A nearest-point `u` jumps across the medial axis inside the shape, so
//      inner glows never read it.)
//
// No offscreen passes, blurs, or clips: one draw, and the cost is a few dozen
// ALU ops per covered pixel.
//
// Uniforms are vec4s and vec4 arrays only, so the float layout is identical on
// every backend (Impeller Metal / Vulkan / GLES, and Skia's SkSL). The Dart
// packer in lib/src/render/beam_uniforms.dart mirrors this order exactly.

#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec4 uRect;      // outline box: left, top, width, height
uniform vec4 uRadii;     // corner radii: top-left, top-right, bottom-right, bottom-left
uniform vec4 uShape;     // x corner inset k, y corner exponent n, z stroke width, w px per device px
uniform vec4 uPerim;     // x perimeter length, y corner arc factor, z bloom side, w dither on/off
uniform vec4 uQuads;     // arc length where each quadrant starts: TR, BR, BL, TL
uniform vec4 uLayers;    // alpha of: x stroke, y bloom, z outer halo, w point lights
uniform vec4 uReach;     // x bloom sigma, y outer reach, z outer plateau, w outer widening
uniform vec4 uHighlight; // rgb highlight colour, a amount
uniform vec4 uEmit;      // x base, y bump count, z opacity, w additive share
uniform vec4 uNoise;     // x amplitude, y frequency (cycles / perimeter), z phase, w light count
uniform vec4 uMask;      // x segment start u, y segment span (0 = all), z feather (u), w dashes
uniform vec4 uColorMap;  // x origin u, y scale, z wrap (1) or clamp (0), w colour count
uniform vec4 uSweep;     // xy direction (unit), z position, w half width
uniform vec4 uSweepAmp;  // x sweep amplitude, yzw unused
uniform vec4 uBumps[8];  // x centre u, y lead width, z tail width, w amplitude
uniform vec4 uColors[8]; // straight RGBA
uniform vec4 uStops[8];  // x stop position (0..1)
uniform vec4 uLightPos[8];   // xy anchor (canvas coords), zw inward unit normal
uniform vec4 uLightShape[8]; // x sigma along the border, y sigma inward, z amplitude, w side
uniform vec4 uLightColor[8]; // rgb colour, a unused

out vec4 fragColor;

const float TAU = 6.283185307;
const float HALF_PI = 1.570796327;

// Distance from a corner-local point q (both components > 0, measured from the
// inner corner of a corner box of size R) to the p-norm corner curve, using the
// first-order correction f / |grad f|. Exact for n = 2; accurate near the curve
// for the superellipse, which is all the stroke needs.
float pnormCornerDistance(vec2 q, float R, float n) {
  vec2 a = max(q / R, vec2(1e-4));
  vec2 an = pow(a, vec2(n));
  float norm = pow(an.x + an.y, 1.0 / n);
  vec2 g = pow(a, vec2(n - 1.0)) / pow(max(norm, 1e-4), n - 1.0);
  return R * (norm - 1.0) / max(length(g), 1e-4);
}

// Returns (signed distance, arc length from top-centre clockwise).
vec2 outline(vec2 p, vec2 b) {
  bool right = p.x > 0.0;
  bool bottom = p.y > 0.0;
  float r = right ? (bottom ? uRadii.z : uRadii.y) : (bottom ? uRadii.w : uRadii.x);
  float R = min(r * uShape.x, min(b.x, b.y));
  float n = R < 0.5 ? 2.0 : uShape.y;
  R = max(R, 1e-3);
  vec2 a = abs(p);
  vec2 q = a - (b - R);

  float legX = b.x - R;
  float arc = R * uPerim.y;
  float d;
  float s; // arc length within the quadrant, starting on the vertical axis
  if (q.x > 0.0 && q.y > 0.0) {
    float circle = length(q) - R;
    if (n == 2.0) {
      d = circle;
    } else {
      // The first-order superellipse distance degrades toward the corner-box
      // centre; deep inside, the circular distance is the better estimate.
      float sq = pnormCornerDistance(q, R, n);
      d = mix(sq, circle, smoothstep(0.25, 0.6, -circle / R));
    }
    s = legX + arc * (atan(q.x, q.y) / HALF_PI);
  } else {
    d = max(q.x, q.y) - R;
    s = q.x > q.y ? legX + arc + (b.y - R - a.y) : a.x;
  }
  // TR and BL run vertical axis → horizontal axis clockwise; BR and TL run the
  // other way, so their local arc length is mirrored.
  float quadLen = legX + arc + (b.y - R);
  float start;
  if (right) {
    start = bottom ? uQuads.y : uQuads.x;
    if (bottom) s = quadLen - s;
  } else {
    start = bottom ? uQuads.z : uQuads.w;
    if (!bottom) s = quadLen - s;
  }
  return vec2(d, start + s);
}

// Wraps a perimeter difference to [-0.5, 0.5).
float wrapDelta(float x) {
  return x - floor(x + 0.5);
}

// Emission along the perimeter. [widen] > 1 spreads every bump (the halo
// spreads along the border as it reaches out, the way a blur does) while
// keeping its energy.
float emission(float u, float widen) {
  float e = uEmit.x;
  for (int i = 0; i < 8; i++) {
    if (float(i) >= uEmit.y) break;
    vec4 bp = uBumps[i];
    float delta = wrapDelta(u - bp.x);
    float width = (delta >= 0.0 ? bp.y : bp.z) * widen;
    float f = max(1.0 - abs(delta) / max(width, 1e-5), 0.0);
    e += bp.w * f * f * (3.0 - 2.0 * f) / widen;
  }
  return e;
}

// Seamless around the ring: every frequency is a whole number of cycles.
float ringNoise(float u) {
  float f = uNoise.y;
  float t = uNoise.z;
  return 0.55 * sin(TAU * (u * f + t))
       + 0.30 * sin(TAU * (u * (2.0 * f + 1.0) - 1.7 * t + 0.31))
       + 0.15 * sin(TAU * (u * (3.0 * f + 2.0) + 2.3 * t + 0.67));
}

float segmentMask(float u) {
  if (uMask.y > 0.0) {
    float x = fract(u - uMask.x);
    if (x > uMask.y) return 0.0;
    float fe = max(uMask.z, 1e-5);
    return smoothstep(0.0, fe, x) * smoothstep(0.0, fe, uMask.y - x);
  }
  return 1.0;
}

float dashMask(float u, float px) {
  if (uMask.w < 2.0) return 1.0;
  float x = fract(u * uMask.w);
  float aa = max(1.5 * px * uMask.w / uPerim.x, 1e-4);
  return smoothstep(0.0, aa, x) * (1.0 - smoothstep(0.6 - aa, 0.6, x));
}

// Gamma-aware mix: interpolating squared (≈ linear) channels keeps the midpoint
// of two saturated stops bright instead of muddy.
vec4 mixColor(vec4 a, vec4 b, float t) {
  vec3 rgb = sqrt(max(mix(a.rgb * a.rgb, b.rgb * b.rgb, t), 0.0));
  return vec4(rgb, mix(a.a, b.a, t));
}

vec4 paletteAt(float cu) {
  float count = uColorMap.w;
  bool wrap = uColorMap.z > 0.5;
  vec4 lastC = uColors[0];
  float lastS = uStops[0].x;
  for (int i = 1; i < 8; i++) {
    if (float(i) >= count) break;
    lastC = uColors[i];
    lastS = uStops[i].x;
  }
  vec4 prevC = wrap ? lastC : uColors[0];
  float prevS = wrap ? lastS - 1.0 : uStops[0].x - 1.0;
  for (int i = 0; i < 8; i++) {
    if (float(i) >= count) break;
    vec4 c = uColors[i];
    float s = uStops[i].x;
    if (cu < s) {
      return mixColor(prevC, c, clamp((cu - prevS) / max(s - prevS, 1e-5), 0.0, 1.0));
    }
    prevC = c;
    prevS = s;
  }
  vec4 nextC = wrap ? uColors[0] : prevC;
  float nextS = wrap ? uStops[0].x + 1.0 : prevS + 1.0;
  return mixColor(prevC, nextC, clamp((cu - prevS) / max(nextS - prevS, 1e-5), 0.0, 1.0));
}

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 b = uRect.zw * 0.5;
  vec2 p = pos - (uRect.xy + b);
  float px = uShape.w;

  vec2 ds = outline(p, b);
  float d = ds.x;
  float u = fract(ds.y / max(uPerim.x, 1e-3));
  float inside = clamp(0.5 - d / px, 0.0, 1.0);
  float outside = 1.0 - inside;

  vec3 premul = vec3(0.0);
  float alpha = 0.0;

  // ── 1. Border light ──
  float mask = segmentMask(u) * dashMask(u, px);
  float shimmer = 0.0;
  if (uSweepAmp.x > 0.0) {
    vec2 rel = p / max(uRect.zw, vec2(1.0));
    float x = dot(rel, uSweep.xy) + 0.5;
    float f = max(1.0 - abs(x - uSweep.z) / max(uSweep.w, 1e-4), 0.0);
    shimmer = uSweepAmp.x * f * f * (3.0 - 2.0 * f);
  }
  float swell = 1.0;
  if (uNoise.x > 0.0) swell = max(1.0 + uNoise.x * ringNoise(u), 0.0);

  float w = uShape.z;
  float centre = d + 0.5 * w;
  float stroke = clamp((0.5 * w - abs(centre)) / px + 0.5, 0.0, 1.0);

  float bloom = 0.0;
  if (uLayers.y > 0.0) {
    float sigma = max(uReach.x, 1e-3);
    bloom = exp(-0.5 * centre * centre / (sigma * sigma));
    float side = uPerim.z; // -1 inside only, +1 outside only, 0 both
    if (side < -0.5) bloom *= inside;
    if (side > 0.5) bloom *= outside;
  }

  float e = (emission(u, 1.0) + shimmer) * mask * swell;
  float near = uLayers.x * stroke + uLayers.y * bloom;
  float borderAlpha = near * e;

  if (uLayers.z > 0.0 && d > -w) {
    float reach = max(uReach.y, 1e-3);
    float x = clamp((max(d, 0.0) - uReach.z) / reach, 0.0, 1.0);
    float widen = 1.0 + uReach.w * x;
    float f = 1.0 - x;
    float halo = f * f * (1.0 + 2.0 * x) * outside;
    borderAlpha += uLayers.z * halo * max(emission(u, widen) + shimmer, 0.0) * mask * swell;
  }

  borderAlpha = max(borderAlpha, 0.0);
  if (borderAlpha > 0.0) {
    float cu = (u - uColorMap.x) * uColorMap.y;
    cu = uColorMap.z > 0.5 ? fract(cu) : clamp(cu, 0.0, 1.0);
    vec4 c = paletteAt(cu);
    float hot = clamp(uHighlight.a * e * e * e * (stroke + 0.5 * bloom), 0.0, 1.0);
    float a = borderAlpha * c.a;
    premul += mix(c.rgb, uHighlight.rgb, hot) * a;
    alpha += a;
  }

  // ── 2. Point lights ──
  if (uLayers.w > 0.0) {
    for (int i = 0; i < 8; i++) {
      if (float(i) >= uNoise.w) break;
      vec4 lp = uLightPos[i];
      vec4 ls = uLightShape[i];
      vec2 rel = pos - lp.xy;
      float across = dot(rel, lp.zw);            // + inward
      float along = dot(rel, vec2(lp.w, -lp.z)); // tangent
      float g = ls.z * exp(-0.5 * (along * along / (ls.x * ls.x) + across * across / (ls.y * ls.y)));
      if (ls.w < -0.5) g *= inside;
      if (ls.w > 0.5) g *= outside;
      float a = uLayers.w * g;
      premul += uLightColor[i].rgb * a;
      alpha += a;
    }
  }

  alpha *= uEmit.z;
  premul *= uEmit.z;
  if (alpha <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  float outA = min(alpha, 1.0);
  vec3 rgb = premul / alpha;

  // Interleaved-gradient dither on the soft tails, so 8-bit targets don't band.
  if (uPerim.w > 0.0 && outA > 0.004) {
    vec2 dev = pos / px;
    float ign = fract(52.9829189 * fract(dot(dev, vec2(0.06711056, 0.00583715))));
    outA = clamp(outA + (ign - 0.5) / 255.0, 0.0, 1.0);
  }
  // Part of the light is added rather than blended: srcOver with the alpha
  // channel scaled down by the additive share brightens what's underneath
  // instead of covering it (glows over dark surfaces).
  fragColor = vec4(rgb * outA, outA * (1.0 - uEmit.w));
}
