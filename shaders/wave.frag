// DistortionWave — the whole transition in one fragment shader.
//
// Per pixel, in one pass over the stage:
//
//   1. the field: the signed distance d to the wave's front (wave_field.glsl);
//   2. the lens: content rises once as the swell passes and settles back,
//      and before the launch everything is pulled toward the source;
//   3. the progressive blur: blur gathers ahead of the front, peaks on it and
//      clears slowly behind, as a mix of the sharp side and two blurred
//      copies of it baked once per snapshot (near, then far);
//   4. the crossfade: the outgoing side covers the incoming one ahead of the
//      front, with a soft zone either side of it;
//   5. colour fringing: the colours part along the way a pixel has been
//      moved, in proportion to how far, over five taps across the spectrum —
//      so it shows exactly where content is distorted, and anything unmoved
//      stays perfectly clean;
//   6. the colour over all of it: the band on the front, the rim and the
//      hairline on the edges (wave_colour.glsl).
//
// Each side arrives as three images of the same size as the stage: sharp,
// near-blurred and far-blurred. One draw, no offscreen passes, no filters.

#version 460 core

#include <flutter/runtime_effect.glsl>
#include "common/wave_uniforms.glsl"

uniform sampler2D uOutSharp; // the side the wave leaves behind
uniform sampler2D uOutNear;
uniform sampler2D uOutFar;
uniform sampler2D uInSharp;  // the side it reveals
uniform sampler2D uInNear;
uniform sampler2D uInFar;

out vec4 fragColor;

#include "common/outline.glsl"
#include "common/wave_field.glsl"
#include "common/wave_colour.glsl"

// How much of the blurred copy covers the sharp side at a blur radius r, for
// a copy that takes over from radius `from` to radius `to`.
float waveCoverage(float r, float from, float to) {
  float t = clamp((r - from) / max(to - from, 1e-3), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// One side at UV, with its blur level mixed in.
#define WAVE_SIDE(SHARP, NEAR, FAR, UV, TN, TF, OUT)                         \
  OUT = texture(SHARP, UV);                                                \
  if (TN > 0.0) OUT = mix(OUT, texture(NEAR, UV), TN);                     \
  if (TF > 0.0) OUT = mix(OUT, texture(FAR, UV), TF);

// Both sides at UV, crossfaded.
#define WAVE_CONTENT(UV, OUT)                                                \
  {                                                                         \
    vec4 outC = vec4(0.0);                                                  \
    vec4 inC = vec4(0.0);                                                   \
    if (useOut) { WAVE_SIDE(uOutSharp, uOutNear, uOutFar, UV, tn, tf, outC) } \
    if (useIn) { WAVE_SIDE(uInSharp, uInNear, uInFar, UV, tn, tf, inC) }      \
    OUT = outC * cover + inC * (1.0 - cover);                               \
  }

// One tap of the colour fringing: the content at S + SPLIT * ALONG, weighed
// into the channels by W (red end to blue end).
#define WAVE_TAP(ALONG, W)                                                   \
  {                                                                         \
    vec2 uv = clamp(s + split * ALONG, lo, hi) / size;                      \
    vec4 c;                                                                 \
    WAVE_CONTENT(uv, c)                                                     \
    col += vec4(c.rgb * W, c.a * 0.2);                                      \
  }

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 p = pos - uRect.xy;
  vec2 size = uRect.zw;

  vec2 q;
  float g;
  vec3 w = waveField(p, q, g);
  float d = w.x;
  vec2 n = w.yz;
  float energy = uFront2.x;
  float gravity = uFront2.y;

  // Ahead of the zone the outgoing side covers the incoming one completely;
  // before the launch the incoming side is not drawn at all; once the front
  // has crossed, nothing of the outgoing side is.
  bool launched = uFront4.x > 0.5;
  float cover = uFront4.y > 0.5
      ? (launched ? smoothstep(-COVER_ZONE, COVER_ZONE, d) : 1.0)
      : 0.0;
  bool useOut = cover > 0.0;
  bool useIn = uFront4.z > 0.5 && cover < 1.0 && d < COVER_ZONE + 6.0;

  // Content rises once as the swell passes and settles back: one smooth
  // pulse per pixel, never a reversal. Steeper ahead, where it compresses
  // what it is about to reach; long behind.
  float u = d / (uLens.y * (d > 0.0 ? 0.85 : 1.5));
  float lift = exp(-u * u);
  vec2 raw = p - uFront0.xy;
  float r = max(length(raw), 1.0);
  float held = waveHeldAt(p);

  // How far the content shown here has been moved. Gravity moves the whole
  // stage, but far from the source it only slides content along: it bends
  // it near the source, so only there does it count toward the fringing.
  vec2 swollen = n * energy * uLens.x * lift * held;
  vec2 inward = raw / r;
  vec2 s = p - swollen + inward * gravity * exp(-r / 900.0) * held;
  vec2 split = (swollen - inward * gravity * exp(-r / 240.0) * held) * uLens.z;

  // The blur the content shown here has: the field moved with the content
  // (to first order), so the blur stays on what the swell carries.
  float ds = d + dot(n, s - p);
  float bu = ds / (ds > 0.0 ? uBlur.x : uBlur.y);
  float radius = energy * uLens.w * exp(-bu * bu) * held;
  float tn = waveCoverage(radius, 0.0, uBlur.z);
  float tf = waveCoverage(radius, uBlur.z, uBlur.w);

  vec2 lo = vec2(0.5);
  vec2 hi = size - 0.5;
  vec4 col = vec4(0.0);
  if (dot(split, split) < 0.0625) {
    // Under a quarter of a point the colours can't be seen apart.
    vec2 uv = clamp(s, lo, hi) / size;
    WAVE_CONTENT(uv, col)
  } else {
    WAVE_TAP(-1.0, vec3(0.571, 0.000, 0.000))
    WAVE_TAP(-0.5, vec3(0.343, 0.206, 0.000))
    WAVE_TAP(0.0, vec3(0.086, 0.588, 0.086))
    WAVE_TAP(0.5, vec3(0.000, 0.206, 0.343))
    WAVE_TAP(1.0, vec3(0.000, 0.000, 0.571))
  }

  vec4 glow = waveDithered(waveGlowWith(p, waveOutline(p), d, q, g), pos);
  fragColor = glow + col * (1.0 - glow.a);
}
