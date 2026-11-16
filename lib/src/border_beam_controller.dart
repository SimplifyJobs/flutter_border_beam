/// @docImport 'border_beam.dart';
library;

import 'package:flutter/foundation.dart';

import 'animation/beam_clock.dart';

/// Programmatic playback control for a [BorderBeam].
///
/// When a controller is attached the widget gives up scheduling entirely:
/// `startAfter` and `duration` must not be set, `active` and `autoPlay` are
/// ignored, the beam starts hidden, and playback is driven exclusively
/// through this API:
///
/// ```dart
/// final controller = BorderBeamController();
///
/// BorderBeam(controller: controller, child: card);
///
/// controller.start();       // fade in, begin animating
/// controller.pause();       // freeze the current frame
/// controller.resume();
/// controller.speed = 2.0;   // double-time
/// controller.stop();        // fade out, halt
/// ```
///
/// One controller drives one beam at a time, and a beam below a `BeamSync`
/// cannot take one — the group owns its playback.
///
/// The controller notifies its listeners when one of its own methods is
/// called, not when the beam changes state by itself (a fade-out finishing,
/// a `BeamPlayback.repeat` budget running out): read [isActive] and
/// [isRunning] when you need them, or use `BorderBeam.onActivate` and
/// `BorderBeam.onDeactivate`.
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

  /// Playback rate multiplier (1.0 = normal). Must be finite and positive.
  ///
  /// Replaces `BeamTiming.speed` while attached. A
  /// `BorderBeam.speedListenable` still wins over it, and reduced motion's
  /// `BeamReducedMotion.slow` still quarters it.
  double get speed => _speed;
  set speed(double value) {
    assert(
      value > 0 && value.isFinite,
      'BorderBeamController.speed must be finite and positive, got $value',
    );
    if (value == _speed) return;
    _speed = value;
    // The attached beam listens and works out the rate in force from this.
    notifyListeners();
  }

  /// Starts the beam: restarts its timeline from zero and fades it in.
  ///
  /// Called mid-fade-out, it reverses the fade from the opacity reached
  /// instead, keeping the timeline. A no-op while the beam is already showing
  /// — including while it is paused; [resume] continues a paused beam.
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

  /// Bumps the beam's brightness once and lets it settle (~0.6s), without
  /// touching the timeline — the way to mark a moment (a message arrived, a
  /// step finished) on a beam that is already running.
  ///
  /// No-op while the beam is hidden or frozen.
  void pulse() {
    _clock?.pulse();
    notifyListeners();
  }

  /// Blinks the beam to full opacity, holds 120ms, and decays — a sharper,
  /// brighter accent than [pulse].
  ///
  /// No-op while the beam is hidden or frozen.
  void flash() {
    _clock?.flash();
    notifyListeners();
  }

  /// Jumps the animation timeline to [position]; a fade in progress carries
  /// on as it was.
  ///
  /// The position lasts only while the beam is showing: [start] begins the
  /// timeline at zero.
  void seek(Duration position) {
    _clock?.seek(position.inMicroseconds / Duration.microsecondsPerSecond);
    notifyListeners();
  }
}

/// Binds a [BorderBeamController] to the clock of the beam it drives.
///
/// Package-internal: the library exports only [BorderBeamController], so
/// application code never sees these. [BorderBeam] is the only caller.
extension BorderBeamControllerBinding on BorderBeamController {
  /// Called by [BorderBeam] when it starts using this controller.
  ///
  /// The beam applies [speed] to [clock] itself, so it can fold in its own
  /// `speedListenable` and reduced-motion rate.
  void attach(BeamClock clock) {
    assert(
      _clock == null || _clock == clock,
      'BorderBeamController is already attached to another BorderBeam. A '
      'controller drives one beam at a time.',
    );
    _clock = clock;
  }

  /// Called by [BorderBeam] when it stops using this controller.
  void detach(BeamClock clock) {
    if (_clock == clock) _clock = null;
  }
}
