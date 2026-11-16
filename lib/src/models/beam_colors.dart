import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ColorScheme;
import 'package:flutter/painting.dart' show HSLColor;

import '../look/beam_look.dart';
import '../render/color_math.dart';
import 'beam_palette.dart';
import 'beam_presets.dart';
import 'model_validation.dart';

/// How [BeamColors.fromSeed] spreads one brand color into a multi-color
/// palette.
///
/// Every harmony works in HSL and keeps the derived colors inside the
/// lightness band a glow reads well in, so a very dark or very light seed
/// still produces a visible beam.
enum BeamSeedHarmony {
  /// Four neighbours of the seed hue (0°, +25°, −25°, +50°). The calmest
  /// option: the palette still reads as one color.
  analogous,

  /// Four colors split across the seed hue and its opposite (0°, +15°,
  /// +180°, +195°) — maximum contrast between the two halves of the border.
  complementary,

  /// Three colors evenly spaced around the wheel (0°, +120°, +240°).
  triadic,

  /// Four tints of the seed hue, stepping through the lightness band with
  /// falling saturation. Keeps a single-hue brand look.
  monochrome,
}

/// The colors of a beam: a ring of color stops around the border.
///
/// Stops sit at perimeter positions in `[0, 1)` — 0 at top-centre,
/// increasing clockwise — and blend into each other, the last back into the
/// first, so the ring is seamless. Effects that travel reveal the colors
/// where the beam passes; ambient effects breathe them in place.
///
/// Use one of the [presets]:
///
/// ```dart
/// BorderBeam(colors: BeamColors.ocean, child: card)
/// ```
///
/// or bring your own colors, evenly spaced or at chosen positions:
///
/// ```dart
/// BorderBeam(
///   colors: const BeamColors([Colors.pink, Colors.cyan, Colors.amber]),
///   child: card,
/// )
/// ```
///
/// [BeamColors.fromSeed] and [BeamColors.fromScheme] derive a palette from a
/// single brand color or a Material [ColorScheme]; [BeamColors.lerp] and
/// [scaleAlpha] transform an existing one.
///
/// Every variant is a value type: two instances built from equal inputs are
/// `==`, so rebuilding `BeamColors([...])` inline in a `build` method does not
/// force the beam to re-resolve its palette.
@immutable
sealed class BeamColors {
  const BeamColors._();

  // ─── Factories ────────────────────────────────────────────────────────────

  /// A ring of [colors] at [stops].
  ///
  /// Give 1–8 colors. [stops] places each one: the same length as [colors],
  /// ascending, each in `[0, 1)`. Omitted, the colors are spaced evenly from
  /// top-centre (0, 1/n, 2/n, …). Alpha is honoured: a translucent stop
  /// glows more faintly.
  ///
  /// The lists are checked when the palette is first resolved — in release
  /// builds too — and a bad one throws an [ArgumentError].
  const factory BeamColors(List<Color> colors, {List<double>? stops}) =
      _StopBeamColors;

  /// A single [color] all the way round.
  const factory BeamColors.solid(Color color) = _SolidBeamColors;

  /// Derives a palette from a single brand color.
  ///
  /// [harmony] picks how the seed hue is spread (see [BeamSeedHarmony]).
  /// The derived colors are lifted into a readable glow band — lightness
  /// 0.55–0.70, saturation at least 0.55 — so a black, white or gray seed
  /// still yields visible, distinguishable colors. They are spaced evenly
  /// around the border.
  ///
  /// ```dart
  /// BorderBeam(
  ///   colors: const BeamColors.fromSeed(Color(0xFF18A8F0)),
  ///   child: card,
  /// )
  /// ```
  const factory BeamColors.fromSeed(Color seed, {BeamSeedHarmony harmony}) =
      _SeedBeamColors;

