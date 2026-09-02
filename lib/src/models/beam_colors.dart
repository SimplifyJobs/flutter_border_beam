import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ColorScheme;
import 'package:flutter/painting.dart' show HSLColor;

import '../constants/extra_palettes.dart';
import '../constants/palettes.dart';
import 'beam_blob.dart';
import 'beam_palette.dart';
import 'model_validation.dart';

/// How [BeamColors.fromSeed] spreads one brand color into a multi-color
/// palette.
///
/// Every harmony works in HSL and keeps the derived colors inside the
/// lightness band a glow reads well in, so a very dark or very light seed
/// still produces visible beams.
enum BeamSeedHarmony {
  /// Four neighbours of the seed hue (0°, +25°, −25°, +50°). The calmest
  /// option: the palette still reads as one color.
  analogous,

  /// Four colors split across the seed hue and its opposite (0°, +15°,
  /// +180°, +195°) — maximum contrast between the two halves of the beam.
  complementary,

  /// Three colors evenly spaced around the wheel (0°, +120°, +240°).
  triadic,

  /// Four tints of the seed hue, stepping through the lightness band with
  /// falling saturation. Keeps a single-hue brand look.
  monochrome,
}

/// The color scheme of a beam.
///
/// Use one of the presets:
///
/// ```dart
/// BorderBeam.rotate(colors: BeamColors.ocean, child: card)
/// ```
///
/// or bring your own colors — [BeamColors.custom] distributes them over a
/// preset's blob geometry so the effect keeps its organic look:
///
/// ```dart
/// BorderBeam.rotate(
///   colors: BeamColors.custom([Colors.pink, Colors.cyan, Colors.amber]),
///   child: card,
/// )
/// ```
///
/// [BeamColors.fromSeed] and [BeamColors.fromScheme] derive a palette from a
/// single brand color or a Material [ColorScheme]; [BeamColors.lerp] and
/// [scaleAlpha] transform an existing one. For pixel-level control,
/// [BeamColors.spec] accepts explicit blob tables.
///
/// Every variant is a value type: two instances built from equal inputs are
/// `==`, so rebuilding `BeamColors.custom([...])` inline in a `build` method
/// does not force the widget to re-resolve its gradient tables.
@immutable
sealed class BeamColors {
  const BeamColors._();

  /// Immutable value used by the resolved-palette LRU.
  Object get _cacheKey;

  /// Rainbow spectrum. The default.
  static const BeamColors colorful = _PresetBeamColors(colorfulPreset);

  /// Grayscale. Hue animation is disabled and layer opacity halved, matching
  /// the source library's mono treatment.
  static const BeamColors mono = _PresetBeamColors(monoPreset, isMono: true);

  /// Blue and purple tones.
  static const BeamColors ocean = _PresetBeamColors(oceanPreset);

  /// Warm orange, yellow, and red tones.
  static const BeamColors sunset = _PresetBeamColors(sunsetPreset);

  // ─── Flutter-only presets ─────────────────────────────────────────────────
  // Each distributes a short color list (`extra_palettes.dart`) over the
  // `colorful` blob geometry, exactly as `BeamColors.custom` does.

  /// Northern lights: teal, violet, green and glacier blue.
  static const BeamColors aurora = _CustomBeamColors(auroraColors);

  /// Fully saturated magenta, cyan and lime — the loudest preset.
  static const BeamColors neon = _CustomBeamColors(neonColors);

  /// Pastel pink, lavender and peach.
  static const BeamColors candy = _CustomBeamColors(candyColors);

  /// Deep red, orange and gold — the hot end of a fire.
  static const BeamColors ember = _CustomBeamColors(emberColors);

  /// Pale blue, white and cyan.
  static const BeamColors ice = _CustomBeamColors(iceColors);

