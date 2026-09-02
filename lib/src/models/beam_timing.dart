import 'package:flutter/foundation.dart';

import 'beam_options.dart';

/// How fast a beam moves: cycle length, the rest between sweeps, playback
/// rate, travel direction, and the periods of the tracks that do not ride
/// the cycle.
///
/// Every field is nullable and means *inherit*. A field is resolved in this
/// order: the value set on the widget, then the nearest `BorderBeamTheme`,
/// then the variant's preset.
///
/// ```dart
/// BorderBeam.rotate(
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
    this.beamCount,
    this.huePeriod,
    this.bloomHuePeriod,
    this.breatheFactor,
    this.spikeFactor,
    this.spike2Factor,
  }) : assert(
         speed == null || (speed > 0 && speed < double.infinity),
         'speed must be finite and positive',
       ),
       assert(
         phaseOffset == null || (phaseOffset >= 0 && phaseOffset <= 1),
         'phaseOffset must be between 0 and 1',
       ),
       assert(
         beamCount == null || beamCount >= 1,
         'beamCount must be at least 1',
       ),
       assert(
         breatheFactor == null ||
             (breatheFactor > 0 && breatheFactor < double.infinity),
         'breatheFactor must be finite and positive',
       ),
       assert(
         spikeFactor == null ||
             (spikeFactor > 0 && spikeFactor < double.infinity),
         'spikeFactor must be finite and positive',
       ),
       assert(
         spike2Factor == null ||
             (spike2Factor > 0 && spike2Factor < double.infinity),
         'spike2Factor must be finite and positive',
       );

  /// Length of one animation cycle. Defaults to the variant preset: 1.96s for
  /// rotate and small, 3.1s for line, 2.3s for the pulse variants.
  ///
  /// Changing it while the beam runs retimes the animation in place: every
  /// track keeps the phase it was at, so the beam speeds up or slows down
  /// without a jump.
  final Duration? cycle;

  /// Rest between sweeps: after each cycle the beam parks at the end of its
  /// travel and fades away for this long before the next sweep starts.
  /// Default [Duration.zero] — one sweep runs straight into the next.
  ///
  /// The fade at each end of the gap takes `min(0.25s, gap / 2)`. Hue,
  /// breathe, and spike tracks are textures rather than the sweep, so they
  /// keep running through the gap.
  ///
  /// The pulse variants ignore it: their breathing has no cycle boundary to
  /// rest at. Changing it needs no retime — the sweep keeps its position and
  /// the gap simply appears at the next cycle end.
  final Duration? cycleGap;

  /// Playback rate multiplier; must be positive. Default 1.
  ///
  /// Ignored while a `BorderBeamController` is attached — the controller's
  /// own `speed` owns the rate then.
  final double? speed;

  /// Which way the beam travels: clockwise (or left-to-right for the line
  /// variant), mirrored, or alternating each cycle. Default
  /// [BeamDirection.forward]. The pulse variants have no travel to direct.
  final BeamDirection? direction;

  /// Fraction of a cycle, 0–1, the timeline starts at, so two beams on the
  /// same cycle can run out of step. Default 0 — the cycle starts at its
  /// beginning.
  final double? phaseOffset;

  /// How many beams travel the contour at once, spaced equally along the
  /// cycle. Must be at least 1; default 1.
  final int? beamCount;

  /// One full period of the hue track.
  ///
  /// Defaults to 12s for rotate, small, and line (a ping-pong across
  /// ±`hueRange`), and to the pulse presets' own periods — 16s for
  /// pulse-inside, 14s for pulse-outside (a continuous revolution). Setting
  /// it overrides the period for every variant.
  ///
  /// Changing it mid-run re-phases the hue track — see [breatheFactor].
  final Duration? huePeriod;

  /// Period of the line variant's separate bloom hue track, a ping-pong
  /// across ±(`hueRange` + 10)°. Default 8s.
  ///
  /// Changing it mid-run re-phases the bloom hue track — see [breatheFactor].
  final Duration? bloomHuePeriod;

  /// The line beam's height-breathe period, as a multiple of [cycle].
  /// Default 1.3.
  ///
  /// Changing a track's own period mid-run **re-phases that track**: it
  /// resumes at `elapsed / newPeriod` rather than holding the fraction it
  /// had, so the line's height jumps once and then continues smoothly. The
  /// in-place retiming [cycle] documents is a different thing — it rescales
  /// elapsed time, which every cycle-derived track (this one included) rides
  /// through without a jump. There is no way to change a period *and* keep
  /// its phase, because the two describe different animations; the same
  /// applies to [spikeFactor], [spike2Factor], [huePeriod], and
  /// [bloomHuePeriod]. Set these once, or accept the single step.
  final double? breatheFactor;

  /// The line beam's first spike-scale period, as a multiple of [cycle].
  /// Default 1.33.
  ///
  /// Changing it mid-run re-phases the spike track — see [breatheFactor].
  final double? spikeFactor;

  /// The line beam's second spike-scale period, as a multiple of [cycle].
  /// Default 1.7.
  ///
  /// Changing it mid-run re-phases the spike track — see [breatheFactor].
  final double? spike2Factor;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamTiming] to clear a field back to
  /// inherit.
  BeamTiming copyWith({
    Duration? cycle,
    Duration? cycleGap,
    double? speed,
    BeamDirection? direction,
    double? phaseOffset,
    int? beamCount,
    Duration? huePeriod,
    Duration? bloomHuePeriod,
    double? breatheFactor,
    double? spikeFactor,
    double? spike2Factor,
  }) => BeamTiming(
    cycle: cycle ?? this.cycle,
    cycleGap: cycleGap ?? this.cycleGap,
    speed: speed ?? this.speed,
    direction: direction ?? this.direction,
    phaseOffset: phaseOffset ?? this.phaseOffset,
    beamCount: beamCount ?? this.beamCount,
    huePeriod: huePeriod ?? this.huePeriod,
    bloomHuePeriod: bloomHuePeriod ?? this.bloomHuePeriod,
    breatheFactor: breatheFactor ?? this.breatheFactor,
    spikeFactor: spikeFactor ?? this.spikeFactor,
    spike2Factor: spike2Factor ?? this.spike2Factor,
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
          beamCount: other.beamCount,
          huePeriod: other.huePeriod,
          bloomHuePeriod: other.bloomHuePeriod,
          breatheFactor: other.breatheFactor,
          spikeFactor: other.spikeFactor,
          spike2Factor: other.spike2Factor,
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
          other.beamCount == beamCount &&
          other.huePeriod == huePeriod &&
          other.bloomHuePeriod == bloomHuePeriod &&
          other.breatheFactor == breatheFactor &&
          other.spikeFactor == spikeFactor &&
          other.spike2Factor == spike2Factor;

  @override
  int get hashCode => Object.hashAll([
    cycle,
    cycleGap,
    speed,
    direction,
    phaseOffset,
    beamCount,
    huePeriod,
    bloomHuePeriod,
    breatheFactor,
    spikeFactor,
    spike2Factor,
  ]);

  @override
  String toString() {
    final fields = <String>[
      if (cycle != null) 'cycle: $cycle',
      if (cycleGap != null) 'cycleGap: $cycleGap',
      if (speed != null) 'speed: $speed',
      if (direction != null) 'direction: $direction',
      if (phaseOffset != null) 'phaseOffset: $phaseOffset',
      if (beamCount != null) 'beamCount: $beamCount',
      if (huePeriod != null) 'huePeriod: $huePeriod',
      if (bloomHuePeriod != null) 'bloomHuePeriod: $bloomHuePeriod',
      if (breatheFactor != null) 'breatheFactor: $breatheFactor',
      if (spikeFactor != null) 'spikeFactor: $spikeFactor',
      if (spike2Factor != null) 'spike2Factor: $spike2Factor',
    ];
    return 'BeamTiming(${fields.join(', ')})';
  }
}
