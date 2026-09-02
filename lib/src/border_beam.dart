import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'animation/beam_clock.dart';
import 'animation/beam_phases.dart';
import 'beam_sync.dart';
import 'border_beam_controller.dart';
import 'border_beam_theme.dart';
import 'models/beam_colors.dart';
import 'models/beam_config.dart';
import 'models/beam_options.dart';
import 'models/beam_playback.dart';
import 'models/beam_shape.dart';
import 'models/beam_style.dart';
import 'models/beam_theme.dart';
import 'models/beam_timing.dart';
import 'models/beam_variant.dart';
import 'models/model_validation.dart';
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
///   shape: const BeamShape.all(24, superellipse: true),
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
    this.progress,
    this.follow,
    this.strengthListenable,
    this.speedListenable,
    this.onActivate,
    this.onDeactivate,
  });

  /// Paints the beam with no child of its own, sized by its parent.
  ///
  /// The beam is the whole widget: drop it into a [Stack] under a
  /// [Positioned.fill] and it traces the stack's bounds, over content it
  /// does not have to wrap. Everything else behaves exactly as the generic
  /// constructor.
  ///
  /// ```dart
  /// Stack(
  ///   children: [
  ///     content,
  ///     const Positioned.fill(
  ///       child: BorderBeam.overlay(borderRadius: 16),
  ///     ),
  ///   ],
  /// )
  /// ```
  const BorderBeam.overlay({
    Key? key,
    BeamVariant variant = BeamVariant.rotate,
    BeamColors? colors,
    bool? active,
    double? borderRadius,
    BeamStyle? style,
    BeamShape? shape,
    BeamTiming? timing,
    BeamPlayback? playback,
    BorderBeamController? controller,
    double? progress,
    Offset? follow,
    ValueListenable<double>? strengthListenable,
    ValueListenable<double>? speedListenable,
    VoidCallback? onActivate,
    VoidCallback? onDeactivate,
  }) : this(
         key: key,
         variant: variant,
         child: const SizedBox.expand(),
         colors: colors,
         active: active,
         borderRadius: borderRadius,
         style: style,
         shape: shape,
         timing: timing,
         playback: playback,
         controller: controller,
         progress: progress,
         follow: follow,
         strengthListenable: strengthListenable,
         speedListenable: speedListenable,
         onActivate: onActivate,
         onDeactivate: onDeactivate,
       );

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
    double? progress,
    Offset? follow,
    ValueListenable<double>? strengthListenable,
    ValueListenable<double>? speedListenable,
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
         progress: progress,
         follow: follow,
         strengthListenable: strengthListenable,
         speedListenable: speedListenable,
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
    double? progress,
    Offset? follow,
    ValueListenable<double>? strengthListenable,
    ValueListenable<double>? speedListenable,
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
         progress: progress,
         follow: follow,
         strengthListenable: strengthListenable,
         speedListenable: speedListenable,
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
    double? progress,
    Offset? follow,
    ValueListenable<double>? strengthListenable,
    ValueListenable<double>? speedListenable,
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
         progress: progress,
         follow: follow,
         strengthListenable: strengthListenable,
         speedListenable: speedListenable,
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
    double? progress,
    Offset? follow,
    ValueListenable<double>? strengthListenable,
    ValueListenable<double>? speedListenable,
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
         progress: progress,
         follow: follow,
         strengthListenable: strengthListenable,
         speedListenable: speedListenable,
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
    double? progress,
    Offset? follow,
    ValueListenable<double>? strengthListenable,
    ValueListenable<double>? speedListenable,
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
         progress: progress,
         follow: follow,
         strengthListenable: strengthListenable,
         speedListenable: speedListenable,
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

  /// Drives the beam's travel from a value instead of the clock, 0–1.
  ///
  /// The sweep sits where this says rather than running with time, which
  /// turns the traveling variants into readouts: [BorderBeam.rotate] becomes
  /// a glowing progress ring, [BorderBeam.line] a progress bar. The clock
  /// keeps running underneath — the fade envelope, the hue shift, and the
  /// line variant's breathe and spike tracks are all still alive, so the
  /// beam looks lit rather than frozen.
  ///
  /// Changing it repaints without re-resolving the beam's configuration, so
  /// it is cheap to drive from an animation. Null hands the travel back to
  /// the clock; the pulse variants have no travel to drive.
  final double? progress;

  /// Pulls the traveling beam toward a point in the child's box, given in
  /// normalized coordinates (0–1 on each axis).
  ///
  /// The beam leaves its schedule and eases to the perimeter position
  /// nearest the point — critically damped, ~150ms — which reads as the glow
  /// following the pointer. Setting it back to null hands the sweep back to
  /// the clock from wherever it is, without a snap.
  ///
  /// Feed it from a [MouseRegion] or [Listener]:
  ///
  /// ```dart
  /// MouseRegion(
  ///   onHover: (e) => setState(() {
  ///     final box = context.findRenderObject()! as RenderBox;
  ///     final local = box.globalToLocal(e.position);
  ///     _follow = Offset(local.dx / box.size.width, local.dy / box.size.height);
  ///   }),
  ///   onExit: (_) => setState(() => _follow = null),
  ///   child: BorderBeam.rotate(follow: _follow, child: card),
  /// )
  /// ```
  ///
  /// [progress] wins over it, and the pulse variants ignore both.
  final Offset? follow;

  /// Scales every layer's opacity each frame, without rebuilding.
  ///
  /// The live twin of `BeamStyle.strength`: point it at a mic level, a
  /// download rate, or any other signal and the beam breathes with it. Values
  /// above 1 brighten up to the clamp every layer opacity already carries.
  final ValueListenable<double>? strengthListenable;

  /// Drives the playback rate each frame, without rebuilding.
  ///
  /// The live twin of `BeamTiming.speed`, and it wins over both that and a
  /// [controller]'s rate while it is set. Values must stay positive.
  final ValueListenable<double>? speedListenable;

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
      )
      ..add(DoubleProperty('progress', progress, defaultValue: null))
      ..add(DiagnosticsProperty<Offset>('follow', follow, defaultValue: null))
      ..add(
        DiagnosticsProperty<ValueListenable<double>>(
          'strengthListenable',
          strengthListenable,
          defaultValue: null,
        ),
      )
      ..add(
        DiagnosticsProperty<ValueListenable<double>>(
          'speedListenable',
          speedListenable,
          defaultValue: null,
        ),
      );
  }
}

