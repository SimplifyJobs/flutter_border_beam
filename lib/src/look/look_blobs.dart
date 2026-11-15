import 'dart:ui';

import 'package:flutter/foundation.dart';

// The building blocks of the beam's look: soft radial colour blobs placed
// around the border, and the tables that place them.

/// One radial colour blob placed around the border.
///
/// An ellipse of [size] radii in logical px, centred at [position] — a
/// fraction of the decorated box, so `Offset(0.33, -0.074)` sits a third of
/// the way along the top edge, just above it — fading from [color] at the
/// centre to transparent at the rim.
@immutable
class BeamBlob {
  /// Creates a blob.
  const BeamBlob({
    required this.color,
    required this.position,
    required this.size,
  });

  /// The colour at the centre. May carry alpha.
  final Color color;

  /// Centre as a fraction of the box (values outside 0–1 are valid).
  final Offset position;

  /// Ellipse radii in logical px: horizontal, vertical.
  final Size size;

  /// A copy with a different [color], keeping the geometry.
  BeamBlob withColor(Color color) =>
      BeamBlob(color: color, position: position, size: size);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamBlob &&
          other.color == color &&
          other.position == position &&
          other.size == size;

  @override
  int get hashCode => Object.hash(color, position, size);

  @override
  String toString() => 'BeamBlob($color, $position, $size)';
}

/// A blob of the line effect. Line blobs ride the edge with the travelling
/// streak: they sit [offsetX] px along the edge from the streak's centre and
/// [offsetY] px off the edge, and their radii scale with the streak's
/// animated width and height.
@immutable
class LineBlob {
  /// Creates a line blob.
  const LineBlob({
    required this.color,
    required this.sizeW,
    required this.sizeH,
    required this.offsetX,
    required this.offsetY,
  });

  /// Blob colour (may carry alpha).
  final Color color;

  /// Base radius along the edge, in px.
  final double sizeW;

  /// Base radius across the edge, in px.
  final double sizeH;

  /// Offset along the edge from the streak centre, in px.
  final double offsetX;

  /// Offset off the edge, in px (positive = outward).
  final double offsetY;

  /// A copy with a different [color], keeping the geometry.
  LineBlob withColor(Color color) => LineBlob(
    color: color,
    sizeW: sizeW,
    sizeH: sizeH,
    offsetX: offsetX,
    offsetY: offsetY,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineBlob &&
          other.color == color &&
          other.sizeW == sizeW &&
          other.sizeH == sizeH &&
          other.offsetX == offsetX &&
          other.offsetY == offsetY;

  @override
  int get hashCode => Object.hash(color, sizeW, sizeH, offsetX, offsetY);

  @override
  String toString() =>
      'LineBlob($color, ${sizeW}x$sizeH, offset $offsetX, $offsetY)';
}

/// The two colours of one fixed bloom spike of the line effect: at its
/// centre and at its mid stop.
@immutable
class SpikePair {
  /// Creates a spike colour pair.
  const SpikePair(this.color1, this.color2);

  /// Colour at the spike centre.
  final Color color1;

  /// Colour at the spike's mid stop.
  final Color color2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpikePair && other.color1 == color1 && other.color2 == color2;

  @override
  int get hashCode => Object.hash(color1, color2);

  @override
  String toString() => 'SpikePair($color1, $color2)';
}

/// The line effect's two leading spike colours.
@immutable
class SpikeColors {
  /// Creates the spike colours.
  const SpikeColors({required this.primary, required this.secondary});

  /// The dominant spike colour.
  final Color primary;

  /// The secondary spike colour.
  final Color secondary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpikeColors &&
          other.primary == primary &&
          other.secondary == secondary;

  @override
  int get hashCode => Object.hash(primary, secondary);

  @override
  String toString() => 'SpikeColors($primary, $secondary)';
}

/// Which size/drift oscillator group (1–3) breathes a pulse blob, so
/// neighbouring blobs never breathe in lockstep.
enum PulseRegion {
  /// Group 1.
  r1,

  /// Group 2.
  r2,

  /// Group 3.
  r3,
}

/// Which corner's opacity oscillator modulates a pulse blob's alpha.
enum PulseQuad {
  /// Top-left.
  tl,

  /// Top-right.
  tr,

  /// Bottom-left.
  bl,

  /// Bottom-right.
  br,
}

/// A pulse table entry: the colour of border blob [ci], an oscillator
/// [region] and [quad], its own ellipse radii [w] × [h], and optionally its
/// own fractional position.
@immutable
class PulseBlobSpec {
  /// Creates a pulse blob spec. [x]/[y] default to the border blob's
  /// position.
  const PulseBlobSpec({
    required this.ci,
    required this.region,
    required this.quad,
    required this.w,
    required this.h,
    this.x,
    this.y,
  });

  /// Index of the colour in the 9-blob border table.
  final int ci;

  /// Size/drift oscillator group.
  final PulseRegion region;

  /// Corner opacity oscillator group.
  final PulseQuad quad;

  /// Horizontal radius in px.
  final double w;

  /// Vertical radius in px.
  final double h;

  /// Fractional x position, or null for the border blob's.
  final double? x;

  /// Fractional y position, or null for the border blob's.
  final double? y;
}