  /// Warm monochrome: amber, gold and bronze.
  ///
  /// Like [mono] it pins the hue — a hue sweep over a single-hue metal reads
  /// as the metal changing material — so `gold` resolves with
  /// `forcesStaticColors: true`. Unlike [mono] it keeps full layer opacity:
  /// the ×0.5 multiplier exists to stop a *grayscale* beam blowing out, and
  /// halving a warm amber only makes it muddy.
  static const BeamColors gold = _CustomBeamColors(goldColors, staticHue: true);

  /// Desaturated pastels built for a hue sweep.
  ///
  /// The colors are deliberately low-contrast; the iridescence comes from
  /// pairing them with a fast continuous hue drift:
  ///
  /// ```dart
  /// BorderBeam.rotate(
  ///   colors: BeamColors.holographic,
  ///   style: const BeamStyle(hueMode: BeamHueMode.continuous),
  ///   timing: const BeamTiming(huePeriod: Duration(seconds: 3)),
  ///   child: card,
  /// )
  /// ```
  static const BeamColors holographic = _CustomBeamColors(holographicColors);

  // ─── Factories ────────────────────────────────────────────────────────────

  /// Distributes [colors] over [base]'s blob geometry (cycling when fewer
  /// colors than blob slots are given).
  ///
  /// The list must not be empty. Alpha channels of the base tables (inner
  /// glows, bloom spikes) are preserved and applied to your colors, so the
  /// layered depth of the effect is kept.
  ///
  /// [base] chooses which resolved tables supply that geometry and alpha
  /// structure — any [BeamColors] is accepted, including another custom
  /// palette. Only the tables are taken: a mono [base] does not make the
  /// result mono.
  const factory BeamColors.custom(List<Color> colors, {BeamColors base}) =
      _CustomBeamColors;

  /// Derives a multi-blob palette from a single brand color.
  ///
  /// [harmony] picks how the seed hue is spread (see [BeamSeedHarmony]).
  /// The derived colors are lifted into a readable glow band — lightness
  /// 0.55–0.70, saturation at least 0.55 — so a black, white or gray seed
  /// still yields visible, distinguishable blobs.
  ///
  /// The palette *geometry* always comes from the [colorful] preset; only
  /// the colors are derived.
  ///
  /// ```dart
  /// BorderBeam.rotate(
  ///   colors: const BeamColors.fromSeed(Color(0xFF18A8F0)),
  ///   child: card,
  /// )
  /// ```
  const factory BeamColors.fromSeed(Color seed, {BeamSeedHarmony harmony}) =
      _SeedBeamColors;

  /// Builds a palette from a Material [ColorScheme]'s primary, secondary and
  /// tertiary roles.
  ///
  /// Roles that are near-duplicates of an earlier one are dropped, so a
  /// scheme whose secondary matches its primary yields a two-color palette
  /// rather than a doubled one. Geometry comes from the [colorful] preset.
  factory BeamColors.fromScheme(ColorScheme scheme) => _CustomBeamColors(
    _dedupe([scheme.primary, scheme.secondary, scheme.tertiary]),
  );

  /// Blends two color choices.
  ///
  /// The result resolves to a palette whose every table entry is the
  /// [Color.lerp] of the corresponding entries of [a] and [b] at [t].
  /// Positions and sizes come from [a]; where [b]'s table is shorter its
  /// colors cycle. `forcesStaticColors` and the mono treatment come from
  /// whichever end is nearer, and the opacity multiplier is interpolated.
  ///
  /// [t] is not clamped — values outside 0–1 extrapolate, as with
  /// [Color.lerp].
  const factory BeamColors.lerp(BeamColors a, BeamColors b, double t) =
      _LerpBeamColors;

  /// Advanced: full per-blob control.
  ///
  /// [border] replaces the 9-blob border table (any length ≥ 1) used by the
  /// rotate stroke and as the pulse color source; each [BeamBlob.size] holds
  /// the ellipse *radii*, not its diameters. Tables not provided
  /// ([smallBorder], [lineBlobs]) are derived by cycling the border colors
  /// over the default geometry.
  const factory BeamColors.spec({
    required List<BeamBlob> border,
    List<BeamBlob>? smallBorder,
    List<LineBlob>? lineBlobs,
  }) = _SpecBeamColors;

