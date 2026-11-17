import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../look/palette_tables.dart';
import '../render/color_math.dart';

/// The most colour stops a palette may carry.
///
/// A design limit, checked when a palette resolves. Palette stops never
/// reach the shader: the effects draw a palette through blob tables sampled
/// from it (`BeamLook.tablesFor`).
const int maxPaletteStops = 8;

/// A resolved palette: a ring of colour stops around the border.
///
/// Produced by `BeamColors.resolve`. Each stop sits at a perimeter coordinate
/// `u` in `[0, 1)` — 0 at top-centre, increasing clockwise by arc length.
/// Between stops the colour blends gamma-aware, and past the last stop it
/// blends back into the first across top-centre, so the ring is seamless.
@immutable
class BeamPalette {
  /// Creates a palette from [colors] at [stops].
  ///
  /// Both lists must have the same length (1–[maxPaletteStops]), and [stops]
  /// must ascend within `[0, 1)`. The lists are stored as given — pass
  /// unmodifiable ones.
  const BeamPalette({
    required this.colors,
    required this.stops,
    this.fixedHue = false,
    this.tables,
    this.tableColors,
    this.mono = false,
  });

  /// The stop colours, in stop order. Alpha is the stop's strength.
  final List<Color> colors;

  /// The perimeter coordinate of each colour, ascending, each in `[0, 1)`.
  final List<double> stops;

  /// Whether the hue must never drift (the mono and gold presets): a hue
  /// sweep over a grey or a single-hue metal reads as the material changing.
  final bool fixedHue;

  /// The blob tables this palette is drawn with, or null to derive them
  /// (see `BeamLook.tablesFor`).
  final BeamLookTables? tables;

  /// Colours to cycle over `colorful`'s blob tables instead of sampling
  /// [colors] into them, or null.
  final List<Color>? tableColors;

  /// Whether this is the greyscale palette: its layers paint at half
  /// opacity (the line effect softens its spikes instead), since white light
  /// reads far brighter than coloured light at the same alpha.
  final bool mono;

  /// The number of stops.
  int get length => colors.length;

  /// The colour at perimeter coordinate [u] (wrapped into `[0, 1)`), blended
  /// gamma-aware between the stops either side of it — how a palette without
  /// tables of its own is sampled into `colorful`'s blob geometry.
  Color sample(double u) =>
      samplePalette(colors, stops, u - u.floorToDouble(), wrap: true);

  /// [count] stop positions evenly spaced around the ring, starting at 0.
  static List<double> evenStops(int count) =>
      List<double>.unmodifiable([for (var i = 0; i < count; i++) i / count]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamPalette &&
          other.fixedHue == fixedHue &&
          other.mono == mono &&
          other.tables == tables &&
          listEquals(other.tableColors, tableColors) &&
          listEquals(other.colors, colors) &&
          listEquals(other.stops, stops);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(colors),
    Object.hashAll(stops),
    fixedHue,
    mono,
    tables,
    tableColors == null ? null : Object.hashAll(tableColors!),
  );

  // Tables are dozens of blobs, so they print as an identity: their hash is
  // structural, so equal tables print alike and different ones apart.
  @override
  String toString() {
    final fields = <String>[
      'colors: $colors',
      'stops: $stops',
      'fixedHue: $fixedHue',
      'mono: $mono',
      if (tables != null) 'tables: ${describeIdentity(tables)}',
      if (tableColors != null) 'tableColors: $tableColors',
    ];
    return 'BeamPalette(${fields.join(', ')})';
  }
}
