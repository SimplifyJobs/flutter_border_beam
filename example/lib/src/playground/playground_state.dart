import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

/// The palette choices the playground offers: the four presets plus a
/// user-assembled [BeamColors.custom] list.
enum PalettePreset {
  /// [BeamColors.colorful] — the package default.
  colorful('Colorful', 'colorful', BeamColors.colorful),

  /// [BeamColors.mono].
  mono('Mono', 'mono', BeamColors.mono),

  /// [BeamColors.ocean].
  ocean('Ocean', 'ocean', BeamColors.ocean),

  /// [BeamColors.sunset].
  sunset('Sunset', 'sunset', BeamColors.sunset),

  /// Colors picked from [customSwatches]; [colors] is null because the list
  /// is built from the playground state.
  custom('Custom', 'custom', null);

  const PalettePreset(this.label, this.id, this.colors);

  /// Chip label.
  final String label;

  /// Stable id used by the share codec and the generated snippet.
  final String id;

  /// The preset this choice maps to, or null for [PalettePreset.custom].
  final BeamColors? colors;
}

/// One entry of the custom-color picker: a name for the control and the
/// color the snippet emits.
typedef Swatch = ({String name, Color color});

/// The fixed palette the custom-colors control picks from — a small preset
/// list rather than a full color picker, which keeps the state shareable as
/// a handful of indices.
const List<Swatch> customSwatches = [
  (name: 'Pink', color: Color(0xFFFF0080)),
  (name: 'Cyan', color: Color(0xFF00E5FF)),
  (name: 'Amber', color: Color(0xFFFFC400)),
  (name: 'Violet', color: Color(0xFF7C4DFF)),
  (name: 'Lime', color: Color(0xFFA6FF00)),
  (name: 'Red', color: Color(0xFFFF3D00)),
  (name: 'Teal', color: Color(0xFF1DE9B6)),
  (name: 'Blue', color: Color(0xFF2979FF)),
];

/// Smallest and largest number of colors [BeamColors.custom] may be given
/// from the picker.
const int minCustomColors = 2;

/// Largest number of colors the custom picker accepts.
const int maxCustomColors = 4;

/// Every knob the playground drives, in one mutable bag.
///
/// A freshly constructed instance is the "all defaults" configuration: every
/// field holds the value the package would resolve on its own, so the
/// snippet generator and the live preview can both emit *only* what differs
/// from it. Fields whose package default depends on the variant or on a
/// theme preset are nullable, and null means "let the package decide".
class PlaygroundState {
  /// Creates the all-defaults state.
  PlaygroundState();

  // ─── Variant & colors ───────────────────────────────────────────────────

  /// Which effect the preview paints.
  BeamVariant variant = BeamVariant.rotate;

  /// Selected palette.
  PalettePreset palette = PalettePreset.colorful;

  /// Indices into [customSwatches] used when [palette] is
  /// [PalettePreset.custom].
  List<int> customColors = [0, 1];

  // ─── Shape ──────────────────────────────────────────────────────────────

  /// Whether the contour is a pill ([BeamShape.stadium]).
  bool stadium = false;

  /// Whether the four corners are set individually.
  bool perCorner = false;

  /// Uniform corner radius, used when [perCorner] and [stadium] are false.
  double radius = 16;

  /// Top-left radius in per-corner mode.
  double radiusTopLeft = 16;

  /// Top-right radius in per-corner mode.
  double radiusTopRight = 16;

  /// Bottom-right radius in per-corner mode.
  double radiusBottomRight = 16;

  /// Bottom-left radius in per-corner mode.
  double radiusBottomLeft = 16;

  /// Whether the contour uses superellipse corners.
  bool superellipse = false;

  /// Stroke ring thickness in logical px.
  double borderWidth = 1;

  // ─── Timing ─────────────────────────────────────────────────────────────

  /// Cycle length in seconds; null keeps the variant preset.
  double? cycleSeconds;

  /// Rest between sweeps in seconds.
  double cycleGapSeconds = 0;

  /// Declarative playback rate. Ignored in [controllerMode].
  double speed = 1;

  /// Hue track period in seconds; null keeps the variant preset.
  double? huePeriodSeconds;

