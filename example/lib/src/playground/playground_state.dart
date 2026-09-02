import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

/// The palette choices the playground offers: the eleven presets, a
/// user-assembled [BeamColors.custom] list, a [BeamColors.fromSeed] palette
/// derived from one swatch, and a [BeamColors.lerp] blend of two presets.
enum PalettePreset {
  /// [BeamColors.colorful] — the package default.
  colorful('Colorful', 'colorful', BeamColors.colorful),

  /// [BeamColors.mono].
  mono('Mono', 'mono', BeamColors.mono),

  /// [BeamColors.ocean].
  ocean('Ocean', 'ocean', BeamColors.ocean),

  /// [BeamColors.sunset].
  sunset('Sunset', 'sunset', BeamColors.sunset),

  /// [BeamColors.aurora].
  aurora('Aurora', 'aurora', BeamColors.aurora),

  /// [BeamColors.neon].
  neon('Neon', 'neon', BeamColors.neon),

  /// [BeamColors.candy].
  candy('Candy', 'candy', BeamColors.candy),

  /// [BeamColors.ember].
  ember('Ember', 'ember', BeamColors.ember),

  /// [BeamColors.ice].
  ice('Ice', 'ice', BeamColors.ice),

  /// [BeamColors.gold].
  gold('Gold', 'gold', BeamColors.gold),

  /// [BeamColors.holographic].
  holographic('Holographic', 'holographic', BeamColors.holographic),

  /// Colors picked from [customSwatches]; [colors] is null because the list
  /// is built from the playground state.
  custom('Custom', 'custom', null),

  /// A palette derived from one swatch through [BeamColors.fromSeed].
  seed('Seed', 'seed', null),

  /// Two presets blended through [BeamColors.lerp].
  lerp('Lerp', 'lerp', null);

  const PalettePreset(this.label, this.id, this.colors);

  /// Chip label.
  final String label;

  /// Stable id used by the share codec and the generated snippet.
  final String id;

  /// The preset this choice maps to, or null for the three assembled modes
  /// ([custom], [seed], [lerp]).
  final BeamColors? colors;

  /// The choices that name a package preset — what the lerp endpoints and
  /// the custom base are picked from.
  static List<PalettePreset> get presets =>
      values.where((preset) => preset.colors != null).toList();
}

/// One entry of the custom-color picker: a name for the control and the
/// color the snippet emits.
typedef Swatch = ({String name, Color color});

/// The fixed palette the custom-colors and seed controls pick from — a small
/// preset list rather than a full color picker, which keeps the state
/// shareable as a handful of indices.
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

/// The dash counts the ring-segments control offers, alongside `off`.
const List<int> segmentChoices = [4, 6, 8, 12, 16];

/// The five-pointed star the shape section's contour toggle installs, so the
/// playground can show a beam travelling a path that is not a rounded
/// rectangle.
///
/// The key is what [BeamPathContour] compares on: two contours drawing the
/// same star are one value, which keeps the beam's resolved config out of
/// the rebuild path.
const BeamPathContour starContour = BeamPathContour(_starPath, key: 'star');

