// Verbatim transcription of the line variant keyframe tables from the React
// library (border-beam v1.3.0, src/styles.ts lines ~2105-2149). Each table is
// a list of (t, value) pairs with t in 0–1; interpolation between stops is
// linear (the CSS animations declaring these run with `linear` or
// `ease-in-out` timing — the easing is applied to the WHOLE cycle progress
// before sampling, matching CSS `animation-timing-function` semantics per
// keyframe segment; see LineKeyframeTrack).

/// A single keyframe stop.
typedef BeamKeyframe = ({double t, double value});

/// `beam-travel` — the traveling beam's x position (fraction of width).
const List<BeamKeyframe> lineTravelX = [
  (t: 0.0, value: 0.06),
  (t: 0.1, value: 0.15),
  (t: 0.2, value: 0.25),
  (t: 0.3, value: 0.35),
  (t: 0.4, value: 0.44),
  (t: 0.5, value: 0.5),
  (t: 0.6, value: 0.56),
  (t: 0.7, value: 0.65),
  (t: 0.8, value: 0.75),
  (t: 0.9, value: 0.85),
  (t: 1.0, value: 0.94),
];

/// `beam-travel` — the beam width factor (peaks mid-travel).
const List<BeamKeyframe> lineTravelW = [
  (t: 0.0, value: 0.5),
  (t: 0.1, value: 0.8),
  (t: 0.2, value: 1.1),
  (t: 0.3, value: 1.3),
  (t: 0.4, value: 1.45),
  (t: 0.5, value: 1.5),
  (t: 0.6, value: 1.45),
  (t: 0.7, value: 1.3),
  (t: 0.8, value: 1.1),
  (t: 0.9, value: 0.8),
  (t: 1.0, value: 0.5),
];

/// `beam-edge-fade` — layer opacity, fading the beam out near travel ends.
const List<BeamKeyframe> lineEdgeFade = [
  (t: 0.0, value: 0),
  (t: 0.125, value: 0),
  (t: 0.325, value: 1),
  (t: 0.675, value: 1),
  (t: 0.875, value: 0),
  (t: 1.0, value: 0),
];

/// `beam-breathe` — the beam height factor (cycle = duration × 1.3,
/// ease-in-out per segment).
const List<BeamKeyframe> lineBreatheH = [
  (t: 0.0, value: 0.8),
  (t: 0.25, value: 1.25),
  (t: 0.55, value: 0.85),
  (t: 0.8, value: 1.3),
  (t: 1.0, value: 0.8),
];

/// `beam-spike` — first spike scale oscillation (cycle = duration × 1.33,
/// ease-in-out per segment).
const List<BeamKeyframe> lineSpike = [
  (t: 0.0, value: 0.8),
  (t: 0.25, value: 1.3),
  (t: 0.5, value: 0.9),
  (t: 0.75, value: 1.4),
  (t: 1.0, value: 0.8),
];

/// `beam-spike2` — second spike scale oscillation (cycle = duration × 1.7,
/// ease-in-out per segment).
const List<BeamKeyframe> lineSpike2 = [
  (t: 0.0, value: 1.2),
  (t: 0.25, value: 0.7),
  (t: 0.5, value: 1.4),
  (t: 0.75, value: 0.8),
  (t: 1.0, value: 1.2),
];
