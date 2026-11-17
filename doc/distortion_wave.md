# DistortionWave — internals

How a distortion wave is built, from its timeline to the draws a frame
takes. For using it, see [distortion_wave_usage.md](distortion_wave_usage.md);
for the border beam's renderer, [architecture.md](architecture.md). Code
shared with the beam: `lib/src/core/shader_program.dart` (`ShaderProgram`)
and `shaders/common/outline.glsl`, mirrored in Dart by `BeamOutline`
(`lib/src/border_beam/render/beam_outline.dart`). The wave's colours are
mixed in OKLab with `Oklab` (`lib/src/core/oklab.dart`), which lives in
`lib/src/core/` but only the wave uses.

Three ideas carry it:

1. **Everything is a pure function of one progress value.** `WaveFrame.at`
   turns progress (0–1 over the wave's whole life), the source, the view's
   size and the settled style into every number the frame needs. Nothing is
   integrated frame to frame, which is what lets the wave scrub, reverse
   mid-way, run off a route's animation, and freeze for a golden.
2. **The views are drawn from pictures of themselves.** While the wave bends
   content, each side is rasterised to a GPU image (plus two blurred copies),
   and one fragment shader draws the frame from those images. The frame's own
   canvas gets no layer, clip, `BackdropFilter`, `ImageFilter` or image draw;
   the pictures and their blurred copies are separate offscreen renders made
   only when a side is pictured.
3. **A picture is taken only when it is needed.** Once when the wave first
   needs a side, and again only when that side's content repaints (or every
   frame, under `WaveSnapshots.everyFrame`); released as soon as the content
   no longer bends.

## Module map

| Path | Contents |
| --- | --- |
| `lib/distortion_wave.dart` | The library: exports the public types only. |
| `lib/src/distortion_wave/distortion_wave.dart` | `DistortionWave` and its state (clock, controller binding, anchor registry, theme/shorthand resolution into a `WaveSpec`, `maintainState`, `TickerMode` and `ExcludeFocus` for the side off screen); `WaveStage` (a `SlottedMultiChildRenderObjectWidget` over `RenderWaveStage`); `WaveSide` / `RenderWaveSide` (reports repaints of a side to the stage). |
| `lib/src/distortion_wave/distortion_wave_route.dart` | `DistortionWaveRoute` and its transition widget. |
| `lib/src/distortion_wave/distortion_wave_controller.dart` | `DistortionWaveController`; the unexported `WaveDriver` interface (implemented by the wave's state) and `DistortionWaveControllerBinding` (`attach`/`detach`/`arrived`). |
| `lib/src/distortion_wave/distortion_wave_theme.dart` | `DistortionWaveTheme`, `DistortionWaveThemeData`. |
| `lib/src/distortion_wave/wave_source.dart` | `WaveSource` (sealed: rect / key / global / none), `defaultWaveSource`, `DistortionWaveAnchor` + state, `WaveAnchorRegistry`, `WaveAnchorScope`. |
| `lib/src/distortion_wave/models/` | Public value objects (`wave_style.dart`, `wave_timing.dart`, `wave_motion.dart`, `wave_lens.dart`, `wave_glow.dart`, `wave_dots.dart`, `wave_palette.dart`, `wave_type.dart`, `wave_snapshots.dart`) and the internal `wave_spec.dart`. |
| `lib/src/distortion_wave/look/wave_defaults.dart` | `waveDefaults(type)`: each type's fully set, tuned style; `waveTravelEasing`, `waveRimEasing`. |
| `lib/src/distortion_wave/timeline/` | `wave_frame.dart` (`WaveFrame.at`, `waveCoverZone`, `waveSmooth`), `wave_particles.dart` (`WaveParticle.all(spec)`, cached for the last few specs), `wave_rim.dart` (`WaveRim.lumps`, `WaveRim.count`, `thickness`), `wave_clock.dart` (`WaveClock`). |
| `lib/src/distortion_wave/render/` | `render_wave_stage.dart` (`RenderWaveStage`, `WaveSlot`, `WavePhase`), `wave_snapshot.dart` (`WaveSideImages`), `wave_frame_data.dart` (`WaveFrameData`, `waveUniformFloats`, `wavePaletteSlots`, `waveNearBlur`), `wave_programs.dart` (`waveProgram`, `waveGlowProgram`, `loadWavePrograms`), `dot_atlas.dart` (`DotAtlas`), `wave_warm_up.dart` (`warmUpWaveRendering`). |
| `shaders/wave.frag`, `shaders/wave_glow.frag` | The two programs, declared under `flutter: shaders:`. |
| `shaders/common/wave_uniforms.glsl`, `wave_field.glsl`, `wave_colour.glsl`, `outline.glsl` | Includes (not listed in the pubspec; impellerc gets `shaders/` as an include path). |

## Settling the look: `WaveSpec`

`WaveSpec.resolve(style, fallback: themeStyle)` layers the widget's style
(with the `type`/`palette` shorthands merged over it) over the merged theme
style, picks the type (else `vertical`), and merges the result over
`waveDefaults(type)`. Every field is then converted to seconds and logical
pixels and settled to a finite value: the constructors' `assert`s vanish in
release builds, so `_within` maps NaN to the field's floor and clamps to its
range, and `_finite` maps a non-finite signed length to 0. Equality is the
resolved style's, so a rebuild with an equal style changes nothing in the
render object (`RenderWaveStage.spec` returns early on `==`).

`duration` = anticipation + the latest of (travel × 0.6, linger + rimFade,
linger + hairlineLinger + hairlineFade, dot life). `returnDuration` =
`duration / returnSpeed`.

## The timeline

The wave's life, in order (`lib/src/distortion_wave/timeline/wave_frame.dart`):

1. **Anticipation.** Everything is pulled toward the source, more the nearer
   it is; a ring of colour falls in onto where the front will start; dots hop
   toward the source and fade before reaching it.
2. **Launch.** The front leaves the source's own outline. For the vertical
   and horizontal waves the front is an offset of a pill — the source's long
   side — whose straight spine shrinks to nothing while its radius grows, so
   it opens into an arc; its x axis is squashed so the arc bows across a tall
   screen. It leans toward the touch as it opens. The center wave is a ring
   from the source's centre, and leaves the source itself alone (`hold`).
3. **Travel.** The front crosses the view on the wave's easing (fast out of
   the source, settling softly). The swell, blur and colour on the front die
   away over the middle part of the travel, while the front still moves.
