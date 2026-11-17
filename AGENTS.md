# prismatic — agent guide

Flutter package of shader effects built for Impeller, with two effects:

- **`BorderBeam`** — animated light around a widget's border. Three effects
  (`rotate`, `line`, `pulse`), all drawn by **one fragment shader in one draw
  call per frame** — no `saveLayer`, blurs, or clips. Its look is that of
  the [border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam)
  React library (MIT, by Jakub Antalik), drawn by a native renderer of its
  own that does not track upstream.
- **`DistortionWave`** — a refractive wave that opens from a button, edge or
  avatar and carries one view into another, in place or between routes
  (`DistortionWaveRoute`). It reimplements the look of Jakub Antalik's SwiftUI
  [Distortion waves](https://github.com/Jakubantalik/Libraries.dev/tree/main/packages/distortion-waves)
  (MIT): both views are drawn from GPU pictures of themselves by **one shader
  draw plus at most one atlas draw per frame** while the wave bends them.

Code shared by both lives in `lib/src/core/` (`ShaderProgram`) and
`shaders/common/` (the rounded-superellipse `outline()`); `lib/src/core/`
also holds `Oklab`, which only the wave uses.

This file is the one agent guide: Codex reads `AGENTS.md`, and Claude Code
reads `CLAUDE.md`, which only imports this file (`@AGENTS.md`). Edit this
file, never `CLAUDE.md`.

## Docs

- **`doc/` is the agent-facing reference** — complete, precise, checked
  against the code. Start at **[doc/README.md](doc/README.md)**, the index
  of which file answers which question. Usage references:
  [doc/border_beam_usage.md](doc/border_beam_usage.md) and
  [doc/distortion_wave_usage.md](doc/distortion_wave_usage.md); internals:
  [doc/architecture.md](doc/architecture.md) (beam) and
  [doc/distortion_wave.md](doc/distortion_wave.md) (wave); topic guides for
  the beam (`effects`, `palettes`, `shape`, `motion`, `theming`) and both
  effects (`accessibility`, `performance`).
- **`README.md` is for humans** on pub.dev and GitHub: what the package is,
  where to use it, demo videos, install, two tiny quick starts, links. Short,
  friendly sentences. Reference material does not go there — it goes in
  `doc/`.
- `CONTRIBUTING.md` is for human contributors (setup, rules in brief, PR
  checklist). `CHANGELOG.md` carries history.
- When public API or behaviour changes, update the matching `doc/*_usage.md`
  in the same change; when a pipeline, uniform layout or module moves, update
  the internals doc and the map below.
- Docs describe how the code works now — no change-history prose ("no longer",
  "previously"). Name constants and getters instead of quoting tuned values
  (hard rule 8 below).

## Commands

- `flutter analyze` — must stay at zero issues, infos included (CI runs `--fatal-infos`; lints include `public_member_api_docs`).
- `flutter test` — full suite (unit + widget + render + goldens).
- `flutter test --exclude-tags golden` — everything except goldens (use on non-macOS).
- **After editing only `shaders/common/*.glsl`**, `rm -rf build && touch shaders/*.frag` before testing: `flutter test` can reuse shaders compiled before an include changed, and run stale.
- `flutter test --update-goldens --tags golden` — regenerate goldens (macOS only, on the Flutter version `ci.yaml` pins — 3.50.0). Regenerate only the scenes you touched (`--plain-name`).
- `dart format .` — formatting (CI: `dart format --output=none --set-exit-if-changed .`).
- `cd example && flutter run` — the showcase app (also the live demo, https://simplifyjobs.github.io/prismatic/, deployed by `pages.yaml`): swipe between the three beam effects, each on its own mock surface with continuous (superellipse) corners; palette swatches and a theme toggle (tokens in `example/lib/src/tokens.dart`); the distortion-wave page (`example/lib/src/wave_page.dart`) opens on a `DistortionWaveRoute`; `example/lib/src/display_corners.dart` supplies iOS display corners. `--dart-define`s `START`, `PALETTE`, `THEME` set the opening state for captures. No tests — CI's `example` job gates it on `flutter analyze --fatal-infos` and a web build.
- `tool/record_demo.sh --target lib/wave_reel.dart --prefix WAVE --contact` — the distortion-wave reel.
- `tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact` — record a demo reel mp4 into `.demos/` (needs a booted iOS simulator + ffmpeg). Reels use `example/lib/demo_harness.dart`'s marker contract (`<PREFIX>:<name>:START/END`, `<PREFIX>:DONE`); new reels are just a map of name → scene widget.
- `dart pub publish --dry-run` — pre-publish validation. `shaders/*.frag` and `shaders/common/*.glsl` must be in the archive (`.pubignore` must never exclude `shaders/`). The `.glsl` includes are not listed under `flutter: shaders:`; impellerc gets `shaders/` as an include path.
- **Cutting a release** — bump `version:` in `pubspec.yaml`, add a `## <version>` section to `CHANGELOG.md`, merge to `main`, then push the matching tag: `git tag v<version> && git push origin v<version>`. `.github/workflows/release.yaml` verifies the tag against the pubspec and the changelog, re-runs format/analyze/test, publishes to pub.dev over GitHub OIDC (no secrets), and creates the GitHub Release from that changelog section; a version with a `-suffix` is marked prerelease. Goldens are verified only by the macOS `goldens` job in `ci.yaml` — the release job runs on ubuntu and skips them, so tag a commit that is green on `main`.
- **One-time, before the first automated release** — publish manually with `flutter pub publish` (pub.dev only automates publishing for packages that already exist), then enable pub.dev Admin → Automated publishing for `SimplifyJobs/prismatic` with tag pattern `v{{version}}`.
- **Bumping the Flutter pin** — change `FLUTTER_VERSION` in `ci.yaml`, `release.yaml`, and `pages.yaml` together, in the same commit as regenerated goldens.

## Architecture

### BorderBeam

Everything animated is a **pure function of elapsed time** — one `Ticker` per
widget (`BeamClock`), or one per `BeamSync` group. No `AnimationController`s.
A frame:

```text
Ticker → BeamClock → BeamPhaseResolver → effect emitter → BeamFrameData → BeamRenderer → one shader draw
```

The look is the reference design's layer construction evaluated per pixel:
up to three layers (inner glow / hairline stroke / bloom), each a stack of
soft radial **blobs** (palette blob tables from `lib/src/border_beam/look/`) with a conic
**overlay** (head highlight, bloom band), an inset shadow, a **geometry** (1px
ring AA'd over one device pixel, fill, blurred ring clipped to the shape, or a
glow outside the shape that fades out — rotate's comet, the only light past
the outline), a **window** (rotating conic table or radial ellipse on an
edge), an edge fade, a colour filter folded into its colours on the CPU, and
an opacity. Every blur of the design is analytic: a blurred ring is
`w/σ·φ(d/σ)`, a blurred blob is an energy-preserving gaussian (truncated where
the design cuts it), a blurred outside glow is `Φ`.

### DistortionWave

Everything is a **pure function of one progress value, 0–1** —
`WaveFrame.at(progress, source, size, spec, focus)` — so the wave scrubs,
reverses and freezes for goldens. One `Ticker` per wave (`WaveClock`), or the
route's own animation. A frame:

```text
WaveClock / route animation → RenderWaveStage → WaveFrame.at → phase → WaveFrameData → wave.frag (one drawRect) + DotAtlas (one drawRawAtlas)
```

`RenderWaveStage` picks a **phase** per frame: `rest` (the visible side as
itself, nothing else), `distorting` (both sides from `WaveSideImages` through
`wave.frag`), `glowing` (the revealed side as itself under
`wave_glow.frag`, once the front has crossed and bends nothing), or
`crossfading` (reduced motion, or a side that cannot be rasterised). A side is
pictured — painted into a detached `OffsetLayer` and `toImageSync`ed, as
`SnapshotWidget` does — when first needed and again only when its content
repaints (`RenderWaveSide.markNeedsPaint` flags it), or every frame with
`WaveSnapshots.everyFrame`; each picture bakes two small blurred copies
once, on its first frame with blur to show — near (`waveNearBlur`, capped at
the spec's blur) and far (the spec's blur), each an `ImageFilter.blur` draw
into its own offscreen `Picture`, never a filter on the stage's canvas. The
shader mixes sharp/near/far by the blur radius each pixel should have —
Swift's stacked blurred copies, in one pass. Pictures are released when the
phase leaves `distorting`. Each stage owns and disposes its `DotAtlas`.

The look (timeline, field, colour model, palettes, per-type tuned styles) is
the reference's; `WaveSpec.resolve` settles widget style ⊕ theme ⊕ type
defaults into seconds and pixels, and settles every value to a finite one
in release builds too (NaN → the field's floor, ranges clamped,
`returnSpeed` 0.01–100). It was calibrated by building
DistortionWavesKit in a throwaway SwiftUI harness and rendering both at the
same progress over the same mock screens (mean difference ≈ 1/255); the
goldens pin those scenes.

Full pipeline, layer model, design data, uniform layout, and invariants in
prose:
**[doc/architecture.md](doc/architecture.md)** (the beam) and
**[doc/distortion_wave.md](doc/distortion_wave.md)** (the wave) — update them
when the layout moves. The map below is the index.

- `lib/src/core/` — `shader_program.dart` (`ShaderProgram`: one instance per `.frag`, loaded once per process, per-zone load sharing, retry after a failed load, `ready`), `oklab.dart` (`Oklab`).
- `lib/distortion_wave.dart` — the wave's library: `DistortionWave`, `DistortionWaveRoute`, `DistortionWaveController`, `DistortionWaveTheme`/`DistortionWaveThemeData`, `DistortionWaveAnchor`/`DistortionWaveAnchorState`, `WaveSource`, `WaveStyle` and its groups (`WaveTiming`, `WaveMotion`, `WaveLens`, `WaveGlow`, `WaveDots`), `WavePalette`/`maxWavePaletteColors`, `WaveType`, `WaveSnapshots`. Nothing in `render/`, `timeline/` or `look/` is exported.
- `lib/src/distortion_wave/` — `distortion_wave.dart` (the widget + its state: clock, controller binding, one `WaveAnchorRegistry` with a `WaveAnchorScope` per side, theme/shorthand resolution, `maintainState`/`TickerMode` for the hidden side, `ExcludeFocus` for the side off screen — at rest or held at either end; also the `WaveStage` slotted widget and `WaveSide`/`RenderWaveSide`), `distortion_wave_route.dart` (`DistortionWaveRoute`: pictures the previous route's page `RepaintBoundary` after the push's first frame and again on pop; `canTransitionFrom` false; its `CurvedAnimation` — linear forward, `spec.easing.flipped` in reverse — made once and disposed with the route; spec resolved once against the navigator's theme), `distortion_wave_controller.dart` (+ the unexported `WaveDriver`/binding), `distortion_wave_theme.dart`, `wave_source.dart` (`WaveSource.rect/key/of`, `DistortionWaveAnchor` — registers as pressed on pointer-down or when focus lands inside it, a keyboard focus dropping its stale touch; `WaveAnchorRegistry.sourceFor`: last pressed on the side on screen → the only anchor there → last pressed on the other side → none; `WaveAnchorScope`, `defaultWaveSource`).
- `lib/src/distortion_wave/models/` — the public value objects (all-nullable, `const`, `copyWith`/`merge`/`==`), `wave_palette.dart`, `wave_type.dart`, `wave_snapshots.dart`, and the internal `wave_spec.dart` (`WaveSpec`: everything settled, value-equal, `duration`/`returnDuration`).
- `lib/src/distortion_wave/look/wave_defaults.dart` — the per-type tuned styles (owned and tunable; goldens move when it does).
- `lib/src/distortion_wave/timeline/` — `wave_frame.dart` (`WaveFrame.at`, `waveCoverZone`, `waveSmooth`), `wave_particles.dart` (`WaveParticle.all`, cached for the last few specs), `wave_rim.dart` (`WaveRim.lumps`/`thickness`), `wave_clock.dart` (`WaveClock`: runs from wherever it is at a full run's speed; interruptible).
- `lib/src/distortion_wave/render/` — `render_wave_stage.dart` (`RenderWaveStage`, `WaveSlot`, `WavePhase`; touches go to the side at rest, and mid-reveal to the revealed side once the phase is `glowing`; semantics visits the side at rest or being headed for), `wave_snapshot.dart` (`WaveSideImages`), `wave_frame_data.dart` (`WaveFrameData`, `waveUniformFloats` = 124 — 31 vec4s, the last `uRadii`, the per-corner radii the edges follow — `wavePaletteSlots` = 8, `waveNearBlur`), `wave_programs.dart` (`waveProgram`, `waveGlowProgram`), `dot_atlas.dart` (`DotAtlas`: one cached AA disc sprite per pixel size; each stage owns one and disposes it), `wave_warm_up.dart` (`warmUpWaveRendering`, run by `DistortionWave.precache`: draws both shaders, a blur bake and an atlas into a 4 × 4 image so pipelines exist before the first wave).
- `shaders/wave.frag`, `shaders/wave_glow.frag`, `shaders/common/wave_uniforms.glsl` (the block both declare — a contract with `wave_frame_data.dart`), `wave_field.glsl`, `wave_colour.glsl`, `outline.glsl`.
- `lib/prismatic.dart` — the package barrel; it re-exports each effect's library. `lib/border_beam.dart` — the beam's library; ONLY `BorderBeam`, `BorderBeamController`, `BorderBeamTheme`/`BorderBeamThemeData`, `BeamSync`, `BeamEffect` + its three subclasses (`RotateEffect`, `LineEffect`, `PulseEffect`), `BeamColors`/`BeamSeedHarmony`, the option types (`BeamDirection`, `BeamEdge`, `BeamHueMode`, `BeamReducedMotion`, `BeamRepeat`), `BeamAnchor`/`BeamCorner`/`BeamSegment`, `BeamTheme`, the four value objects (`BeamStyle`, `BeamShape`, `BeamTiming`, `BeamPlayback`), and the four widgets are public. Nothing in `render/` or `effects/effect_emitters.dart` is exported.
- `lib/src/border_beam/border_beam.dart` — widget: `BorderBeam({effect, …})` and `BorderBeam.overlay`; three shorthands (`colors`/`active`/`borderRadius`) over the value objects; the driven inputs (`progress`, `follow`, `strengthListenable`, `speedListenable`); `BorderBeam.precache()`; scheduling/lifecycle. Controller attached ⇒ it owns playback exclusively (the resolved playback asserts `startAfter`/`duration` are null, and the controller's `speed` replaces `timing.speed`). `speed` never reaches `BeamConfig` — it is applied to the clock and kept out of the config-cache key.
- `lib/src/border_beam/border_beam_theme.dart` — `BorderBeamTheme` (`InheritedWidget`) + `BorderBeamThemeData` (`effect`, `style`, `shape`, `timing`, `playback`). `of` walks every enclosing scope, depends on each, and merges them outside-in.
- `lib/src/border_beam/beam_sync.dart` — `BeamSync` + its internal scope: one clock for a subtree. The group owns playback; a member's `BorderBeamController` asserts.
- `lib/src/border_beam/border_beam_controller.dart` — `BorderBeamController`, a `ChangeNotifier` over one clock (`start`/`stop`/`pause`/`resume`/`seek`/`speed`, plus the one-shot `pulse`/`flash` accents).
- `lib/src/border_beam/effects/` — `beam_effect.dart` (sealed `BeamEffect`: `rotate({length, count, comet})`, `line({edge})`, `pulse`; each knows `travels`, `defaultCycle`, `defaultCycleGap`, `defaultHueMode`, `defaultHuePeriod`; `values` = [rotate, line, pulse]), `effect_emitters.dart` (`emitEffect` — one private emitter per effect writing its layers into `BeamFrameData`; `BeamFrame` context; `applyTrack`/`segmentTrack`; `conicFraction`, shared with `follow`). rotate switches to the compact chip tables at a shortest side ≤ `compactMaxExtent` (`look/rotate_look.dart`), and `comet` swaps its blurred-ring bloom for the outside `glow`; line runs on its edge (mirrored into reading order) or, with a segment, in path space, with two ping-pong hue tracks off one `huePeriod` (bloom 1×, stroke 1.5×, capped swing); pulse samples the 17-oscillator bank per frame, its corner opacities on a breath (quicker swell than fade).
- `lib/src/border_beam/look/` — the design data, owned and tunable (goldens move when it does): `palette_tables.dart` (`BeamLookTables` + the 4 original palettes' blob tables), `extra_palettes.dart` (the 7 extras' colours, cycled over colorful's tables), `beam_look.dart` (`BeamLook.tablesFor`: own / cycled / sampled-from-stops tables, memoized per palette), `layer_presets.dart` (per-family × surface layer opacities, inset shadow, brightness, saturation), `rotate_look.dart`, `line_look.dart` (keyframes + geometry + `sampleKeyframes`), `pulse_tables.dart`, `pulse_look.dart` (breathing params, oscillator bank, `breath`), `look_blobs.dart`.
- `lib/src/border_beam/render/` — `beam_renderer.dart` (`BeamRenderer`: per-beam `FragmentShader`/`Paint`/`BeamFrameData`, the upload, the draw bounds), `beam_frame.dart` (`BeamFrameData` — the uniform buffer in shader order and its writers; `BeamGeometry`/`BeamWindow`/`BeamTable`/`BeamBlobSpace`; `beamUniformFloats` = 672; blob slots 14/10/10; 16-stop tables), `beam_outline.dart` (`BeamOutline`, the Dart mirror of the shader's `outline()`, including a port of Flutter's `RSuperellipse` construction — per corner, two halves of superellipse-then-arc keyed on edge-to-radius ratio, `squircleReach` 2.5 radii), `beam_painter.dart` (the `CustomPainter`; repaint = clock ⊕ shader-ready ⊕ progress ⊕ strength), `beam_program.dart` (`beamProgram`, the beam's `ShaderProgram` from `lib/src/core/shader_program.dart`, loaded once), `color_math.dart` (`mixColor`, `samplePalette` — CPU-only; the shader never blends palette stops, blobs arrive coloured). `BeamFrameData.setFilter` builds the hue-rotate → brightness → saturate matrix, which `finish` always folds into the layer's colours on the CPU.
- `shaders/beam.frag` — the layer model per pixel. Header documents it; the uniform block is a contract with `beam_frame.dart`.
- `lib/src/border_beam/animation/` — `beam_clock.dart` (ticker, speed, pause, seek, retime, fade envelopes, pulse/flash boosts; no fps cap; `elapsedSeconds` is the speed-scaled animation timeline, `activeSeconds` unscaled time while ticking — fades, boosts, and `duration` run on `activeSeconds`, so `speed`/`seek`/`retime` move only the animation, never a fade, and pause freezes both), `spring_curve.dart` (`BeamSpringCurve`, Apple-style damping ratio + response: `fadeIn` ζ 1, `fadeOut` ζ 1 with a longer response, `pop` ζ 0.75 for a pulse's rise (a flash has none); `BeamClock.fadeInSeconds`/`fadeOutSeconds` are their settling times), `beam_phases.dart` (`BeamFramePhases` + `BeamPhaseResolver`: fade incl. gap envelope, hue, travellers, `reversedNow`, ambient `cycles`, `driven`).
- `lib/src/border_beam/models/` — the four public value objects (`beam_style.dart`, `beam_shape.dart`, `beam_timing.dart`, `beam_playback.dart`) are all-nullable, `const`, with `copyWith`/`merge`/`==`; null means *inherit*. `beam_options.dart` (enums + `BeamRepeat`), `beam_segment.dart` (`BeamAnchor`/`BeamCorner`/`BeamSegment`), `beam_colors.dart` (sealed `BeamColors`: preset/stops/solid/seed/lerp/scaled, value-keyed LRU memo), `beam_presets.dart` (the 19 presets' stops; each original points at its tables in `look/palette_tables.dart`, each extra at its table colours in `look/extra_palettes.dart`), `beam_palette.dart` (resolved ring of ≤ 8 stops, `maxPaletteStops`, carrying `tables`/`tableColors`/`mono`), `beam_theme.dart`, `model_validation.dart` (release-mode checks). `BeamConfig.resolve({effect, palette, brightness, style, shape, timing, textDirection})` settles every inherited value (effect defaults, 16px radius, fixed-hue palettes forcing `BeamHueMode.none`) into one value-equal config; `BeamPainter.shouldRepaint` compares configs.
- `lib/src/border_beam/widgets/` — `beam_decoration.dart` (the renderer as a `Decoration`; no context, so brightness and `BorderBeamThemeData` are arguments and reduced motion is inert), `beam_focus_ring.dart`, `beam_hover.dart`, `beam_press.dart`.

## Hard rules

### BorderBeam

1. **One draw call per frame; zero `saveLayer`, clip, `ImageFilter`, `MaskFilter`.** A lit frame is exactly one `drawRect`/`drawDRRect` whose paint carries the beam shader; a frame with no lit layer (fade, gap) draws nothing; saves and restores balance. `test/border_beam/render/frame_budget_test.dart` asserts this across every effect × theme × palette subset × shape family × instant, plus effect options and driven progress. A blur in the design becomes analytic shader maths — never a layer, a blur, or a second draw.
2. **The uniform layout is a contract.** The `uniform` block in `shaders/beam.frag` and the offsets/slot counts in `lib/src/border_beam/render/beam_frame.dart` change together, in one commit. Uniforms are `vec4`s and `vec4` arrays only (identical float layout on every backend), ≤ 896 floats (the 224 `vec4`s GLES 3.0 guarantees). Arrays are indexed only by constants and loop indices (SkSL strict ES2), so each layer has its own blob array and each table its own uniform. `test/border_beam/render/uniform_layout_test.dart` parses the shader and checks types, array lengths against the Dart constants, loop bounds, the total, and the order: every `BeamFrameData` writer must land in the uniform the shader declares at that offset.
3. **`BeamOutline` mirrors the shaders' `outline()` (`shaders/common/outline.glsl`, included by every shader) exactly** — corner model, distance, nearest-piece choice, and arc-length `u`. Emitters lay blobs along the outline with it, segments resolve against it, and `follow` maps the pointer with it.
4. **Fixed slots.** 14 blobs in layer 0, 10 in layers 1 and 2, 16 stops per conic table, ≤ 8 palette stops. `addBlob` drops extras silently; palettes with more stops are rejected at resolve.
5. **Nothing inside the shape reads `u`.** Inside the shape `u` jumps across the medial axis; inner glows are planar blobs (blobs laid along the outline are planar ellipses whose axes follow the normal) or path-space blobs kept within the edge fade.
6. **Emitters are pure and allocation-light per frame.** An emitter is a function of config, phases, outline, and the palette's tables; it writes into the renderer's reused `BeamFrameData`; table transforms use scratch lists, oscillator banks are cached per tuning, derived tables memoized per palette.
7. **Parity with the reference look is checked by eye, then pinned by goldens.** The goldens in `test/border_beam/golden/goldens/` pin the calibrated look: when retuning rotate/line/pulse, render the change beside them and beside the border-beam reference, and regenerate only once it matches.
8. **Don't quote or hard-code look values in docs** — tuning lives in `lib/src/border_beam/look/` and the emitters (and `lib/src/distortion_wave/look/` for the wave) and changes; docs describe behaviour.

### DistortionWave

1. **Distortion window: one shader `drawRect` plus at most one `drawRawAtlas` per frame; zero `saveLayer`, clip, `ImageFilter`, `BackdropFilter`, `MaskFilter`, image draws on the stage's canvas.** At rest the wave paints the visible child and nothing else; in the glow phase, the revealed child plus one `drawRect` and at most one atlas. (Picturing a side is separate offscreen work — one `toImageSync` plus two `ImageFilter.blur` bakes — and happens only per rule 2.) `test/distortion_wave/render/wave_frame_budget_test.dart` asserts this per phase × type. Never reach for `ImageFilter.shader`/`BackdropFilter`: they are Impeller-only, need a new filter object every frame, and hit open engine bugs (flutter#185175, #187820).
2. **A side is pictured only when its content changed** (or every frame under `WaveSnapshots.everyFrame`), and pictures are released when the phase leaves `distorting`. The snapshot-count and lifecycle tests pin both.
3. **The uniform block is a contract.** `shaders/common/wave_uniforms.glsl` (declared once, included by both wave shaders) and `WaveFrameData`'s offsets change together, in one commit; vec4s only, samplers after it in `wave.frag` in the order the renderer binds them (out sharp/near/far, in sharp/near/far). `test/distortion_wave/render/wave_uniform_layout_test.dart` checks both shaders through `test/support/shader_source.dart`, which inlines `#include`s.
4. **`WaveFrame` stays a pure function of progress.** Scrubbing, reversing, the route and the goldens depend on it; anything per-frame that is not (a ticker, an image) lives in the clock or the stage.
5. **Parity with the reference look is checked by rendering both, then pinned by goldens.** When retuning, rebuild the SwiftUI harness (DistortionWavesKit + `ImageRenderer` at fixed `scrub:`, built with `xcodebuild`, which needs the Metal Toolchain) and compare at the golden scenes' progress values.
6. **SkSL strict ES2 in every shader** — loops with constant bounds, arrays indexed by constants or loop indices — so the wave also runs on Skia and the web.

## Testing conventions

- **Directories** — `test/core/` (code shared by every effect: `ShaderProgram`, `Oklab`); `test/support/` (helpers shared by both effects' tests: `shader_source.dart`); the wave's under `test/distortion_wave/`: `models/` (value objects, `WaveSpec` resolution, palettes), `timeline/` (`WaveFrame` — ports of every `WaveFrontTests` case — particles, rim, clock, seeded property sweep), `render/` (uniform layout, frame budget + snapshot counts, `wave_paint_structure_test.dart` for where pixels land in real frames), `widget/` (behaviour, lifecycle, route, theme; helpers in `wave_test_utils.dart`), `golden/` (`wave_golden_test.dart`: each type at its telling moments, palettes; scenes held with `progress:`); the beam's tests under `test/border_beam/`: `test/border_beam/models/` (value objects, config resolution, colours/palettes, effects, segments), `test/border_beam/animation/` (clock, spring, phases, travel, seeded property test), `test/border_beam/render/` (frame budget, uniform layout, `BeamOutline`, `beam_frame_test.dart` for frame sanity and per-effect layer structure, boundaries, paint smoke, `paint_structure_test.dart` for where light lands; helpers in `render_utils.dart`), `test/border_beam/widget/` (`BorderBeam` itself: lifecycle, updates, shorthands, theming, sync, speed, progress, follow, motion, playback, cycle gap, shape), `test/border_beam/widgets/` (the four widgets), `test/border_beam/golden/`.
- **Leak tracking.** `test/distortion_wave/widget/distortion_wave_lifecycle_test.dart` and `distortion_wave_route_test.dart` call `LeakTesting.enable()` (`leak_tracker_flutter_testing`, a dev dependency pinned by `flutter_test` through `any`): any image, `ChangeNotifier`, `CurvedAnimation` or controller the code or the test creates must be disposed (`addTearDown(controller.dispose)`). Call `LeakTesting.enable()` in new lifecycle-style test files.
- **Pixel tests need the shader.** Anything that reads pixels or counts draws awaits `BorderBeam.precache()` (or `DistortionWave.precache()`) in `setUpAll`; before it resolves a beam paints nothing and a wave shows its sides plainly.
- **Beam golden families** (one file each, `@Tags(['golden'])`, staged by `test/border_beam/golden/golden_scene.dart`): `beam_golden_test.dart` (effect × theme × palette, effect options), `palette_golden_test.dart` (every preset, the constructors and transforms), `motion_golden_test.dart` (direction, gap, count, phase offset, driven progress), `surface_golden_test.dart` (radii, superellipse, stadium, ring offset, border width, segments, dashes, line edges), `widgets_golden_test.dart` (`BeamDecoration` and the three wrappers). A new scene belongs in the family that names its axis; add a file only for an axis none of them names. The wave's goldens are one file, `test/distortion_wave/golden/wave_golden_test.dart`, each scene held with `progress:`.
- **Goldens are macOS-generated on Flutter 3.50.0** (the `ci.yaml` pin) and run with `--tags golden`. Beam scenes freeze the fake clock at t = 1.3s (post fade-in, mid-cycle); travelling effects get a second `_late` capture at 2.0s. Regenerating on another OS or SDK produces diffs.
- **Structure tests over pixel pins.** `paint_structure_test.dart` compares regions of real frames against each other (lit here, dark there) rather than pinning values, so retuning the look leaves it standing. Prefer that style for new rendering behaviour; leave exact pixels to goldens.
- `test/border_beam/render/paint_smoke_test.dart` sweeps every effect × theme × palette subset × shape family for "paints visible light through the real shader" — extend `render_utils.dart`'s `shapeVariety`/`paletteSubset` when adding a shape or palette path.
- `test/border_beam/render/boundary_test.dart` covers degenerate geometry (zero/1px/sliver boxes, radius past the short side, `borderWidth` 0) and out-of-range parameters, asserts every packed uniform is finite, and pins `strength: 0` to painting *no* pixels.
- `test/border_beam/animation/phase_property_test.dart` property-tests `BeamPhaseResolver.sample` over a seeded random sweep: purity, per-cycle periodicity, and the range of every phase field.
- `test/border_beam/widget/border_beam_lifecycle_test.dart` asserts no ticker survives disposal mid-fade, an effect swap, `TickerMode`, or a controller outliving its beam — `tester.binding.transientCallbackCount` must return to 0. `test/distortion_wave/widget/distortion_wave_lifecycle_test.dart` does the same for a wave disposed mid-run, `TickerMode`, a controller outliving or moving between waves, and the release of the sides' pictures.
- Ticker tests: the first tick after `Ticker.start()` reports elapsed 0 — pump once before pumping durations.
- A test that documents behavior the code does not yet have is marked `skip: 'defect: <one line>'` rather than rewritten to match the bug (`testWidgets` only takes a bool, so its reason goes in a comment).