// The cycle length a resolved timing implies for a variant.
double _cycleSecondsOf(BeamTiming timing, BeamVariant variant) =>
    (timing.cycle ?? variant.defaultCycleDuration).inMicroseconds /
    Duration.microsecondsPerSecond;

// The timing fields the painted config is built from — everything except
// `speed`, which is applied to the clock and never reaches BeamConfig.
// Keeping it out of the cache key is what lets a rate change ride through
// without re-resolving the config or rebuilding the phase resolver.
BeamTiming _configTiming(BeamTiming timing) => BeamTiming(
  cycle: timing.cycle,
  cycleGap: timing.cycleGap,
  direction: timing.direction,
  phaseOffset: timing.phaseOffset,
  beamCount: timing.beamCount,
  huePeriod: timing.huePeriod,
  bloomHuePeriod: timing.bloomHuePeriod,
  breatheFactor: timing.breatheFactor,
  spikeFactor: timing.spikeFactor,
  spike2Factor: timing.spike2Factor,
);

// BeamReducedMotion.slow runs the clock at a quarter rate.
const double _slowMotionFactor = 0.25;

// How far outside the viewport a beam keeps running before its clock is
// paused, matching the root margin the source's IntersectionObserver uses.
const double _offscreenMarginPx = 256;

// How long the follow easing takes to cover most of the distance to the
// pointer. Short enough to feel attached, long enough to smooth a jittery
// pointer stream.
const double _followResponseSeconds = 0.15;

