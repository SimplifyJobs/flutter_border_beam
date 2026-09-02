import 'dart:ui';

import 'package:flutter/painting.dart';

import 'beam_options.dart';
import 'beam_palette.dart';
import 'beam_segment.dart';
import 'beam_shape.dart';
import 'beam_style.dart';
import 'beam_theme_config.dart';
import 'beam_timing.dart';
import 'beam_variant.dart';
import 'model_validation.dart';

// The line variant's breathe/spike tracks run at multiples of the cycle.
const double _defaultBreatheFactor = 1.3;
const double _defaultSpikeFactor = 1.33;
const double _defaultSpike2Factor = 1.7;

// The window BeamStyle.renderScale is clamped to: below a quarter the
// magnification is coarse enough to read as a blur, and above 1 the beam
// would be painted larger than the box it fills.
const double _minRenderScale = 0.25;
const double _maxRenderScale = 1;

double _seconds(Duration d) =>
    d.inMicroseconds / Duration.microsecondsPerSecond;

/// The fully-resolved, frame-invariant configuration handed to the painter.
///
/// Built once by the widget whenever its inputs change; painting then only
/// depends on this config plus the animated frame phases.
class BeamConfig {
  /// Creates a resolved config. Prefer [BeamConfig.resolve].
  const BeamConfig({
    required this.variant,
    required this.palette,
    required this.theme,
    required this.brightness,
    required this.borderRadius,
    required this.borderWidth,
    required this.useSuperellipse,
    required this.strength,
    required this.brightnessFactor,
    required this.saturation,
    required this.hueRange,
    required this.hueBase,
    required this.staticColors,
    required this.cycleSeconds,
    required this.hueMode,
    required this.huePeriodSeconds,
    required this.bloomHuePeriodSeconds,
    this.gapSeconds = 0,
    this.breatheFactor = _defaultBreatheFactor,
    this.spikeFactor = _defaultSpikeFactor,
    this.spike2Factor = _defaultSpike2Factor,
    this.strokeOpacityFactor = 1,
    this.innerOpacityFactor = 1,
    this.bloomOpacityFactor = 1,
    this.glowBoost = 1,
    this.coreBlur,
    this.bloomBlur,
    this.glowBrightness,
    this.glowSaturation,
    this.tailLength = 1,
    this.glowSpread = 1,
    this.comet = false,
    this.sparkle = 0,
    this.segments,
    this.innerSizeScale = 1,
    this.renderScale = 1,
    this.pulseOutsideTuning = BeamPulseOutsideTuning.demo,
    this.edge = BeamEdge.bottom,
    this.ringOffset = 0,
    this.contour,
    this.segment,
    this.wrapCorners = false,
    this.direction = BeamDirection.forward,
    this.phaseOffset = 0,
    this.beamCount = 1,
  });

