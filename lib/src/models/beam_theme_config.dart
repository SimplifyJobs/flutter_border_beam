import 'dart:ui';

import '../constants/theme_presets.dart';
import 'beam_variant.dart';

/// Theme-and-variant-tuned layer opacities and filter multipliers.
///
/// Direct port of the React library's `ThemeColors` entries in
/// `sizeThemePresets`: each beam variant has one config per brightness. Reach
/// for [presetFor] to start from a built-in preset, [copyWith] the one field
/// you want moved, and hand the result to `BeamStyle.themeConfig`.
///
/// ```dart
/// BorderBeam.rotate(
///   style: BeamStyle(
///     themeConfig: BeamThemeConfig.presetFor(
///       BeamVariant.rotate,
///       Brightness.dark,
///     ).copyWith(bloomOpacity: 0.4),
///   ),
///   child: card,
/// )
/// ```
class BeamThemeConfig {
  /// Creates a theme config.
  const BeamThemeConfig({
    required this.strokeOpacity,
    required this.innerOpacity,
    required this.bloomOpacity,
    required this.innerShadow,
    required this.saturation,
    this.brightness,
    this.hairlineOpacity,
  });

  /// The built-in preset for [variant] at [brightness].
  static BeamThemeConfig presetFor(
    BeamVariant variant,
    Brightness brightness,
  ) => themePresetFor(variant, brightness);

  /// Opacity of the stroke ring layer. May exceed 1 (intentional overdrive
  /// in the source, e.g. line/dark = 1.14); the painted product is clamped.
  final double strokeOpacity;

  /// Opacity of the inner glow layer.
  final double innerOpacity;

  /// Opacity of the bloom layer.
  final double bloomOpacity;

  /// Color of the inset shadow on the inner glow layer
  /// ([Color(0x00000000)] i.e. transparent for pulse variants).
  final Color innerShadow;

  /// Default saturation filter multiplier.
  final double saturation;

  /// Default brightness filter multiplier; null falls back to 1.3.
  final double? brightness;

  /// Opacity of the static 1px hairline (pulse-outside only; preset 0 so the
  /// wrapped child's own border provides the idle edge).
  final double? hairlineOpacity;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value.
  BeamThemeConfig copyWith({
    double? strokeOpacity,
    double? innerOpacity,
    double? bloomOpacity,
    Color? innerShadow,
    double? saturation,
    double? brightness,
    double? hairlineOpacity,
  }) => BeamThemeConfig(
    strokeOpacity: strokeOpacity ?? this.strokeOpacity,
    innerOpacity: innerOpacity ?? this.innerOpacity,
    bloomOpacity: bloomOpacity ?? this.bloomOpacity,
    innerShadow: innerShadow ?? this.innerShadow,
    saturation: saturation ?? this.saturation,
    brightness: brightness ?? this.brightness,
    hairlineOpacity: hairlineOpacity ?? this.hairlineOpacity,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamThemeConfig &&
          other.strokeOpacity == strokeOpacity &&
          other.innerOpacity == innerOpacity &&
          other.bloomOpacity == bloomOpacity &&
          other.innerShadow == innerShadow &&
          other.saturation == saturation &&
          other.brightness == brightness &&
          other.hairlineOpacity == hairlineOpacity;

  @override
  int get hashCode => Object.hash(
    strokeOpacity,
    innerOpacity,
    bloomOpacity,
    innerShadow,
    saturation,
    brightness,
    hairlineOpacity,
  );

  @override
  String toString() =>
      'BeamThemeConfig(strokeOpacity: $strokeOpacity, '
      'innerOpacity: $innerOpacity, bloomOpacity: $bloomOpacity, '
      'innerShadow: $innerShadow, saturation: $saturation, '
      'brightness: $brightness, hairlineOpacity: $hairlineOpacity)';
}
