import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show BorderRadius;

import '../models/beam_palette.dart';
import '../render/beam_outline.dart';
import 'look_blobs.dart';
import 'palette_tables.dart';

/// Resolves a palette to the blob tables every effect draws with.
///
/// The original palettes carry their own tables. The extras cycle a short
/// colour list over `colorful`'s tables. Every other palette — custom stops,
/// solid, seeded, scheme, blended, scaled — keeps `colorful`'s geometry and
/// takes each blob's colour from the palette at the point of the border the
/// blob sits on. Resolved once per palette and remembered.
abstract final class BeamLook {
  static final Expando<BeamLookTables> _memo = Expando<BeamLookTables>(
    'BeamLook',
  );

  /// The tables [palette] is drawn with.
  static BeamLookTables tablesFor(BeamPalette palette) {
    final own = palette.tables;
    if (own != null) return own;
    return _memo[palette] ??= _derive(palette);
  }

  static BeamLookTables _derive(BeamPalette palette) {
    final cycle = palette.tableColors;
    if (cycle != null && cycle.isNotEmpty) {
      return cycleColors(cycle, colorfulTables);
    }
    return sampleTables(palette);
  }
}

/// Distributes [colors] over [base]'s tables by index, cycling, and keeps
/// each entry's alpha so the layered depth of the look survives.
BeamLookTables cycleColors(List<Color> colors, BeamLookTables base) {
  Color pick(int i, Color original) =>
      colors[i % colors.length].withValues(alpha: original.a);
  return BeamLookTables(
    border: [
      for (final (i, b) in base.border.indexed) b.withColor(pick(i, b.color)),
    ],
    spike: SpikeColors(
      primary: pick(0, base.spike.primary),
      secondary: pick(1, base.spike.secondary),
    ),
    spikeLt: SpikeColors(
      primary: pick(0, base.spikeLt.primary),
      secondary: pick(1, base.spikeLt.secondary),
    ),
    smallBorder: [
      for (final (i, b) in base.smallBorder.indexed)
        b.withColor(pick(i, b.color)),
    ],
    smallInner: [
      for (final (i, b) in base.smallInner.indexed)
        b.withColor(pick(i, b.color)),
    ],
    lineDark: [
      for (final (i, b) in base.lineDark.indexed) b.withColor(pick(i, b.color)),
    ],
    lineLight: [
      for (final (i, b) in base.lineLight.indexed)
        b.withColor(pick(i, b.color)),
    ],
    lineInner: [
      for (final (i, b) in base.lineInner.indexed)
        b.withColor(pick(i, b.color)),
    ],
    lineBloomDark: [
      for (final (i, s) in base.lineBloomDark.indexed)
        SpikePair(pick(i, s.color1), pick(i, s.color2)),
    ],
    lineBloomLight: [
      for (final (i, s) in base.lineBloomLight.indexed)
        SpikePair(pick(i, s.color1), pick(i, s.color2)),
    ],
  );
}

/// Every table colour passed through [f], keeping all geometry.
BeamLookTables mapTableColors(BeamLookTables t, Color Function(Color) f) =>
    BeamLookTables(
      border: [for (final b in t.border) b.withColor(f(b.color))],
      spike: SpikeColors(
        primary: f(t.spike.primary),
        secondary: f(t.spike.secondary),
      ),
      spikeLt: SpikeColors(
        primary: f(t.spikeLt.primary),
        secondary: f(t.spikeLt.secondary),
      ),
      smallBorder: [for (final b in t.smallBorder) b.withColor(f(b.color))],
      smallInner: [for (final b in t.smallInner) b.withColor(f(b.color))],
      lineDark: [for (final b in t.lineDark) b.withColor(f(b.color))],
      lineLight: [for (final b in t.lineLight) b.withColor(f(b.color))],
      lineInner: [for (final b in t.lineInner) b.withColor(f(b.color))],
      lineBloomDark: [
        for (final s in t.lineBloomDark) SpikePair(f(s.color1), f(s.color2)),
      ],
      lineBloomLight: [
        for (final s in t.lineBloomLight) SpikePair(f(s.color1), f(s.color2)),
      ],
    );

/// [t] with every alpha multiplied by [factor] (clamped to 0–1).
BeamLookTables scaleTableAlpha(BeamLookTables t, double factor) =>
    mapTableColors(
      t,
      (c) => c.withValues(alpha: (c.a * factor).clamp(0.0, 1.0)),
    );

// The boxes `colorful`'s tables are laid out on: a card and a chip.
final BeamOutline _card = BeamOutline(
  const Rect.fromLTWH(0, 0, 350, 140),
  const BorderRadius.all(Radius.circular(16)),
);
final BeamOutline _chip = BeamOutline(
  const Rect.fromLTWH(0, 0, 70, 36),
  const BorderRadius.all(Radius.circular(18)),
);

// The spike positions along the edge, as fractions of its length.
const List<double> _spikeAt = [0.36, 0.50, 0.64, 0.78, 0.92];

/// `colorful`'s tables recoloured from [palette]: each blob takes the
/// palette's colour at the point of the border it sits on (line blobs, which
/// travel with the streak, take it across the streak), keeping `colorful`'s
/// alpha.
BeamLookTables sampleTables(BeamPalette palette) {
  const base = colorfulTables;
  Color tint(Color c, double u) {
    final s = palette.sample(u);
    return s.withValues(alpha: (c.a * s.a).clamp(0.0, 1.0));
  }

  Color onCard(BeamBlob b) => tint(
    b.color,
    _card.nearestFraction(Offset(b.position.dx * 350, b.position.dy * 140)),
  );
  Color onChip(BeamBlob b) => tint(
    b.color,
    _chip.nearestFraction(Offset(b.position.dx * 70, b.position.dy * 36)),
  );
  // Across the streak, end to end: each table over its own width, since the
  // light-surface streak is wider than the dark one and the inner glow.
  List<LineBlob> across(List<LineBlob> blobs) {
    final half = blobs.fold(0.0, (m, b) => math.max(m, b.offsetX.abs()));
    return [
      for (final b in blobs)
        b.withColor(
          tint(
            b.color,
            half > 0 ? ((b.offsetX + half) / (2 * half)).clamp(0.0, 0.999) : 0,
          ),
        ),
    ];
  }

  SpikePair spike(SpikePair s, double at) =>
      SpikePair(tint(s.color1, at), tint(s.color2, at));

  return BeamLookTables(
    border: [for (final b in base.border) b.withColor(onCard(b))],
    spike: SpikeColors(
      primary: tint(base.spike.primary, 0.08),
      secondary: tint(base.spike.secondary, 0.22),
    ),
    spikeLt: SpikeColors(
      primary: tint(base.spikeLt.primary, 0.08),
      secondary: tint(base.spikeLt.secondary, 0.22),
    ),
    smallBorder: [for (final b in base.smallBorder) b.withColor(onChip(b))],
    smallInner: [for (final b in base.smallInner) b.withColor(onChip(b))],
    lineDark: across(base.lineDark),
    lineLight: across(base.lineLight),
    lineInner: across(base.lineInner),
    lineBloomDark: [
      for (final (i, s) in base.lineBloomDark.indexed) spike(s, _spikeAt[i]),
    ],
    lineBloomLight: [
      for (final (i, s) in base.lineBloomLight.indexed) spike(s, _spikeAt[i]),
    ],
  );
}
