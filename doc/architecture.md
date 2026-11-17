# Architecture — BorderBeam internals

This document covers the border beam's renderer; for using it, see
[border_beam_usage.md](border_beam_usage.md). The distortion wave has its
own: **[distortion_wave.md](distortion_wave.md)**. Code both share lives in
`lib/src/core/` (`ShaderProgram`) and `shaders/common/` (`outline.glsl`,
the rounded-superellipse outline every shader includes). `lib/src/core/`
also holds `Oklab`, which only the wave uses so far.

Two ideas carry the border beam:

1. **Everything animated is a pure function of elapsed time.** One `Ticker` produces a number of seconds; every visual value is recomputed from it each frame. There are no `AnimationController`s and no per-track state to keep in step, which is what makes goldens, property tests, and `BeamPlayback.debugFrozenAt` possible.
2. **Every frame is one shader draw.** An effect writes the layers of its look — blob tables, conic windows, masks, colour filters — into one uniform buffer; one fragment shader evaluates every layer per pixel and composites them in a single pass, with no offscreen layers, blurs, or clips.

## The frame

```text
Ticker ─► BeamClock ─► BeamPhaseResolver ─► effect emitter ─► BeamFrameData ─► BeamRenderer ─► one draw
          elapsed s     BeamFramePhases      _rotate, _line…    3 layers: blobs,   uploads the floats, drawRect or
          speed, fade   sweep, hue,          (pure functions)   windows, masks,    picks the bounds    drawDRRect with
          pause, boost  travellers, cycles                      filters, tables    of the light        shaders/beam.frag
```

1. **`BeamClock`** (`lib/src/border_beam/animation/beam_clock.dart`) owns the ticker. It keeps two times: the speed-scaled animation timeline every phase is sampled from, and unscaled active time — real seconds while it ticks. The fade-in and fade-out (critically damped springs, `BeamSpringCurve.fadeIn` / `fadeOut`, settling in `BeamClock.fadeInSeconds` / `fadeOutSeconds`), the one-shot `pulse()` / `flash()` boosts, and `playback.duration` run on active time, so `speed`, seek, and retime move the animation without stretching, skipping, or replaying a fade; pause freezes both. It is a `Listenable` and notifies on every frame the engine produces — there is no frame-rate cap. Under a `BeamSync` one clock serves the whole subtree.
2. **`BeamPhaseResolver`** (`lib/src/border_beam/animation/beam_phases.dart`) samples a `BeamFramePhases` for a time: the fade (including a cycle gap's envelope), the hue rotation and the time the hue track reads, the travel position of every traveller (`travellers`, spaced `1 / count` apart), whether this cycle runs mirrored, the continuous `cycles` clock the breathing runs on (the pulse, the line's spikes), and whether a `progress` / `follow` value is driving the travel. Pure — the same time in gives the same phases out. It knows nothing about what an effect looks like.
3. **The effect emitter** (`lib/src/border_beam/effects/effect_emitters.dart`) is a switch over the sealed `BeamEffect`. Each effect is a function of the resolved `BeamConfig`, the phases, the `BeamOutline`, and the palette's blob tables (`BeamLook.tablesFor`), and writes its layers into a `BeamFrameData`. The time-driven design values — the line's width, height, spike, and edge-fade keyframes, the pulse's 17 oscillators — are sampled here, on the CPU, once per frame.
4. **`BeamFrameData`** (`lib/src/border_beam/render/beam_frame.dart`) is the frame as the shader consumes it: the outline, the visible track, the conic coordinate, four conic tables, and three layers, each with a geometry, a window, an edge fade, an inset shadow, an overlay, a colour filter, an opacity, and a stack of blobs. It is one `Float32List` laid out exactly like the shader's uniform block, reset and rewritten in place every frame.
5. **`BeamRenderer`** (`lib/src/border_beam/render/beam_renderer.dart`) owns one `FragmentShader`, one `Paint`, and one `BeamFrameData` per beam. Per frame it writes the outline and track, runs the emitter, folds each layer's colour filter into its colours, uploads the floats, works out where light can land, and issues a single `drawRect` or `drawDRRect` — or nothing, when no layer is lit.

