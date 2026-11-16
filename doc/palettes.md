# Palettes

A palette is a **ring of colour stops around the border**. Each stop is a colour at a perimeter position in `[0, 1)`: 0 is top-centre, and positions increase clockwise by arc length. Between stops the colour blends, and past the last stop it blends back into the first across top-centre, so the ring has no seam.

Effects draw a palette as soft blobs of colour placed around the border — the same blob tables the original design was tuned with:

- The four originals (`colorful`, `mono`, `ocean`, `sunset`) carry their own hand-tuned tables; the seven extras that follow them cycle their colours over `colorful`'s tables.
- Every other palette — the presets new in 0.2 and everything you build with `BeamColors(...)`, `.solid`, `.fromSeed`, `.fromScheme`, `.lerp` — keeps `colorful`'s blob geometry and takes each blob's colour from the ring of stops at the point of the border the blob sits on. `scaleAlpha` keeps a preset's own tables, dimmed. The tables are worked out once per palette.

How the colours are shown depends on the effect:

- `rotate` and `pulse` hold the colours still and reveal them wherever their light falls — a rotating beam changes colour as it laps the border.
- `line` spreads the palette across its streak, so every colour shows at once.

## Presets

| Preset | Colours | Notes |
| --- | --- | --- |
| `colorful` | orange, magenta, violet, blue, green, hot pink | the default |
| `mono` | whites and greys | the hue never drifts |
| `ocean` | blues and violets | |
| `sunset` | reds, oranges, amber | |
| `aurora` | teal, violet, green | |
| `neon` | magenta, lime, cyan | the loudest |
| `candy` | pastel pink, lavender, peach | |
| `ember` | deep red, orange, gold | |
| `ice` | pale blue, white, cyan | |
| `gold` | amber, gold, bronze | the hue never drifts |
| `holographic` | desaturated pastels | built for a fast continuous hue drift |
| `lagoon` | teal, aqua, mint | |
| `dusk` | indigo, violet, rose | |
| `forest` | emerald, lime, teal | |
| `rose` | pink, coral, mauve | |
| `cosmic` | deep violet, electric blue, magenta | |
| `citrus` | lime, yellow, tangerine | |
| `sky` | cerulean, periwinkle, white-blue | |
| `lavender` | lilac, lavender, soft pink | |

`BeamColors.presets` is a `Map<String, BeamColors>` of all 19, in this order — handy for a picker. The presets' stops live in `lib/src/models/beam_presets.dart` and their blob tables in `lib/src/look/`; every one is meant to read on both dark and light surfaces.

Two presets pin the hue: `mono` and `gold` set `BeamHueMode.none` whatever the style says, because a hue sweep over greys or a single-hue metal reads as the material changing. `mono` is also painted with its layers at half strength (the line softens its spikes instead), since white light reads brighter than coloured light at the same opacity.

`holographic` is the opposite bet — low-contrast pastels that come alive under a fast continuous drift:

```dart
BorderBeam(
  colors: BeamColors.holographic,
  style: const BeamStyle(hueMode: BeamHueMode.continuous),
  timing: const BeamTiming(huePeriod: Duration(seconds: 3)),
  child: card,
);
```

## Your own colours

```dart
// Evenly spaced clockwise from top-centre: 0, 1/3, 2/3.
const BeamColors([Colors.pink, Colors.cyan, Colors.amber]);

// At chosen positions.
const BeamColors(
  [Color(0xFF6B2BFF), Color(0xFFF02BD9), Color(0xFF33A1FF)],
  stops: [0.1, 0.45, 0.8],
);

// One colour all the way round.
const BeamColors.solid(Color(0xFF18A8F0));
```

`BeamColors(colors, {stops})` takes 1–8 colours. `stops`, when given, has one entry per colour, ascending, each in `[0, 1)`; two equal neighbours make a hard edge. Alpha is honoured: a translucent stop glows more faintly. The lists are checked when the palette first resolves — in release builds too — and a malformed one throws an `ArgumentError`.

Colours blend **gamma-aware**: squared channels (close to linear light) are interpolated and the square root taken, so the midpoint between two saturated colours stays bright instead of turning muddy. The blending runs on the CPU once per palette — the results are memoized — never per frame.

## From a brand colour

`BeamColors.fromSeed` spreads one colour into a palette with one of four harmonies, spaced evenly round the border:

| `BeamSeedHarmony` | Hue offsets | Feel |
| --- | --- | --- |
| `analogous` (default) | 0°, +25°, −25°, +50° | calmest; still reads as one colour |
| `complementary` | 0°, +15°, +180°, +195° | maximum contrast between the two halves |
| `triadic` | 0°, +120°, +240° | three-way, evenly spaced |
| `monochrome` | one hue, four lightness steps | a single-hue brand look |

The derived colours are lifted into a band a glow reads well in (lightness 0.55–0.70, with a saturation floor), so a black, white, or grey seed still yields a visible palette. That is also why `fromSeed` cannot reproduce a very dark or very desaturated brand colour exactly — use `BeamColors([...])` when you need the exact colour.

```dart
const BeamColors.fromSeed(Color(0xFF18A8F0), harmony: BeamSeedHarmony.complementary);
```

`BeamColors.fromScheme(colorScheme)` takes the scheme's `primary`, `secondary`, and `tertiary`, dropping any role that is nearly the same colour as one already kept — so a scheme whose secondary matches its primary gives two colours rather than a doubled one. It is not `const`.

## Transforming a palette

```dart
// Crossfade two palettes from an animation.
BorderBeam(
  colors: BeamColors.lerp(BeamColors.ocean, BeamColors.ember, animation.value),
  child: card,
);

// Dim the palette itself.
BorderBeam(colors: BeamColors.neon.scaleAlpha(0.5), child: card);
```

`BeamColors.lerp(a, b, t)` samples both palettes at eight evenly spaced positions and mixes each pair gamma-aware at `t`, which is clamped to 0–1. At exactly 0 or 1 it returns `a` or `b` unchanged. The result pins its hue when the nearer end does.

`scaleAlpha(factor)` multiplies every stop's alpha, clamped to 0–1; `factor` must not be negative. It dims the palette rather than the beam, so stops that were already fainter stay relatively fainter. `BeamStyle.strength` is the other lever: it scales the whole beam's opacity. Reach for `scaleAlpha` when a palette is too hot and `strength` when the whole effect is.

## Hue drift

On top of its stops, a palette can drift in hue over time (`BeamStyle.hueMode`):

- `pingPong` swings the hue ±`hueShift` degrees (30 by default) and back over one `huePeriod`;
- `continuous` turns it a full 360° per `huePeriod`;
- `none` paints the palette as given.

`hueBase` adds a fixed rotation in degrees on top, which is the quickest way to nudge a preset toward a brand colour. Each effect picks its own default mode and period — see [effects](effects.md#defaults). The rotation is folded into each blob's colour on the CPU every frame, so drifting costs nothing on the GPU.

## Values, equality, and the memo

Every `BeamColors` is a value type: two instances built from equal inputs are `==`. Resolution to a concrete `BeamPalette` is memoized by value through a bounded LRU (32 entries), so building `BeamColors([...])` inline in `build` is free after the first frame, and an evicted palette is rebuilt and compares equal to the one it replaced. Presets skip the memo entirely: each is a canonical constant.

The practical consequence: do not hand the beam a palette that compares unequal on every build. A beam whose palette changes re-resolves its config and rebuilds its phase resolver, every frame if the palette changes every frame.
