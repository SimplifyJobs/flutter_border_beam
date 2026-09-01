import 'dart:async';

import 'package:flutter/material.dart';

import 'animation/beam_clock.dart';
import 'animation/beam_phases.dart';
import 'border_beam_controller.dart';
import 'models/beam_colors.dart';
import 'models/beam_config.dart';
import 'models/beam_theme.dart';
import 'models/beam_variant.dart';
import 'painting/beam_painter.dart';
import 'painting/variant_strategy.dart';

/// An animated glow around [child]'s border.
///
/// A faithful Flutter port of the border-beam React library. Pick a variant
/// through the named constructors:
///
/// - [BorderBeam.rotate] — full border traveling beam (cards, surfaces).
/// - [BorderBeam.small] — compact traveling beam (buttons, icons).
/// - [BorderBeam.line] — beam traveling along the bottom edge (inputs).
/// - [BorderBeam.pulseInside] — contained breathing glow.
/// - [BorderBeam.pulseOutside] — outward-blooming halo behind the child.
///
/// ```dart
/// BorderBeam.rotate(
///   colors: BeamColors.ocean,
///   borderRadius: 16,
///   child: Card(child: content),
/// )
/// ```
///
/// The beam layers are purely decorative: they never intercept pointer
/// events and only paint — [child] is laid out and hit-tested normally.
///
/// ## Scheduling
///
/// Without a [controller], the beam plays by itself: [autoPlay] starts it
/// (after [startAfter], if given) and [duration] bounds the total play time
/// (null loops forever). Toggling [active] fades the beam in (0.6s) and out
/// (0.5s) with spring-eased envelopes; [onActivate]/[onDeactivate] fire when
/// the fades complete.
///
/// With a [BorderBeamController] attached, the controller owns playback
/// exclusively and [startAfter]/[duration] must not be set.
///
/// ## pulse-outside requirements
///
/// [BorderBeam.pulseOutside] paints its glow *behind* the child and *outside*
/// its bounds. The child must be opaque (so only the outward spill shows),
/// should carry its own 1px border for a defined idle edge, and needs
/// clip-free room around it (padding in the parent; no tight [ClipRRect]).
class BorderBeam extends StatefulWidget {
  const BorderBeam._({
    super.key,
    required this.variant,
    required this.child,
    this.colors = BeamColors.colorful,
    this.theme = BeamTheme.auto,
    this.strength = 1,
    this.active = true,
    this.borderRadius,
    this.useSuperellipse = false,
    this.borderWidth,
    this.brightness,
    this.saturation,
    this.hueRange = 30,
    this.hueBase = 0,
    this.staticColors = false,
    this.respectReducedMotion = true,
    this.cycleDuration,
    this.controller,
    this.startAfter,
    this.duration,
    this.autoPlay = true,
    this.onActivate,
    this.onDeactivate,
    this.strokeOpacityFactor = 1,
    this.innerOpacityFactor = 1,
    this.bloomOpacityFactor = 1,
    this.glowBoost = 1,
    this.coreBlur,
    this.bloomBlur,
    this.glowBrightness,
    this.glowSaturation,
  }) : assert(
         controller == null || (startAfter == null && duration == null),
         'When a BorderBeamController is attached it owns playback: '
         'startAfter and duration must not be set.',
       );