// A critically damped step toward [target]: no overshoot, no ringing, and it
// carries velocity, so a target that keeps moving never produces a corner.
({double value, double velocity}) _smoothDamp({
  required double current,
  required double target,
  required double velocity,
  required double dt,
  required double response,
}) {
  final omega = 2 / response;
  final x = omega * dt;
  // Padé approximation of exp(-x) — stable at any frame duration.
  final decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
  final change = current - target;
  final temp = (velocity + omega * change) * dt;
  return (
    value: target + (change + temp) * decay,
    velocity: (velocity - omega * temp) * decay,
  );
}

// TickerProviderStateMixin (not Single-): a variant change rebuilds the
// clock, creating a second ticker over this State's lifetime.
class _BorderBeamState extends State<BorderBeam> with TickerProviderStateMixin {
  // Exactly one of these is set: a beam owns a clock unless a BeamSync hands
  // it the group's.
  BeamClock? _ownClock;
  BeamClock? _sharedClock;
  Timer? _startTimer;
  double? _durationStartedAt;

  BeamConfig? _config;
  BeamPhaseResolver? _resolver;
  Object? _configKey;

  // Timing and playback drive scheduling, so they are resolved whenever the
  // widget or its dependencies change rather than at paint time.
  BeamTiming _timing = const BeamTiming();
  BeamPlayback _playback = const BeamPlayback();
  double _cycleSeconds = 0;

  // The sweep position when something other than the clock drives it. It
  // reaches the painter as a listenable so `progress` and `follow` move the
  // beam without rebuilding the config.
  final ValueNotifier<double?> _driven = ValueNotifier<double?>(null);
  double? _followValue;
  double _followVelocity = 0;
  double _lastTickSeconds = 0;
  BeamClock? _listeningTo;

  BeamClock get _clock => _sharedClock ?? _ownClock!;

  /// Whether this beam runs on a [BeamSync] group clock.
  bool get _synced => _sharedClock != null;

  BeamVariantStrategy get _strategy => strategyFor(widget.variant);

  bool get _active => _playback.active ?? true;
  bool get _autoPlay => _playback.autoPlay ?? true;

  // A frozen beam paints one instant of its timeline forever, so its clock
  // is never started at all.
  bool get _frozen => _playback.debugFrozenAt != null;

  bool _autoPlayScheduled = false;
  bool _hasStarted = false;
  BeamReducedMotion? _reducedApplied;
  // Set only when reduced motion paused the clock, so turning reduced motion
  // back off never overrides a pause the controller asked for.
  bool _pausedForReducedMotion = false;
  // The same idea for the offscreen pause: set only when this beam stopped
  // the clock because nobody could see it, so resuming never overrides a
  // pause a controller or reduced motion asked for.
  bool _pausedForOffscreen = false;
  ScrollableState? _scrollable;
  ScrollPosition? _scrollPosition;
  bool _offscreenCheckScheduled = false;
  double _hueTimeOffset = 0;

  @override
  void initState() {
    super.initState();
    _createOwnClock();
    // The theme is not reachable yet; the widget's own values carry the beam
    // until didChangeDependencies resolves them properly, before first build.
    _timing = widget.timing ?? const BeamTiming();
    _playback = widget._playbackInput ?? const BeamPlayback();
    validateBeamTiming(_timing);
    validateRepeat(_playback.repeat);
    _cycleSeconds = _cycleSecondsOf(_timing, widget.variant);
    _applySpeed();
    _applyFadeCurve();
    widget.controller?.attach(_clock);
    widget.speedListenable?.addListener(_applySpeed);
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
    validateBeamTiming(timing);
    validateRepeat(playback.repeat);
    final previousCycle = _cycleSeconds;
    final previousGap =
        (_timing.cycleGap ?? Duration.zero).inMicroseconds /
        Duration.microsecondsPerSecond;
    final previousPhase = _timing.phaseOffset ?? 0;
    _playback = playback;
    _timing = timing;
    _cycleSeconds = _cycleSecondsOf(timing, widget.variant);
    final nextGap =
        (timing.cycleGap ?? Duration.zero).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (retime) {
      _retimeToNewCycle(
        previousCycle,
        _cycleSeconds,
        oldGap: previousGap,
        newGap: nextGap,
        oldPhase: previousPhase,
        newPhase: timing.phaseOffset ?? 0,
      );
    }
    _applySpeed();
    _applyFadeCurve();
    _syncResolverPlayback();
    _syncTickListener();
    _syncScrollListener();
  }

