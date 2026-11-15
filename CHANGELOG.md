# Changelog

All notable changes to this package are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 0.2.0

A new renderer and a new effect model. This is the first release since 0.1.0
and includes everything developed in between, so it breaks the API: the
[migration table](#migrating-to-020) maps every removed name to its
replacement.

### Why the renderer changed

0.1 reproduced the React [border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam)
library's CSS layer stack on Flutter's canvas: per frame, several `saveLayer`s
(each an offscreen render target), Gaussian blurs through `ImageFilter` and
`MaskFilter` (each a separate pass), path clips, and freshly built gradients.
A beam left running on a card kept the GPU busy enough to heat a phone, and
the pulse variants ran at a capped ~30fps, as the original's pulse driver does.

0.2.0 draws every effect with **one fragment shader in a single pass**:

- one `drawRect` / `drawDRRect` per frame — no `saveLayer`, no clip, no
  `ImageFilter` or `MaskFilter`, no offscreen target;
- glows (the bloom around the stroke, the outer halo, light reaching inward)
  evaluated analytically per pixel instead of blurred;
- fragment work limited to the band where light can land;
- per frame, the CPU fills a fixed block of uniforms in a `FragmentShader`
  reused for the beam's lifetime — no path or gradient construction;
- every effect at the display's refresh rate, 120Hz included.

With that, the package is no longer a port. It was originally ported from
border-beam and remains inspired by it, but 0.2.0 is an independent native
renderer: it does not track the original's source, and its constants are
design data rather than transcriptions.

### Added

#### Renderer

- `shaders/beam.frag`, declared under `flutter: shaders:` and bundled with the
  package; nothing to add to an app's pubspec.
- `BorderBeam.precache()` loads the shader ahead of the first beam — in `main`
  for a ready first frame, and in tests before reading pixels.

#### Effects

- `BeamEffect`, a sealed value type chosen with `effect:` on `BorderBeam`,
  `BorderBeam.overlay`, `BeamDecoration`, `BeamFocusRing`, `BeamHover`, and
  `BeamPress`, and as a default with `BorderBeamThemeData.effect`. Eight
  effects:
  - `BeamEffect.rotate({length, count, comet})` — a beam laps the border.
  - `BeamEffect.line({edge})` — a streak rides one edge with spikes of light.
  - `BeamEffect.pulse()` — colour breathes inward from the border.
  - `BeamEffect.halo()` — light breathes outward around the widget.
  - **New:** `BeamEffect.flow()` — colours stream round the border with an
    inner glow that swells and ebbs.
  - **New:** `BeamEffect.spin()` — a full gradient ring spins around the
    border.
  - **New:** `BeamEffect.shimmer({angle})` — a glint sweeps across, then
    rests.
  - **New:** `BeamEffect.charge()` — the border fills clockwise with a hot
    leading edge; drive it with `BorderBeam.progress` for determinate
    progress.
- `BeamEffect.values`, and per effect `travels`, `defaultCycle`,
  `defaultCycleGap`, `defaultHueMode`, and `defaultHuePeriod`.

#### Palettes

- Palettes are rings of 1–8 colour stops: `BeamColors(colors, {stops})` places
  colours evenly or at chosen perimeter positions, and `BeamColors.solid(color)`
  is one colour all the way round.
- 15 presets beyond 0.1.0's four, 19 in all: `aurora`, `neon`, `candy`,
  `ember`, `ice`, `gold`, `holographic`, and, new in this release, `lagoon`,
  `dusk`, `forest`, `rose`, `cosmic`, `citrus`, `sky`, and `lavender`.
  `BeamColors.presets` maps every name to its palette.
- `BeamColors.fromSeed` (four harmonies), `BeamColors.fromScheme`,
  `BeamColors.lerp`, and `scaleAlpha`.

#### API since 0.1.0

- Four value objects replace the flat parameter list: `BeamStyle`
  (`colors`, `theme`, `strength`, `glow`, `hueShift`, `hueMode`, `hueBase`),
  `BeamShape` (`radius`, `superellipse`, `borderWidth`, `ringOffset`,
  `segment`, `dashes`; `.all`, `.circular`, `.stadium`), `BeamTiming`
  (`cycle`, `cycleGap`, `speed`, `direction`, `phaseOffset`, `huePeriod`), and
  `BeamPlayback` (`active`, `autoPlay`, `startAfter`, `duration`, `repeat`,
  `reducedMotion`, `pauseWhenOffscreen`, `fadeCurve`, `debugFrozenAt`). Every
  field is nullable and means *inherit*; `colors`, `active`, and
  `borderRadius` stay on the widget as shorthands.
- `BorderBeamTheme` / `BorderBeamThemeData` supply defaults to a subtree;
  nested themes merge field by field.
- `BorderBeam.overlay` paints a beam with no child, sized by its parent.
- `BeamSync` runs a subtree's beams off one clock.
- `BorderBeam.progress`, `follow`, `strengthListenable`, and
  `speedListenable` drive the beam without a controller.
- `BeamShape.segment` with `BeamSegment`, `BeamAnchor`, and `BeamCorner`
  lights part of the border; `BeamShape.dashes` breaks it into dashes;
  per-corner, direction-aware radii; stadiums; `ringOffset`.
- `BeamTiming.cycleGap`, `direction` (`forward` / `reverse` / `bounce`), and
  `phaseOffset`; `BeamStyle.hueMode` (`pingPong` / `continuous` / `none`).
- `BeamPlayback.repeat`, four `reducedMotion` behaviours (`staticFrame`,
  `hide`, `slow`, `animate`), `pauseWhenOffscreen`, `fadeCurve` with
  `BeamPlayback.cssEase`, and `debugFrozenAt`.
- `BorderBeamController.pulse()` and `flash()`, one-shot brightness accents.
- `BeamDecoration`, and the `BeamFocusRing`, `BeamHover`, and `BeamPress`
  wrappers.

### Changed

- **Package name.** The package is `flutter_border_beam`; import
  `package:flutter_border_beam/flutter_border_beam.dart`.
- **Every effect is re-tuned for the shader.** The look is close to 0.1's and
  in places richer, but it is not pixel-matched to the original, and every
  golden was regenerated.
- **`pulseOutside` is `halo`.** It paints in the same single pass over the
  child as every other effect — a thin stroke on the border and its glow
  outside it — so the child no longer has to be opaque, and a
  `BeamDecoration` halo goes in `foregroundDecoration:` like every other
  effect.
- **`small` is folded into `rotate`.** `rotate`'s glow scales with the box, so
  one effect reads on a chip and on a full-screen surface. The default radius
  is 16 for every effect.
- **`pulseInside` is `pulse`.**
- **Default timings:** `rotate`'s cycle is 2.4s (was 1.96s); `line` has one
  8s hue period (was 12s with a separate 8s bloom track) and no longer caps
  its hue swing at 13°.
- **Palettes are stop rings, not blob tables.** The four original presets and
  the seven extras are re-derived as stops from where 0.1 placed their glows.
  `mono`'s halved layer opacity is now automatic for any grey palette.
- **`BeamColors.lerp`** clamps `t` to 0–1 and mixes gamma-aware at eight
  sampled positions; **`scaleAlpha`** scales each stop's alpha.
- **`hueRange` is `hueShift`.**
- **Every effect runs at the display rate**; the pulse variants' ~30fps cap is
  gone.
- **Superellipse corners** are computed in the shader, from a p-norm curve
  fitted to Flutter's `RSuperellipse`.
- **`BeamFocusRing`** defaults to `BeamEffect.spin()` (was `small`);
  **`BeamPress`** defaults to `BeamEffect.pulse()` (was `pulseInside`).

### Removed

- `BeamVariant` and the named constructors `BorderBeam.rotate`, `.small`,
  `.line`, `.pulseInside`, and `.pulseOutside` — use `effect:`.
- `BeamThemeConfig`, `BeamBlob`, `LineBlob`, `BeamColors.custom`,
  `BeamColors.spec`, `BeamContour`, `BeamPathContour`,
  `BeamPulseOutsideTuning`, and `BeamStyle.pulseOutsideStock`.
- `BeamStyle`: `brightness`, `saturation`, `staticColors`,
  `strokeOpacityFactor`, `innerOpacityFactor`, `bloomOpacityFactor`,
  `glowBoost`, `coreBlur`, `bloomBlur`, `glowBrightness`, `glowSaturation`,
  `tailLength`, `glowSpread`, `comet`, `sparkle`, `segments`,
  `innerSizeScale`, `renderScale`, `pulseOutsideTuning`, and `themeConfig`.
- `BeamShape`: `edge`, `contour`, and `wrapCorners`. Outlines are rounded
  rectangles with circular or superellipse corners; arbitrary paths are not
  supported.
- `BeamTiming`: `beamCount`, `bloomHuePeriod`, `breatheFactor`,
  `spikeFactor`, and `spike2Factor`.
- The frame-rate cap on the pulse variants.
- The transcribed upstream constants (`lib/src/constants/`), the vendored
  upstream spec and its parity test, `tool/spec/`, and the upstream-drift
  workflow.

### Migrating to 0.2.0

| Before | 0.2.0 |
| --- | --- |
| `import 'package:border_beam/border_beam.dart'` | `import 'package:flutter_border_beam/flutter_border_beam.dart'` |
| `BorderBeam.rotate(…)` | `BorderBeam(…)` — `rotate` is the default — or `BorderBeam(effect: const BeamEffect.rotate(), …)` |
| `BorderBeam.small(…)` | `BorderBeam(effect: const BeamEffect.rotate(), borderRadius: 32, …)` — set the radius you relied on; the default is 16 |
| `BorderBeam.line(…)` | `BorderBeam(effect: const BeamEffect.line(), …)` |
| `BorderBeam.pulseInside(…)` | `BorderBeam(effect: const BeamEffect.pulse(), …)` |
| `BorderBeam.pulseOutside(…)` | `BorderBeam(effect: const BeamEffect.halo(), …)` — the child may be translucent |
| `BorderBeam(variant: BeamVariant.x, …)` | `BorderBeam(effect: const BeamEffect.x(), …)` |
| `BeamDecoration(variant: …)` | `BeamDecoration(effect: …)`, in `foregroundDecoration:` for every effect |
| `BeamFocusRing` / `BeamHover` / `BeamPress` `(variant: …)` | `(effect: …)` |
| `BeamVariant.defaultHuePeriod` and friends | `BeamEffect.defaultHuePeriod`, `defaultCycle`, `defaultCycleGap`, `defaultHueMode` |
| `BeamShape(edge: e)` | `BeamEffect.line(edge: e)` |
| `BeamShape(wrapCorners: true)` on a line | `BeamShape(segment: BeamSegment.bottomEdge)` (or the preset for your edge) with `BeamEffect.line()` |
| `BeamShape(contour: …)`, `BeamContour`, `BeamPathContour` | no replacement |
| `BeamStyle(tailLength: x)` | `BeamEffect.rotate(length: x)` |
| `BeamStyle(comet: true)` | `BeamEffect.rotate(comet: true)` |
| `BeamTiming(beamCount: n)` | `BeamEffect.rotate(count: n)` (1–4) |
| `BeamStyle(segments: n)` | `BeamShape(dashes: n)` |
| `BeamStyle(glowSpread: x)` | `BeamStyle(glow: x)` |
| `glowBoost`, `coreBlur`, `bloomBlur`, `glowBrightness`, `glowSaturation`, `innerSizeScale` | `BeamStyle(glow: …)` |
| `strokeOpacityFactor`, `innerOpacityFactor`, `bloomOpacityFactor` | `BeamStyle(strength: …)` for the whole beam, `glow` for the glows |
| `hueRange: x` | `BeamStyle(hueShift: x)` |
| `staticColors: true` | `BeamStyle(hueMode: BeamHueMode.none)` |
| `brightness:`, `saturation:` | no replacement — adjust the palette's colours; `hueBase` still rotates the hue |
| `sparkle`, `renderScale` | no replacement; glows scale with the box |
| `themeConfig`, `BeamThemeConfig` | no replacement — `theme`, `strength`, and `glow` |
| `pulseOutsideTuning`, `BeamPulseOutsideTuning`, `BeamStyle.pulseOutsideStock` | no replacement |
| `bloomHuePeriod`, `breatheFactor`, `spikeFactor`, `spike2Factor` | no replacement; `huePeriod` sets the one hue track |
| `BeamColors.custom(colors)` / `custom(colors, base: …)` | `BeamColors(colors)`, optionally with `stops:` |
| `BeamColors.spec(…)`, `BeamBlob`, `LineBlob` | `BeamColors(colors, stops: …)` |
| 0.1.0 `useSuperellipse: true` | `shape: const BeamShape(superellipse: true)` |
| 0.1.0 `borderWidth:` | `shape: BeamShape(borderWidth: …)` |
| 0.1.0 `cycleDuration: d` | `timing: BeamTiming(cycle: d)` |
| 0.1.0 `strength:`, `theme:`, `hueBase:` | `style: BeamStyle(…)` |
| 0.1.0 `autoPlay:`, `startAfter:`, `duration:` | `playback: BeamPlayback(…)` |
| 0.1.0 `respectReducedMotion: false` | `playback: const BeamPlayback(reducedMotion: BeamReducedMotion.animate)` |

### Tooling & CI

- CI pins Flutter 3.47.4, the SDK the goldens are generated on; the `min-sdk`
  job still builds and tests the declared 3.35.0 lower bound.
- `test/render/` holds the renderer's contracts: the frame budget (one draw,
  no `saveLayer`, clip, or image / mask filter), the uniform layout (parsed
  from `shaders/beam.frag` against `beamUniformFloats`), the Dart outline
  mirror, per-effect emission sanity, degenerate geometry, a paint smoke sweep
  through the real shader, and where light lands.
- Golden families: `beam_`, `palette_`, `motion_`, `surface_`, `widgets_`.
- Removed the upstream spec parity test, its fixtures, `tool/spec/`, and
  `.github/workflows/upstream_drift.yaml`.
- CI runs format / analyze / test with coverage, macOS goldens, the minimum
  SDK, pana, and the example app; pushing a `vX.Y.Z` tag publishes through
  `release.yaml` over GitHub OIDC.

### Docs

- README rewritten for the effect model and the shader renderer, with a
  Performance section (one draw, 120Hz setup, `precache`, Impeller notes).
- [`doc/effects.md`](doc/effects.md) replaces `doc/variants.md`;
  `doc/parity.md` is gone; [`doc/architecture.md`](doc/architecture.md)
  describes the frame pipeline, the light model, and the Dart / shader
  contracts.

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