  /// Full border traveling beam (React `md`). The default look, tuned for
  /// cards and larger surfaces.
  const BorderBeam.rotate({
    Key? key,
    required Widget child,
    BeamColors colors = BeamColors.colorful,
    BeamTheme theme = BeamTheme.auto,
    double strength = 1,
    bool active = true,
    double? borderRadius,
    bool useSuperellipse = false,
    double? borderWidth,
    double? brightness,
    double? saturation,
    double hueRange = 30,
    double hueBase = 0,
    bool staticColors = false,
    bool respectReducedMotion = true,
    Duration? cycleDuration,
    BorderBeamController? controller,
    Duration? startAfter,
    Duration? duration,
    bool autoPlay = true,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
    double strokeOpacityFactor = 1,
    double innerOpacityFactor = 1,
    double bloomOpacityFactor = 1,
  }) : this._(
         key: key,
         variant: BeamVariant.rotate,
         child: child,
         colors: colors,
         theme: theme,
         strength: strength,
         active: active,
         borderRadius: borderRadius,
         useSuperellipse: useSuperellipse,
         borderWidth: borderWidth,
         brightness: brightness,
         saturation: saturation,
         hueRange: hueRange,
         hueBase: hueBase,
         staticColors: staticColors,
         respectReducedMotion: respectReducedMotion,
         cycleDuration: cycleDuration,
         controller: controller,
         startAfter: startAfter,
         duration: duration,
         autoPlay: autoPlay,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
         strokeOpacityFactor: strokeOpacityFactor,
         innerOpacityFactor: innerOpacityFactor,
         bloomOpacityFactor: bloomOpacityFactor,
       );

  /// Compact traveling beam for small elements (React `sm`) — icon buttons,
  /// chips. Defaults to a 32px radius.
  const BorderBeam.small({
    Key? key,
    required Widget child,
    BeamColors colors = BeamColors.colorful,
    BeamTheme theme = BeamTheme.auto,
    double strength = 1,
    bool active = true,
    double? borderRadius,
    bool useSuperellipse = false,
    double? borderWidth,
    double? brightness,
    double? saturation,
    double hueRange = 30,
    double hueBase = 0,
    bool staticColors = false,
    bool respectReducedMotion = true,
    Duration? cycleDuration,
    BorderBeamController? controller,
    Duration? startAfter,
    Duration? duration,
    bool autoPlay = true,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
    double strokeOpacityFactor = 1,
    double innerOpacityFactor = 1,
    double bloomOpacityFactor = 1,
  }) : this._(
         key: key,
         variant: BeamVariant.small,
         child: child,
         colors: colors,
         theme: theme,
         strength: strength,
         active: active,
         borderRadius: borderRadius,
         useSuperellipse: useSuperellipse,
         borderWidth: borderWidth,
         brightness: brightness,
         saturation: saturation,
         hueRange: hueRange,
         hueBase: hueBase,
         staticColors: staticColors,
         respectReducedMotion: respectReducedMotion,
         cycleDuration: cycleDuration,
         controller: controller,
         startAfter: startAfter,
         duration: duration,
         autoPlay: autoPlay,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
         strokeOpacityFactor: strokeOpacityFactor,
         innerOpacityFactor: innerOpacityFactor,
         bloomOpacityFactor: bloomOpacityFactor,
       );

  /// Bottom-edge traveling beam (React `line`) — search bars, text inputs.
  /// The hue animation range is capped at 13°, as in the source.
  const BorderBeam.line({
    Key? key,
    required Widget child,
    BeamColors colors = BeamColors.colorful,
    BeamTheme theme = BeamTheme.auto,
    double strength = 1,
    bool active = true,
    double? borderRadius,
    bool useSuperellipse = false,
    double? borderWidth,
    double? brightness,
    double? saturation,
    double hueRange = 30,
    double hueBase = 0,
    bool staticColors = false,
    bool respectReducedMotion = true,
    Duration? cycleDuration,
    BorderBeamController? controller,
    Duration? startAfter,
    Duration? duration,
    bool autoPlay = true,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
    double strokeOpacityFactor = 1,
    double innerOpacityFactor = 1,
    double bloomOpacityFactor = 1,
  }) : this._(
         key: key,
         variant: BeamVariant.line,
         child: child,
         colors: colors,
         theme: theme,
         strength: strength,
         active: active,
         borderRadius: borderRadius,
         useSuperellipse: useSuperellipse,
         borderWidth: borderWidth,
         brightness: brightness,
         saturation: saturation,
         hueRange: hueRange,
         hueBase: hueBase,
         staticColors: staticColors,
         respectReducedMotion: respectReducedMotion,
         cycleDuration: cycleDuration,
         controller: controller,
         startAfter: startAfter,
         duration: duration,
         autoPlay: autoPlay,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
         strokeOpacityFactor: strokeOpacityFactor,
         innerOpacityFactor: innerOpacityFactor,
         bloomOpacityFactor: bloomOpacityFactor,
       );

