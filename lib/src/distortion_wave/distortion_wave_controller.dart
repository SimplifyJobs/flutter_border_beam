import 'package:flutter/foundation.dart';

import 'wave_source.dart';

/// Drives a `DistortionWave` from outside it: send the wave out, collapse it
/// back, or hold it at any point of its life.
///
/// Attached to a wave, the controller owns its playback: the wave's
/// `revealed` flag is ignored. A controller drives one wave at a time.
///
/// ```dart
/// final wave = DistortionWaveController();
///
/// DistortionWave(controller: wave, revealedChild: receipt, child: review)
///
/// // later
/// wave.reveal();
/// ```
///
/// Notifies its listeners when a run starts or arrives, and on [seek].
class DistortionWaveController extends ChangeNotifier {
  /// A controller resting on the first side, or on the second if [_revealed].
  DistortionWaveController({this._revealed = false});

  bool _revealed;
  WaveDriver? _driver;

  /// Whether the wave is on, or heading for, the revealed side.
  bool get isRevealed => _revealed;

  /// Where the wave is, 0 (the first side) to 1 (the revealed side).
  double get progress => _driver?.progress ?? (_revealed ? 1 : 0);

  /// Whether a run is in flight.
  bool get isRunning => _driver?.isRunning ?? false;

  /// Sends the wave out to the revealed side: from [source] if given and the
  /// wave is at rest, else from the source the run in flight opened from.
  void reveal({WaveSource? source}) => _go(true, source);

  /// Collapses the wave back onto the first side: into [source] if given and
  /// the wave is at rest, else into the source it opened from.
  void collapse({WaveSource? source}) => _go(false, source);

  /// Reveals when on the first side, collapses when revealed; from [source]
  /// if given and the wave is at rest.
  void toggle({WaveSource? source}) => _go(!_revealed, source);

  /// Holds the wave at [progress], 0–1, stopping any run.
  void seek(double progress) {
    _revealed = progress >= 0.5;
    _driver?.seekTo(progress.clamp(0.0, 1.0));
    notifyListeners();
  }

  void _go(bool reveal, WaveSource? source) {
    _revealed = reveal;
    _driver?.drive(reveal: reveal, source: source);
    notifyListeners();
  }

  void _changed() => notifyListeners();

  @override
  void dispose() {
    _driver = null;
    super.dispose();
  }
}

/// What a controller drives: implemented by the wave's state.
abstract interface class WaveDriver {
  /// Where the wave is, 0–1.
  double get progress;

  /// Whether a run is in flight.
  bool get isRunning;

  /// Starts a run toward the revealed side if [reveal], else back to the
  /// first side.
  void drive({required bool reveal, WaveSource? source});

  /// Holds the wave at [progress].
  void seekTo(double progress);
}

/// Wiring between a controller and the wave it drives. Not exported.
extension DistortionWaveControllerBinding on DistortionWaveController {
  /// Attaches [driver]; asserts the controller drives nothing else.
  void attach(WaveDriver driver) {
    assert(
      _driver == null || identical(_driver, driver),
      'A DistortionWaveController can drive only one DistortionWave at a '
      'time.',
    );
    _driver = driver;
  }

  /// Detaches [driver], if attached.
  void detach(WaveDriver driver) {
    if (identical(_driver, driver)) _driver = null;
  }

  /// Tells listeners a run has arrived.
  void arrived() => _changed();

  /// Tells the controller's listeners that the wave started a run it was
  /// not asked for through the controller (a hold let go).
  void started() => _changed();
}