  /// Resolves the beam value objects against the variant/theme presets,
  /// mirroring the React component's computed values.
  ///
  /// [palette] is the resolved form of `style.colors` and [brightness] the
  /// resolved form of `style.theme` — both are settled by the widget, which
  /// owns the ambient theme. [textDirection] resolves `shape.radius`.
  factory BeamConfig.resolve({
    required BeamVariant variant,
    required BeamPalette palette,
    required Brightness brightness,
    BeamStyle style = const BeamStyle(),
    BeamShape shape = const BeamShape(),
    BeamTiming timing = const BeamTiming(),
    TextDirection textDirection = TextDirection.ltr,
  }) {
    validateBeamTiming(timing);
    final theme =
        style.themeConfig ?? BeamThemeConfig.presetFor(variant, brightness);
    final cycleSeconds = _seconds(timing.cycle ?? variant.defaultCycleDuration);
    final hueRange = style.hueRange ?? 30;
    return BeamConfig(
      variant: variant,
      palette: palette,
      theme: theme,
      brightness: brightness,
      borderRadius:
          shape.radius?.resolve(textDirection) ??
          BorderRadius.circular(variant.defaultBorderRadius),
      borderWidth: shape.borderWidth ?? variant.defaultBorderWidth,
      useSuperellipse: shape.superellipse ?? false,
      strength: (style.strength ?? 1).clamp(0.0, 1.0),
      brightnessFactor: style.brightness ?? theme.brightness ?? 1.3,
      saturation: style.saturation ?? theme.saturation,
      // The line variant caps the hue range at 13°, as in the source.
      hueRange: variant == BeamVariant.line
          ? (hueRange > 13 ? 13.0 : hueRange)
          : hueRange,
      hueMode:
          style.hueMode ??
          (variant.isPulse ? BeamHueMode.continuous : BeamHueMode.pingPong),
      hueBase: style.hueBase ?? 0,
      staticColors: (style.staticColors ?? false) || palette.forcesStaticColors,
      cycleSeconds: cycleSeconds,
      gapSeconds: _seconds(timing.cycleGap ?? Duration.zero),
      huePeriodSeconds: _seconds(timing.huePeriod ?? variant.defaultHuePeriod),
      bloomHuePeriodSeconds: _seconds(
        timing.bloomHuePeriod ?? variant.defaultBloomHuePeriod,
      ),
      breatheFactor: timing.breatheFactor ?? _defaultBreatheFactor,
      spikeFactor: timing.spikeFactor ?? _defaultSpikeFactor,
      spike2Factor: timing.spike2Factor ?? _defaultSpike2Factor,
      strokeOpacityFactor: style.strokeOpacityFactor ?? 1,
      innerOpacityFactor: style.innerOpacityFactor ?? 1,
      bloomOpacityFactor: style.bloomOpacityFactor ?? 1,
      glowBoost: style.glowBoost ?? 1,
      coreBlur: style.coreBlur,
      bloomBlur: style.bloomBlur,
      glowBrightness: style.glowBrightness,
      glowSaturation: style.glowSaturation,
      tailLength: style.tailLength ?? 1,
      glowSpread: style.glowSpread ?? 1,
      comet: style.comet ?? false,
      sparkle: (style.sparkle ?? 0).clamp(0.0, 1.0),
      segments: style.segments,
      innerSizeScale: style.innerSizeScale ?? 1,
      renderScale: (style.renderScale ?? 1).clamp(
        _minRenderScale,
        _maxRenderScale,
      ),
      pulseOutsideTuning:
          style.pulseOutsideTuning ?? BeamPulseOutsideTuning.demo,
      edge: shape.edge ?? BeamEdge.bottom,
      ringOffset: shape.ringOffset ?? 0,
      contour: shape.contour,
      segment: shape.segment,
      wrapCorners: shape.wrapCorners ?? false,
      direction: timing.direction ?? BeamDirection.forward,
      phaseOffset: timing.phaseOffset ?? 0,
      beamCount: timing.beamCount ?? 1,
    );
  }

  /// Which effect to paint.
  final BeamVariant variant;

  /// Resolved gradient tables and mono modifiers.
  final BeamPalette palette;

  /// Theme preset (layer opacities, inset shadow, defaults).
  final BeamThemeConfig theme;

  /// Resolved brightness (dark/light) the preset was chosen for.
  final Brightness brightness;

  /// Corner radii of the beam shape in logical px — per corner, already
  /// resolved against the ambient text direction.
  final BorderRadius borderRadius;

  /// Stroke ring thickness in logical px.
  final double borderWidth;

  /// Whether to shape the beam as a rounded superellipse (squircle).
  final bool useSuperellipse;

  /// Global effect opacity multiplier, clamped 0–1.
  final double strength;

  /// Brightness filter multiplier.
  final double brightnessFactor;

  /// Saturation filter multiplier.
  final double saturation;

  /// Hue animation amplitude in degrees (rotate/small/line ping-pong).
  final double hueRange;

  /// Whether the hue swings across ±[hueRange] or revolves continuously.
  final BeamHueMode hueMode;

  /// Static hue offset in degrees added to the animated hue.
  final double hueBase;

  /// Whether hue animation is disabled.
  final bool staticColors;

  /// Seconds per animation cycle.
  final double cycleSeconds;

  /// Seconds the beam rests at the end of its travel between sweeps.
  final double gapSeconds;

  /// Seconds for one full period of the hue track.
  final double huePeriodSeconds;

  /// Seconds for one full period of the line bloom's hue track.
  final double bloomHuePeriodSeconds;

  /// The line beam's height-breathe period as a multiple of [cycleSeconds].
  final double breatheFactor;

