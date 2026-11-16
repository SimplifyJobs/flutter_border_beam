import 'package:flutter/foundation.dart';

/// The tiny white dots of a distortion wave: they hop toward the source
/// before the wave leaves it, then fly out with the front and burn out one by
/// one.
///
/// Every field is nullable and means *inherit*: from the nearest
/// `DistortionWaveTheme`, then from the wave type's tuned defaults.
@immutable
class WaveDots {
  /// Creates the dots' settings. Every omitted field is inherited.
  const WaveDots({
    this.count,
    this.size,
    this.reach,
    this.flight,
    this.gap,
    this.life,
    this.spread,
  }) : assert(
         count == null || (count >= 0 && count <= maxWaveDots),
         'count must be between 0 and $maxWaveDots',
       ),
       assert(
         spread == null || (spread >= 0 && spread <= 1),
         'spread must be between 0 and 1',
       );

  /// The most dots a wave draws.
  static const int maxWaveDots = 256;

  /// How many dots fall into the source and fly out with the wave. 0 draws
  /// none.
  final int? count;

  /// Diameter of the largest dot, in logical pixels.
  final double? size;

  /// How far from the source the farthest dot is born in the anticipation,
  /// in logical pixels.
  final double? reach;

  /// How far each dot flies toward the source in one hop, in logical pixels.
  final double? flight;

  /// How close to the source a dot comes before it has faded, in logical
  /// pixels.
  final double? gap;

  /// How long after the launch the last dot has faded out.
  final Duration? life;

  /// How far the dots are thrown, as a share of the front's way, 0–1: at 1
  /// the quickest ride the front off the view; less keeps them nearer the
  /// source, in view for longer.
  final double? spread;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value.
  WaveDots copyWith({
    int? count,
    double? size,
    double? reach,
    double? flight,
    double? gap,
    Duration? life,
    double? spread,
  }) => WaveDots(
    count: count ?? this.count,
    size: size ?? this.size,
    reach: reach ?? this.reach,
    flight: flight ?? this.flight,
    gap: gap ?? this.gap,
    life: life ?? this.life,
    spread: spread ?? this.spread,
  );

  /// Layers [other] over these settings: every non-null field of [other]
  /// wins.
  WaveDots merge(WaveDots? other) => other == null
      ? this
      : copyWith(
          count: other.count,
          size: other.size,
          reach: other.reach,
          flight: other.flight,
          gap: other.gap,
          life: other.life,
          spread: other.spread,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveDots &&
          other.count == count &&
          other.size == size &&
          other.reach == reach &&
          other.flight == flight &&
          other.gap == gap &&
          other.life == life &&
          other.spread == spread;

  @override
  int get hashCode =>
      Object.hash(count, size, reach, flight, gap, life, spread);

  @override
  String toString() {
    final fields = <String>[
      if (count != null) 'count: $count',
      if (size != null) 'size: $size',
      if (reach != null) 'reach: $reach',
      if (flight != null) 'flight: $flight',
      if (gap != null) 'gap: $gap',
      if (life != null) 'life: $life',
      if (spread != null) 'spread: $spread',
    ];
    return 'WaveDots(${fields.join(', ')})';
  }
}
