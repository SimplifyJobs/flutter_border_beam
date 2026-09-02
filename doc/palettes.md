# Palettes

A palette is not a list of colors — it is a set of **blob tables**. Each table entry is an ellipse with a color, a fractional position, and a pair of radii, and the beam's look comes from where those ellipses sit as much as from their hues. The [README's palette tables](../README.md#palettes) list every preset and factory; this guide is about how they work.

## What a palette actually holds

`BeamPalette` carries one table per surface the engine paints:

| Table | Used by |
| --- | --- |
| `border` (9 blobs) | the `rotate` stroke, and as the pulse variants' color source |
| `smallBorder`, `smallInner` | `small` |
| `lineDark`, `lineLight`, `lineInner` | `line`, per brightness |
| `lineBloomDark`, `lineBloomLight`, `spike`, `spikeLt` | the `line` bloom and its spikes |

Plus three modifiers: `forcesStaticColors` (pin the hue), `opacityMultiplier` (the mono ×0.5), and `monoTreatment`.

This is why `BeamColors.custom` takes a *list of colors* and a *base*: it keeps the base's positions, radii, and per-entry alpha and substitutes only the hues, so a custom palette keeps the layered depth the original tuned.

## Presets

Four come from upstream (`colorful`, `mono`, `ocean`, `sunset`) and are transcribed verbatim. Seven are original to this package (`aurora`, `neon`, `candy`, `ember`, `ice`, `gold`, `holographic`) and are defined as short color lists in `lib/src/constants/extra_palettes.dart`, distributed over `colorful`'s geometry exactly the way `BeamColors.custom` does. Editing one of those lists changes how that preset looks and has no bearing on parity with the source.

Two presets pin the hue, for different reasons:

- **`mono`** carries the source's full mono treatment: static colors *and* halved layer opacity, which stops a grayscale beam blowing out.
- **`gold`** pins the hue but keeps full opacity. A hue sweep over a single-hue metal reads as the metal changing material; halving a warm amber only makes it muddy.

`holographic` is the opposite bet — deliberately low-contrast pastels that come alive when paired with a fast continuous hue drift:

```dart
BorderBeam.rotate(
  colors: BeamColors.holographic,
  style: const BeamStyle(hueMode: BeamHueMode.continuous),
  timing: const BeamTiming(huePeriod: Duration(seconds: 3)),
  child: card,
);
```

## Deriving from a brand color

`BeamColors.fromSeed` spreads one color into a palette using one of four harmonies:

| `BeamSeedHarmony` | Hue offsets | Feel |
| --- | --- | --- |
| `analogous` (default) | 0°, +25°, −25°, +50° | calmest; still reads as one color |
| `complementary` | 0°, +15°, +180°, +195° | maximum contrast across the beam |
| `triadic` | 0°, +120°, +240° | three-way, evenly spaced |
| `monochrome` | one hue, four lightness steps | single-hue brand look |

Every derived color is lifted into a band a glow reads well in — lightness 0.55–0.70, saturation at least 0.55 — so a black, white, or gray seed still yields visible, distinguishable blobs rather than a smudge. That clamping is deliberate and is why `fromSeed` cannot reproduce a very dark or very desaturated brand color exactly; when you need the exact color, use `custom`.

```dart
BorderBeam.rotate(
  colors: const BeamColors.fromSeed(
    Color(0xFF18A8F0),
    harmony: BeamSeedHarmony.complementary,
  ),
  child: card,
);
```

`BeamColors.fromScheme` is the Material shortcut over the same machinery: it takes `primary`, `secondary`, and `tertiary`, dropping any role that is within a small RGB distance of one already kept — so a scheme whose secondary matches its primary yields a two-color palette rather than a doubled one.

## Transforming a palette

`lerp` and `scaleAlpha` produce new palettes from existing ones and are themselves values, so they can live in a `const` expression or be rebuilt per frame.

```dart
// Crossfade two palettes from an animation.
BorderBeam.rotate(
  colors: BeamColors.lerp(BeamColors.ocean, BeamColors.ember, animation.value),
  child: card,
);

// Dim without touching layer opacity.
BorderBeam.rotate(colors: BeamColors.neon.scaleAlpha(0.5), child: card);
```

`lerp` interpolates table-by-table, keeping `a`'s geometry and cycling `b`'s colors where its table is shorter. `t` is not clamped, so values outside 0–1 extrapolate. The mono modifiers come from whichever end is nearer, and the opacity multiplier is interpolated.

`scaleAlpha` dims the *palette* rather than the layer opacities, so the relative depth of the inner, stroke, and bloom tables survives. `style.strength` is the other lever: it scales the composited layers instead. Reach for `scaleAlpha` when a palette is too hot, and `strength` when the whole effect is.

## Per-blob control

`BeamColors.spec` replaces the border table outright. Sizes are **radii**, not diameters — they map straight onto CSS `radial-gradient(ellipse W H …)`, whose sizes are radii too — and positions are fractions of the painted box, so values outside 0–1 legitimately sit on or beyond the edge.

```dart
const palette = BeamColors.spec(
  border: [
    BeamBlob(
      color: Color(0xFFFF4D8D),
      position: Offset(0.33, -0.074),
      size: Size(70, 40),
    ),
    BeamBlob(
      color: Color(0xFF18A8F0),
      position: Offset(0.72, 1.05),
      size: Size(90, 50),
    ),
  ],
);
```

Tables you do not supply (`smallBorder`, `lineBlobs`) are derived by cycling your border colors over the default geometry, so a `spec` palette still works on every variant.

## Values, equality, and the memo

Every `BeamColors` is a value type: two instances built from equal inputs are `==`. Resolution to concrete tables is memoized by that value through a bounded LRU (32 entries), so building a palette inline in `build` is free after the first frame, and an evicted palette is simply rebuilt and compares equal to the one it replaced. The four upstream presets bypass the LRU entirely — they are canonical const instances, memoized by identity for the life of the isolate.

The practical consequence: **never** put a palette behind a factory that returns a fresh non-equal object each build (a `Color` list built with `List.generate` is fine — it compares by element; a closure is not). If a beam re-resolves its config every frame, an unequal palette is the first thing to check.
