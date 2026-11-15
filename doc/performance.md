# Performance

A beam is meant to be something you can leave running on a card while the user scrolls, at the display's full rate, without the phone warming up. The renderer is built around one rule: **one shader, one draw, no offscreen work.**

## What a frame costs

**One draw call.** Every frame of every effect is a single `drawRect` or `drawDRRect` whose paint carries the beam's fragment shader. There is no `saveLayer` (no offscreen render target to allocate, fill, and composite back), no clip, and no `ImageFilter` or `MaskFilter` (no blur pass). Glows that would conventionally be blurred — the bloom around the stroke, the outer halo, the light reaching inward — are evaluated analytically per pixel instead: a gaussian or a smooth falloff of the distance to the border.

`test/render/frame_budget_test.dart` asserts this for every effect, on both surface tunings, across a palette subset, every shape family (rounded, per-corner, superellipse, stadium, segment, dashes, inward and outward ring offset, a thick border), the effect options, driven progress, and several instants: exactly one draw with the beam shader, zero `saveLayer`s, zero clips, no image or mask filter, and balanced saves and restores. A frame the fade or a cycle gap has blacked out draws nothing at all.

**Pixels only where light can land.** The draw covers the box grown by the furthest outward glow, minus the interior beyond the furthest inward one — a ring, not the whole box. A beam whose light hugs the border shades a thin band of pixels.

**Little CPU per frame.** Per frame the beam samples its phases from one elapsed-seconds number, hue-rotates at most eight palette colours, computes a few bumps of light along the border and up to eight point lights, and writes a fixed block of uniform floats into a `FragmentShader` it reuses for its lifetime. There is no path building, no gradient construction, and no per-frame buffer allocation; the outline is computed in the shader and its Dart mirror is cached until the box or radius changes.

**Every effect costs about the same.** They share the shader and the single draw, so choose effects for their look.

## 120Hz

The beam's clock ticks on every frame the engine produces; there is no frame-rate cap on any effect. On a 120Hz display the beam animates at 120Hz.

On ProMotion iPhones, iOS holds an app to 60Hz unless the app opts in. Add this to your app's `ios/Runner/Info.plist`:

```xml
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
```

The example app sets it. iPads with ProMotion need no key.

## Loading the shader

The shader is a package asset, compiled by the Flutter tool and loaded once per process with `FragmentProgram.fromAsset`. A beam starts the load itself and paints nothing until it resolves — a few milliseconds that the 0.6s fade-in hides. To have the very first frame ready, load it at startup:

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

**Repaints without rebuilds.** The clock, `progress`, `strengthListenable`, and `speedListenable` drive the painter directly; none of them rebuilds a widget per frame.

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
3. **Keep glows proportionate.** `style.glow` scales how far light reaches; a larger reach means more pixels shaded. `halo` and `rotate(comet: true)` reach furthest outward.
4. **Keep `pauseWhenOffscreen` on.** Turn it off only when a beam must stay in step with something visible while it is itself out of view.
5. **Keep palettes value-equal.** A palette that compares unequal on every build re-resolves the config each time. See [palettes](palettes.md#values-equality-and-the-memo).

## Web

The package compiles and runs on web — the [playground](https://simplifyjobs.github.io/flutter_border_beam/) is a web build of the example app, and CI builds it on every commit. The renderer is the same single shader draw there.
