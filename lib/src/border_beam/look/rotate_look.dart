// The travelling beam's conic tables: each a list of stop positions around
// the turn (0–1, clockwise from the beam's start angle) and the alpha at each
// stop. The bright core is followed by a short falloff on the leading side and
// a long soft foot trailing behind, which is what makes the beam read as a
// head dragging a tail.

/// The rotating soft window that reveals the stroke and inner glow.
const List<double> rotateWindowStops = [
  0.0, 0.30, 0.36, 0.44, 0.52, 0.80, 0.86, 0.92, 0.95, 1.0, //
];

/// Alphas of [rotateWindowStops].
const List<double> rotateWindowAlphas = [
  0.0, 0.0, 0.1, 0.35, 1.0, 1.0, 0.35, 0.1, 0.0, 0.0, //
];

/// The wider window a compact chip's inner glow uses.
const List<double> compactWindowStops = [
  0.0, 0.22, 0.28, 0.36, 0.46, 0.82, 0.88, 0.94, 0.97, 1.0, //
];

/// Alphas of [compactWindowStops].
const List<double> compactWindowAlphas = [
  0.0, 0.0, 0.12, 0.4, 1.0, 1.0, 0.4, 0.12, 0.0, 0.0, //
];

/// The highlight at the head of the stroke — white on a dark surface, black
/// on a light one.
const List<double> rotateHighlightStops = [
  0.0, 0.54, 0.57, 0.60, 0.63, 0.66, 0.69, 0.72, 0.75, 0.78, 1.0, //
];

/// Dark-surface alphas of [rotateHighlightStops].
const List<double> rotateHighlightAlphasDark = [
  0.0, 0.0, 0.1, 0.3, 0.6, 0.75, 0.6, 0.3, 0.1, 0.0, 0.0, //
];

/// Light-surface alphas of [rotateHighlightStops].
const List<double> rotateHighlightAlphasLight = [
  0.0, 0.0, 0.08, 0.2, 0.4, 0.55, 0.4, 0.2, 0.08, 0.0, 0.0, //
];

/// The narrow band of the bloom, which is blurred into a soft glow.
const List<double> rotateBloomStops = [
  0.0, 0.58, 0.62, 0.65, 0.67, 0.69, 0.70, 0.705, 0.715, 0.73, 0.75, 0.78,
  0.82, 1.0, //
];

/// Dark-surface alphas of [rotateBloomStops].
const List<double> rotateBloomAlphasDark = [
  0.0, 0.0, 0.03, 0.08, 0.2, 0.45, 0.85, 0.85, 0.45, 0.2, 0.08, 0.03, 0.0,
  0.0, //
];

/// Light-surface alphas of [rotateBloomStops].
const List<double> rotateBloomAlphasLight = [
  0.0, 0.0, 0.02, 0.08, 0.2, 0.4, 0.6, 0.6, 0.4, 0.2, 0.08, 0.02, 0.0, 0.0, //
];

/// Where the beam's head sits in the tables: the bloom's peak.
const double rotateHeadStop = 0.7025;

/// Blur of the bloom band, in px.
const double rotateBloomBlur = 8;

/// The inner glow's inset shadow blur on a card, in px.
const double rotateInnerShadowBlur = 9;

/// The inner glow's inset shadow blur on a compact chip, in px.
const double compactInnerShadowBlur = 5;

/// How far in from the edge the inner glow fades out, in px.
const double innerEdgeFade = 28;

/// The alpha of the inner glow's blobs, derived from the border table.
const double rotateInnerBlobAlpha = 0.45;

/// [rotateInnerBlobAlpha] for the mono palette.
const double rotateInnerBlobAlphaMono = 0.225;

/// The size of the inner glow's blobs relative to the border table's.
const double rotateInnerBlobScale = 0.9;

/// How far past the border a comet's glow reaches, in px.
const double cometReach = 12;

/// The shortest side at or below which a box is drawn with the compact
/// chip tables.
const double compactMaxExtent = 56;
