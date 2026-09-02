# Performance

A beam is an animated blur — the most expensive thing a phone GPU does per pixel. The engine is built around keeping that cost fixed and small, and around never paying it for a beam nobody can see.

## What the engine does for you

**One ticker per beam.** Not per layer, not per track. Every animated value is recomputed from one elapsed-seconds number each frame, so there is no per-track state to advance and no controller graph to walk. Under a [`BeamSync`](motion.md#beamsync) the whole subtree shares a single ticker.

**A ~30fps cap on the pulse variants**, matching the original's pulse driver. Time still accumulates at full resolution — only notifications are throttled — so the animation is not slowed, just sampled less often. A `pulse()` or `flash()` boost lifts the cap while it plays, because a brightness accent at 30fps reads as a step.

**`RepaintBoundary` isolation, twice.** The beam sits in its own boundary, and the child sits in another one inside it. The consequence is the one that matters: **your child never re-rasterizes** when the beam animates, however complex the child is.

**Color matrices folded on the CPU.** Hue, brightness, and saturation are baked into the gradient colors before painting rather than carried on a `ColorFilter`. A filter needs a layer to ride on; folding it costs a few multiplications per frame instead.

**An offscreen pause.** With `playback.pauseWhenOffscreen` (the default), a beam watches its nearest enclosing `Scrollable` and stops its clock once it is more than 256px outside the viewport, resuming exactly where it left off — play state, fade, and callbacks untouched. A long list of beamed cards therefore costs the beams you can see, not the beams you have. With no enclosing `Scrollable` it does nothing.

## The saveLayer budget

`saveLayer` is the expensive call: it allocates an offscreen surface, paints into it, and composites it back. The per-frame count — `paintBehind` plus `paintAbove` — is fixed per variant and **measured**, not estimated:

| Variant | `saveLayer`s per frame |
| --- | --- |
| `rotate` | 4 |
| `small` | 3 |
| `line` | 4 |
| `pulseInside` | 4 |
| `pulseOutside` | 3 |

Each entry is a layer the variant genuinely composites: the inner glow, the stroke, the bloom, the mask sub-layer where two masks intersect (`rotate`, `line`, `pulseInside`), and pulse-outside's two behind-child glows.

`test/painting/save_layer_budget_test.dart` measures the count through a counting canvas for every variant × brightness × palette × time sample and asserts it **exactly**, along with save/restore balance. A regression and an improvement both fail the suite until the table is updated in both the test and this document — which is the point: the number is a contract, not a high-water mark.

The rule the engine follows: never add a `saveLayer` to carry a `ColorFilter`. A filter rides on a layer that exists anyway, and blur is the only filter allowed to justify a layer of its own.

## Measuring your own scene

**Count the layers a widget paints.** The same technique the budget test uses works on any widget:

```dart
import 'dart:ui' as ui;

final recorder = ui.PictureRecorder();
final canvas = Canvas(recorder);
// Paint your beam's painter into `canvas`, then inspect the recorded picture.
```

For a scene rather than a painter, the simplest reliable count is DevTools: open the **Performance** view, enable **Track widget builds**, and use the *Raster* timeline — `saveLayer` calls show up as separate raster work in the frame's layer tree.

**Check the raster thread, not the UI thread.** A beam does almost nothing on the UI thread; its cost is entirely raster. A frame budget blown by beams shows up as a tall raster bar with a short UI bar.

**Toggle the two DevTools flags that matter here:**

- *Highlight repaints* — every beam should show its own boundary changing color while the child inside it does not. If the child flashes too, something above the beam is invalidating it.
- *Render Surface Layers* (`debugRepaintRainbowEnabled` / the raster overlay) — confirms the beam is compositing on its own surface rather than forcing the page to.

**Profile in profile mode, on a device.** Blur cost in debug mode on a simulator tells you nothing.

## Getting a scene cheaper

In rough order of how much they buy:

1. **Use fewer beams.** A beam is emphasis; a screen where everything is emphasized has none. One hero beam almost always looks better than six.
2. **Put a group on a `BeamSync`.** Ten beams become one ticker and one timeline, and the group reads as deliberate rather than noisy.
3. **Prefer `small` and `pulseOutside`** where the design allows — they are the two three-layer variants.
4. **Drop `sparkle` and `comet`** on a scene that is already tight; both add geometry to the traveling head.
5. **Lower `renderScale`** on very large boxes. It paints the beam smaller and scales up, which cuts blur cost as well as making a card-sized palette read at screen size.
6. **Keep `pauseWhenOffscreen` on.** Turn it off only when a beam must stay phase-locked to something visible while it is itself out of view.
7. **Keep palettes value-equal.** A palette that compares unequal each build re-resolves the config and rebuilds the phase resolver every frame. See [palettes](palettes.md#values-equality-and-the-memo).

## Web

The package compiles and runs on web — the [playground](https://simplifyjobs.github.io/flutter_border_beam/) is a web build of the example app, and CI builds it on every commit. Blur is the expensive part on every web renderer, so `line` and `pulseOutside` cost the most there. A single hero beam is a safe bet; a grid of them is not.
