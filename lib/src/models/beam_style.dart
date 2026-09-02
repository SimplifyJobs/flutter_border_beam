import 'package:flutter/foundation.dart';

import '../constants/pulse_constants.dart';
import 'beam_colors.dart';
import 'beam_options.dart';
import 'beam_theme.dart';
import 'beam_theme_config.dart';

/// How a beam looks: its colors, how it adapts to the background, the shape
/// of its beam and glow, and every filter and layer-opacity hook ported from
/// the source's CSS custom properties.
///
/// Every field is nullable and means *inherit*. A field is resolved in this
/// order: the value set on the widget (a shorthand such as `colors:` wins
/// over the same field of the widget's own style), then the nearest
/// `BorderBeamTheme`, then the variant's preset.
///
/// ```dart
/// BorderBeam.rotate(
///   style: const BeamStyle(colors: BeamColors.ocean, strength: 0.6),
///   child: card,
/// )
/// ```
@immutable
class BeamStyle {
  /// Creates a style. Every omitted field is inherited.
  const BeamStyle({
    this.colors,
    this.theme,
    this.strength,
    this.brightness,
    this.saturation,
    this.hueRange,
    this.hueMode,
    this.hueBase,
    this.staticColors,
    this.strokeOpacityFactor,
    this.innerOpacityFactor,
    this.bloomOpacityFactor,
    this.glowBoost,
    this.coreBlur,
    this.bloomBlur,
    this.glowBrightness,
    this.glowSaturation,
    this.tailLength,
    this.glowSpread,
    this.comet,
    this.sparkle,
    this.segments,
    this.innerSizeScale,
    this.renderScale,
    this.pulseOutsideTuning,
    this.themeConfig,
  });

  /// The pulse-outside look as the React library ships it, before the demo
  /// page's tuning.
  ///
  /// `BorderBeam.pulseOutside` paints the tuned demo recipe by default — the
  /// look beam.jakubantalik.com is known for. This style rolls every part of
  /// that tuning back: the prominence boost and the glow multiplier through
  /// the hooks that carry them ([glowBoost], the three opacity factors, and
  /// [glowBrightness]/[glowSaturation]), and the glow's insets, blurs, and
  /// size-derived unit through [pulseOutsideTuning].
  ///
  /// The result is a tighter, dimmer halo that sits closer to the child.
  ///
  /// ```dart
  /// BorderBeam.pulseOutside(
  ///   style: BeamStyle.pulseOutsideStock,
  ///   child: card,
  /// )
  /// ```
  ///
  /// Layer your own fields over it with [copyWith] or [merge]; anything you
  /// set wins, so `BeamStyle.pulseOutsideStock.copyWith(glowBoost: 1.4)`
  /// keeps the stock geometry and pushes the blobs back out.
  static const BeamStyle pulseOutsideStock = BeamStyle(
    strokeOpacityFactor: 1 / pulseOuterTunedGlowMultiplier,
    innerOpacityFactor: 1 / pulseOuterTunedGlowMultiplier,
    bloomOpacityFactor: 1 / pulseOuterTunedGlowMultiplier,
    glowBoost: 1 / pulseOuterTunedBoost,
    glowBrightness: pulseOuterGlowBrightness,
    glowSaturation: pulseOuterGlowSaturation,
    pulseOutsideTuning: BeamPulseOutsideTuning.stock,
  );

  /// Color scheme: a preset, [BeamColors.custom], or [BeamColors.spec].
  /// Defaults to [BeamColors.colorful].
  final BeamColors? colors;

  /// Background adaptation: dark, light, or follow the ambient theme.
  /// Defaults to [BeamTheme.auto].
  final BeamTheme? theme;

  /// Effect opacity 0–1 (clamped). Scales only the beam layers. Default 1.
  final double? strength;

  /// Glow brightness multiplier; inherits the variant/theme preset.
  final double? brightness;

  /// Glow saturation multiplier; inherits the variant/theme preset.
  final double? saturation;

  /// Hue animation amplitude in degrees (default 30; the line variant caps it
  /// at 13). Not used by pulse variants, whose hue cycles continuously.
  final double? hueRange;

  /// Whether the hue swings back and forth across ±[hueRange] or advances
  /// through one continuous 360° revolution.
  ///
  /// Defaults to [BeamHueMode.pingPong] for the traveling variants and
  /// [BeamHueMode.continuous] for the pulse variants, matching the source.
  final BeamHueMode? hueMode;

  /// Static hue offset in degrees added to the whole palette. Default 0.
  final double? hueBase;

  /// Disables the hue animation. Default false; forced on by
  /// [BeamColors.mono].
  final bool? staticColors;

  /// Stroke ring opacity multiplier (React `--beam-stroke-opacity`).
  /// Default 1.
  final double? strokeOpacityFactor;

