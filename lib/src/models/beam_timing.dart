import 'package:flutter/foundation.dart';

import 'beam_options.dart';

/// How fast a beam moves: cycle length, the rest between sweeps, playback
/// rate, travel direction, starting phase, and the period of the colour
/// drift.
///
/// Every field is nullable and means *inherit*. A field is resolved in this
/// order: the value set on the widget, then the nearest `BorderBeamTheme`,
/// then the effect's default.
///
/// ```dart
/// BorderBeam(
///   timing: const BeamTiming(
///     cycle: Duration(seconds: 3),
///     cycleGap: Duration(seconds: 1),
///   ),
///   child: card,
/// )
/// ```
@immutable
class BeamTiming {
  /// Creates a timing. Every omitted field is inherited.
  const BeamTiming({
    this.cycle,
    this.cycleGap,
    this.speed,
    this.direction,
    this.phaseOffset,
    this.huePeriod,
  }) : assert(
         speed == null || (speed > 0 && speed < double.infinity),
         'speed must be finite and positive',
       ),
       assert(
         phaseOffset == null || (phaseOffset >= 0 && phaseOffset <= 1),
         'phaseOffset must be between 0 and 1',
       );

  /// Length of one animation cycle: one sweep of a travelling effect, one
  /// breath or revolution of an ambient one. The default depends on the
  /// effect (`BeamEffect.defaultCycle`).
  ///
  /// Changing it while the beam runs retimes the animation in place: the
  /// beam keeps the phase it was at and speeds up or slows down without a
  /// jump.
  final Duration? cycle;

  /// Rest between sweeps: after each cycle a travelling effect parks at the
  /// end of its travel and fades away for this long before the next sweep
  /// starts. The default depends on the effect (`BeamEffect.defaultCycleGap`)
  /// — zero for most, so one sweep runs straight into the next.
  ///
  /// The colour drift keeps running through the gap. Ambient effects ignore
  /// it: their motion has no cycle boundary to rest at. Changing it needs no
  /// retime — the sweep keeps its position and the gap simply appears at the
  /// next cycle end.
  final Duration? cycleGap;

  /// Playback rate multiplier; must be positive. Default 1.
  ///
  /// Ignored while a `BorderBeamController` is attached — the controller's
  /// own `speed` owns the rate then.
  final double? speed;

  /// Which way a travelling effect moves: clockwise (left-to-right for the
  /// line effect), mirrored, or alternating each cycle. Default
  /// [BeamDirection.forward]. Ambient effects have no travel to direct.
  final BeamDirection? direction;

  /// Fraction of a cycle, 0–1, the timeline starts at, so two beams on the
  /// same cycle can run out of step. Default 0 — the cycle starts at its
  /// beginning.
  final double? phaseOffset;

  /// One full period of the colour drift: a swing across ±`hueShift` under
  /// `BeamHueMode.pingPong`, or a 360° revolution under
  /// `BeamHueMode.continuous`. The default depends on the effect
  /// (`BeamEffect.defaultHuePeriod`).
  ///
  /// Changing it mid-run **re-phases the drift**: it resumes at
  /// `elapsed / newPeriod` rather than holding the fraction it had, so the
  /// colours jump once and then continue smoothly.
  final Duration? huePeriod;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamTiming] to clear a field back to
  /// inherit.
  BeamTiming copyWith({
    Duration? cycle,
    Duration? cycleGap,
    double? speed,
    BeamDirection? direction,
    double? phaseOffset,
    Duration? huePeriod,
  }) => BeamTiming(
    cycle: cycle ?? this.cycle,
    cycleGap: cycleGap ?? this.cycleGap,
    speed: speed ?? this.speed,
    direction: direction ?? this.direction,
    phaseOffset: phaseOffset ?? this.phaseOffset,
    huePeriod: huePeriod ?? this.huePeriod,
  );

  /// Layers [other] over this timing: every non-null field of [other] wins,
  /// every null one inherits from this timing.
  BeamTiming merge(BeamTiming? other) => other == null
      ? this
      : copyWith(
          cycle: other.cycle,
          cycleGap: other.cycleGap,
          speed: other.speed,
          direction: other.direction,
          phaseOffset: other.phaseOffset,
          huePeriod: other.huePeriod,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamTiming &&
          other.cycle == cycle &&
          other.cycleGap == cycleGap &&
          other.speed == speed &&
          other.direction == direction &&
          other.phaseOffset == phaseOffset &&
          other.huePeriod == huePeriod;

  @override
  int get hashCode =>
      Object.hash(cycle, cycleGap, speed, direction, phaseOffset, huePeriod);

  @override
  String toString() {
    final fields = <String>[
      if (cycle != null) 'cycle: $cycle',
      if (cycleGap != null) 'cycleGap: $cycleGap',
      if (speed != null) 'speed: $speed',
      if (direction != null) 'direction: $direction',
      if (phaseOffset != null) 'phaseOffset: $phaseOffset',
      if (huePeriod != null) 'huePeriod: $huePeriod',
    ];
    return 'BeamTiming(${fields.join(', ')})';
  }
}
