# prismatic example

A one-screen showcase for the [`prismatic`](../) package: each of the
three effects on the kind of widget it is made for, big enough to see.

```bash
flutter run          # phone / desktop
flutter run -d chrome
```

`main()` awaits `BorderBeam.precache()` after
`WidgetsFlutterBinding.ensureInitialized()`, so the shader is loaded before the
first frame.

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
| `lib/src/controls.dart` | the effect selector, palette swatches, round toggles |
| `lib/src/tokens.dart` | dark and light colour tokens, as a `ThemeExtension` |

## Demo reels

The other entry points are recording reels driven by `lib/demo_harness.dart`:
a reel is a map of scene name → widget, and the harness precaches the shader,
then mounts each scene centred on the dark backdrop, printing the markers the
recorder keys off (`<PREFIX>:<name>:START/END`, then `<PREFIX>:DONE`).
`lib/showcase.dart` is the README reel — the three effects, palettes, and a
squircle. Record it with the repo's `tool/record_demo.sh`:

```bash
# from the package root, with a booted iOS simulator and ffmpeg installed
tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
```

Output mp4s land in `.demos/` (gitignored), centre-cropped at 60fps, with an
optional contact-sheet PNG for review.
