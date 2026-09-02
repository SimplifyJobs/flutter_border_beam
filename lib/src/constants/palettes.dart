import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/beam_blob.dart';

// Verbatim transcription of the color palette tables from the React library
// (border-beam v1.3.0, src/styles.ts): `colorPalettes`, `smallColorPalettes`,
// `lineColorPalettes`, `lineInnerGradientData`, `lineBloomColors`.
// CSS `pos: '33% -7.4%'` becomes `Offset(0.33, -0.074)`;
// `size: '70px 40px'` becomes `Size(70, 40)`. Do not tweak values.

/// The complete gradient-table bundle for one color preset.
class BeamPresetData {
  /// Creates a preset bundle.
  const BeamPresetData({
    required this.border,
    required this.spike,
    required this.spikeLt,
    required this.smallBorder,
    required this.smallInner,
    required this.lineDark,
    required this.lineLight,
    required this.lineInner,
    required this.lineBloomDark,
    required this.lineBloomLight,
  });

  /// 9 border blobs (rotate stroke, pulse ring/bloom color source).
  final List<BeamBlob> border;

  /// Line traveling spike colors, dark theme.
  final SpikeColors spike;

  /// Line traveling spike colors, light theme.
  final SpikeColors spikeLt;

  /// 8 compact border blobs for the small variant.
  final List<BeamBlob> smallBorder;

  /// 8 compact inner-glow blobs for the small variant (pre-baked alpha).
  final List<BeamBlob> smallInner;

  /// 9 traveling line blobs, dark theme.
  final List<LineBlob> lineDark;

  /// 9 traveling line blobs, light theme.
  final List<LineBlob> lineLight;

  /// 9 line inner-glow blobs (pre-baked alpha, theme-independent).
  final List<LineBlob> lineInner;

  /// 5 fixed bloom spike color pairs, dark theme.
  final List<SpikePair> lineBloomDark;

  /// 5 fixed bloom spike color pairs, light theme.
  final List<SpikePair> lineBloomLight;

  // Structural equality: derived bundles (custom/seed/lerp palettes) are
  // built fresh on every resolve, so two bundles carrying the same tables
  // must compare equal for `BeamConfig` — and therefore
  // `BeamPainter.shouldRepaint` — to see them as the same paint.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamPresetData &&
          listEquals(other.border, border) &&
          other.spike == spike &&
          other.spikeLt == spikeLt &&
          listEquals(other.smallBorder, smallBorder) &&
          listEquals(other.smallInner, smallInner) &&
          listEquals(other.lineDark, lineDark) &&
          listEquals(other.lineLight, lineLight) &&
          listEquals(other.lineInner, lineInner) &&
          listEquals(other.lineBloomDark, lineBloomDark) &&
          listEquals(other.lineBloomLight, lineBloomLight);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(border),
    spike,
    spikeLt,
    Object.hashAll(smallBorder),
    Object.hashAll(smallInner),
    Object.hashAll(lineDark),
    Object.hashAll(lineLight),
    Object.hashAll(lineInner),
    Object.hashAll(lineBloomDark),
    Object.hashAll(lineBloomLight),
  );
}

// ── colorful ────────────────────────────────────────────────────────────────