4. **Edges.** The colour the band left on the view's edges clings there,
   uneven and drifting, with a hairline on the glass; a second, later front
   wipes the colour away, and a third, later still, the hairline.

`WaveFrame` reports which sides show (`showsOutgoing` until the front has
crossed the whole view — `hasCleared` — and `showsIncoming` once it has
`launched`), whether content is bent (`bendsContent`: `energy > 0 ||
gravity > 0`) and whether the content can be drawn as itself
(`contentAtRest`: cleared and not bent). `WaveParticle` and `WaveRim` are
pure in the same way.

A reveal runs the clock linearly over `duration`; a collapse runs it back on
`spec.easing` over `returnDuration`. `WaveClock` runs from wherever progress
is, at a full run's speed (half the way takes half the time); a new `runTo`
interrupts the one in flight without a jump, and its `onDone` is dropped. A
route drives the same stage from its own animation, curved linearly forward
and on `spec.easing.flipped` in reverse.

## The frame

```text
WaveClock or route animation (or the held `progress`)
  └─► RenderWaveStage.paint
        ├─ WaveFrame.at(progress, source, size, spec, focus)
        ├─ phase: rest │ distorting │ glowing │ crossfading
        ├─ WaveSideImages for each side shown (taken or reused)
        ├─ WaveFrameData ─► wave.frag ─► one drawRect
        └─ DotAtlas ─► at most one drawRawAtlas
```

| Phase | When | Draws |
| --- | --- | --- |
| `rest` | progress 0 or 1 (or the shader not yet loaded) | the visible side, as itself; images released |
| `distorting` | the wave bends content, or the outgoing side still shows | both sides' images through `wave.frag` (one `drawRect`), and the dots |
| `glowing` | `contentAtRest` | the revealed side as itself, `wave_glow.frag` over it (one `drawRect`, skipped when edge colour and band are both 0), and the dots; images released |
| `crossfading` | reduced motion (`plain`), or a side that cannot be rasterised | the incoming side, and the outgoing one over it in a `pushOpacity` layer (with no outgoing side — a route over a page it could not picture — the incoming side fading in in that layer); images released |

