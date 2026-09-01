import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'animation/beam_clock.dart';

/// Runs every [BorderBeam] below it off one shared clock, so a group of
/// beams animates in lockstep.
///
/// A beam normally owns its own [Ticker]. Ten beams on a screen means ten
/// tickers, each started at a different instant, so their sweeps drift apart
/// — fine for beams that have nothing to do with each other, wrong for a row
/// of cards that should read as one system. [BeamSync] hands them a single
/// clock: one ticker for the whole subtree, one timeline, identical phases.
///
/// ```dart
/// BeamSync(
///   child: Row(
///     children: [
///       for (final card in cards)
///         BorderBeam.rotate(child: card),
///     ],
///   ),
/// )
/// ```
///
/// Beams stay individually configurable — palette, variant, shape, and
/// `BeamTiming.phaseOffset` are still per beam, so a group can run evenly
/// spaced around the cycle rather than perfectly on top of each other:
///
/// ```dart
/// BorderBeam.rotate(
///   timing: BeamTiming(phaseOffset: i / cards.length),
///   child: card,
/// )
/// ```
///
/// The group owns playback. A synced beam does not start, stop, pause, or
/// fade on its own, so `BeamPlayback`'s `active`, `autoPlay`, `startAfter`,
/// `duration`, and `repeat` are ignored below a [BeamSync] — use [active]
/// and [speed] here instead. A `BorderBeamController` is playback control
/// for one beam and asserts if it meets a [BeamSync].
///
/// Reduced motion pauses the shared clock for the whole group; each beam
/// still paints according to its own `BeamPlayback.reducedMotion`.
class BeamSync extends StatefulWidget {
  /// Creates a scope whose descendant beams share one clock.
  const BeamSync({
    super.key,
    required this.child,
    this.active = true,
    this.speed = 1,
  });

  /// The subtree whose beams share the clock.
  final Widget child;

  /// Whether the group is playing. Toggling fades every beam in (0.6s) or
  /// out (0.5s) together.
  final bool active;

  /// Playback rate for the group; must be positive.
  final double speed;

  /// The shared clock for [context], or null when there is no enclosing
  /// [BeamSync]. Internal — do not call from application code.
  static BeamClock? clockOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeamSyncScope>()?.clock;

  @override
  State<BeamSync> createState() => _BeamSyncState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('active', value: active, ifFalse: 'stopped'))
      ..add(DoubleProperty('speed', speed, defaultValue: 1.0));
  }
}

class _BeamSyncState extends State<BeamSync>
    with SingleTickerProviderStateMixin {
  late final BeamClock _clock = BeamClock(createTicker: createTicker)
    ..speed = widget.speed;

  bool _started = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion is delivered here, and the first frame needs it before
    // the clock starts: a group that begins under reduced motion never
    // starts a ticker at all.
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_started && reduced == _reduced) return;
    _reduced = reduced;
    if (!_started) {
      _started = true;
      if (!widget.active) return;
      if (reduced) {
        _clock.showStatic();
      } else {
        _clock.activate();
      }
      return;
    }
    if (reduced) {
      _clock.pause();
    } else {
      _clock.resume();
    }
  }

  @override
  void didUpdateWidget(BeamSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speed != oldWidget.speed) _clock.speed = widget.speed;
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      if (_reduced) {
        _clock.showStatic();
      } else {
        _clock.activate();
      }
    } else {
      _clock.deactivate();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BeamSyncScope(clock: _clock, child: widget.child);
}

/// Carries a [BeamSync]'s shared clock down the tree. Internal — read it
/// through [BeamSync.clockOf].
class BeamSyncScope extends InheritedWidget {
  /// Creates the scope for [clock].
  const BeamSyncScope({super.key, required this.clock, required super.child});

  /// The clock every beam in this subtree runs on.
  final BeamClock clock;

  @override
  bool updateShouldNotify(BeamSyncScope oldWidget) => oldWidget.clock != clock;
}