  /// Contained breathing glow (React `pulse-inner`) — working states,
  /// subscribe buttons.
  const BorderBeam.pulseInside({
    Key? key,
    required Widget child,
    BeamColors colors = BeamColors.colorful,
    BeamTheme theme = BeamTheme.auto,
    double strength = 1,
    bool active = true,
    double? borderRadius,
    bool useSuperellipse = false,
    double? borderWidth,
    double? brightness,
    double? saturation,
    double hueBase = 0,
    bool staticColors = false,
    bool respectReducedMotion = true,
    Duration? cycleDuration,
    BorderBeamController? controller,
    Duration? startAfter,
    Duration? duration,
    bool autoPlay = true,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
    double strokeOpacityFactor = 1,
    double innerOpacityFactor = 1,
    double bloomOpacityFactor = 1,
    double glowBoost = 1,
  }) : this._(
         key: key,
         variant: BeamVariant.pulseInside,
         child: child,
         colors: colors,
         theme: theme,
         strength: strength,
         active: active,
         borderRadius: borderRadius,
         useSuperellipse: useSuperellipse,
         borderWidth: borderWidth,
         brightness: brightness,
         saturation: saturation,
         hueBase: hueBase,
         staticColors: staticColors,
         respectReducedMotion: respectReducedMotion,
         cycleDuration: cycleDuration,
         controller: controller,
         startAfter: startAfter,
         duration: duration,
         autoPlay: autoPlay,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
         strokeOpacityFactor: strokeOpacityFactor,
         innerOpacityFactor: innerOpacityFactor,
         bloomOpacityFactor: bloomOpacityFactor,
         glowBoost: glowBoost,
       );

  /// Outward-blooming breathing halo (React `pulse-outside`).
  ///
  /// The glow paints behind and outside the child — see the class docs for
  /// the opaque-child / border / overflow-room requirements. [coreBlur],
  /// [bloomBlur], [glowBrightness], and [glowSaturation] port the source's
  /// consumer tuning hooks.
  const BorderBeam.pulseOutside({
    Key? key,
    required Widget child,
    BeamColors colors = BeamColors.colorful,
    BeamTheme theme = BeamTheme.auto,
    double strength = 1,
    bool active = true,
    double? borderRadius,
    bool useSuperellipse = false,
    double? borderWidth,
    double? brightness,
    double? saturation,
    double hueBase = 0,
    bool staticColors = false,
    bool respectReducedMotion = true,
    Duration? cycleDuration,
    BorderBeamController? controller,
    Duration? startAfter,
    Duration? duration,
    bool autoPlay = true,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
    double strokeOpacityFactor = 1,
    double innerOpacityFactor = 1,
    double bloomOpacityFactor = 1,
    double glowBoost = 1,
    double? coreBlur,
    double? bloomBlur,
    double? glowBrightness,
    double? glowSaturation,
  }) : this._(
         key: key,
         variant: BeamVariant.pulseOutside,
         child: child,
         colors: colors,
         theme: theme,
         strength: strength,
         active: active,
         borderRadius: borderRadius,
         useSuperellipse: useSuperellipse,
         borderWidth: borderWidth,
         brightness: brightness,
         saturation: saturation,
         hueBase: hueBase,
         staticColors: staticColors,
         respectReducedMotion: respectReducedMotion,
         cycleDuration: cycleDuration,
         controller: controller,
         startAfter: startAfter,
         duration: duration,
         autoPlay: autoPlay,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
         strokeOpacityFactor: strokeOpacityFactor,
         innerOpacityFactor: innerOpacityFactor,
         bloomOpacityFactor: bloomOpacityFactor,
         glowBoost: glowBoost,
         coreBlur: coreBlur,
         bloomBlur: bloomBlur,
         glowBrightness: glowBrightness,
         glowSaturation: glowSaturation,
       );

