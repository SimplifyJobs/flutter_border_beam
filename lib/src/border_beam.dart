import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'animation/beam_clock.dart';
import 'animation/beam_phases.dart';
import 'beam_sync.dart';
import 'border_beam_controller.dart';
import 'border_beam_theme.dart';
import 'effects/beam_effect.dart';
import 'effects/effect_emitters.dart' show conicFraction;
import 'models/beam_colors.dart';
import 'models/beam_config.dart';
import 'models/beam_options.dart';
import 'models/beam_playback.dart';
import 'models/beam_shape.dart';
import 'models/beam_style.dart';
import 'models/beam_theme.dart';
import 'models/beam_timing.dart';
import 'models/model_validation.dart';
import 'render/beam_outline.dart';
import 'render/beam_painter.dart';
import 'render/beam_program.dart';
import 'render/beam_renderer.dart';

/// An animated glow around [child]'s border.
///
/// Pick what the light does with [effect] — a travelling beam, a streak on
/// one edge, or a breathing pulse:
///
/// ```dart
/// BorderBeam(
///   effect: const BeamEffect.rotate(),
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
///   effect: const BeamEffect.line(),
///   style: const BeamStyle(colors: BeamColors.sunset, strength: 0.8),
///   shape: const BeamShape.all(24, superellipse: true),
///   timing: const BeamTiming(cycleGap: Duration(seconds: 1)),
///   child: card,
/// )
/// ```
///
/// A field left null — [effect] included — falls through to the nearest
/// [BorderBeamTheme], then to the effect's own default.
///
/// The beam is drawn by one fragment shader in a single draw call over the
/// child: no offscreen layers, no blurs, no clips. It never intercepts
/// pointer events and adds no semantics — [child] is laid out and hit-tested
/// normally.
///
/// ## Scheduling
///
/// Without a [controller], the beam plays by itself: `playback.autoPlay`
/// starts it (after `playback.startAfter`, if given) and `playback.duration`
/// bounds the total play time (null loops forever). Toggling [active] fades
/// the beam in (about 0.5s) and out (about 0.6s) on critically damped
/// springs;
/// [onActivate]/[onDeactivate] fire when the fades complete.
///
/// With a [BorderBeamController] attached, the controller owns playback
/// exclusively: `playback.startAfter` and `playback.duration` must not be set
/// (on the widget or on a [BorderBeamTheme]), and the controller's own
/// `speed` replaces `timing.speed`.
///
/// ## Light outside the bounds
///
/// Light that reaches outward — rotate's `comet`, a positive
/// `shape.ringOffset` — paints past the child's bounds. Give them clip-free
/// room (padding in the parent; no tight [ClipRRect] above the beam).
class BorderBeam extends StatefulWidget {
  /// Creates a beam around [child].
  const BorderBeam({
    super.key,
    required this.child,
    this.effect,
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
    BeamEffect? effect,
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
         effect: effect,
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

  /// What the light does. Null inherits the [BorderBeamTheme]'s effect, and
  /// then [BeamEffect.rotate].
  final BeamEffect? effect;

  /// The wrapped content. Laid out and hit-tested normally.
  final Widget child;

  /// Shorthand for `style.colors`; a non-null value here wins over it.
  final BeamColors? colors;

  /// Shorthand for `playback.active`; a non-null value here wins over it.
  final bool? active;

  /// Shorthand for a uniform `shape.radius` in logical px; a non-null value
  /// here wins over it. Match your child's decoration radius.
  final double? borderRadius;

  /// Colours, surface brightness, strength, glow, and hue drift.
  final BeamStyle? style;

  /// Corner radii, corner family, stroke width, segment, and dashes.
  final BeamShape? shape;

  /// Cycle length, rest between sweeps, playback rate, direction, and the
  /// hue drift period.
  final BeamTiming? timing;

  /// Play state and scheduling. Ignored while a [controller] is attached.
  final BeamPlayback? playback;

  /// Optional playback controller. When set it owns playback exclusively —
  /// `playback.startAfter`/`duration` must be null and [active] is ignored.
  final BorderBeamController? controller;

  /// Drives the beam's travel from a value instead of the clock, 0–1.
  ///
  /// The sweep sits where this says rather than running with time, which
  /// turns the travelling effects into readouts: [BeamEffect.rotate] becomes
  /// a glowing progress ring, [BeamEffect.line] a progress bar. The clock
  /// keeps running underneath — the fade, the hue drift, and the line's
  /// spikes are all still alive, so the beam looks lit rather than frozen.
  ///
  /// Changing it repaints without re-resolving the beam's configuration, so
  /// it is cheap to drive from an animation. Null hands the travel back to
  /// the clock; the ambient effects have no travel to drive.
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
  ///   child: BorderBeam(follow: _follow, child: card),
  /// )
  /// ```
  ///
  /// [progress] wins over it, and the ambient effects ignore both.
  final Offset? follow;

  /// Scales the beam's opacity each frame, without rebuilding.
  ///
  /// The live twin of `BeamStyle.strength`: point it at a mic level, a
  /// download rate, or any other signal and the beam breathes with it. Values
  /// above 1 brighten, saturating at full opacity.
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

  /// Loads the beam shader ahead of the first beam.
  ///
  /// Optional: a beam loads it on demand and its fade-in hides the few
  /// milliseconds that takes. Await this in `main` (after
  /// `WidgetsFlutterBinding.ensureInitialized()`) to have the very first
  /// frame of every beam ready — and in tests, before pumping a beam whose
  /// pixels you check.
  static Future<void> precache() => BeamProgram.load();

  @override
  State<BorderBeam> createState() => _BorderBeamState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<BeamEffect>('effect', effect, defaultValue: null),
      )
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

// The cycle length a resolved timing implies for an effect.
double _cycleSecondsOf(BeamTiming timing, BeamEffect effect) =>
    (timing.cycle ?? effect.defaultCycle).inMicroseconds /
    Duration.microsecondsPerSecond;

// The rest between sweeps a resolved timing implies for an effect.
double _gapSecondsOf(BeamTiming timing, BeamEffect effect) => effect.travels
    ? (timing.cycleGap ?? effect.defaultCycleGap).inMicroseconds /
          Duration.microsecondsPerSecond
    : 0;

// The timing fields the painted config is built from — everything except
// `speed`, which is applied to the clock and never reaches BeamConfig.
// Keeping it out of the cache key is what lets a rate change ride through
// without re-resolving the config or rebuilding the phase resolver.
BeamTiming _configTiming(BeamTiming timing) => BeamTiming(
  cycle: timing.cycle,
  cycleGap: timing.cycleGap,
  direction: timing.direction,
  phaseOffset: timing.phaseOffset,
  huePeriod: timing.huePeriod,
);

// BeamReducedMotion.slow runs the clock at a quarter rate.
const double _slowMotionFactor = 0.25;

// How far outside the viewport a beam keeps running before its clock is
// paused: far enough that a beam scrolling into view is already running.
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

// TickerProviderStateMixin (not Single-): leaving a BeamSync creates a fresh
// clock, and with it a second ticker over this State's lifetime.
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
  BeamClock? _resetBoundTo;

  BeamClock get _clock => _sharedClock ?? _ownClock!;

  /// Whether this beam runs on a [BeamSync] group clock.
  bool get _synced => _sharedClock != null;

  // The effect in force: the widget's, else the theme's, else rotate.
  BeamEffect _effect = const BeamEffect.rotate();

  // Paints frames with the shared shader; owns this beam's FragmentShader.
  final BeamRenderer _renderer = BeamRenderer();

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
  double _travelTimeOffset = 0;
  double _breatheTimeOffset = 0;

  @override
  void initState() {
    super.initState();
    BeamProgram.load();
    _createOwnClock();
    // The theme is not reachable yet; the widget's own values carry the beam
    // until didChangeDependencies resolves them properly, before first build.
    _effect = widget.effect ?? const BeamEffect.rotate();
    _timing = widget.timing ?? const BeamTiming();
    _playback = widget._playbackInput ?? const BeamPlayback();
    validateBeamTiming(_timing);
    validateRepeat(_playback.repeat);
    _cycleSeconds = _cycleSecondsOf(_timing, _effect);
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
    final previousGap = _gapSecondsOf(_timing, _effect);
    final previousPhase = _timing.phaseOffset ?? 0;
    _effect = widget.effect ?? data.effect ?? const BeamEffect.rotate();
    _playback = playback;
    _timing = timing;
    _cycleSeconds = _cycleSecondsOf(timing, _effect);
    final nextGap = _gapSecondsOf(timing, _effect);
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
    _detachResetListener();
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
    _syncResetListener();
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
      onFadeComplete: _onFadeComplete,
    );
    // A replacement clock starts its own timeline at zero, so it takes the
    // reset listener and drops every correction that described the old one.
    _syncResetListener();
    _onTimelineReset();
  }

