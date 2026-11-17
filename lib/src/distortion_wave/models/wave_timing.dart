import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// How a distortion wave moves through its life: the pull before it leaves,
/// how long it travels and on what curve, and how long the colour it leaves
/// on the view's edges lingers.
///
/// Every field is nullable and means *inherit*: from the nearest
/// `DistortionWaveTheme`, then from the wave type's tuned defaults.
@immutable
class WaveTiming {
  /// Creates a timing. Every omitted field is inherited.
  const WaveTiming({
    this.anticipation,
    this.travel,
    this.easing,
    this.returnSpeed,
    this.linger,
    this.rimFade,
    this.rimEasing,
    this.hairlineLinger,
    this.hairlineFade,
  }) : assert(
         returnSpeed == null || (returnSpeed > 0 && returnSpeed <= 100),
         'returnSpeed must be greater than 0 and at most 100',
       );

  /// How long everything is pulled toward the source before the wave leaves
  /// it.
  final Duration? anticipation;

  /// From the wave leaving the source to its front having settled past the
  /// far side.
  final Duration? travel;

  /// How the front covers its way over [travel]: by default it leaves the
  /// source at full speed and settles softly, `Cubic(0.22, 1, 0.36, 1)`.
  final Curve? easing;

  /// How much faster the wave collapses back into the source than it opened;
  /// greater than 0 and at most 100.
  final double? returnSpeed;

  /// How long after the wave leaves the source the colour on the view's
  /// edges starts to be wiped away. Negative starts it before, so the wipe
  /// follows close behind the front while the wave is still moving.
  final Duration? linger;

  /// How long the colour on the edges takes to be wiped away once it goes.
  final Duration? rimFade;

  /// How the wipe moves over [rimFade]: by default ease-in-out, so the
  /// colour starts leaving gently and settles out gently.
  final Curve? rimEasing;

  /// How long the hairline on the edges holds on after the colour starts to
  /// be wiped away.
  final Duration? hairlineLinger;

  /// How long the hairline takes to be wiped away once it goes; longer than
  /// [rimFade], so it outlasts the colour.
  final Duration? hairlineFade;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value.
  WaveTiming copyWith({
    Duration? anticipation,
    Duration? travel,
    Curve? easing,
    double? returnSpeed,
    Duration? linger,
    Duration? rimFade,
    Curve? rimEasing,
    Duration? hairlineLinger,
    Duration? hairlineFade,
  }) => WaveTiming(
    anticipation: anticipation ?? this.anticipation,
    travel: travel ?? this.travel,
    easing: easing ?? this.easing,
    returnSpeed: returnSpeed ?? this.returnSpeed,
    linger: linger ?? this.linger,
    rimFade: rimFade ?? this.rimFade,
    rimEasing: rimEasing ?? this.rimEasing,
    hairlineLinger: hairlineLinger ?? this.hairlineLinger,
    hairlineFade: hairlineFade ?? this.hairlineFade,
  );

  /// Layers [other] over this timing: every non-null field of [other] wins.
  WaveTiming merge(WaveTiming? other) => other == null
      ? this
      : copyWith(
          anticipation: other.anticipation,
          travel: other.travel,
          easing: other.easing,
          returnSpeed: other.returnSpeed,
          linger: other.linger,
          rimFade: other.rimFade,
          rimEasing: other.rimEasing,
          hairlineLinger: other.hairlineLinger,
          hairlineFade: other.hairlineFade,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveTiming &&
          other.anticipation == anticipation &&
          other.travel == travel &&
          other.easing == easing &&
          other.returnSpeed == returnSpeed &&
          other.linger == linger &&
          other.rimFade == rimFade &&
          other.rimEasing == rimEasing &&
          other.hairlineLinger == hairlineLinger &&
          other.hairlineFade == hairlineFade;

  @override
  int get hashCode => Object.hash(
    anticipation,
    travel,
    easing,
    returnSpeed,
    linger,
    rimFade,
    rimEasing,
    hairlineLinger,
    hairlineFade,
  );

  @override
  String toString() {
    final fields = <String>[
      if (anticipation != null) 'anticipation: $anticipation',
      if (travel != null) 'travel: $travel',
      if (easing != null) 'easing: $easing',
      if (returnSpeed != null) 'returnSpeed: $returnSpeed',
      if (linger != null) 'linger: $linger',
      if (rimFade != null) 'rimFade: $rimFade',
      if (rimEasing != null) 'rimEasing: $rimEasing',
      if (hairlineLinger != null) 'hairlineLinger: $hairlineLinger',
      if (hairlineFade != null) 'hairlineFade: $hairlineFade',
    ];
    return 'WaveTiming(${fields.join(', ')})';
  }
}
