import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

/// The eight effects the playground can preview, in gallery order.
enum EffectKind {
  /// [BeamEffect.rotate].
  rotate('Rotate'),

  /// [BeamEffect.line].
  line('Line'),

  /// [BeamEffect.pulse].
  pulse('Pulse'),

  /// [BeamEffect.halo].
  halo('Halo'),

  /// [BeamEffect.flow].
  flow('Flow'),

  /// [BeamEffect.spin].
  spin('Spin'),

  /// [BeamEffect.shimmer].
  shimmer('Shimmer'),

  /// [BeamEffect.charge].
  charge('Charge');

  const EffectKind(this.label);

  /// Chip label.
  final String label;

  /// Stable id used by the share codec and the generated snippet — the
  /// effect's own `BeamEffect.name`.
  String get id => name;

  /// This effect with its default parameters — the source of every
  /// effect-dependent default the controls show.
  BeamEffect get defaults => switch (this) {
    EffectKind.rotate => const BeamEffect.rotate(),
    EffectKind.line => const BeamEffect.line(),
    EffectKind.pulse => const BeamEffect.pulse(),
    EffectKind.halo => const BeamEffect.halo(),
    EffectKind.flow => const BeamEffect.flow(),
    EffectKind.spin => const BeamEffect.spin(),
    EffectKind.shimmer => const BeamEffect.shimmer(),
    EffectKind.charge => const BeamEffect.charge(),
  };
}

/// How the playground assembles its palette: one of the package presets, or
/// one of the three palette factories.
enum PaletteMode {
  /// A named entry of [BeamColors.presets].
  preset('preset'),

  /// A [BeamColors] ring built from [customSwatches].
  custom('custom'),

  /// A palette derived from one swatch through [BeamColors.fromSeed].
  seed('seed'),

  /// Two presets blended through [BeamColors.lerp].
  lerp('lerp');

  const PaletteMode(this.id);

  /// Stable id used by the share codec, sharing the `p=` key with the
  /// preset names.
  final String id;
}

/// The package presets by name, in gallery order.
List<String> get presetNames => BeamColors.presets.keys.toList();

/// `ocean` → `Ocean`.
String presetLabel(String name) =>
    name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';

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

/// Fewest colors the custom picker keeps selected.
const int minCustomColors = 2;

/// Most colors the custom picker accepts.
const int maxCustomColors = 6;

/// The dash counts the dashes control offers, alongside `off`.
const List<int> dashChoices = [4, 6, 8, 12, 16, 24];

/// Partial-contour choices exposed by the Shape controls.
enum SegmentPreset {
  /// The full contour.
  off('Off', 'off'),

  /// [BeamSegment.bottomHalf].
  bottomHalf('Bottom half', 'bottomHalf'),

  /// [BeamSegment.topHalf].
  topHalf('Top half', 'topHalf'),

  /// [BeamSegment.leftHalf].
  leftHalf('Left half', 'leftHalf'),

  /// [BeamSegment.rightHalf].
  rightHalf('Right half', 'rightHalf'),

  /// [BeamSegment.bottomEdge].
  bottomEdge('Bottom edge', 'bottomEdge'),

  /// [BeamSegment.topEdge].
  topEdge('Top edge', 'topEdge'),

  /// [BeamSegment.leftEdge].
  leftEdge('Left edge', 'leftEdge'),

  /// [BeamSegment.rightEdge].
  rightEdge('Right edge', 'rightEdge'),

  /// A segment assembled from the two edge-anchor controls.
  custom('Custom', 'custom');

  const SegmentPreset(this.label, this.id);

  /// Chip label.
  final String label;

  /// Stable share-link identifier.
  final String id;
}

// The effect parameters' own defaults, read off the package so the
// playground tracks it.
const RotateEffect _rotateDefaults = RotateEffect();
const LineEffect _lineDefaults = LineEffect();
const ShimmerEffect _shimmerDefaults = ShimmerEffect();

/// Every knob the playground drives, in one mutable bag.
///
/// A freshly constructed instance is the "all defaults" configuration: every
/// field holds the value the package would resolve on its own, so the
/// snippet generator and the live preview can both emit *only* what differs
/// from it. Fields whose package default depends on the effect are nullable,
/// and null means "let the package decide".
class PlaygroundState {
  /// Creates the all-defaults state.
  PlaygroundState();

