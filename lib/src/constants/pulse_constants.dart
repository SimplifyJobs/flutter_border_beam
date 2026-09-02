// The pulse variants' painting constants.
//
// Two provenances, kept apart below:
//
//  * VERBATIM — transcribed from the React library (border-beam v1.3.0,
//    `src/styles.ts`): the pulse-outside outward-glow transform, the
//    reference element the glow geometry was authored against, and the
//    pulse-inside corner accents.
//  * FLUTTER-SIDE TUNING — the demo-hero recipe
//    (`.beam-host--pulse-outside-tuned` in the source's demo page), which the
//    React library layers on top of its own raw defaults. It is baked in here
//    because the pulse-outside look everyone knows from
//    beam.jakubantalik.com is the tuned one; every value stays overridable
//    through the widget's coreBlur/bloomBlur/glowBrightness/glowSaturation/
//    glowBoost/opacity hooks.

// ─── Verbatim: pulse-outside geometry ───────────────────────────────────────

/// Horizontal factor of the source's constant outward-glow transform
/// (`scale(0.95, 0.9)`).
const double pulseOuterScaleX = 0.95;

/// Vertical factor of the outward-glow transform.
const double pulseOuterScaleY = 0.9;

/// Reference child width the glow geometry was authored for.
const double pulseOuterReferenceWidth = 350;

/// Reference child height the glow geometry was authored for.
const double pulseOuterReferenceHeight = 140;

/// Lower clamp on the glow's size scale.
const double pulseOuterMinScale = 0.35;

/// Upper clamp on the glow's size scale.
const double pulseOuterMaxScale = 4;

/// Damping applied to the size-derived halo unit (`--sub-glow-unit`), which
/// scales reach and blur with the element's size relative to the demo's
/// Subscribe button baseline.
const double pulseOuterGlowUnitDamping = 0.7;

// ─── Verbatim: pulse-inside corner accents ──────────────────────────────────

/// Radius of the fixed corner-accent ellipses of the pulse-inside inner
/// layer.
const double pulseInnerCornerRadius = 60;

/// Dark-theme alpha of a corner accent at full breath.
const double pulseInnerCornerAlphaDark = 0.18;

/// Light-theme alpha of a corner accent at full breath.
const double pulseInnerCornerAlphaLight = 0.08;

/// The stop the corner accent has faded out by.
const double pulseInnerCornerEndStop = 0.70;

/// Blur sigma of the pulse-inside frozen bloom layer.
const double pulseInnerBloomBlurSigma = 8;

// ─── Flutter-side tuning: the pulse-outside demo recipe ─────────────────────

/// Prominence boost multiplied into the glow blob geometry.
const double pulseOuterTunedBoost = 1.05;

/// Multiplier on the glow layers' opacity, brightness, and saturation.
const double pulseOuterTunedGlowMultiplier = 1.71;

/// Unit-scaled inset the core glow is grown past the child's bounds.
const double pulseOuterTunedCoreInset = 6;

/// Unit-scaled inset the bloom halo is grown past the child's bounds.
const double pulseOuterTunedBloomInset = 14;

/// Unit-scaled blur of the core glow — the value that melts the separate
/// blobs into one continuous edge-hugging glow.
const double pulseOuterTunedCoreBlur = 10;

/// Unit-scaled blur of the ambient bloom halo.
const double pulseOuterTunedBloomBlur = 19;

/// Default glow brightness before the tuning multiplier.
const double pulseOuterGlowBrightness = 1.3;

/// Default glow saturation before the tuning multiplier.
const double pulseOuterGlowSaturation = 1.2;