  /// The line beam's breathe period, as a multiple of the cycle.
  double breatheFactor = 1.3;

  /// The line beam's first spike period, as a multiple of the cycle.
  double spikeFactor = 1.33;

  /// The line beam's second spike period, as a multiple of the cycle.
  double spike2Factor = 1.7;

  /// Whether the hue animation is disabled.
  bool staticColors = false;

  // ─── Style ──────────────────────────────────────────────────────────────

  /// Effect opacity, 0–1.
  double strength = 1;

  /// Glow brightness multiplier; null keeps the theme preset.
  double? brightness;

  /// Glow saturation multiplier; null keeps the theme preset.
  double? saturation;

  /// Hue animation amplitude in degrees.
  double hueRange = 30;

  /// Static hue offset in degrees.
  double hueBase = 0;

  /// Stroke ring opacity multiplier.
  double strokeOpacityFactor = 1;

  /// Inner glow opacity multiplier.
  double innerOpacityFactor = 1;

  /// Bloom opacity multiplier.
  double bloomOpacityFactor = 1;

  /// Pulse glow prominence multiplier.
  double glowBoost = 1;

  /// pulse-outside core blur override in px; null keeps the preset.
  double? coreBlur;

  /// pulse-outside halo blur override in px; null keeps the preset.
  double? bloomBlur;

  /// pulse-outside glow brightness override; null keeps the preset.
  double? glowBrightness;

  /// pulse-outside glow saturation override; null keeps the preset.
  double? glowSaturation;

  // ─── Playback ───────────────────────────────────────────────────────────

  /// Declarative play state. Ignored in [controllerMode].
  bool active = true;

  /// Whether a [BorderBeamController] drives playback instead of the
  /// declarative fields.
  bool controllerMode = false;

  /// The controller's playback rate, used in [controllerMode].
  double controllerSpeed = 1;

  /// Autoplay delay in seconds; 0 means none.
  double startAfterSeconds = 0;

  /// Total play time in seconds; 0 means forever.
  double durationSeconds = 0;

  // ─── Theme demo ─────────────────────────────────────────────────────────

  /// Whether the preview sits inside a [BorderBeamTheme] supplying ocean +
  /// squircle-20 defaults, so fields left at their default inherit from it.
  bool themeDemo = false;

  // ─── Derived values ─────────────────────────────────────────────────────

  /// The colors this state selects.
  BeamColors get beamColors =>
      palette.colors ??
      BeamColors.custom([
        for (final i in customColors) customSwatches[i].color,
      ]);

  /// Whether the palette differs from the package default.
  bool get hasColors => palette != PalettePreset.colorful;

  /// The uniform radius the package would resolve on its own.
  double get defaultRadius => variant.defaultBorderRadius;

  /// The cycle length in seconds the package would resolve on its own.
  double get defaultCycleSeconds =>
      variant.defaultCycleDuration.inMilliseconds / 1000;

  /// The hue period in seconds the package would resolve on its own — 12s
  /// for the traveling variants, and the pulse presets' own periods.
  double get defaultHuePeriodSeconds => switch (variant) {
    BeamVariant.pulseInside => 16,
    BeamVariant.pulseOutside => 14,
    _ => 12,
  };

  /// The brightness multiplier the preset carries for [variant] at
  /// [themeBrightness].
  double defaultBrightness(Brightness themeBrightness) =>
      BeamThemeConfig.presetFor(variant, themeBrightness).brightness ?? 1.3;

  /// The saturation multiplier the preset carries for [variant] at
  /// [themeBrightness].
  double defaultSaturation(Brightness themeBrightness) =>
      BeamThemeConfig.presetFor(variant, themeBrightness).saturation;

  /// The corner radii the beam contour uses, per-corner mode included.
  /// Stadium corners are infinite and clamped per corner by the ring
  /// geometry, which is what makes them track the box.
  BorderRadius get borderRadius => stadium
      ? const BorderRadius.all(Radius.circular(double.infinity))
      : perCorner
      ? BorderRadius.only(
          topLeft: Radius.circular(radiusTopLeft),
          topRight: Radius.circular(radiusTopRight),
          bottomRight: Radius.circular(radiusBottomRight),
          bottomLeft: Radius.circular(radiusBottomLeft),
        )
      : BorderRadius.circular(radius);