The stage is a repaint boundary that repaints on every change of its
progress listenable. A side that is not shown is never pictured; its sampler
slots are bound to the other side's images so every sampler is set.

### Pictures of the sides

`WaveSideImages.take(side, devicePixelRatio)` paints a side into a detached
`OffsetLayer` and rasterises it with `toImageSync` at the device pixel ratio
— the technique of Flutter's `SnapshotWidget`. It returns null when the
layer does not support rasterisation (a platform view); the stage then
crossfades for the rest of that run (`_unrasterizable`, reset at rest).

`bakeBlurs(near, far)` then makes two blurred copies from the sharp image,
each one `drawImageRect` with `ImageFilter.blur` (edge-clamped tile mode)
into a `Picture` rasterised with `toImageSync`:

- *near*: blurred by `min(waveNearBlur, spec.blur)`, at one pixel per logical
  pixel;
- *far*: blurred by `spec.blur`, at half a pixel per logical pixel.

They are baked on the first frame that has blur to show
(`frame.energy > 0 && spec.blur > 0`) and kept with that picture
(`hasBlurs`); a new picture bakes them again. With `blur: 0` they are never
baked and the shader reads the sharp image in their slots.

Each side sits under a `RenderWaveSide`, which overrides `markNeedsPaint`: a
repaint anywhere below that is not caught by a repaint boundary passes
through it on its way up and flags the side (`RenderWaveStage.sideChanged`),
and the next frame that needs the side takes a new picture. The wave's own
animation repaints only the stage, so it never triggers one. Content inside
a nested `RepaintBoundary` repaints without passing through, which is what
`WaveSnapshots.everyFrame` is for: it re-takes (and re-bakes) every shown
side on every `distorting` frame.

Pictures are released (`_release`) whenever a frame is not `distorting`, when
a side stops showing, when the device pixel ratio changes, and on
`detach`/`dispose`.

### `wave.frag`

Per pixel, in the stage's logical coordinates (see the shader's header):

1. **The field** (`common/wave_field.glsl`): the signed distance `d` to the
   front, divided by the gradient of the squashed metric so it stays a
   distance, plus a slow bend along the front. Every other part reads `d`, so
   the swell, the blur and the colour can never drift apart.
2. **The lens:** one rise per pixel as the swell passes (steeper ahead, long
   behind), along the field's normal, plus the pull toward the source before
   the launch. The held source of the center wave is left alone.
3. **The blur:** the radius this content should have — gathering ahead of
   the front, peaking on it, clearing slowly behind — evaluated with the
   field moved along with the content, then turned into the coverage of the
   near and far copies. Sharp → near → far: the reference's stacked blurred
   copies, mixed in one pass.
4. **The crossfade:** ahead of the front the outgoing side covers the
   incoming one, with a zone either side of the front where they fade.
5. **Colour fringing:** the colours part along the way a pixel has moved, in
   proportion to how far, over five taps across the spectrum; anything that
   moved less than a quarter of a point takes one tap and stays clean.
6. **The colour** (`common/wave_colour.glsl`), over the content: the band on
   the front (the palette flowing along it in OKLab, the `ahead` fringe in
   front of it, the `behind` fringe after it, a near-white core) and the rim
   and hairline on the view's edges, which follow the shared `outline()` —
   Flutter's rounded superellipse, each corner with its own radius — and its
   arc length. The rim's lumps arrive as uniforms, computed once a frame by
   `WaveRim.lumps`.

`wave_glow.frag` is step 6 alone, for the `glowing` phase.

### The edges' corners

`RenderWaveStage._corners`: when the widget passed the display's radii
(`MediaQuery.maybeDisplayCornerRadiiOf`, only when no style or theme sets
`WaveGlow.cornerRadius`) and the stage fills the view (global origin and
`MediaQuery.sizeOf` size, within half a pixel), each corner takes the
display's radius; otherwise all four take `spec.cornerRadius`. The stage
builds a `BeamOutline` (superellipse) from those radii, cached until the
size or corners change, and writes its radii, perimeter and quadrant starts
into the uniforms. The largest radius goes into `uBand.w`, bounding where the
edge colour can reach.

### The uniform block

`shaders/common/wave_uniforms.glsl` declares the float uniforms once; both
shaders include it, and `WaveFrameData` (`render/wave_frame_data.dart`)
writes them in that order, all `vec4`s:

