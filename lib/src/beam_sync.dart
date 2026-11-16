/// @docImport 'package:flutter/scheduler.dart';
/// @docImport 'border_beam.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'animation/beam_clock.dart';
import 'models/beam_options.dart';
import 'models/model_validation.dart';

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
///         BorderBeam(child: card),
///     ],
///   ),
/// )
/// ```
///
/// Beams stay individually configurable — effect, palette, shape, and
/// `BeamTiming.phaseOffset` are still per beam, so a group can run evenly
/// spaced around the cycle rather than perfectly on top of each other:
///
/// ```dart
/// BorderBeam(
///   timing: BeamTiming(phaseOffset: i / cards.length),
///   child: card,
/// )
/// ```
///
/// The group owns playback. A synced beam does not start, stop, pause, or
/// fade on its own, so `BeamPlayback`'s `active`, `autoPlay`, `startAfter`,
/// `duration`, `repeat`, `fadeCurve`, and `pauseWhenOffscreen` are ignored
/// below a [BeamSync], as is `BeamTiming.speed` — use [active] and [speed]
/// here instead. A `BorderBeamController` is playback control
/// for one beam and asserts if it meets a [BeamSync].
///
/// Reduced motion is necessarily group-owned too: one shared clock cannot
/// simultaneously be static for one member and run slowly for another. Set
/// [reducedMotion] here; per-beam reduced-motion settings are ignored while
/// they are below a [BeamSync].
class BeamSync extends StatefulWidget {
  /// Creates a scope whose descendant beams share one clock.
  const BeamSync({
    super.key,
    required this.child,
    this.active = true,
    this.speed = 1,
    this.reducedMotion = BeamReducedMotion.staticFrame,
  }) : assert(
         speed > 0 && speed < double.infinity,
         'BeamSync.speed must be finite and positive',
       );

  /// The subtree whose beams share the clock.
  final Widget child;

  /// Whether the group is playing. Toggling fades every beam in (about 0.5s)
  /// or out (about 0.6s) together.
  final bool active;

  /// Playback rate for the group; must be finite and positive. Default 1.
  final double speed;

  /// How the whole group responds to the platform reduced-motion request.
  /// Default [BeamReducedMotion.staticFrame].
  final BeamReducedMotion reducedMotion;

  @override
  State<BeamSync> createState() => _BeamSyncState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('active', value: active, ifFalse: 'stopped'))
      ..add(DoubleProperty('speed', speed, defaultValue: 1.0))
      ..add(EnumProperty<BeamReducedMotion>('reducedMotion', reducedMotion));
  }
}

class _BeamSyncState extends State<BeamSync>
    with SingleTickerProviderStateMixin {
  late final BeamClock _clock = BeamClock(createTicker: createTicker)
    ..speed = validateSpeed(widget.speed, 'BeamSync.speed');

  bool _started = false;
  bool _reduced = false;

  // The constructor only asserts, so the rate is checked here as well, where
  // release builds run it before it reaches the shared clock.
  void _applySpeed() {
    final factor = _reduced && widget.reducedMotion == BeamReducedMotion.slow
        ? slowMotionFactor
        : 1.0;
    _clock.speed = validateSpeed(widget.speed, 'BeamSync.speed') * factor;
  }

  // Puts the group's clock back in motion. A clock that is mid-fade-out is
  // still visible, so resuming it would only carry the fade to invisible —
  // activate() is what reverses it, from the opacity it has reached.
  void _runClock() {
    if (_clock.isVisible && _clock.stage != BeamFadeStage.fadingOut) {
      _clock.resume();
    } else {
      _clock.activate();
    }
  }

  void _applyReducedMotion() {
    _applySpeed();
    if (!widget.active) return;
    final motion =
        !_reduced ||
        widget.reducedMotion == BeamReducedMotion.animate ||
        widget.reducedMotion == BeamReducedMotion.slow;
    if (motion) {
      _runClock();
      return;
    }
    _clock.showStatic();
  }

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
      _applyReducedMotion();
      return;
    }
    _applyReducedMotion();
  }

  @override
  void didUpdateWidget(BeamSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speed != oldWidget.speed ||
        widget.reducedMotion != oldWidget.reducedMotion) {
      _applyReducedMotion();
    }
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _applyReducedMotion();
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
  Widget build(BuildContext context) => BeamSyncScope(
    clock: _clock,
    reducedMotion: widget.reducedMotion,
    child: widget.child,
  );
}

/// Carries a [BeamSync]'s shared clock down the tree.
///
/// Package-internal: the library exports only [BeamSync], so these lookups
/// stay out of the public API. [BorderBeam] is their only caller.
class BeamSyncScope extends InheritedWidget {
  /// Creates the scope for [clock].
  const BeamSyncScope({
    super.key,
    required this.clock,
    required this.reducedMotion,
    required super.child,
  });

  /// The shared clock for [context], or null when there is no enclosing
  /// [BeamSync].
  static BeamClock? clockOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeamSyncScope>()?.clock;

  /// The reduced-motion policy owned by the nearest group, or null when the
  /// beam is not synchronized.
  static BeamReducedMotion? reducedMotionOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BeamSyncScope>()
      ?.reducedMotion;

  /// The clock every beam in this subtree runs on.
  final BeamClock clock;

  /// Group-owned reduced-motion behavior.
  final BeamReducedMotion reducedMotion;

  @override
  bool updateShouldNotify(BeamSyncScope oldWidget) =>
      oldWidget.clock != clock || oldWidget.reducedMotion != reducedMotion;
}