  /// The same contour, sized for a concrete [size] — the preview surface's
  /// own decoration needs finite stadium radii.
  BorderRadius resolvedBorderRadius(Size size) => stadium
      ? BorderRadius.circular(
          (size.shortestSide / 2).clamp(0.0, double.maxFinite),
        )
      : borderRadius;

  /// Whether the shape differs from what the package would resolve.
  bool get hasShape =>
      stadium ||
      perCorner ||
      superellipse ||
      radius != defaultRadius ||
      borderWidth != 1;

  // ─── Value objects ──────────────────────────────────────────────────────

  /// The [BeamShape] to hand the widget, or null when nothing differs from
  /// the package default.
  BeamShape? buildShape() {
    if (!hasShape) return null;
    final width = borderWidth == 1 ? null : borderWidth;
    final se = superellipse ? true : null;
    if (stadium) return BeamShape.stadium(borderWidth: width, superellipse: se);
    return BeamShape(
      radius: borderRadius,
      borderWidth: width,
      superellipse: se,
    );
  }

  /// The [BeamStyle] to hand the widget, or null when nothing differs.
  BeamStyle? buildStyle() {
    final style = BeamStyle(
      colors: hasColors ? beamColors : null,
      strength: strength == 1 ? null : strength,
      brightness: brightness,
      saturation: saturation,
      hueRange: hueRange == 30 ? null : hueRange,
      hueBase: hueBase == 0 ? null : hueBase,
      staticColors: staticColors ? true : null,
      strokeOpacityFactor: strokeOpacityFactor == 1
          ? null
          : strokeOpacityFactor,
      innerOpacityFactor: innerOpacityFactor == 1 ? null : innerOpacityFactor,
      bloomOpacityFactor: bloomOpacityFactor == 1 ? null : bloomOpacityFactor,
      glowBoost: variant.isPulse && glowBoost != 1 ? glowBoost : null,
      coreBlur: variant == BeamVariant.pulseOutside ? coreBlur : null,
      bloomBlur: variant == BeamVariant.pulseOutside ? bloomBlur : null,
      glowBrightness: variant == BeamVariant.pulseOutside
          ? glowBrightness
          : null,
      glowSaturation: variant == BeamVariant.pulseOutside
          ? glowSaturation
          : null,
    );
    return style == const BeamStyle() ? null : style;
  }

  /// The [BeamTiming] to hand the widget, or null when nothing differs.
  ///
  /// The breathe/spike factors belong to the line variant, and a controller
  /// owns the playback rate, so both are dropped where they do not apply.
  BeamTiming? buildTiming() {
    final isLine = variant == BeamVariant.line;
    final timing = BeamTiming(
      cycle: cycleSeconds == null ? null : _durationOf(cycleSeconds!),
      cycleGap: cycleGapSeconds == 0 ? null : _durationOf(cycleGapSeconds),
      speed: speed == 1 || controllerMode ? null : speed,
      huePeriod: huePeriodSeconds == null
          ? null
          : _durationOf(huePeriodSeconds!),
      breatheFactor: isLine && breatheFactor != 1.3 ? breatheFactor : null,
      spikeFactor: isLine && spikeFactor != 1.33 ? spikeFactor : null,
      spike2Factor: isLine && spike2Factor != 1.7 ? spike2Factor : null,
    );
    return timing == const BeamTiming() ? null : timing;
  }

  /// The [BeamPlayback] to hand the widget, or null when nothing differs.
  ///
  /// A controller owns scheduling exclusively, so `startAfter` and
  /// `duration` must not be set alongside one.
  BeamPlayback? buildPlayback() {
    if (controllerMode) return null;
    final playback = BeamPlayback(
      startAfter: startAfterSeconds == 0
          ? null
          : _durationOf(startAfterSeconds),
      duration: durationSeconds == 0 ? null : _durationOf(durationSeconds),
    );
    return playback == const BeamPlayback() ? null : playback;
  }

  /// The `active:` shorthand, or null when the controller owns playback or
  /// the beam is simply on.
  bool? buildActive() => controllerMode || active ? null : false;
}

Duration _durationOf(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());