  /// The line beam's first spike period as a multiple of [cycleSeconds].
  final double spikeFactor;

  /// The line beam's second spike period as a multiple of [cycleSeconds].
  final double spike2Factor;

  /// Stroke ring opacity multiplier hook (React `--beam-stroke-opacity`).
  final double strokeOpacityFactor;

  /// Inner glow opacity multiplier hook (React `--beam-inner-opacity`).
  final double innerOpacityFactor;

  /// Bloom opacity multiplier hook (React `--beam-bloom-opacity`).
  final double bloomOpacityFactor;

  /// Pulse glow prominence multiplier (React `--pulse-glow-boost`).
  final double glowBoost;

  /// Pulse-outside core blur override in px (React `--beam-core-blur`).
  final double? coreBlur;

  /// Pulse-outside bloom blur override in px (React `--beam-bloom-blur`).
  final double? bloomBlur;

  /// Pulse-outside glow brightness override (React `--beam-glow-brightness`).
  final double? glowBrightness;

  /// Pulse-outside glow saturation override (React `--beam-glow-saturate`).
  final double? glowSaturation;

  /// Multiplier on the angular width of the traveling window — the length of
  /// the beam's tail.
  final double tailLength;

  /// Multiplier on how far the bloom and halo layers reach past the ring.
  final double glowSpread;

  /// Whether a soft halo trails the traveling head outside the ring.
  final bool comet;

  /// Density 0–1 of the twinkles scattered at the traveling beam's head.
  final double sparkle;

  /// Number of dashes the ring is broken into, or null for a solid ring.
  final int? segments;

  /// Multiplier on the pulse-inside inner wash's blobs and corner accents.
  final double innerSizeScale;

  /// The fraction of the box the beam is painted at before being magnified
  /// back to fill it, clamped to 0.25–1.
  final double renderScale;

  /// Which pulse-outside glow geometry to paint.
  final BeamPulseOutsideTuning pulseOutsideTuning;

  /// Which edge the line variant's beam travels along.
  final BeamEdge edge;

  /// Logical px the ring sits outside (+) or inside (−) the child's bounds.
  final double ringOffset;

  /// An arbitrary contour replacing the rounded rectangle, or null to build
  /// the contour from [borderRadius] and [useSuperellipse].
  final BeamContour? contour;

  /// The visible clockwise portion of the contour, or null for the full ring.
  final BeamSegment? segment;

  /// Whether line blobs bend through corners in border-path space.
  final bool wrapCorners;

  /// Which way the beam travels around the contour.
  final BeamDirection direction;

  /// Fraction of a cycle, 0–1, the timeline starts at.
  final double phaseOffset;

  /// How many beams travel the contour at once, spaced equally along the
  /// cycle.
  final int beamCount;

  /// This config re-authored for a box [factor] the size of the real one.
  ///
  /// Only the lengths measured against the box travel with it — the corner
  /// radii, the ring's thickness, and its offset. Everything the palettes fix
  /// in absolute px (blob sizes, blur radii, corner accents) deliberately
  /// stays put: painting those at [factor] and magnifying the result back is
  /// exactly what makes a palette authored for a card read on a screen-sized
  /// box. [renderScale] is spent by the copy, so a painter cannot scale
  /// twice.
  BeamConfig scaledBy(double factor) => BeamConfig(
    variant: variant,
    palette: palette,
    theme: theme,
    brightness: brightness,
    borderRadius: borderRadius * factor,
    borderWidth: borderWidth * factor,
    useSuperellipse: useSuperellipse,
    strength: strength,
    brightnessFactor: brightnessFactor,
    saturation: saturation,
    hueRange: hueRange,
    hueBase: hueBase,
    staticColors: staticColors,
    cycleSeconds: cycleSeconds,
    hueMode: hueMode,
    huePeriodSeconds: huePeriodSeconds,
    bloomHuePeriodSeconds: bloomHuePeriodSeconds,
    gapSeconds: gapSeconds,
    breatheFactor: breatheFactor,
    spikeFactor: spikeFactor,
    spike2Factor: spike2Factor,
    strokeOpacityFactor: strokeOpacityFactor,
    innerOpacityFactor: innerOpacityFactor,
    bloomOpacityFactor: bloomOpacityFactor,
    glowBoost: glowBoost,
    coreBlur: coreBlur,
    bloomBlur: bloomBlur,
    glowBrightness: glowBrightness,
    glowSaturation: glowSaturation,
    tailLength: tailLength,
    glowSpread: glowSpread,
    comet: comet,
    sparkle: sparkle,
    segments: segments,
    innerSizeScale: innerSizeScale,
    renderScale: 1,
    pulseOutsideTuning: pulseOutsideTuning,
    edge: edge,
    ringOffset: ringOffset * factor,
    contour: contour,
    segment: segment?.scaledBy(factor),
    wrapCorners: wrapCorners,
    direction: direction,
    phaseOffset: phaseOffset,
    beamCount: beamCount,
  );

