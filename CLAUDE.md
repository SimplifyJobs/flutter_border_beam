# flutter_border_beam — agent guide

Flutter package: animated light around a widget's border. Three effects
(`rotate`, `line`, `pulse`), all drawn by **one fragment shader in one draw
call per frame** — no `saveLayer`, blurs, or clips. Originally ported from the
[border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam)
React library (MIT, by Jakub Antalik); since 0.2.0 an independent native
renderer that does not track upstream.

## Commands

- `flutter analyze` — must stay at zero issues (lints include `public_member_api_docs`).
- `flutter test` — full suite (unit + widget + render + goldens).
- `flutter test --exclude-tags golden` — everything except goldens (use on non-macOS).
- `flutter test --update-goldens --tags golden` — regenerate goldens (macOS only, on the Flutter version `ci.yaml` pins — 3.47.4). Regenerate only the scenes you touched (`--plain-name`).
- `dart format .` — formatting.
- `cd example && flutter run` — one-screen showcase app: swipe between the three effects, each on its own mock surface with continuous (superellipse) corners; palette swatches and a theme toggle (tokens in `example/lib/src/tokens.dart`); `--dart-define`s `START`, `PALETTE`, `THEME` set the opening state for captures. No tests — CI gates it on `flutter analyze --fatal-infos` and a web build.
- `tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact` — record a demo reel mp4 into `.demos/` (needs a booted iOS simulator + ffmpeg). Reels use `example/lib/demo_harness.dart`'s marker contract (`<PREFIX>:<name>:START/END`, `<PREFIX>:DONE`); new reels are just a map of name → scene widget.
- `dart pub publish --dry-run` — pre-publish validation. `shaders/beam.frag` must be in the archive (`.pubignore` must never exclude `shaders/`).
- **Cutting a release** — bump `version:` in `pubspec.yaml`, add a `## <version>` section to `CHANGELOG.md`, merge to `main`, then push the matching tag: `git tag v<version> && git push origin v<version>`. `.github/workflows/release.yaml` verifies the tag against the pubspec and the changelog, re-runs format/analyze/test, publishes to pub.dev over GitHub OIDC (no secrets), and creates the GitHub Release from that changelog section; a version with a `-suffix` is marked prerelease. Goldens are verified only by the macOS `goldens` job in `ci.yaml` — the release job runs on ubuntu and skips them, so tag a commit that is green on `main`.
- **One-time, before the first automated release** — publish manually with `flutter pub publish` (pub.dev only automates publishing for packages that already exist), then enable pub.dev Admin → Automated publishing for `SimplifyJobs/flutter_border_beam` with tag pattern `v{{version}}`.
- **Bumping the Flutter pin** — change `FLUTTER_VERSION` in `ci.yaml`, `release.yaml`, and `pages.yaml` together, in the same commit as regenerated goldens.

## Architecture

Everything animated is a **pure function of elapsed time** — one `Ticker` per
widget (`BeamClock`), or one per `BeamSync` group. No `AnimationController`s.
A frame:

```text
Ticker → BeamClock → BeamPhaseResolver → effect emitter → BeamFrameData → BeamRenderer → one shader draw
```

The look is the reference design's layer construction evaluated per pixel:
up to three layers (inner glow / hairline stroke / bloom), each a stack of
soft radial **blobs** (palette blob tables from `lib/src/look/`) with a conic
**overlay** (head highlight, bloom band), an inset shadow, a **geometry** (1px
ring AA'd over one device pixel, fill, blurred ring clipped to the shape, or a
glow outside the shape that fades out — rotate's comet, the only light past
the outline), a **window** (rotating conic table or radial ellipse on an
edge), an edge fade, a colour filter folded into its colours on the CPU, and
an opacity. Every blur of the design is analytic: a blurred ring is
`w/σ·φ(d/σ)`, a blurred blob is an energy-preserving gaussian (truncated where
the design cuts it), a blurred outside glow is `Φ`.

Full pipeline, layer model, design data, uniform layout, and invariants in
prose:
**[doc/architecture.md](doc/architecture.md)** — update it when the layout
moves. The map below is the index.