  /// Builds a palette from a Material [ColorScheme]'s primary, secondary and
  /// tertiary roles, spaced evenly around the border.
  ///
  /// Roles that are near-duplicates of an earlier one are dropped, so a
  /// scheme whose secondary matches its primary yields a two-color palette
  /// rather than a doubled one.
  factory BeamColors.fromScheme(ColorScheme scheme) => _StopBeamColors(
    _dedupe([scheme.primary, scheme.secondary, scheme.tertiary]),
  );

  /// Blends two color choices.
  ///
  /// Both palettes are sampled at eight evenly spaced positions around the
  /// border and each pair is mixed gamma-aware at [t], which is clamped to
  /// 0–1. At exactly 0 or 1 the result is [a] or [b] unchanged. The hue is
  /// fixed when the nearer end's is.
  const factory BeamColors.lerp(BeamColors a, BeamColors b, double t) =
      _LerpBeamColors;

  // ─── Presets ──────────────────────────────────────────────────────────────

  /// Orange, magenta, violet, blue, green, and hot pink — the full spectrum.
  /// The default.
  static const BeamColors colorful = _PresetBeamColors(
    'colorful',
    colorfulPalette,
  );

  /// Whites and greys. The hue never drifts.
  static const BeamColors mono = _PresetBeamColors('mono', monoPalette);

  /// Blues and violets.
  static const BeamColors ocean = _PresetBeamColors('ocean', oceanPalette);

  /// Reds, oranges, and amber.
  static const BeamColors sunset = _PresetBeamColors('sunset', sunsetPalette);

  /// Northern lights: teal, violet, and green.
  static const BeamColors aurora = _PresetBeamColors('aurora', auroraPalette);

  /// Fully saturated magenta, lime, and cyan — the loudest preset.
  static const BeamColors neon = _PresetBeamColors('neon', neonPalette);

  /// Pastel pink, lavender, and peach.
  static const BeamColors candy = _PresetBeamColors('candy', candyPalette);

  /// Deep red, orange, and gold — the hot end of a fire.
  static const BeamColors ember = _PresetBeamColors('ember', emberPalette);

  /// Pale blue, white, and cyan.
  static const BeamColors ice = _PresetBeamColors('ice', icePalette);

  /// Warm monochrome: amber, gold, and bronze.
  ///
  /// Like [mono] it pins the hue — a hue sweep over a single-hue metal reads
  /// as the metal changing material.
  static const BeamColors gold = _PresetBeamColors('gold', goldPalette);

  /// Desaturated pastels built for a hue sweep.
  ///
  /// The colors are deliberately low-contrast; the iridescence comes from
  /// pairing them with a fast continuous hue drift:
  ///
  /// ```dart
  /// BorderBeam(
  ///   colors: BeamColors.holographic,
  ///   style: const BeamStyle(hueMode: BeamHueMode.continuous),
  ///   timing: const BeamTiming(huePeriod: Duration(seconds: 3)),
  ///   child: card,
  /// )
  /// ```
  static const BeamColors holographic = _PresetBeamColors(
    'holographic',
    holographicPalette,
  );

  /// Teal, aqua, and mint — shallow tropical water.
  static const BeamColors lagoon = _PresetBeamColors('lagoon', lagoonPalette);

  /// Indigo, violet, and rose — the sky after sundown.
  static const BeamColors dusk = _PresetBeamColors('dusk', duskPalette);

  /// Emerald, lime, and teal.
  static const BeamColors forest = _PresetBeamColors('forest', forestPalette);

  /// Pink, coral, and mauve.
  static const BeamColors rose = _PresetBeamColors('rose', rosePalette);

  /// Deep violet, electric blue, and magenta.
  static const BeamColors cosmic = _PresetBeamColors('cosmic', cosmicPalette);

  /// Lime, yellow, and tangerine.
  static const BeamColors citrus = _PresetBeamColors('citrus', citrusPalette);

  /// Cerulean, periwinkle, and a white-blue.
  static const BeamColors sky = _PresetBeamColors('sky', skyPalette);

