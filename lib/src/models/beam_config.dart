import 'dart:ui';

import '../constants/theme_presets.dart';
import 'beam_palette.dart';
import 'beam_theme_config.dart';
import 'beam_variant.dart';

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
    this.strokeOpacityFactor = 1,
    this.innerOpacityFactor = 1,
    this.bloomOpacityFactor = 1,
    this.glowBoost = 1,
    this.coreBlur,
    this.bloomBlur,
    this.glowBrightness,
    this.glowSaturation,
  });

  /// Resolves user-facing parameters (nullable overrides) against the
  /// variant/theme presets, mirroring the React component's computed values.
  factory BeamConfig.resolve({
    required BeamVariant variant,
    required BeamPalette palette,
    required Brightness brightness,
    double? borderRadius,
    double? borderWidth,
    bool useSuperellipse = false,
    double strength = 1,
    double? brightnessFactor,
    double? saturation,
    double hueRange = 30,
    double hueBase = 0,
    bool staticColors = false,
    Duration? cycleDuration,
    double strokeOpacityFactor = 1,
    double innerOpacityFactor = 1,
    double bloomOpacityFactor = 1,
    double glowBoost = 1,
    double? coreBlur,
    double? bloomBlur,
    double? glowBrightness,
    double? glowSaturation,
  }) {
    final theme = themePresetFor(variant, brightness);
    return BeamConfig(
      variant: variant,
      palette: palette,
      theme: theme,
      brightness: brightness,
      borderRadius: borderRadius ?? variant.defaultBorderRadius,
      borderWidth: borderWidth ?? variant.defaultBorderWidth,
      useSuperellipse: useSuperellipse,
      strength: strength.clamp(0.0, 1.0),
      brightnessFactor: brightnessFactor ?? theme.brightness ?? 1.3,
      saturation: saturation ?? theme.saturation,
      // The line variant caps the hue range at 13°, as in the source.
      hueRange: variant == BeamVariant.line
          ? (hueRange > 13 ? 13.0 : hueRange)
          : hueRange,
      hueBase: hueBase,
      staticColors: staticColors || palette.forcesStaticColors,
      cycleSeconds:
          (cycleDuration ?? variant.defaultCycleDuration).inMicroseconds /
          Duration.microsecondsPerSecond,
      strokeOpacityFactor: strokeOpacityFactor,
      innerOpacityFactor: innerOpacityFactor,
      bloomOpacityFactor: bloomOpacityFactor,
      glowBoost: glowBoost,
      coreBlur: coreBlur,
      bloomBlur: bloomBlur,
      glowBrightness: glowBrightness,
      glowSaturation: glowSaturation,
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

  /// Corner radius of the beam shape in logical px.
  final double borderRadius;

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

  /// Static hue offset in degrees added to the animated hue.
  final double hueBase;

  /// Whether hue animation is disabled.
  final bool staticColors;

  /// Seconds per animation cycle.
  final double cycleSeconds;

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
}
