import 'dart:ui';

import '../models/beam_blob.dart';

// Verbatim transcription of the pulse gradient tables from the React library
// (border-beam v1.3.0, src/styles.ts lines ~685-744). Do not tweak values.

/// Region/quad assignment for each of the 9 palette border blobs when used as
/// the pulse perimeter ring (React `PULSE_RING_MAP`).
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

/// Override ellipse sizes for the pulse-inner `::before` layer's 9 blobs
/// (React `PULSE_INNER_SIZES`).
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

/// Pulse-inner bloom table (React `PULSE_INNER_BLOOM`): 7 of the 9 palette
/// colors, expanded, positions inherited from the palette blob.
const List<PulseBlobSpec> pulseInnerBloom = [
  PulseBlobSpec(
    ci: 0,
    region: PulseRegion.r1,
    quad: PulseQuad.tl,
    w: 84,
    h: 48,
  ),
  PulseBlobSpec(
    ci: 1,
    region: PulseRegion.r2,
    quad: PulseQuad.tl,
    w: 72,
    h: 42,
  ),
  PulseBlobSpec(
    ci: 2,
    region: PulseRegion.r3,
    quad: PulseQuad.bl,
    w: 48,
    h: 84,
  ),
  PulseBlobSpec(
    ci: 4,
    region: PulseRegion.r2,
    quad: PulseQuad.br,
    w: 216,
    h: 38,
  ),
  PulseBlobSpec(
    ci: 5,
    region: PulseRegion.r3,
    quad: PulseQuad.br,
    w: 102,
    h: 31,
  ),
  PulseBlobSpec(
    ci: 6,
    region: PulseRegion.r1,
    quad: PulseQuad.tr,
    w: 89,
    h: 38,
  ),
  PulseBlobSpec(
    ci: 8,
    region: PulseRegion.r3,
    quad: PulseQuad.tr,
    w: 62,
    h: 58,
  ),
];

/// Pulse-outside core/stroke table (React `PULSE_OUTER_CORE`): 8 blobs with
/// explicit edge positions. Used for BOTH the crisp stroke ring and the
/// outward core glow.
const List<PulseBlobSpec> pulseOuterCore = [
  PulseBlobSpec(
    ci: 0,
    region: PulseRegion.r1,
    quad: PulseQuad.tl,
    w: 80,
    h: 19,
    x: 0.27,
    y: 0,
  ),
  PulseBlobSpec(
    ci: 6,
    region: PulseRegion.r2,
    quad: PulseQuad.tr,
    w: 74,
    h: 11,
    x: 0.73,
    y: -0.01,
  ),
  PulseBlobSpec(
    ci: 7,
    region: PulseRegion.r3,
    quad: PulseQuad.tr,
    w: 15,
    h: 44,
    x: 1.0,
    y: 0.33,
  ),
  PulseBlobSpec(
    ci: 8,
    region: PulseRegion.r1,
    quad: PulseQuad.br,
    w: 19,
    h: 38,
    x: 1.01,
    y: 0.72,
  ),
  PulseBlobSpec(
    ci: 4,
    region: PulseRegion.r2,
    quad: PulseQuad.br,
    w: 84,
    h: 13,
    x: 0.67,
    y: 1.0,
  ),
  PulseBlobSpec(
    ci: 1,
    region: PulseRegion.r3,
    quad: PulseQuad.bl,
    w: 60,
    h: 21,
    x: 0.24,
    y: 1.01,
  ),
  PulseBlobSpec(
    ci: 2,
    region: PulseRegion.r1,
    quad: PulseQuad.bl,
    w: 17,
    h: 40,
    x: 0.0,
    y: 0.60,
  ),
  PulseBlobSpec(
    ci: 3,
    region: PulseRegion.r2,
    quad: PulseQuad.tl,
    w: 13,
    h: 32,
    x: -0.01,
    y: 0.28,
  ),
];

/// Pulse-outside bloom halo table (React `PULSE_OUTER_BLOOM`): 7 wider blobs.
const List<PulseBlobSpec> pulseOuterBloom = [
  PulseBlobSpec(
    ci: 0,
    region: PulseRegion.r1,
    quad: PulseQuad.tl,
    w: 110,
    h: 30,
    x: 0.27,
    y: 0.03,
  ),
  PulseBlobSpec(
    ci: 6,
    region: PulseRegion.r2,
    quad: PulseQuad.tr,
    w: 100,
    h: 20,
    x: 0.73,
    y: 0.01,
  ),
  PulseBlobSpec(
    ci: 7,
    region: PulseRegion.r3,
    quad: PulseQuad.tr,
    w: 26,
    h: 62,
    x: 1.0,
    y: 0.33,
  ),
  PulseBlobSpec(
    ci: 8,
    region: PulseRegion.r1,
    quad: PulseQuad.br,
    w: 30,
    h: 56,
    x: 1.01,
    y: 0.72,
  ),
  PulseBlobSpec(
    ci: 4,
    region: PulseRegion.r2,
    quad: PulseQuad.br,
    w: 120,
    h: 22,
    x: 0.67,
    y: 0.99,
  ),
  PulseBlobSpec(
    ci: 1,
    region: PulseRegion.r3,
    quad: PulseQuad.bl,
    w: 88,
    h: 32,
    x: 0.24,
    y: 0.99,
  ),
  PulseBlobSpec(
    ci: 2,
    region: PulseRegion.r1,
    quad: PulseQuad.bl,
    w: 28,
    h: 58,
    x: 0.0,
    y: 0.60,
  ),
];
