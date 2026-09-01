import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'animation/beam_clock.dart';
import 'animation/beam_phases.dart';
import 'border_beam_controller.dart';
import 'border_beam_theme.dart';
import 'models/beam_colors.dart';
import 'models/beam_config.dart';
import 'models/beam_playback.dart';
import 'models/beam_shape.dart';
import 'models/beam_style.dart';
import 'models/beam_theme.dart';
import 'models/beam_timing.dart';
import 'models/beam_variant.dart';
import 'painting/beam_painter.dart';
import 'painting/variant_strategy.dart';

/// An animated glow around [child]'s border.
///
/// A faithful Flutter port of the border-beam React library. Pick a variant
/// through the named constructors — or pass one to the generic constructor
/// when the choice is made at runtime:
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
/// Everything else is grouped into four value objects — [style], [shape],
/// [timing], and [playback] — whose fields are all nullable:
///
/// ```dart
/// BorderBeam(
///   variant: variant,
///   style: const BeamStyle(colors: BeamColors.sunset, strength: 0.8),
///   shape: const BeamShape.circular(24, superellipse: true),
///   timing: const BeamTiming(cycleGap: Duration(seconds: 1)),
///   child: card,
/// )
/// ```
///
/// A field left null falls through to the nearest [BorderBeamTheme], then to
/// the variant's own preset — so app-wide defaults live in one place.
///
/// The beam layers are purely decorative: they never intercept pointer
/// events and only paint — [child] is laid out and hit-tested normally.
///
/// ## Scheduling
///
/// Without a [controller], the beam plays by itself: `playback.autoPlay`
/// starts it (after `playback.startAfter`, if given) and `playback.duration`
/// bounds the total play time (null loops forever). Toggling [active] fades
/// the beam in (0.6s) and out (0.5s) with spring-eased envelopes;
/// [onActivate]/[onDeactivate] fire when the fades complete.
///
/// With a [BorderBeamController] attached, the controller owns playback
/// exclusively: `playback.startAfter` and `playback.duration` must not be set
/// (on the widget or on a [BorderBeamTheme]), and the controller's own
/// `speed` replaces `timing.speed`.
///
/// ## pulse-outside requirements
///
/// [BorderBeam.pulseOutside] paints its glow *behind* the child and *outside*
/// its bounds. The child must be opaque (so only the outward spill shows),
/// should carry its own 1px border for a defined idle edge, and needs
/// clip-free room around it (padding in the parent; no tight [ClipRRect]).
class BorderBeam extends StatefulWidget {
  /// Creates a beam of any [variant], for when the variant is picked at
  /// runtime. The named constructors are the readable form when it is not.
  const BorderBeam({
    super.key,
    required this.variant,
    required this.child,
    this.colors,
    this.active,
    this.borderRadius,
    this.style,
    this.shape,
    this.timing,
    this.playback,
    this.controller,
    this.onActivate,
    this.onDeactivate,
  });

  /// Full border traveling beam (React `md`). The default look, tuned for
  /// cards and larger surfaces.
  const BorderBeam.rotate({
    Key? key,
    required Widget child,
    BeamColors? colors,
    bool? active,
    double? borderRadius,
    BeamStyle? style,
    BeamShape? shape,
    BeamTiming? timing,
    BeamPlayback? playback,
    BorderBeamController? controller,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
  }) : this(
         key: key,
         variant: BeamVariant.rotate,
         child: child,
         colors: colors,
         active: active,
         borderRadius: borderRadius,
         style: style,
         shape: shape,
         timing: timing,
         playback: playback,
         controller: controller,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
       );

  /// Compact traveling beam for small elements (React `sm`) — icon buttons,
  /// chips. Defaults to a 32px radius.
  const BorderBeam.small({
    Key? key,
    required Widget child,
    BeamColors? colors,
    bool? active,
    double? borderRadius,
    BeamStyle? style,
    BeamShape? shape,
    BeamTiming? timing,
    BeamPlayback? playback,
    BorderBeamController? controller,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
  }) : this(
         key: key,
         variant: BeamVariant.small,
         child: child,
         colors: colors,
         active: active,
         borderRadius: borderRadius,
         style: style,
         shape: shape,
         timing: timing,
         playback: playback,
         controller: controller,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
       );

  /// Bottom-edge traveling beam (React `line`) — search bars, text inputs.
  /// The hue animation range is capped at 13°, as in the source.
  const BorderBeam.line({
    Key? key,
    required Widget child,
    BeamColors? colors,
    bool? active,
    double? borderRadius,
    BeamStyle? style,
    BeamShape? shape,
    BeamTiming? timing,
    BeamPlayback? playback,
    BorderBeamController? controller,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
  }) : this(
         key: key,
         variant: BeamVariant.line,
         child: child,
         colors: colors,
         active: active,
         borderRadius: borderRadius,
         style: style,
         shape: shape,
         timing: timing,
         playback: playback,
         controller: controller,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
       );

