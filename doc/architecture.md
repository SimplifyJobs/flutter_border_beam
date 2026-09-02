# Architecture

The one idea the whole package is built on: **everything animated is a pure function of elapsed time.** One `Ticker` produces a number; every visual value is recomputed from that number each frame. There are no `AnimationController`s anywhere, no per-track state to keep in sync, and no way for two tracks to drift apart — which mirrors the original React library's single shared `requestAnimationFrame` loop, and is what makes goldens, property tests, and `debugFrozenAt` possible.

## The frame

```text
Ticker ──► BeamClock ──► BeamPhaseResolver ──► VariantStrategy ──► BeamPainter
           elapsed s      every animated       geometry for        stroke / inner /
           speed, fade    track for this       this variant        bloom layers
           pause, fps     frame               family
```

1. **`BeamClock`** owns the ticker. It scales elapsed time by the playback rate, runs the fade envelope on activate/deactivate, handles pause/resume/seek, applies the optional fps cap, and carries the one-shot `pulse()`/`flash()` boosts. It is a `Listenable`; the painter repaints from it.
2. **`BeamPhaseResolver`** samples every animated track for a given time: sweep position, hue, the line variant's breathe and spike scales, the pulse oscillator bank. Pure — same time in, same phases out.
3. **A `VariantStrategy`** per variant family turns phases into geometry: the traveling window and its masks, or the breathing blob table.
4. **`BeamPainter`** is one `CustomPainter` running that pipeline into a fixed layer budget, on a `behind` pass (pulse-outside) or an `above` pass (everything else).

## Module layout

### Public entry points

| File | Contents |
| --- | --- |
| `lib/flutter_border_beam.dart` | The barrel. Only `BorderBeam`, `BorderBeamController`, `BorderBeamTheme`/`BorderBeamThemeData`, `BeamSync`, `BeamVariant`, `BeamColors`/`BeamSeedHarmony`, `BeamBlob`/`LineBlob`, `BeamTheme`, `BeamThemeConfig`, the four value objects, the option types, and the four widgets are exported. |
| `lib/src/border_beam.dart` | The widget: a generic constructor taking a `BeamVariant`, `BorderBeam.overlay`, five named constructors, three flat shorthands (`colors` / `active` / `borderRadius`), the driven inputs (`progress`, `follow`, `strengthListenable`, `speedListenable`), and all scheduling and lifecycle. A controller attached ⇒ it owns playback exclusively. |
| `lib/src/border_beam_controller.dart` | `BorderBeamController` — a `ChangeNotifier` over one clock. |
| `lib/src/border_beam_theme.dart` | `BorderBeamTheme` (an `InheritedWidget`) + `BorderBeamThemeData`. `of` walks every enclosing scope, depends on each, and merges them outside-in, so nested themes compose. |
| `lib/src/beam_sync.dart` | `BeamSync` and its internal scope — one clock for a whole subtree. |

### `lib/src/models/` — data types

The four public **value objects** (`beam_style.dart`, `beam_shape.dart`, `beam_timing.dart`, `beam_playback.dart`) are all-nullable, `const`, with `copyWith` / `merge` / `==`. A null field means *inherit*.

`beam_options.dart` holds the small option types those fields take: `BeamHueMode`, `BeamDirection`, `BeamEdge`, `BeamReducedMotion`, `BeamRepeat`, `BeamPulseOutsideTuning`, and the `BeamContour` / `BeamPathContour` pair — a contour is a config-cache key, so every implementer overrides `==` / `hashCode`.

`beam_colors.dart` is the sealed `BeamColors` hierarchy (preset, custom, seed, scheme, lerp, scaled, spec) with the value-keyed LRU that memoizes resolution; `beam_palette.dart` and `beam_blob.dart` are the resolved tables and their entries; `beam_theme.dart` and `beam_theme_config.dart` are the brightness selector and the per-variant × brightness preset.

`beam_config.dart` is where it all lands. `BeamConfig.resolve({variant, palette, brightness, style, shape, timing, textDirection})` flattens the value objects into the painter's config, mirroring the React component's computed values — per-variant default durations and radii, the line variant's 13° hue cap, mono forcing static colors. It carries the timing tracks (`gapSeconds`, hue periods, breathe/spike factors) and a per-corner resolved `BorderRadius`, and it is value-equal, so `BeamPainter.shouldRepaint` compares configs.

### `lib/src/animation/`

| File | Contents |
| --- | --- |
| `beam_clock.dart` | The ticker, playback rate, pause/resume/seek, spring or curve fade envelopes, the optional fps cap, and the `pulse`/`flash` boosts. |
| `spring_curve.dart` | The in-package fade spring (mass 1, stiffness 180, damping 20) — the reason the package depends on nothing but the Flutter SDK. |
| `oscillator.dart` | The ping-pong helper and the 17-oscillator pulse bank. |
| `beam_phases.dart` | `BeamPhaseResolver` — the per-frame value object and keyframe sampling. |

