# prismatic docs — index

The reference for agents (Claude Code, Codex) and anyone who wants the
details. The root `README.md` is a short introduction for people; everything
it leaves out is here. Repo rules, commands and the full source map are in
[`AGENTS.md`](../AGENTS.md).

## Which file answers what

| Question | File |
| --- | --- |
| How do I use `BorderBeam`? Constructor, value objects and defaults, precedence, controller, `BeamSync`, `BeamDecoration`, wrappers, pitfalls | [border_beam_usage.md](border_beam_usage.md) |
| What do `rotate`, `line`, `pulse` do, and which inputs does each read? | [effects.md](effects.md) |
| Presets, custom stops, `fromSeed`, `fromScheme`, `lerp`, `scaleAlpha`, hue drift, palette equality | [palettes.md](palettes.md) |
| Radii, superellipse, stadium, `borderWidth`, `ringOffset`, segments and anchors, dashes | [shape.md](shape.md) |
| Clock, speed, retiming, `cycleGap`, direction, `BeamSync`, `progress`, `follow`, listenables, accents | [motion.md](motion.md) |
| `BeamTheme` (surface tuning) vs `BorderBeamTheme` (subtree defaults), merging | [theming.md](theming.md) |
| How is a beam frame rendered? Layer model, uniform layout, `BeamOutline`, invariants, tests | [architecture.md](architecture.md) |
| How do I use `DistortionWave` / `DistortionWaveRoute`? Sources and anchors, controller, theme, types, palettes, every style field, snapshots, display corners, fallbacks | [distortion_wave_usage.md](distortion_wave_usage.md) |
| How is a wave frame rendered? Timeline, phases, pictures, shader, uniform block, route, invariants, tests | [distortion_wave.md](distortion_wave.md) |
| Reduced motion, semantics, focus, touches — both effects | [accessibility.md](accessibility.md) |
| Frame cost, 120 Hz, offscreen ancestors, snapshot costs — both effects | [performance.md](performance.md) |

## Package facts

- **Libraries.** `package:prismatic/prismatic.dart` re-exports both
  `package:prismatic/border_beam.dart` and
  `package:prismatic/distortion_wave.dart`; each effect can be imported
  alone. Their export lists are in the two usage files.
- **Requirements.** Read `pubspec.yaml` (`environment:`, `dependencies:`):
  a Flutter floor (tested by CI's `min-sdk` job), a Dart SDK constraint, and
  one dependency, `material_ui` (Material without the deprecated
  `package:flutter/material.dart`).
- **Shaders.** `shaders/beam.frag`, `shaders/wave.frag` and
  `shaders/wave_glow.frag` are declared under `flutter: shaders:` in the
  package's pubspec, so a consuming app adds nothing; `shaders/common/*.glsl`
  are includes. Each program is loaded once per process (`ShaderProgram`,
  `lib/src/core/shader_program.dart`). `BorderBeam.precache()` and
  `DistortionWave.precache()` load them ahead of first use.
- **Renderers.** Built for Impeller; the shaders are SkSL strict ES2, so both
  effects also run on Skia and the web.
- **Example app.** `example/` — the showcase, also the live demo at
  <https://simplifyjobs.github.io/prismatic/>. Commands in `AGENTS.md`.

## Conventions shared by both effects

- **All-nullable value objects.** `BeamStyle`, `BeamShape`, `BeamTiming`,
  `BeamPlayback`, `WaveStyle` and its groups: `const`, value-equal,
  `copyWith` (null keeps) and `merge` (the argument's non-null fields win).
  Null means *inherit*.
- **Precedence**, per field: widget shorthand > the widget's value object >
  the nearest theme (`BorderBeamTheme` / `DistortionWaveTheme`; every
  enclosing theme merged, inner over outer) > the effect's or wave type's
  defaults.
- **Pure functions of one number.** A beam's frame is a function of elapsed
  time (`BeamClock`); a wave's of progress 0–1 (`WaveFrame.at`). That is what
  makes `BeamPlayback.debugFrozenAt`, `DistortionWave.progress`, scrubbing and
  goldens possible.
- **A fixed draw budget.** A lit beam frame is one shader draw. A wave frame
  that bends content is one shader draw plus at most one atlas draw. Tests
  enforce both.
- **Validation in release.** Constructors assert ranges in debug; resolution
  re-checks in release — the beam throws `ArgumentError` on invalid timing,
  speed, repeat or palette (`models/model_validation.dart`), the wave settles
  every value to a finite, in-range one (`WaveSpec`).
- **Reduced motion is honoured by default.** A beam shows a static frame; a
  wave becomes a short crossfade.
- **No semantics of their own, never a hit target.** A beam passes hits and
  semantics straight through to its child; a wave routes them to the side
  that is on screen (or being headed for) — see
  [accessibility.md](accessibility.md).

## Writing these docs

- Describe how the code works now, with real API names and file paths.
- Don't quote tuned look values — they live in `lib/src/border_beam/look/`,
  the emitters, `animation/spring_curve.dart`, and
  `lib/src/distortion_wave/look/wave_defaults.dart`, and they change. Name
  the constant or getter instead. API defaults that are part of the contract
  (a 16 px default radius, a 0.3 s reduced-motion crossfade) are fine.
- Change a usage file with the public API it describes; change an internals
  file with the pipeline, uniform layout or module it describes.