  /// Which effect this beam paints.
  final BeamVariant variant;

  /// The wrapped content. Laid out and hit-tested normally.
  final Widget child;

  /// Color scheme: a preset, [BeamColors.custom], or [BeamColors.spec].
  final BeamColors colors;

  /// Background adaptation: dark, light, or follow the ambient theme.
  final BeamTheme theme;

  /// Effect opacity 0–1 (clamped). Scales only the beam layers.
  final double strength;

  /// Declarative play state: toggling fades the beam in/out. Ignored when a
  /// [controller] is attached.
  final bool active;

  /// Corner radius in logical px; null uses the variant preset (16, or 32
  /// for [BeamVariant.small]). Match your child's decoration radius.
  final double? borderRadius;

  /// Shape the beam as a rounded superellipse (Apple-style squircle) instead
  /// of a circular-arc rounded rectangle.
  final bool useSuperellipse;

  /// Stroke ring thickness in logical px (default 1, as in the source).
  final double? borderWidth;

  /// Glow brightness multiplier; null uses the variant/theme preset.
  final double? brightness;

  /// Glow saturation multiplier; null uses the variant/theme preset.
  final double? saturation;

  /// Hue animation amplitude in degrees (default 30; the line variant caps
  /// it at 13). Not used by pulse variants, whose hue cycles continuously.
  final double hueRange;

  /// Static hue offset in degrees added to the whole palette.
  final double hueBase;

  /// Disables the hue animation. Forced on by [BeamColors.mono].
  final bool staticColors;

  /// When true (default), honors [MediaQuery.disableAnimationsOf] by
  /// painting a single static frame instead of animating.
  final bool respectReducedMotion;

  /// Length of one animation cycle; null uses the variant default
  /// (1.96s rotate/small, 3.1s line, 2.3s pulse).
  ///
  /// Changing it while the beam runs retimes the animation in place: every
  /// track keeps the phase it was at, so the beam speeds up or slows down
  /// without a jump.
  final Duration? cycleDuration;

  /// Optional playback controller. When set it owns playback exclusively —
  /// [startAfter] and [duration] must be null and [active]/[autoPlay] are
  /// ignored.
  final BorderBeamController? controller;

  /// Delay before autoplay starts. Only without a [controller].
  final Duration? startAfter;

  /// Total play time before the beam fades out by itself; null plays
  /// forever. Only without a [controller].
  final Duration? duration;

  /// Whether the beam starts by itself (default true). Only without a
  /// [controller].
  final bool autoPlay;

  /// Called when the fade-in completes.
  final VoidCallback? onActivate;

  /// Called when the fade-out completes.
  final VoidCallback? onDeactivate;

  /// Stroke ring opacity multiplier (React `--beam-stroke-opacity`).
  final double strokeOpacityFactor;

  /// Inner glow opacity multiplier (React `--beam-inner-opacity`).
  final double innerOpacityFactor;

  /// Bloom opacity multiplier (React `--beam-bloom-opacity`).
  final double bloomOpacityFactor;

  /// Pulse glow prominence multiplier (React `--pulse-glow-boost`).
  final double glowBoost;

  /// pulse-outside core glow blur override in px (React `--beam-core-blur`).
  final double? coreBlur;

  /// pulse-outside halo blur override in px (React `--beam-bloom-blur`).
  final double? bloomBlur;

  /// pulse-outside glow brightness override
  /// (React `--beam-glow-brightness`).
  final double? glowBrightness;

  /// pulse-outside glow saturation override (React `--beam-glow-saturate`).
  final double? glowSaturation;

  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

// The cycle length a widget resolves to, independent of theme — enough to
// detect a cycle change without resolving the whole config.
double _cycleSecondsOf(BorderBeam widget) =>
    (widget.cycleDuration ?? widget.variant.defaultCycleDuration)
        .inMicroseconds /
    Duration.microsecondsPerSecond;

// TickerProviderStateMixin (not Single-): a variant change rebuilds the
// clock, creating a second ticker over this State's lifetime.
class _BorderBeamState extends State<BorderBeam> with TickerProviderStateMixin {
  late BeamClock _clock;
  Timer? _startTimer;
  Timer? _durationTimer;

