import '../constants/palettes.dart';

/// A fully-resolved palette: the gradient-table bundle plus the paint-time
/// modifiers a color choice implies.
///
/// Produced by [BeamColors.resolve] — strategies read tables from [data] and
/// apply [opacityMultiplier] / [monoTreatment].
class BeamPalette {
  /// Creates a resolved palette.
  const BeamPalette({
    required this.data,
    this.forcesStaticColors = false,
    this.opacityMultiplier = 1.0,
    this.monoTreatment = false,
  });

  /// The gradient tables (border blobs, small tables, line tables, spikes).
  final BeamPresetData data;

  /// Whether hue animation must be disabled (mono preset).
  final bool forcesStaticColors;

  /// Layer opacity multiplier (0.5 for mono on rotate/small/pulse variants;
  /// the line variant ignores this and uses [monoTreatment] instead).
  final double opacityMultiplier;

  /// Whether the line variant applies its grayscale spike attenuation
  /// (alpha rescale, wider/shorter spikes, extra bloom blur).
  final bool monoTreatment;
}