  /// Lilac, lavender, and a soft pink.
  static const BeamColors lavender = _PresetBeamColors(
    'lavender',
    lavenderPalette,
  );

  /// Every preset by name, in gallery order: the four originals, then the
  /// rest.
  static const Map<String, BeamColors> presets = {
    'colorful': colorful,
    'mono': mono,
    'ocean': ocean,
    'sunset': sunset,
    'aurora': aurora,
    'neon': neon,
    'candy': candy,
    'ember': ember,
    'ice': ice,
    'gold': gold,
    'holographic': holographic,
    'lagoon': lagoon,
    'dusk': dusk,
    'forest': forest,
    'rose': rose,
    'cosmic': cosmic,
    'citrus': citrus,
    'sky': sky,
    'lavender': lavender,
  };

  // ─── Transforms ───────────────────────────────────────────────────────────

  /// Multiplies every stop's alpha by [factor], clamping the result to 0–1.
  ///
  /// This dims the palette itself rather than the beam's overall strength,
  /// so stops that were already fainter stay relatively fainter. [factor]
  /// must not be negative.
  BeamColors scaleAlpha(double factor) => _ScaledBeamColors(this, factor);

  // ─── Resolution ───────────────────────────────────────────────────────────

  /// Immutable value used by the resolved-palette LRU.
  Object get _cacheKey;

  /// Resolves this color choice to concrete stops.
  ///
  /// The result is memoized by *value*: two separately constructed but equal
  /// instances return the identical [BeamPalette], which is what lets a
  /// beam compare palettes cheaply. The memo is a bounded LRU, so a
  /// long-lived app cycling through many palettes cannot grow it without
  /// limit; an evicted palette is simply rebuilt, and compares equal to the
  /// one it replaces.
  BeamPalette resolve() => _resolveCached(this);

  /// Builds the palette. Called at most once per distinct value while that
  /// value stays in the memo.
  BeamPalette _buildPalette();
}

// ─── Palette memo ───────────────────────────────────────────────────────────

/// How many distinct color choices keep a resolved palette. Comfortably
/// above the handful a screen uses at once, small enough that the retained
/// stops stay negligible.
const int _paletteCacheCapacity = 32;

// Insertion-ordered, so the first key is the least recently used: a hit
// re-inserts its key at the end, and an overflowing insert drops the front.
final LinkedHashMap<Object, BeamPalette> _paletteCache =
    LinkedHashMap<Object, BeamPalette>();

BeamPalette _resolveCached(BeamColors colors) {
  // User-provided colors may come from growable lists. Never put the public
  // value object itself in a hash map: mutating one of those source lists
  // would change its hash while it was resident and make the entry
  // unreachable. Each implementation supplies an immutable snapshot of the
  // inputs that affect resolution instead.
  final key = colors._cacheKey;
  final hit = _paletteCache.remove(key);
  if (hit != null) {
    _paletteCache[key] = hit;
    return hit;
  }
  final built = colors._buildPalette();
  _paletteCache[key] = built;
  if (_paletteCache.length > _paletteCacheCapacity) {
    _paletteCache.remove(_paletteCache.keys.first);
  }
  return built;
}

/// A hash-stable snapshot of a list used by a palette cache key.
class _ListKey<T> {
  _ListKey(Iterable<T> values) : values = List<T>.unmodifiable(values);

  final List<T> values;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ListKey<T> && listEquals(values, other.values);

  @override
  int get hashCode => Object.hashAll(values);
}

/// A validated palette built from caller-owned lists, snapshotted so a later
/// mutation of those lists cannot change it.
BeamPalette _paletteOf(
  List<Color> colors,
  List<double>? stops,
  String name, {
  bool fixedHue = false,
}) {
  final resolvedStops = stops ?? BeamPalette.evenStops(colors.length);
  validatePalette(colors, resolvedStops, name);
  return BeamPalette(
    colors: List<Color>.unmodifiable(colors),
    stops: List<double>.unmodifiable(resolvedStops),
    fixedHue: fixedHue,
  );
}