/// Traces a five-pointed star inscribed in [rect].
Path _starPath(Rect rect) {
  const points = 5;
  final center = rect.center;
  final outer = rect.shortestSide / 2;
  final inner = outer * 0.44;
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final radius = i.isEven ? outer : inner;
    // Start at 12 o'clock so the star stands upright.
    final angle = -math.pi / 2 + i * math.pi / points;
    final point = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

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

  /// The preset whose blob geometry and alpha structure the custom colors
  /// are distributed over.
  PalettePreset customBase = PalettePreset.colorful;

  /// Index into [customSwatches] of the [BeamColors.fromSeed] brand color.
  int seedColor = 7;

  /// How [BeamColors.fromSeed] spreads the seed hue.
  BeamSeedHarmony seedHarmony = BeamSeedHarmony.analogous;

  /// First endpoint of a [BeamColors.lerp] palette.
  PalettePreset lerpFrom = PalettePreset.ocean;

  /// Second endpoint of a [BeamColors.lerp] palette.
  PalettePreset lerpTo = PalettePreset.sunset;

  /// Where the [BeamColors.lerp] blend sits between its endpoints.
  double lerpT = 0.5;

  /// Multiplier applied to every palette entry's alpha through
  /// [BeamColors.scaleAlpha].
  double alphaScale = 1;

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

  /// Which edge the line variant's beam rides.
  BeamEdge edge = BeamEdge.bottom;

  /// How far the ring sits outside (positive) or inside (negative) the
  /// child's bounds, in logical px.
  double ringOffset = 0;

  /// Whether the beam travels [starContour] instead of a rounded rectangle.
  bool contour = false;

  // ─── Timing ─────────────────────────────────────────────────────────────

  /// Cycle length in seconds; null keeps the variant preset.
  double? cycleSeconds;

  /// Rest between sweeps in seconds.
  double cycleGapSeconds = 0;

  /// Declarative playback rate. Ignored in [controllerMode].
  double speed = 1;

  /// Which way the beam travels its contour.
  BeamDirection direction = BeamDirection.forward;

  /// Fraction of a cycle, 0–1, the timeline starts at.
  double phaseOffset = 0;

  /// How many beams travel the contour at once.
  int beamCount = 1;

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

  /// Whether the hue swings or revolves; null keeps the variant default.
  BeamHueMode? hueMode;

  /// Static hue offset in degrees.
  double hueBase = 0;

  /// Stroke ring opacity multiplier.
  double strokeOpacityFactor = 1;

  /// Inner glow opacity multiplier.
  double innerOpacityFactor = 1;

  /// Bloom opacity multiplier.
  double bloomOpacityFactor = 1;

  /// Angular width multiplier of the traveling window.
  double tailLength = 1;

  /// How far the bloom and halo layers reach past the stroke ring.
  double glowSpread = 1;

  /// Whether a soft halo trails the traveling head outside the ring.
  bool comet = false;

  /// Density of the twinkles scattered at the traveling head, 0–1.
  double sparkle = 0;

  /// Number of dashes the ring is broken into; null keeps it solid.
  int? segments;

  /// Multiplier on the size of the pulse-inside inner wash.
  double innerSizeScale = 1;

  /// The fraction of the box the beam is painted at before being magnified
  /// back up to fill it.
  double renderScale = 1;

  /// Whether pulse-outside paints [BeamStyle.pulseOutsideStock] — the React
  /// library's own look, before the demo page's tuning — under the fields
  /// set here.
  bool stockPulseOutside = false;

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

  /// How many cycles the beam runs before it fades out; null loops forever.
  int? repeatCycles;

  /// What the beam does under reduced motion; null keeps the package
  /// default, [BeamReducedMotion.staticFrame].
  BeamReducedMotion? reducedMotion;

  /// Whether the preview is wrapped in a `MediaQuery` asking for reduced
  /// motion, so [reducedMotion] can be watched without OS settings. A
  /// preview concern only: it reaches neither the beam's fields nor the
  /// snippet.
  bool simulateReducedMotion = false;

  /// Whether the beam stops painting while it is scrolled out of view.
  bool pauseWhenOffscreen = false;

  /// Whether the fades run on [BeamPlayback.cssEase] instead of the spring.
  bool cssFadeCurve = false;

  /// Whether a [BorderBeamController] drives playback instead of the
  /// declarative fields.
  bool controllerMode = false;

  /// The controller's playback rate, used in [controllerMode].
  double controllerSpeed = 1;

  /// Autoplay delay in seconds; 0 means none.
  double startAfterSeconds = 0;

  /// Total play time in seconds; 0 means forever.
  double durationSeconds = 0;

  // ─── Drive ──────────────────────────────────────────────────────────────

  /// Whether `BorderBeam.progress` parks the sweep instead of the clock.
  bool driveProgress = false;

  /// Where the driven sweep sits, 0–1.
  double progress = 0.35;

  /// Whether the preview feeds pointer position to `BorderBeam.follow`.
  bool followPointer = false;

  /// Whether a sine-wave signal drives `BorderBeam.strengthListenable`.
  bool strengthSignal = false;

  // ─── Group demos ────────────────────────────────────────────────────────

  /// Whether the preview sits inside a [BorderBeamTheme] supplying ocean +
  /// squircle-20 defaults, so fields left at their default inherit from it.
  bool themeDemo = false;

  /// Whether the preview shows three beams under one [BeamSync], each a
  /// third of a cycle apart.
  bool syncDemo = false;

  // ─── Derived values ─────────────────────────────────────────────────────

  /// The colors this state selects.
  BeamColors get beamColors {
    final base = switch (palette) {
      PalettePreset.custom => BeamColors.custom([
        for (final i in customColors) customSwatches[i].color,
      ], base: customBase.colors ?? BeamColors.colorful),
      PalettePreset.seed => BeamColors.fromSeed(
        customSwatches[seedColor].color,
        harmony: seedHarmony,
      ),
      PalettePreset.lerp => BeamColors.lerp(
        lerpFrom.colors ?? BeamColors.colorful,
        lerpTo.colors ?? BeamColors.colorful,
        lerpT,
      ),
      _ => palette.colors ?? BeamColors.colorful,
    };
    return alphaScale == 1 ? base : base.scaleAlpha(alphaScale);
  }

  /// Whether the palette differs from the package default.
  bool get hasColors => palette != PalettePreset.colorful || alphaScale != 1;

  /// Whether the variant's beam travels its contour — the family that has a
  /// direction, a phase, a head, and a progress to drive.
  bool get isTraveling => !variant.isPulse;

  /// Whether the variant sweeps the whole ring, which is what a tail length
  /// and a comet halo shape: rotate and small, but not the line beam.
  bool get isRing =>
      variant == BeamVariant.rotate || variant == BeamVariant.small;

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
      contour ||
      radius != defaultRadius ||
      borderWidth != 1 ||
      ringOffset != 0 ||
      (variant == BeamVariant.line && edge != BeamEdge.bottom);

  // ─── Value objects ──────────────────────────────────────────────────────

  /// The [BeamShape] to hand the widget, or null when nothing differs from
  /// the package default.
  BeamShape? buildShape() {
    if (!hasShape) return null;
    final width = borderWidth == 1 ? null : borderWidth;
    final se = superellipse ? true : null;
    final beamEdge = variant == BeamVariant.line && edge != BeamEdge.bottom
        ? edge
        : null;
    final offset = ringOffset == 0 ? null : ringOffset;
    final path = contour ? starContour : null;
    if (stadium) {
      return BeamShape.stadium(
        borderWidth: width,
        superellipse: se,
        edge: beamEdge,
        ringOffset: offset,
        contour: path,
      );
    }
    return BeamShape(
      radius: borderRadius,
      borderWidth: width,
      superellipse: se,
      edge: beamEdge,
      ringOffset: offset,
      contour: path,
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
      hueMode: hueMode,
      hueBase: hueBase == 0 ? null : hueBase,
      staticColors: staticColors ? true : null,
      strokeOpacityFactor: strokeOpacityFactor == 1
          ? null
          : strokeOpacityFactor,
      innerOpacityFactor: innerOpacityFactor == 1 ? null : innerOpacityFactor,
      bloomOpacityFactor: bloomOpacityFactor == 1 ? null : bloomOpacityFactor,
      tailLength: isRing && tailLength != 1 ? tailLength : null,
      glowSpread: glowSpread == 1 ? null : glowSpread,
      comet: isRing && comet ? true : null,
      sparkle: isTraveling && sparkle != 0 ? sparkle : null,
      segments: variant == BeamVariant.line ? null : segments,
      innerSizeScale: variant == BeamVariant.pulseInside && innerSizeScale != 1
          ? innerSizeScale
          : null,
      renderScale: renderScale == 1 ? null : renderScale,
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
    // The stock look is a whole style, not a field: it goes underneath, so
    // anything set here still wins.
    if (usesStockPulseOutside) {
      return BeamStyle.pulseOutsideStock.merge(style);
    }
    return style == const BeamStyle() ? null : style;
  }

  /// Whether the stock pulse-outside style applies — it is that variant's
  /// own recipe, and no other variant reads it.
  bool get usesStockPulseOutside =>
      stockPulseOutside && variant == BeamVariant.pulseOutside;

  /// The [BeamTiming] to hand the widget, or null when nothing differs.
  ///
  /// The breathe/spike factors belong to the line variant, the travel fields
  /// to the traveling ones, and a controller owns the playback rate, so each
  /// is dropped where it does not apply.
  BeamTiming? buildTiming() {
    final isLine = variant == BeamVariant.line;
    final timing = BeamTiming(
      cycle: cycleSeconds == null ? null : _durationOf(cycleSeconds!),
      cycleGap: cycleGapSeconds == 0 ? null : _durationOf(cycleGapSeconds),
      speed: speed == 1 || controllerMode ? null : speed,
      direction: isTraveling && direction != BeamDirection.forward
          ? direction
          : null,
      phaseOffset: isTraveling && phaseOffset != 0 ? phaseOffset : null,
      beamCount: isTraveling && beamCount != 1 ? beamCount : null,
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
  /// `duration` are dropped alongside one; `repeat` and `reducedMotion` are
  /// the beam's own and survive either way.
  BeamPlayback? buildPlayback() {
    final playback = BeamPlayback(
      startAfter: startAfterSeconds == 0 || controllerMode
          ? null
          : _durationOf(startAfterSeconds),
      duration: durationSeconds == 0 || controllerMode
          ? null
          : _durationOf(durationSeconds),
      repeat: buildRepeat(),
      reducedMotion: reducedMotion,
      pauseWhenOffscreen: pauseWhenOffscreen ? true : null,
      fadeCurve: cssFadeCurve ? BeamPlayback.cssEase : null,
    );
    return playback == const BeamPlayback() ? null : playback;
  }

  /// The [BeamRepeat] the cycle-count control selects, or null while the
  /// beam loops forever.
  BeamRepeat? buildRepeat() => switch (repeatCycles) {
    null => null,
    1 => const BeamRepeat.once(),
    final int n => BeamRepeat.count(n),
  };

  /// The `active:` shorthand, or null when the controller owns playback or
  /// the beam is simply on.
  bool? buildActive() => controllerMode || active ? null : false;

  /// The `progress:` value, or null while the clock owns the travel — which
  /// the pulse variants always do.
  double? buildProgress() => driveProgress && isTraveling ? progress : null;

  /// Whether the preview feeds `follow:` a pointer position.
  ///
  /// `progress` parks the sweep where it says, so a beam driven by one has no
  /// travel left for the pointer to pull; the pulse variants never travel.
  bool get followsPointer => followPointer && isTraveling && !driveProgress;
}

Duration _durationOf(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());
