# flutter_border_beam — agent guide

Flutter package: animated border beam effects. A faithful port of the
[border-beam](https://github.com/Jakubantalik/border-beam) React library
(v1.3.0, MIT, by Jakub Antalik).

## Commands

- `flutter analyze` — must stay at zero issues (lints include `public_member_api_docs`).
- `flutter test` — full suite (unit + widget + smoke + goldens).
- `flutter test --exclude-tags golden` — everything except goldens (use on non-macOS).
- `flutter test --update-goldens --tags golden` — regenerate goldens (macOS only; goldens are pinned to macOS rendering).
- `dart format .` — formatting.
- `cd example && flutter run` — demo gallery app (React-demo-styled; tokens in `example/lib/src/demo_theme.dart`).
- `tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact` — record a demo reel mp4 into `.demos/` (needs a booted iOS simulator + ffmpeg). Reels use `example/lib/demo_harness.dart`'s marker contract (`<PREFIX>:<name>:START/END`, `<PREFIX>:DONE`); new reels are just a map of name → scene widget.
- `dart pub publish --dry-run` — pre-publish validation.

## Architecture

Everything animated is a **pure function of elapsed time** — one `Ticker` per
widget (`BeamClock`), mirroring the React library's single shared rAF loop.
No `AnimationController`s; phases are recomputed from `elapsedSeconds` each
frame.

- `lib/flutter_border_beam.dart` — barrel; ONLY `BorderBeam`, `BorderBeamController`, `BeamVariant`, `BeamColors`, `BeamBlob`/`LineBlob`, `BeamTheme` are public.
- `lib/src/border_beam.dart` — widget, 5 named constructors, scheduling/lifecycle. Controller attached ⇒ it owns playback exclusively (asserts `startAfter`/`duration` are null).
- `lib/src/animation/` — `beam_clock.dart` (ticker, speed, pause, spring fades via `spring_curve.dart`, optional fps cap), `oscillator.dart` (pingPong + the 17-oscillator pulse bank), `beam_phases.dart` (per-frame value object + keyframe sampling).
- `lib/src/painting/` — `beam_painter.dart` (one `CustomPainter`, repaint driven by the clock, `behind`/`above` passes), `strategies/` (one per variant family), `ring_geometry.dart` (rrect + `RSuperellipse` ring via `Path.combine` difference), `gradient_builders.dart`, `color_matrix.dart` (hue/brightness/saturation matrices), `layer_utils.dart`.
- `lib/src/constants/` — **verbatim transcriptions** of the React source's tables (`palettes.dart`, `theme_presets.dart`, `pulse_tables.dart`, `pulse_params.dart`, `line_keyframes.dart`).
- `lib/src/models/` — public/internal data types; `BeamConfig.resolve` mirrors the React component's computed values (per-variant default durations, the line 13° hue cap, mono forcing static colors).

## Hard rules

1. **Never tweak values in `lib/src/constants/`** — they are transcribed 1:1 from `src/styles.ts` of the React source (clone: `git clone https://github.com/Jakubantalik/border-beam /tmp/border-beam-react`). Visual parity depends on them. If a value looks wrong, verify against the source first.
2. **saveLayer budget: ≤3 per frame per variant.** Hue/brightness/saturation are folded into gradient colors on the CPU (`BeamColorMatrix.transform`) — do not introduce per-layer `ColorFilter` saveLayers. Blur layers are the only place filter saveLayers are allowed.
3. **CSS↔Flutter mapping conventions** (see `gradient_builders.dart`): CSS conic gradients start at 12 o'clock — `SweepGradient` needs the −90° rotation baked in; CSS `radial-gradient(ellipse W H ...)` sizes are RADII; CSS `filter: blur(Npx)` maps to sigma = N; gradient fades to `color.withValues(alpha: 0)` (never `Color(0x00000000)`, which lerps through black).
4. Layer opacity is a multiplied chain (fade × preset × mono × hook × strength), clamped at paint time — presets legitimately exceed 1 (line/dark stroke = 1.14).
5. The line variant does NOT use the mono ×0.5 opacity multiplier; its mono treatment is spike attenuation inside the bloom (see `LineStrategy._paintSpikes`).

## Testing conventions

- Golden scenes freeze the fake test clock at t=1.3s (post fade-in, mid-cycle); regenerating on a different OS will produce diffs — keep goldens macOS-generated.
- `test/painting/paint_smoke_test.dart` sweeps every variant×theme×palette×shape for "paints without throwing, produces pixels" — extend it when adding paint paths.
- Ticker tests: the first tick after `Ticker.start()` reports elapsed 0 — pump once before pumping durations.
