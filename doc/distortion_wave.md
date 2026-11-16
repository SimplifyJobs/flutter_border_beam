# DistortionWave

How a distortion wave is built, from its timeline to the one draw a frame
takes. For using it, see the [README](../README.md#distortionwave); for the
border beam's renderer, [architecture.md](architecture.md).

Three ideas carry it:

1. **Everything is a pure function of one progress value.** `WaveFrame.at`
   turns progress (0–1 over the wave's whole life), the source, the view's
   size and the settled style into every number the frame needs. Nothing is
   integrated frame to frame, which is what lets the wave scrub, reverse
   mid-way, run off a route's animation, and freeze for a golden.
2. **The views are drawn from pictures of themselves.** While the wave bends
   content, each view is rasterised to a GPU image and one fragment shader
   draws the frame from the images. Nothing is drawn through a layer, a
   `BackdropFilter` or an `ImageFilter`.
3. **A picture is taken only when it is needed.** Once when the wave first
   needs a view, and again only when that view's content repaints; released
   as soon as the content no longer bends.

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
   from the source's centre, and leaves the source itself alone.
3. **Travel.** The front crosses the view on the wave's easing (fast out of
   the source, settling softly). The swell, blur and colour on the front die
   away over the middle part of the travel, while the front still moves.
4. **Edges.** The colour the band left on the view's edges clings there,
   uneven and drifting, with a hairline on the glass; a second, later front
   wipes the colour away, and a third, later still, the hairline.

`WaveFrame` reports which sides show (`showsOutgoing` until the front has
crossed the whole view, `showsIncoming` once it has launched) and whether
the content is bent at all (`bendsContent`). `WaveParticle` and `WaveRim`
are pure in the same way.

A reveal runs linearly over the whole duration; a collapse runs back on the
wave's easing, `returnSpeed` times faster, quick through the end of the
wave's life where little is on screen. `WaveClock` (or a route's animation)
drives progress; flipping mid-run turns back from wherever the wave is.

## The frame

```text
WaveClock or route animation
  └─► RenderWaveStage.paint
        ├─ WaveFrame.at(progress, source, size, spec, focus)
        ├─ phase: rest │ distorting │ glowing │ crossfading
        ├─ WaveSideImages for each side shown (taken or reused)
        ├─ WaveFrameData ─► wave.frag ─► one drawRect
        └─ DotAtlas ─► one drawRawAtlas
```

| Phase | When | Draws |
| --- | --- | --- |
| `rest` | progress 0 or 1 | the visible side, as itself |
| `distorting` | the wave bends content, or the outgoing side still shows | both sides' images through `wave.frag`, and the dots |
| `glowing` | the front has crossed and bends nothing | the revealed side as itself, `wave_glow.frag` over it, and the dots |
| `crossfading` | reduced motion, or a side that cannot be rasterised | the outgoing side fading out over the incoming one |

### Pictures of the sides

`WaveSideImages.take` paints a side into a detached `OffsetLayer` and
rasterises it with `toImageSync` at the device pixel ratio — the technique of
Flutter's `SnapshotWidget`, which the zoom page transition uses. It then bakes
two blurred copies from that picture once: *near* (about 7 pt of blur, at one
pixel per logical pixel) and *far* (the style's full blur, at half that).

Each side sits under a `RenderWaveSide`, which overrides `markNeedsPaint`: a
repaint anywhere below that is not caught by a repaint boundary passes
through it on its way up and flags the side, and the next frame that needs
the side takes a new picture. The wave's own animation repaints only the
stage, so it never triggers one. Content inside a nested `RepaintBoundary`
repaints without passing through, which is what `WaveSnapshots.everyFrame`
is for.

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
   the front (the palette flowing along it in OKLab, a warm fringe ahead, a
   cool one behind, a near-white core) and the rim and hairline on the
   view's edges, which follow the shared `outline()` — Flutter's rounded
   superellipse — and its arc length. The rim's lumps arrive as uniforms,
   computed once a frame by `WaveRim`.

`wave_glow.frag` is step 6 alone, for the `glowing` phase.

### The uniform block

`shaders/common/wave_uniforms.glsl` declares the float uniforms once; both
shaders include it, and `WaveFrameData` writes them in that order:
the stage (rect, pixel size, outline perimeter and quadrant starts), the
frame (front, strengths, wipes, which sides show), the settled style (lens,
blur levels, band, rim, hairline), the palette (eight OKLab slots, cycled to
fill, and the two fringes) and the rim's seven lumps — 120 floats in vec4s.
`wave.frag` then declares its six samplers: the outgoing side's sharp, near
and far images, then the incoming side's.

## Touches, semantics, warm-up

While the wave bends the views, neither takes a touch. Once a reveal no
longer bends the revealed side (the `glowing` phase), that side takes
touches again, so its controls answer while the colour lingers. The
semantics tree shows the side at rest, or the side the wave is heading for.

`DistortionWave.precache()` loads both programs and then draws everything a
wave draws — both shaders, a blurred bake, an atlas — once into a 4 × 4
offscreen image (`render/wave_warm_up.dart`), so the GPU builds those
pipelines before the first wave rather than on its first frames.

## The route

`DistortionWaveRoute` drives the same `WaveStage` from its animation. The
incoming side is the new page; the outgoing side is a picture of the page
underneath, taken from that route's own page `RepaintBoundary` once the
push's first frame has painted it — until then the stage draws nothing over
it, so nothing jumps — and again as a pop starts. `canTransitionFrom` is
false, so the page underneath plays no exit transition of its own behind the
wave.

## Invariants

- **Distortion window: one shader `drawRect` and at most one `drawRawAtlas`
  per frame**, with no layer, clip, filter or image draw; at rest, the visible
  side and nothing else.
- **A side is pictured only when its content changed** (or every frame, when
  asked), and released when it stops being needed.
- **The uniform block and `WaveFrameData` change together.**
- **`WaveFrame` is pure.**
- **The shaders are SkSL strict ES2**, so they run on Skia and the web too.

## Calibration

The look is the reference's: its timeline, field, colour model, palettes and
tuned styles. The port was checked by building the reference
(DistortionWavesKit) into a throwaway SwiftUI harness, rendering it with
`ImageRenderer` at fixed progress over mock screens, rendering the Flutter
wave at the same progress over the same screens, and comparing pixel by
pixel. The goldens in `test/distortion_wave/golden/` pin those scenes. When
retuning, repeat the comparison at the golden scenes' progress values.

## Tests

- `test/distortion_wave/timeline/` — the timeline, ported case for case from
  the reference's tests, plus a seeded property sweep.
- `test/distortion_wave/render/` — the uniform layout of both shaders, the
  frame budget per phase and type, the snapshot counts, and where pixels land
  in real frames.
- `test/distortion_wave/widget/` — behaviour, lifecycle and the route.
- `test/distortion_wave/golden/` — the pinned look.
