# flutter_border_beam example

The gallery app for the [`flutter_border_beam`](../) package — a Flutter
recreation of the original [border-beam demo](https://beam.jakubantalik.com).

```bash
flutter run          # phone / desktop
flutter run -d chrome
```

`main()` awaits `BorderBeam.precache()` after
`WidgetsFlutterBinding.ensureInitialized()`, so the beam shader is loaded
before the first frame.

## What's in it

- **Rotate** and **Pulse** example tabs, wrapping mock chat inputs, task cards,
  and search bars — the same surfaces the original demo uses. The Pulse tab's
  halo (the old pulse-outside) breathes outside its card, unclipped.
- **Flow, spin, shimmer, charge** — the four effects beyond the original
  library, each on the surface it suits: a listening assistant, a "Get started"
  button, an "Upgrade to Pro" call to action, and a saving pill.
- **Every effect** — `BeamEffect.values`, one card each.
- **Driven progress** — `progress:` fed by a looping `AnimationController`:
  charge filling an upload row to the value, and a rotate ring parked on it.
- **Palettes** — a card per entry of `BeamColors.presets`, all nineteen, with
  the eight added in 0.2 tagged.
- **Themed** — three effects under a single `BorderBeamTheme`. Each card sets
  nothing but its effect, so colors, shape, and cycle all come from the theme.
- **Rest between sweeps** — a `cycleGap` beam that parks at the end of its
  travel and fades away before the next sweep.
- **Partial contours** — the half-phone `BeamSegment` on rotate, line, and
  pulse, plus spin held to `BeamSegment.bottomEdge`.
- **Surfaces** — the beam reached without the wrapper: a `BeamDecoration` in a
  `Container`'s `foregroundDecoration`, a `BeamFocusRing` around a focusable
  field, and `BeamHover` / `BeamPress` cards.
- **Motion** — one card each for `direction: reverse`, `direction: bounce`,
  `BeamEffect.rotate(count: 3)`, `dashes: 8`, the comet tail, and `glow: 2`.
- **Sync** — four cards on one `BeamSync` clock, spaced by `phaseOffset`.
- **Playground** — every field of the API, live (below).
- A dark/light theme toggle. Styling comes from the demo's own design tokens
  (`lib/src/demo_theme.dart`), not Material defaults.

## Playground

`lib/src/playground/` holds the state bag every control drives
(`playground_state.dart`), the shareable-link codec (`share_codec.dart`), the
snippet generator (`snippet.dart`), the control widgets (`controls.dart`), and
the section itself (`playground_section.dart`).

An install line sits above it: `flutter pub add flutter_border_beam` with a
Copy chip, beside a chip that copies the repository link.

Controls are grouped into collapsible sections:

| Section | Controls |
| --- | --- |
| Effect | the eight effects; length, count, and comet on rotate; the edge on line; the angle on shimmer |
| Colors | every preset in `BeamColors.presets`, plus three factories: **Custom** (2–6 swatches, fed to `BeamColors([...])`), **Seed** (one swatch + a `BeamSeedHarmony`, fed to `BeamColors.fromSeed`), and **Lerp** (two presets and a blend slider, fed to `BeamColors.lerp`); an alpha-scale slider over any of them (`BeamColors.scaleAlpha`) |
| Style | theme (auto / dark / light), strength, glow, hue mode (auto / ping-pong / continuous / none), hue shift, hue base |
| Shape | stadium, per-corner, and squircle toggles; a corner-radius slider (or four, in per-corner mode); border width; ring offset; dashes; segment presets or custom edge anchors with feathering |
| Timing | cycle, cycle gap, speed, direction, phase offset, hue period |
| Playback | active toggle; controller mode with `start()` / `pause()` / `resume()` / `stop()` / `pulse()` / `flash()` and its own speed; `startAfter` and `duration` outside controller mode; repeat (forever / once / 3 cycles); reduced motion, with a toggle that simulates it; offscreen pause; the fade curve (spring or `BeamPlayback.cssEase`) |
| Drive | `progress:` with a position slider, `follow:` fed by the pointer over the preview, and `strengthListenable:` fed by a sine wave |
| Theme & sync | wraps the preview in a `BorderBeamTheme` carrying ocean colors and a squircle-20 shape, and swaps it for three `BeamSync` beams a third of a cycle apart |

A few conventions worth knowing:

- **The preview and the snippet come from the same rule.** The effect is always
  written out; everything else only where it differs from the package default.
  With the theme toggle on, a control left at its default inherits from the
  `BorderBeamTheme` while anything you set wins.
- **The snippet compiles as written.** Every value object is `const`, and the
  pointer, the controller, and the strength signal print as the variables the
  surrounding widget would hold (`follow: pointer`, `controller: controller`,
  `strengthListenable: level`), declared above the beam.
- **`auto` means "let the effect decide".** Cycle, cycle gap, and hue period
  default per effect (shimmer and charge rest between sweeps, for instance);
  their `auto` chip clears the override.
- **Controls that cannot reach the beam are disabled or explained, and drop out
  of the snippet.** Cycle gap, progress, and follow need a travelling effect; direction
  does nothing on pulse and halo; hue shift only moves a ping-pong drift; the
  hue period does nothing once the hue mode is none.
- **Controller mode owns playback.** With a controller attached, `startAfter`,
  `duration`, `active`, and `timing.speed` belong to it, so those controls are
  disabled and drop out of the snippet.
- **Two previews.** When the window is wide enough the configuration renders on
  a dark and a light backdrop at once. `BeamTheme.auto` reads the ambient
  brightness, so neither preview sets `theme:` unless you pick one.
- **Static frame is the reduced-motion default**, so that chip sets no field.
  **Simulate reduced motion** is a preview concern — it wraps the preview in a
  `MediaQuery` asking for reduced motion and changes nothing in the snippet.
- The **Copy** button beside the snippet puts it on the clipboard.

### Share links

The playground encodes itself into a compact `key=value&key=value` string
holding only the non-default fields, so the default configuration is the empty
string. On the web that string is written to the address bar, and reloading —
or opening someone's link — restores the configuration. **Copy share link**
copies the current URL on the web, and off the web a link into the published
example:

```
https://simplifyjobs.github.io/flutter_border_beam/#v=shimmer&p=gold
```

Unknown keys, malformed pairs, and out-of-range values are ignored on the way
in, so a truncated or hand-edited link still opens a usable playground. Links
from the 0.1 playground open too: `small` maps to rotate, `pulse-inside` to
pulse, `pulse-outside` to halo, and the fields that moved (line edge, tail
length, beam count, comet, ring segments, static colors) are read from their
old keys.

## Demo reels

Entry points other than `lib/main.dart` are recording reels driven by
`lib/demo_harness.dart`: a reel is a map of scene name → widget, and the
harness precaches the shader, then mounts each scene centered on the demo
backdrop, printing the markers the recorder keys off
(`<PREFIX>:<name>:START/END`, then `<PREFIX>:DONE`). `lib/showcase.dart` is the
README reel — the eight effects, palettes, and a squircle; `lib/halo_demo.dart`
is a long take of the halo. Record with the repo's `tool/record_demo.sh`:

```bash
# from the package root, with a booted iOS simulator and ffmpeg installed
tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
tool/record_demo.sh --target lib/halo_demo.dart --prefix HALO --contact
```

Output mp4s land in `.demos/` (gitignored), center-cropped at 60fps, with an
optional contact-sheet PNG for review.
