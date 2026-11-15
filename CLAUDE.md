# flutter_border_beam — agent guide

Flutter package: animated light around a widget's border. Eight effects, all
drawn by **one fragment shader in one draw call per frame** — no `saveLayer`,
blurs, or clips. Originally ported from the
[border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam)
React library (MIT, by Jakub Antalik); since 0.2.0 an independent native
renderer that does not track upstream.

## Commands

- `flutter analyze` — must stay at zero issues (lints include `public_member_api_docs`).
- `flutter test` — full suite (unit + widget + render + goldens).
- `flutter test --exclude-tags golden` — everything except goldens (use on non-macOS).
- `flutter test --update-goldens --tags golden` — regenerate goldens (macOS only, on the Flutter version `ci.yaml` pins — 3.47.4). Regenerate only the scenes you touched (`--plain-name`).
- `dart format .` — formatting.
- `cd example && flutter run` — demo gallery app (React-demo-styled; tokens in `example/lib/src/demo_theme.dart`).
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
Ticker → BeamClock → BeamPhaseResolver → effect emitter → BeamEmission → BeamRenderer → one shader draw
```

The shader shades every pixel from `d` (signed distance to the outline) and
`u` (perimeter position, 0 at top-centre, clockwise): border light =
palette(u) × emission(u) × profile(d) (stroke, bloom, outer halo), plus up to 8
**point lights** — anisotropic gaussians anchored on the border — for every
glow that reaches inside.

Full pipeline, light model, uniform layout, and invariants in prose:
**[doc/architecture.md](doc/architecture.md)** — update it when the layout
moves. The map below is the index.

- `lib/flutter_border_beam.dart` — barrel; ONLY `BorderBeam`, `BorderBeamController`, `BorderBeamTheme`/`BorderBeamThemeData`, `BeamSync`, `BeamEffect` + its eight subclasses, `BeamColors`/`BeamSeedHarmony`, the option types (`BeamDirection`, `BeamEdge`, `BeamHueMode`, `BeamReducedMotion`, `BeamRepeat`), `BeamAnchor`/`BeamCorner`/`BeamSegment`, `BeamTheme`, the four value objects (`BeamStyle`, `BeamShape`, `BeamTiming`, `BeamPlayback`), and the four widgets are public. Nothing in `render/` or `effects/effect_emitters.dart` is exported.
- `lib/src/border_beam.dart` — widget: `BorderBeam({effect, …})` and `BorderBeam.overlay`; three shorthands (`colors`/`active`/`borderRadius`) over the value objects; the driven inputs (`progress`, `follow`, `strengthListenable`, `speedListenable`); `BorderBeam.precache()`; scheduling/lifecycle. Controller attached ⇒ it owns playback exclusively (the resolved playback asserts `startAfter`/`duration` are null, and the controller's `speed` replaces `timing.speed`). `speed` never reaches `BeamConfig` — it is applied to the clock and kept out of the config-cache key.
- `lib/src/border_beam_theme.dart` — `BorderBeamTheme` (`InheritedWidget`) + `BorderBeamThemeData` (`effect`, `style`, `shape`, `timing`, `playback`). `of` walks every enclosing scope, depends on each, and merges them outside-in.
- `lib/src/beam_sync.dart` — `BeamSync` + its internal scope: one clock for a subtree. The group owns playback; a member's `BorderBeamController` asserts.
- `lib/src/border_beam_controller.dart` — `BorderBeamController`, a `ChangeNotifier` over one clock (`start`/`stop`/`pause`/`resume`/`seek`/`speed`, plus the one-shot `pulse`/`flash` accents).
- `lib/src/effects/` — `beam_effect.dart` (sealed `BeamEffect`: `rotate({length, count, comet})`, `line({edge})`, `pulse`, `halo`, `flow`, `spin`, `shimmer({angle})`, `charge`; each knows `travels`, `defaultCycle`, `defaultCycleGap`, `defaultHueMode`, `defaultHuePeriod`), `effect_emitters.dart` (`emitEffect` — one private emitter per effect writing a `BeamEmission`; `applySegment`/`segmentWeight`; per-outline anchor caches).
- `lib/src/render/` — `beam_renderer.dart` (`BeamRenderer`: per-beam `FragmentShader`/`Paint`/`BeamEmission`, `_pack`, the draw bounds, `beamUniformFloats`), `beam_emission.dart` (`BeamEmission`, `BeamSide`, `beamSlots` = 8), `beam_outline.dart` (`BeamOutline`, the Dart mirror of the shader's `outline()`, and the superellipse fit `squircleInset` 1.42 / `squircleExponent` 3.04), `beam_painter.dart` (the `CustomPainter`; repaint = clock ⊕ shader-ready ⊕ progress ⊕ strength), `beam_program.dart` (shared `FragmentProgram`, loaded once), `color_math.dart` (`hueRotate`, `mixColor`, `samplePalette`).
- `shaders/beam.frag` — the whole look. Header documents the model; the uniform block is a contract with `_pack`.
- `lib/src/animation/` — `beam_clock.dart` (ticker, speed, pause, retime, fade envelopes, pulse/flash boosts; no fps cap), `spring_curve.dart` (fade spring: mass 1, stiffness 180, damping 20), `beam_phases.dart` (`BeamFramePhases` + `BeamPhaseResolver`: fade incl. gap envelope, hue, travellers, `reversedNow`, ambient `cycles`, `driven`).
- `lib/src/models/` — the four public value objects (`beam_style.dart`, `beam_shape.dart`, `beam_timing.dart`, `beam_playback.dart`) are all-nullable, `const`, with `copyWith`/`merge`/`==`; null means *inherit*. `beam_options.dart` (enums + `BeamRepeat`), `beam_segment.dart` (`BeamAnchor`/`BeamCorner`/`BeamSegment`), `beam_colors.dart` (sealed `BeamColors`: preset/stops/solid/seed/lerp/scaled, value-keyed LRU memo), `beam_presets.dart` (the 19 presets — plain design data, safe to edit), `beam_palette.dart` (resolved ring of ≤ 8 stops, `maxPaletteStops`), `beam_theme.dart`, `model_validation.dart` (release-mode checks). `BeamConfig.resolve({effect, palette, brightness, style, shape, timing, textDirection})` settles every inherited value (effect defaults, 16px radius, fixed-hue palettes forcing `BeamHueMode.none`) into one value-equal config; `BeamPainter.shouldRepaint` compares configs.
- `lib/src/widgets/` — `beam_decoration.dart` (the renderer as a `Decoration`; no context, so brightness and `BorderBeamThemeData` are arguments and reduced motion is inert), `beam_focus_ring.dart`, `beam_hover.dart`, `beam_press.dart`.

## Hard rules

1. **One draw call per frame; zero `saveLayer`, clip, `ImageFilter`, `MaskFilter`.** A lit frame is exactly one `drawRect`/`drawDRRect` whose paint carries the beam shader; a blacked-out frame draws nothing; saves and restores balance. `test/render/frame_budget_test.dart` asserts this across every effect × theme × palette subset × shape family × instant, plus effect options and driven progress. A new look is new shader maths or new emission data — never a layer, a blur, or a second draw.
2. **The uniform layout is a contract.** The `uniform` block in `shaders/beam.frag`, `_pack` in `lib/src/render/beam_renderer.dart`, and `beamUniformFloats` change together, in one commit. Uniforms are `vec4`s and `vec4[beamSlots]` arrays only (identical float layout on every backend). `test/render/uniform_layout_test.dart` parses the shader and checks types, array lengths, and the total — but not the order, so a reorder on one side only produces garbage frames, not a failure. `_pack` asserts the count in debug.
3. **`BeamOutline` mirrors the shader's `outline()` exactly** — corner model, distance, nearest-piece choice, and arc-length `u`. Emitters place lights with it, segments resolve against it, and `follow` maps the pointer with it; a change to one side only puts light off the stroke.
4. **At most 8 bumps, 8 point lights, and 8 colour stops per frame** (`beamSlots`, `maxPaletteStops`). `addBump`/`addLight` drop extras silently; palettes with more stops are rejected at resolve.
5. **Inner glows are point lights, never the nearest-point `u`.** Inside the shape `u` jumps across the medial axis; anything that reaches inward must be a point light (or have compact support that ends well before the medial axis).
6. **Emitters are pure and allocation-free per frame.** An emitter is a function of config, phases, outline, and this frame's colours; it writes into the renderer's reused `BeamEmission` and builds no lists, maps, or closures per frame. Values that depend only on the outline are cached per outline (`Expando`, see `_anchors`).
7. **Colours mix gamma-aware the same way on CPU and GPU.** `color_math.dart`'s `mixColor`/`samplePalette` and the shader's `mixColor`/`paletteAt` are one algorithm (interpolate squared channels, take the square root); change both or neither. Hue rotation happens on the CPU, on ≤ 8 colours per frame.
8. **Don't quote or hard-code look values in docs** — effect tuning (layer weights, reaches, sigmas) lives in `effect_emitters.dart` and changes; docs describe behaviour.

## Testing conventions

- **Directories** — `test/models/` (value objects, config resolution, colours/palettes, effects, segments), `test/animation/` (clock, spring, phases, travel, seeded property test), `test/render/` (frame budget, uniform layout, `BeamOutline`, `BeamEmission` sanity, boundaries, paint smoke, `paint_structure_test.dart` for where light lands; helpers in `render_utils.dart`), `test/widget/` (`BorderBeam` itself: lifecycle, updates, shorthands, theming, sync, speed, progress, follow, motion, playback, cycle gap, shape), `test/widgets/` (the four widgets), `test/golden/`.
- **Pixel tests need the shader.** Anything that reads pixels or counts draws awaits `BorderBeam.precache()` in `setUpAll` (`setUpAll(BorderBeam.precache)`); before it resolves a beam paints nothing.
- **Golden families** (one file each, `@Tags(['golden'])`, staged by `test/golden/golden_scene.dart`): `beam_golden_test.dart` (effect × theme × palette, effect options), `palette_golden_test.dart` (every preset, the constructors and transforms), `motion_golden_test.dart` (direction, gap, count, phase offset, driven progress), `surface_golden_test.dart` (radii, superellipse, stadium, ring offset, border width, segments, dashes, line edges), `widgets_golden_test.dart` (`BeamDecoration` and the three wrappers). A new scene belongs in the family that names its axis; add a file only for an axis none of them names.
- **Goldens are macOS-generated on Flutter 3.47.4** (the `ci.yaml` pin) and run with `--tags golden`. Scenes freeze the fake clock at t = 1.3s (post fade-in, mid-cycle); travelling effects get a second `_late` capture (rotate and line 2.0s, shimmer 3.7s, charge 2.2s). Regenerating on another OS or SDK produces diffs.
- **Structure tests over pixel pins.** `paint_structure_test.dart` compares regions of real frames against each other (lit here, dark there) rather than pinning values, so retuning the look leaves it standing. Prefer that style for new rendering behaviour; leave exact pixels to goldens.
- `test/render/paint_smoke_test.dart` sweeps every effect × theme × palette subset × shape family for "paints visible light through the real shader" — extend `render_utils.dart`'s `shapeVariety`/`paletteSubset` when adding a shape or palette path.
- `test/render/boundary_test.dart` covers degenerate geometry (zero/1px/sliver boxes, radius past the short side, `borderWidth` 0) and out-of-range parameters, asserts every packed uniform is finite, and pins `strength: 0` to painting *no* pixels.
- `test/animation/phase_property_test.dart` property-tests `BeamPhaseResolver.sample` over a seeded random sweep: purity, per-cycle periodicity, and the range of every phase field.
- `test/widget/border_beam_lifecycle_test.dart` asserts no ticker survives disposal mid-fade, an effect swap, `TickerMode`, or a controller outliving its beam — `tester.binding.transientCallbackCount` must return to 0.
- Ticker tests: the first tick after `Ticker.start()` reports elapsed 0 — pump once before pumping durations.
- A test that documents behavior the code does not yet have is marked `skip: 'defect: <one line>'` rather than rewritten to match the bug (`testWidgets` only takes a bool, so its reason goes in a comment).
