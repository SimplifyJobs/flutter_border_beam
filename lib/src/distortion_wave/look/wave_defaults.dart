import 'package:flutter/animation.dart';

import '../models/wave_dots.dart';
import '../models/wave_glow.dart';
import '../models/wave_lens.dart';
import '../models/wave_motion.dart';
import '../models/wave_palette.dart';
import '../models/wave_style.dart';
import '../models/wave_timing.dart';
import '../models/wave_type.dart';

// The tuned look of each wave type: every field set, so a style merged over
// it resolves completely. Owned and tunable, like the beam's look data —
// goldens move when it does. Calibrated against the reference design
// (DistortionWavesKit's tuned styles).

/// The front's default curve: it leaves the source at full speed and settles
/// softly at the far side.
const Curve waveTravelEasing = Cubic(0.22, 1, 0.36, 1);

/// The default curve of the wipe that clears the edges: ease-in-out.
const Curve waveRimEasing = Cubic(0.42, 0, 0.58, 1);

const WaveStyle _vertical = WaveStyle(
  type: WaveType.vertical,
  palette: WavePalette.colorful,
  timing: WaveTiming(
    anticipation: Duration(milliseconds: 500),
    travel: Duration(milliseconds: 2280),
    easing: waveTravelEasing,
    returnSpeed: 1.45,
    linger: Duration(milliseconds: -350),
    rimFade: Duration(milliseconds: 3030),
    rimEasing: waveRimEasing,
    hairlineLinger: Duration(milliseconds: 470),
    hairlineFade: Duration(milliseconds: 3000),
  ),
  motion: WaveMotion(
    pull: 24,
    inhale: 56,
    gatherGlow: 0.33,
    gatherDots: 1,
    launchGap: 0,
    orientation: 0.91,
  ),
  lens: WaveLens(
    amplitude: 34,
    width: 150,
    aberration: 0.78,
    swell: 22,
    blur: 18,
    blurAhead: 90,
    blurBehind: 240,
  ),
  glow: WaveGlow(
    lead: 130,
    tail: 300,
    strength: 0.92,
    rimWidth: 14,
    rimUnevenness: 1,
    rimStrength: 0.82,
    rimSoftness: 343,
    rimPulse: 0.6,
    hairlineWidth: 1.5,
    hairlineOpacity: 0.9,
    hairlineWhite: 0.95,
    cornerRadius: 62,
  ),
  dots: WaveDots(
    count: 64,
    size: 1.8,
    reach: 150,
    flight: 30,
    gap: 24,
    life: Duration(milliseconds: 2190),
    spread: 1,
  ),
);

// A sheet is about 0.6 the height of a screen, so the center wave's lengths
// are 0.6 of the vertical one's. It gathers no colour and no dots before it
// leaves, has no colour fringing (which would part white into red and blue),
// and keeps its dots in view.
final WaveStyle _center = _vertical.merge(
  const WaveStyle(
    type: WaveType.center,
    palette: WavePalette.green,
    timing: WaveTiming(
      anticipation: Duration(milliseconds: 250),
      travel: Duration(milliseconds: 3430),
      rimFade: Duration(milliseconds: 2510),
      hairlineLinger: Duration(milliseconds: 960),
    ),
    motion: WaveMotion(pull: 14.4, inhale: 33.6, gatherGlow: 0, gatherDots: 0),
    lens: WaveLens(
      amplitude: 20.4,
      width: 90,
      aberration: 0,
      swell: 13.2,
      blur: 10.8,
      blurAhead: 54,
      blurBehind: 144,
    ),
    glow: WaveGlow(
      lead: 78,
      tail: 180,
      strength: 0.6,
      rimStrength: 0.6,
      rimSoftness: 205.8,
      cornerRadius: 48,
    ),
    dots: WaveDots(
      count: 89,
      reach: 90,
      flight: 18,
      gap: 11,
      life: Duration(milliseconds: 3930),
      spread: 0.64,
    ),
  ),
);

final WaveStyle _horizontal = _vertical.copyWith(type: WaveType.horizontal);

/// The fully resolved defaults of [type]: every field set.
WaveStyle waveDefaults(WaveType type) => switch (type) {
  WaveType.vertical => _vertical,
  WaveType.horizontal => _horizontal,
  WaveType.center => _center,
};