/// RGB distance below which two scheme roles count as the same color.
const double _dedupeThreshold = 0.06;

/// Drops colors within [_dedupeThreshold] of one already kept, comparing
/// straight-line distance in unpremultiplied RGB.
List<Color> _dedupe(List<Color> colors) {
  final kept = <Color>[];
  for (final c in colors) {
    final duplicate = kept.any((k) {
      final dr = k.r - c.r;
      final dg = k.g - c.g;
      final db = k.b - c.b;
      return dr * dr + dg * dg + db * db < _dedupeThreshold * _dedupeThreshold;
    });
    if (!duplicate) kept.add(c);
  }
  return kept;
}

// ─── Seed harmonies ─────────────────────────────────────────────────────────

/// Lowest lightness a derived seed color may take — below this a glow reads
/// as a smudge on a dark surface.
const double _seedMinLightness = 0.55;

/// Highest lightness a derived seed color may take — above this the glow
/// washes out against a light surface.
const double _seedMaxLightness = 0.70;

/// Saturation floor, so an achromatic seed still produces hue separation.
const double _seedMinSaturation = 0.55;

List<Color> _seedColors(Color seed, BeamSeedHarmony harmony) {
  final hsl = HSLColor.fromColor(seed);
  final hue = hsl.hue;
  final saturation = clampDouble(hsl.saturation, _seedMinSaturation, 1);
  final lightness = clampDouble(
    hsl.lightness,
    _seedMinLightness,
    _seedMaxLightness,
  );

  Color at(double hueDelta, [double lightnessDelta = 0]) => HSLColor.fromAHSL(
    1,
    ((hue + hueDelta) % 360 + 360) % 360,
    saturation,
    clampDouble(
      lightness + lightnessDelta,
      _seedMinLightness,
      _seedMaxLightness,
    ),
  ).toColor();

  return switch (harmony) {
    BeamSeedHarmony.analogous => [at(0), at(25, 0.05), at(-25, -0.05), at(50)],
    BeamSeedHarmony.complementary => [
      at(0),
      at(15, 0.05),
      at(180),
      at(195, -0.05),
    ],
    BeamSeedHarmony.triadic => [at(0), at(120), at(240)],
    BeamSeedHarmony.monochrome => [
      for (var i = 0; i < 4; i++)
        HSLColor.fromAHSL(
          1,
          hue,
          clampDouble(saturation * (1 - 0.1 * i), 0, 1),
          lerpDouble(_seedMinLightness, _seedMaxLightness, i / 3)!,
        ).toColor(),
    ],
  };
}

// ─── Implementations ────────────────────────────────────────────────────────

class _PresetBeamColors extends BeamColors {
  const _PresetBeamColors(this.name, this.palette) : super._();

  final String name;
  final BeamPalette palette;

  @override
  Object get _cacheKey => (#preset, name);

  // A preset's palette is a canonical const: no memo needed.
  @override
  BeamPalette resolve() => palette;

  @override
  BeamPalette _buildPalette() => palette;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PresetBeamColors &&
          other.name == name &&
          identical(other.palette, palette);

  @override
  int get hashCode => Object.hash(_PresetBeamColors, name);

  @override
  String toString() => 'BeamColors.$name';
}

class _StopBeamColors extends BeamColors {
  const _StopBeamColors(this.colors, {this.stops}) : super._();

  final List<Color> colors;
  final List<double>? stops;

  @override
  Object get _cacheKey =>
      (#stops, _ListKey(colors), stops == null ? null : _ListKey(stops!));

  @override
  BeamPalette _buildPalette() => _paletteOf(colors, stops, 'BeamColors');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StopBeamColors &&
          listEquals(other.colors, colors) &&
          listEquals(other.stops, stops);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(colors),
    stops == null ? null : Object.hashAll(stops!),
  );

