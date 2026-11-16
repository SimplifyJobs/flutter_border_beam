import 'package:flutter/animation.dart' show Curves;

// The line effect's design: keyframe tables for the travelling streak, its
// radial windows, its stroke highlight, and the seven bloom spikes that rise
// from the edge. Lengths are px in a frame where the streak rides the bottom
// edge; every other edge is that frame turned about the box's centre.

/// A single keyframe stop.
typedef BeamKeyframe = ({double t, double value});

/// The streak's position along the edge (a fraction of its length) through
/// one sweep.
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

/// The streak's width factor through one sweep (widest mid-run).
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

/// The streak's opacity through one sweep: it fades out near the ends.
const List<BeamKeyframe> lineEdgeFade = [
  (t: 0.0, value: 0),
  (t: 0.125, value: 0),
  (t: 0.325, value: 1),
  (t: 0.675, value: 1),
  (t: 0.875, value: 0),
  (t: 1.0, value: 0),
];

/// The streak's height factor (period = cycle × [lineBreathePeriod], eased
/// per segment).
const List<BeamKeyframe> lineBreatheH = [
  (t: 0.0, value: 0.8),
  (t: 0.25, value: 1.25),
  (t: 0.55, value: 0.85),
  (t: 0.8, value: 1.3),
  (t: 1.0, value: 0.8),
];

/// The first spike scale (period = cycle × [lineSpikePeriod], eased per
/// segment).
const List<BeamKeyframe> lineSpike = [
  (t: 0.0, value: 0.8),
  (t: 0.25, value: 1.3),
  (t: 0.5, value: 0.9),
  (t: 0.75, value: 1.4),
  (t: 1.0, value: 0.8),
];

/// The second spike scale (period = cycle × [lineSpike2Period], eased per
/// segment).
const List<BeamKeyframe> lineSpike2 = [
  (t: 0.0, value: 1.2),
  (t: 0.25, value: 0.7),
  (t: 0.5, value: 1.4),
  (t: 0.75, value: 0.8),
  (t: 1.0, value: 1.2),
];

/// Horizontal radius of the radial window shared by the inner and stroke
/// layers.
const double lineWindowRadiusX = 78;

/// Vertical radius of [lineWindowRadiusX]'s window.
const double lineWindowRadiusY = 60;

/// Mid stop of the inner/stroke window.
const double lineWindowMidStop = 0.45;

/// Alpha at [lineWindowMidStop].
const double lineWindowMidAlpha = 0.5;

/// Horizontal radius of the bloom layer's (wider, taller) window mask.
const double lineBloomWindowRadiusX = 84;

/// Vertical radius of the bloom window.
const double lineBloomWindowRadiusY = 110;

/// Mid stop of the bloom window.
const double lineBloomWindowMidStop = 0.35;

/// Alpha at [lineBloomWindowMidStop].
const double lineBloomWindowMidAlpha = 0.5;

/// Inner shadow blur of the line variant's inner layer.
const double lineInnerShadowBlur = 9;

/// Blur of the bloom layer, in px.
const double lineBloomBlur = 8;

/// Blur of the bloom layer for the mono palette, in px.
const double lineBloomBlurMono = 6;

// ─── Traveling highlight ────────────────────────────────────────────────────

/// How far below the bottom edge the stroke highlight is centred.
const double lineHighlightOffsetY = 2;

/// Dark-theme highlight radii and stops.
const double lineHighlightRadiusXDark = 24;

/// Vertical radius of the dark-theme highlight.
const double lineHighlightRadiusYDark = 28;

/// Dark-theme highlight alphas (centre, mid, edge).
const List<double> lineHighlightAlphasDark = [0.38, 0.12, 0.0];

/// Stops of [lineHighlightAlphasDark].
const List<double> lineHighlightStopsDark = [0, 0.30, 0.65];

/// Light-theme highlight horizontal radius.
const double lineHighlightRadiusXLight = 35;

/// Vertical radius of the light-theme highlight.
const double lineHighlightRadiusYLight = 28;

/// Light-theme highlight alphas (centre, mid, edge).
const List<double> lineHighlightAlphasLight = [0.6, 0.25, 0.0];

/// Stops of [lineHighlightAlphasLight].
const List<double> lineHighlightStopsLight = [0, 0.35, 0.70];

// ─── Bloom spikes ───────────────────────────────────────────────────────────

/// One bloom spike's fixed geometry: `fx` is its position along the edge as
/// a fraction of the width, `yInset` how far above the edge it is centred,
/// and `midStop`/`endStop` its two gradient stops.
typedef LineSpikeGeometry = ({
  double fx,
  double yInset,
  double midStop,
  double endStop,
});

/// The seven fixed spikes, at 8/22/36/50/64/78/92% of the edge.
const List<LineSpikeGeometry> lineSpikes = [
  (fx: 0.08, yInset: 2, midStop: 0.30, endStop: 0.88),
  (fx: 0.22, yInset: 4, midStop: 0.50, endStop: 0.95),
  (fx: 0.36, yInset: 3, midStop: 0.40, endStop: 0.90),
  (fx: 0.50, yInset: 2, midStop: 0.55, endStop: 0.96),
  (fx: 0.64, yInset: 4, midStop: 0.35, endStop: 0.89),
  (fx: 0.78, yInset: 2, midStop: 0.48, endStop: 0.94),
  (fx: 0.92, yInset: 3, midStop: 0.42, endStop: 0.91),
];

/// Horizontal radius of the wide spike at 22%.
const double lineSpikeWideRadiusX22 = 10;

