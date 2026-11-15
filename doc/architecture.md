# Architecture

Two ideas carry the whole package:

1. **Everything animated is a pure function of elapsed time.** One `Ticker` produces a number of seconds; every visual value is recomputed from it each frame. There are no `AnimationController`s and no per-track state to keep in step, which is what makes goldens, property tests, and `BeamPlayback.debugFrozenAt` possible.
2. **Every frame is one shader draw.** An effect describes where light sits along the border; one fragment shader turns that description into pixels in a single pass, with no offscreen layers, blurs, or clips.

## The frame

```text
Ticker ─► BeamClock ─► BeamPhaseResolver ─► effect emitter ─► BeamEmission ─► BeamRenderer ─► one draw
          elapsed s     BeamFramePhases      _rotate, _line…    bumps, lights,    packs uniforms,     drawRect or
          speed, fade   sweep, hue,          (pure functions)   layer weights,    picks the bounds    drawDRRect with
          pause, boost  travellers, cycles                      colour map        of the light        shaders/beam.frag
```

1. **`BeamClock`** (`lib/src/animation/beam_clock.dart`) owns the ticker. It integrates speed-scaled time, runs the spring-eased fade-in (0.6s) and fade-out (0.5s), handles pause / resume / seek / retime, and carries the one-shot `pulse()` / `flash()` boosts. It is a `Listenable` and notifies on every frame the engine produces — there is no frame-rate cap. Under a `BeamSync` one clock serves the whole subtree.
2. **`BeamPhaseResolver`** (`lib/src/animation/beam_phases.dart`) samples a `BeamFramePhases` for a time: the fade (including a cycle gap's envelope), the hue rotation, the travel position of every traveller (`travellers`, spaced `1 / count` apart), whether this cycle runs mirrored, the continuous `cycles` clock the ambient effects breathe by, and whether a `progress` / `follow` value is driving the travel. Pure — the same time in gives the same phases out. It knows nothing about what an effect looks like.
3. **The effect emitter** (`lib/src/effects/effect_emitters.dart`) is a switch over the sealed `BeamEffect`. Each effect is a function of the resolved `BeamConfig`, the phases, the `BeamOutline`, and this frame's hue-rotated colours, and writes into a `BeamEmission`.
4. **`BeamEmission`** (`lib/src/render/beam_emission.dart`) is the frame as the shader consumes it: up to 8 bumps along the border, up to 8 point lights, layer weights (stroke, bloom, outer halo, lights), the colour mapping, ring noise, the shimmer sweep, and the visible segment. It is a mutable buffer of typed lists that the renderer resets and reuses every frame.
5. **`BeamRenderer`** (`lib/src/render/beam_renderer.dart`) owns one `FragmentShader`, one `Paint`, and one `BeamEmission` per beam. Per frame it hue-rotates the palette's colours (at most 8), runs the emitter, packs every uniform into the shader, works out where light can land, and issues a single `drawRect` or `drawDRRect`.

`BeamPainter` (`lib/src/render/beam_painter.dart`) is the `CustomPainter` that runs this as `BorderBeam`'s foreground painter. Its repaint listenable is the clock merged with the shader-ready signal and the driven `progress` / `strength` listenables, so frames never rebuild widgets. `BeamDecoration` runs the same renderer from a `BoxPainter`.

`BeamProgram` (`lib/src/render/beam_program.dart`) loads `shaders/beam.frag` once per process (`FragmentProgram.fromAsset`, trying the `packages/flutter_border_beam/` key a consuming app uses and the bare key the package's own tests use). Until it resolves, beams paint nothing; `BorderBeam.precache()` awaits it.

## The light model

The shader evaluates every effect from two coordinates it derives per pixel:

- **`d`** — signed distance to the outline in logical px, negative inside.
- **`u`** — position along the perimeter in `[0, 1)`: 0 at top-centre, increasing clockwise, by arc length of the nearest outline piece.

### The outline

The outline is a rectangle with four independently sized corners. A corner is either a circular arc or a superellipse ("squircle") curve. The superellipse is a p-norm curve fitted to Flutter's `RSuperellipse`: the curve spans `k · r` along each edge with `k = 1.42`, exponent `n = 3.04`, and stays within `0.006 · r` of `Path.addRSuperellipse` — so the stroke sits on the edge of a child clipped by `RoundedSuperellipseBorder`. A circular corner is the same code path with `k = 1, n = 2`.

Distance in a corner is the first-order estimate `R · f / |∇f|` (exact for a circle); deep inside a superellipse corner it blends toward the circular distance, where the first-order estimate degrades. Along straight edges `u` is exact; in a corner it is parametrised by angle and scaled to the corner's arc length (`π/2` per unit radius for a circle, measured once for the superellipse). Radii are clamped the way `RRect.scaleRadii` clamps them, and an elliptical radius is reduced to the mean of its two axes.

`u` is continuous on and outside a convex outline, but inside the shape the nearest piece jumps across the medial axis, so `u` has a seam there. That one fact shapes the rest of the model.

### Border light

`colour(u) × emission(u) × profile(d)`, which has no seams because it only matters near and outside the outline:

- **Emission** along the perimeter: a uniform `base`, plus up to 8 **bumps** — each a centre, a lead width (ahead, clockwise), a tail width, and an amplitude, with a smooth falloff and an optional flattened top (`bumpPlateau`). A short lead and a long tail is a travelling comet. Optionally swelled by ring **noise** (sines with whole-number frequencies, so it is seamless round the ring), plus a **shimmer sweep**: a band across the box along a direction, independent of `u`. Multiplied by the **segment mask** (the visible track, feathered at both ends) and the **dash mask**.
- **Profile** across the border: the crisp **stroke** in `d ∈ [-borderWidth, 0]`, anti-aliased analytically over one device pixel; a gaussian **bloom** around the stroke's centre line, limited to the inside, the outside, or both; and an outer **halo** that falls off outside the border, with an optional full-strength plateau and a widening that spreads it along the border as it reaches out, the way a blur would.
- **Colour** from the palette: `cu = (u − origin) · scale`, wrapped (the palette once around the ring) or clamped (the palette spread across one beam, as `line` does). Moving `origin` makes the colours flow. The hottest light whitens on a dark surface and deepens toward its own colour on a light one.

### Point lights

Every glow that reaches *inside* the shape is a **point light**: an anisotropic gaussian anchored on the border, in its own tangent / inward-normal frame, with a sigma along the border, a sigma inward, an amplitude, a colour, and a side (inside, outside, or both). Up to 8 per frame. The emitter places them on the CPU with `BeamOutline.pointAt` / `normalAt` and colours them by sampling the palette where they sit. Because a point light measures distance from its own anchor, it never reads `u`, and so it never shows the medial-axis seam. `halo`'s clouds are point lights pushed outward and limited to the outside.

### Compositing

Border light and point lights are summed premultiplied, scaled by the frame opacity (fade × strength × boost × live strength), and clamped. A small interleaved-gradient dither on the soft tails keeps 8-bit targets from banding. On dark surfaces part of the light is *added* rather than blended: the output alpha is scaled down by an additive share, so the light brightens what is underneath instead of covering it.

### Where the draw goes

The renderer bounds the draw to where light can land: the box grown by the furthest outward reach (bloom on the outside, the halo, outward point lights), minus the interior beyond the furthest inward reach. That ring is one `drawDRRect`; when the inward reach covers the box it is one `drawRect`.

## Mirrors between Dart and the shader

Some of the shader's maths runs on the CPU too, and the two copies must agree exactly.

**`BeamOutline`** (`lib/src/render/beam_outline.dart`) is the Dart mirror of the shader's `outline()`. `locate()` returns the same `(d, u)` the GPU computes, including the nearest-piece choice; `pointAt` / `normalAt` invert it. Emitters use it to place lights, `BeamSegment` anchors resolve against it (`edgeRange`, `cornerRange`, `fractionOfEdge`, `fractionOfCorner`), and `BorderBeam.follow` uses `nearestFraction` to map a pointer to the border. The renderer packs its `radii`, `inset`, `exponent`, `length`, `arcFactor`, and `quadStarts` straight into the shader, so a change to the corner model goes in both places at once.

**Colour maths** (`lib/src/render/color_math.dart`): `mixColor` interpolates squared channels (≈ linear light) and takes the square root, exactly as the shader's `mixColor`; `samplePalette` walks the stops exactly as the shader's `paletteAt`. `BeamPalette.sample`, `BeamColors.lerp`, and the point-light colours all go through them. `hueRotate` is the luminance-preserving hue-rotation matrix, applied on the CPU to at most 8 colours per frame, so the shader never rotates hue per pixel.

**The uniform layout.** The shader declares only `vec4`s and `vec4` arrays, so the float layout is identical on every backend (Impeller on Metal, Vulkan, and GLES, and Skia). `BeamRenderer._pack` writes floats by index in declaration order:

| # | Uniform | Floats |
| --- | --- | --- |
| 1 | `uRect` — box left, top, width, height | 4 |
| 2 | `uRadii` — corner radii TL, TR, BR, BL | 4 |
| 3 | `uShape` — corner inset, exponent, stroke width, px per device px | 4 |
| 4 | `uPerim` — perimeter length, corner arc factor, bloom side, dither | 4 |
| 5 | `uQuads` — arc length at which each quadrant starts | 4 |
| 6 | `uLayers` — stroke, bloom, outer halo, point-light weights | 4 |
| 7 | `uReach` — bloom sigma, outer reach, outer plateau, outer widening | 4 |
| 8 | `uHighlight` — highlight colour, amount | 4 |
| 9 | `uEmit` — base, bump count, opacity, additive share | 4 |
| 10 | `uNoise` — amplitude, frequency, phase, light count | 4 |
| 11 | `uMask` — segment start, span, feather, dashes | 4 |
| 12 | `uColorMap` — origin, scale, wrap, colour count | 4 |
| 13 | `uSweep` — direction, position, half width | 4 |
| 14 | `uExtra` — sweep amplitude, bump plateau, highlight ink | 4 |
| 15–20 | `uBumps[8]`, `uColors[8]`, `uStops[8]`, `uLightPos[8]`, `uLightShape[8]`, `uLightColor[8]` | 6 × 32 |

That is 248 floats, `beamUniformFloats`. The packer asserts it wrote exactly that many, and `test/render/uniform_layout_test.dart` parses `shaders/beam.frag` and checks that every uniform is a `vec4` or `vec4` array, that every array has `beamSlots` (8) entries, and that the declared floats add up to `beamUniformFloats`. The test cannot check the *order*: a uniform reordered on one side only shifts every value after it, and the frame is garbage rather than an error. Change the shader's declarations, `_pack`, and `beamUniformFloats` in one commit.

## Module layout

### Public entry points

| File | Contents |
| --- | --- |
| `lib/flutter_border_beam.dart` | The barrel. It exports `BorderBeam`, `BorderBeamController`, `BorderBeamTheme` / `BorderBeamThemeData`, `BeamSync`, `BeamEffect` and its eight subclasses, `BeamColors` / `BeamSeedHarmony`, the option types (`BeamDirection`, `BeamEdge`, `BeamHueMode`, `BeamReducedMotion`, `BeamRepeat`), `BeamAnchor` / `BeamCorner` / `BeamSegment`, `BeamTheme`, the four value objects, and the four widgets. Nothing under `render/` is public. |
| `lib/src/border_beam.dart` | The widget: `BorderBeam` and `BorderBeam.overlay`, the three shorthands (`colors`, `active`, `borderRadius`), the driven inputs (`progress`, `follow`, `strengthListenable`, `speedListenable`), `BorderBeam.precache()`, and all scheduling and lifecycle. A controller attached ⇒ it owns playback. |
| `lib/src/border_beam_controller.dart` | `BorderBeamController`, a `ChangeNotifier` over one clock. |
| `lib/src/border_beam_theme.dart` | `BorderBeamTheme` (an `InheritedWidget`) and `BorderBeamThemeData`, with an `effect` slot and one per value object. `of` walks every enclosing scope, depends on each, and merges them outside-in. |
| `lib/src/beam_sync.dart` | `BeamSync` and its internal scope — one clock for a subtree. |

### `lib/src/effects/`

| File | Contents |
| --- | --- |
| `beam_effect.dart` | The sealed `BeamEffect` and its eight `final` subclasses. Each knows its name, whether it travels, and its default cycle, cycle gap, hue mode, and hue period. Value-equal. |
| `effect_emitters.dart` | `emitEffect` and one private emitter per effect; `BeamFrame` (what an emitter reads); `applySegment` / `segmentWeight` (the CPU side of the segment mask). |

### `lib/src/render/`

| File | Contents |
| --- | --- |
| `beam_renderer.dart` | `BeamRenderer`: per-beam shader, `Paint`, and emission; `_pack`; the draw bounds; `beamUniformFloats`. |
| `beam_emission.dart` | `BeamEmission`, `BeamSide`, and `beamSlots` (8). |
| `beam_outline.dart` | `BeamOutline`, the Dart mirror of the shader's outline, and the superellipse fit constants. |
| `beam_painter.dart` | `BeamPainter`, the `CustomPainter`. |
| `beam_program.dart` | `BeamProgram`, the shared `FragmentProgram`. |
| `color_math.dart` | `hueRotate`, `mixColor`, `samplePalette` — the CPU copies of the shader's colour maths. |

### `shaders/beam.frag`

The whole look. Its header describes the light model; its uniform block is the contract above. It is declared under `flutter: shaders:` in `pubspec.yaml` and must ship in the published archive.

### `lib/src/models/`

The four public value objects (`beam_style.dart`, `beam_shape.dart`, `beam_timing.dart`, `beam_playback.dart`) are all-nullable, `const`, with `copyWith` / `merge` / `==`; a null field means *inherit*. `beam_options.dart` holds the option enums and `BeamRepeat`; `beam_segment.dart` holds `BeamAnchor`, `BeamCorner`, and `BeamSegment`.

`beam_colors.dart` is the sealed `BeamColors` hierarchy (preset, stops, solid, seed, lerp, scaled) with a value-keyed LRU memo; `beam_presets.dart` holds the 19 preset palettes as plain design data; `beam_palette.dart` is the resolved ring of stops (at most `maxPaletteStops`, 8). `beam_theme.dart` is the `dark` / `light` / `auto` selector. `model_validation.dart` repeats the constructor assertions at runtime, because assertions vanish in release builds.

`beam_config.dart` is where it lands: `BeamConfig.resolve({effect, palette, brightness, style, shape, timing, textDirection})` settles every inherited value — the effect's default cycle, gap, hue mode, and hue period, the 16px default radius, a fixed-hue palette forcing `BeamHueMode.none` — into one value-equal config, so `BeamPainter.shouldRepaint` compares configs.

### `lib/src/animation/`

| File | Contents |
| --- | --- |
| `beam_clock.dart` | The ticker, playback rate, pause / resume / seek / retime, the fade envelopes, and the `pulse` / `flash` boosts. |
| `spring_curve.dart` | The in-package fade spring (mass 1, stiffness 180, damping 20). |
| `beam_phases.dart` | `BeamFramePhases` and `BeamPhaseResolver`. |

### `lib/src/widgets/`

`beam_decoration.dart` (the renderer as a `Decoration`), `beam_focus_ring.dart`, `beam_hover.dart`, `beam_press.dart`.

## Invariants

**One draw per lit frame, and nothing that forces an offscreen pass.** A frame issues exactly one `drawRect` or `drawDRRect` with the beam shader — or none, when the fade or a cycle gap has blacked it out — and no `saveLayer`, no clip, no `ImageFilter`, no `MaskFilter`, with saves and restores balanced. `test/render/frame_budget_test.dart` asserts this for every effect × theme × palette subset × shape family × several instants, plus effect options and driven progress. A new look is new shader maths or new emission data, never a layer.

**The uniform contract moves as one.** The shader's uniform block, `_pack`, and `beamUniformFloats` change in the same commit (see above).

**`BeamOutline` mirrors `outline()` exactly.** A change to corner geometry or to how `u` is measured is made in both, or lights land off the stroke and segments resolve to the wrong place.

**At most 8 of everything per frame.** Bumps, point lights, and palette stops are each bounded by `beamSlots`; `addBump` and `addLight` drop anything past the eighth, and a palette with more than 8 stops is rejected when it resolves.

**Inner glows are point lights.** Nothing that reaches inside the shape reads the nearest-point `u`, which jumps across the medial axis.

**Emitters are pure and allocate no buffers.** An emitter is a function of the config, the phases, the outline, and this frame's colours; it writes into the renderer's reused `BeamEmission` and builds no lists or maps per frame. Anything that depends only on the outline (the ambient effects' anchor positions) is cached per outline.

**CPU and GPU mix colours the same way.** `color_math.dart` and the shader's `mixColor` / `paletteAt` are the same maths, so a light coloured on the CPU matches the stroke beneath it.

**Speed never reaches `BeamConfig`.** It is applied to the clock and kept out of the config cache key, so a rate change does not re-resolve the config or rebuild the phase resolver.

## Tests

| Directory | Covers |
| --- | --- |
| `test/models/` | The value objects, `BeamConfig.resolve`, `BeamColors` and palettes, `BeamEffect`, segments. |
| `test/animation/` | The clock, the spring, phase sampling, travel, and a seeded property test over `BeamPhaseResolver.sample`. |
| `test/render/` | The frame budget, the uniform layout, `BeamOutline`, `BeamEmission` sanity per effect, degenerate geometry, a paint smoke sweep through the real shader, and where light lands (`paint_structure_test.dart`). |
| `test/widget/` | `BorderBeam` itself: lifecycle, updates, shorthands, theming, sync, speed, progress, follow, motion, playback, cycle gap. |
| `test/widgets/` | The four widgets in `lib/src/widgets/`. |
| `test/golden/` | Five golden families — `beam_`, `palette_`, `motion_`, `surface_`, `widgets_`. |

Golden scenes freeze the fake clock at t = 1.3s (past the fade-in, mid-cycle); travelling effects are captured a second time further along. Goldens are generated on macOS on the Flutter version `ci.yaml` pins; regenerating on another OS or SDK produces diffs.