| Uniform | Contents | Writer |
| --- | --- | --- |
| `uRect` | the stage in the canvas: left, top, width, height | `setStage` |
| `uView` | px per device px, dither, outline perimeter | `setStage` |
| `uQuads` | arc length where each quadrant starts | `setStage` |
| `uFront0`–`uFront4` | the front, time, strengths, wipes, ring/hold, which sides show | `setFrame` |
| `uLens`, `uBlur`, `uBand`, `uRim`, `uHair` | the settled style: lens, blur levels (near, far), band (+ largest corner), rim, hairline (+ palette colour count) | `setSpec` |
| `uStops[8]` | palette colours in OKLab, cycled to fill `wavePaletteSlots` | `setSpec` |
| `uFringe[2]` | the `ahead` and `behind` fringes in OKLab | `setSpec` |
| `uLumps[7]` | the rim's lumps (`WaveRim.count`) | `setLumps` |
| `uRadii` | corner radii TL, TR, BR, BL | `setStage` |

That is 31 `vec4`s, **124 floats** — `waveUniformFloats`. `wave.frag` then
declares its six samplers, in the order the renderer binds them: the
outgoing side's sharp, near and far images, then the incoming side's.
`setStage` and `setSpec` are rewritten only when the stage or the spec
changes; `setFrame` and `setLumps` every frame. `upload` writes all 124
floats.

`test/distortion_wave/render/wave_uniform_layout_test.dart` (through
`test/support/shader_source.dart`, which inlines `#include`s) checks that
both shaders declare the same block, that every float uniform is a `vec4` or
`vec4` array, that the arrays hold what `WaveFrameData` packs, that the
shaders' loops visit every slot, that the total equals `waveUniformFloats`
(and fits the 224 `vec4`s GLES 3.0 guarantees), that each writer lands in the
uniform declared at its offset, and the six samplers' order.

## The dots

`DotAtlas` draws every visible dot in one `drawRawAtlas`: one anti-aliased
white disc sprite, scaled per dot and modulated by its opacity. The sprite is
rendered once per diameter in device pixels and kept until the diameter
changes. **Each `RenderWaveStage` owns its `DotAtlas` and disposes it in
`dispose()`**, so no image outlives its wave. Dot positions come from
`WaveParticle.all(spec)` (cached for the last few specs) evaluated on the frame.

## Anchors and sources