  // A group clock's fade belongs to its BeamSync, not to one member.
  void _applyFadeCurve() {
    if (_synced) return;
    _clock.fadeCurve = _playback.fadeCurve;
  }

  // The rate the clock runs at: a live speedListenable first, then the
  // controller that owns playback, then the resolved timing — scaled down
  // while reduced motion asks for slow motion. A synced beam leaves the
  // group's rate to its BeamSync.
  void _applySpeed() {
    if (_synced) return;
    final base =
        widget.speedListenable?.value ??
        widget.controller?.speed ??
        _timing.speed ??
        1;
    final factor = _reducedApplied == BeamReducedMotion.slow
        ? _slowMotionFactor
        : 1.0;
    _clock.speed = base * factor;
  }

  void _scheduleAutoplayStart() {
    _startTimer?.cancel();
    _startTimer = null;
    if (_synced ||
        widget.controller != null ||
        !_autoPlay ||
        !_active ||
        _frozen ||
        _clock.isVisible) {
      return;
    }
    final delay = _playback.startAfter;
    if (delay == null) {
      _start();
      return;
    }
    _startTimer = Timer(delay, () {
      _startTimer = null;
      if (!mounted ||
          _synced ||
          widget.controller != null ||
          !_autoPlay ||
          !_active) {
        return;
      }
      _start();
    });
  }

  void _applyReducedMotionChange() {
    final reduced = _reduced;
    if (reduced == _reducedApplied) return;
    _reducedApplied = reduced;
    _applySpeed();
    // A group clock follows BeamSync's group-level policy.
    if (_synced) return;
    if (_motionFrozen) {
      _pauseForReducedMotion();
    } else {
      _leaveReducedMotion();
    }
  }