  @override
  String toString() => stops == null
      ? 'BeamColors($colors)'
      : 'BeamColors($colors, stops: $stops)';
}

class _SolidBeamColors extends BeamColors {
  const _SolidBeamColors(this.color) : super._();

  final Color color;

  @override
  Object get _cacheKey => (#solid, color);

  @override
  BeamPalette _buildPalette() =>
      BeamPalette(colors: List<Color>.unmodifiable([color]), stops: const [0]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SolidBeamColors && other.color == color;

  @override
  int get hashCode => Object.hash(_SolidBeamColors, color);

  @override
  String toString() => 'BeamColors.solid($color)';
}

class _SeedBeamColors extends BeamColors {
  const _SeedBeamColors(this.seed, {this.harmony = BeamSeedHarmony.analogous})
    : super._();

  final Color seed;
  final BeamSeedHarmony harmony;

  @override
  Object get _cacheKey => (#seed, seed, harmony);

  @override
  BeamPalette _buildPalette() =>
      _paletteOf(_seedColors(seed, harmony), null, 'BeamColors.fromSeed');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SeedBeamColors &&
          other.seed == seed &&
          other.harmony == harmony;

  @override
  int get hashCode => Object.hash(seed, harmony);

  @override
  String toString() => 'BeamColors.fromSeed($seed, harmony: ${harmony.name})';
}

class _LerpBeamColors extends BeamColors {
  const _LerpBeamColors(this.a, this.b, this.t) : super._();

  final BeamColors a;
  final BeamColors b;
  final double t;

  /// How many positions both ends are sampled at.
  static const int _samples = maxPaletteStops;

  @override
  Object get _cacheKey => (#lerp, a._cacheKey, b._cacheKey, t);

  @override
  BeamPalette _buildPalette() {
    final pa = a.resolve();
    final pb = b.resolve();
    final f = t.isNaN ? 0.0 : clampDouble(t, 0, 1);
    if (f == 0) return pa;
    if (f == 1) return pb;
    final stops = BeamPalette.evenStops(_samples);
    return BeamPalette(
      colors: List<Color>.unmodifiable([
        for (final u in stops) mixColor(pa.sample(u), pb.sample(u), f),
      ]),
      stops: stops,
      fixedHue: (f < 0.5 ? pa : pb).fixedHue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LerpBeamColors && other.a == a && other.b == b && other.t == t;

  @override
  int get hashCode => Object.hash(a, b, t);

  @override
  String toString() => 'BeamColors.lerp($a, $b, $t)';
}

class _ScaledBeamColors extends BeamColors {
  const _ScaledBeamColors(this.source, this.factor) : super._();

  final BeamColors source;
  final double factor;

  @override
  Object get _cacheKey => (#scaled, source._cacheKey, factor);

  @override
  BeamPalette _buildPalette() {
    if (!(factor >= 0)) {
      throw ArgumentError.value(
        factor,
        'BeamColors.scaleAlpha factor',
        'must not be negative',
      );
    }
    final base = source.resolve();
    // A palette drawn with its own tables keeps them, scaled; the rest are
    // sampled from the scaled stops.
    final ownTables = base.tables != null || base.tableColors != null;
    return BeamPalette(
      colors: List<Color>.unmodifiable([
        for (final c in base.colors)
          c.withValues(alpha: clampDouble(c.a * factor, 0, 1)),
      ]),
      stops: base.stops,
      fixedHue: base.fixedHue,
      tables: ownTables
          ? scaleTableAlpha(BeamLook.tablesFor(base), factor)
          : null,
      mono: base.mono,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ScaledBeamColors &&
          other.source == source &&
          other.factor == factor;

  @override
  int get hashCode => Object.hash(source, factor);

  @override
  String toString() => '$source.scaleAlpha($factor)';
}
