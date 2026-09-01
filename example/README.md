# flutter_border_beam example

The gallery app for the [`flutter_border_beam`](../) package — a Flutter
recreation of the original [border-beam demo](https://beam.jakubantalik.com).

```bash
flutter run          # phone / desktop
flutter run -d chrome
```

## What's in it

- **Rotate** and **Pulse** example tabs, wrapping mock chat inputs, task cards,
  and search bars — the same surfaces the original demo uses.
- **Themed** — three variants under a single `BorderBeamTheme`. Each card sets
  nothing but its variant, so colors, shape, and cycle all come from the theme.
- **Rest between sweeps** — a `cycleGap` beam that parks at the end of its
  travel and fades away before the next sweep.
- **Playground** — every meaningful field of the API, live (below).
- A dark/light theme toggle. Styling comes from the demo's own design tokens
  (`lib/src/demo_theme.dart`), not Material defaults.

## Playground

`lib/src/playground/` holds the state bag every control drives
(`playground_state.dart`), the shareable-link codec (`share_codec.dart`), the
snippet generator (`snippet.dart`), the control widgets (`controls.dart`), and
the section itself (`playground_section.dart`).

Controls are grouped into collapsible sections:

| Section | Controls |
| --- | --- |
| Variant & colors | variant; palette (colorful / mono / ocean / sunset / custom); custom colors — 2–4 swatches from a fixed preset list, fed to `BeamColors.custom` |
| Shape | stadium, per-corner, and squircle toggles; a corner-radius slider (or four, in per-corner mode); border width |
| Timing | cycle, cycle gap, speed, hue period; breathe / spike / spike 2 on the line variant; a static-colors toggle |
| Style | strength, brightness, saturation, hue range, hue base, the three layer-opacity factors; `glowBoost` on the pulse variants; core blur, bloom blur, glow brightness, and glow saturation on pulse-outside |
| Playback | active toggle; controller mode with start / pause / resume / stop and its own speed; `startAfter` and `duration` outside controller mode |
| Theme | wraps the preview in a `BorderBeamTheme` carrying ocean colors and a squircle-20 shape |

A few conventions worth knowing:

- **The preview and the snippet come from the same rule.** Both emit only what
  differs from the package default, so a fresh playground prints the one-liner,
  and with the theme toggle on, a control left at its default inherits from the
  `BorderBeamTheme` while anything you set wins.
- **`auto` means "let the package decide".** Fields whose default depends on the
  variant or a theme preset (cycle, hue period, brightness, saturation, and the
  pulse-outside glow overrides) carry an `auto` chip that clears the override.
- **Controller mode owns playback.** With a controller attached, `startAfter`,
  `duration`, `active`, and `timing.speed` belong to it, so those controls are
  disabled and drop out of the snippet.
- **Two previews.** When the window is wide enough the configuration renders on
  a dark and a light backdrop at once. `BeamTheme.auto` reads the ambient
  brightness, so neither preview sets `theme:` — the snippet stays faithful.
- The **Copy** button beside the snippet puts it on the clipboard.

### Share links

The playground encodes itself into a compact `key=value&key=value` string
holding only the non-default fields, so the default configuration is the empty
string. On the web that string is written to the address bar, and reloading —
or opening someone's link — restores the configuration. **Copy share link**
copies the current URL on the web, and off the web a link into the published
example:

```
https://simplifyjobs.github.io/flutter_border_beam/#v=line&str=0.6
```

Unknown keys, malformed pairs, and out-of-range values are ignored on the way
in, so a truncated or hand-edited link still opens a usable playground.

## Demo reels

Entry points other than `lib/main.dart` are recording reels driven by
`lib/demo_harness.dart`: a reel is a map of scene name → widget, and the
harness mounts each scene centered on the demo backdrop, printing the markers
the recorder keys off (`<PREFIX>:<name>:START/END`, then `<PREFIX>:DONE`).
`lib/showcase.dart` is the README reel; `lib/pulse_outside_demo.dart` is a
single long take of the pulse-outside halo. Record with the repo's
`tool/record_demo.sh`:

```bash
# from the package root, with a booted iOS simulator and ffmpeg installed
tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
```

Output mp4s land in `.demos/` (gitignored), center-cropped at 60fps, with an
optional contact-sheet PNG for review.
