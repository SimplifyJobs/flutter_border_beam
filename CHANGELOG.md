# Changelog

All notable changes to this package are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

This release tracks upstream [border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam)
**1.4.0**; the tables in `lib/src/constants/` are transcribed from that
version's `src/styles.ts`, whose spec still declares `1.3.0` as its visual
baseline. See [doc/parity.md](doc/parity.md) for the deviation list and how
the transcription is verified.

### Added

#### API

- `BorderBeam` has a public generic constructor taking a `BeamVariant`, so a
  variant chosen at runtime needs no switch over the five named ones.
- `BorderBeam.overlay` paints a beam with no child of its own, sized by its
  parent — drop it into a `Stack` under a `Positioned.fill` and it traces the
  stack's bounds.
- `BorderBeamTheme` supplies `BorderBeamThemeData` defaults to the beams below
  it, one slot per value object. `of` walks every enclosing scope, depends on
  each, and merges them outside-in, so nested themes compose.
- `BeamThemeConfig` is public, with `copyWith`, value equality, and
  `BeamThemeConfig.presetFor(variant, brightness)` to start from a preset.
- `BeamVariant.defaultHuePeriod` and `BeamVariant.defaultBloomHuePeriod`
  expose the per-variant hue timings the config resolves against.
- `BorderBeam` and `BeamPainter` implement `debugFillProperties`.

#### Palettes

- Seven Flutter-only presets: `aurora`, `neon`, `candy`, `ember`, `ice`,
  `gold` (hue pinned, full opacity) and `holographic` (built for pairing with
  a fast continuous hue drift). They live in `extra_palettes.dart`, separate
  from the transcribed tables.
- `BeamColors.custom` takes a `base` palette to distribute over.
- `BeamColors.fromSeed` derives a glow-safe palette from one brand color in
  four harmonies (`analogous`, `complementary`, `triadic`, `monochrome`),
  lifting derived colors into a readable lightness/saturation band.
- `BeamColors.fromScheme` builds a palette from a Material `ColorScheme`'s
  primary, secondary and tertiary roles, dropping near-duplicates.
- `BeamColors.lerp` blends two color choices per blob; `scaleAlpha` dims every
  table entry without touching layer opacity.

#### Shape

- `BeamShape.all(radius)` is the const path to a uniform radius — it stores
  the number instead of building a `BorderRadius`, so a theme or a widget can
  hold one in a `const` expression. It compares equal to
  `BeamShape.circular(radius)`.
- `BeamShape.edge` moves the line variant's beam to any `BeamEdge` (top,
  right, bottom, left).
- `BeamShape.ringOffset` pushes the ring outward or pulls it inward from the
  child's bounds.
- `BeamShape.contour` takes a `BeamContour` — an arbitrary closed path for the
  beam to travel, replacing the rounded rectangle, with a true normal offset
  for its inner ring. `BeamPathContour` wraps a `Path Function(Rect)` with an
  explicit equality key.

#### Style

- `BeamStyle.hueMode` picks the shape of the hue track: `BeamHueMode.pingPong`
  swings across ±`hueRange`, `BeamHueMode.continuous` revolves a full 360°.
  Traveling variants ping-pong and pulse variants revolve by default.
- `BeamStyle.tailLength` scales the traveling window about its head, and
  `BeamStyle.glowSpread` scales how far the bloom and halo layers reach past
  the ring.
- `BeamStyle.comet` re-aims the bloom into a halo trailing the rotate and
  small beams' head outside the ring; `BeamStyle.sparkle` scatters
  deterministic twinkles at that head, at a density of 0–1.
- `BeamStyle.segments` breaks the ring into that many evenly spaced dashes
  through a feathered conic mask; null keeps it solid.
- `BeamStyle.innerSizeScale` scales pulse-inside's inner wash: below 1 it
  pulls tighter to the border, above 1 it floods further in. The perimeter
  ring and the bloom keep their own geometry.
