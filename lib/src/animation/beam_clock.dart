import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'spring_curve.dart';

/// The fade lifecycle stage of a beam.
enum BeamFadeStage {
  /// Not animating a fade (either idle or fully visible).
  none,

  /// Fading in (0.6s).
  fadingIn,

  /// Fading out (0.5s).
  fadingOut,
}

/// The single time source of a beam instance.
///
/// Mirrors the source library's model: every animated value is a pure
/// function of elapsed time, driven by ONE [Ticker] (the React library uses
/// one shared requestAnimationFrame loop). The clock integrates scaled
/// deltas so [speed] changes and pauses keep continuity, runs the
/// fade-in/fade-out envelope (spring-eased via [FadeSpringCurve]), and can
/// cap its notification rate for the pulse variants (~30fps in the source).
class BeamClock extends ChangeNotifier {
  /// Creates a clock. [createTicker] is typically
  /// `TickerProviderStateMixin.createTicker`. [maxFps] caps notification
  /// frequency while not fading (null = every frame). [onFadeComplete] fires
  /// with `true` when a fade-in finishes and `false` when a fade-out
  /// finishes.
  BeamClock({
    required Ticker Function(TickerCallback) createTicker,
    this.maxFps,
    this.onFadeComplete,
  }) : _createTicker = createTicker;

  /// Fade-in duration in seconds (React `beam-fade-in 0.6s`).
  static const double fadeInSeconds = 0.6;

  /// Fade-out duration in seconds (React `beam-fade-out 0.5s`).
  static const double fadeOutSeconds = 0.5;

  // Spring-eased fade, isolated here so the curve is trivially replaceable.
  static const _fadeCurve = FadeSpringCurve.instance;

  final Ticker Function(TickerCallback) _createTicker;

  /// Optional notification rate cap (frames per second) while not fading.
  final double? maxFps;

  /// Fired when a fade completes; the argument is whether the beam is now
  /// active (`true` after fade-in, `false` after fade-out).
  final ValueChanged<bool>? onFadeComplete;

  Ticker? _ticker;
  Duration _lastRaw = Duration.zero;
  double _elapsed = 0;
  double _speed = 1;
  BeamFadeStage _stage = BeamFadeStage.none;
  double _fadeStart = 0;
  double _fadeFromOpacity = 0;
  double _lastNotify = -1;
  bool _visible = false;

  /// Elapsed animation time in (speed-scaled) seconds.
  double get elapsedSeconds => _elapsed;

  /// Whether the ticker is currently producing frames.
  bool get isRunning => _ticker?.isActive ?? false;

  /// Whether the beam is visible at all (fading counts as visible).
  bool get isVisible => _visible;

  /// The current fade stage.
  BeamFadeStage get stage => _stage;

  /// Playback rate multiplier. Takes effect from the next frame.
  double get speed => _speed;
  set speed(double value) {
    assert(value > 0, 'speed must be positive');
    _speed = value;
  }

  /// The current fade envelope value (0–1).
  ///
  /// The spring curve is lightly under-damped and overshoots its target by
  /// up to ~3%; the result is clamped so it is always a valid opacity.
  double get fadeOpacity {
    final raw = switch (_stage) {
      BeamFadeStage.none => _visible ? 1.0 : 0.0,
      BeamFadeStage.fadingIn =>
        _fadeFromOpacity +
            (1 - _fadeFromOpacity) *
                _fadeCurve.transform(
                  ((_elapsed - _fadeStart) / fadeInSeconds).clamp(0.0, 1.0),
                ),
      BeamFadeStage.fadingOut =>
        _fadeFromOpacity *
            (1 -
                _fadeCurve.transform(
                  ((_elapsed - _fadeStart) / fadeOutSeconds).clamp(0.0, 1.0),
                )),
    };
    return raw.clamp(0.0, 1.0);
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

  /// Marks the beam visible at full opacity without animating (used for
  /// reduced motion and for initially-active beams that must not fade in).
  void showStatic() {
    _visible = true;
    _stage = BeamFadeStage.none;
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
    _elapsed += deltaSeconds * _speed;

    var mustNotify = true;
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
      onFadeComplete?.call(false);
    } else if (_stage == BeamFadeStage.none && maxFps != null) {
      // Rate cap (pulse variants): skip paint-frame notifications, matching
      // the source's ~30fps pulse driver. Time still accumulates.
      final interval = 1 / maxFps! - 0.002;
      if (_elapsed - _lastNotify < interval) mustNotify = false;
    }
    if (mustNotify) {
      _lastNotify = _elapsed;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}
