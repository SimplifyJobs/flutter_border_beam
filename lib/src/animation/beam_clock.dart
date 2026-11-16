import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'spring_curve.dart';

/// The fade lifecycle stage of a beam.
enum BeamFadeStage {
  /// Not animating a fade (either idle or fully visible).
  none,

  /// Fading in ([BeamClock.fadeInSeconds]).
  fadingIn,

  /// Fading out ([BeamClock.fadeOutSeconds]).
  fadingOut,
}

/// The single time source of a beam instance.
///
/// Every animated value is a pure function of elapsed time, driven by ONE
/// [Ticker]. The clock integrates scaled
/// deltas so [speed] changes and pauses keep continuity, and runs the
/// fade-in/fade-out envelope (critically damped springs —
/// [BeamSpringCurve.fadeIn] and [BeamSpringCurve.fadeOut] — unless
/// [fadeCurve] replaces them). It notifies on every display frame — the beam is
/// cheap enough to run at the panel's full rate, 120Hz included.
class BeamClock extends ChangeNotifier {
  /// Creates a clock. [createTicker] is typically
  /// `TickerProviderStateMixin.createTicker`. [onFadeComplete] fires
  /// with `true` when a fade-in finishes and `false` when a fade-out
  /// finishes. [fadeCurve] replaces the spring easing of both fades.
  BeamClock({
    required Ticker Function(TickerCallback) createTicker,
    this.onFadeComplete,
    this.fadeCurve,
  }) : _createTicker = createTicker;

  /// Fade-in duration in seconds: [BeamSpringCurve.fadeIn]'s settling time,
  /// so the spring plays in real time.
  static const double fadeInSeconds = 0.475;

  /// Fade-out duration in seconds: [BeamSpringCurve.fadeOut]'s settling
  /// time.
  static const double fadeOutSeconds = 0.581;

  /// How far [pulse] lifts [boost] at its peak.
  static const double pulsePeak = 2;

  /// How far [flash] lifts [boost] at its peak.
  ///
  /// High enough that the beam saturates at full opacity, which is what
  /// makes the blink read as a flash.
  static const double flashPeak = 4;

  final Ticker Function(TickerCallback) _createTicker;

  /// Fired when a fade completes; the argument is whether the beam is now
  /// active (`true` after fade-in, `false` after fade-out).
  final ValueChanged<bool>? onFadeComplete;

  /// The easing both fades run on; null uses the springs
  /// ([BeamSpringCurve.fadeIn], [BeamSpringCurve.fadeOut]).
  ///
  /// Settable so a beam can pick up `BeamPlayback.fadeCurve` after its clock
  /// exists. It is read per frame, so a change lands on the next one — and
  /// mid-fade, since both stages read the curve from where they already are.
  Curve? fadeCurve;

  Ticker? _ticker;
  Duration _lastRaw = Duration.zero;
  double _elapsed = 0;
  double _activeSeconds = 0;
  double _speed = 1;
  BeamFadeStage _stage = BeamFadeStage.none;
  double _fadeStart = 0;
  double _fadeFromOpacity = 0;
  bool _visible = false;
  _Boost? _boost;

  /// Elapsed animation time in (speed-scaled) seconds.
  double get elapsedSeconds => _elapsed;

  /// Unscaled wall time accumulated while the ticker is running.
  ///
  /// Unlike [elapsedSeconds], this is unaffected by playback speed and does
  /// not advance while paused. Scheduling uses it for duration limits so an
  /// offscreen pause suspends the remaining play time too.
  double get activeSeconds => _activeSeconds;

  /// Whether the ticker is currently producing frames.
  bool get isRunning => _ticker?.isActive ?? false;

  /// Whether the beam is visible at all (fading counts as visible).
  bool get isVisible => _visible;

  /// The current fade stage.
  BeamFadeStage get stage => _stage;

  /// Whether a [pulse] or [flash] envelope is still playing.
  bool get isBoosting => _boost != null;

  /// The amplitude envelope on top of [fadeOpacity]: 1 at rest, rising to
  /// [pulsePeak] or [flashPeak] while a [pulse] or [flash] plays.
  ///
  /// The painter multiplies it into the fade it hands the resolver, so it
  /// scales every layer's opacity at once. Layer opacity is clamped at paint
  /// time, so a boost brightens the dim layers and saturates the ones that
  /// are already near full — it can never overflow.
  double get boost {
    final b = _boost;
    if (b == null) return 1;
    return 1 + b.envelopeAt(_elapsed) * (b.peak - 1);
  }