  // ─── Effect ─────────────────────────────────────────────────────────────

  /// Which effect the preview paints.
  EffectKind effect = EffectKind.rotate;

  /// [RotateEffect.length]: the tail length multiplier.
  double rotateLength = _rotateDefaults.length;

  /// [RotateEffect.count]: how many beams travel the border at once.
  int rotateCount = _rotateDefaults.count;

  /// [RotateEffect.comet]: whether a glow trails the head outside the
  /// border.
  bool rotateComet = _rotateDefaults.comet;

  /// [LineEffect.edge]: the edge the line's streak rides.
  BeamEdge lineEdge = _lineDefaults.edge;

  /// [ShimmerEffect.angle]: the sweep's tilt in degrees from vertical.
  double shimmerAngle = _shimmerDefaults.angle;

  // ─── Colors ─────────────────────────────────────────────────────────────

  /// How the palette is assembled.
  PaletteMode paletteMode = PaletteMode.preset;

  /// The [BeamColors.presets] entry used in [PaletteMode.preset].
  String preset = 'colorful';

  /// Indices into [customSwatches] used in [PaletteMode.custom].
  List<int> customColors = [0, 1];

  /// Index into [customSwatches] of the [BeamColors.fromSeed] brand color.
  int seedColor = 7;

  /// How [BeamColors.fromSeed] spreads the seed hue.
  BeamSeedHarmony seedHarmony = BeamSeedHarmony.analogous;

  /// First endpoint of a [BeamColors.lerp] palette, a preset name.
  String lerpFrom = 'ocean';

  /// Second endpoint of a [BeamColors.lerp] palette, a preset name.
  String lerpTo = 'sunset';

  /// Where the [BeamColors.lerp] blend sits between its endpoints.
  double lerpT = 0.5;

  /// Multiplier applied to every palette entry's alpha through
  /// [BeamColors.scaleAlpha].
  double alphaScale = 1;

  // ─── Style ──────────────────────────────────────────────────────────────

  /// Background adaptation; null leaves [BeamTheme.auto], which follows the
  /// preview's own brightness.
  BeamTheme? beamTheme;

  /// Overall opacity, 0–1.
  double strength = 1;

  /// Size and intensity of every glow around the border.
  double glow = 1;

  /// How far the hue swings either side under [BeamHueMode.pingPong].
  double hueShift = 30;

  /// How the colours drift; null keeps the effect's own choice.
  BeamHueMode? hueMode;

  /// Static hue rotation in degrees.
  double hueBase = 0;

  // ─── Shape ──────────────────────────────────────────────────────────────

  /// Whether the contour is a pill ([BeamShape.stadium]).
  bool stadium = false;

  /// Whether the four corners are set individually.
  bool perCorner = false;

  /// Uniform corner radius.
  double radius = BeamShape.defaultRadius;

  /// Top-left radius in per-corner mode.
  double radiusTopLeft = BeamShape.defaultRadius;

  /// Top-right radius in per-corner mode.
  double radiusTopRight = BeamShape.defaultRadius;

  /// Bottom-right radius in per-corner mode.
  double radiusBottomRight = BeamShape.defaultRadius;

  /// Bottom-left radius in per-corner mode.
  double radiusBottomLeft = BeamShape.defaultRadius;

  /// Whether the contour uses superellipse corners.
  bool superellipse = false;

  /// Stroke thickness in logical px.
  double borderWidth = 1;

  /// How far the outline sits outside (positive) or inside (negative) the
  /// child's bounds, in logical px.
  double ringOffset = 0;

  /// Which part of the contour is visible.
  SegmentPreset segmentPreset = SegmentPreset.off;

  /// Edge carrying the custom segment's start anchor.
  BeamEdge segmentStartEdge = BeamEdge.right;

  /// Position along [segmentStartEdge]'s clockwise straight run.
  double segmentStartT = 0.5;

  /// Edge carrying the custom segment's end anchor.
  BeamEdge segmentEndEdge = BeamEdge.left;

  /// Position along [segmentEndEdge]'s clockwise straight run.
  double segmentEndT = 0.5;