/// Rainbow preset (React `colorful`). The default.
const BeamPresetData colorfulPreset = BeamPresetData(
  border: [
    BeamBlob(
      color: Color.fromRGBO(255, 50, 100, 1),
      position: Offset(0.33, -0.074),
      size: Size(70, 40),
    ),
    BeamBlob(
      color: Color.fromRGBO(40, 140, 255, 1),
      position: Offset(0.12, -0.05),
      size: Size(60, 35),
    ),
    BeamBlob(
      color: Color.fromRGBO(50, 200, 80, 1),
      position: Offset(0.021, 0.683),
      size: Size(40, 70),
    ),
    BeamBlob(
      color: Color.fromRGBO(30, 185, 170, 1),
      position: Offset(0.021, 0.683),
      size: Size(20, 35),
    ),
    BeamBlob(
      color: Color.fromRGBO(100, 70, 255, 1),
      position: Offset(0.744, 1),
      size: Size(180, 32),
    ),
    BeamBlob(
      color: Color.fromRGBO(40, 140, 255, 1),
      position: Offset(0.55, 1),
      size: Size(85, 26),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 120, 40, 1),
      position: Offset(0.939, 0),
      size: Size(74, 32),
    ),
    BeamBlob(
      color: Color.fromRGBO(240, 50, 180, 1),
      position: Offset(1, 0.271),
      size: Size(26, 42),
    ),
    BeamBlob(
      color: Color.fromRGBO(180, 40, 240, 1),
      position: Offset(1, 0.271),
      size: Size(52, 48),
    ),
  ],
  spike: SpikeColors(
    primary: Color.fromRGBO(255, 60, 80, 1),
    secondary: Color.fromRGBO(40, 190, 180, 0.98),
  ),
  spikeLt: SpikeColors(
    primary: Color.fromRGBO(200, 30, 60, 1),
    secondary: Color.fromRGBO(20, 150, 140, 1),
  ),
  smallBorder: [
    BeamBlob(
      color: Color.fromRGBO(50, 200, 80, 1),
      position: Offset(0.02, 0.68),
      size: Size(9, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(30, 185, 170, 1),
      position: Offset(0.02, 0.68),
      size: Size(4, 8),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 120, 40, 1),
      position: Offset(0.72, -0.03),
      size: Size(59, 9),
    ),
    BeamBlob(
      color: Color.fromRGBO(100, 70, 255, 1),
      position: Offset(0.74, 1),
      size: Size(42, 7),
    ),
    BeamBlob(
      color: Color.fromRGBO(240, 50, 180, 1),
      position: Offset(1, 0.27),
      size: Size(10, 17),
    ),
    BeamBlob(
      color: Color.fromRGBO(180, 40, 240, 1),
      position: Offset(1, 0.27),
      size: Size(10, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(40, 140, 255, 1),
      position: Offset(1, 0.27),
      size: Size(5, 10),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 50, 100, 1),
      position: Offset(1, 0.27),
      size: Size(11, 12),
    ),
  ],
  smallInner: [
    BeamBlob(
      color: Color.fromRGBO(50, 200, 80, 0.5),
      position: Offset(0.02, 0.68),
      size: Size(9, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(30, 185, 170, 0.45),
      position: Offset(0.02, 0.68),
      size: Size(4, 8),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 120, 40, 0.35),
      position: Offset(0.72, -0.03),
      size: Size(59, 9),
    ),
    BeamBlob(
      color: Color.fromRGBO(100, 70, 255, 0.35),
      position: Offset(0.74, 1),
      size: Size(42, 7),
    ),
    BeamBlob(
      color: Color.fromRGBO(240, 50, 180, 0.3),
      position: Offset(1, 0.27),
      size: Size(10, 17),
    ),
    BeamBlob(
      color: Color.fromRGBO(180, 40, 240, 0.4),
      position: Offset(1, 0.27),
      size: Size(10, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(40, 140, 255, 0.3),
      position: Offset(1, 0.27),
      size: Size(5, 10),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 50, 100, 0.3),
      position: Offset(1, 0.27),
      size: Size(11, 12),
    ),
  ],
  lineDark: [
    LineBlob(
      color: Color.fromRGBO(255, 50, 100, 1),
      sizeW: 36,
      sizeH: 36,
      offsetX: 0,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(40, 180, 220, 1),
      sizeW: 30,
      sizeH: 32,
      offsetX: 39,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(50, 200, 80, 1),
      sizeW: 33,
      sizeH: 28,
      offsetX: -36,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(180, 40, 240, 1),
      sizeW: 29,
      sizeH: 34,
      offsetX: -54,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 160, 30, 1),
      sizeW: 27,
      sizeH: 30,
      offsetX: 51,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(100, 70, 255, 1),
      sizeW: 36,
      sizeH: 24,
      offsetX: 21,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(40, 140, 255, 1),
      sizeW: 30,
      sizeH: 22,
      offsetX: -21,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(240, 50, 180, 1),
      sizeW: 25,
      sizeH: 28,
      offsetX: 66,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(30, 185, 170, 1),
      sizeW: 23,
      sizeH: 30,
      offsetX: -66,
      offsetY: -1,
    ),
  ],
  lineLight: [
    LineBlob(
      color: Color.fromRGBO(255, 50, 100, 1),
      sizeW: 45,
      sizeH: 36,
      offsetX: 0,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(40, 140, 255, 1),
      sizeW: 35,
      sizeH: 32,
      offsetX: 65,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(50, 200, 80, 1),
      sizeW: 40,
      sizeH: 28,
      offsetX: -60,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(180, 40, 240, 1),
      sizeW: 35,
      sizeH: 34,
      offsetX: -90,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(30, 185, 170, 1),
      sizeW: 38,
      sizeH: 30,
      offsetX: 85,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(100, 70, 255, 1),
      sizeW: 50,
      sizeH: 24,
      offsetX: 35,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(40, 140, 255, 1),
      sizeW: 40,
      sizeH: 22,
      offsetX: -35,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 120, 40, 1),
      sizeW: 35,
      sizeH: 28,
      offsetX: 110,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(240, 50, 180, 1),
      sizeW: 30,
      sizeH: 30,
      offsetX: -110,
      offsetY: -1,
    ),
  ],
  lineInner: [
    LineBlob(
      color: Color.fromRGBO(255, 50, 100, 0.48),
      sizeW: 33,
      sizeH: 30,
      offsetX: 0,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(40, 180, 220, 0.42),
      sizeW: 24,
      sizeH: 26,
      offsetX: 39,
      offsetY: -3,
    ),
    LineBlob(
      color: Color.fromRGBO(50, 200, 80, 0.48),
      sizeW: 27,
      sizeH: 24,
      offsetX: -36,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(180, 40, 240, 0.42),
      sizeW: 23,
      sizeH: 28,
      offsetX: -54,
      offsetY: -2,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 160, 30, 0.50),
      sizeW: 24,
      sizeH: 24,
      offsetX: 51,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(100, 70, 255, 0.45),
      sizeW: 30,
      sizeH: 20,
      offsetX: 21,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(40, 140, 255, 0.40),
      sizeW: 25,
      sizeH: 18,
      offsetX: -21,
      offsetY: -2,
    ),
    LineBlob(
      color: Color.fromRGBO(240, 50, 180, 0.45),
      sizeW: 21,
      sizeH: 24,
      offsetX: 66,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(30, 185, 170, 0.52),
      sizeW: 18,
      sizeH: 26,
      offsetX: -66,
      offsetY: -1,
    ),
  ],
  lineBloomDark: [
    SpikePair(Color.fromRGBO(100, 70, 255, 1), Color.fromRGBO(100, 70, 255, 1)),
    SpikePair(
      Color.fromRGBO(255, 170, 40, 0.59),
      Color.fromRGBO(255, 170, 40, 0.29),
    ),
    SpikePair(Color.fromRGBO(50, 200, 100, 1), Color.fromRGBO(50, 200, 100, 1)),
    SpikePair(
      Color.fromRGBO(200, 50, 240, 0.91),
      Color.fromRGBO(200, 50, 240, 0.45),
    ),
    SpikePair(Color.fromRGBO(40, 140, 255, 1), Color.fromRGBO(40, 140, 255, 1)),
  ],
  lineBloomLight: [
    SpikePair(Color.fromRGBO(80, 50, 200, 1), Color.fromRGBO(80, 50, 200, 0.8)),
    SpikePair(
      Color.fromRGBO(210, 130, 0, 0.7),
      Color.fromRGBO(210, 130, 0, 0.46),
    ),
    SpikePair(
      Color.fromRGBO(30, 160, 70, 1),
      Color.fromRGBO(30, 160, 70, 0.82),
    ),
    SpikePair(
      Color.fromRGBO(160, 30, 190, 1),
      Color.fromRGBO(160, 30, 190, 0.7),
    ),
    SpikePair(
      Color.fromRGBO(30, 100, 200, 1),
      Color.fromRGBO(30, 100, 200, 0.78),
    ),
  ],
);

