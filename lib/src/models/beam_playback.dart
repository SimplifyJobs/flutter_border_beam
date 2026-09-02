import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'beam_options.dart';

/// When a beam plays: whether it is on, whether it starts by itself, how
/// long it runs, how many cycles it repeats, and what it does under reduced
/// motion.
///
/// Every field is nullable and means *inherit*. A field is resolved in this
/// order: the value set on the widget (the `active:` shorthand wins over
/// [active]), then the nearest `BorderBeamTheme`, then the default below.
///
/// A `BorderBeamController` takes playback over entirely: with one attached,
/// [startAfter] and [duration] must be null, and [active] and [autoPlay] are
/// ignored.
///
/// ```dart
/// BorderBeam.pulseInside(
///   playback: BeamPlayback(
///     active: isWorking,
///     startAfter: const Duration(milliseconds: 500),
///   ),
///   child: card,
/// )
/// ```
@immutable
class BeamPlayback {
  /// Creates a playback schedule. Every omitted field is inherited.
  const BeamPlayback({
    this.active,
    this.autoPlay,
    this.startAfter,
    this.duration,
    this.repeat,
    this.reducedMotion,
    this.pauseWhenOffscreen,
    this.fadeCurve,
    this.debugFrozenAt,
  });

  /// The web platform's `ease` timing function, as a [Curve].
  ///
  /// The fades default to a spring, which carries a little momentum. Hand
  /// this to [fadeCurve] to get the CSS transition the source library's own
  /// page fades with instead.
  static const Curve cssEase = Cubic(0.25, 0.1, 0.25, 1);

  /// Declarative play state: toggling fades the beam in (0.6s) and out
  /// (0.5s). Default true.
  final bool? active;

  /// Whether the beam starts by itself. Default true.
  final bool? autoPlay;

  /// Delay before autoplay starts. Null starts immediately.
  final Duration? startAfter;

  /// Total play time before the beam fades out by itself. Null plays forever.
  final Duration? duration;

  /// How many cycles the beam runs before it fades out by itself. Default
  /// [BeamRepeat.forever].
  final BeamRepeat? repeat;

  /// What the beam does when `MediaQuery.disableAnimationsOf` asks for
  /// reduced motion: a single static frame (the default), nothing at all,
  /// quarter-speed motion, or full motion regardless.
  final BeamReducedMotion? reducedMotion;

  /// Whether the beam's clock stops while the beam is scrolled out of its
  /// enclosing scrollable, with a 256px margin. Default true.
  ///
  /// A list of beams costs one ticker each; this is what keeps the ones
  /// nobody can see from spending frames. The beam is only *paused* — its
  /// play state, its fade, and its callbacks are untouched, so it comes back
  /// on screen exactly where it left off rather than restarting.
  ///
  /// It watches the nearest enclosing `Scrollable` and does nothing when
  /// there is none.
  final bool? pauseWhenOffscreen;

  /// The easing both fade envelopes run on. Null (the default) uses the
  /// spring, which overshoots slightly and settles.
  ///
  /// [cssEase] is the web's own `ease`, for a fade that matches the source
  /// library exactly.
  final Curve? fadeCurve;

  /// Pins the beam to one instant of its timeline and never starts its
  /// clock.
  ///
  /// Every animated value is a pure function of elapsed time, so a fixed
  /// time is a fixed frame: two runs a week apart paint the same pixels.
  /// That is what makes a beam screenshottable — golden tests, docs
  /// captures, design reviews.
  ///
  /// It reads the timeline from activation, so anything past the 0.6s
  /// fade-in is a fully-lit frame. The frozen frame is still sampled at the
  /// live strength — [BeamStyle.strength] and
  /// [BorderBeam.strengthListenable] dim it as they would any other frame,
  /// and a strength of 0 paints nothing.
  final Duration? debugFrozenAt;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamPlayback] to clear a field back to
  /// inherit.
  BeamPlayback copyWith({
    bool? active,
    bool? autoPlay,
    Duration? startAfter,
    Duration? duration,
    BeamRepeat? repeat,
    BeamReducedMotion? reducedMotion,
    bool? pauseWhenOffscreen,
    Curve? fadeCurve,
    Duration? debugFrozenAt,
  }) => BeamPlayback(
    active: active ?? this.active,
    autoPlay: autoPlay ?? this.autoPlay,
    startAfter: startAfter ?? this.startAfter,
    duration: duration ?? this.duration,
    repeat: repeat ?? this.repeat,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    pauseWhenOffscreen: pauseWhenOffscreen ?? this.pauseWhenOffscreen,
    fadeCurve: fadeCurve ?? this.fadeCurve,
    debugFrozenAt: debugFrozenAt ?? this.debugFrozenAt,
  );

  /// Layers [other] over this playback: every non-null field of [other] wins,
  /// every null one inherits from this playback.
  BeamPlayback merge(BeamPlayback? other) => other == null
      ? this
      : copyWith(
          active: other.active,
          autoPlay: other.autoPlay,
          startAfter: other.startAfter,
          duration: other.duration,
          repeat: other.repeat,
          reducedMotion: other.reducedMotion,
          pauseWhenOffscreen: other.pauseWhenOffscreen,
          fadeCurve: other.fadeCurve,
          debugFrozenAt: other.debugFrozenAt,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamPlayback &&
          other.active == active &&
          other.autoPlay == autoPlay &&
          other.startAfter == startAfter &&
          other.duration == duration &&
          other.repeat == repeat &&
          other.reducedMotion == reducedMotion &&
          other.pauseWhenOffscreen == pauseWhenOffscreen &&
          other.fadeCurve == fadeCurve &&
          other.debugFrozenAt == debugFrozenAt;

  @override
  int get hashCode => Object.hash(
    active,
    autoPlay,
    startAfter,
    duration,
    repeat,
    reducedMotion,
    pauseWhenOffscreen,
    fadeCurve,
    debugFrozenAt,
  );

  @override
  String toString() {
    final fields = <String>[
      if (active != null) 'active: $active',
      if (autoPlay != null) 'autoPlay: $autoPlay',
      if (startAfter != null) 'startAfter: $startAfter',
      if (duration != null) 'duration: $duration',
      if (repeat != null) 'repeat: $repeat',
      if (reducedMotion != null) 'reducedMotion: $reducedMotion',
      if (pauseWhenOffscreen != null) 'pauseWhenOffscreen: $pauseWhenOffscreen',
      if (fadeCurve != null) 'fadeCurve: $fadeCurve',
      if (debugFrozenAt != null) 'debugFrozenAt: $debugFrozenAt',
    ];
    return 'BeamPlayback(${fields.join(', ')})';
  }
}