  /// Lifts the beam to [pulsePeak] and settles back over ~0.6s — a one-shot
  /// bump that marks a moment without restarting anything.
  ///
  /// No-op while the beam is hidden or frozen: there is no frame budget to
  /// play the envelope on.
  void pulse() => _startBoost(
    const _Boost(peak: pulsePeak, rise: 0.24, hold: 0, fall: 0.36),
  );

  /// Blinks the beam to [flashPeak], holds for 120ms, and decays — a
  /// sharper, brighter accent than [pulse].
  ///
  /// No-op while the beam is hidden or frozen.
  void flash() => _startBoost(
    const _Boost(peak: flashPeak, rise: 0, hold: 0.12, fall: 0.28),
  );

  void _startBoost(_Boost boost) {
    if (!_visible || !isRunning) return;
    _boost = boost.startingAt(_elapsed);
    notifyListeners();
  }

  /// Playback rate multiplier. Takes effect from the next frame.
  double get speed => _speed;
  set speed(double value) {
    assert(value > 0, 'speed must be positive');
    _speed = value;
  }

  /// The current fade envelope value (0–1).
  ///
  /// The default springs are critically damped and never leave 0–1; the
  /// result is clamped anyway, since a custom [fadeCurve] may overshoot.
  double get fadeOpacity {
    final raw = switch (_stage) {
      BeamFadeStage.none => _visible ? 1.0 : 0.0,
      BeamFadeStage.fadingIn =>
        _fadeFromOpacity +
            (1 - _fadeFromOpacity) *
                (fadeCurve ?? BeamSpringCurve.fadeIn).transform(
                  ((_elapsed - _fadeStart) / fadeInSeconds).clamp(0.0, 1.0),
                ),
      BeamFadeStage.fadingOut =>
        _fadeFromOpacity *
            (1 -
                (fadeCurve ?? BeamSpringCurve.fadeOut).transform(
                  ((_elapsed - _fadeStart) / fadeOutSeconds).clamp(0.0, 1.0),
                )),
    };
    return raw.clamp(0.0, 1.0);
  }

  // Called when `elapsedSeconds` goes back to zero. Kept separate from the
  // ChangeNotifier listeners, which fire every frame: a reset happens only
  // on a restart, so registering for it costs nothing per frame.
  final List<VoidCallback> _timelineResetListeners = <VoidCallback>[];

  /// Registers [listener] to hear that the timeline restarted from zero.
  ///
  /// Anything holding a correction *relative* to elapsed time — a hue shift,
  /// a rescale offset, a `follow` hand-back — is meaningless once the
  /// timeline restarts, and a shared group clock restarts without any one
  /// member being told. This is how they find out.
  void addTimelineResetListener(VoidCallback listener) =>
      _timelineResetListeners.add(listener);

  /// Removes a listener added with [addTimelineResetListener].
  void removeTimelineResetListener(VoidCallback listener) =>
      _timelineResetListeners.remove(listener);

  void _notifyTimelineReset() {
    // Copied: a listener is free to detach itself while being called.
    for (final listener in List<VoidCallback>.of(_timelineResetListeners)) {
      listener();
    }
  }

  /// Activates the beam: resets the timeline (matching CSS animation restart
  /// when `data-active` is re-applied) and fades in.
  void activate() {
    if (_visible && _stage != BeamFadeStage.fadingOut) return;
    if (_stage == BeamFadeStage.fadingOut) {
      // Mid-fade re-activation: continue the timeline, fade back in from the
      // current opacity so there is no visual jump.
      _fadeFromOpacity = fadeOpacity;
    } else {
      _elapsed = 0;
      _fadeFromOpacity = 0;
      _boost = null;
      _notifyTimelineReset();
    }
    _visible = true;
    _stage = BeamFadeStage.fadingIn;
    _fadeStart = _elapsed;
    _startTicker();
    notifyListeners();
  }

  /// Begins the fade-out; the ticker stops once it completes.
  void deactivate() {
    if (!_visible || _stage == BeamFadeStage.fadingOut) return;
    _fadeFromOpacity = fadeOpacity;
    _stage = BeamFadeStage.fadingOut;
    _fadeStart = _elapsed;
    _startTicker();
    notifyListeners();
  }

