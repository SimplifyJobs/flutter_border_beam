import 'dart:ui';

import 'package:flutter/foundation.dart';

/// One radial-gradient color blob positioned around the border.
///
/// This is the core building block of every beam palette: an ellipse of
/// [size] radii in logical pixels, centered at [position] (expressed as a
/// fraction of the decorated box, so `Offset(0.33, -0.074)` is the CSS
/// position `33% -7.4%`), fading from [color] at the center to transparent
/// at the edge.
@immutable
class BeamBlob {
  /// Creates a blob. [position] is fractional (may exceed 0–1 to sit on or
  /// beyond the edge); [size] holds the ellipse radii in logical pixels.
  const BeamBlob({
    required this.color,
    required this.position,
    required this.size,
  });

  /// The blob color at the ellipse center. May carry alpha.
  final Color color;

  /// Center of the ellipse as a fraction of the painted rect
  /// (0,0 = top-left, 1,1 = bottom-right; values outside 0–1 are valid).
  final Offset position;

  /// Ellipse radii in logical pixels: [Size.width] is the horizontal radius
  /// and [Size.height] the vertical one, matching CSS
  /// `radial-gradient(ellipse W H ...)`, whose sizes are radii. Painters
  /// pass these straight through as `radiusX`/`radiusY`.
  final Size size;

  /// Returns a copy with a different [color], keeping the geometry.
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
  String toString() =>
      'BeamBlob(color: $color, position: $position, '
      'size: $size)';
}

/// A blob used by the line variant. Line blobs ride the bottom edge: their
/// x-position is `beamX + offsetX` px and their y sits at the bottom edge
/// shifted by [offsetY] px, with the ellipse scaled by the animated
/// width/height factors.
@immutable
class LineBlob {
  /// Creates a line blob with base ellipse radii and pixel offsets from the
  /// traveling beam center.
  const LineBlob({
    required this.color,
    required this.sizeW,
    required this.sizeH,
    required this.offsetX,
    required this.offsetY,
  });

  /// Blob color (may carry alpha for inner-glow tables).
  final Color color;

  /// Base horizontal ellipse radius in px, multiplied by the animated beam
  /// width factor and passed to the painter as `radiusX`.
  final double sizeW;

  /// Base vertical ellipse radius in px, multiplied by the animated beam
  /// height factor and passed to the painter as `radiusY`.
  final double sizeH;

  /// Horizontal offset in px from the traveling beam center.
  final double offsetX;

  /// Vertical offset in px from the bottom edge (positive = below).
  final double offsetY;

  /// Returns a copy with a different [color], keeping the geometry.
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
      'LineBlob(color: $color, size: ${sizeW}x$sizeH, '
      'offset: $offsetX, $offsetY)';
}

/// A pair of colors used by one fixed bloom spike of the line variant
/// (center color and mid-stop color).
@immutable
class SpikePair {
  /// Creates a spike color pair.
  const SpikePair(this.color1, this.color2);

  /// Color at the spike center.
  final Color color1;

  /// Color at the spike's mid gradient stop.
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

/// Primary/secondary spike colors used by the line variant's traveling
/// accents.
@immutable
class SpikeColors {
  /// Creates the spike color pair.
  const SpikeColors({required this.primary, required this.secondary});

  /// The dominant spike color.
  final Color primary;

  /// The secondary spike color.
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
  String toString() =>
      'SpikeColors(primary: $primary, '
      'secondary: $secondary)';
}

/// Which oscillator group (1–3) scales/drifts a pulse blob.
///
/// The pulse engine runs three independent size/drift oscillator groups so
/// neighboring blobs never breathe in lockstep.
enum PulseRegion {
  /// Oscillator group 1 (`--bw1/--bh1/--bx1/--by1`).
  r1,

  /// Oscillator group 2.
  r2,

  /// Oscillator group 3.
  r3,
}

/// Which corner opacity oscillator (`--bop-*`) modulates a pulse blob's
/// alpha.
enum PulseQuad {
  /// Top-left corner group.
  tl,

  /// Top-right corner group.
  tr,

  /// Bottom-left corner group.
  bl,

  /// Bottom-right corner group.
  br,
}

/// A pulse-table entry: references a palette blob by index [ci] and assigns
/// it an oscillator [region], a [quad] opacity group, an override ellipse
/// size, and (for the outer tables) an explicit fractional position.
class PulseBlobSpec {
  /// Creates a pulse blob spec. [x]/[y] are fractional positions; when null
  /// the referenced palette blob's own position is used.
  const PulseBlobSpec({
    required this.ci,
    required this.region,
    required this.quad,
    required this.w,
    required this.h,
    this.x,
    this.y,
  });

  /// Index of the color in the palette's 9-blob border table.
  final int ci;

  /// Size/drift oscillator group.
  final PulseRegion region;

  /// Corner opacity oscillator group.
  final PulseQuad quad;

  /// Base ellipse width in px.
  final double w;

  /// Base ellipse height in px.
  final double h;

  /// Fractional x position override (e.g. 1.01 = CSS `101%`), or null to use
  /// the palette blob's position.
  final double? x;

  /// Fractional y position override, or null to use the palette blob's
  /// position.
  final double? y;
}