  BeamConfig? _config;
  BeamPhaseResolver? _resolver;
  Object? _configKey;

  BeamVariantStrategy get _strategy => strategyFor(widget.variant);

  bool _autoPlayScheduled = false;
  bool _hasStarted = false;
  bool _reducedMotionApplied = false;
  // Set only when reduced motion paused the clock, so turning reduced motion
  // back off never overrides a pause the controller asked for.
  bool _pausedForReducedMotion = false;
  double _hueTimeOffset = 0;

  @override
  void initState() {
    super.initState();
    _createClock();
    widget.controller?.attach(_clock);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Autoplay needs MediaQuery (reduced motion), so it can't run from
    // initState. Reduced motion is also tracked here, where a change to it
    // is delivered.
    final reduced = _reducedMotion;
    if (!_autoPlayScheduled) {
      _autoPlayScheduled = true;
      _reducedMotionApplied = reduced;
      if (widget.controller == null && widget.autoPlay && widget.active) {
        if (widget.startAfter != null) {
          _startTimer = Timer(widget.startAfter!, _start);
        } else {
          _start();
        }
      }
      return;
    }
    if (reduced == _reducedMotionApplied) return;
    _reducedMotionApplied = reduced;
    if (reduced) {
      _pauseForReducedMotion();
    } else {
      _leaveReducedMotion();
    }
  }

  void _pauseForReducedMotion() {
    if (!_clock.isRunning) return;
    _clock.pause();
    _pausedForReducedMotion = true;
  }

  void _leaveReducedMotion() {
    if (_pausedForReducedMotion) {
      _pausedForReducedMotion = false;
      if (_clock.isVisible) {
        _clock.resume();
        return;
      }
    }
    // The beam never got to start: reduced motion was on when autoplay ran.
    // A beam that has already played is left alone — its duration may have
    // run out. startAfter belongs to that first autoplay only, so it is
    // honored while its timer is pending and skipped once it has fired.
    if (_hasStarted ||
        widget.controller != null ||
        !widget.autoPlay ||
        !widget.active) {
      return;
    }
    if (_clock.isVisible || (_startTimer?.isActive ?? false)) return;
    _start();
  }

  void _createClock() {
    _clock = BeamClock(
      createTicker: createTicker,
      maxFps: _strategy.preferredFps,
      onFadeComplete: _onFadeComplete,
    );
  }

  void _start() {
    if (_reducedMotion) return;
    _hasStarted = true;
    // Activating from hidden restarts the timeline, so the hue shift a
    // retime accumulated goes with it; a mid-fade-out re-activation keeps
    // the timeline, and keeps the shift.
    if (!_clock.isVisible) _setHueTimeOffset(0);
    _clock.activate();
    _armDurationTimer();
  }

  void _setHueTimeOffset(double seconds) {
    _hueTimeOffset = seconds;
    _resolver?.hueTimeOffset = seconds;
  }

  // A cycle-duration change mid-run must not snap the beam. Rescaling
  // elapsed time by the cycle ratio holds every cycle-derived track at its
  // current fraction; shifting the hue clock back by the same amount holds
  // the fixed-period hue tracks, which do not scale with the cycle.
  void _retimeToNewCycle(double oldCycle, double newCycle) {
    if (!_clock.isVisible || oldCycle <= 0 || oldCycle == newCycle) return;
    final before = _clock.elapsedSeconds;
    _clock.retime(newCycle / oldCycle);
    _setHueTimeOffset(_hueTimeOffset + before - _clock.elapsedSeconds);
  }

  void _armDurationTimer() {
    _durationTimer?.cancel();
    if (widget.controller == null && widget.duration != null) {
      _durationTimer = Timer(widget.duration!, _clock.deactivate);
    }
  }

