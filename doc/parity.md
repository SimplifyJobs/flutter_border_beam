# Parity with the original

This package is a port, not an interpretation. The visual constants come from the source, and the deviations are deliberate, few, and listed here.

Tracked upstream: **[border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam) 1.4.0**, MIT, by [Jakub Antalik](https://x.com/jakubantalik). That npm release is visually identical to 1.3.0, and its machine-readable spec still declares `1.3.0` as the visual baseline — which is the number `upstreamLibraryVersion` records, because it is the one the tables are audited against.

## Where the constants come from

Everything in `lib/src/constants/` is a **verbatim transcription** of the tables in the source's `src/styles.ts`:

| File | Upstream content |
| --- | --- |
| `palettes.dart` | the four preset blob tables (`colorful`, `mono`, `ocean`, `sunset`) |
| `theme_presets.dart` | `sizeThemePresets` — layer opacities, inset shadows, filter multipliers per variant × brightness |
| `pulse_params.dart` | `pulseParams` — breathing parameters per variant, theme, and cycle length |
| `pulse_tables.dart` | the pulse blob tables and their oscillator/quadrant assignments |
| `pulse_constants.dart` | the pulse engine's fixed scalars |
| `line_keyframes.dart` | the line variant's keyframe tracks |
| `line_geometry.dart` | the line variant's blob geometry |
| `rotate_stops.dart` | the rotate/small gradient stops |

`extra_palettes.dart` is the one file in that directory that is **not** a transcription: it holds the seven Flutter-only presets, defined as short color lists distributed over `colorful`'s geometry. Editing it changes how those presets look and has no bearing on parity.

`upstream.dart` records the provenance of the whole directory — `upstreamLibraryVersion`, `upstreamSpecVersion`, and `upstreamRepository`. It is internal (the barrel does not export it) and is the single place those strings live, so the parity test reads them rather than restating them.

**Never tweak a value in `lib/src/constants/`.** Visual parity depends on them, and a value that looks wrong is far more likely to be a transcription that is right for a reason. Verify against the source before changing anything:

```console
git clone https://github.com/Jakubantalik/Libraries /tmp/border-beam-upstream
```

## How the transcription is verified

Transcription is exactly the kind of work a human does badly and a test does well, so it is not left to review.

The upstream library ships a machine-readable `spec/beam-spec.json` generated from its `src/styles.ts`. That file is vendored, byte for byte, at `test/fixtures/beam-spec.json`, with its provenance (commit, versions, and a SHA-256 of the `src/styles.ts` it was generated from) alongside it in `test/fixtures/UPSTREAM`. `test/constants/spec_parity_test.dart` reads the fixture and asserts every table in `lib/src/constants/` against it, entry by entry — handling the conventions that differ between the two worlds along the way: CSS `rgb()`/`rgba()` colors, `"33% -7.4%"` positions as fractional offsets, `"70px 40px"` sizes as **radii**, and percent stops against fractional ones.

Refreshing the fixture is one command:

```console
tool/spec/refresh.sh              # from upstream main
tool/spec/refresh.sh <tag|sha>    # from a specific ref
```

It is idempotent, so re-running against an unchanged upstream leaves the tree untouched. Afterwards, re-read `upstream.dart` — its version strings are hand-maintained — and run `flutter test test/constants/spec_parity_test.dart`.

`.github/workflows/upstream_drift.yaml` watches the hash: a change to upstream's `src/styles.ts` that never reached the spec generator still raises the alarm.

A drifted constant therefore fails a unit test rather than a golden, which means it *names* the value instead of showing a diff of blurry pixels. And when the test does fail, the fix is to re-audit against `src/styles.ts` and report the divergence — **never** to change a constant until the test passes.

The goldens are the second layer. `test/golden/` freezes the fake clock at a known time and captures every variant × theme × palette, with the traveling variants captured a second time further along their sweep. They catch changes in how the values are *used*, where the constant test catches changes in the values themselves.


## Deliberate deviations

### Fade envelope: a spring, not CSS `ease`

Activation and deactivation fade over 0.6s and 0.5s. The original eases them with CSS `ease`; this package eases them with a spring (mass 1, stiffness 180, damping 20), which settles more naturally under interruption — a beam toggled off mid-fade-in carries its velocity instead of restarting a curve.

For an exact match, `BeamPlayback.cssEase` is `cubic-bezier(0.25, 0.1, 0.25, 1)`:

```dart
BorderBeam.rotate(
  playback: const BeamPlayback(fadeCurve: BeamPlayback.cssEase),
  child: card,
);
```

`fadeCurve` accepts any `Curve`, so the envelope is fully yours.

### Reduced motion: all five variants

The original applies reduced motion to the pulse variants only, and its web build hides them; the iOS and React Native ports do the same. This package applies it to all five and defaults to a **static frame** rather than hiding — a beam that vanishes takes its meaning with it, while a still frame keeps marking the state. `BeamReducedMotion.hide` restores the upstream web behavior. See [accessibility](accessibility.md).

### pulse-outside defaults

The original's demo page applies its own tuning on top of the library's pulse-outside defaults — insets and blurs scaled by the element's size, melting the separate blobs into one continuous edge-hugging glow, plus a prominence boost and a glow multiplier. That tuned look is what people recognize as "the pulse-outside effect", so it is what `BorderBeam.pulseOutside` ships.

`BeamStyle.pulseOutsideStock` rolls all of it back — the boost and multiplier through the hooks that carry them (`glowBoost`, the three opacity factors, `glowBrightness`/`glowSaturation`) and the geometry through `pulseOutsideTuning` — leaving the library's own defaults: a tighter, dimmer halo sitting closer to the child.

```dart
BorderBeam.pulseOutside(style: BeamStyle.pulseOutsideStock, child: card);
```

Layer your own fields over it with `copyWith` or `merge`; anything you set wins. `BeamPulseOutsideTuning` on its own switches only the glow geometry (`demo`, the default, or `stock`).

Both sets are the source's numbers; they differ only in which is the default.

### `BeamTheme.auto` follows the app, not the OS

Upstream, `auto` follows the OS color scheme. Here it follows `Theme.of(context).brightness`, because in Flutter the app's own theme is what a widget actually sits on: a card in a dark sheet inside a light app should get the dark tuning, and asking the OS would get it wrong. `BeamTheme.dark` and `BeamTheme.light` pin it explicitly.

### No child-radius auto-detection

The original reads its child's radius. This package asks you to pass it, because it also wraps widgets with no decoration to read — a `Text`, a `Row`, a third-party card — and a wrong guess is worse than a required argument. See [shape](shape.md#match-the-child-yourself).

## Flutter-only additions

None of these exist upstream:

**Color** — `hueBase`; `BeamColors.custom`, `fromSeed` (four harmonies), `fromScheme`, `lerp`, `scaleAlpha`, `spec`; and the seven extra presets (`aurora`, `neon`, `candy`, `ember`, `ice`, `gold`, `holographic`).

**Shape** — per-corner direction-aware radii, `BeamShape.stadium`, superellipse corners, `ringOffset`, `edge`, arbitrary `BeamContour` paths, `BeamShape.segment`, and `BeamShape.wrapCorners`.

**Motion** — `cycleGap`, `direction`, `phaseOffset`, `beamCount`, `segments`, `tailLength`, `glowSpread`, `comet`, `sparkle`, `renderScale`, `innerSizeScale`, driven `progress`, pointer `follow`, `strengthListenable`, `speedListenable`, and `BeamSync`.

**Playback & API** — the value-object API itself, `BorderBeamTheme`, `BorderBeamController` (including `pulse()` and `flash()`), `BeamRepeat`, `pauseWhenOffscreen`, `debugFrozenAt`, `fadeCurve`, and `pulseOutsideTuning` as a selectable field.

**Surfaces** — `BorderBeam.overlay`, `BeamDecoration`, `BeamFocusRing`, `BeamHover`, `BeamPress`.

The React original has no segment API. `BeamSegment` is a Flutter extension that masks the unchanged full-contour animation in perimeter space. The original author's SwiftUI showcase composes the half-phone look with a screen-space gradient mask over a full beam; this package expresses that composition as `shape.segment` and keeps it correct for arbitrary sizes, radii, offsets, and contours.

## CSS ↔ Flutter mapping

Four conventions account for most of the translation, and getting one wrong produces a subtly-off effect rather than an obvious break:

| CSS | Flutter |
| --- | --- |
| `conic-gradient` starts at 12 o'clock | `SweepGradient` starts at 3 o'clock — the −90° rotation is baked in |
| `radial-gradient(ellipse W H …)` sizes are **radii** | passed straight through as `radiusX` / `radiusY` |
| `filter: blur(Npx)` | `MaskFilter.blur` with **sigma = N** |
| a gradient fading out | `color.withValues(alpha: 0)`, never `Color(0x00000000)` — transparent black lerps through black |

Layer opacity is a multiplied chain — fade × preset × mono × hook × strength — clamped at paint time, which is why presets may legitimately exceed 1 (line/dark's stroke is 1.14 in the source).
