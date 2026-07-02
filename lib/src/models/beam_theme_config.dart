import 'dart:ui';

/// Theme-and-variant-tuned layer opacities and filter multipliers.
///
/// Direct port of the React library's `ThemeColors` entries in
/// `sizeThemePresets`: each beam variant has one config per brightness.
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
}