Every `DistortionWave` owns one `WaveAnchorRegistry` and wraps **each side
in its own `WaveAnchorScope`** (`onRevealedSide` true for the incoming side,
false for the outgoing). An anchor registers on `didChangeDependencies` with
its side, and reports `pressed` on pointer-down and when focus lands inside
it (keyboard focus also clears its `lastTouch`). `sourceFor(revealedOnScreen:)`
picks: last pressed if on the side on screen → the only anchor on that side
→ last pressed anywhere → none. The wave's state calls it only when a run
starts from rest (`_sourceForRun`), so the source never changes mid-wave.
`DistortionWaveRoute` wraps its stage in a registry of its own, made once
per route, so anchors in a route's page never register with an enclosing
wave. The rules as a user sees
them: [distortion_wave_usage.md](distortion_wave_usage.md#where-the-wave-opens-from).

`RenderWaveStage` resolves its source lazily (`_origin`) and keeps the
result until the source changes (by `==`), the type changes, or — for the
default spot only — the stage is laid out again.

## Touches, focus, semantics, warm-up

- **Touches** (`_touchable`): the side at rest; while running, none, except
  the revealed side once a reveal reaches `contentAtRest` (never while
  crossfading).
- **Focus**: the widget wraps the side off screen — `child` at progress 1,
  `revealedChild` at progress 0, at rest or held there — in `ExcludeFocus`.
- **Tickers**: at rest the hidden side is under `TickerMode(enabled: false)`;
  with `maintainState: false` it is not built at all.
- **Semantics** (`visitChildrenForSemantics`): the side at rest, or the side
  the wave is heading for (`revealing`).
- **Warm-up**: `DistortionWave.precache()` awaits `loadWavePrograms()` and
  then `warmUpWaveRendering()` draws both shaders, a blurred bake and an
  atlas once into a 4 × 4 image, so the GPU builds those pipelines before the
  first wave rather than on its first frames.

## The route

`DistortionWaveRoute` drives the same `WaveStage` from its animation. The
incoming side is the new page; the outgoing side is a `RawImage` of the page
underneath, pictured from that route's own page `RepaintBoundary`
(`subtreeContext`'s render object) with `toImageSync` in a post-frame
callback after the push's first frame — until then the outgoing side is
empty, so the page underneath shows through and nothing jumps — and again
after a pop starts. The old image is disposed when replaced and in
`dispose()`. A page whose layer does not support rasterisation (a platform
view) is not pictured: the transition then gives the stage no outgoing side
and `plain: true`, so the new page fades in over the live page underneath,
and out on pop. `canTransitionFrom` is false, so the page underneath plays no
exit transition of its own behind the wave.

The route's `CurvedAnimation` (linear forward, `spec.easing.flipped` in
reverse) is **made once** — `buildTransitions` runs every frame, and a curve
made there would add a listener to the route's animation each time — and
disposed with the route; it is remade only if the parent animation changes.
`spec` is resolved once, lazily, against `DistortionWaveTheme.of` the
navigator's context. Durations: `spec.duration` / `spec.returnDuration`, or
300 ms each under reduced motion.

## Invariants

- **Distortion window: one shader `drawRect` and at most one `drawRawAtlas`
  per frame** on the stage's canvas, with no `saveLayer`, clip, filter or
  image draw; at rest, the visible side and nothing else; glowing, the
  revealed side plus one `drawRect` and at most one atlas.
  `test/distortion_wave/render/wave_frame_budget_test.dart` asserts this per
  phase × type.
- **A side is pictured only when its content changed** (or every frame under
  `everyFrame`), and released when the phase leaves `distorting`. The
  snapshot-count tests in the same file and the lifecycle test pin both.
- **The uniform block and `WaveFrameData` change together**, in one commit.
- **`WaveFrame` is pure**: a function of progress, source, size, spec and
  focus. Tickers and images live in the clock and the stage.
- **The shaders are SkSL strict ES2** (constant loop bounds, arrays indexed by
  constants or loop indices), so they run on Skia and the web too.
- **Never `ImageFilter.shader` or `BackdropFilter`** for the wave: they are
  Impeller-only, need a new filter object every frame, and hit open engine
  bugs (flutter#185175, #187820).

## Calibration

The look is the reference's: its timeline, field, colour model, palettes and
tuned styles. The port was checked by building the reference
(DistortionWavesKit) into a throwaway SwiftUI harness, rendering it with
`ImageRenderer` at fixed progress (`scrub:`) over mock screens, rendering the
Flutter wave at the same progress over the same screens, and comparing pixel
by pixel. The harness is built with `xcodebuild`, which needs the Metal
Toolchain. The goldens in `test/distortion_wave/golden/` pin those scenes.
When retuning `wave_defaults.dart`, repeat the comparison at the golden
scenes' progress values, then regenerate only the affected goldens.

## Tests

| Path | Covers |
| --- | --- |
| `test/distortion_wave/models/` | Value objects (`copyWith`, `merge`, `==`, ranges asserted), `WaveSpec.resolve` (precedence, per-type defaults, release-mode settling, durations), palettes. |
| `test/distortion_wave/timeline/` | `WaveFrame`, ported case for case from the reference's `WaveFrontTests`, plus a seeded property sweep; particles, rim, clock. |
| `test/distortion_wave/render/` | Uniform layout of both shaders, the frame budget per phase × type and the snapshot counts (`wave_frame_budget_test.dart`), where pixels land in real frames (`wave_paint_structure_test.dart`). |
| `test/distortion_wave/widget/` | Behaviour (sources, anchors, focus, touches, controller, theme, holding, display corners), lifecycle, the route. Helpers in `wave_test_utils.dart`. `distortion_wave_lifecycle_test.dart` and `distortion_wave_route_test.dart` call `LeakTesting.enable()` (`leak_tracker_flutter_testing`, a dev dependency), so an object Flutter's leak tracker instruments — an image, a `ChangeNotifier`, a `CurvedAnimation` — that is created and never disposed fails them. |
| `test/distortion_wave/golden/` | `wave_golden_test.dart`: each type at its telling moments, palettes, mixed display corners; scenes held with `progress:`. |