- `BeamStyle.renderScale` (0.25–1) paints the beam at that fraction of the box
  and magnifies it back, so a palette authored against a 350×140 card still
  reads on a screen-width one. One canvas transform, no extra layer.
- `BeamStyle.pulseOutsideStock` is a ready-made style carrying the upstream
  library's stock pulse-outside look — a tighter, dimmer halo — next to this
  package's default, which bakes the tuning the original's demo page applies.
  `BeamStyle.pulseOutsideTuning` (`BeamPulseOutsideTuning.demo` / `.stock`)
  switches the glow geometry alone.

#### Motion

- `BeamTiming.cycleGap` rests the traveling beam between sweeps.
- `BeamTiming.direction` runs the beam forward, reversed, or alternating each
  cycle (`BeamDirection`); reversed sweeps mirror the asymmetric stop tables
  at runtime, so the soft tail still trails the head.
- `BeamTiming.phaseOffset` starts the timeline part way through a cycle.
- `BeamTiming.beamCount` sends several beams around the contour at once,
  equally spaced — tiled into one sweep shader for rotate, one traveller per
  band for line.
- `BeamTiming.huePeriod`, `bloomHuePeriod`, `breatheFactor`, `spikeFactor`,
  and `spike2Factor` expose the timings that were fixed in the phase resolver.
- `BorderBeam.progress` drives the sweep from a value instead of the clock,
  turning `rotate` into a progress ring and `line` into a progress bar, with
  the clock still running underneath.
- `BorderBeam.follow` eases the sweep toward a normalized point in the box —
  critically damped, ~150ms — and hands it back to the clock without a snap.
- `BorderBeam.strengthListenable` and `BorderBeam.speedListenable` drive layer
  opacity and playback rate per frame without rebuilding.
- `BeamSync` runs every descendant beam off one shared clock: one ticker, one
  timeline, identical phases, with `active` and `speed` on the group.

#### Playback

- `BeamPlayback.repeat` stops the beam after a set number of cycles
  (`BeamRepeat.forever()`, `.once()`, `.count(n)`), fading out and firing
  `onDeactivate` rather than cutting mid-sweep.
- `BeamPlayback.reducedMotion` chooses what happens under
  `MediaQuery.disableAnimations`: `staticFrame` (the default), `hide` (no
  painter, no ticks), `slow` (quarter speed), or `animate` to ignore the ask.
- `BeamPlayback.pauseWhenOffscreen` (default true) stops the clock while the
  beam is more than 256px outside its nearest enclosing `Scrollable`, and
  resumes it exactly where it left off — play state, fade, and callbacks
  untouched. It does nothing when there is no enclosing scrollable.
- `BeamPlayback.fadeCurve` sets the easing both fade envelopes run on;
  `BeamPlayback.cssEase` is the web's `cubic-bezier(0.25, 0.1, 0.25, 1)`.
- `BeamPlayback.debugFrozenAt` pins the beam to one instant of its timeline,
  at full opacity, and never starts its clock — deterministic frames for
  goldens, docs captures, and design reviews.
- `BorderBeamController.pulse()` and `flash()` are one-shot brightness accents
  that ride the fade envelope without touching the timeline.

#### Widgets

- `BeamDecoration` paints a beam as a `Decoration`, for dropping into an
  existing `Container` or `DecoratedBox` — `foregroundDecoration` for the
  variants `BorderBeam` paints over its child, `decoration` for
  `pulseOutside`. It takes `brightness` and a `BorderBeamThemeData` as
  arguments, since a `BoxPainter` has no `BuildContext`.
- `BeamFocusRing` lights while the wrapped subtree, or a given `FocusNode`,
  holds focus, honoring `FocusManager.highlightMode`.
- `BeamHover` lights on hover and steers the sweep to the cursor through
  `BorderBeam.follow`, with a hold after exit.
- `BeamPress` lights while a finger is down, with a minimum duration, and
  never takes a gesture from its child.