  /// Contained breathing glow (React `pulse-inner`) — working states,
  /// subscribe buttons.
  const BorderBeam.pulseInside({
    Key? key,
    required Widget child,
    BeamColors? colors,
    bool? active,
    double? borderRadius,
    BeamStyle? style,
    BeamShape? shape,
    BeamTiming? timing,
    BeamPlayback? playback,
    BorderBeamController? controller,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
  }) : this(
         key: key,
         variant: BeamVariant.pulseInside,
         child: child,
         colors: colors,
         active: active,
         borderRadius: borderRadius,
         style: style,
         shape: shape,
         timing: timing,
         playback: playback,
         controller: controller,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
       );

  /// Outward-blooming breathing halo (React `pulse-outside`).
  ///
  /// The glow paints behind and outside the child — see the class docs for
  /// the opaque-child / border / overflow-room requirements. `BeamStyle`'s
  /// `coreBlur`, `bloomBlur`, `glowBrightness`, and `glowSaturation` port the
  /// source's consumer tuning hooks for this variant.
  const BorderBeam.pulseOutside({
    Key? key,
    required Widget child,
    BeamColors? colors,
    bool? active,
    double? borderRadius,
    BeamStyle? style,
    BeamShape? shape,
    BeamTiming? timing,
    BeamPlayback? playback,
    BorderBeamController? controller,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
  }) : this(
         key: key,
         variant: BeamVariant.pulseOutside,
         child: child,
         colors: colors,
         active: active,
         borderRadius: borderRadius,
         style: style,
         shape: shape,
         timing: timing,
         playback: playback,
         controller: controller,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
       );

  /// Which effect this beam paints.
  final BeamVariant variant;

  /// The wrapped content. Laid out and hit-tested normally.
  final Widget child;

  /// Shorthand for `style.colors`; a non-null value here wins over it.
  final BeamColors? colors;

  /// Shorthand for `playback.active`; a non-null value here wins over it.
  final bool? active;

  /// Shorthand for a uniform `shape.radius` in logical px; a non-null value
  /// here wins over it. Match your child's decoration radius.
  final double? borderRadius;

  /// Colors, theme adaptation, and every filter/opacity tuning hook.
  final BeamStyle? style;

  /// Corner radii, ring width, and corner family.
  final BeamShape? shape;

  /// Cycle length, rest between sweeps, playback rate, and hue periods.
  final BeamTiming? timing;

  /// Play state and scheduling. Ignored while a [controller] is attached.
  final BeamPlayback? playback;

  /// Optional playback controller. When set it owns playback exclusively —
  /// `playback.startAfter`/`duration` must be null and [active] is ignored.
  final BorderBeamController? controller;

  /// Called when the fade-in completes.
  final VoidCallback? onActivate;

  /// Called when the fade-out completes.
  final VoidCallback? onDeactivate;

  // The widget's own style/shape/playback, with the shorthands folded in.
  BeamStyle? get _styleInput => colors == null
      ? style
      : (style ?? const BeamStyle()).copyWith(colors: colors);

  BeamShape? get _shapeInput => borderRadius == null
      ? shape
      : (shape ?? const BeamShape()).copyWith(
          radius: BorderRadius.circular(borderRadius!),
        );

  BeamPlayback? get _playbackInput => active == null
      ? playback
      : (playback ?? const BeamPlayback()).copyWith(active: active);

  @override
  State<BorderBeam> createState() => _BorderBeamState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<BeamVariant>('variant', variant))
      ..add(DiagnosticsProperty<BeamStyle>('style', _styleInput))
      ..add(DiagnosticsProperty<BeamShape>('shape', _shapeInput))
      ..add(DiagnosticsProperty<BeamTiming>('timing', timing))
      ..add(DiagnosticsProperty<BeamPlayback>('playback', _playbackInput))
      ..add(
        DiagnosticsProperty<BorderBeamController>(
          'controller',
          controller,
          defaultValue: null,
        ),
      );
  }
}