  void _start() {
    if (_motionFrozen || _synced || _frozen) return;
    _hasStarted = true;
    _clock.activate();
    _armDurationBudget();
  }

  // Every offset below is a correction measured against the running
  // timeline: the hue shift a retime accumulated, the line tracks' rescale
  // correction, and a `follow` hand-back. A restart puts elapsed time back
  // to zero, which leaves all of them describing a timeline that no longer
  // exists — so the clock tells us, and we drop them. A mid-fade-out
  // re-activation keeps its timeline, and so keeps the corrections.
  void _onTimelineReset() {
    _setHueTimeOffset(0);
    _setBreatheTimeOffset(0);
    _setTravelTimeOffset(0);
  }

  void _syncResetListener() {
    if (_resetBoundTo == _clock) return;
    _detachResetListener();
    _resetBoundTo = _clock..addTimelineResetListener(_onTimelineReset);
  }

  void _detachResetListener() {
    _resetBoundTo?.removeTimelineResetListener(_onTimelineReset);
    _resetBoundTo = null;
  }

  void _setHueTimeOffset(double seconds) {
    _hueTimeOffset = seconds;
    _resolver?.hueTimeOffset = seconds;
  }

  void _setTravelTimeOffset(double seconds) {
    _travelTimeOffset = seconds;
    _resolver?.travelTimeOffset = seconds;
  }

