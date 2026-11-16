## Summary

<!--
What changed and why, in a short paragraph. Link the issue it closes
(`Closes #12`). If this changes what a beam looks like, say so here — that is
the first thing a reviewer needs to know.
-->

## Changes

<!--
Bullets, each opening with a bold lead-in naming the area:

- **Render** (`lib/src/border_beam/render/`, `shaders/beam.frag`) — …
- **Docs** — …
-->

-

## Testing

<!--
What you actually ran, and what it said. Do not claim a check you skipped —
"goldens not run (no macOS)" is a fine and useful answer.
-->

- [ ] `dart format .` — clean
- [ ] `flutter analyze --fatal-infos` — zero issues (package and `example/`)
- [ ] `flutter test` — green (`--exclude-tags golden` if you are not on macOS)

**Goldens** — none regenerated / regenerated:

<!--
If you regenerated any: list which scenes, and why the pixels legitimately
moved (a retuned effect, a shader fix, a Flutter pin bump). Goldens are
macOS-only and pinned to Flutter 3.50.0; regenerate only the scenes you
touched, with `--plain-name`.
-->

**Frame budget** — still one draw, no `saveLayer` / clip / image or mask filter:

<!--
`test/border_beam/render/frame_budget_test.dart` must pass unchanged. If you touched the
shader's uniforms, say so: `shaders/beam.frag` and the offsets and slot
counts in `lib/src/border_beam/render/beam_frame.dart` (`beamUniformFloats`) must move
together, and the uniform order is checked by hand.
-->

## Checklist

- [ ] `BeamOutline` and `color_math.dart` still mirror the shader (if either
      side changed)
- [ ] New public API has doc comments (`public_member_api_docs` is enforced)
- [ ] Docs and comments describe current behavior — no change-history prose
- [ ] `CHANGELOG.md` updated
- [ ] README updated if this changes what a user reaches for first
