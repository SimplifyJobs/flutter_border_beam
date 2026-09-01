// Verbatim transcription of the conic gradient stop/alpha tables of the
// rotate (React `md`) and small (React `sm`) variants, from the React library
// (border-beam v1.3.0, `src/styles.ts` — generateBorderVariantCSS /
// generateSmallVariantCSS, whose window/highlight/bloom tables are identical
// apart from the wider `smallMask` window). Every list is a CSS
// `conic-gradient` colour-stop list flattened into parallel stop and alpha
// lists: `stops[i]` is the CSS stop position 0–1 and `alphas[i]` the alpha of
// the white (dark theme) or black (light theme) colour at it.
//
// The tables are asymmetric in the stop axis: the bright core is followed by
// a short falloff on the leading side and a long soft foot on the trailing
// side, which is what makes the beam read as a head dragging a tail.

/// `beam-mask` — the rotating soft window that reveals the rotate variant's
/// stroke and inner layers.
const List<double> rotateWindowStops = [
  0.0, 0.30, 0.36, 0.44, 0.52, 0.80, 0.86, 0.92, 0.95, 1.0, //
];

/// Alphas of [rotateWindowStops].
const List<double> rotateWindowAlphas = [
  0.0, 0.0, 0.1, 0.35, 1.0, 1.0, 0.35, 0.1, 0.0, 0.0, //
];

/// `smallMask` — the wider window the small variant's inner layer uses.
const List<double> smallWindowStops = [
  0.0, 0.22, 0.28, 0.36, 0.46, 0.82, 0.88, 0.94, 0.97, 1.0, //
];

/// Alphas of [smallWindowStops].
const List<double> smallWindowAlphas = [
  0.0, 0.0, 0.12, 0.4, 1.0, 1.0, 0.4, 0.12, 0.0, 0.0, //
];

/// The stroke's highlight sweep — white on the dark theme, black on the
/// light one.
const List<double> rotateHighlightStops = [
  0.0, 0.54, 0.57, 0.60, 0.63, 0.66, 0.69, 0.72, 0.75, 0.78, 1.0, //
];

/// Dark-theme alphas of [rotateHighlightStops].
const List<double> rotateHighlightAlphasDark = [
  0.0, 0.0, 0.1, 0.3, 0.6, 0.75, 0.6, 0.3, 0.1, 0.0, 0.0, //
];

/// Light-theme alphas of [rotateHighlightStops].
const List<double> rotateHighlightAlphasLight = [
  0.0, 0.0, 0.08, 0.2, 0.4, 0.55, 0.4, 0.2, 0.08, 0.0, 0.0, //
];

/// The sharp bloom band, painted into a blurred layer.
const List<double> rotateBloomStops = [
  0.0, 0.58, 0.62, 0.65, 0.67, 0.69, 0.70, 0.705, 0.715, 0.73, 0.75, 0.78,
  0.82, 1.0, //
];

/// Dark-theme alphas of [rotateBloomStops].
const List<double> rotateBloomAlphasDark = [
  0.0, 0.0, 0.03, 0.08, 0.2, 0.45, 0.85, 0.85, 0.45, 0.2, 0.08, 0.03, 0.0,
  0.0, //
];

/// Light-theme alphas of [rotateBloomStops].
const List<double> rotateBloomAlphasLight = [
  0.0, 0.0, 0.02, 0.08, 0.2, 0.4, 0.6, 0.6, 0.4, 0.2, 0.08, 0.02, 0.0, 0.0, //
];

/// The blur sigma of the rotate/small bloom layer (CSS `filter: blur(8px)`).
const double rotateBloomBlurSigma = 8;

/// The inner shadow blur of the rotate variant's inner layer.
const double rotateInnerShadowBlur = 9;

/// The inner shadow blur of the small variant's inner layer.
const double smallInnerShadowBlur = 5;

/// The alpha the rotate variant's inner blobs are fixed at (its inner layer
/// is derived from the border blob table at 0.9× size).
const double rotateInnerBlobAlpha = 0.45;

/// The mono palette's replacement for [rotateInnerBlobAlpha].
const double rotateInnerBlobAlphaMono = 0.225;

/// The size factor the rotate variant's inner blobs take from the border
/// table.
const double rotateInnerBlobScale = 0.9;
