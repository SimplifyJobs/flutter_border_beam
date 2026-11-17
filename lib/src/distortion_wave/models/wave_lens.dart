import 'package:flutter/foundation.dart';

/// How a distortion wave bends what it passes: the swell that lifts content,
/// the colour fringing, the bend along the front and the progressive blur.
///
/// Every field is nullable and means *inherit*: from the nearest
/// `DistortionWaveTheme`, then from the wave type's tuned defaults.
@immutable
class WaveLens {
  /// Creates a lens. Every omitted field is inherited.
  const WaveLens({
    this.amplitude,
    this.width,
    this.aberration,
    this.swell,
    this.blur,
    this.blurAhead,
    this.blurBehind,
  }) : assert(
         blur == null || (blur >= 0 && blur <= 64),
         'blur must be between 0 and 64',
       );

  /// How far the swell lifts content as it passes, in logical pixels.
  final double? amplitude;

  /// Width of the swell, in logical pixels.
  final double? width;

  /// How far red and blue part either way, as a share of how far the content
  /// has moved; where nothing is moved, the colours stay together. 0 turns
  /// the fringing off.
  final double? aberration;

  /// How far the front bends along its length, in logical pixels.
  final double? swell;

  /// Blur radius on the front, in logical pixels. 0 turns the blur off.
  final double? blur;

  /// Distance ahead of the front over which the blur gathers, in logical
  /// pixels.
  final double? blurAhead;

  /// Distance behind the front over which the blur clears, in logical pixels.
  final double? blurBehind;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value.
  WaveLens copyWith({
    double? amplitude,
    double? width,
    double? aberration,
    double? swell,
    double? blur,
    double? blurAhead,
    double? blurBehind,
  }) => WaveLens(
    amplitude: amplitude ?? this.amplitude,
    width: width ?? this.width,
    aberration: aberration ?? this.aberration,
    swell: swell ?? this.swell,
    blur: blur ?? this.blur,
    blurAhead: blurAhead ?? this.blurAhead,
    blurBehind: blurBehind ?? this.blurBehind,
  );

  /// Layers [other] over this lens: every non-null field of [other] wins.
  WaveLens merge(WaveLens? other) => other == null
      ? this
      : copyWith(
          amplitude: other.amplitude,
          width: other.width,
          aberration: other.aberration,
          swell: other.swell,
          blur: other.blur,
          blurAhead: other.blurAhead,
          blurBehind: other.blurBehind,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveLens &&
          other.amplitude == amplitude &&
          other.width == width &&
          other.aberration == aberration &&
          other.swell == swell &&
          other.blur == blur &&
          other.blurAhead == blurAhead &&
          other.blurBehind == blurBehind;

  @override
  int get hashCode => Object.hash(
    amplitude,
    width,
    aberration,
    swell,
    blur,
    blurAhead,
    blurBehind,
  );

  @override
  String toString() {
    final fields = <String>[
      if (amplitude != null) 'amplitude: $amplitude',
      if (width != null) 'width: $width',
      if (aberration != null) 'aberration: $aberration',
      if (swell != null) 'swell: $swell',
      if (blur != null) 'blur: $blur',
      if (blurAhead != null) 'blurAhead: $blurAhead',
      if (blurBehind != null) 'blurBehind: $blurBehind',
    ];
    return 'WaveLens(${fields.join(', ')})';
  }
}
