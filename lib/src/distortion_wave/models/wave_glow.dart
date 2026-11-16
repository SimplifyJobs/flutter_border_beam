import 'package:flutter/foundation.dart';

/// The colour of a distortion wave: the band riding its front, the colour it
/// leaves on the view's edges, and the hairline on the glass over it.
///
/// Every field is nullable and means *inherit*: from the nearest
/// `DistortionWaveTheme`, then from the wave type's tuned defaults.
@immutable
class WaveGlow {
  /// Creates a glow. Every omitted field is inherited.
  const WaveGlow({
    this.lead,
    this.tail,
    this.strength,
    this.rimWidth,
    this.rimUnevenness,
    this.rimStrength,
    this.rimSoftness,
    this.rimPulse,
    this.hairlineWidth,
    this.hairlineOpacity,
    this.hairlineWhite,
    this.cornerRadius,
  }) : assert(
         strength == null || (strength >= 0 && strength <= 1),
         'strength must be between 0 and 1',
       ),
       assert(
         rimStrength == null || (rimStrength >= 0 && rimStrength <= 1),
         'rimStrength must be between 0 and 1',
       ),
       assert(
         rimUnevenness == null || (rimUnevenness >= 0 && rimUnevenness <= 2),
         'rimUnevenness must be between 0 and 2',
       ),
       assert(
         rimPulse == null || (rimPulse >= 0 && rimPulse <= 1),
         'rimPulse must be between 0 and 1',
       ),
       assert(
         hairlineOpacity == null ||
             (hairlineOpacity >= 0 && hairlineOpacity <= 1),
         'hairlineOpacity must be between 0 and 1',
       ),
       assert(
         hairlineWhite == null || (hairlineWhite >= 0 && hairlineWhite <= 1),
         'hairlineWhite must be between 0 and 1',
       );

  /// Distance the colour feathers out ahead of the front, in logical pixels.
  final double? lead;

  /// Length of the colour trailing behind the front, in logical pixels.
  final double? tail;

  /// Peak opacity of the colour on the front, 0–1. 0 hides the band.
  final double? strength;

  /// How far in from the view's edges the colour reaches, in logical pixels.
  final double? rimWidth;

  /// How unequal the colour's thickness is along the edges, 0–2: 0 is even
  /// all the way round, 1 drifting lumps almost three times as thick as the
  /// average with thin stretches between; past 1 the lumps grow further and
  /// the thinnest stretches break off.
  final double? rimUnevenness;

  /// Peak opacity of the colour on the edges, 0–1. 0 leaves no colour behind.
  final double? rimStrength;

  /// How softly the colour on the edges is wiped away, in logical pixels.
  final double? rimSoftness;

  /// How alive the colour on the edges is, 0–1: its lumps drift and breathe,
  /// a soft brightness runs round the edge and its colours flow. 0 keeps only
  /// a slow drift.
  final double? rimPulse;

  /// Width of a hairline right on the view's edge, over the colour, in
  /// logical pixels. 0 draws none.
  final double? hairlineWidth;

  /// Peak opacity of the hairline, 0–1.
  final double? hairlineOpacity;

  /// How far the hairline whitens where the pulse's light runs, 0–1.
  final double? hairlineWhite;

  /// The corner radius of the view the wave fills — the screen's, or a
  /// sheet's — which the colour on the edges and its hairline follow, in
  /// logical pixels. The corners are Flutter's rounded superellipse, as a
  /// phone screen's are.
  final double? cornerRadius;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value.
  WaveGlow copyWith({
    double? lead,
    double? tail,
    double? strength,
    double? rimWidth,
    double? rimUnevenness,
    double? rimStrength,
    double? rimSoftness,
    double? rimPulse,
    double? hairlineWidth,
    double? hairlineOpacity,
    double? hairlineWhite,
    double? cornerRadius,
  }) => WaveGlow(
    lead: lead ?? this.lead,
    tail: tail ?? this.tail,
    strength: strength ?? this.strength,
    rimWidth: rimWidth ?? this.rimWidth,
    rimUnevenness: rimUnevenness ?? this.rimUnevenness,
    rimStrength: rimStrength ?? this.rimStrength,
    rimSoftness: rimSoftness ?? this.rimSoftness,
    rimPulse: rimPulse ?? this.rimPulse,
    hairlineWidth: hairlineWidth ?? this.hairlineWidth,
    hairlineOpacity: hairlineOpacity ?? this.hairlineOpacity,
    hairlineWhite: hairlineWhite ?? this.hairlineWhite,
    cornerRadius: cornerRadius ?? this.cornerRadius,
  );

  /// Layers [other] over this glow: every non-null field of [other] wins.
  WaveGlow merge(WaveGlow? other) => other == null
      ? this
      : copyWith(
          lead: other.lead,
          tail: other.tail,
          strength: other.strength,
          rimWidth: other.rimWidth,
          rimUnevenness: other.rimUnevenness,
          rimStrength: other.rimStrength,
          rimSoftness: other.rimSoftness,
          rimPulse: other.rimPulse,
          hairlineWidth: other.hairlineWidth,
          hairlineOpacity: other.hairlineOpacity,
          hairlineWhite: other.hairlineWhite,
          cornerRadius: other.cornerRadius,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveGlow &&
          other.lead == lead &&
          other.tail == tail &&
          other.strength == strength &&
          other.rimWidth == rimWidth &&
          other.rimUnevenness == rimUnevenness &&
          other.rimStrength == rimStrength &&
          other.rimSoftness == rimSoftness &&
          other.rimPulse == rimPulse &&
          other.hairlineWidth == hairlineWidth &&
          other.hairlineOpacity == hairlineOpacity &&
          other.hairlineWhite == hairlineWhite &&
          other.cornerRadius == cornerRadius;

  @override
  int get hashCode => Object.hash(
    lead,
    tail,
    strength,
    rimWidth,
    rimUnevenness,
    rimStrength,
    rimSoftness,
    rimPulse,
    hairlineWidth,
    hairlineOpacity,
    hairlineWhite,
    cornerRadius,
  );

  @override
  String toString() {
    final fields = <String>[
      if (lead != null) 'lead: $lead',
      if (tail != null) 'tail: $tail',
      if (strength != null) 'strength: $strength',
      if (rimWidth != null) 'rimWidth: $rimWidth',
      if (rimUnevenness != null) 'rimUnevenness: $rimUnevenness',
      if (rimStrength != null) 'rimStrength: $rimStrength',
      if (rimSoftness != null) 'rimSoftness: $rimSoftness',
      if (rimPulse != null) 'rimPulse: $rimPulse',
      if (hairlineWidth != null) 'hairlineWidth: $hairlineWidth',
      if (hairlineOpacity != null) 'hairlineOpacity: $hairlineOpacity',
      if (hairlineWhite != null) 'hairlineWhite: $hairlineWhite',
      if (cornerRadius != null) 'cornerRadius: $cornerRadius',
    ];
    return 'WaveGlow(${fields.join(', ')})';
  }
}
