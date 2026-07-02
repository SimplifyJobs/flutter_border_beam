import 'dart:ui';

import '../models/beam_theme_config.dart';
import '../models/beam_variant.dart';

// Verbatim transcription of `sizeThemePresets` from the React library
// (border-beam v1.3.0, src/styles.ts). Do not tweak values here — visual
// parity with the source depends on them.

const Color _transparent = Color(0x00000000);

/// Per-variant, per-brightness theme presets (React `sizeThemePresets`).
const Map<BeamVariant, ({BeamThemeConfig dark, BeamThemeConfig light})>
beamThemePresets = {
  BeamVariant.small: (
    dark: BeamThemeConfig(
      strokeOpacity: 0.46,
      innerOpacity: 0.24,
      bloomOpacity: 0.38,
      innerShadow: Color.fromRGBO(255, 255, 255, 0.3),
      saturation: 1.2,
    ),
    light: BeamThemeConfig(
      strokeOpacity: 0.12,
      innerOpacity: 0.3,
      bloomOpacity: 0.16,
      innerShadow: Color.fromRGBO(0, 0, 0, 0.14),
      saturation: 1.8,
    ),
  ),
  BeamVariant.rotate: (
    dark: BeamThemeConfig(
      strokeOpacity: 0.26,
      innerOpacity: 0.42,
      bloomOpacity: 0.24,
      innerShadow: Color.fromRGBO(255, 255, 255, 0.27),
      saturation: 1.2,
    ),
    light: BeamThemeConfig(
      strokeOpacity: 0.12,
      innerOpacity: 0.26,
      bloomOpacity: 0.34,
      innerShadow: Color.fromRGBO(0, 0, 0, 0.14),
      saturation: 1.5,
    ),
  ),
  BeamVariant.line: (
    dark: BeamThemeConfig(
      strokeOpacity: 1.14,
      innerOpacity: 0.7,
      bloomOpacity: 0.8,
      innerShadow: Color.fromRGBO(255, 255, 255, 0.1),
      saturation: 1.2,
    ),
    light: BeamThemeConfig(
      strokeOpacity: 0.16,
      innerOpacity: 0.32,
      bloomOpacity: 0.3,
      innerShadow: Color.fromRGBO(0, 0, 0, 0.14),
      saturation: 1.95,
    ),
  ),
  BeamVariant.pulseOutside: (
    dark: BeamThemeConfig(
      strokeOpacity: 0.94,
      innerOpacity: 0.34,
      bloomOpacity: 0.3,
      innerShadow: _transparent,
      saturation: 1.2,
      brightness: 1.9,
      // The wrapped child supplies its own 1px border; the beam must not add
      // a second hairline on top (see React v1.1.0 changelog).
      hairlineOpacity: 0,
    ),
    light: BeamThemeConfig(
      strokeOpacity: 1.96,
      innerOpacity: 1.04,
      bloomOpacity: 0.42,
      innerShadow: _transparent,
      saturation: 0.6,
      brightness: 1.7,
      hairlineOpacity: 0,
    ),
  ),
  BeamVariant.pulseInside: (
    dark: BeamThemeConfig(
      strokeOpacity: 1.54,
      innerOpacity: 0.44,
      bloomOpacity: 0.66,
      innerShadow: _transparent,
      saturation: 1.2,
      brightness: 0.75,
    ),
    light: BeamThemeConfig(
      strokeOpacity: 0.32,
      innerOpacity: 0.4,
      bloomOpacity: 0.8,
      innerShadow: _transparent,
      saturation: 0.75,
      brightness: 1.3,
    ),
  ),
};

/// Resolves the theme preset for a variant and brightness.
BeamThemeConfig themePresetFor(BeamVariant variant, Brightness brightness) {
  final preset = beamThemePresets[variant]!;
  return brightness == Brightness.dark ? preset.dark : preset.light;
}
