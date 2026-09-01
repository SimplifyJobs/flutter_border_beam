# Changelog

## Unreleased

### Changed

- The package is named `flutter_border_beam`; the barrel is
  `package:flutter_border_beam/flutter_border_beam.dart`.
- The canonical repository is https://github.com/SimplifyJobs/flutter_border_beam.

## 0.1.0

Initial release — a faithful Flutter port of the [border-beam](https://github.com/Jakubantalik/border-beam) React library (v1.3.0) by Jakub Antalik.

### Features

- **Five beam variants** via named constructors, pixel-matched to the source:
  - `BorderBeam.rotate` — full border traveling beam (React `md`)
  - `BorderBeam.small` — compact traveling beam for buttons (React `sm`)
  - `BorderBeam.line` — bottom-edge traveling beam (React `line`)
  - `BorderBeam.pulseInside` — contained breathing glow (React `pulse-inner`)
  - `BorderBeam.pulseOutside` — outward-blooming halo (React `pulse-outside`)
- **Color system**: the four source presets (`colorful`, `mono`, `ocean`, `sunset`), `BeamColors.custom(List<Color>)` auto-distributed over the preset geometry, and an advanced `BeamColors.spec` for per-blob control.
- **Superellipse borders**: `useSuperellipse: true` shapes the beam as an Apple-style squircle (`RoundedSuperellipseBorder`, Flutter ≥ 3.35).
- **Playback control**: optional `BorderBeamController` (`start` / `stop` / `pause` / `resume` / `seek` / `speed`) with exclusive ownership, or declarative `active` + `autoPlay` / `startAfter` / `duration` scheduling.
- **Theming**: dark / light presets per variant, `BeamTheme.auto` follows `Theme.of(context)`.
- **Tuning hooks** ported from the source's CSS custom properties: `strength`, `brightness`, `saturation`, `hueRange`, `hueBase`, `staticColors`, layer opacity factors, and pulse glow overrides (`glowBoost`, `coreBlur`, `bloomBlur`, `glowBrightness`, `glowSaturation`).
- **Accessibility & performance**: honors `MediaQuery.disableAnimations`, pauses under `TickerMode`, spring-eased fades (`sprung`), single-`Ticker` engine with a ~30fps cap for pulse variants, `RepaintBoundary`-isolated painting (the child never re-rasterizes), and CPU hue folding to keep `saveLayer` counts at ≤3 per frame.
