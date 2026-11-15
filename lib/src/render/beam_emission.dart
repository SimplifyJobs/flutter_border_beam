import 'dart:typed_data';
import 'dart:ui';

/// Maximum bumps, palette stops, and point lights the shader evaluates.
const int beamSlots = 8;

/// Which side of the outline a light or the bloom may reach.
enum BeamSide {
  /// Inside the outline only.
  inside,

  /// Both sides.
  both,

  /// Outside the outline only.
  outside,
}

/// One frame of light, as the shader consumes it: what an effect emits.
///
/// Mutable and reused frame after frame by its renderer, so producing a frame
/// allocates nothing. [reset] returns every field to "no light".
final class BeamEmission {
  /// Uniform light around the whole border, before bumps.
  double base = 0;

  /// Bumps along the perimeter: `centre u, lead width, tail width, amplitude`
  /// per slot. The lead side is +u (clockwise).
  final Float32List bumps = Float32List(beamSlots * 4);

  /// Number of bumps in use.
  int bumpCount = 0;

  /// Colour coordinate origin (perimeter `u` that maps to palette 0).
  double colorOrigin = 0;

  /// Colour coordinate scale (1: the palette once around the border).
  double colorScale = 1;

  /// Whether the colour coordinate wraps (palette around the ring) or clamps
  /// (palette spread across one beam).
  bool colorWrap = true;

  /// Amplitude of the ring noise that swells the border light (0 = none).
  double noiseAmplitude = 0;

  /// Ring noise base frequency, in whole cycles around the perimeter.
  double noiseFrequency = 0;

  /// Ring noise phase.
  double noisePhase = 0;

  /// Alpha of the crisp stroke.
  double stroke = 1;

  /// Alpha of the gaussian bloom hugging the stroke.
  double bloom = 0;

  /// Bloom standard deviation in logical px.
  double bloomSigma = 4;

  /// Which side the bloom reaches.
  BeamSide bloomSide = BeamSide.inside;

  /// Alpha of the outer halo.
  double outer = 0;

  /// How far the halo reaches past its plateau, in logical px.
  double outerReach = 0;

  /// Width of the halo's full-strength plateau just outside the border.
  double outerPlateau = 0;

  /// How much the halo spreads along the border as it reaches out (0 = not).
  double outerWiden = 0;

  /// Alpha multiplier of the point lights.
  double lights = 0;

  /// How strongly the hottest light whitens (or, on light themes, darkens).
  double highlight = 0;

  /// Share of the light that is added rather than blended (0–1).
  double additive = 0;

  /// Shimmer sweep amplitude (0 = no sweep).
  double sweepAmplitude = 0;

  /// Unit direction the sweep travels along, in box-normalised space.
  Offset sweepDirection = const Offset(1, 0);

  /// Sweep band centre along [sweepDirection] (0–1 spans the box).
  double sweepPosition = 0;

  /// Sweep band half width (box-normalised).
  double sweepHalfWidth = 0.1;

  /// Visible track start `u` and span (span 0 = whole border).
  double segmentStart = 0;

  /// See [segmentStart].
  double segmentSpan = 0;

  /// Feather at each end of the visible track, in `u`.
  double segmentFeather = 0;

  /// Point lights: `x, y, inward normal x, inward normal y` per slot.
  final Float32List lightPos = Float32List(beamSlots * 4);

  /// Point lights: `sigma along, sigma inward, amplitude, side` per slot.
  final Float32List lightShape = Float32List(beamSlots * 4);

  /// Point lights: `r, g, b, 0` per slot (straight colour).
  final Float32List lightColor = Float32List(beamSlots * 4);

  /// Number of point lights in use.
  int lightCount = 0;

  /// The furthest any point light reaches outside the outline, in logical px.
  double lightReachOutside = 0;

  /// The furthest any point light reaches inside the outline, in logical px.
  double lightReachInside = 0;

  /// Returns every field to "no light".
  void reset() {
    base = 0;
    bumpCount = 0;
    colorOrigin = 0;
    colorScale = 1;
    colorWrap = true;
    noiseAmplitude = 0;
    noiseFrequency = 0;
    noisePhase = 0;
    stroke = 1;
    bloom = 0;
    bloomSigma = 4;
    bloomSide = BeamSide.inside;
    outer = 0;
    outerReach = 0;
    outerPlateau = 0;
    outerWiden = 0;
    lights = 0;
    highlight = 0;
    additive = 0;
    sweepAmplitude = 0;
    sweepDirection = const Offset(1, 0);
    sweepPosition = 0;
    sweepHalfWidth = 0.1;
    segmentStart = 0;
    segmentSpan = 0;
    segmentFeather = 0;
    lightCount = 0;
    lightReachOutside = 0;
    lightReachInside = 0;
  }

  /// Adds a bump centred at [centre] (perimeter `u`). [lead] is its half
  /// width ahead (+u), [tail] behind. Ignored once every slot is used.
  void addBump(double centre, double lead, double tail, double amplitude) {
    if (bumpCount >= beamSlots || amplitude <= 0) return;
    final i = bumpCount * 4;
    bumps[i] = centre;
    bumps[i + 1] = lead;
    bumps[i + 2] = tail;
    bumps[i + 3] = amplitude;
    bumpCount++;
  }

  /// Adds an anisotropic gaussian light anchored at [at] (canvas coords),
  /// with [inward] the unit normal pointing into the shape. [anchorOutside]
  /// is how far outside the outline the anchor sits, for the draw bounds.
  /// Ignored once every slot is used.
  void addLight({
    required Offset at,
    required Offset inward,
    required double alongSigma,
    required double inwardSigma,
    required double amplitude,
    required Color color,
    BeamSide side = BeamSide.inside,
    double anchorOutside = 0,
  }) {
    if (lightCount >= beamSlots || amplitude <= 0) return;
    final i = lightCount * 4;
    lightPos[i] = at.dx;
    lightPos[i + 1] = at.dy;
    lightPos[i + 2] = inward.dx;
    lightPos[i + 3] = inward.dy;
    lightShape[i] = alongSigma < 0.5 ? 0.5 : alongSigma;
    lightShape[i + 1] = inwardSigma < 0.5 ? 0.5 : inwardSigma;
    lightShape[i + 2] = amplitude;
    lightShape[i + 3] = switch (side) {
      BeamSide.inside => -1,
      BeamSide.both => 0,
      BeamSide.outside => 1,
    };
    lightColor[i] = color.r;
    lightColor[i + 1] = color.g;
    lightColor[i + 2] = color.b;
    lightColor[i + 3] = 0;
    final reach = 3 * (alongSigma > inwardSigma ? alongSigma : inwardSigma);
    if (side != BeamSide.outside && reach > lightReachInside) {
      lightReachInside = reach;
    }
    if (side != BeamSide.inside && reach + anchorOutside > lightReachOutside) {
      lightReachOutside = reach + anchorOutside;
    }
    lightCount++;
  }
}
