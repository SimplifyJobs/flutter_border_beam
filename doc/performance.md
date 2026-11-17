# Performance

What a frame of each effect costs, what the widgets do to keep it cheap, and what an app can do wrong. The sections up to [Getting a scene cheaper](#getting-a-scene-cheaper) cover `BorderBeam`; [DistortionWave](#distortionwave) covers the wave.

A beam is meant to be something you can leave running on a card while the user scrolls, at the display's full rate, without the phone warming up. The renderer is built around one rule: **one shader, one draw, no offscreen work.**

## What a frame costs

**One draw call.** Every frame of every effect is a single `drawRect` or `drawDRRect` whose paint carries the beam's fragment shader. There is no `saveLayer` (no offscreen render target to allocate, fill, and composite back), no clip, and no `ImageFilter` or `MaskFilter` (no blur pass). The design is built from layers — an inner glow, a hairline stroke, a bloom — and several of them are blurred in the reference look; here the shader evaluates every layer per pixel and replaces each blur with its closed form: a blurred hairline is a gaussian across the distance to the ring, a blurred colour blob is a gaussian blob with the same energy, a blurred glow outside the box is a smooth step across its edge.

`test/border_beam/render/frame_budget_test.dart` asserts this for every effect, on both surface tunings, across a palette subset, every shape family (rounded, per-corner, superellipse, stadium, segment, dashes, inward and outward ring offset, a thick border), the effect options, driven progress, and several instants: exactly one draw with the beam shader, zero `saveLayer`s, zero clips, no image or mask filter, and balanced saves and restores. A frame the fade or a cycle gap has blacked out draws nothing at all.

**Pixels only where light can land.** The draw covers the box grown by the furthest outward glow, minus the interior beyond the furthest inward one — a ring, not the whole box. The inner glows fade out a short way in, so a card's beam shades a band around its edge; the line's bloom rises through the box, and a comet reaches outside it.

**Cheap pixels.** Per pixel the shader computes the distance to the outline once, reads its four conic tables (an unused one stops at a single comparison), and then, layer by layer, skips everything a mask has already zeroed: the 1px stroke evaluates its blobs only on the ring itself, a windowed layer only inside its window. A layer holds at most 14 blobs (most hold 7–10), each a handful of multiply-adds and one square root or exponential.

**Little CPU per frame.** Per frame the beam samples its phases from one elapsed-seconds number, samples the effect's keyframes or oscillators, writes a few dozen blobs and a fixed block of 672 uniform floats into a buffer it reuses, folds each layer's colour filter into its colours, and uploads the floats to a `FragmentShader` it keeps for its lifetime. There is no path building, no gradient construction, and no per-frame buffer allocation; a palette's blob tables are resolved once and remembered, and the outline's Dart mirror is cached until the box or radius changes.

**Every effect costs about the same.** They share the shader and the single draw; what differs is how many pixels the draw covers — `line` covers its whole box, since its bloom rises through it, and `rotate(comet: true)` reaches furthest outside.

## 120Hz

The beam's clock ticks on every frame the engine produces; there is no frame-rate cap on any effect. On a 120Hz display the beam animates at 120Hz.

On ProMotion iPhones, iOS holds an app to 60Hz unless the app opts in. Add this to your app's `ios/Runner/Info.plist`:

```xml
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
```

The example app sets it. iPads with ProMotion need no key.

## Loading the shader

The shader is a package asset, compiled by the Flutter tool and loaded once per process with `FragmentProgram.fromAsset`. A beam starts the load itself and paints nothing until it resolves — a few milliseconds that the fade-in hides. To have the very first frame ready, load it at startup:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BorderBeam.precache();
  runApp(const App());
}
```

In widget tests that read pixels, `await BorderBeam.precache()` in `setUpAll`.

## What the widget does for you

**One ticker per beam** — or exactly one per `BeamSync`, however many beams are in the group.

**`RepaintBoundary` isolation, twice.** The beam sits in its own repaint boundary and the child in another inside it, so **your child never re-rasterizes** when the beam animates, however complex it is.

**An offscreen pause.** With `playback.pauseWhenOffscreen` (the default), a beam watches its nearest enclosing `Scrollable` and stops its clock once it is more than 256px outside the viewport, resuming exactly where it left off — play state, fade, and callbacks untouched. A long list of beamed cards costs the beams you can see. With no enclosing `Scrollable` it does nothing.

**Repaints without rebuilds.** The clock, `strengthListenable`, and `speedListenable` drive the painter directly; none of them rebuilds a widget per frame. `progress` is a plain value, so a new one arrives with a rebuild of the beam, but it reaches the painter through a listenable and repaints without re-resolving the configuration.

## Impeller: keep the beam off offscreen ancestors

The beam itself never asks for an offscreen pass, but an ancestor can force one around it, and then the beam's pixels are rendered into a texture and composited back every frame. Keep a beam out from under:

- **`Opacity`, `AnimatedOpacity`, and `FadeTransition`** with a value strictly between 0 and 1;
- **`ShaderMask`**;
- **`BackdropFilter`**;
- **`ColorFiltered`** and **`ImageFiltered`**;
- a clip with `Clip.antiAliasWithSaveLayer`.

To fade a beam, use `style.strength` (static), `strengthListenable` (per frame, no rebuild), or `active` (the beam's own fade) instead of wrapping it in `Opacity`. To dim only the colours, use `BeamColors.scaleAlpha`.

## Measuring your own scene

**Check the raster thread.** A beam does very little on the UI thread; its cost is a single draw on the raster thread. In DevTools' Performance view, a frame budget blown by beams shows up as a tall raster bar with a short UI bar.

**Look for offscreen passes above the beam.** If raster time is high, check the layer tree for an `OpacityLayer`, `ShaderMaskLayer`, `BackdropFilterLayer`, or `ColorFilterLayer` above the beam — that is the ancestor problem above, not the beam.

**Use the repaint overlay.** With *Highlight repaints* on, each beam's boundary should change colour every frame while the child inside it does not. If the child flashes too, something above the beam is invalidating it.

**Profile in profile mode, on a device.** Debug builds and simulators tell you little about GPU cost.

## Getting a scene cheaper

1. **Use fewer beams.** A beam is emphasis; a screen where everything is emphasized has none. One hero beam usually looks better than six.
2. **Put a group on a `BeamSync`.** Many beams become one ticker and one timeline, and the group reads as deliberate.
3. **Keep glows proportionate.** `style.glow` scales how far light reaches; a larger reach means more pixels shaded. `rotate(comet: true)` reaches furthest outward.
4. **Keep `pauseWhenOffscreen` on.** Turn it off only when a beam must stay in step with something visible while it is itself out of view.
5. **Keep palettes value-equal.** A palette that compares unequal on every build re-resolves the config each time. See [palettes](palettes.md#values-equality-and-the-memo).

## DistortionWave

Code: `lib/src/distortion_wave/render/render_wave_stage.dart`,
`render/wave_snapshot.dart`, `render/dot_atlas.dart`. Internals:
[distortion_wave.md](distortion_wave.md).

### What a frame costs, by phase

| Phase | On the stage's canvas | Offscreen work |
| --- | --- | --- |
| `rest` (progress 0 or 1) | the visible side, painted as itself | none; no ticker runs; pictures released |
| `distorting` (the wave bends content) | one `drawRect` with `wave.frag`, plus at most one `drawRawAtlas` for the dots | a side's pictures, only when (re)taken — below |
| `glowing` (front crossed, only colour on the edges) | the revealed side as itself, one `drawRect` with `wave_glow.frag` (none once the colour is gone), at most one `drawRawAtlas` | none; pictures released |
| `crossfading` (reduced motion, or a side holding a platform view) | both sides, the outgoing one in a `pushOpacity` layer | the opacity layer's offscreen pass |

The stage's canvas never gets a `saveLayer`, clip, `ImageFilter`,
`BackdropFilter`, `MaskFilter` or image draw in the first three phases.
`test/distortion_wave/render/wave_frame_budget_test.dart` asserts this per
phase × type, and pins how many pictures each side gets.

Per frame on the CPU: `WaveFrame.at` (pure arithmetic), the rim's lumps,
the visible dots' positions, and an upload of `waveUniformFloats` (124)
floats into a `FragmentShader` the stage keeps. The stage and spec uniforms
are rewritten only when they change.

### What a picture costs

Taking a picture of a side (`WaveSideImages.take`) is one offscreen render
of the side's layer tree at the device pixel ratio (`OffsetLayer.toImageSync`).
The first frame of a picture that has blur to show (blur energy above 0 and
`WaveLens.blur` above 0) also bakes two blurred copies, each a
`drawImageRect` through `ImageFilter.blur` into a `Picture` rasterised with
`toImageSync`: a near copy at one pixel per logical pixel and a far copy at
half that. With `WaveLens.blur: 0` no copies are baked.

| `WaveSnapshots` | Pictures per run |
| --- | --- |
| `onChange` (default) | The outgoing side once, on the first `distorting` frame; the incoming side once, when the front launches. Again only when content repaints through the side (an animation inside it that is not behind its own `RepaintBoundary`). Each picture: 1 render + up to 2 blur bakes. |
| `everyFrame` | Every `distorting` frame, for each side shown: 1 render + up to 2 blur bakes each — up to 6 offscreen renders a frame while both sides show. Use it only when content behind a nested `RepaintBoundary` must keep moving through the wave. |

Pictures are GPU images the size of the stage (the blurred copies smaller),
held only while the phase is `distorting`: released at rest, in the glowing
and crossfading phases, when a side stops showing, when the device pixel
ratio changes, and when the stage is detached or disposed.

`DistortionWaveRoute` adds one more picture: the page underneath, rasterised
from its route's `RepaintBoundary` once after the push's first frame and
once as a pop starts, held by the route until it is replaced or the route is
disposed.

### Keeping it cheap

- `await DistortionWave.precache()` at startup: it loads both programs and
  draws both shaders, a blur bake and an atlas into a 4 × 4 image, so the
  pipelines exist before the first wave's first frame.
- Keep `snapshots: WaveSnapshots.onChange` unless something visibly freezes.
- An animation inside a side that repaints through it re-pictures that side
  on each of its frames while the wave bends it; pause decorative animations
  in a side for the second or so the wave runs, or put them behind a
  `RepaintBoundary` (they then hold still while bent).
- A platform view in a side cannot be pictured; that run is a crossfade. A
  `DistortionWaveRoute` over a page showing one fades the new page in and
  out instead of bending the page underneath.

## Web

The package compiles and runs on web — the [live demo](https://simplifyjobs.github.io/prismatic/) is a web build of the example app, and CI builds it on every commit. The beam is the same single shader draw there; the wave's shaders are SkSL strict ES2 so they run on Skia and the web as well as Impeller.
