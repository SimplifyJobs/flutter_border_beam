# Variants

Five effects, two engines. The [README's variant table](../README.md#variants) lists the defaults; this guide is about which one to reach for and how each behaves.

## The two families

**Traveling** (`rotate`, `small`, `line`) sweeps a window around the beam's contour once per `cycle`. Everything about travel applies: `direction`, `cycleGap`, `beamCount`, `phaseOffset`, `progress`, `follow`, `segments`, `tailLength`.

**Pulse** (`pulseInside`, `pulseOutside`) breathes. A bank of independent oscillators scales, drifts, and fades the palette's blobs so that neighbouring blobs never move in lockstep; there is no sweep, so the travel fields above do nothing. Their hue advances continuously rather than swinging, and their clock is capped at ~30fps.

`BeamVariant.isPulse` answers the question in code, and is what the widget uses to pick an engine.

## `rotate` — the default

A beam travels the full border of the box. Tuned for cards, panels, and any surface big enough that a full lap reads as motion rather than a flicker.

```dart
BorderBeam.rotate(borderRadius: 16, child: card);
```

It is the variant most affected by the traveling-only style fields — `comet` trails a soft halo outside the ring behind the head, and `sparkle` scatters twinkles at it:

```dart
BorderBeam.rotate(
  style: const BeamStyle(comet: true, sparkle: 0.5, tailLength: 1.3),
  child: card,
);
```

## `small` — buttons and chips

The same traveling engine at a compact scale, with a 32px default radius. Reach for it on anything the size of a button, an icon, or a chip, where `rotate`'s geometry would overwhelm the element. It is the cheapest variant on the [saveLayer budget](performance.md).

```dart
BorderBeam.small(shape: const BeamShape.stadium(), child: chip);
```

## `line` — inputs

A beam that rides one edge rather than lapping the box, with a bloom that spikes and breathes underneath it. Built for text fields and search bars, where a full border lap fights the caret for attention.

```dart
BorderBeam.line(child: searchBar);
```

Three things are specific to it:

- **Its hue range is capped at 13°**, however large a `hueRange` you set. That cap is in the original, and a wider swing on a single bright edge reads as a color bug rather than an animation.
- **It has a second hue track** for the bloom, on its own `bloomHuePeriod` (8s).
- **It has breathe and spike tracks**, whose periods are given as multiples of `cycle`: `breatheFactor` (1.3), `spikeFactor` (1.33), `spike2Factor` (1.7). They are deliberately incommensurate with the cycle, so the beam never repeats exactly.

`BeamShape.edge` moves it to any side of the box:

```dart
BorderBeam.line(shape: const BeamShape(edge: BeamEdge.top), child: banner);
```

The `mono` palette does **not** get the ×0.5 opacity treatment here; the line variant expresses mono as attenuated spikes inside the bloom instead.

## `pulseInside` — a contained working state

A breathing glow held inside the child's bounds. It is the safe pulse: nothing paints outside the box, so it drops into a list, a grid, or a clipped surface without any layout accommodation. Good for "this row is working", a pressed state (`BeamPress` defaults to it), or a subscribe button that wants attention without a sweep.

```dart
BorderBeam.pulseInside(active: isWorking, child: card);
```

`innerSizeScale` sets how much of the surface the glow fills — below 1 it tightens toward the border, above 1 it reaches further in — and `glowBoost` sets how prominent it is.

## `pulseOutside` — a halo

The same breathing, blooming *behind and outside* the child. It is the most striking variant and the only one with requirements attached:

> The child must be **opaque**, so only the outward spill shows. It should carry its **own 1px border**, which is the edge you see when the glow is at its dimmest. And it needs **clip-free room** — padding in the parent, no tight `ClipRRect` — because a halo with nowhere to bloom is invisible.

```dart
Padding(
  padding: const EdgeInsets.all(32),
  child: BorderBeam.pulseOutside(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    ),
  ),
);
```

It is the only variant that paints on the **behind** pass, which is why it is the only one that goes in a `Container`'s `decoration:` rather than `foregroundDecoration:` when used as a [`BeamDecoration`](../README.md#beamdecoration).

Its four glow overrides — `coreBlur`, `bloomBlur`, `glowBrightness`, `glowSaturation` — port the original's consumer tuning hooks and apply to nothing else. This package's defaults bake the tuning the original's web demo applies; `BeamStyle.pulseOutsideStock` is the library's stock look. See [parity](parity.md).

## Choosing at runtime

The generic constructor takes a `BeamVariant`, so a variant that comes from state, a theme, or a settings screen needs no switch:

```dart
BorderBeam(variant: variant, colors: BeamColors.aurora, child: card);
```

Swapping the variant on a live beam is supported: the widget rebuilds its clock and its strategy, and the old ticker is disposed.