  /// Inner glow opacity multiplier (React `--beam-inner-opacity`). Default 1.
  final double? innerOpacityFactor;

  /// Bloom opacity multiplier (React `--beam-bloom-opacity`). Default 1.
  final double? bloomOpacityFactor;

  /// Pulse glow prominence multiplier (React `--pulse-glow-boost`).
  /// Default 1.
  final double? glowBoost;

  /// pulse-outside core glow blur override in px (React `--beam-core-blur`).
  final double? coreBlur;

  /// pulse-outside halo blur override in px (React `--beam-bloom-blur`).
  final double? bloomBlur;

  /// pulse-outside glow brightness override
  /// (React `--beam-glow-brightness`).
  final double? glowBrightness;

  /// pulse-outside glow saturation override (React `--beam-glow-saturate`).
  final double? glowSaturation;

  /// Multiplier on the angular width of the rotate/small traveling window:
  /// above 1 the beam drags a longer tail behind its head, below 1 it
  /// shortens to a point. Default 1.
  final double? tailLength;

  /// Multiplier on how far the bloom and halo layers reach past the stroke
  /// ring: above 1 the glow spreads wider and softer, below 1 it hugs the
  /// border. Default 1.
  final double? glowSpread;

  /// Whether a soft halo trails the traveling head outside the ring, giving
  /// the rotate and small beams a comet tail. Default false.
  final bool? comet;

  /// Density 0–1 (clamped) of the twinkles scattered at the traveling beam's
  /// head. Default 0 — no sparkle.
  final double? sparkle;

  /// Number of dashes the ring is broken into, spaced evenly around the
  /// contour. Null (the default) keeps the ring solid.
  final int? segments;

  /// Multiplier on the size of the pulse-inside inner wash — its blobs and
  /// its corner accents. Default 1.
  ///
  /// Below 1 the wash pulls tighter to the border, leaving more of the child
  /// clear; above 1 it floods further in. The perimeter ring and the bloom
  /// keep their own geometry, so the border itself does not move.
  ///
  /// Only `BeamVariant.pulseInside` paints that layer; every other variant
  /// ignores this.
  final double? innerSizeScale;

  /// The fraction of the box the beam is *painted* at before being scaled
  /// back up to fill it, 0.25–1 (clamped). Default 1 — no rescaling.
  ///
  /// The palettes are authored against a 350×140 card, so on a
  /// screen-width box the blobs read as small and sparse. Painting at, say,
  /// `0.5` and magnifying restores the proportions the palette was drawn
  /// for: the glow, its blurs, and the corner radii all grow together, so
  /// the beam reads the same at any size.
  ///
  /// It costs nothing — one canvas transform, no extra layer — but it is a
  /// magnification, so the ring's own edge softens as the factor drops.
  final double? renderScale;

  /// Which pulse-outside glow geometry to paint: the demo recipe (the
  /// default) or the source's stock table.
  ///
  /// [BeamStyle.pulseOutsideStock] is the whole stock look; this field alone
  /// changes only the insets and blurs.
  final BeamPulseOutsideTuning? pulseOutsideTuning;

