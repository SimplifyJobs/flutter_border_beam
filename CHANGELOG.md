# Changelog

All notable changes to this package are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 0.3.0

The first release on pub.dev. Two shader effects for Flutter, built for
Impeller.

### `BorderBeam`

Light that travels or breathes around a widget's border.

- Three effects: `rotate` laps the border, `line` rides one edge, and
  `pulse` breathes in from the whole border.
- 19 palettes. Or bring your own colours, a seed colour, or a
  `ColorScheme`.
- Rounded, squircle and stadium shapes, plus partial segments and dashes.
- A theme, a controller, synchronised groups, driven progress and pointer
  follow.
- `BeamDecoration`, `BorderBeam.overlay`, and focus, hover and press
  wrappers.
- One shader draw per frame. No layers, blurs or clips.

### `DistortionWave`

A colourful wave that bends one screen into the next.

- Three types: `vertical`, `horizontal` and `center`, each tuned on its own.
- Use it in place with `DistortionWave`, or between pages with
  `DistortionWaveRoute`.
- `DistortionWaveAnchor` finds the button and the touch by itself. It works
  from the keyboard too, and with a screen reader when the screen has one
  anchor.
- Five palettes, a one-colour palette, your own colours, or any
  `BorderBeam` palette.
- A controller, a theme, `progress:` to hold the wave at any moment, and a
  short crossfade when the system asks for reduced motion.
- When it fills the screen, its light follows the display's own corners.
- One shader draw plus one sprite draw per frame. Runs on Impeller, Skia
  and the web.

Earlier versions (0.1.0 and 0.2.0) were developed as `flutter_border_beam`
and never published. Their notes are in the git history.
