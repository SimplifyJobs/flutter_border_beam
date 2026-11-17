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
  return outline(p - hs, hs, uRadii, true, uQuads, uView.z);
}

// Whether p is close enough to the edges for the rim or the hairline to
// reach it. Further in than this even the thickest lump has faded to
// nothing, and the hairline is far behind.
// How wide the crease where two edges meet is rounded, in rim widths.
const float CORNER_POOL = 2.5;

// How much nearer the rim's own depth can be than the outline's distance:
// the easing on a corner's diagonal, and the small gap between a circular
// corner and Flutter's rounded superellipse of the same radius (see
// waveRimInset).
float wavePoolSlack() {
  float k = CORNER_POOL * uRim.x;
  return 0.25 * k + 0.1 * uBand.w;
}

// A smooth minimum: the smaller of a and b, eased where they are within k.
float waveSmin(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

// How deep in from the edges the rim's colour is measured: along each
// corner's own radius, as the hairline is — a display whose corners differ
// (8 pt on one side of a phone and 59 pt on the other) has light that
// follows each of them. Up to that radius the depth is the distance to the
// corner's arc. Deeper in, the distance to the outline would crease along
// the corner's diagonal, where the nearest edge changes, and the colour's
// inner edge would turn there along a mitre; so there the distances to the
// two edges meeting at the corner are eased into each other, and the inner
// edge turns smoothly.
float waveRimInset(vec2 p, float inset) {
  vec2 hs = uRect.zw * 0.5;
  vec2 c = p - hs;
  float k = CORNER_POOL * uRim.x;
  float r = c.x > 0.0 ? (c.y > 0.0 ? uRadii.z : uRadii.y)
                      : (c.y > 0.0 ? uRadii.w : uRadii.x);
  float rho = min(r, min(hs.x, hs.y));
  vec2 q = abs(c) - hs + rho;
  float sd = length(max(q, 0.0)) + min(-waveSmin(-q.x, -q.y, k), 0.0) - rho;
  return min(inset, max(-sd, 0.0));
}

bool waveNearEdge(float inset) {
  return uFront2.w > 0.0 &&
      inset - wavePoolSlack() <
          max(uRim.x * 2.2 * (1.0 + 1.9 * uRim.z), uHair.x * 0.5 + 0.75);
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
  return lower - wavePoolSlack() <
      max(uRim.x * 2.2 * (1.0 + 1.9 * uRim.z), uHair.x * 0.5 + 0.75);
}

// The premultiplied colour of the band, the rim and the hairline at p, given
// the field there (d, q, g) and the view's outline there (o).
// How thick the rim is at arc length s, as a share of its width.
// Where p is along the view's edge, as a fraction of the way round,
// clockwise from the top centre — continuous everywhere the rim can reach.
//
// The arc length of the nearest point of the outline is not: inside a corner
// the nearest point flips from one edge to the other across the corner's
// diagonal, and with a sharp corner that flip runs right through the lit
// rim as a line. So the rim is placed on a box whose corners are circular
// with a radius at least as deep as the rim reaches: inside a corner a point
// goes by its angle round that arc, and the flip between two edges happens
// only deeper than any colour.
float waveEdgeAt(vec2 p) {
  vec2 hs = uRect.zw * 0.5;
  vec2 a = abs(p - hs);
  float reach = uRim.x * 2.2 * (1.0 + 1.9 * uRim.z);
  float rho = min(max(reach, uBand.w), min(hs.x, hs.y));
  float ex = hs.x - rho;
  float ey = hs.y - rho;
  float arc = OUTLINE_HALF_PI * rho;
  float quarter = ex + arc + ey;
  // Within the quarter: along the horizontal edge from its centre, round
  // the corner, then along the vertical edge to its centre.
  float s;
  if (a.x > ex && a.y > ey) {
    vec2 v = a - vec2(ex, ey);
    s = ex + rho * (OUTLINE_HALF_PI - atan(v.y, max(v.x, 1e-4)));
  } else if (a.x - ex > a.y - ey) {
    s = ex + arc + (ey - a.y);
  } else {
    s = a.x;
  }
  vec2 c = p - hs;
  // Clockwise from the top centre: TR, BR, BL, TL.
  if (c.x >= 0.0) {
    s = c.y < 0.0 ? s : 2.0 * quarter - s;
  } else {
    s = c.y >= 0.0 ? 2.0 * quarter + s : 4.0 * quarter - s;
  }
  return s / (4.0 * quarter);
}

float waveRimThicknessAt(float s) {
  if (uRim.z <= 0.0) return 1.0;
  // Past 1 the lumps are pushed further still, and the thinnest stretches
  // break off altogether.
  return max(1.0 + (waveRimThickness(s, uView.z) - 1.0) * uRim.z, 0.04);
}

// How much of the rim's colour reaches p, 0–1, for a rim [thickness] wide
// there (as a share of its width).
//
// Round a round corner the rim is one band of light following the outline,
// as the glass does. Round a sharp corner no band can bend without showing
// it — along a mitre, or bowing into the corner — so there each of the two
// edges meeting at the corner glows on its own, each with its own
// thickness where p falls on it, and the two overlap at the corner as light
// along two edges of a frame does. Corners in between blend the two by how
// sharp they are next to the rim's width. Away from a corner, where only
// one edge reaches, both are the same band.
float waveRimHug(vec2 p, float inset, float thickness) {
  float w = uRim.x;
  float band = exp(-waveSq(waveRimInset(p, inset) / (w * thickness)));
  vec2 hs = uRect.zw * 0.5;
  vec2 c = p - hs;
  float r = c.x > 0.0 ? (c.y > 0.0 ? uRadii.z : uRadii.y)
                      : (c.y > 0.0 ? uRadii.w : uRadii.x);
  float round = smoothstep(0.75 * w, 2.5 * w, r);
  if (round >= 1.0) return band;
  // Only where both edges reach does the corner matter.
  vec2 e = hs - abs(c);
  float reach = w * 2.2 * (1.0 + 1.9 * uRim.z);
  if (max(e.x, e.y) > reach) return band;
  vec2 onTop = vec2(p.x, c.y < 0.0 ? 0.0 : uRect.w);
  vec2 onSide = vec2(c.x < 0.0 ? 0.0 : uRect.z, p.y);
  // Right at the corner both edges are as thick as the corner is, and each
  // eases into its own thickness over the rim's reach — as thickness eases
  // along a round corner's curve — so the corner is lit evenly, not thick on
  // one edge and thin on the other.
  vec2 tip = vec2(c.x < 0.0 ? 0.0 : uRect.z, c.y < 0.0 ? 0.0 : uRect.w);
  float atTip = waveRimThicknessAt(waveEdgeAt(tip) * uView.z);
  float top = mix(
      atTip, waveRimThicknessAt(waveEdgeAt(onTop) * uView.z), smoothstep(0.0, reach, e.x));
  float side = mix(
      atTip, waveRimThicknessAt(waveEdgeAt(onSide) * uView.z), smoothstep(0.0, reach, e.y));
  float a = exp(-waveSq(e.y / (w * top)));
  float b = exp(-waveSq(e.x / (w * side)));
  float edges = 1.0 - (1.0 - a) * (1.0 - b);
  return mix(edges, band, round);
}

// Whether, with the band gone, the rim has faded to nothing this far in and
// the hairline is behind: exp(-2.76^2) is under the 0.0005 that is dropped.
// Whether p is in a corner sharp enough that its rim light comes from both
// edges meeting there (see waveRimHug), within reach of both.
bool waveInSharpCorner(vec2 p) {
  vec2 hs = uRect.zw * 0.5;
  vec2 c = p - hs;
  float r = c.x > 0.0 ? (c.y > 0.0 ? uRadii.z : uRadii.y)
                      : (c.y > 0.0 ? uRadii.w : uRadii.x);
  if (r >= 2.5 * uRim.x) return false;
  vec2 e = hs - abs(c);
  return max(e.x, e.y) <= uRim.x * 2.2 * (1.0 + 1.9 * uRim.z);
}

// Whether the rim at p, [thickness] wide there, has faded below a level
// (and the band is gone), so nothing more need be worked out. Not in a
// sharp corner: there the light comes from two edges, each as thick as it
// is where p falls on it, and p's own thickness says nothing about them.
bool waveRimFaded(vec2 p, float inset, float thickness) {
  return uFront2.z <= 0.0 &&
      !waveInSharpCorner(p) &&
      inset - wavePoolSlack() >= uRim.x * thickness * 2.76 &&
      inset >= uHair.x * 0.5 + 0.75;
}

vec4 waveGlowCore(vec2 p, vec4 o, float edge, float thickness, float d, vec2 q, float g) {
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
    float hug = waveRimHug(p, inset, thickness);
    float reached = 1.0 - smoothstep(-lead * 0.7, lead * 0.5, d);
    float kept = smoothstep(-uRim.y, uRim.y, d + (uFront0.w - uFront3.x) / g);
    // Two soft swells of brightness running round the edge.
    shimmer = 0.5 + 0.5 * sin(time * 3.4 - edge * 2.0 * WAVE_TAU);
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
  // The colour lives on the glass: it fades out over the last device pixel
  // inside the view's outline, so its edge is anti-aliased by itself. It
  // ends just inside the outline rather than straddling it: a view the app
  // clips to that outline (a sheet, a card) is cut by a clip that on Impeller
  // is not anti-aliased, and a clip through still-lit pixels would leave a
  // bright staircase round the corners while the wave runs.
  float onGlass = clamp(-o.x / uView.x, 0.0, 1.0);
  return vec4(clamp(rgb, 0.0, 1.0) * total, total) * onGlass;
}

vec4 waveGlowWith(vec2 p, vec4 o, float d, vec2 q, float g) {
  float thickness = 1.0;
  float edge = 0.0;
  if (waveNearEdge(max(-o.x, 0.0))) {
    edge = waveEdgeAt(p);
    thickness = waveRimThicknessAt(edge * uView.z);
  }
  return waveGlowCore(p, o, edge, thickness, d, q, g);
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