// ── mono ────────────────────────────────────────────────────────────────────

/// Grayscale preset (React `mono`). Forces static colors and halves layer
/// opacity at paint time.
const BeamPresetData monoPreset = BeamPresetData(
  border: [
    BeamBlob(
      color: Color.fromRGBO(180, 180, 180, 1),
      position: Offset(0.33, -0.074),
      size: Size(70, 40),
    ),
    BeamBlob(
      color: Color.fromRGBO(140, 140, 140, 1),
      position: Offset(0.12, -0.05),
      size: Size(60, 35),
    ),
    BeamBlob(
      color: Color.fromRGBO(160, 160, 160, 1),
      position: Offset(0.021, 0.683),
      size: Size(40, 70),
    ),
    BeamBlob(
      color: Color.fromRGBO(130, 130, 130, 1),
      position: Offset(0.021, 0.683),
      size: Size(20, 35),
    ),
    BeamBlob(
      color: Color.fromRGBO(170, 170, 170, 1),
      position: Offset(0.744, 1),
      size: Size(180, 32),
    ),
    BeamBlob(
      color: Color.fromRGBO(150, 150, 150, 1),
      position: Offset(0.55, 1),
      size: Size(85, 26),
    ),
    BeamBlob(
      color: Color.fromRGBO(190, 190, 190, 1),
      position: Offset(0.939, 0),
      size: Size(74, 32),
    ),
    BeamBlob(
      color: Color.fromRGBO(145, 145, 145, 1),
      position: Offset(1, 0.271),
      size: Size(26, 42),
    ),
    BeamBlob(
      color: Color.fromRGBO(165, 165, 165, 1),
      position: Offset(1, 0.271),
      size: Size(52, 48),
    ),
  ],
  spike: SpikeColors(
    primary: Color.fromRGBO(200, 200, 200, 1),
    secondary: Color.fromRGBO(170, 170, 170, 1),
  ),
  spikeLt: SpikeColors(
    primary: Color.fromRGBO(80, 80, 80, 1),
    secondary: Color.fromRGBO(120, 120, 120, 1),
  ),
  smallBorder: [
    BeamBlob(
      color: Color.fromRGBO(160, 160, 160, 1),
      position: Offset(0.02, 0.68),
      size: Size(9, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(140, 140, 140, 1),
      position: Offset(0.02, 0.68),
      size: Size(4, 8),
    ),
    BeamBlob(
      color: Color.fromRGBO(180, 180, 180, 1),
      position: Offset(0.72, -0.03),
      size: Size(59, 9),
    ),
    BeamBlob(
      color: Color.fromRGBO(150, 150, 150, 1),
      position: Offset(0.74, 1),
      size: Size(42, 7),
    ),
    BeamBlob(
      color: Color.fromRGBO(170, 170, 170, 1),
      position: Offset(1, 0.27),
      size: Size(10, 17),
    ),
    BeamBlob(
      color: Color.fromRGBO(155, 155, 155, 1),
      position: Offset(1, 0.27),
      size: Size(10, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(145, 145, 145, 1),
      position: Offset(1, 0.27),
      size: Size(5, 10),
    ),
    BeamBlob(
      color: Color.fromRGBO(165, 165, 165, 1),
      position: Offset(1, 0.27),
      size: Size(11, 12),
    ),
  ],
  smallInner: [
    BeamBlob(
      color: Color.fromRGBO(160, 160, 160, 0.25),
      position: Offset(0.02, 0.68),
      size: Size(9, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(140, 140, 140, 0.22),
      position: Offset(0.02, 0.68),
      size: Size(4, 8),
    ),
    BeamBlob(
      color: Color.fromRGBO(180, 180, 180, 0.17),
      position: Offset(0.72, -0.03),
      size: Size(59, 9),
    ),
    BeamBlob(
      color: Color.fromRGBO(150, 150, 150, 0.17),
      position: Offset(0.74, 1),
      size: Size(42, 7),
    ),
    BeamBlob(
      color: Color.fromRGBO(170, 170, 170, 0.15),
      position: Offset(1, 0.27),
      size: Size(10, 17),
    ),
    BeamBlob(
      color: Color.fromRGBO(155, 155, 155, 0.20),
      position: Offset(1, 0.27),
      size: Size(10, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(145, 145, 145, 0.15),
      position: Offset(1, 0.27),
      size: Size(5, 10),
    ),
    BeamBlob(
      color: Color.fromRGBO(165, 165, 165, 0.15),
      position: Offset(1, 0.27),
      size: Size(11, 12),
    ),
  ],
  lineDark: [
    LineBlob(
      color: Color.fromRGBO(200, 200, 200, 1),
      sizeW: 36,
      sizeH: 36,
      offsetX: 0,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(170, 170, 170, 1),
      sizeW: 30,
      sizeH: 32,
      offsetX: 39,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(155, 155, 155, 1),
      sizeW: 33,
      sizeH: 28,
      offsetX: -36,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(185, 185, 185, 1),
      sizeW: 29,
      sizeH: 34,
      offsetX: -54,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(165, 165, 165, 1),
      sizeW: 27,
      sizeH: 30,
      offsetX: 51,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(180, 180, 180, 1),
      sizeW: 36,
      sizeH: 24,
      offsetX: 21,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(160, 160, 160, 1),
      sizeW: 30,
      sizeH: 22,
      offsetX: -21,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(175, 175, 175, 1),
      sizeW: 25,
      sizeH: 28,
      offsetX: 66,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(190, 190, 190, 1),
      sizeW: 23,
      sizeH: 30,
      offsetX: -66,
      offsetY: -1,
    ),
  ],
  lineLight: [
    LineBlob(
      color: Color.fromRGBO(100, 100, 100, 1),
      sizeW: 45,
      sizeH: 36,
      offsetX: 0,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(80, 80, 80, 1),
      sizeW: 35,
      sizeH: 32,
      offsetX: 65,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(90, 90, 90, 1),
      sizeW: 40,
      sizeH: 28,
      offsetX: -60,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(70, 70, 70, 1),
      sizeW: 35,
      sizeH: 34,
      offsetX: -90,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(85, 85, 85, 1),
      sizeW: 38,
      sizeH: 30,
      offsetX: 85,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(95, 95, 95, 1),
      sizeW: 50,
      sizeH: 24,
      offsetX: 35,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(75, 75, 75, 1),
      sizeW: 40,
      sizeH: 22,
      offsetX: -35,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(105, 105, 105, 1),
      sizeW: 35,
      sizeH: 28,
      offsetX: 110,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(65, 65, 65, 1),
      sizeW: 30,
      sizeH: 30,
      offsetX: -110,
      offsetY: -1,
    ),
  ],
  lineInner: [
    LineBlob(
      color: Color.fromRGBO(200, 200, 200, 0.48),
      sizeW: 33,
      sizeH: 30,
      offsetX: 0,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(170, 170, 170, 0.42),
      sizeW: 24,
      sizeH: 26,
      offsetX: 39,
      offsetY: -3,
    ),
    LineBlob(
      color: Color.fromRGBO(155, 155, 155, 0.48),
      sizeW: 27,
      sizeH: 24,
      offsetX: -36,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(185, 185, 185, 0.42),
      sizeW: 23,
      sizeH: 28,
      offsetX: -54,
      offsetY: -2,
    ),
    LineBlob(
      color: Color.fromRGBO(165, 165, 165, 0.50),
      sizeW: 24,
      sizeH: 24,
      offsetX: 51,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(180, 180, 180, 0.45),
      sizeW: 30,
      sizeH: 20,
      offsetX: 21,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(160, 160, 160, 0.40),
      sizeW: 25,
      sizeH: 18,
      offsetX: -21,
      offsetY: -2,
    ),
    LineBlob(
      color: Color.fromRGBO(175, 175, 175, 0.45),
      sizeW: 21,
      sizeH: 24,
      offsetX: 66,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(190, 190, 190, 0.52),
      sizeW: 18,
      sizeH: 26,
      offsetX: -66,
      offsetY: -1,
    ),
  ],
  lineBloomDark: [
    SpikePair(
      Color.fromRGBO(200, 200, 200, 1),
      Color.fromRGBO(200, 200, 200, 1),
    ),
    SpikePair(
      Color.fromRGBO(180, 180, 180, 0.59),
      Color.fromRGBO(180, 180, 180, 0.29),
    ),
    SpikePair(
      Color.fromRGBO(190, 190, 190, 1),
      Color.fromRGBO(190, 190, 190, 1),
    ),
    SpikePair(
      Color.fromRGBO(170, 170, 170, 0.91),
      Color.fromRGBO(170, 170, 170, 0.45),
    ),
    SpikePair(
      Color.fromRGBO(185, 185, 185, 1),
      Color.fromRGBO(185, 185, 185, 1),
    ),
  ],
  lineBloomLight: [
    SpikePair(Color.fromRGBO(80, 80, 80, 1), Color.fromRGBO(80, 80, 80, 0.8)),
    SpikePair(
      Color.fromRGBO(100, 100, 100, 0.7),
      Color.fromRGBO(100, 100, 100, 0.46),
    ),
    SpikePair(Color.fromRGBO(70, 70, 70, 1), Color.fromRGBO(70, 70, 70, 0.82)),
    SpikePair(Color.fromRGBO(90, 90, 90, 1), Color.fromRGBO(90, 90, 90, 0.7)),
    SpikePair(Color.fromRGBO(85, 85, 85, 1), Color.fromRGBO(85, 85, 85, 0.78)),
  ],
);

// ── ocean ───────────────────────────────────────────────────────────────────

/// Blue/purple preset (React `ocean`).
const BeamPresetData oceanPreset = BeamPresetData(
  border: [
    BeamBlob(
      color: Color.fromRGBO(100, 80, 220, 1),
      position: Offset(0.33, -0.074),
      size: Size(70, 40),
    ),
    BeamBlob(
      color: Color.fromRGBO(60, 120, 255, 1),
      position: Offset(0.12, -0.05),
      size: Size(60, 35),
    ),
    BeamBlob(
      color: Color.fromRGBO(80, 100, 200, 1),
      position: Offset(0.021, 0.683),
      size: Size(40, 70),
    ),
    BeamBlob(
      color: Color.fromRGBO(50, 140, 220, 1),
      position: Offset(0.021, 0.683),
      size: Size(20, 35),
    ),
    BeamBlob(
      color: Color.fromRGBO(120, 80, 255, 1),
      position: Offset(0.744, 1),
      size: Size(180, 32),
    ),
    BeamBlob(
      color: Color.fromRGBO(70, 130, 255, 1),
      position: Offset(0.55, 1),
      size: Size(85, 26),
    ),
    BeamBlob(
      color: Color.fromRGBO(140, 100, 240, 1),
      position: Offset(0.939, 0),
      size: Size(74, 32),
    ),
    BeamBlob(
      color: Color.fromRGBO(90, 110, 230, 1),
      position: Offset(1, 0.271),
      size: Size(26, 42),
    ),
    BeamBlob(
      color: Color.fromRGBO(130, 70, 255, 1),
      position: Offset(1, 0.271),
      size: Size(52, 48),
    ),
  ],
  spike: SpikeColors(
    primary: Color.fromRGBO(100, 120, 255, 1),
    secondary: Color.fromRGBO(130, 100, 220, 0.98),
  ),
  spikeLt: SpikeColors(
    primary: Color.fromRGBO(60, 60, 180, 1),
    secondary: Color.fromRGBO(80, 100, 200, 1),
  ),
  smallBorder: [
    BeamBlob(
      color: Color.fromRGBO(60, 140, 200, 1),
      position: Offset(0.02, 0.68),
      size: Size(9, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(50, 120, 180, 1),
      position: Offset(0.02, 0.68),
      size: Size(4, 8),
    ),
    BeamBlob(
      color: Color.fromRGBO(100, 80, 220, 1),
      position: Offset(0.72, -0.03),
      size: Size(59, 9),
    ),
    BeamBlob(
      color: Color.fromRGBO(80, 100, 255, 1),
      position: Offset(0.74, 1),
      size: Size(42, 7),
    ),
    BeamBlob(
      color: Color.fromRGBO(120, 70, 240, 1),
      position: Offset(1, 0.27),
      size: Size(10, 17),
    ),
    BeamBlob(
      color: Color.fromRGBO(90, 80, 220, 1),
      position: Offset(1, 0.27),
      size: Size(10, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(70, 110, 255, 1),
      position: Offset(1, 0.27),
      size: Size(5, 10),
    ),
    BeamBlob(
      color: Color.fromRGBO(110, 90, 230, 1),
      position: Offset(1, 0.27),
      size: Size(11, 12),
    ),
  ],
  smallInner: [
    BeamBlob(
      color: Color.fromRGBO(60, 140, 200, 0.5),
      position: Offset(0.02, 0.68),
      size: Size(9, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(50, 120, 180, 0.45),
      position: Offset(0.02, 0.68),
      size: Size(4, 8),
    ),
    BeamBlob(
      color: Color.fromRGBO(100, 80, 220, 0.35),
      position: Offset(0.72, -0.03),
      size: Size(59, 9),
    ),
    BeamBlob(
      color: Color.fromRGBO(80, 100, 255, 0.35),
      position: Offset(0.74, 1),
      size: Size(42, 7),
    ),
    BeamBlob(
      color: Color.fromRGBO(120, 70, 240, 0.3),
      position: Offset(1, 0.27),
      size: Size(10, 17),
    ),
    BeamBlob(
      color: Color.fromRGBO(90, 80, 220, 0.4),
      position: Offset(1, 0.27),
      size: Size(10, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(70, 110, 255, 0.3),
      position: Offset(1, 0.27),
      size: Size(5, 10),
    ),
    BeamBlob(
      color: Color.fromRGBO(110, 90, 230, 0.3),
      position: Offset(1, 0.27),
      size: Size(11, 12),
    ),
  ],
  lineDark: [
    LineBlob(
      color: Color.fromRGBO(100, 80, 220, 1),
      sizeW: 36,
      sizeH: 36,
      offsetX: 0,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(60, 120, 255, 1),
      sizeW: 30,
      sizeH: 32,
      offsetX: 39,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(80, 100, 200, 1),
      sizeW: 33,
      sizeH: 28,
      offsetX: -36,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(130, 70, 255, 1),
      sizeW: 29,
      sizeH: 34,
      offsetX: -54,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(70, 130, 255, 1),
      sizeW: 27,
      sizeH: 30,
      offsetX: 51,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(120, 80, 255, 1),
      sizeW: 36,
      sizeH: 24,
      offsetX: 21,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(90, 110, 230, 1),
      sizeW: 30,
      sizeH: 22,
      offsetX: -21,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(110, 90, 240, 1),
      sizeW: 25,
      sizeH: 28,
      offsetX: 66,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(140, 100, 255, 1),
      sizeW: 23,
      sizeH: 30,
      offsetX: -66,
      offsetY: -1,
    ),
  ],
  lineLight: [
    LineBlob(
      color: Color.fromRGBO(80, 60, 200, 1),
      sizeW: 45,
      sizeH: 36,
      offsetX: 0,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(50, 100, 220, 1),
      sizeW: 35,
      sizeH: 32,
      offsetX: 65,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(70, 90, 190, 1),
      sizeW: 40,
      sizeH: 28,
      offsetX: -60,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(110, 60, 220, 1),
      sizeW: 35,
      sizeH: 34,
      offsetX: -90,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(60, 110, 230, 1),
      sizeW: 38,
      sizeH: 30,
      offsetX: 85,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(100, 70, 240, 1),
      sizeW: 50,
      sizeH: 24,
      offsetX: 35,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(80, 100, 210, 1),
      sizeW: 40,
      sizeH: 22,
      offsetX: -35,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(90, 80, 225, 1),
      sizeW: 35,
      sizeH: 28,
      offsetX: 110,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(120, 90, 245, 1),
      sizeW: 30,
      sizeH: 30,
      offsetX: -110,
      offsetY: -1,
    ),
  ],
  lineInner: [
    LineBlob(
      color: Color.fromRGBO(100, 80, 220, 0.48),
      sizeW: 33,
      sizeH: 30,
      offsetX: 0,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(60, 120, 255, 0.42),
      sizeW: 24,
      sizeH: 26,
      offsetX: 39,
      offsetY: -3,
    ),
    LineBlob(
      color: Color.fromRGBO(80, 100, 200, 0.48),
      sizeW: 27,
      sizeH: 24,
      offsetX: -36,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(130, 70, 255, 0.42),
      sizeW: 23,
      sizeH: 28,
      offsetX: -54,
      offsetY: -2,
    ),
    LineBlob(
      color: Color.fromRGBO(70, 130, 255, 0.50),
      sizeW: 24,
      sizeH: 24,
      offsetX: 51,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(120, 80, 255, 0.45),
      sizeW: 30,
      sizeH: 20,
      offsetX: 21,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(90, 110, 230, 0.40),
      sizeW: 25,
      sizeH: 18,
      offsetX: -21,
      offsetY: -2,
    ),
    LineBlob(
      color: Color.fromRGBO(110, 90, 240, 0.45),
      sizeW: 21,
      sizeH: 24,
      offsetX: 66,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(140, 100, 255, 0.52),
      sizeW: 18,
      sizeH: 26,
      offsetX: -66,
      offsetY: -1,
    ),
  ],
  lineBloomDark: [
    SpikePair(Color.fromRGBO(100, 80, 255, 1), Color.fromRGBO(100, 80, 255, 1)),
    SpikePair(
      Color.fromRGBO(80, 130, 220, 0.59),
      Color.fromRGBO(80, 130, 220, 0.29),
    ),
    SpikePair(Color.fromRGBO(60, 100, 255, 1), Color.fromRGBO(60, 100, 255, 1)),
    SpikePair(
      Color.fromRGBO(90, 120, 200, 0.91),
      Color.fromRGBO(90, 120, 200, 0.45),
    ),
    SpikePair(Color.fromRGBO(120, 90, 255, 1), Color.fromRGBO(120, 90, 255, 1)),
  ],
  lineBloomLight: [
    SpikePair(Color.fromRGBO(50, 40, 180, 1), Color.fromRGBO(50, 40, 180, 0.8)),
    SpikePair(
      Color.fromRGBO(40, 80, 200, 0.7),
      Color.fromRGBO(40, 80, 200, 0.46),
    ),
    SpikePair(
      Color.fromRGBO(30, 50, 190, 1),
      Color.fromRGBO(30, 50, 190, 0.82),
    ),
    SpikePair(Color.fromRGBO(60, 90, 180, 1), Color.fromRGBO(60, 90, 180, 0.7)),
    SpikePair(
      Color.fromRGBO(70, 60, 200, 1),
      Color.fromRGBO(70, 60, 200, 0.78),
    ),
  ],
);

// ── sunset ──────────────────────────────────────────────────────────────────

/// Warm orange/red preset (React `sunset`).
const BeamPresetData sunsetPreset = BeamPresetData(
  border: [
    BeamBlob(
      color: Color.fromRGBO(255, 80, 50, 1),
      position: Offset(0.33, -0.074),
      size: Size(70, 40),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 160, 40, 1),
      position: Offset(0.12, -0.05),
      size: Size(60, 35),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 120, 60, 1),
      position: Offset(0.021, 0.683),
      size: Size(40, 70),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 200, 50, 1),
      position: Offset(0.021, 0.683),
      size: Size(20, 35),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 100, 80, 1),
      position: Offset(0.744, 1),
      size: Size(180, 32),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 180, 60, 1),
      position: Offset(0.55, 1),
      size: Size(85, 26),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 60, 60, 1),
      position: Offset(0.939, 0),
      size: Size(74, 32),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 140, 50, 1),
      position: Offset(1, 0.271),
      size: Size(26, 42),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 90, 70, 1),
      position: Offset(1, 0.271),
      size: Size(52, 48),
    ),
  ],
  spike: SpikeColors(
    primary: Color.fromRGBO(255, 140, 80, 1),
    secondary: Color.fromRGBO(255, 100, 60, 0.98),
  ),
  spikeLt: SpikeColors(
    primary: Color.fromRGBO(200, 80, 40, 1),
    secondary: Color.fromRGBO(220, 120, 30, 1),
  ),
  smallBorder: [
    BeamBlob(
      color: Color.fromRGBO(255, 180, 50, 1),
      position: Offset(0.02, 0.68),
      size: Size(9, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 150, 40, 1),
      position: Offset(0.02, 0.68),
      size: Size(4, 8),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 80, 60, 1),
      position: Offset(0.72, -0.03),
      size: Size(59, 9),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 100, 80, 1),
      position: Offset(0.74, 1),
      size: Size(42, 7),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 60, 80, 1),
      position: Offset(1, 0.27),
      size: Size(10, 17),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 120, 60, 1),
      position: Offset(1, 0.27),
      size: Size(10, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 200, 50, 1),
      position: Offset(1, 0.27),
      size: Size(5, 10),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 90, 70, 1),
      position: Offset(1, 0.27),
      size: Size(11, 12),
    ),
  ],
  smallInner: [
    BeamBlob(
      color: Color.fromRGBO(255, 180, 50, 0.5),
      position: Offset(0.02, 0.68),
      size: Size(9, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 150, 40, 0.45),
      position: Offset(0.02, 0.68),
      size: Size(4, 8),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 80, 60, 0.35),
      position: Offset(0.72, -0.03),
      size: Size(59, 9),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 100, 80, 0.35),
      position: Offset(0.74, 1),
      size: Size(42, 7),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 60, 80, 0.3),
      position: Offset(1, 0.27),
      size: Size(10, 17),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 120, 60, 0.4),
      position: Offset(1, 0.27),
      size: Size(10, 18),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 200, 50, 0.3),
      position: Offset(1, 0.27),
      size: Size(5, 10),
    ),
    BeamBlob(
      color: Color.fromRGBO(255, 90, 70, 0.3),
      position: Offset(1, 0.27),
      size: Size(11, 12),
    ),
  ],
  lineDark: [
    LineBlob(
      color: Color.fromRGBO(255, 100, 60, 1),
      sizeW: 36,
      sizeH: 36,
      offsetX: 0,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 180, 50, 1),
      sizeW: 30,
      sizeH: 32,
      offsetX: 39,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 140, 70, 1),
      sizeW: 33,
      sizeH: 28,
      offsetX: -36,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 80, 80, 1),
      sizeW: 29,
      sizeH: 34,
      offsetX: -54,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 200, 60, 1),
      sizeW: 27,
      sizeH: 30,
      offsetX: 51,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 120, 50, 1),
      sizeW: 36,
      sizeH: 24,
      offsetX: 21,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 160, 80, 1),
      sizeW: 30,
      sizeH: 22,
      offsetX: -21,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 90, 60, 1),
      sizeW: 25,
      sizeH: 28,
      offsetX: 66,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 70, 70, 1),
      sizeW: 23,
      sizeH: 30,
      offsetX: -66,
      offsetY: -1,
    ),
  ],
  lineLight: [
    LineBlob(
      color: Color.fromRGBO(220, 80, 40, 1),
      sizeW: 45,
      sizeH: 36,
      offsetX: 0,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(230, 150, 30, 1),
      sizeW: 35,
      sizeH: 32,
      offsetX: 65,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(210, 110, 50, 1),
      sizeW: 40,
      sizeH: 28,
      offsetX: -60,
      offsetY: 2,
    ),
    LineBlob(
      color: Color.fromRGBO(200, 60, 60, 1),
      sizeW: 35,
      sizeH: 34,
      offsetX: -90,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(220, 170, 40, 1),
      sizeW: 38,
      sizeH: 30,
      offsetX: 85,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(210, 100, 30, 1),
      sizeW: 50,
      sizeH: 24,
      offsetX: 35,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(230, 130, 60, 1),
      sizeW: 40,
      sizeH: 22,
      offsetX: -35,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(190, 70, 50, 1),
      sizeW: 35,
      sizeH: 28,
      offsetX: 110,
      offsetY: 1,
    ),
    LineBlob(
      color: Color.fromRGBO(180, 50, 50, 1),
      sizeW: 30,
      sizeH: 30,
      offsetX: -110,
      offsetY: -1,
    ),
  ],
  lineInner: [
    LineBlob(
      color: Color.fromRGBO(255, 100, 60, 0.48),
      sizeW: 33,
      sizeH: 30,
      offsetX: 0,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 180, 50, 0.42),
      sizeW: 24,
      sizeH: 26,
      offsetX: 39,
      offsetY: -3,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 140, 70, 0.48),
      sizeW: 27,
      sizeH: 24,
      offsetX: -36,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 80, 80, 0.42),
      sizeW: 23,
      sizeH: 28,
      offsetX: -54,
      offsetY: -2,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 200, 60, 0.50),
      sizeW: 24,
      sizeH: 24,
      offsetX: 51,
      offsetY: -1,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 120, 50, 0.45),
      sizeW: 30,
      sizeH: 20,
      offsetX: 21,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 160, 80, 0.40),
      sizeW: 25,
      sizeH: 18,
      offsetX: -21,
      offsetY: -2,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 90, 60, 0.45),
      sizeW: 21,
      sizeH: 24,
      offsetX: 66,
      offsetY: 0,
    ),
    LineBlob(
      color: Color.fromRGBO(255, 70, 70, 0.52),
      sizeW: 18,
      sizeH: 26,
      offsetX: -66,
      offsetY: -1,
    ),
  ],
  lineBloomDark: [
    SpikePair(Color.fromRGBO(255, 100, 80, 1), Color.fromRGBO(255, 100, 80, 1)),
    SpikePair(
      Color.fromRGBO(255, 150, 80, 0.59),
      Color.fromRGBO(255, 150, 80, 0.29),
    ),
    SpikePair(Color.fromRGBO(255, 80, 60, 1), Color.fromRGBO(255, 80, 60, 1)),
    SpikePair(
      Color.fromRGBO(255, 120, 50, 0.91),
      Color.fromRGBO(255, 120, 50, 0.45),
    ),
    SpikePair(Color.fromRGBO(255, 140, 70, 1), Color.fromRGBO(255, 140, 70, 1)),
  ],
  lineBloomLight: [
    SpikePair(Color.fromRGBO(200, 60, 30, 1), Color.fromRGBO(200, 60, 30, 0.8)),
    SpikePair(
      Color.fromRGBO(220, 100, 20, 0.7),
      Color.fromRGBO(220, 100, 20, 0.46),
    ),
    SpikePair(
      Color.fromRGBO(180, 40, 20, 1),
      Color.fromRGBO(180, 40, 20, 0.82),
    ),
    SpikePair(Color.fromRGBO(210, 80, 10, 1), Color.fromRGBO(210, 80, 10, 0.7)),
    SpikePair(
      Color.fromRGBO(190, 70, 30, 1),
      Color.fromRGBO(190, 70, 30, 0.78),
    ),
  ],
);