`BeamPainter` (`lib/src/border_beam/render/beam_painter.dart`) is the `CustomPainter` that runs this as `BorderBeam`'s foreground painter. Its repaint listenable is the clock merged with the shader-ready signal and the driven `progress` / `strength` listenables, so frames never rebuild widgets. `BeamDecoration` runs the same renderer from a `BoxPainter`.

`beamProgram` (`lib/src/border_beam/render/beam_program.dart`, a `ShaderProgram` from `lib/src/core/shader_program.dart`) loads `shaders/beam.frag` once per process (`FragmentProgram.fromAsset`, trying the `packages/prismatic/` key a consuming app uses and the bare key the package's own tests use). Until it resolves, beams paint nothing; `BorderBeam.precache()` awaits it.

## The layer model

The look is the reference design's own construction, evaluated per pixel. A beam is up to three layers, composited bottom to top, and every effect uses the same three: layer 0 is the inner glow, layer 1 the 1px stroke, and layer 2 the bloom.

A layer is:

- **A stack of blobs** — soft radial ellipses, each with a centre, two radii, a straight colour, and a piecewise-linear alpha falloff (`a0` at the centre through two mid stops to 0 at the rim). They composite premultiplied source-over in painting order, each over the ones before. A blob is placed in the plane, or in **path space** (arc length along the outline × depth in), where a streak bends around a corner with the border.
- **An overlay** — a conic table drawn in white or black under the blobs: the travelling beam's head highlight, the bloom band.
- **An inset shadow** — solid to a depth inside the outline, then blurred.
- **A geometry** — the 1px **ring** just inside the outline (anti-aliased over one device pixel, which is what keeps it a hairline), the **filled** shape, a **blurred ring** clipped to the shape, or a **glow** outside the shape that fades out (the shape grown by a reach and blurred — rotate's comet). The glow is the only geometry that paints outside the outline.
- **A window** — a **conic** table (rotating with the beam: `tw = fract(angle − start)`, repeated `count` times round the turn) or a **radial** ellipse riding an edge.
- **An edge fade** — opaque at the edge, fading to transparent a short depth in (the two axes screened), or by depth in path space. `BeamStyle.glow` deepens it, capped so a small box keeps a clear middle.
- **A colour filter** — CSS `hue-rotate → brightness → saturate` as a 3 × 3 matrix. The renderer always folds it into each colour of the layer on the CPU — every blob, the overlay ink, the shadow — before compositing, which keeps overlapping colours saturated; the layer's matrix in the shader stays the identity.
- **An opacity** — the family preset × fade × strength × the mono halving × `glow` (up to 1, on the glow layers), clamped to 1.

### The outline

The outline is a rectangle with four independently sized corners. A corner is either a circular arc or a superellipse ("squircle") curve. The superellipse follows Flutter's own `RSuperellipse` construction (`impeller/geometry/round_superellipse_param`): each corner is two halves meeting on its diagonal, and each half is a superellipse from the middle of its edge to a joint, then a circular arc to the diagonal, with the exponent and joint looked up from the ratio of the edge's half-length to the radius. That ratio is why one shape spans cards, pills, and circles — a 56 px pill's ends come out as exact semicircles while its long edges ease in over a much longer run — and it keeps the stroke on the edge of a child clipped by `RoundedSuperellipseBorder` to within Flutter's own path approximation. The shader derives each corner's parameters from the radii and box per pixel, only near a corner. Uneven radii keep each corner to its own quarter of the box rather than Flutter's proportional split, which is exact in ordinary use and drifts by about 2% of the radius only where a half-short-side corner meets a square one across that side.

For every pixel the shader derives the signed distance `d` to the outline (negative inside), the arc length `s` from top-centre clockwise (`u = s / length`), and the outward normal of the nearest piece. Distance in a corner is the first-order estimate `R · f / |∇f|` (exact for a circle); deep inside a superellipse corner it blends toward the circular distance. `u` is continuous on and outside a convex outline, but inside the shape the nearest piece jumps across the medial axis — so the glows that reach inside are planar blobs, or path-space blobs that stay within the edge fade, never fields of `u`.

### Blurs, analytically

The reference design blurs three things; each becomes closed-form maths:

- **A blurred 1px ring** (the rotate bloom, the pulse bloom) is the ring's width times the normal density across it: `w / σ · φ(d_c / σ)` with `d_c` the distance to the ring's centre line, clipped to the shape. Its colour comes from the bloom's conic table — pre-blurred around the turn on the CPU — or from blobs sampled where the ring is, not where the light spread to.
- **A blurred blob** (the line's spikes and dot) is the energy-preserving gaussian of the blob plus the blur: the profile's mass and variance are integrated on the CPU (`σ² = r² · m₂ / 2m₀ + blur²`, peak `= mass / (σx · σy)`). Where the design cuts a blob at an edge before blurring it (the line's bloom stops at the box), the gaussian is truncated there and moment-matched, so light below the edge never spills back in.
- **A blurred glow outside the shape** (the comet) is a smooth step across the outline grown by its reach: `Φ((reach − d) / σ)`.

### Compositing and the draw

Layers composite source-over, premultiplied, then the visible track (the segment mask, feathered more the further light is from the stroke) multiplies the result; a layer marked dashed is cut into dashes first. A small interleaved-gradient dither on the soft tails keeps 8-bit targets from banding.

The renderer bounds the draw to where light can land: the box grown by the furthest outward reach (the comet's reach plus three sigmas of its blur), minus the interior beyond the furthest inward reach (the edge fade, the blurred ring's three sigmas). That ring is one `drawDRRect`; when a layer fills the whole box (the line's bloom) it is one `drawRect`.

## The design data

`lib/src/border_beam/look/` holds the tuned values the look is built from — plain data, safe to retune (the goldens will move):

| File | Contents |
| --- | --- |
| `palette_tables.dart` | `BeamLookTables` and the tables of the four original palettes: 9 border blobs, 8 + 8 compact-chip blobs, the line's 9 + 9 + 9 streak blobs, its spike colours and 5 bloom spike pairs. |
| `extra_palettes.dart` | The seven extras' colour lists, cycled over `colorful`'s tables. |
| `beam_look.dart` | `BeamLook.tablesFor(palette)`: a palette's own tables, the extras' cycled ones, or — for every other palette — `colorful`'s geometry recoloured by sampling the palette's stops where each blob sits. Memoized per palette. |
| `layer_presets.dart` | Per family (rotate, compact chip, line, pulse) and surface: the three layer opacities, the inset shadow colour, brightness, saturation. |
| `rotate_look.dart` | The rotate window, the compact window, the head highlight and bloom band tables; the inner blob alpha and scale; blurs; the 56 px compact threshold. |
| `line_look.dart` | The line's keyframes (travel x and width, edge fade, height, two spike tracks) and its window, highlight, spike, dot, ambient, and shadow geometry. |
| `pulse_tables.dart`, `pulse_look.dart` | The pulse's blob tables (ring map, inner sizes, bloom), the breathing parameters, the 17-oscillator bank, and the breath the corner opacities follow (a quicker swell than fade). |

## Mirrors between Dart and the shader

Some of the shader's maths runs on the CPU too, and the two copies must agree exactly.

**`BeamOutline`** (`lib/src/border_beam/render/beam_outline.dart`) is the Dart mirror of the shaders' `outline()` in `shaders/common/outline.glsl`, which every shader includes. `locate()` returns the same `(d, u)` the GPU computes, including the nearest-piece choice; `pointAt` / `normalAt` invert it. Emitters lay blobs along the outline with it, `BeamSegment` anchors resolve against it, and `BorderBeam.follow` maps a pointer to the border with it. The renderer packs its `radii`, its corner model (circular or superellipse), `length`, and `quadStarts` straight into the shader, so a change to the corner model goes in both places at once. A test renders the real shader at 3× and checks its distance against `locate()` pixel by pixel.

**Conic tables.** `BeamFrameData.tableAt` reads a table exactly as the shader's `TABLE_LOOKUP` does; tests read windows and overlays back through it.

**The uniform layout.** The shader declares only `vec4`s and `vec4` arrays, so the float layout is identical on every backend (Impeller on Metal, Vulkan, and GLES, and Skia). `BeamFrameData` writes floats by index in declaration order:

| # | Uniform | Floats |
| --- | --- | --- |
| 1 | `uRect` — box left, top, width, height | 4 |
| 2 | `uRadii` — corner radii TL, TR, BR, BL | 4 |
| 3 | `uShape` — corner model (0 circular, 1 superellipse), unused, stroke width, px per device px | 4 |
| 4 | `uPerim` — perimeter length, unused, dither | 4 |
| 5 | `uQuads` — arc length at which each quadrant starts | 4 |
| 6 | `uMask` — track start, span, feather, dashes | 4 |
| 7 | `uConic` — conic centre, start angle (turns), repeats | 4 |
| 8 | `uLayer[27]` — 9 vec4s per layer: geometry, window and overlay, window parameters, blob mode and count, shadow colour, shadow and dash flags, colour matrix rows | 108 |
| 9–12 | `uWinA[8]`, `uWinB[8]`, `uOverA[8]`, `uOverB[8]` — conic tables, 16 (position, alpha) stops each | 4 × 32 |
| 13–15 | `uBlobA[42]`, `uBlobB[30]`, `uBlobC[30]` — 14, 10, and 10 blobs, three vec4s each | 408 |

That is 672 floats, `beamUniformFloats` — inside the 896 (224 `vec4`s) GLES 3.0 guarantees. `test/border_beam/render/uniform_layout_test.dart` parses `shaders/beam.frag` and checks that every uniform is a `vec4` or `vec4` array, that each array holds what `BeamFrameData` packs (`beamLayerCount`, `tableStops`, the blob slots), that the shader's loops run to the slot counts, and that the declared floats add up to `beamUniformFloats`. It also checks the *order*: it derives each uniform's offset from the shader's declarations and runs every `BeamFrameData` writer on a fresh frame, so a uniform reordered on one side only — which would otherwise shift every value after it and paint garbage rather than fail — breaks the test. Change the shader's declarations and `beam_frame.dart`'s offsets in one commit.

## Module layout

### Public entry points

| File | Contents |
| --- | --- |
| `lib/prismatic.dart`, `lib/border_beam.dart` | `prismatic.dart` is the package barrel and re-exports `border_beam.dart` and `distortion_wave.dart`. `border_beam.dart` exports `BorderBeam`, `BorderBeamController`, `BorderBeamTheme` / `BorderBeamThemeData`, `BeamSync`, `BeamEffect` and its three subclasses (`RotateEffect`, `LineEffect`, `PulseEffect`), `BeamColors` / `BeamSeedHarmony`, the option types (`BeamDirection`, `BeamEdge`, `BeamHueMode`, `BeamReducedMotion`, `BeamRepeat`), `BeamAnchor` / `BeamCorner` / `BeamSegment`, `BeamTheme`, the four value objects, and the four widgets. Nothing under `render/` or `effects/effect_emitters.dart` is public. |
| `lib/src/border_beam/border_beam.dart` | The widget: `BorderBeam` and `BorderBeam.overlay`, the three shorthands (`colors`, `active`, `borderRadius`), the driven inputs (`progress`, `follow`, `strengthListenable`, `speedListenable`), `BorderBeam.precache()`, and all scheduling and lifecycle. A controller attached ⇒ it owns playback. |
| `lib/src/border_beam/border_beam_controller.dart` | `BorderBeamController`, a `ChangeNotifier` over one clock. |
| `lib/src/border_beam/border_beam_theme.dart` | `BorderBeamTheme` (an `InheritedWidget`) and `BorderBeamThemeData`, with an `effect` slot and one per value object. `of` walks every enclosing scope, depends on each, and merges them outside-in. |
| `lib/src/border_beam/beam_sync.dart` | `BeamSync` and its internal scope — one clock for a subtree. |

### `lib/src/border_beam/effects/`

| File | Contents |
| --- | --- |
| `beam_effect.dart` | The sealed `BeamEffect` and its three `final` subclasses. Each knows its name, whether it travels, and its default cycle, cycle gap, hue mode, and hue period. Value-equal. |
| `effect_emitters.dart` | `emitEffect` and one private emitter per effect; `BeamFrame` (what an emitter reads); `applyTrack` / `segmentTrack` (the visible track); `conicFraction` (the conic angle of a point, shared with `follow`). |

### `lib/src/border_beam/look/`

The design data (see above).

### `lib/src/border_beam/render/`

| File | Contents |
| --- | --- |
| `beam_renderer.dart` | `BeamRenderer`: per-beam shader, `Paint`, and frame data; the upload; the draw bounds. |
| `beam_frame.dart` | `BeamFrameData` — the uniform buffer and its writers — the layer, window, table, and blob-space enums, `beamUniformFloats`, and the slot counts. |
| `beam_outline.dart` | `BeamOutline`, the Dart mirror of the shader's outline, including the port of Flutter's `RSuperellipse` construction (`squircleReach`). |
| `beam_painter.dart` | `BeamPainter`, the `CustomPainter`. |
| `beam_program.dart` | `beamProgram`, the beam's shared `ShaderProgram`. |
| `color_math.dart` | `mixColor`, `samplePalette` — gamma-aware palette blending on the CPU (stops, lerps, derived blob tables). The shader never blends palette stops; blobs arrive coloured. |

### `shaders/beam.frag`

The layer model, per pixel. Its header describes it; its uniform block is the contract above. It is declared under `flutter: shaders:` in `pubspec.yaml` and must ship in the published archive.

### `lib/src/border_beam/models/`

The four public value objects (`beam_style.dart`, `beam_shape.dart`, `beam_timing.dart`, `beam_playback.dart`) are all-nullable, `const`, with `copyWith` / `merge` / `==`; a null field means *inherit*. `beam_options.dart` holds the option enums and `BeamRepeat`; `beam_segment.dart` holds `BeamAnchor`, `BeamCorner`, and `BeamSegment`.

`beam_colors.dart` is the sealed `BeamColors` hierarchy (preset, stops, solid, seed, lerp, scaled) with a value-keyed LRU memo; `beam_presets.dart` holds the 19 preset palettes; `beam_palette.dart` is the resolved ring of stops (at most `maxPaletteStops`, 8), carrying a preset's own blob tables (or the extras' table colours) and the mono flag. `beam_theme.dart` is the `dark` / `light` / `auto` selector. `model_validation.dart` repeats the constructor assertions at runtime, because assertions vanish in release builds.

`beam_config.dart` is where it lands: `BeamConfig.resolve({effect, palette, brightness, style, shape, timing, textDirection})` settles every inherited value — the effect's default cycle, gap, hue mode, and hue period, the 16px default radius, a fixed-hue palette forcing `BeamHueMode.none` — into one value-equal config, so `BeamPainter.shouldRepaint` compares configs.

### `lib/src/border_beam/animation/`

| File | Contents |
| --- | --- |
| `beam_clock.dart` | The ticker, playback rate, pause / resume / seek / retime, the fade envelopes, and the `pulse` / `flash` boosts — the animation on the speed-scaled timeline, the fades and boosts on unscaled active time. |
| `spring_curve.dart` | `BeamSpringCurve`: springs described as Apple's APIs describe them (damping ratio and response) — the critically damped fade-in and fade-out, and the bouncier rise of the pulse/flash accents. |
| `beam_phases.dart` | `BeamFramePhases` and `BeamPhaseResolver`. |

### `lib/src/border_beam/widgets/`

`beam_decoration.dart` (the renderer as a `Decoration`), `beam_focus_ring.dart`, `beam_hover.dart`, `beam_press.dart`.

## Invariants

**One draw per lit frame, and nothing that forces an offscreen pass.** A frame issues exactly one `drawRect` or `drawDRRect` with the beam shader — or none, when the fade or a cycle gap leaves no layer lit — and no `saveLayer`, no clip, no `ImageFilter`, no `MaskFilter`, with saves and restores balanced. `test/border_beam/render/frame_budget_test.dart` asserts this for every effect × theme × palette subset × shape family × several instants, plus effect options and driven progress. A blur in the design becomes analytic maths in the shader, never a layer.

**The uniform contract moves as one.** The shader's uniform block and `beam_frame.dart`'s offsets and slot counts change in the same commit (see above).

**`BeamOutline` mirrors `outline()` exactly.** A change to corner geometry or to how `u` is measured is made in both, or blobs land off the stroke and segments resolve to the wrong place.

**Fixed slots.** Layer 0 holds 14 blobs, layers 1 and 2 hold 10 each, and a conic table 16 stops; `addBlob` drops anything past a layer's slots. The pulse's inner glow (9 blobs + 4 corner accents) is the fullest layer.

**Nothing inside the shape reads `u`.** Inside the shape `u` jumps across the medial axis; inner glows are planar blobs, or path-space blobs kept within the edge fade. Blobs laid along the outline (`_onOutline`) are planar ellipses whose axes follow the normal, so they stay seamless through a corner.

**Emitters are pure and allocation-light.** An emitter is a function of the config, the phases, the outline, and the palette's tables; it writes into the renderer's reused `BeamFrameData` and builds no buffers per frame (table transforms use scratch lists; the oscillator banks are cached per tuning; derived tables are memoized per palette).

**Speed never reaches `BeamConfig`.** It is applied to the clock and kept out of the config cache key, so a rate change does not re-resolve the config or rebuild the phase resolver.

## Tests

| Directory | Covers |
| --- | --- |
| `test/border_beam/models/` | The value objects, `BeamConfig.resolve`, `BeamColors` and palettes, `BeamEffect`, segments. |
| `test/border_beam/animation/` | The clock, the spring, phase sampling, travel, and a seeded property test over `BeamPhaseResolver.sample`. |
| `test/border_beam/render/` | The frame budget, the uniform layout, `BeamOutline`, `BeamFrameData` sanity and structure per effect (`beam_frame_test.dart`), degenerate geometry, a paint smoke sweep through the real shader, and where light lands (`paint_structure_test.dart`). |
| `test/border_beam/widget/` | `BorderBeam` itself: lifecycle, updates, shorthands, theming, sync, speed, progress, follow, motion, playback, cycle gap, shape. |
| `test/border_beam/widgets/` | The four widgets in `lib/src/border_beam/widgets/`. |
| `test/border_beam/golden/` | Five golden families — `beam_`, `palette_`, `motion_`, `surface_`, `widgets_`. |

Golden scenes freeze the fake clock at t = 1.3s (past the fade-in, mid-cycle); travelling effects are captured a second time further along. Goldens are generated on macOS on the Flutter version `ci.yaml` pins; regenerating on another OS or SDK produces diffs.
