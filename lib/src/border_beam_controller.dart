import 'package:flutter/foundation.dart';

import 'animation/beam_clock.dart';

/// Programmatic playback control for a [BorderBeam].
///
/// When a controller is attached the widget gives up scheduling entirely:
/// `startAfter`, `duration`, and `autoPlay` must not be set, the beam starts
/// hidden, and playback is driven exclusively through this API:
///
/// ```dart
/// final controller = BorderBeamController();
///
/// BorderBeam.rotate(controller: controller, child: card);
///
/// controller.start();       // fade in, begin animating
/// controller.pause();       // freeze the current frame
/// controller.resume();
/// controller.speed = 2.0;   // double-time
/// controller.stop();        // fade out, halt
/// ```
class BorderBeamController extends ChangeNotifier {
  BeamClock? _clock;
  double _speed = 1;

  /// Whether a [BorderBeam] is currently attached.
  bool get isAttached => _clock != null;

  /// Whether the beam is visible (fading counts as visible).
  bool get isActive => _clock?.isVisible ?? false;

  /// Whether frames are being produced right now (false while paused or
  /// stopped).
  bool get isRunning => _clock?.isRunning ?? false;

  /// Playback rate multiplier (1.0 = normal). Must be positive.
  double get speed => _speed;
  set speed(double value) {
    assert(value > 0, 'speed must be positive');
    _speed = value;
    _clock?.speed = value;
    notifyListeners();
  }

  /// Starts the beam: resets the timeline and fades in.
  void start() {
    _clock?.activate();
    notifyListeners();
  }

  /// Stops the beam with a fade-out.
  void stop() {
    _clock?.deactivate();
    notifyListeners();
  }

  /// Freezes the animation on the current frame (no fade).
  void pause() {
    _clock?.pause();
    notifyListeners();
  }

  /// Resumes after [pause].
  void resume() {
    _clock?.resume();
    notifyListeners();
  }

  /// Jumps the animation timeline to [position].
  void seek(Duration position) {
    _clock?.seek(position.inMicroseconds / Duration.microsecondsPerSecond);
  }

  /// Called by [BorderBeam] when it starts using this controller. Internal —
  /// do not call from application code.
  void attach(BeamClock clock) {
    assert(
      _clock == null || _clock == clock,
      'BorderBeamController is already attached to another BorderBeam',
    );
    _clock = clock;
    clock.speed = _speed;
  }

  /// Called by [BorderBeam] when it stops using this controller. Internal —
  /// do not call from application code.
  void detach(BeamClock clock) {
    if (_clock == clock) _clock = null;
  }
}