### `lib/src/painting/`

| File | Contents |
| --- | --- |
| `beam_painter.dart` | The single `CustomPainter`; repaint driven by the clock, `behind` / `above` passes. |
| `variant_strategy.dart` | The strategy interface, including `preferredFps`. |
| `strategies/` | `rotate_strategy.dart`, `line_strategy.dart`, `pulse_inner_strategy.dart`, `pulse_outer_strategy.dart`, and the `pulse_common.dart` they share. |
| `ring_geometry.dart` | The rounded-rect and `RSuperellipse` ring, built as a `Path.combine` difference; contour and ring-offset handling. |
| `gradient_builders.dart` | Blob tables to `Gradient`s, and the CSS↔Flutter conventions. |
| `color_matrix.dart` | Hue, brightness, and saturation matrices, folded into colors on the CPU. |
| `layer_utils.dart` | The `saveLayer` helpers the budget is counted through. |

### `lib/src/constants/`

Verbatim transcriptions of the upstream `src/styles.ts` tables — `palettes.dart`, `theme_presets.dart`, `pulse_tables.dart`, `pulse_params.dart`, `pulse_constants.dart`, `line_keyframes.dart`, `line_geometry.dart`, `rotate_stops.dart` — plus `upstream.dart` (internal provenance: the tracked library and spec versions and the source repository) and `extra_palettes.dart` (the seven Flutter-only presets, which are *not* transcriptions). `tool/spec/refresh.sh` vendors upstream's machine-readable spec into `test/fixtures/`, and `test/constants/spec_parity_test.dart` asserts every table against it. See [parity](parity.md).

### `lib/src/widgets/`

`beam_decoration.dart` (the engine as a `Decoration`), `beam_focus_ring.dart`, `beam_hover.dart`, `beam_press.dart`.

## Invariants worth knowing

**Never tweak values in `lib/src/constants/`.** They are transcribed 1:1 from the source and pinned by the constant tests. See [parity](parity.md).

**The saveLayer budget is exact.** rotate 4, small 3, line 4, pulseInside 4, pulseOutside 3 per frame, asserted by `test/painting/save_layer_budget_test.dart` — a regression and an improvement both fail until the table moves. Never add a `saveLayer` just to carry a `ColorFilter`; a filter rides on a layer that exists anyway, and blur is the only filter allowed to justify a layer of its own. See [performance](performance.md).

**CSS↔Flutter conventions** live in `gradient_builders.dart` and are listed in [parity](parity.md#css--flutter-mapping): conic gradients start at 12 o'clock so `SweepGradient` needs a baked −90°; CSS radial-gradient sizes are radii; `blur(Npx)` maps to sigma = N; fades go to `color.withValues(alpha: 0)`, never `Color(0x00000000)`.

**Layer opacity is a multiplied chain** — fade × preset × mono × hook × strength — clamped at paint time. Presets legitimately exceed 1 (line/dark's stroke is 1.14).

**The line variant does not use the mono ×0.5 multiplier.** Its mono treatment is spike attenuation inside the bloom, in `LineStrategy`.

**Speed never reaches `BeamConfig`.** It is applied to the clock, deliberately kept out of the config cache key, so a rate change rides through without re-resolving the config or rebuilding the phase resolver.

## Tests

| Directory | Covers |
| --- | --- |
| `test/models/` | Value objects, `BeamConfig.resolve`, palettes, colors, variants. |
| `test/animation/` | Clock, spring curve, oscillators, phases, travel, periods, and a seeded property test over `BeamPhaseResolver.sample`. |
| `test/painting/` | Ring geometry, color matrices, surface features, the saveLayer budget, degenerate geometry, and a paint smoke sweep. |
| `test/widget/` | `BorderBeam` itself: lifecycle, updates, shorthands, theming, sync, speed, progress, motion, cycle gap. |
| `test/widgets/` | The four widgets in `lib/src/widgets/`. |
| `test/golden/` | Golden families, one per axis — `beam_`, `palette_`, `motion_`, `surface_`, `widgets_`. |
| `test/constants/`, `test/fixtures/` | The transcription check against the extracted upstream fixtures. |

Golden scenes freeze the fake clock at a known time (t=1.3s — post fade-in, mid-cycle) for every variant × theme × palette, with the traveling variants captured a second time further along their sweep. Goldens are pinned to macOS rendering and to the Flutter version CI pins; regenerating on another OS or SDK produces diffs.