  /// Fade length at each end of a custom segment, in logical px.
  double segmentFeather = 48;

  /// How many dashes the border is broken into; null keeps it solid.
  int? dashes;

  // ─── Timing ─────────────────────────────────────────────────────────────

  /// Cycle length in seconds; null keeps the effect's default.
  double? cycleSeconds;

  /// Rest between sweeps in seconds; null keeps the effect's default.
  double? cycleGapSeconds;

  /// Declarative playback rate. Ignored in [controllerMode].
  double speed = 1;

  /// Which way the beam moves.
  BeamDirection direction = BeamDirection.forward;

  /// Fraction of a cycle, 0–1, the timeline starts at.
  double phaseOffset = 0;

  /// Hue drift period in seconds; null keeps the effect's default.
  double? huePeriodSeconds;

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

  /// Whether the beam pauses while scrolled out of view. Null keeps the
  /// package default (true), while false explicitly opts out.
  bool? pauseWhenOffscreen;

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

  /// Whether `BorderBeam.progress` places the sweep instead of the clock.
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

  /// The effect this state selects, parameters included.
  BeamEffect buildEffect() => switch (effect) {
    EffectKind.rotate => BeamEffect.rotate(
      length: rotateLength,
      count: rotateCount,
      comet: rotateComet,
    ),
    EffectKind.line => BeamEffect.line(edge: lineEdge),
    EffectKind.shimmer => BeamEffect.shimmer(angle: shimmerAngle),
    _ => effect.defaults,
  };

  /// Whether the effect travels — the family that has a sweep to rest
  /// between, a progress to drive, and a pointer to follow.
  bool get travels => effect.defaults.travels;

  /// Whether [direction] changes anything: the travelling effects run
  /// either way, and flow and spin turn backwards on
  /// [BeamDirection.reverse]. Pulse and halo have no motion to direct.
  bool get directionApplies =>
      travels || effect == EffectKind.flow || effect == EffectKind.spin;

  /// The hue mode the beam resolves to: the one set here, else the effect's.
  BeamHueMode get effectiveHueMode => hueMode ?? effect.defaults.defaultHueMode;

  /// The palette named [name], falling back to the package default.
  static BeamColors presetColors(String name) =>
      BeamColors.presets[name] ?? BeamColors.colorful;

  /// The colors this state selects.
  BeamColors get beamColors {
    final base = switch (paletteMode) {
      PaletteMode.preset => presetColors(preset),
      PaletteMode.custom => BeamColors([
        for (final i in customColors) customSwatches[i].color,
      ]),
      PaletteMode.seed => BeamColors.fromSeed(
        customSwatches[seedColor].color,
        harmony: seedHarmony,
      ),
      PaletteMode.lerp => BeamColors.lerp(
        presetColors(lerpFrom),
        presetColors(lerpTo),
        lerpT,
      ),
    };
    return alphaScale == 1 ? base : base.scaleAlpha(alphaScale);
  }

  /// Whether the palette differs from the package default.
  bool get hasColors =>
      paletteMode != PaletteMode.preset ||
      preset != 'colorful' ||
      alphaScale != 1;

  /// The cycle length in seconds the package would resolve on its own.
  double get defaultCycleSeconds => _secondsOf(effect.defaults.defaultCycle);

  /// The rest between sweeps the package would resolve on its own.
  double get defaultCycleGapSeconds =>
      _secondsOf(effect.defaults.defaultCycleGap);

  /// The hue period in seconds the package would resolve on its own.
  double get defaultHuePeriodSeconds =>
      _secondsOf(effect.defaults.defaultHuePeriod);

  /// The corner radii the beam contour uses, per-corner mode included.
  /// Stadium corners are infinite and clamped per corner by the outline,
  /// which is what makes them track the box.
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
      radius != BeamShape.defaultRadius ||
      borderWidth != 1 ||
      ringOffset != 0 ||
      segmentPreset != SegmentPreset.off ||
      dashes != null;

  /// Whether the only shape change is a uniform radius — what the
  /// `borderRadius:` shorthand carries on its own.
  bool get radiusOnly =>
      hasShape &&
      !stadium &&
      !perCorner &&
      !superellipse &&
      borderWidth == 1 &&
      ringOffset == 0 &&
      segmentPreset == SegmentPreset.off &&
      dashes == null;

