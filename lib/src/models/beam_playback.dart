import 'package:flutter/foundation.dart';

/// When a beam plays: whether it is on, whether it starts by itself, and how
/// long it runs.
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
    this.respectReducedMotion,
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

  /// Whether `MediaQuery.disableAnimationsOf` is honored by painting a single
  /// static frame instead of animating. Default true.
  final bool? respectReducedMotion;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamPlayback] to clear a field back to
  /// inherit.
  BeamPlayback copyWith({
    bool? active,
    bool? autoPlay,
    Duration? startAfter,
    Duration? duration,
    bool? respectReducedMotion,
  }) => BeamPlayback(
    active: active ?? this.active,
    autoPlay: autoPlay ?? this.autoPlay,
    startAfter: startAfter ?? this.startAfter,
    duration: duration ?? this.duration,
    respectReducedMotion: respectReducedMotion ?? this.respectReducedMotion,
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
          respectReducedMotion: other.respectReducedMotion,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamPlayback &&
          other.active == active &&
          other.autoPlay == autoPlay &&
          other.startAfter == startAfter &&
          other.duration == duration &&
          other.respectReducedMotion == respectReducedMotion;

  @override
  int get hashCode =>
      Object.hash(active, autoPlay, startAfter, duration, respectReducedMotion);

  @override
  String toString() {
    final fields = <String>[
      if (active != null) 'active: $active',
      if (autoPlay != null) 'autoPlay: $autoPlay',
      if (startAfter != null) 'startAfter: $startAfter',
      if (duration != null) 'duration: $duration',
      if (respectReducedMotion != null)
        'respectReducedMotion: $respectReducedMotion',
    ];
    return 'BeamPlayback(${fields.join(', ')})';
  }
}
