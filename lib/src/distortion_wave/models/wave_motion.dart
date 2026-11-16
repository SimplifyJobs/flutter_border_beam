import 'package:flutter/foundation.dart';

/// What happens around the source before the wave leaves it, and how the
/// wave leans with a touch.
///
/// Every field is nullable and means *inherit*: from the nearest
/// `DistortionWaveTheme`, then from the wave type's tuned defaults.
@immutable
class WaveMotion {
  /// Creates a motion. Every omitted field is inherited.
  const WaveMotion({
    this.pull,
    this.inhale,
    this.gatherGlow,
    this.gatherDots,
    this.launchGap,
    this.orientation,
  }) : assert(
         orientation == null || (orientation >= 0 && orientation <= 1),
         'orientation must be between 0 and 1',
       ),
       assert(
         gatherGlow == null || (gatherGlow >= 0 && gatherGlow <= 2),
         'gatherGlow must be between 0 and 2',
       ),
       assert(
         gatherDots == null || (gatherDots >= 0 && gatherDots <= 1),
         'gatherDots must be between 0 and 1',
       );

  /// How far the anticipation pulls content toward the source, in logical
  /// pixels.
  final double? pull;

  /// How far out the ring of colour that falls onto the source starts, in
  /// logical pixels.
  final double? inhale;

  /// How strong the colour is through the anticipation, 0–2: 1 has gathered
  /// half the front's full colour by the launch, 2 all of it, 0 none.
  final double? gatherGlow;

  /// How visible the dots hopping toward the source in the anticipation are,
  /// 0–1. 0 leaves only the dots that fly out with the front.
  final double? gatherDots;

  /// How far out from the source's outline the front starts, in logical
  /// pixels: 0 leaves from the source itself.
  final double? launchGap;

  /// How much the wave leans with where the source was touched, 0–1: 0 opens
  /// evenly from the whole source, 1 opens from under the finger and leans
  /// its way. The center wave never leans.
  final double? orientation;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value.
  WaveMotion copyWith({
    double? pull,
    double? inhale,
    double? gatherGlow,
    double? gatherDots,
    double? launchGap,
    double? orientation,
  }) => WaveMotion(
    pull: pull ?? this.pull,
    inhale: inhale ?? this.inhale,
    gatherGlow: gatherGlow ?? this.gatherGlow,
    gatherDots: gatherDots ?? this.gatherDots,
    launchGap: launchGap ?? this.launchGap,
    orientation: orientation ?? this.orientation,
  );

  /// Layers [other] over this motion: every non-null field of [other] wins.
  WaveMotion merge(WaveMotion? other) => other == null
      ? this
      : copyWith(
          pull: other.pull,
          inhale: other.inhale,
          gatherGlow: other.gatherGlow,
          gatherDots: other.gatherDots,
          launchGap: other.launchGap,
          orientation: other.orientation,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveMotion &&
          other.pull == pull &&
          other.inhale == inhale &&
          other.gatherGlow == gatherGlow &&
          other.gatherDots == gatherDots &&
          other.launchGap == launchGap &&
          other.orientation == orientation;

  @override
  int get hashCode =>
      Object.hash(pull, inhale, gatherGlow, gatherDots, launchGap, orientation);

  @override
  String toString() {
    final fields = <String>[
      if (pull != null) 'pull: $pull',
      if (inhale != null) 'inhale: $inhale',
      if (gatherGlow != null) 'gatherGlow: $gatherGlow',
      if (gatherDots != null) 'gatherDots: $gatherDots',
      if (launchGap != null) 'launchGap: $launchGap',
      if (orientation != null) 'orientation: $orientation',
    ];
    return 'WaveMotion(${fields.join(', ')})';
  }
}
