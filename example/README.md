# flutter_border_beam example

The gallery app for the [`flutter_border_beam`](../) package — a Flutter
recreation of the original [border-beam demo](https://beam.jakubantalik.com).

```bash
flutter run
```

## What's in it

- **Rotate** and **Pulse** example tabs, wrapping mock chat inputs, task cards,
  and search bars — the same surfaces the original demo uses.
- **Playground** — pick a variant and palette, drag `strength`, toggle the
  superellipse contour, and play/pause the beam, with a live code snippet that
  matches whatever you've dialled in.
- A dark/light theme toggle. Styling comes from the demo's own design tokens
  (`lib/src/demo_theme.dart`), not Material defaults.

## Demo reels

Entry points other than `lib/main.dart` are recording reels driven by
`lib/demo_harness.dart` (marker contract: `<PREFIX>:<name>:START/END` …
`<PREFIX>:DONE`). Record them with the repo's `tool/record_demo.sh`:

```bash
# from the package root, with a booted iOS simulator and ffmpeg installed
tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
```

Output mp4s land in `.demos/` (gitignored), center-cropped at 60fps, with an
optional contact-sheet PNG for review.
