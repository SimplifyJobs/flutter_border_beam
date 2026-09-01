# Changelog

## Unreleased

### Added

- `BeamStyle.hueMode` picks the shape of the hue track: `BeamHueMode.pingPong`
  swings across ±`hueRange`, `BeamHueMode.continuous` revolves a full 360°.
  Traveling variants ping-pong, pulse variants revolve, as before.
- `BeamStyle.tailLength` stretches or shortens the traveling window's tail,
  and `BeamStyle.glowSpread` scales how far the bloom and halo layers reach
  past the ring.
- `BeamStyle.comet` trails a soft halo outside the ring behind the rotate and
  small beams' head; `BeamStyle.sparkle` scatters twinkles at that head, at a
  density of 0–1.
- `BeamStyle.segments` breaks the ring into that many evenly spaced dashes;
  null keeps it solid.
- `BeamShape.all(radius)` is the const path to a uniform radius — it stores
  the number instead of building a `BorderRadius`, so a theme or a widget can
  hold one in a `const` expression. It compares equal to
  `BeamShape.circular(radius)`.
- `BeamShape.edge` moves the line variant's beam to any `BeamEdge` (top,
  right, bottom, left); `BeamShape.ringOffset` pushes the ring outward or
  pulls it inward from the child's bounds.
- `BeamShape.contour` takes a `BeamContour` — an arbitrary closed path for the
  beam to travel, replacing the rounded rectangle. `BeamPathContour` wraps a
  `Path Function(Rect)` with an explicit equality key.
- `BeamTiming.direction` runs the beam forward, reversed, or alternating each
  cycle (`BeamDirection`); `BeamTiming.phaseOffset` starts the timeline part
  way through a cycle; `BeamTiming.beamCount` sends several beams around the
  contour at once, equally spaced.
- `BeamPlayback.repeat` stops the beam after a set number of cycles
  (`BeamRepeat.forever()`, `.once()`, `.count(n)`).
- `BeamPlayback.reducedMotion` chooses what happens under
  `MediaQuery.disableAnimations`: `staticFrame` (the default), `hide`, `slow`
  (quarter speed), or `animate` to ignore the request.
- `BeamVariant.defaultHuePeriod` and `BeamVariant.defaultBloomHuePeriod`
  expose the per-variant hue timings the config resolves against.

### Changed

- The package is named `flutter_border_beam`; the barrel is
  `package:flutter_border_beam/flutter_border_beam.dart`.
- The canonical repository is https://github.com/SimplifyJobs/flutter_border_beam.
- `BorderBeam` takes four value objects instead of a flat parameter list:
  `BeamStyle` (colors, theme, filters, layer-opacity hooks, and a
  `themeConfig` that replaces the whole variant×brightness preset),
  `BeamShape` (per-corner radius, border width, superellipse), `BeamTiming`
  (cycle, rest, speed, hue periods, line track factors), and `BeamPlayback`
  (active, autoPlay, startAfter, duration, reduced motion). Every field is
  nullable and means *inherit*; `controller`, `onActivate`, and `onDeactivate`
  stay flat on the widget.
- `colors`, `active`, and `borderRadius` remain on the widget as shorthands
  for `style.colors`, `playback.active`, and a uniform `shape.radius`; a
  non-null shorthand wins over the same field in its object.
- `BorderBeam` has a public generic constructor taking a `BeamVariant`, so a
  variant chosen at runtime no longer needs a switch over the five named ones.
- `BorderBeamTheme` supplies `BorderBeamThemeData` defaults to the beams below
  it. Resolution order is widget → theme → variant preset, and nested themes
  merge inner over outer.
- Shapes are per-corner: `BeamShape.radius` is a `BorderRadiusGeometry`
  resolved against the ambient `Directionality`, clamped per corner the way
  `RRect.scaleRadii` clamps. `BeamShape.circular(r)` and `BeamShape.stadium()`
  cover the uniform and pill cases; a stadium rounds to half the shortest side,
  so a square box comes out a circle.
- `BeamTiming.cycleGap` rests the traveling beam between sweeps: the sweep
  still takes `cycle`, then the beam parks at the end of its travel while its
  fade envelope eases out and back in over `min(0.25s, gap / 2)` at each end.
  The pulse variants ignore it. `BeamTiming.speed` sets the playback rate when
  no controller is attached; `huePeriod`, `bloomHuePeriod`, `breatheFactor`,
  `spikeFactor`, and `spike2Factor` expose the timings that were fixed in the
  phase resolver.
- `BeamThemeConfig` is public, with `copyWith`, value equality, and
  `BeamThemeConfig.presetFor(variant, brightness)` to start from a preset.

### Removed

- `BeamPlayback.respectReducedMotion`, replaced by
  `BeamPlayback.reducedMotion`; `reducedMotion: BeamReducedMotion.animate` is
  what `respectReducedMotion: false` used to say.
- The `sprung` dependency. The fade envelope is eased by the in-package
  `FadeSpringCurve` (mass 1, stiffness 180, damping 20 — the same spring),
  so the package depends on the Flutter SDK alone.

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