  /// Replaces the whole variant×brightness preset (layer opacities, inset
  /// shadow, and the default brightness/saturation) with your own.
  ///
  /// [brightness] and [saturation] still override on top of it. Start from
  /// [BeamThemeConfig.presetFor] to tweak a single field of a preset.
  final BeamThemeConfig? themeConfig;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamStyle] to clear a field back to inherit.
  BeamStyle copyWith({
    BeamColors? colors,
    BeamTheme? theme,
    double? strength,
    double? brightness,
    double? saturation,
    double? hueRange,
    BeamHueMode? hueMode,
    double? hueBase,
    bool? staticColors,
    double? strokeOpacityFactor,
    double? innerOpacityFactor,
    double? bloomOpacityFactor,
    double? glowBoost,
    double? coreBlur,
    double? bloomBlur,
    double? glowBrightness,
    double? glowSaturation,
    double? tailLength,
    double? glowSpread,
    bool? comet,
    double? sparkle,
    int? segments,
    double? innerSizeScale,
    double? renderScale,
    BeamPulseOutsideTuning? pulseOutsideTuning,
    BeamThemeConfig? themeConfig,
  }) => BeamStyle(
    colors: colors ?? this.colors,
    theme: theme ?? this.theme,
    strength: strength ?? this.strength,
    brightness: brightness ?? this.brightness,
    saturation: saturation ?? this.saturation,
    hueRange: hueRange ?? this.hueRange,
    hueMode: hueMode ?? this.hueMode,
    hueBase: hueBase ?? this.hueBase,
    staticColors: staticColors ?? this.staticColors,
    strokeOpacityFactor: strokeOpacityFactor ?? this.strokeOpacityFactor,
    innerOpacityFactor: innerOpacityFactor ?? this.innerOpacityFactor,
    bloomOpacityFactor: bloomOpacityFactor ?? this.bloomOpacityFactor,
    glowBoost: glowBoost ?? this.glowBoost,
    coreBlur: coreBlur ?? this.coreBlur,
    bloomBlur: bloomBlur ?? this.bloomBlur,
    glowBrightness: glowBrightness ?? this.glowBrightness,
    glowSaturation: glowSaturation ?? this.glowSaturation,
    tailLength: tailLength ?? this.tailLength,
    glowSpread: glowSpread ?? this.glowSpread,
    comet: comet ?? this.comet,
    sparkle: sparkle ?? this.sparkle,
    segments: segments ?? this.segments,
    innerSizeScale: innerSizeScale ?? this.innerSizeScale,
    renderScale: renderScale ?? this.renderScale,
    pulseOutsideTuning: pulseOutsideTuning ?? this.pulseOutsideTuning,
    themeConfig: themeConfig ?? this.themeConfig,
  );

  /// Layers [other] over this style: every non-null field of [other] wins,
  /// every null one inherits from this style.
  BeamStyle merge(BeamStyle? other) => other == null
      ? this
      : copyWith(
          colors: other.colors,
          theme: other.theme,
          strength: other.strength,
          brightness: other.brightness,
          saturation: other.saturation,
          hueRange: other.hueRange,
          hueMode: other.hueMode,
          hueBase: other.hueBase,
          staticColors: other.staticColors,
          strokeOpacityFactor: other.strokeOpacityFactor,
          innerOpacityFactor: other.innerOpacityFactor,
          bloomOpacityFactor: other.bloomOpacityFactor,
          glowBoost: other.glowBoost,
          coreBlur: other.coreBlur,
          bloomBlur: other.bloomBlur,
          glowBrightness: other.glowBrightness,
          glowSaturation: other.glowSaturation,
          tailLength: other.tailLength,
          glowSpread: other.glowSpread,
          comet: other.comet,
          sparkle: other.sparkle,
          segments: other.segments,
          innerSizeScale: other.innerSizeScale,
          renderScale: other.renderScale,
          pulseOutsideTuning: other.pulseOutsideTuning,
          themeConfig: other.themeConfig,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamStyle &&
          other.colors == colors &&
          other.theme == theme &&
          other.strength == strength &&
          other.brightness == brightness &&
          other.saturation == saturation &&
          other.hueRange == hueRange &&
          other.hueMode == hueMode &&
          other.hueBase == hueBase &&
          other.staticColors == staticColors &&
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
          other.themeConfig == themeConfig;

  @override
  int get hashCode => Object.hashAll([
    colors,
    theme,
    strength,
    brightness,
    saturation,
    hueRange,
    hueMode,
    hueBase,
    staticColors,
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
    themeConfig,
  ]);

  @override
  String toString() {
    final fields = <String>[
      if (colors != null) 'colors: $colors',
      if (theme != null) 'theme: $theme',
      if (strength != null) 'strength: $strength',
      if (brightness != null) 'brightness: $brightness',
      if (saturation != null) 'saturation: $saturation',
      if (hueRange != null) 'hueRange: $hueRange',
      if (hueMode != null) 'hueMode: $hueMode',
      if (hueBase != null) 'hueBase: $hueBase',
      if (staticColors != null) 'staticColors: $staticColors',
      if (strokeOpacityFactor != null)
        'strokeOpacityFactor: $strokeOpacityFactor',
      if (innerOpacityFactor != null) 'innerOpacityFactor: $innerOpacityFactor',
      if (bloomOpacityFactor != null) 'bloomOpacityFactor: $bloomOpacityFactor',
      if (glowBoost != null) 'glowBoost: $glowBoost',
      if (coreBlur != null) 'coreBlur: $coreBlur',
      if (bloomBlur != null) 'bloomBlur: $bloomBlur',
      if (glowBrightness != null) 'glowBrightness: $glowBrightness',
      if (glowSaturation != null) 'glowSaturation: $glowSaturation',
      if (tailLength != null) 'tailLength: $tailLength',
      if (glowSpread != null) 'glowSpread: $glowSpread',
      if (comet != null) 'comet: $comet',
      if (sparkle != null) 'sparkle: $sparkle',
      if (segments != null) 'segments: $segments',
      if (innerSizeScale != null) 'innerSizeScale: $innerSizeScale',
      if (renderScale != null) 'renderScale: $renderScale',
      if (pulseOutsideTuning != null) 'pulseOutsideTuning: $pulseOutsideTuning',
      if (themeConfig != null) 'themeConfig: $themeConfig',
    ];
    return 'BeamStyle(${fields.join(', ')})';
  }
}
