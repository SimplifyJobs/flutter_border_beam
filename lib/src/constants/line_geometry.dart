// Verbatim transcription of the line variant's mask and blob geometry from
// the React library (border-beam v1.3.0, `src/styles.ts` —
// generateLineVariantCSS and getLineBloomGradients). Every length is in
// logical px in the authored coordinate space, where the beam rides the
// bottom edge of the box; every stop is a CSS gradient stop 0–1.
//
// The mask/highlight radii are multiplied at paint time by the animated
// width/height factors (`lineW`/`lineH`) and the two spike tracks, which is
// why only the base numbers live here.

/// Radial window mask radii shared by the inner and stroke layers.
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

/// Bloom blur sigma while the hue animation runs (CSS `blur(8px)`).
const double lineBloomBlurSigma = 8;

/// Bloom blur sigma for the mono palette (CSS `blur(6px)`).
const double lineBloomBlurSigmaMono = 6;

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

/// One bloom spike's fixed geometry: [fx] is its position along the edge as
/// a fraction of the width, [yInset] how far above the edge it is centred,
/// and [midStop]/[endStop] its two gradient stops.
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