  void _applySchedulingTransition(
    BeamPlayback previous, {
    required bool controllerChanged,
  }) {
    final wasActive = previous.active ?? true;
    final wasAutoPlay = previous.autoPlay ?? true;
    final activeChanged = wasActive != _active;

    if (_synced || widget.controller != null) {
      _startTimer?.cancel();
      _startTimer = null;
      _clearDurationBudget();
      return;
    }

    if (activeChanged) {
      _startTimer?.cancel();
      _startTimer = null;
      if (_active) {
        _start();
      } else {
        _clearDurationBudget();
        _clock.deactivate();
      }
      return;
    }

    final startScheduleChanged =
        wasAutoPlay != _autoPlay ||
        previous.startAfter != _playback.startAfter ||
        controllerChanged;
    if (startScheduleChanged && !_hasStarted) {
      if (_autoPlay) {
        _scheduleAutoplayStart();
      } else {
        _startTimer?.cancel();
        _startTimer = null;
      }
    }

    if (previous.duration != _playback.duration) {
      if (_clock.isVisible && _playback.duration != null) {
        _armDurationBudget();
      } else {
        _clearDurationBudget();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Autoplay needs MediaQuery (reduced motion), so it can't run from
    // initState. Reduced motion is also tracked here, where a change to it
    // is delivered, as is the enclosing BeamSync.
    final first = !_autoPlayScheduled;
    final previousPlayback = _playback;
    _adoptSharedClock(BeamSync.clockOf(context));
    _resolveScheduling(retime: !first);
    if (first) {
      _autoPlayScheduled = true;
      _reducedApplied = _reduced;
      _applySpeed();
      _scheduleAutoplayStart();
      return;
    }
    _applyReducedMotionChange();
    _applySchedulingTransition(previousPlayback, controllerChanged: false);
  }

  // Moves this beam onto (or off) a BeamSync group clock.
  void _adoptSharedClock(BeamClock? shared) {
    if (shared == _sharedClock) return;
    assert(
      shared == null || widget.controller == null,
      'A BorderBeam under a BeamSync runs on the group clock, so it cannot '
      'also take a BorderBeamController — a controller owns a clock of its '
      'own. Drive the group through BeamSync, or move the beam out of it.',
    );
    _detachTickListener();
    if (shared != null) {
      _startTimer?.cancel();
      _startTimer = null;
      _durationStartedAt = null;
      final own = _ownClock;
      _ownClock = null;
      _sharedClock = shared;
      own?.dispose();
    } else {
      _sharedClock = null;
      _createOwnClock();
      _applySpeed();
      _applyFadeCurve();
      if (widget.controller == null && _autoPlay && _active) _start();
    }
    _syncTickListener();
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
        // Motion is allowed again, but visibility may not be — re-check
        // rather than leaving an offscreen beam ticking.
        _scheduleOffscreenCheck();
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

  void _createOwnClock() {
    _ownClock = BeamClock(
      createTicker: createTicker,
      maxFps: _strategy.preferredFps,
      onFadeComplete: _onFadeComplete,
    );
  }

  void _start() {
    if (_motionFrozen || _synced || _frozen) return;
    _hasStarted = true;
    // Activating from hidden restarts the timeline, so the hue shift a
    // retime accumulated goes with it; a mid-fade-out re-activation keeps
    // the timeline, and keeps the shift.
    if (!_clock.isVisible) _setHueTimeOffset(0);
    _clock.activate();
    _armDurationBudget();
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
  void _retimeToNewCycle(
    double oldCycle,
    double newCycle, {
    required double oldGap,
    required double newGap,
    required double oldPhase,
    required double newPhase,
  }) {
    if (!_clock.isVisible || oldCycle <= 0 || oldCycle == newCycle) return;
    if (widget.variant.isPulse) {
      oldGap = 0;
      newGap = 0;
    }
    final before = _clock.elapsedSeconds;
    final oldPeriod = oldCycle + oldGap;
    final newPeriod = newCycle + newGap;
    // The resolver samples the shifted timeline, not the clock's raw elapsed
    // time, so sweep-or-gap has to be decided there: an offset beam resting
    // in the gap sits at a different point of the period than its elapsed
    // time alone says, and segmenting the raw timeline would drop it into
    // the middle of the sweep.
    final travel = _resolver?.travelTimeOffset ?? 0;
    final shifted = before + oldPhase * oldCycle + travel;
    final completed = oldPeriod <= 0 ? 0 : (shifted / oldPeriod).floor();
    final local = oldPeriod <= 0 ? shifted : shifted - completed * oldPeriod;
    final newLocal = local < oldCycle || oldGap <= 0
        ? local * newCycle / oldCycle
        : newCycle + (local - oldCycle) * newGap / oldGap;
    // Back out of the shifted timeline: the resolver re-applies the new
    // offset and the unchanged travel hand-back on top of what the clock
    // reports.
    final target =
        completed * newPeriod + newLocal - newPhase * newCycle - travel;
    final factor = before == 0 ? newCycle / oldCycle : target / before;
    if (!factor.isFinite || factor <= 0) return;
    _clock.retime(factor);
    _setHueTimeOffset(_hueTimeOffset + before - _clock.elapsedSeconds);
  }

  void _armDurationBudget() {
    final duration = _playback.duration;
    if (widget.controller == null && duration != null) {
      _durationStartedAt = _clock.activeSeconds;
    } else {
      _durationStartedAt = null;
    }
    _syncTickListener();
  }

  void _clearDurationBudget() {
    _durationStartedAt = null;
    _syncTickListener();
  }

  void _checkDurationBudget() {
    final startedAt = _durationStartedAt;
    final duration = _playback.duration;
    if (startedAt == null || duration == null) return;
    final allowed = duration.inMicroseconds / Duration.microsecondsPerSecond;
    if (_clock.activeSeconds - startedAt < allowed) return;
    _durationStartedAt = null;
    _clock.deactivate();
    _syncTickListener();
  }

  void _onFadeComplete(bool active) {
    if (active) {
      widget.onActivate?.call();
    } else {
      widget.onDeactivate?.call();
    }
  }

  /// The reduced-motion behavior in force, or null when the platform is not
  /// asking for it (or this beam ignores the ask).
  BeamReducedMotion? get _reduced {
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return null;
    final mode =
        BeamSync.reducedMotionOf(context) ??
        _playback.reducedMotion ??
        BeamReducedMotion.staticFrame;
    return mode == BeamReducedMotion.animate ? null : mode;
  }

  // A frozen beam stops ticking: the static frame and the hidden beam both
  // have nothing to advance. Slow motion keeps running, at a quarter rate.
  bool get _motionFrozen =>
      _reducedApplied == BeamReducedMotion.staticFrame ||
      _reducedApplied == BeamReducedMotion.hide;

  // ─── Repeat budget & driven travel ──────────────────────────────────────

  void _syncResolverPlayback() {
    // Playback belongs to the group under a BeamSync, so one member's repeat
    // budget must not stop everyone's clock.
    _resolver?.repeatCycles = _synced ? null : validateRepeat(_playback.repeat);
  }

  // The per-frame hook is only worth its cost while something needs it.
  void _syncTickListener() {
    final needed =
        widget.follow != null ||
        _followValue != null ||
        _durationStartedAt != null ||
        (!_synced && _playback.repeat?.cycles != null);
    if (!needed) {
      _detachTickListener();
      return;
    }
    if (_listeningTo == _clock) return;
    _detachTickListener();
    _listeningTo = _clock..addListener(_onClockTick);
    _lastTickSeconds = _clock.elapsedSeconds;
  }

  void _detachTickListener() {
    _listeningTo?.removeListener(_onClockTick);
    _listeningTo = null;
  }

  void _onClockTick() {
    final now = _clock.elapsedSeconds;
    final dt = now - _lastTickSeconds;
    _lastTickSeconds = now;
    // A restart rewinds the timeline and a retime rescales it; neither step
    // is a frame's worth of time, so it is dropped rather than eased across.
    if (dt > 0 && dt < 0.25) _advanceFollow(dt);
    _checkDurationBudget();
    _checkRepeatBudget();
  }

  void _checkRepeatBudget() {
    final resolver = _resolver;
    if (resolver == null || resolver.repeatCycles == null) return;
    final clock = _clock;
    if (!clock.isVisible || clock.stage == BeamFadeStage.fadingOut) return;
    // The beam fades out the way an inactive one does, so the last cycle
    // ends on a fade rather than a cut.
    if (resolver.finishedAt(clock.elapsedSeconds)) clock.deactivate();
  }

  // The perimeter position the pointer is asking for, as sweep progress.
  double? _followTarget() {
    final follow = widget.follow;
    final config = _config;
    if (follow == null || config == null) return null;
    switch (widget.variant) {
      case BeamVariant.rotate || BeamVariant.small:
        // Progress 0 sits at 12 o'clock and runs clockwise, so the angle to
        // the point is measured from straight up.
        final angle =
            math.atan2(follow.dy - 0.5, follow.dx - 0.5) + math.pi / 2;
        return (angle / (2 * math.pi)) % 1.0;
      case BeamVariant.line:
        // The beam travels one edge, so only the coordinate along it counts.
        final along = switch (config.edge) {
          BeamEdge.top || BeamEdge.bottom => follow.dx,
          BeamEdge.left || BeamEdge.right => follow.dy,
        };
        return along.clamp(0.0, 1.0);
      case BeamVariant.pulseInside || BeamVariant.pulseOutside:
        // Breathing has no travel to steer.
        return null;
    }
  }

  void _advanceFollow(double dt) {
    final target = _followTarget();
    final resolver = _resolver;
    if (target == null || resolver == null) return;
    final from = _followValue ?? _timedProgress(resolver);
    // Shortest way round the contour: the beam never takes the long way to a
    // point just behind it.
    final delta = ((target - from) + 0.5) % 1.0 - 0.5;
    final step = _smoothDamp(
      current: from,
      target: from + delta,
      velocity: _followVelocity,
      dt: dt,
      response: _followResponseSeconds,
    );
    _followVelocity = step.velocity;
    _followValue = step.value % 1.0;
    if (widget.progress == null) _driven.value = _followValue;
  }

  double _timedProgress(BeamPhaseResolver resolver) =>
      resolver.sample(_clock.elapsedSeconds, 1).travelProgress;

  // Hands the sweep back to the clock where the pointer left it. Shifting
  // the travel timeline is the same move as a phase offset, so the beam
  // carries on from here instead of snapping back to its own schedule.
  void _releaseFollow() {
    final held = _followValue;
    _followValue = null;
    _followVelocity = 0;
    _driven.value = widget.progress;
    final resolver = _resolver;
    if (held == null || resolver == null || _cycleSeconds <= 0) return;
    final phases = resolver.sample(_clock.elapsedSeconds, 1);
    var delta = held - phases.travelProgress;
    // Travel time always runs forward; a mirrored cycle spends it backwards.
    if (phases.reversedNow) delta = -delta;
    delta = ((delta + 0.5) % 1.0) - 0.5;
    resolver.travelTimeOffset += delta * _cycleSeconds;
  }

  // ─── Offscreen pause ────────────────────────────────────────────────────

  bool get _pauseWhenOffscreen => _playback.pauseWhenOffscreen ?? true;

  // Watches the nearest enclosing Scrollable, if there is one and this beam
  // has a clock of its own to pause. Scrollable.maybeOf registers a
  // dependency, so a scroll view swapping its position re-runs this.
  void _syncScrollListener() {
    final scrollable = (_pauseWhenOffscreen && !_synced && !_frozen)
        ? Scrollable.maybeOf(context)
        : null;
    final position = scrollable?.position;
    if (position == _scrollPosition) return;
    _scrollPosition?.removeListener(_onScrollChanged);
    _scrollable = scrollable;
    _scrollPosition = position;
    if (position == null) {
      // Nothing left to tell this beam it is hidden, so it must not stay
      // paused on the strength of a check nobody will repeat.
      _resumeFromOffscreen();
      return;
    }
    position.addListener(_onScrollChanged);
    _scheduleOffscreenCheck();
  }

  void _onScrollChanged() => _scheduleOffscreenCheck();

  // Coalesced to one check per frame, and deferred to the end of it: a
  // scroll position moves before layout, so the beam's paint transform is
  // only settled once the frame is done.
  void _scheduleOffscreenCheck() {
    if (_offscreenCheckScheduled) return;
    _offscreenCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _offscreenCheckScheduled = false;
      _updateOffscreenPause();
    });
  }

  void _updateOffscreenPause() {
    if (!mounted || !_pauseWhenOffscreen || _synced || _frozen) return;
    final viewport = _scrollable?.context.findRenderObject();
    final self = context.findRenderObject();
    if (viewport is! RenderBox || self is! RenderBox) return;
    if (!viewport.attached ||
        !viewport.hasSize ||
        !self.attached ||
        !self.hasSize) {
      return;
    }
    final origin = self.localToGlobal(Offset.zero, ancestor: viewport);
    final visible = (origin & self.size)
        .inflate(_offscreenMarginPx)
        .overlaps(Offset.zero & viewport.size);
    if (visible) {
      _resumeFromOffscreen();
    } else {
      _pauseForOffscreen();
    }
  }

  void _pauseForOffscreen() {
    // A clock that is already stopped was stopped by someone else — a
    // controller, reduced motion, or a finished fade-out — and stays theirs.
    if (_pausedForOffscreen || !_clock.isRunning) return;
    _clock.pause();
    _pausedForOffscreen = true;
  }

  void _resumeFromOffscreen() {
    if (!_pausedForOffscreen) return;
    _pausedForOffscreen = false;
    // Reduced motion outranks visibility: a beam that must not move stays
    // still whether or not it is on screen.
    if (_motionFrozen || _pausedForReducedMotion) return;
    if (_clock.isVisible) _clock.resume();
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(BorderBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousPlayback = _playback;
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      oldWidget.controller?.detach(_clock);
      widget.controller?.attach(_clock);
    }
    if (oldWidget.speedListenable != widget.speedListenable) {
      oldWidget.speedListenable?.removeListener(_applySpeed);
      widget.speedListenable?.addListener(_applySpeed);
    }
    final variantChanged = oldWidget.variant != widget.variant;
    _resolveScheduling(retime: !variantChanged);
    if (variantChanged && !_synced) {
      // The fps cap is variant-bound; rebuild the clock.
      final wasVisible = _clock.isVisible;
      widget.controller?.detach(_clock);
      _detachTickListener();
      _ownClock!.dispose();
      _createOwnClock();
      _applySpeed();
      _applyFadeCurve();
      widget.controller?.attach(_clock);
      _syncTickListener();
      if (wasVisible && widget.controller == null && _active) _start();
    }
    _applyReducedMotionChange();
    _applySchedulingTransition(
      previousPlayback,
      controllerChanged: controllerChanged,
    );
    // The pointer left: release now rather than waiting for a tick, which a
    // paused or stopped clock would never deliver.
    if (widget.follow == null && _followValue != null) {
      _releaseFollow();
      _syncTickListener();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _durationStartedAt = null;
    widget.speedListenable?.removeListener(_applySpeed);
    _scrollPosition?.removeListener(_onScrollChanged);
    _scrollPosition = null;
    _scrollable = null;
    _detachTickListener();
    widget.controller?.detach(_clock);
    _ownClock?.dispose();
    _driven.dispose();
    super.dispose();
  }

  BeamConfig _resolveConfig(
    BeamStyle style,
    BeamShape shape,
    Brightness ambient,
    TextDirection textDirection,
  ) {
    final brightness = (style.theme ?? BeamTheme.auto).resolve(ambient);
    final timing = _configTiming(_timing);
    final key = (
      widget.variant,
      style,
      shape,
      timing,
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
        timing: timing,
        textDirection: textDirection,
      );
      _resolver = BeamPhaseResolver(_config!)..hueTimeOffset = _hueTimeOffset;
      _syncResolverPlayback();
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
    final playing = (widget.controller != null || _synced)
        ? _clock.isVisible
        : _active && _autoPlay;
    final staticMode =
        _reducedApplied == BeamReducedMotion.staticFrame && playing;
    // BeamReducedMotion.hide leaves the child bare: no painter, no ticks.
    final hidden = _reducedApplied == BeamReducedMotion.hide;

    // An explicit progress owns the sweep; a follow gesture only steers what
    // the clock would otherwise drive.
    _driven.value = widget.progress?.clamp(0.0, 1.0) ?? _followValue;

    return RepaintBoundary(
      child: CustomPaint(
        painter: !hidden && widget.variant == BeamVariant.pulseOutside
            ? BeamPainter(
                clock: _clock,
                config: config,
                resolver: _resolver!,
                strategy: strategy,
                behind: true,
                staticMode: staticMode,
                progress: _driven,
                strength: widget.strengthListenable,
                frozenAt: _playback.debugFrozenAt,
              )
            : null,
        foregroundPainter: hidden
            ? null
            : BeamPainter(
                clock: _clock,
                config: config,
                resolver: _resolver!,
                strategy: strategy,
                behind: false,
                staticMode: staticMode,
                progress: _driven,
                strength: widget.strengthListenable,
                frozenAt: _playback.debugFrozenAt,
              ),
        // The child never re-rasterizes with the beam's frames.
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