  /// Freezes the timeline, keeping the current frame on screen.
  void pause() => _ticker?.stop();

  /// Resumes after [pause].
  void resume() {
    if (_visible && !isRunning) _startTicker();
  }

  /// Jumps the timeline to [seconds].
  void seek(double seconds) {
    _elapsed = seconds;
    notifyListeners();
  }

  /// Rescales the timeline by [factor], keeping every cycle-relative phase
  /// where it is.
  ///
  /// Used when a beam's cycle duration changes mid-run: every animated
  /// track derived from the cycle reads `elapsed / cycleSeconds`, so
  /// multiplying elapsed time by `newCycle / oldCycle` leaves each track at
  /// the exact fraction it had. The fade envelope is a wall-clock schedule,
  /// not a cycle-relative one, so its anchor moves with the timeline rather
  /// than being scaled — the fade keeps its current opacity and its
  /// remaining duration.
  void retime(double factor) {
    assert(factor > 0, 'retime factor must be positive');
    final shift = _elapsed * factor - _elapsed;
    _elapsed += shift;
    _fadeStart += shift;
    _boost = _boost?.shiftedBy(shift);
    notifyListeners();
  }

  /// Marks the beam visible at full opacity without animating (used for
  /// reduced motion and for initially-active beams that must not fade in).
  void showStatic() {
    _visible = true;
    _stage = BeamFadeStage.none;
    _ticker?.stop();
    notifyListeners();
  }

  void _startTicker() {
    if (_ticker == null) {
      _ticker = _createTicker(_onTick);
    } else if (_ticker!.isActive) {
      return;
    }
    _lastRaw = Duration.zero;
    _ticker!.start();
  }

  void _onTick(Duration raw) {
    final deltaSeconds =
        (raw - _lastRaw).inMicroseconds / Duration.microsecondsPerSecond;
    _lastRaw = raw;
    _activeSeconds += deltaSeconds;
    _elapsed += deltaSeconds * _speed;

    if (_stage == BeamFadeStage.fadingIn &&
        _elapsed - _fadeStart >= fadeInSeconds) {
      _stage = BeamFadeStage.none;
      onFadeComplete?.call(true);
    } else if (_stage == BeamFadeStage.fadingOut &&
        _elapsed - _fadeStart >= fadeOutSeconds) {
      _stage = BeamFadeStage.none;
      _visible = false;
      _ticker!.stop();
      _elapsed = 0;
      _notifyTimelineReset();
      onFadeComplete?.call(false);
    }
    // Drop a spent boost, keeping the frame that lands back at 1.
    if (_boost?.isDoneAt(_elapsed) ?? false) _boost = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _boost = null;
    _timelineResetListeners.clear();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// One amplitude bump: a rise, a hold at the peak, and a decay back to rest.
class _Boost {
  const _Boost({
    required this.peak,
    required this.rise,
    required this.hold,
    required this.fall,
    this.startedAt = 0,
  });

  /// The multiplier at the top of the envelope.
  final double peak;

  /// Seconds spent climbing to [peak], on [BeamSpringCurve.pop].
  final double rise;

  /// Seconds held at [peak].
  final double hold;

  /// Seconds spent decaying back to rest, smootherstep-eased so the release
  /// has no visible corner at either end.
  final double fall;

  /// Timeline position the envelope started at.
  final double startedAt;

  double get _total => rise + hold + fall;

  _Boost startingAt(double now) =>
      _Boost(peak: peak, rise: rise, hold: hold, fall: fall, startedAt: now);

  _Boost shiftedBy(double shift) => _Boost(
    peak: peak,
    rise: rise,
    hold: hold,
    fall: fall,
    startedAt: startedAt + shift,
  );

  bool isDoneAt(double now) => now - startedAt >= _total;

  /// The 0–1 envelope at timeline position [now].
  double envelopeAt(double now) {
    var x = now - startedAt;
    if (x <= 0) return rise > 0 ? 0 : 1;
    if (x < rise) return BeamSpringCurve.pop.transform(x / rise);
    x -= rise;
    if (x < hold) return 1;
    x -= hold;
    if (fall <= 0 || x >= fall) return 0;
    return 1 - _smootherstep(x / fall);
  }

  static double _smootherstep(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * c * (c * (c * 6 - 15) + 10);
  }
}
