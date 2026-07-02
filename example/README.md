# border_beam example

A gallery recreating the original [border-beam demo](https://beam.jakubantalik.com) in Flutter: Rotate/Pulse example tabs with mock chat inputs, task cards, and search bars, plus an interactive playground (variant, palette, strength, squircle, play/pause) with live code snippets. Dark/light theme toggle included; styling uses the demo's own design tokens, not Material defaults.

```bash
flutter run
```

## Demo reels

Entry points other than `lib/main.dart` are recording reels driven by `lib/demo_harness.dart` (marker contract: `<PREFIX>:<name>:START/END` … `<PREFIX>:DONE`). Record them with the repo's `tool/record_demo.sh`:

```bash
# from the package root, with a booted iOS simulator and ffmpeg installed
tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
```

Output mp4s land in `.demos/` (gitignored), center-cropped at 60fps, with an optional contact-sheet PNG for review.
