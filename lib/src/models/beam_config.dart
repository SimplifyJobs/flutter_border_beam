import 'dart:ui';

import 'package:flutter/painting.dart';

import '../constants/pulse_params.dart';
import 'beam_palette.dart';
import 'beam_shape.dart';
import 'beam_style.dart';
import 'beam_theme_config.dart';
import 'beam_timing.dart';
import 'beam_variant.dart';

// The hue ping-pong period of the traveling variants (React
// `beam-hue-shift`, 12s) and the line bloom's own hue period (8s).
const double _defaultHuePeriodSeconds = 12;
const double _defaultBloomHuePeriodSeconds = 8;

// The line variant's breathe/spike tracks run at multiples of the cycle.
const double _defaultBreatheFactor = 1.3;
const double _defaultSpikeFactor = 1.33;
const double _defaultSpike2Factor = 1.7;

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
    this.gapSeconds = 0,
    this.huePeriodSeconds = _defaultHuePeriodSeconds,
    this.bloomHuePeriodSeconds = _defaultBloomHuePeriodSeconds,
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
      hueBase: style.hueBase ?? 0,
      staticColors: (style.staticColors ?? false) || palette.forcesStaticColors,
      cycleSeconds: cycleSeconds,
      gapSeconds: _seconds(timing.cycleGap ?? Duration.zero),
      huePeriodSeconds: timing.huePeriod != null
          ? _seconds(timing.huePeriod!)
          : _defaultHuePeriod(variant, brightness, cycleSeconds),
      bloomHuePeriodSeconds: timing.bloomHuePeriod != null
          ? _seconds(timing.bloomHuePeriod!)
          : _defaultBloomHuePeriodSeconds,
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
    );
  }

  // The traveling variants ping-pong their hue over a fixed 12s; the pulse
  // variants revolve over the period their own preset carries.
  static double _defaultHuePeriod(
    BeamVariant variant,
    Brightness brightness,
    double cycleSeconds,
  ) => variant.isPulse
      ? PulseParams.resolve(variant, brightness, cycleSeconds).huePeriod
      : _defaultHuePeriodSeconds;

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
          other.glowSaturation == glowSaturation;

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
  ]);

  @override
  String toString() =>
      'BeamConfig($variant, $brightness, radius: $borderRadius, '
      'cycle: ${cycleSeconds}s, gap: ${gapSeconds}s, strength: $strength)';
}
