# prismatic example

A showcase for the [`prismatic`](../) package: each of the three border-beam
effects on the kind of widget it is made for, big enough to see, and — one tap
away — the distortion wave on the screens it is made for.

```bash
flutter run          # phone / desktop
flutter run -d chrome
```

`main()` awaits `BorderBeam.precache()` and `DistortionWave.precache()` after
`WidgetsFlutterBinding.ensureInitialized()`, so both effects' shaders are
loaded before the first frame.

## What it shows

Swipe the stage, or tap the selector under it, to move between the effects:

| Effect | Surface |
| --- | --- |
| `BeamEffect.rotate()` | an agent's task card |
| `BeamEffect.line()` | a chat composer, the streak on its bottom edge |
| `BeamEffect.pulse()` | an assistant's "thinking" card |

- **Palettes** — the row of swatches is `BeamColors.presets`, all nineteen;
  each swatch is drawn from the preset's own colour stops.
- **Fade** — tap the stage, or the play/pause button, to toggle `active` and
  watch the beam fade out and back in.
- **Theme** — the sun/moon button flips the app between dark (the default) and
  light. The beam's `BeamStyle.theme` follows, so it uses its light-surface
  tuning on the light theme.
- Under the caption, the effect and palette on screen are written as code
  (`BeamEffect.line()  ·  BeamColors.ocean`).

## Distortion wave

The wave button in the home header (between play/pause and the theme toggle)
opens the distortion wave page — itself on a `DistortionWaveRoute` from that
button; the close button in the same spot collapses it back. Swipe the stage,
or tap the selector, to move between three mock screens, one per
`WaveType`. Each has a `DistortionWaveAnchor` around the control that starts
the wave, so it opens from that control and leans toward the touch:

| Type | Demo |
| --- | --- |
| `WaveType.vertical` | **Send money** — a payment review; Send reveals the receipt, Done collapses it |
| `WaveType.horizontal` | **Next step** — a sign-up step; the tall tab on the left edge goes on to the next step, Back returns |
| `WaveType.center` | **Success sheet** — a 500pt sheet with 48pt corners; the fingerprint icon turns it into its paid state |

- **Palettes** — the swatches are `WavePalette.presets` (colorful, green,
  ocean, sunset, mono), then aurora and lagoon through
  `WavePalette.fromBeamColors`. Each demo starts on its type's default.
- **Scrub** — drag the bar to hold the wave at any point (`progress:`); let go
  and it plays on from there to the nearer side. Between drags the thumb
  follows the wave as it plays.
- **Route** — the pill in the header pushes a full page on a
  `DistortionWaveRoute` from itself; Close, in the same spot, pops it back
  into the pill.

The demos use a `DistortionWaveController` each (the scrub bar seeks it on
release), so they live in `lib/src/wave_scenes.dart`, shared with the reel;
the page is `lib/src/wave_page.dart`.

On wide windows the screen stays centred at phone-like width. Every card and
chip uses continuous (superellipse) corners, and each beam is given the same
corners, so the light sits exactly on the edge.

For captures, three `--dart-define`s set the opening state:

```bash
flutter run --dart-define=START=pulse --dart-define=PALETTE=ocean --dart-define=THEME=light
```

## Layout

| File | What it holds |
| --- | --- |
| `lib/main.dart` | `main()` and the app: theme state, `MaterialApp` |
| `lib/src/home.dart` | the screen: header, swipeable stage, caption, controls |
| `lib/src/surfaces.dart` | the three mock surfaces the beams wrap |
| `lib/src/wave_page.dart` | the distortion wave screen, and the page its Route pill pushes |
| `lib/src/wave_scenes.dart` | the wave demos: mock screens, palettes, `DemoWave` |
| `lib/src/controls.dart` | the selector, swatches, round toggles, pill button, scrub bar |
| `lib/src/tokens.dart` | dark and light colour tokens, as a `ThemeExtension` |

## Demo reels

The other entry points are recording reels driven by `lib/demo_harness.dart`:
a reel is a map of scene name → widget, and the harness precaches the
shaders, then mounts each scene centred on the dark backdrop, printing the
markers the recorder keys off (`<PREFIX>:<name>:START/END`, then
`<PREFIX>:DONE`). `lib/showcase.dart` is the README reel — the three effects,
palettes, and a squircle. `lib/wave_reel.dart` is the wave's — each type's
demo revealing and collapsing on its own, then the send demo in a border-beam
palette. Record them with the repo's `tool/record_demo.sh`:

```bash
# from the package root, with a booted iOS simulator and ffmpeg installed
tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
tool/record_demo.sh --target lib/wave_reel.dart --prefix WAVE --contact
```

The wave scenes are phone-screen sized, taller than the recorder's default
crop band; add `--no-crop` (or a `--crop-height`) to keep them whole.

Output mp4s land in `.demos/` (gitignored), centre-cropped at 60fps, with an
optional contact-sheet PNG for review.