  void _onFadeComplete(bool active) {
    if (active) {
      widget.onActivate?.call();
    } else {
      widget.onDeactivate?.call();
    }
  }

  bool get _reducedMotion =>
      widget.respectReducedMotion &&
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didUpdateWidget(BorderBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_clock);
      widget.controller?.attach(_clock);
    }
    if (oldWidget.variant != widget.variant) {
      // The fps cap is variant-bound; rebuild the clock.
      final wasVisible = _clock.isVisible;
      widget.controller?.detach(_clock);
      _clock.dispose();
      _createClock();
      widget.controller?.attach(_clock);
      if (wasVisible && widget.controller == null && widget.active) _start();
    }
    if (oldWidget.variant == widget.variant &&
        oldWidget.cycleDuration != widget.cycleDuration) {
      _retimeToNewCycle(_cycleSecondsOf(oldWidget), _cycleSecondsOf(widget));
    }
    if (widget.controller == null && oldWidget.active != widget.active) {
      _startTimer?.cancel();
      if (widget.active) {
        _start();
      } else {
        _durationTimer?.cancel();
        _clock.deactivate();
      }
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _durationTimer?.cancel();
    widget.controller?.detach(_clock);
    _clock.dispose();
    super.dispose();
  }

  BeamConfig _resolveConfig(Brightness ambient) {
    final brightness = widget.theme.resolve(ambient);
    final key = (
      widget.variant,
      widget.colors,
      brightness,
      widget.borderRadius,
      widget.borderWidth,
      widget.useSuperellipse,
      widget.strength,
      widget.brightness,
      widget.saturation,
      widget.hueRange,
      widget.hueBase,
      widget.staticColors,
      widget.cycleDuration,
      widget.strokeOpacityFactor,
      widget.innerOpacityFactor,
      widget.bloomOpacityFactor,
      widget.glowBoost,
      widget.coreBlur,
      widget.bloomBlur,
      widget.glowBrightness,
      widget.glowSaturation,
    );
    if (_config == null || key != _configKey) {
      _configKey = key;
      _config = BeamConfig.resolve(
        variant: widget.variant,
        palette: widget.colors.resolve(),
        brightness: brightness,
        borderRadius: widget.borderRadius,
        borderWidth: widget.borderWidth,
        useSuperellipse: widget.useSuperellipse,
        strength: widget.strength,
        brightnessFactor: widget.brightness,
        saturation: widget.saturation,
        hueRange: widget.hueRange,
        hueBase: widget.hueBase,
        staticColors: widget.staticColors,
        cycleDuration: widget.cycleDuration,
        strokeOpacityFactor: widget.strokeOpacityFactor,
        innerOpacityFactor: widget.innerOpacityFactor,
        bloomOpacityFactor: widget.bloomOpacityFactor,
        glowBoost: widget.glowBoost,
        coreBlur: widget.coreBlur,
        bloomBlur: widget.bloomBlur,
        glowBrightness: widget.glowBrightness,
        glowSaturation: widget.glowSaturation,
      );
      _resolver = BeamPhaseResolver(_config!)..hueTimeOffset = _hueTimeOffset;
    }
    return _config!;
  }

  @override
  Widget build(BuildContext context) {
    final ambient = Theme.of(context).brightness;
    final config = _resolveConfig(ambient);
    final strategy = _strategy;
    final reduced = _reducedMotion;
    final staticMode =
        reduced &&
        (widget.controller != null
            ? _clock.isVisible
            : widget.active && widget.autoPlay);

    return RepaintBoundary(
      child: CustomPaint(
        painter: widget.variant == BeamVariant.pulseOutside
            ? BeamPainter(
                clock: _clock,
                config: config,
                resolver: _resolver!,
                strategy: strategy,
                behind: true,
                staticMode: staticMode,
              )
            : null,
        foregroundPainter: BeamPainter(
          clock: _clock,
          config: config,
          resolver: _resolver!,
          strategy: strategy,
          behind: false,
          staticMode: staticMode,
        ),
        // The child never re-rasterizes with the beam's frames.
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