/// Vertical radius of the spike at 22%.
const double lineSpikeRadiusY22 = 35;

/// Horizontal radius of the wide spike at 50%.
const double lineSpikeWideRadiusX50 = 14;

/// Vertical radius of the spike at 50%.
const double lineSpikeRadiusY50 = 28;

/// Horizontal radius of the spike at 78%.
const double lineSpikeRadiusX78 = 7;

/// Vertical radius of the spike at 78%.
const double lineSpikeRadiusY78 = 45;

/// Widths of the four thin spikes (8/36/64/92%) with a colour palette.
const List<double> lineThinSpikeWidths = [0.8, 2.0, 1.2, 0.6];

/// The light-theme width of the thin spike at 92%.
const double lineThinSpikeWidthLight92 = 1.0;

/// Heights of the four thin spikes (8/36/64/92%) with a colour palette.
const List<double> lineThinSpikeHeights = [92.0, 72.0, 85.0, 60.0];

/// Widths the mono palette widens the four thin spikes to.
const List<double> lineMonoThinSpikeWidths = [12.0, 14.0, 12.0, 10.0];

/// The mono width of the thin spike at 92% on the light theme.
const double lineMonoThinSpikeWidthLight92 = 12.0;

/// Heights the mono palette shortens the four thin spikes to.
const List<double> lineMonoThinSpikeHeights = [42.0, 38.0, 40.0, 32.0];

/// Mono attenuation of the primary spike colour.
const double lineMonoSpike1 = 0.14;

/// Mono attenuation of the primary spike colour's dark mid stop.
const double lineMonoSpike1MidDark = 0.09;

/// Mono attenuation of the primary spike colour's light mid stop.
const double lineMonoSpike1MidLight = 0.11;

/// The non-mono light-theme alpha of the primary spike's mid stop.
const double lineSpike1MidLightAlpha = 0.85;

/// Mono attenuation of the secondary spike colour.
const double lineMonoSpike2 = 0.12;

/// Mono alpha of the secondary spike colour's dark mid stop.
const double lineMonoSpike2MidDark = 0.06;

/// Mono attenuation of the secondary spike colour's light mid stop.
const double lineMonoSpike2MidLight = 0.09;

/// The non-mono dark-theme alpha of the secondary spike's mid stop.
const double lineSpike2MidDarkAlpha = 0.49;

/// The non-mono light-theme alpha of the secondary spike's mid stop.
const double lineSpike2MidLightAlpha = 0.7;

/// Mono attenuation of a table spike's first colour.
const double lineMonoTableSpike1 = 0.14;

/// Mono attenuation of a table spike's second colour.
const double lineMonoTableSpike2 = 0.14 * 0.7;

// ─── Traveling dot, ambient glow, and the light theme's shadow ──────────────

/// How far below the edge the dark theme's traveling dot is centred.
const double lineDotOffsetY = 1;

/// Horizontal radius of the traveling dot.
const double lineDotRadiusX = 21;

/// Vertical radius of the traveling dot.
const double lineDotRadiusY = 15;

/// Dot alphas (centre, 20%, 50%) with a colour palette.
const List<double> lineDotAlphas = [1.0, 0.9, 0.5];

/// Dot alphas for the mono palette.
const List<double> lineDotAlphasMono = [0.5, 0.45, 0.25];

/// Stops of the dot gradient.
const List<double> lineDotStops = [0, 0.20, 0.50, 1.0];

/// Horizontal radius of the ambient glow around the dot.
const double lineAmbientRadiusX = 42;

/// Vertical radius of the ambient glow.
const double lineAmbientRadiusY = 40;

/// Ambient glow alphas (centre, 25%, 55%) with a colour palette.
const List<double> lineAmbientAlphas = [0.3, 0.12, 0.03];

/// Ambient glow alphas for the mono palette.
const List<double> lineAmbientAlphasMono = [0.15, 0.06, 0.015];

/// Stops of the ambient glow gradient.
const List<double> lineAmbientStops = [0, 0.25, 0.55, 0.80];

/// Horizontal radius of the light theme's traveling shadow blob.
const double lineShadowRadiusX = 50;

/// Vertical radius of the traveling shadow blob.
const double lineShadowRadiusY = 32;

/// Alphas of the traveling shadow blob.
const List<double> lineShadowAlphas = [0.5, 0.18, 0.03, 0.0];

/// Stops of the traveling shadow blob.
const List<double> lineShadowStops = [0, 0.30, 0.60, 0.85];

/// The streak height track's period, in cycles.
const double lineBreathePeriod = 1.3;

/// The first spike track's period, in cycles.
const double lineSpikePeriod = 1.33;

/// The second spike track's period, in cycles.
const double lineSpike2Period = 1.7;

/// How much wider the bloom's hue swing runs than the stroke's, in degrees.
const double lineBloomHueBonus = 10;

/// The widest hue swing the line takes, in degrees.
const double lineHueCap = 13;

/// Samples a keyframe table at cycle progress [t] (0–1), linearly or eased
/// within each segment.
double sampleKeyframes(
  List<BeamKeyframe> frames,
  double t, {
  bool eased = false,
}) {
  final clamped = t.clamp(0.0, 1.0);
  for (var i = 1; i < frames.length; i++) {
    final prev = frames[i - 1];
    final next = frames[i];
    if (clamped <= next.t) {
      final span = next.t - prev.t;
      if (span <= 0) return next.value;
      var local = (clamped - prev.t) / span;
      if (eased) local = Curves.easeInOut.transform(local);
      return prev.value + (next.value - prev.value) * local;
    }
  }
  return frames.last.value;
}
