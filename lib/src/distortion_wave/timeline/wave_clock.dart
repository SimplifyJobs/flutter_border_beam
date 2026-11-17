import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Drives a wave's progress, 0–1, with one [Ticker].
///
/// A run goes from wherever the progress is to a target, at the speed of a
/// full run: half the way takes half the time. Starting a new run interrupts
/// the one in flight without a jump, which is how flipping a wave mid-way
/// sends it back the way it came.
///
/// Notifies its listeners on every change of [progress].
class WaveClock extends ChangeNotifier implements ValueListenable<double> {
  /// A clock at [progress] whose ticker comes from [vsync].
  WaveClock({required TickerProvider vsync, double progress = 0})
    : _progress = progress.clamp(0.0, 1.0) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  double _progress;
  double _from = 0;
  double _to = 0;
  double _seconds = 0;
  Curve _curve = Curves.linear;
  VoidCallback? _onDone;
  bool _disposed = false;

  /// Where the wave is, 0 (at rest on the first side) to 1 (at rest on the
  /// second).
  double get progress => _progress;

  /// The same as [progress].
  @override
  double get value => _progress;

  /// Whether a run is in flight.
  bool get isRunning => _ticker.isActive;

  /// Where the run in flight is going, or null when idle.
  double? get target => isRunning ? _to : null;

  /// Runs from the current progress to [target] on [curve]. A whole run (0 to
  /// 1 or back) takes [fullSeconds]; a shorter one takes its share of that.
  ///
  /// [onDone] is called once the run arrives; not if it is interrupted by
  /// another [runTo], [jumpTo] or [stop], or the clock is disposed.
  void runTo(
    double target, {
    required double fullSeconds,
    Curve curve = Curves.linear,
    VoidCallback? onDone,
  }) {
    assert(!_disposed, 'WaveClock used after dispose');
    _ticker.stop();
    _onDone = null;
    _from = _progress;
    _to = target.clamp(0.0, 1.0);
    _curve = curve;
    _seconds = fullSeconds * (_to - _from).abs();
    if (_seconds <= 0 || _from == _to) {
      _set(_to);
      onDone?.call();
      return;
    }
    _onDone = onDone;
    _ticker.start();
  }

  /// Moves straight to [progress], stopping any run in flight.
  void jumpTo(double progress) {
    assert(!_disposed, 'WaveClock used after dispose');
    stop();
    _set(progress.clamp(0.0, 1.0));
  }

  /// Stops the run in flight where it is. Its `onDone` is not called.
  void stop() {
    _onDone = null;
    _ticker.stop();
  }

  void _tick(Duration elapsed) {
    final f =
        (elapsed.inMicroseconds / Duration.microsecondsPerSecond) / _seconds;
    if (f >= 1) {
      _ticker.stop();
      final done = _onDone;
      _onDone = null;
      _set(_to);
      done?.call();
      return;
    }
    _set(_from + (_to - _from) * _curve.transform(f));
  }

  void _set(double value) {
    if (value == _progress) return;
    _progress = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _onDone = null;
    _ticker.dispose();
    super.dispose();
  }
}