  void _setBreatheTimeOffset(double seconds) {
    _breatheTimeOffset = seconds;
    _resolver?.breatheTimeOffset = seconds;
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
    final before = _clock.elapsedSeconds;
    final oldPeriod = oldCycle + oldGap;
    final newPeriod = newCycle + newGap;
    // The resolver samples the shifted timeline, not the clock's raw elapsed
    // time, so sweep-or-gap has to be decided there: an offset beam resting
    // in the gap sits at a different point of the period than its elapsed
    // time alone says, and segmenting the raw timeline would drop it into
    // the middle of the sweep.
    final travel = _travelTimeOffset;
    final shifted = before + oldPhase * oldCycle + travel;
    final completed = oldPeriod <= 0 ? 0 : (shifted / oldPeriod).floor();
    final local = oldPeriod <= 0 ? shifted : shifted - completed * oldPeriod;
    final newLocal = local < oldCycle || oldGap <= 0
        ? local * newCycle / oldCycle
        : newCycle + (local - oldCycle) * newGap / oldGap;
    // Back out of the shifted timeline: the resolver re-applies the new
    // offset and the unchanged travel hand-back on top of what the clock
    // reports.
    var target =
        completed * newPeriod + newLocal - newPhase * newCycle - travel;
    // A follow hand-back leaves a negative travel offset behind, so backing
    // it out can put the target at or below zero even though the phase it
    // names is perfectly valid. Every track the target feeds is periodic, so
    // lift it by whole periods into a clock time that exists rather than
    // refusing the retime and letting the beam jump.
    if (target <= 0 && newPeriod > 0) {
      target += newPeriod * (1 + (-target / newPeriod).floor());
    }
    final factor = before == 0 ? newCycle / oldCycle : target / before;
    if (!factor.isFinite || factor <= 0) return;
    _clock.retime(factor);
    final after = _clock.elapsedSeconds;
    // The fixed-period hue tracks keep the timeline they had.
    _setHueTimeOffset(_hueTimeOffset + before - after);
    // The ambient track (BeamFramePhases.cycles) scales with the cycle, so
    // what holds its phase is the pure ratio rescale — not the target
    // above, which is bent by the gap, the phase offset, the hand-back, and
    // any whole-period lift. Put them back on the rescaled timeline.
    _setBreatheTimeOffset(
      (before + _breatheTimeOffset) * newCycle / oldCycle - after,
    );
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
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
    final size = box.size;
    final point = Offset(follow.dx * size.width, follow.dy * size.height);
    switch (config.effect) {
      case RotateEffect():
        final rect = (Offset.zero & size).inflate(config.ringOffset);
        final outline = BeamOutline(
          rect,
          config.borderRadius,
          superellipse: config.superellipse,
        );
        final segment = config.segment?.resolve(outline);
        if (segment == null) {
          // A rotating beam sweeps around the centre: its travel is the
          // pointer's angle.
          return conicFraction(point, rect.center);
        }
        final u = outline.nearestFraction(point);
        final span = BeamOutline.wrapFraction(segment.to - segment.from);
        if (span <= 0) return u;
        final along = BeamOutline.wrapFraction(u - segment.from);
        return (along / span).clamp(0.0, 1.0);
      case LineEffect(:final edge):
        // The streak rides one edge in reading order, so only the coordinate
        // along it counts.
        return switch (edge) {
          BeamEdge.top || BeamEdge.bottom => follow.dx,
          BeamEdge.left || BeamEdge.right => follow.dy,
        }.clamp(0.0, 1.0);
      case PulseEffect():
        // Ambient light has no travel to steer.
        return null;
    }
  }

