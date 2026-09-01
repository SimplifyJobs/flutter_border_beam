import 'package:flutter/foundation.dart';

import 'beam_colors.dart';
import 'beam_theme.dart';
import 'beam_theme_config.dart';

/// How a beam looks: its colors, how it adapts to the background, and every
/// filter and layer-opacity hook ported from the source's CSS custom
/// properties.
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
    this.themeConfig,
  });

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
    BeamThemeConfig? themeConfig,
  }) => BeamStyle(
    colors: colors ?? this.colors,
    theme: theme ?? this.theme,
    strength: strength ?? this.strength,
    brightness: brightness ?? this.brightness,
    saturation: saturation ?? this.saturation,
    hueRange: hueRange ?? this.hueRange,
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
          other.themeConfig == themeConfig;

  @override
  int get hashCode => Object.hashAll([
    colors,
    theme,
    strength,
    brightness,
    saturation,
    hueRange,
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
      if (themeConfig != null) 'themeConfig: $themeConfig',
    ];
    return 'BeamStyle(${fields.join(', ')})';
  }
}