- `lib/flutter_border_beam.dart` — barrel; ONLY `BorderBeam`, `BorderBeamController`, `BorderBeamTheme`/`BorderBeamThemeData`, `BeamSync`, `BeamEffect` + its three subclasses (`RotateEffect`, `LineEffect`, `PulseEffect`), `BeamColors`/`BeamSeedHarmony`, the option types (`BeamDirection`, `BeamEdge`, `BeamHueMode`, `BeamReducedMotion`, `BeamRepeat`), `BeamAnchor`/`BeamCorner`/`BeamSegment`, `BeamTheme`, the four value objects (`BeamStyle`, `BeamShape`, `BeamTiming`, `BeamPlayback`), and the four widgets are public. Nothing in `render/` or `effects/effect_emitters.dart` is exported.
- `lib/src/border_beam.dart` — widget: `BorderBeam({effect, …})` and `BorderBeam.overlay`; three shorthands (`colors`/`active`/`borderRadius`) over the value objects; the driven inputs (`progress`, `follow`, `strengthListenable`, `speedListenable`); `BorderBeam.precache()`; scheduling/lifecycle. Controller attached ⇒ it owns playback exclusively (the resolved playback asserts `startAfter`/`duration` are null, and the controller's `speed` replaces `timing.speed`). `speed` never reaches `BeamConfig` — it is applied to the clock and kept out of the config-cache key.
- `lib/src/border_beam_theme.dart` — `BorderBeamTheme` (`InheritedWidget`) + `BorderBeamThemeData` (`effect`, `style`, `shape`, `timing`, `playback`). `of` walks every enclosing scope, depends on each, and merges them outside-in.
- `lib/src/beam_sync.dart` — `BeamSync` + its internal scope: one clock for a subtree. The group owns playback; a member's `BorderBeamController` asserts.
- `lib/src/border_beam_controller.dart` — `BorderBeamController`, a `ChangeNotifier` over one clock (`start`/`stop`/`pause`/`resume`/`seek`/`speed`, plus the one-shot `pulse`/`flash` accents).
- `lib/src/effects/` — `beam_effect.dart` (sealed `BeamEffect`: `rotate({length, count, comet})`, `line({edge})`, `pulse`; each knows `travels`, `defaultCycle`, `defaultCycleGap`, `defaultHueMode`, `defaultHuePeriod`; `values` = [rotate, line, pulse]), `effect_emitters.dart` (`emitEffect` — one private emitter per effect writing its layers into `BeamFrameData`; `BeamFrame` context; `applyTrack`/`segmentTrack`; `conicFraction`, shared with `follow`). rotate switches to the compact chip tables at a shortest side ≤ 56px, and `comet` swaps its blurred-ring bloom for the outside `glow`; line runs on its edge (mirrored into reading order) or, with a segment, in path space, with two ping-pong hue tracks off one `huePeriod` (bloom 1×, stroke 1.5×, capped swing); pulse samples the 17-oscillator bank per frame, its corner opacities on a breath (quicker swell than fade).
- `lib/src/look/` — the design data, owned and tunable (goldens move when it does): `palette_tables.dart` (`BeamLookTables` + the 4 original palettes' blob tables), `extra_palettes.dart` (the 7 extras' colours, cycled over colorful's tables), `beam_look.dart` (`BeamLook.tablesFor`: own / cycled / sampled-from-stops tables, memoized per palette), `layer_presets.dart` (per-family × surface layer opacities, inset shadow, brightness, saturation), `rotate_look.dart`, `line_look.dart` (keyframes + geometry + `sampleKeyframes`), `pulse_tables.dart`, `pulse_look.dart` (breathing params, oscillator bank, `breath`), `look_blobs.dart`.
- `lib/src/render/` — `beam_renderer.dart` (`BeamRenderer`: per-beam `FragmentShader`/`Paint`/`BeamFrameData`, the upload, the draw bounds), `beam_frame.dart` (`BeamFrameData` — the uniform buffer in shader order and its writers; `BeamGeometry`/`BeamWindow`/`BeamTable`/`BeamBlobSpace`; `beamUniformFloats` = 672; blob slots 14/10/10; 16-stop tables), `beam_outline.dart` (`BeamOutline`, the Dart mirror of the shader's `outline()`, including a port of Flutter's `RSuperellipse` construction — per corner, two halves of superellipse-then-arc keyed on edge-to-radius ratio, `squircleReach` 2.5 radii), `beam_painter.dart` (the `CustomPainter`; repaint = clock ⊕ shader-ready ⊕ progress ⊕ strength), `beam_program.dart` (shared `FragmentProgram`, loaded once), `color_math.dart` (`mixColor`, `samplePalette` — CPU-only; the shader never blends palette stops, blobs arrive coloured). `BeamFrameData.setFilter` builds the hue-rotate → brightness → saturate matrix, which `finish` always folds into the layer's colours on the CPU.
- `shaders/beam.frag` — the layer model per pixel. Header documents it; the uniform block is a contract with `beam_frame.dart`.
- `lib/src/animation/` — `beam_clock.dart` (ticker, speed, pause, seek, retime, fade envelopes, pulse/flash boosts; no fps cap; `elapsedSeconds` is the speed-scaled animation timeline, `activeSeconds` unscaled time while ticking — fades, boosts, and `duration` run on `activeSeconds`, so `speed`/`seek`/`retime` move only the animation, never a fade, and pause freezes both), `spring_curve.dart` (`BeamSpringCurve`, Apple-style damping ratio + response: `fadeIn` ζ 1, `fadeOut` ζ 1 with a longer response, `pop` ζ 0.75 for the accents' rise; `BeamClock.fadeInSeconds`/`fadeOutSeconds` are their settling times), `beam_phases.dart` (`BeamFramePhases` + `BeamPhaseResolver`: fade incl. gap envelope, hue, travellers, `reversedNow`, ambient `cycles`, `driven`).
- `lib/src/models/` — the four public value objects (`beam_style.dart`, `beam_shape.dart`, `beam_timing.dart`, `beam_playback.dart`) are all-nullable, `const`, with `copyWith`/`merge`/`==`; null means *inherit*. `beam_options.dart` (enums + `BeamRepeat`), `beam_segment.dart` (`BeamAnchor`/`BeamCorner`/`BeamSegment`), `beam_colors.dart` (sealed `BeamColors`: preset/stops/solid/seed/lerp/scaled, value-keyed LRU memo), `beam_presets.dart` (the 19 presets' stops; each original points at its tables in `look/palette_tables.dart`, each extra at its table colours in `look/extra_palettes.dart`), `beam_palette.dart` (resolved ring of ≤ 8 stops, `maxPaletteStops`, carrying `tables`/`tableColors`/`mono`), `beam_theme.dart`, `model_validation.dart` (release-mode checks). `BeamConfig.resolve({effect, palette, brightness, style, shape, timing, textDirection})` settles every inherited value (effect defaults, 16px radius, fixed-hue palettes forcing `BeamHueMode.none`) into one value-equal config; `BeamPainter.shouldRepaint` compares configs.
- `lib/src/widgets/` — `beam_decoration.dart` (the renderer as a `Decoration`; no context, so brightness and `BorderBeamThemeData` are arguments and reduced motion is inert), `beam_focus_ring.dart`, `beam_hover.dart`, `beam_press.dart`.

## Hard rules

1. **One draw call per frame; zero `saveLayer`, clip, `ImageFilter`, `MaskFilter`.** A lit frame is exactly one `drawRect`/`drawDRRect` whose paint carries the beam shader; a frame with no lit layer (fade, gap) draws nothing; saves and restores balance. `test/render/frame_budget_test.dart` asserts this across every effect × theme × palette subset × shape family × instant, plus effect options and driven progress. A blur in the design becomes analytic shader maths — never a layer, a blur, or a second draw.
2. **The uniform layout is a contract.** The `uniform` block in `shaders/beam.frag` and the offsets/slot counts in `lib/src/render/beam_frame.dart` change together, in one commit. Uniforms are `vec4`s and `vec4` arrays only (identical float layout on every backend), ≤ 896 floats (the 224 `vec4`s GLES 3.0 guarantees). Arrays are indexed only by constants and loop indices (SkSL strict ES2), so each layer has its own blob array and each table its own uniform. `test/render/uniform_layout_test.dart` parses the shader and checks types, array lengths against the Dart constants, loop bounds, the total, and the order: every `BeamFrameData` writer must land in the uniform the shader declares at that offset.
3. **`BeamOutline` mirrors the shader's `outline()` exactly** — corner model, distance, nearest-piece choice, and arc-length `u`. Emitters lay blobs along the outline with it, segments resolve against it, and `follow` maps the pointer with it.
4. **Fixed slots.** 14 blobs in layer 0, 10 in layers 1 and 2, 16 stops per conic table, ≤ 8 palette stops. `addBlob` drops extras silently; palettes with more stops are rejected at resolve.
5. **Nothing inside the shape reads `u`.** Inside the shape `u` jumps across the medial axis; inner glows are planar blobs (blobs laid along the outline are planar ellipses whose axes follow the normal) or path-space blobs kept within the edge fade.
6. **Emitters are pure and allocation-light per frame.** An emitter is a function of config, phases, outline, and the palette's tables; it writes into the renderer's reused `BeamFrameData`; table transforms use scratch lists, oscillator banks are cached per tuning, derived tables memoized per palette.
7. **Parity with the reference look is checked by eye, then pinned by goldens.** The original look (old goldens at `git show 85be4f8:test/golden/goldens/`) is the calibration: render side by side when retuning rotate/line/pulse.
8. **Don't quote or hard-code look values in docs** — tuning lives in `lib/src/look/` and the emitters and changes; docs describe behaviour.

## Testing conventions

- **Directories** — `test/models/` (value objects, config resolution, colours/palettes, effects, segments), `test/animation/` (clock, spring, phases, travel, seeded property test), `test/render/` (frame budget, uniform layout, `BeamOutline`, `beam_frame_test.dart` for frame sanity and per-effect layer structure, boundaries, paint smoke, `paint_structure_test.dart` for where light lands; helpers in `render_utils.dart`), `test/widget/` (`BorderBeam` itself: lifecycle, updates, shorthands, theming, sync, speed, progress, follow, motion, playback, cycle gap, shape), `test/widgets/` (the four widgets), `test/golden/`.
- **Pixel tests need the shader.** Anything that reads pixels or counts draws awaits `BorderBeam.precache()` in `setUpAll` (`setUpAll(BorderBeam.precache)`); before it resolves a beam paints nothing.
- **Golden families** (one file each, `@Tags(['golden'])`, staged by `test/golden/golden_scene.dart`): `beam_golden_test.dart` (effect × theme × palette, effect options), `palette_golden_test.dart` (every preset, the constructors and transforms), `motion_golden_test.dart` (direction, gap, count, phase offset, driven progress), `surface_golden_test.dart` (radii, superellipse, stadium, ring offset, border width, segments, dashes, line edges), `widgets_golden_test.dart` (`BeamDecoration` and the three wrappers). A new scene belongs in the family that names its axis; add a file only for an axis none of them names.
- **Goldens are macOS-generated on Flutter 3.47.4** (the `ci.yaml` pin) and run with `--tags golden`. Scenes freeze the fake clock at t = 1.3s (post fade-in, mid-cycle); travelling effects get a second `_late` capture at 2.0s. Regenerating on another OS or SDK produces diffs.
- **Structure tests over pixel pins.** `paint_structure_test.dart` compares regions of real frames against each other (lit here, dark there) rather than pinning values, so retuning the look leaves it standing. Prefer that style for new rendering behaviour; leave exact pixels to goldens.
- `test/render/paint_smoke_test.dart` sweeps every effect × theme × palette subset × shape family for "paints visible light through the real shader" — extend `render_utils.dart`'s `shapeVariety`/`paletteSubset` when adding a shape or palette path.
- `test/render/boundary_test.dart` covers degenerate geometry (zero/1px/sliver boxes, radius past the short side, `borderWidth` 0) and out-of-range parameters, asserts every packed uniform is finite, and pins `strength: 0` to painting *no* pixels.
- `test/animation/phase_property_test.dart` property-tests `BeamPhaseResolver.sample` over a seeded random sweep: purity, per-cycle periodicity, and the range of every phase field.
- `test/widget/border_beam_lifecycle_test.dart` asserts no ticker survives disposal mid-fade, an effect swap, `TickerMode`, or a controller outliving its beam — `tester.binding.transientCallbackCount` must return to 0.
- Ticker tests: the first tick after `Ticker.start()` reports elapsed 0 — pump once before pumping durations.
- A test that documents behavior the code does not yet have is marked `skip: 'defect: <one line>'` rather than rewritten to match the bug (`testWidgets` only takes a bool, so its reason goes in a comment).