// The cycle length a resolved timing implies for a variant.
double _cycleSecondsOf(BeamTiming timing, BeamVariant variant) =>
    (timing.cycle ?? variant.defaultCycleDuration).inMicroseconds /
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

  // Timing and playback drive scheduling, so they are resolved whenever the
  // widget or its dependencies change rather than at paint time.
  BeamTiming _timing = const BeamTiming();
  BeamPlayback _playback = const BeamPlayback();
  double _cycleSeconds = 0;

  BeamVariantStrategy get _strategy => strategyFor(widget.variant);

  bool get _active => _playback.active ?? true;
  bool get _autoPlay => _playback.autoPlay ?? true;

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
    // The theme is not reachable yet; the widget's own values carry the beam
    // until didChangeDependencies resolves them properly, before first build.
    _timing = widget.timing ?? const BeamTiming();
    _playback = widget._playbackInput ?? const BeamPlayback();
    _cycleSeconds = _cycleSecondsOf(_timing, widget.variant);
    _applySpeed();
    widget.controller?.attach(_clock);
  }

  // Resolves the scheduling inputs against the enclosing BorderBeamTheme;
  // widget-level values (shorthands folded in) win over theme ones.
  void _resolveScheduling({required bool retime}) {
    final data = BorderBeamTheme.of(context);
    final playback = (data.playback ?? const BeamPlayback()).merge(
      widget._playbackInput,
    );
    assert(
      widget.controller == null ||
          (playback.startAfter == null && playback.duration == null),
      'When a BorderBeamController is attached it owns playback: startAfter '
      'and duration must not be set, on the widget or on a BorderBeamTheme.',
    );
    final timing = (data.timing ?? const BeamTiming()).merge(widget.timing);
    final previousCycle = _cycleSeconds;
    _playback = playback;
    _timing = timing;
    _cycleSeconds = _cycleSecondsOf(timing, widget.variant);
    if (retime) _retimeToNewCycle(previousCycle, _cycleSeconds);
    _applySpeed();
  }

  // A controller sets the clock's speed itself when it attaches, and owns it
  // from then on.
  void _applySpeed() {
    if (widget.controller != null) return;
    _clock.speed = _timing.speed ?? 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Autoplay needs MediaQuery (reduced motion), so it can't run from
    // initState. Reduced motion is also tracked here, where a change to it
    // is delivered.
    final first = !_autoPlayScheduled;
    _resolveScheduling(retime: !first);
    final reduced = _reducedMotion;
    if (first) {
      _autoPlayScheduled = true;
      _reducedMotionApplied = reduced;
      if (widget.controller == null && _autoPlay && _active) {
        final startAfter = _playback.startAfter;
        if (startAfter != null) {
          _startTimer = Timer(startAfter, _start);
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
    if (_hasStarted || widget.controller != null || !_autoPlay || !_active) {
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
  // the fixed-period hue tracks, which do not scale with the cycle. A
  // cycle-gap change needs none of this: the sweep keeps its position and the
  // rest simply appears at the next cycle end.
  void _retimeToNewCycle(double oldCycle, double newCycle) {
    if (!_clock.isVisible || oldCycle <= 0 || oldCycle == newCycle) return;
    final before = _clock.elapsedSeconds;
    _clock.retime(newCycle / oldCycle);
    _setHueTimeOffset(_hueTimeOffset + before - _clock.elapsedSeconds);
  }

  void _armDurationTimer() {
    _durationTimer?.cancel();
    final duration = _playback.duration;
    if (widget.controller == null && duration != null) {
      _durationTimer = Timer(duration, _clock.deactivate);
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
      (_playback.respectReducedMotion ?? true) &&
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didUpdateWidget(BorderBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = _active;
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_clock);
      widget.controller?.attach(_clock);
    }
    final variantChanged = oldWidget.variant != widget.variant;
    _resolveScheduling(retime: !variantChanged);
    if (variantChanged) {
      // The fps cap is variant-bound; rebuild the clock.
      final wasVisible = _clock.isVisible;
      widget.controller?.detach(_clock);
      _clock.dispose();
      _createClock();
      _applySpeed();
      widget.controller?.attach(_clock);
      if (wasVisible && widget.controller == null && _active) _start();
    }
    if (widget.controller == null && wasActive != _active) {
      _startTimer?.cancel();
      if (_active) {
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

  BeamConfig _resolveConfig(
    BeamStyle style,
    BeamShape shape,
    Brightness ambient,
    TextDirection textDirection,
  ) {
    final brightness = (style.theme ?? BeamTheme.auto).resolve(ambient);
    final key = (
      widget.variant,
      style,
      shape,
      _timing,
      brightness,
      textDirection,
    );
    if (_config == null || key != _configKey) {
      _configKey = key;
      _config = BeamConfig.resolve(
        variant: widget.variant,
        palette: (style.colors ?? BeamColors.colorful).resolve(),
        brightness: brightness,
        style: style,
        shape: shape,
        timing: _timing,
        textDirection: textDirection,
      );
      _resolver = BeamPhaseResolver(_config!)..hueTimeOffset = _hueTimeOffset;
    }
    return _config!;
  }

  @override
  Widget build(BuildContext context) {
    final data = BorderBeamTheme.of(context);
    final style = (data.style ?? const BeamStyle()).merge(widget._styleInput);
    final shape = (data.shape ?? const BeamShape()).merge(widget._shapeInput);
    final config = _resolveConfig(
      style,
      shape,
      Theme.of(context).brightness,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
    final strategy = _strategy;
    final reduced = _reducedMotion;
    final staticMode =
        reduced &&
        (widget.controller != null ? _clock.isVisible : _active && _autoPlay);

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