### Changed

#### Naming & repository

- The package is named `flutter_border_beam`; the barrel is
  `package:flutter_border_beam/flutter_border_beam.dart`. The pub.dev name
  `border_beam` belongs to an unrelated package.
- The canonical repository is <https://github.com/SimplifyJobs/flutter_border_beam>,
  which `repository`, `issue_tracker`, and `homepage` now point at.
- `LICENSE` leads with the canonical MIT header so GitHub detects it, with the
  border-beam third-party notice preserved below.
- The pubspec gains a `screenshots:` section backed by PNGs shipped in
  `screenshots/`; `assets/` stays pub-ignored.

#### API

- `BorderBeam` takes four value objects instead of a flat parameter list:
  `BeamStyle` (colors, theme, filters, layer-opacity hooks, and a
  `themeConfig` that replaces the whole variant×brightness preset),
  `BeamShape` (per-corner radius, border width, superellipse, edge, ring
  offset, contour), `BeamTiming` (cycle, rest, speed, direction, hue periods,
  line track factors), and `BeamPlayback` (active, autoPlay, startAfter,
  duration, repeat, reduced motion). Every field is nullable and means
  *inherit*; `controller`, `onActivate`, and `onDeactivate` stay flat on the
  widget.
- `colors`, `active`, and `borderRadius` remain on the widget as shorthands
  for `style.colors`, `playback.active`, and a uniform `shape.radius`; a
  non-null shorthand wins over the same field in its object.
- Field resolution is one order throughout: flat shorthand, then the value
  object on the widget, then `BorderBeamTheme` (inner over outer), then the
  variant preset.

#### Shape

- Shapes are per-corner: `BeamShape.radius` is a `BorderRadiusGeometry`
  resolved against the ambient `Directionality`, clamped per corner the way
  `RRect.scaleRadii` clamps. `BeamShape.circular(r)` and `BeamShape.stadium()`
  cover the uniform and pill cases; a stadium rounds to half the shortest
  side, so a square box comes out a circle.

#### Motion

- `BeamTiming.cycleGap` rests the traveling beam between sweeps: the sweep
  still takes `cycle`, then the beam parks at the end of its travel while its
  fade envelope eases out and back in over `min(0.25s, gap / 2)` at each end.
  The pulse variants ignore it. Hue, breathe, and spike tracks keep running
  through the gap.
- `BeamTiming.speed` sets the playback rate when no controller is attached,
  and leaves the config-cache key entirely — a rate change no longer
  re-resolves the config or rebuilds the phase resolver.

#### Palettes

- `BeamColors`, `BeamPalette`, `BeamPresetData`, `BeamBlob`, and `LineBlob`
  are value types that compare structurally, and `resolve()` memoizes by value
  through a bounded LRU, so equal color choices share one `BeamPalette` and a
  palette rebuilt inline in `build()` hits the widget's config cache instead
  of re-deriving nine gradient tables.
- `BeamBlob` and `LineBlob` sizes are documented as the ellipse **radii** every
  painter already treats them as.

#### Engine

- The transcribed rotate stop tables, line geometry, and pulse constants moved
  into `lib/src/constants/`, with rendering unchanged.
- Every new style and shape option folds into layers each variant already
  composites, so the per-variant `saveLayer` budget holds under any
  combination.

### Removed

- `BeamPlayback.respectReducedMotion`, replaced by
  `BeamPlayback.reducedMotion`; `reducedMotion: BeamReducedMotion.animate` is
  what `respectReducedMotion: false` used to say.
- The `sprung` dependency. The fade envelope is eased by the in-package
  `FadeSpringCurve` (mass 1, stiffness 180, damping 20 — the same spring,
  reproduced bit-for-bit with a linear end correction so t=1 lands on 1), so
  the package depends on the Flutter SDK alone.
- The example app's boilerplate and its unused `cupertino_icons` dependency.

### Fixed