  void _advanceFollow(double dt) {
    final target = _followTarget();
    final resolver = _resolver;
    if (target == null || resolver == null) return;
    final from = _followValue ?? _timedProgress(resolver);
    // A full-ring rotate loops, so it takes the shortest way round and never
    // the long way to a point just behind it. Every other sweep runs from one
    // end to the other and must not wrap through its ends.
    final config = _config;
    final loops = config?.effect is RotateEffect && config?.segment == null;
    final delta = loops ? ((target - from) + 0.5) % 1.0 - 0.5 : target - from;
    final step = _smoothDamp(
      current: from,
      target: from + delta,
      velocity: _followVelocity,
      dt: dt,
      response: _followResponseSeconds,
    );
    _followVelocity = step.velocity;
    _followValue = loops ? step.value % 1.0 : step.value.clamp(0.0, 1.0);
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
    _setTravelTimeOffset(_travelTimeOffset + delta * _cycleSeconds);
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
    _resolveScheduling(retime: oldWidget.effect == widget.effect);
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
    _detachResetListener();
    widget.controller?.detach(_clock);
    _ownClock?.dispose();
    _driven.dispose();
    _renderer.dispose();
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
    final key = (_effect, style, shape, timing, brightness, textDirection);
    if (_config == null || key != _configKey) {
      _configKey = key;
      _config = BeamConfig.resolve(
        effect: _effect,
        palette: (style.colors ?? BeamColors.colorful).resolve(),
        brightness: brightness,
        style: style,
        shape: shape,
        timing: timing,
        textDirection: textDirection,
      );
      // A config change rebuilds the resolver, and the time offsets are
      // timeline state the beam has already committed to: dropping them would
      // snap the hue back and throw away a follow hand-back.
      _resolver = BeamPhaseResolver(_config!)
        ..hueTimeOffset = _hueTimeOffset
        ..travelTimeOffset = _travelTimeOffset
        ..breatheTimeOffset = _breatheTimeOffset;
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
        foregroundPainter: hidden
            ? null
            : BeamPainter(
                renderer: _renderer,
                clock: _clock,
                config: config,
                resolver: _resolver!,
                staticMode: staticMode,
                devicePixelRatio:
                    MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
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
