// The distortion wave's colour, in two parts.
//
// The band rides the front: the palette flowing along it, with a warm fringe
// ahead, a cool one behind and a near-white core between them. Every edge of
// it is wide and feathered, with no line anywhere.
//
// The rim is what the band leaves on the view's edges: colour clinging to
// them in uneven, drifting lumps after the middle has cleared, with a
// hairline on the glass over it, until two later fronts wipe them away.
//
// Colours arrive in OKLab and are mixed in OKLab, so neighbours never pass
// through grey. Reads the uniforms in wave_uniforms.glsl; needs outline.glsl
// and wave_field.glsl included first.

#ifndef PRISMATIC_WAVE_COLOUR_GLSL
#define PRISMATIC_WAVE_COLOUR_GLSL

const float WAVE_TAU = 6.283185307;

float waveSq(float x) {
  return x * x;
}

vec3 oklabToSrgb(vec3 c) {
  float l = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z;
  float m = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z;
  float s = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z;
  l = l * l * l;
  m = m * m * m;
  s = s * s * s;
  vec3 lin = clamp(vec3(
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
  ), 0.0, 1.0);
  return mix(12.92 * lin, 1.055 * pow(lin, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), lin));
}

// One colour from the ring of palette colours at u (wrapping), mixed so
// neighbours ease into each other. Loops over every slot so the arrays are
// indexed by the loop index only.
vec3 wavePaletteAt(float u) {
  float count = uHair.w;
  float x = fract(u) * count;
  float i = min(floor(x), count - 1.0);
  float j = mod(i + 1.0, count);
  float m = fract(x);
  m = m * m * (3.0 - 2.0 * m);
  vec3 a = uStops[0].xyz;
  vec3 b = uStops[0].xyz;
  for (int k = 0; k < 8; k++) {
    float fk = float(k);
    if (fk == i) a = uStops[k].xyz;
    if (fk == j) b = uStops[k].xyz;
  }
  return mix(a, b, m);
}

// How thick the colour on the edges is at s along a perimeter of P, as a
// share of the rim's width: drifting lumps of their own length and depth
// with thin stretches between them. Averages 1. The lumps are worked out
// once a frame on the CPU (WaveRim).
float waveRimThickness(float s, float P) {
  float t = 0.08;
  for (int i = 0; i < 7; i++) {
    vec4 lump = uLumps[i];
    float ds = s - lump.x;
    ds -= P * floor(ds / P + 0.5);
    t += lump.z * exp(-waveSq(ds / lump.y));
  }
  return t / 1.0498;
}

// The view's outline at p: signed distance, arc length, normal.
vec4 waveOutline(vec2 p) {
  vec2 hs = uRect.zw * 0.5;
  return outline(p - hs, hs, vec4(uBand.w), true, uQuads, uView.z);
}

// Whether p is close enough to the edges for the rim or the hairline to
// reach it. Further in than this even the thickest lump has faded to
// nothing, and the hairline is far behind.
bool waveNearEdge(float inset) {
  return uFront2.w > 0.0 &&
      inset < max(uRim.x * 2.2 * (1.0 + 1.9 * uRim.z), uHair.x * 0.5 + 0.75);
}

// Whether any colour can reach p, from the field alone and a lower bound on
// the inset: the outline contains the box with its corners cut off where the
// straight edges end, so the inset is at least the distance to that octagon.
// False only where waveGlowWith would return nothing.
bool waveColourReaches(vec2 p, float d) {
  if (uFront2.z > 0.0 && d < uBand.x && d > -1.3 * uBand.y - 0.01) return true;
  if (uFront2.w <= 0.0) return false;
  vec2 hs = uRect.zw * 0.5;
  vec2 e = hs - abs(p - hs);
  vec2 cut = min(vec2(SQUIRCLE_REACH * uBand.w), hs);
  float chamfer = (e.x * cut.y + e.y * cut.x - cut.x * cut.y) * inversesqrt(max(dot(cut, cut), 1e-6));
  float lower = min(min(e.x, e.y), chamfer);
  return lower < max(uRim.x * 2.2 * (1.0 + 1.9 * uRim.z), uHair.x * 0.5 + 0.75);
}

// The premultiplied colour of the band, the rim and the hairline at p, given
// the field there (d, q, g) and the view's outline there (o).
// How thick the rim is at arc length s, as a share of its width.
float waveRimThicknessAt(float s) {
  if (uRim.z <= 0.0) return 1.0;
  // Past 1 the lumps are pushed further still, and the thinnest stretches
  // break off altogether.
  return max(1.0 + (waveRimThickness(s, uView.z) - 1.0) * uRim.z, 0.04);
}

// Whether, with the band gone, the rim has faded to nothing this far in and
// the hairline is behind: exp(-2.76^2) is under the 0.0005 that is dropped.
bool waveRimFaded(float inset, float thickness) {
  return uFront2.z <= 0.0 && inset >= uRim.x * thickness * 2.76 &&
      inset >= uHair.x * 0.5 + 0.75;
}

