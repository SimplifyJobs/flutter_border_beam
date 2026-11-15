import 'package:flutter/foundation.dart';

/// How a beam's colours drift over time.
enum BeamHueMode {
  /// The hue swings from `-hueShift` to `+hueShift` and back over one hue
  /// period — the default of most effects.
  pingPong,

  /// The hue advances through a full 360° revolution over one hue period,
  /// never reversing — the default of the breathing effects.
  continuous,

  /// The colours never drift: the palette is painted as given (rotated by
  /// `BeamStyle.hueBase`, if set).
  none,
}

/// Which way a travelling effect moves.
enum BeamDirection {
  /// Clockwise around the border, or left-to-right (top-to-bottom on a side
  /// edge) for `BeamEffect.line`.
  forward,

  /// The mirror of [forward]: counter-clockwise, or right-to-left.
  reverse,

  /// Alternates each cycle, running [forward] on one sweep and [reverse] on
  /// the next.
  bounce,
}

/// An edge of the beam's box — the edge `BeamEffect.line` rides, or the edge
/// a `BeamAnchor.edge` sits on.
enum BeamEdge {
  /// The top edge.
  top,

  /// The right edge.
  right,

  /// The bottom edge — `BeamEffect.line`'s default.
  bottom,

  /// The left edge.
  left,
}

/// What a beam does when the platform asks for reduced motion
/// (`MediaQuery.disableAnimationsOf`).
enum BeamReducedMotion {
  /// Ignores the request and keeps animating.
  animate,

  /// Paints a single static frame of the effect instead of animating — the
  /// default.
  staticFrame,

  /// Paints nothing at all, leaving the child bare.
  hide,

  /// Keeps animating at a quarter of the configured speed.
  slow,
}

/// How many cycles a beam runs before it stops.
///
/// A beam that reaches its last cycle fades out the way an inactive one
/// does, rather than cutting off mid-sweep.
///
/// ```dart
/// BorderBeam(
///   playback: const BeamPlayback(repeat: BeamRepeat.count(3)),
///   child: card,
/// )
/// ```
@immutable
class BeamRepeat {
  /// Loops forever — the default.
  const BeamRepeat.forever() : cycles = null;

  /// Runs exactly one cycle, then stops.
  const BeamRepeat.once() : cycles = 1;

  /// Runs [n] cycles, then stops. [n] must be at least 1.
  const BeamRepeat.count(int n)
    : assert(n >= 1, 'BeamRepeat.count needs at least one cycle'),
      cycles = n;

  /// How many cycles to run, or null to loop forever.
  final int? cycles;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BeamRepeat && other.cycles == cycles;

  @override
  int get hashCode => cycles.hashCode;

  @override
  String toString() =>
      cycles == null ? 'BeamRepeat.forever()' : 'BeamRepeat.count($cycles)';
}