  // ─── Transforms ───────────────────────────────────────────────────────────

  /// Multiplies every table entry's alpha by [factor], clamping the result
  /// to 0–1.
  ///
  /// This dims the palette itself rather than the layer opacity, so the
  /// relative depth of the inner/stroke/bloom tables is preserved. [factor]
  /// must not be negative.
  BeamColors scaleAlpha(double factor) => _ScaledBeamColors(this, factor);

  // ─── Resolution ───────────────────────────────────────────────────────────

  /// Resolves this color choice to concrete gradient tables.
  ///
  /// The result is memoized by *value*: two separately constructed but equal
  /// instances return the identical [BeamPalette], which is what lets a
  /// config compare palettes cheaply. The memo is a bounded LRU, so a
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
/// tables stay negligible.
const int _paletteCacheCapacity = 32;

// Insertion-ordered, so the first key is the least recently used: a hit
// re-inserts its key at the end, and an overflowing insert drops the front.
final LinkedHashMap<Object, BeamPalette> _paletteCache =
    LinkedHashMap<Object, BeamPalette>();

BeamPalette _resolveCached(BeamColors colors) {
  // User-provided tables may come from growable lists. Never put the public
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

// The presets bypass the LRU: they are canonicalized const instances, so an
// identity-keyed Expando memoizes them for the life of the isolate without
// hashing a color table or competing with user palettes for a cache slot.
final Expando<BeamPalette> _presetPaletteCache = Expando<BeamPalette>(
  'BeamColors.preset',
);

// ─── Table helpers ──────────────────────────────────────────────────────────

/// Distributes [colors] over [base]'s blob geometry, cycling when there are
/// fewer colors than blob slots and preserving each table entry's alpha so
/// the layered depth of the effect survives the substitution.
BeamPresetData _distribute(List<Color> colors, BeamPresetData base) {
  Color pick(int i, Color original) {
    final c = colors[i % colors.length];
    // Keep the preset's alpha so inner/bloom layering depth is preserved.
    return c.withValues(alpha: original.a);
  }

  return BeamPresetData(
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

/// Rebuilds [data] with every table color passed through [f], keeping all
/// geometry.
BeamPresetData _mapColors(BeamPresetData data, Color Function(Color) f) =>
    BeamPresetData(
      border: [for (final b in data.border) b.withColor(f(b.color))],
      spike: SpikeColors(
        primary: f(data.spike.primary),
        secondary: f(data.spike.secondary),
      ),
      spikeLt: SpikeColors(
        primary: f(data.spikeLt.primary),
        secondary: f(data.spikeLt.secondary),
      ),
      smallBorder: [for (final b in data.smallBorder) b.withColor(f(b.color))],
      smallInner: [for (final b in data.smallInner) b.withColor(f(b.color))],
      lineDark: [for (final b in data.lineDark) b.withColor(f(b.color))],
      lineLight: [for (final b in data.lineLight) b.withColor(f(b.color))],
      lineInner: [for (final b in data.lineInner) b.withColor(f(b.color))],
      lineBloomDark: [
        for (final s in data.lineBloomDark) SpikePair(f(s.color1), f(s.color2)),
      ],
      lineBloomLight: [
        for (final s in data.lineBloomLight)
          SpikePair(f(s.color1), f(s.color2)),
      ],
    );

/// Pairs [a]'s tables with [b]'s and combines their colors through [mix],
/// keeping [a]'s geometry. Where [b]'s table is shorter its entries cycle;
/// where it is empty, [a]'s color passes through untouched.
BeamPresetData _zipColors(
  BeamPresetData a,
  BeamPresetData b,
  Color Function(Color, Color) mix,
) {
  Color at<T>(List<T> other, int i, Color own, Color Function(T) color) =>
      other.isEmpty ? own : mix(own, color(other[i % other.length]));

  List<BeamBlob> blobs(List<BeamBlob> xa, List<BeamBlob> xb) => [
    for (final (i, blob) in xa.indexed)
      blob.withColor(at(xb, i, blob.color, (o) => o.color)),
  ];
  List<LineBlob> lines(List<LineBlob> xa, List<LineBlob> xb) => [
    for (final (i, blob) in xa.indexed)
      blob.withColor(at(xb, i, blob.color, (o) => o.color)),
  ];
  List<SpikePair> pairs(List<SpikePair> xa, List<SpikePair> xb) => [
    for (final (i, s) in xa.indexed)
      SpikePair(
        at(xb, i, s.color1, (o) => o.color1),
        at(xb, i, s.color2, (o) => o.color2),
      ),
  ];

  return BeamPresetData(
    border: blobs(a.border, b.border),
    spike: SpikeColors(
      primary: mix(a.spike.primary, b.spike.primary),
      secondary: mix(a.spike.secondary, b.spike.secondary),
    ),
    spikeLt: SpikeColors(
      primary: mix(a.spikeLt.primary, b.spikeLt.primary),
      secondary: mix(a.spikeLt.secondary, b.spikeLt.secondary),
    ),
    smallBorder: blobs(a.smallBorder, b.smallBorder),
    smallInner: blobs(a.smallInner, b.smallInner),
    lineDark: lines(a.lineDark, b.lineDark),
    lineLight: lines(a.lineLight, b.lineLight),
    lineInner: lines(a.lineInner, b.lineInner),
    lineBloomDark: pairs(a.lineBloomDark, b.lineBloomDark),
    lineBloomLight: pairs(a.lineBloomLight, b.lineBloomLight),
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

/// Highest lightness a derived seed color may take — above this the blobs
/// wash out against a light surface.
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
  const _PresetBeamColors(this.preset, {this.isMono = false}) : super._();

  final BeamPresetData preset;
  final bool isMono;

  @override
  Object get _cacheKey => (#preset, preset, isMono);

  @override
  BeamPalette resolve() => _presetPaletteCache[this] ??= _buildPalette();

  @override
  BeamPalette _buildPalette() => BeamPalette(
    data: preset,
    forcesStaticColors: isMono,
    opacityMultiplier: isMono ? 0.5 : 1.0,
    monoTreatment: isMono,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PresetBeamColors &&
          identical(other.preset, preset) &&
          other.isMono == isMono;

  @override
  int get hashCode => Object.hash(identityHashCode(preset), isMono);

  @override
  String toString() => 'BeamColors(preset, isMono: $isMono)';
}

class _CustomBeamColors extends BeamColors {
  const _CustomBeamColors(
    this.colors, {
    this.base = BeamColors.colorful,
    this.staticHue = false,
  }) : super._();

  final List<Color> colors;
  final BeamColors base;

  // Set only by the built-in single-hue presets; `BeamColors.custom` never
  // exposes it, because pinning the hue of a palette the caller chose would
  // silently ignore their `hueMode`.
  final bool staticHue;

  @override
  Object get _cacheKey =>
      (#custom, _ListKey(colors), base._cacheKey, staticHue);

  @override
  BeamPalette _buildPalette() {
    validateColorTable(colors.length, 'BeamColors.custom colors');
    return BeamPalette(
      data: _distribute(colors, base.resolve().data),
      forcesStaticColors: staticHue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CustomBeamColors &&
          listEquals(other.colors, colors) &&
          other.base == base &&
          other.staticHue == staticHue;

  @override
  int get hashCode => Object.hash(Object.hashAll(colors), base, staticHue);

  @override
  String toString() => 'BeamColors.custom($colors)';
}

class _SeedBeamColors extends BeamColors {
  const _SeedBeamColors(this.seed, {this.harmony = BeamSeedHarmony.analogous})
    : super._();

  final Color seed;
  final BeamSeedHarmony harmony;

  @override
  Object get _cacheKey => (#seed, seed, harmony);

  @override
  BeamPalette _buildPalette() => BeamPalette(
    data: _distribute(_seedColors(seed, harmony), colorfulPreset),
  );

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

  @override
  Object get _cacheKey => (#lerp, a._cacheKey, b._cacheKey, t);

  @override
  BeamPalette _buildPalette() {
    final pa = a.resolve();
    final pb = b.resolve();
    final nearer = t < 0.5 ? pa : pb;
    return BeamPalette(
      data: _zipColors(pa.data, pb.data, (x, y) => Color.lerp(x, y, t)!),
      forcesStaticColors: nearer.forcesStaticColors,
      opacityMultiplier: lerpDouble(
        pa.opacityMultiplier,
        pb.opacityMultiplier,
        t,
      )!,
      monoTreatment: nearer.monoTreatment,
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
    assert(factor >= 0, 'BeamColors.scaleAlpha requires a non-negative factor');
    final base = source.resolve();
    return BeamPalette(
      data: _mapColors(
        base.data,
        (c) => c.withValues(alpha: clampDouble(c.a * factor, 0, 1)),
      ),
      forcesStaticColors: base.forcesStaticColors,
      opacityMultiplier: base.opacityMultiplier,
      monoTreatment: base.monoTreatment,
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

class _SpecBeamColors extends BeamColors {
  const _SpecBeamColors({
    required this.border,
    this.smallBorder,
    this.lineBlobs,
  }) : super._();

  final List<BeamBlob> border;
  final List<BeamBlob>? smallBorder;
  final List<LineBlob>? lineBlobs;

  @override
  Object get _cacheKey => (
    #spec,
    _ListKey(border),
    smallBorder == null ? null : _ListKey(smallBorder!),
    lineBlobs == null ? null : _ListKey(lineBlobs!),
  );

  @override
  BeamPalette _buildPalette() {
    validateColorTable(border.length, 'BeamColors.spec border');
    // The caller keeps their list, and a growable one they mutate later would
    // otherwise change the palette this cache holds under a key that no
    // longer matches it. Every table that reaches BeamPresetData is a
    // snapshot of its own — the unmodifiable cache key alone does not make
    // the resolved palette immutable.
    final borderTable = List<BeamBlob>.unmodifiable(border);
    final smallTable = smallBorder == null
        ? null
        : List<BeamBlob>.unmodifiable(smallBorder!);
    final lineTable = lineBlobs == null
        ? null
        : List<LineBlob>.unmodifiable(lineBlobs!);
    // Derive any missing tables by cycling the provided border colors over
    // the default geometry.
    final derived = _distribute([
      for (final b in borderTable) b.color,
    ], colorfulPreset);
    return BeamPalette(
      data: BeamPresetData(
        border: borderTable,
        spike: derived.spike,
        spikeLt: derived.spikeLt,
        smallBorder: smallTable ?? derived.smallBorder,
        smallInner: smallTable != null
            ? [
                for (final b in smallTable)
                  b.withColor(b.color.withValues(alpha: b.color.a * 0.45)),
              ]
            : derived.smallInner,
        lineDark: lineTable ?? derived.lineDark,
        lineLight: lineTable ?? derived.lineLight,
        lineInner: derived.lineInner,
        lineBloomDark: derived.lineBloomDark,
        lineBloomLight: derived.lineBloomLight,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SpecBeamColors &&
          listEquals(other.border, border) &&
          listEquals(other.smallBorder, smallBorder) &&
          listEquals(other.lineBlobs, lineBlobs);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(border),
    smallBorder == null ? null : Object.hashAll(smallBorder!),
    lineBlobs == null ? null : Object.hashAll(lineBlobs!),
  );

  @override
  String toString() =>
      'BeamColors.spec(border: ${border.length} blobs, '
      'smallBorder: ${smallBorder?.length}, lineBlobs: ${lineBlobs?.length})';
}
