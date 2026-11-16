// The distortion wave's field: one signed distance to its front, which every
// part of the wave reads — the swell, the blur and the colour — so they can
// never drift apart, none of them having a position of its own.
//
//   d > 0  the wave has not got here yet
//   d = 0  the front
//   d < 0  the wave has passed
//
// The front is an offset of a pill: a straight spine centred on the origin,
// turned by the tilt, its x axis squashed so the front bows. It starts as the
// source's own outline and opens into an arc as the spine shrinks to nothing
// while the radius grows. A ring has no spine and no squash. The Dart side
// (lib/src/distortion_wave/timeline/wave_frame.dart) moves all of it.
//
// Reads the uniforms in wave_uniforms.glsl.

#ifndef PRISMATIC_WAVE_FIELD_GLSL
#define PRISMATIC_WAVE_FIELD_GLSL

// Half the zone over which the two sides crossfade, pt (waveCoverZone).
const float COVER_ZONE = 60.0;

bool waveIsRing() {
  return uFront3.z > 0.5;
}

// How much of the wave acts at p: 0 on a held source (the center wave's
// avatar), 1 well clear of it.
float waveHeldAt(vec2 p) {
  float hold = uFront3.w;
  if (hold <= 0.0) return 1.0;
  return smoothstep(hold * 0.9, hold * 1.8, length(p - uFront0.xy));
}

// The field at p (stage pt): signed distance to the front, and the outward
// normal on screen. Also returns q, the position in the wave's own frame,
// and g, how fast the raw distance grows (which d has been divided by).
vec3 waveField(vec2 p, out vec2 q, out float g) {
  vec2 raw = p - uFront0.xy;
  float cs = cos(uFront1.w);
  float sn = sin(uFront1.w);
  q = vec2(cs * raw.x + sn * raw.y, -sn * raw.x + cs * raw.y);
  float spine = uFront0.z;
  float squash = uFront1.x;
  float time = uFront1.y;

  // A narrower x metric bows the front: wider than a circle would be, it
  // would otherwise cross a phone screen as a nearly flat line.
  float mx = q.x * squash;
  vec2 v = vec2(max(abs(mx) - spine, 0.0), q.y);
  float len = length(v);
  float l = max(len, 1e-3);
  // On the spine itself the gradient has no direction: take the frame's
  // vertical, so the distance there stays -radius rather than blowing up.
  vec2 grad = len > 1e-3 ? vec2(v.x * sign(q.x) * squash, v.y) / l : vec2(0.0, 1.0);
  g = max(length(grad), 1e-3);

  // A slow bend along the front, so the wave never looks drawn with a
  // compass. Low frequencies only: anything quicker reads as a wobble.
  float bend;
  if (waveIsRing()) {
    // atan(0, 0) is undefined (NaN on some drivers): the ring's centre.
    float a = abs(q.x) + abs(q.y) > 0.0 ? atan(q.y, q.x) : 0.0;
    bend = 0.62 * sin(2.0 * a + time * 1.1) + 0.38 * sin(3.0 * a - time * 1.5 + 1.7);
  } else {
    float s = mx * 0.0058;
    bend = 0.62 * sin(s + time * 1.1) + 0.38 * sin(s * 2.1 - time * 1.5 + 1.7);
  }

  vec2 n = grad / g;
  float d = (l - uFront0.w) / g + uFront1.z * bend;
  return vec3(d, cs * n.x - sn * n.y, sn * n.x + cs * n.y);
}

#endif
