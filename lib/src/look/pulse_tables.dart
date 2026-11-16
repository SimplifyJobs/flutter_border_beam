import 'dart:ui';

import 'look_blobs.dart';

// The pulse's blob tables. Their colours come from a palette's
// 9-blob border table (by index); the geometry here — sizes, and which
// oscillators breathe each blob — is the same for every palette.

/// Region/quad assignment for each of the 9 palette border blobs when used as
/// the pulse perimeter ring.
const List<({PulseRegion region, PulseQuad quad})> pulseRingMap = [
  (region: PulseRegion.r1, quad: PulseQuad.tl),
  (region: PulseRegion.r2, quad: PulseQuad.tl),
  (region: PulseRegion.r3, quad: PulseQuad.bl),
  (region: PulseRegion.r1, quad: PulseQuad.bl),
  (region: PulseRegion.r2, quad: PulseQuad.br),
  (region: PulseRegion.r3, quad: PulseQuad.br),
  (region: PulseRegion.r1, quad: PulseQuad.tr),
  (region: PulseRegion.r2, quad: PulseQuad.tr),
  (region: PulseRegion.r3, quad: PulseQuad.tr),
];

/// The pulse inner glow's radii for each of the 9 border blobs.
const List<Size> pulseInnerSizes = [
  Size(65, 35),
  Size(55, 30),
  Size(35, 65),
  Size(15, 30),
  Size(173, 28),
  Size(80, 22),
  Size(69, 28),
  Size(22, 38),
  Size(47, 44),
];

/// The pulse bloom: 7 of the 9 border colours, larger, at the border blobs'
/// own positions.
///
/// The bloom holds still: every blob sits at the breathing's average alpha
/// (`PulseParams.frozenBloomAlpha`).
const List<PulseBlobSpec> pulseInnerBloom = [
  PulseBlobSpec(ci: 0, w: 84, h: 48),
  PulseBlobSpec(ci: 1, w: 72, h: 42),
  PulseBlobSpec(ci: 2, w: 48, h: 84),
  PulseBlobSpec(ci: 4, w: 216, h: 38),
  PulseBlobSpec(ci: 5, w: 102, h: 31),
  PulseBlobSpec(ci: 6, w: 89, h: 38),
  PulseBlobSpec(ci: 8, w: 62, h: 58),
];
