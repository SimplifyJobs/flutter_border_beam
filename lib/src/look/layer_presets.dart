import 'dart:ui';

import 'package:flutter/foundation.dart';

// How strongly each effect family paints its three layers on a dark and on a
// light surface, and the colour filter (brightness, saturation) its layers
// run through. Opacities may exceed 1 — the product with the fade and the
// palette is clamped when the frame is painted.

/// One family's layer tuning for one surface brightness.
@immutable
class BeamLayerPreset {
  /// Creates a preset.
  const BeamLayerPreset({
    required this.strokeOpacity,
    required this.innerOpacity,
    required this.bloomOpacity,
    required this.innerShadow,
    required this.saturation,
    this.brightness = 1.3,
  });

  /// Opacity of the hairline stroke layer.
  final double strokeOpacity;

  /// Opacity of the inner glow layer.
  final double innerOpacity;

  /// Opacity of the bloom layer.
  final double bloomOpacity;

  /// Colour of the inner glow's inset shadow (transparent for none).
  final Color innerShadow;

  /// Saturation of the layers' colour filter.
  final double saturation;

  /// Brightness of the layers' colour filter.
  final double brightness;
}

/// A dark/light pair of presets.
typedef BeamLayerPresets = ({BeamLayerPreset dark, BeamLayerPreset light});

const Color _transparent = Color(0x00000000);

/// The travelling beam on a compact chip.
const BeamLayerPresets compactPresets = (
  dark: BeamLayerPreset(
    strokeOpacity: 0.46,
    innerOpacity: 0.24,
    bloomOpacity: 0.38,
    innerShadow: Color.fromRGBO(255, 255, 255, 0.3),
    saturation: 1.2,
  ),
  light: BeamLayerPreset(
    strokeOpacity: 0.12,
    innerOpacity: 0.3,
    bloomOpacity: 0.16,
    innerShadow: Color.fromRGBO(0, 0, 0, 0.14),
    saturation: 1.8,
  ),
);

/// The travelling beam on a card or panel.
const BeamLayerPresets rotatePresets = (
  dark: BeamLayerPreset(
    strokeOpacity: 0.26,
    innerOpacity: 0.42,
    bloomOpacity: 0.24,
    innerShadow: Color.fromRGBO(255, 255, 255, 0.27),
    saturation: 1.2,
  ),
  light: BeamLayerPreset(
    strokeOpacity: 0.12,
    innerOpacity: 0.26,
    bloomOpacity: 0.34,
    innerShadow: Color.fromRGBO(0, 0, 0, 0.14),
    saturation: 1.5,
  ),
);

/// The edge-riding streak.
const BeamLayerPresets linePresets = (
  dark: BeamLayerPreset(
    strokeOpacity: 1.14,
    innerOpacity: 0.7,
    bloomOpacity: 0.8,
    innerShadow: Color.fromRGBO(255, 255, 255, 0.1),
    saturation: 1.2,
  ),
  light: BeamLayerPreset(
    strokeOpacity: 0.16,
    innerOpacity: 0.32,
    bloomOpacity: 0.3,
    innerShadow: Color.fromRGBO(0, 0, 0, 0.14),
    saturation: 1.95,
  ),
);

/// The outward halo.
const BeamLayerPresets haloPresets = (
  dark: BeamLayerPreset(
    strokeOpacity: 0.94,
    innerOpacity: 0.34,
    bloomOpacity: 0.3,
    innerShadow: _transparent,
    saturation: 1.2,
    brightness: 1.9,
  ),
  light: BeamLayerPreset(
    strokeOpacity: 1.96,
    innerOpacity: 1.04,
    bloomOpacity: 0.42,
    innerShadow: _transparent,
    saturation: 0.6,
    brightness: 1.7,
  ),
);

/// The inward pulse.
const BeamLayerPresets pulsePresets = (
  dark: BeamLayerPreset(
    strokeOpacity: 1.54,
    innerOpacity: 0.44,
    bloomOpacity: 0.66,
    innerShadow: _transparent,
    saturation: 1.2,
    brightness: 0.75,
  ),
  light: BeamLayerPreset(
    strokeOpacity: 0.32,
    innerOpacity: 0.4,
    bloomOpacity: 0.8,
    innerShadow: _transparent,
    saturation: 0.75,
    brightness: 1.3,
  ),
);

/// Picks the preset for a surface.
BeamLayerPreset presetFor(BeamLayerPresets presets, {required bool dark}) =>
    dark ? presets.dark : presets.light;