- A beam laid out thinner than twice its border width no longer asserts in
  `RRect` construction: `BeamRingGeometry` returns empty contours for empty or
  inverted rects, floors corner radii at zero, and paints the whole outer
  shape as the ring for sub-2px boxes.
- The reduced-motion static frame keeps the traveling variants' mid-cycle
  geometry but no longer samples the hue ping-pong, so it shows the palette's
  own colors, as documented.
- Changing `cycle` mid-run rescales the clock so every cycle-derived track
  keeps its fraction, while the fixed-period hue tracks are held by a
  resolver-side time offset — the beam speeds up or slows down without a snap,
  mid-fade included.
- Reduced motion is tracked where its change is delivered: turning it on
  pauses the clock, turning it off resumes only a pause it caused (a
  controller pause wins) or starts an autoplay beam that never got to run.
  `build` no longer mutates the clock.
- `BeamColors.spec` derives its fallback tables directly instead of through a
  throwaway custom palette, and the phase resolver resolves `PulseParams`
  once.

### Tooling & CI

- CI runs five independent jobs: format/analyze/test with coverage to Codecov
  (tokenless OIDC) and a publish dry-run on the pinned Flutter the goldens
  were rendered with; goldens on macOS with failure diffs uploaded as
  artifacts; the declared 3.35.0 lower bound built and tested as a hard gate;
  pana with a 20-point floor; and the example app analyzed, tested, and built
  for web.
- Pushing a `vX.Y.Z` tag runs `release.yaml`: it checks the tag against the
  pubspec and the changelog, re-runs the gate, publishes to pub.dev through
  `dart-lang/setup-dart`'s OIDC token, and creates the GitHub Release from
  that changelog section.
- The upstream library's machine-readable `spec/beam-spec.json` is vendored at
  `test/fixtures/beam-spec.json` (with its provenance in
  `test/fixtures/UPSTREAM`), refreshed by `tool/spec/refresh.sh`, and asserted
  table by table by `test/constants/spec_parity_test.dart`.
  `.github/workflows/upstream_drift.yaml` hashes upstream's `src/styles.ts`,
  so a styles change that never reached the spec generator still raises the
  alarm. `lib/src/constants/upstream.dart` records the tracked versions and
  the source repository in one place.
- Dependabot groups weekly action and pub bumps; `codecov.yml` keeps coverage
  informational.
- The example app exposes the whole API in an interactive playground with a
  shareable link, and is deployed to GitHub Pages.
- Tests: a counting canvas pins each variant's per-frame `saveLayer` count
  (rotate 4, small 3, line 4, pulseInside 4, pulseOutside 3) exactly, with
  save/restore balance; lifecycle tests prove no ticker outlives disposal
  mid-fade, a variant swap, `TickerMode`, or a controller that outlives its
  beam; boundary tests sweep degenerate boxes, radius and width extremes, and
  out-of-range parameters; seeded property tests check the phase resolver's
  purity, per-cycle periodicity, and field ranges; and the goldens cover every
  variant × theme × palette, with a later freeze for the two traveling
  variants.

### Docs

- The README is rebuilt around a per-concept structure, with a full field
  table (default and applicable variants) for each of the four value objects,
  and sections for accessibility, performance, upstream parity, and how the
  engine works.
- New guides in [`doc/`](doc): variants, palettes, shape, motion, theming,
  performance, accessibility, parity, and architecture.
- `CLAUDE.md` keeps the commands and hard rules and points at
  [doc/architecture.md](doc/architecture.md) for the module deep-dive.

## 0.1.0

Initial release — a faithful Flutter port of the [border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam) React library by Jakub Antalik.

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
- **Accessibility & performance**: honors `MediaQuery.disableAnimations`, pauses under `TickerMode`, spring-eased fades (`sprung`), single-`Ticker` engine with a ~30fps cap for pulse variants, `RepaintBoundary`-isolated painting (the child never re-rasterizes), and CPU hue folding to keep `saveLayer` counts low.