vec4 waveGlowCore(vec2 p, vec4 o, float thickness, float d, vec2 q, float g) {
  float glow = uFront2.z;
  float rim = uFront2.w;
  float time = uFront1.y;
  float lead = uBand.x;
  float inset = max(-o.x, 0.0);
  bool nearEdge = waveNearEdge(inset);
  if (glow <= 0.0 && !nearEdge) return vec4(0.0);

  // The tail swells and thins along the front, like a voice glow's lobes,
  // and is lighter in the middle of the view, which it clears first.
  bool ring = waveIsRing();
  float turn = 0.0;
  if (ring && abs(q.x) + abs(q.y) > 0.0) turn = atan(q.y, q.x);
  float along = q.x * 0.0068;
  float bandA = 0.0;
  if (glow > 0.0 && d < lead) {
    if (d >= 0.0) {
      float k = 1.0 - d / lead;
      bandA = k * k * k * (k * (k * 6.0 - 15.0) + 10.0);
    } else {
      float lobes = ring
          ? 0.5 + 0.5 * sin(2.0 * turn + time * 1.4) * cos(turn - time * 0.7 + 1.2)
          : 0.5 + 0.5 * sin(along * 1.3 + time * 1.4) * cos(along * 0.6 - time * 0.7 + 1.2);
      bandA = pow(1.0 - clamp(-d / (uBand.y * mix(0.6, 1.3, lobes)), 0.0, 1.0), 2.3);
    }
    bandA *= glow * uBand.z * mix(0.6, 1.0, exp(-inset / 140.0)) * waveHeldAt(p);
  }

  // Around the view: normalised, so the long sides get their share of colour.
  float rimA = 0.0;
  float hairA = 0.0;
  float shimmer = 0.5;
  float pulse = uRim.w;
  if (nearEdge) {
    float perimeter = uView.z;
    float hug = exp(-waveSq(inset / (uRim.x * thickness)));
    float reached = 1.0 - smoothstep(-lead * 0.7, lead * 0.5, d);
    float kept = smoothstep(-uRim.y, uRim.y, d + (uFront0.w - uFront3.x) / g);
    // Two soft swells of brightness running round the edge.
    shimmer = 0.5 + 0.5 * sin(time * 3.4 - o.y / perimeter * 2.0 * WAVE_TAU);
    rimA = hug * reached * kept * rim * mix(1.0, 0.7 + 0.3 * shimmer, pulse);

    // A hairline right on the glass, all the way round, brightest where the
    // lumps are and where the pulse's light runs. Wiped by a front of its
    // own, later and slower than the colour's, so it outlasts the colour.
    float hairWidth = uHair.x;
    if (hairWidth > 0.0) {
      float line = 1.0 - smoothstep(hairWidth * 0.5, hairWidth * 0.5 + 0.75, inset);
      float hairKept = smoothstep(-uRim.y, uRim.y, d + (uFront0.w - uFront3.y) / g);
      hairA = line * reached * hairKept * rim * uHair.y
          * mix(0.5, 1.0, smoothstep(0.1, 1.5, thickness))
          * mix(1.0, 0.55 + 0.45 * shimmer, pulse);
    }
  }

  float a = 1.0 - (1.0 - bandA) * (1.0 - rimA);
  float total = 1.0 - (1.0 - a) * (1.0 - hairA);
  if (total <= 0.0005) return vec4(0.0);

  // Round a ring, the palette goes once round with it.
  float flow = 0.62 + (ring ? turn / WAVE_TAU : along * 0.2) + time * 0.13 + d * 0.0015
      + (ring ? 0.0 : 0.05 * sin(q.y * 0.009 + time));
  vec3 lab = wavePaletteAt(flow);
  lab = mix(lab, uFringe[0].xyz, 0.5 * exp(-waveSq((d - 30.0) / 50.0)));
  lab = mix(lab, uFringe[1].xyz, 0.5 * exp(-waveSq((d + 84.0) / 72.0)));
  lab.yz *= 1.22;
  lab = mix(lab, vec3(0.99, 0.0, 0.0), 0.7 * exp(-waveSq((d + 8.0) / 26.0)));

  // Once around the rim: `around` jumps by a whole turn, which fract hides.
  vec3 rimLab = vec3(0.0);
  if (rimA > 0.0 || hairA > 0.0) {
    vec2 c = p - uRect.zw * 0.5;
    float around = atan(c.y / uRect.w, c.x / uRect.z);
    rimLab = wavePaletteAt(around / WAVE_TAU + time * (0.12 + 0.25 * pulse) + inset * 0.0012);
    rimLab.yz *= 1.1;
    lab = mix(lab, rimLab, rimA / (rimA + bandA + 1e-4));
  }

  // The hairline over the glow: the edge's own colour, whitening where the
  // pulse's light passes.
  vec3 rgb = oklabToSrgb(lab);
  if (hairA > 0.0) {
    vec3 hair = mix(oklabToSrgb(rimLab), vec3(1.0), uHair.z * (0.5 + 0.5 * shimmer));
    rgb = (rgb * a * (1.0 - hairA) + hair * hairA) / total;
  }
  return vec4(clamp(rgb, 0.0, 1.0) * total, total);
}

vec4 waveGlowWith(vec2 p, vec4 o, float d, vec2 q, float g) {
  float thickness = 1.0;
  if (waveNearEdge(max(-o.x, 0.0))) thickness = waveRimThicknessAt(o.y);
  return waveGlowCore(p, o, thickness, d, q, g);
}

// Interleaved gradient noise, ±0.5: enough to hide banding, not enough to see.
float waveDither(vec2 devicePx) {
  return fract(52.9829189 * fract(dot(devicePx, vec2(0.06711056, 0.00583715)))) - 0.5;
}

// Dithers a premultiplied colour by a step of one 8-bit level, where lit.
vec4 waveDithered(vec4 c, vec2 pos) {
  if (uView.y < 0.5 || c.a <= 0.0) return c;
  float noise = waveDither(pos / uView.x) * 2.0 / 255.0;
  return clamp(c + vec4(vec3(noise), noise), 0.0, 1.0);
}

#endif