  /// The selected partial contour, or null for the full contour.
  BeamSegment? get segment => switch (segmentPreset) {
    SegmentPreset.off => null,
    SegmentPreset.bottomHalf => BeamSegment.bottomHalf,
    SegmentPreset.topHalf => BeamSegment.topHalf,
    SegmentPreset.leftHalf => BeamSegment.leftHalf,
    SegmentPreset.rightHalf => BeamSegment.rightHalf,
    SegmentPreset.bottomEdge => BeamSegment.bottomEdge,
    SegmentPreset.topEdge => BeamSegment.topEdge,
    SegmentPreset.leftEdge => BeamSegment.leftEdge,
    SegmentPreset.rightEdge => BeamSegment.rightEdge,
    SegmentPreset.custom => BeamSegment(
      start: BeamAnchor.edge(segmentStartEdge, segmentStartT),
      end: BeamAnchor.edge(segmentEndEdge, segmentEndT),
      feather: segmentFeather,
    ),
  };

  // ─── Value objects ──────────────────────────────────────────────────────

  /// The [BeamShape] to hand the widget, or null when nothing differs from
  /// the package default. Whenever a shape is handed over it carries its
  /// radius, so a shape set here never inherits a theme's corners.
  BeamShape? buildShape() {
    if (!hasShape) return null;
    final width = borderWidth == 1 ? null : borderWidth;
    final se = superellipse ? true : null;
    final offset = ringOffset == 0 ? null : ringOffset;
    if (stadium) {
      return BeamShape.stadium(
        borderWidth: width,
        superellipse: se,
        ringOffset: offset,
        segment: segment,
        dashes: dashes,
      );
    }
    return BeamShape(
      radius: borderRadius,
      borderWidth: width,
      superellipse: se,
      ringOffset: offset,
      segment: segment,
      dashes: dashes,
    );
  }

  /// The [BeamStyle] to hand the widget, or null when nothing differs.
  BeamStyle? buildStyle() {
    final style = BeamStyle(
      colors: hasColors ? beamColors : null,
      theme: beamTheme,
      strength: strength == 1 ? null : strength,
      glow: glow == 1 ? null : glow,
      hueShift: hueShiftApplies && hueShift != 30 ? hueShift : null,
      hueMode: hueMode,
      hueBase: hueBase == 0 ? null : hueBase,
    );
    return style == const BeamStyle() ? null : style;
  }

  /// Whether [hueShift] reaches the beam: only a ping-pong drift swings.
  bool get hueShiftApplies => effectiveHueMode == BeamHueMode.pingPong;

  /// Whether the hue drifts at all, which is what a hue period times.
  bool get hueDrifts => effectiveHueMode != BeamHueMode.none;

  /// The [BeamTiming] to hand the widget, or null when nothing differs.
  ///
  /// The rest between sweeps belongs to the travelling effects, direction
  /// only to the effects that move, and a controller owns the playback rate,
  /// so each is dropped where it does not apply.
  BeamTiming? buildTiming() {
    final timing = BeamTiming(
      cycle: cycleSeconds == null ? null : _durationOf(cycleSeconds!),
      cycleGap: travels && cycleGapSeconds != null
          ? _durationOf(cycleGapSeconds!)
          : null,
      speed: speed == 1 || controllerMode ? null : speed,
      direction: directionApplies && direction != BeamDirection.forward
          ? direction
          : null,
      phaseOffset: phaseOffset == 0 ? null : phaseOffset,
      huePeriod: hueDrifts && huePeriodSeconds != null
          ? _durationOf(huePeriodSeconds!)
          : null,
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
      pauseWhenOffscreen: pauseWhenOffscreen,
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
  /// the ambient effects always do.
  double? buildProgress() => driveProgress && travels ? progress : null;

  /// Whether the preview feeds `follow:` a pointer position.
  ///
  /// `progress` places the sweep where it says, so a beam driven by one has
  /// no travel left for the pointer to pull; the ambient effects never
  /// travel.
  bool get followsPointer => followPointer && travels && !driveProgress;
}

double _secondsOf(Duration duration) =>
    duration.inMicroseconds / Duration.microsecondsPerSecond;

Duration _durationOf(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());