  /// Two configs are equal when every painted value is, which is what lets
  /// `BeamPainter.shouldRepaint` compare configs rather than identities.
  ///
  /// [palette] compares by identity: `BeamColors.resolve` memoizes one
  /// palette per color instance, so equal color choices reaching one widget
  /// resolve to the identical palette.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamConfig &&
          other.variant == variant &&
          other.palette == palette &&
          other.theme == theme &&
          other.brightness == brightness &&
          other.borderRadius == borderRadius &&
          other.borderWidth == borderWidth &&
          other.useSuperellipse == useSuperellipse &&
          other.strength == strength &&
          other.brightnessFactor == brightnessFactor &&
          other.saturation == saturation &&
          other.hueRange == hueRange &&
          other.hueMode == hueMode &&
          other.hueBase == hueBase &&
          other.staticColors == staticColors &&
          other.cycleSeconds == cycleSeconds &&
          other.gapSeconds == gapSeconds &&
          other.huePeriodSeconds == huePeriodSeconds &&
          other.bloomHuePeriodSeconds == bloomHuePeriodSeconds &&
          other.breatheFactor == breatheFactor &&
          other.spikeFactor == spikeFactor &&
          other.spike2Factor == spike2Factor &&
          other.strokeOpacityFactor == strokeOpacityFactor &&
          other.innerOpacityFactor == innerOpacityFactor &&
          other.bloomOpacityFactor == bloomOpacityFactor &&
          other.glowBoost == glowBoost &&
          other.coreBlur == coreBlur &&
          other.bloomBlur == bloomBlur &&
          other.glowBrightness == glowBrightness &&
          other.glowSaturation == glowSaturation &&
          other.tailLength == tailLength &&
          other.glowSpread == glowSpread &&
          other.comet == comet &&
          other.sparkle == sparkle &&
          other.segments == segments &&
          other.innerSizeScale == innerSizeScale &&
          other.renderScale == renderScale &&
          other.pulseOutsideTuning == pulseOutsideTuning &&
          other.edge == edge &&
          other.ringOffset == ringOffset &&
          other.contour == contour &&
          other.segment == segment &&
          other.wrapCorners == wrapCorners &&
          other.direction == direction &&
          other.phaseOffset == phaseOffset &&
          other.beamCount == beamCount;

  @override
  int get hashCode => Object.hashAll([
    variant,
    palette,
    theme,
    brightness,
    borderRadius,
    borderWidth,
    useSuperellipse,
    strength,
    brightnessFactor,
    saturation,
    hueRange,
    hueMode,
    hueBase,
    staticColors,
    cycleSeconds,
    gapSeconds,
    huePeriodSeconds,
    bloomHuePeriodSeconds,
    breatheFactor,
    spikeFactor,
    spike2Factor,
    strokeOpacityFactor,
    innerOpacityFactor,
    bloomOpacityFactor,
    glowBoost,
    coreBlur,
    bloomBlur,
    glowBrightness,
    glowSaturation,
    tailLength,
    glowSpread,
    comet,
    sparkle,
    segments,
    innerSizeScale,
    renderScale,
    pulseOutsideTuning,
    edge,
    ringOffset,
    contour,
    segment,
    wrapCorners,
    direction,
    phaseOffset,
    beamCount,
  ]);

  @override
  String toString() =>
      'BeamConfig($variant, $brightness, radius: $borderRadius, '
      'cycle: ${cycleSeconds}s, gap: ${gapSeconds}s, strength: $strength)';
}
