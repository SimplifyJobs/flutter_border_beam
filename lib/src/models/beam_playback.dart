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
  });

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
  }) => BeamPlayback(
    active: active ?? this.active,
    autoPlay: autoPlay ?? this.autoPlay,
    startAfter: startAfter ?? this.startAfter,
    duration: duration ?? this.duration,
    repeat: repeat ?? this.repeat,
    reducedMotion: reducedMotion ?? this.reducedMotion,
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
          other.reducedMotion == reducedMotion;

  @override
  int get hashCode => Object.hash(
    active,
    autoPlay,
    startAfter,
    duration,
    repeat,
    reducedMotion,
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
    ];
    return 'BeamPlayback(${fields.join(', ')})';
  }
}
