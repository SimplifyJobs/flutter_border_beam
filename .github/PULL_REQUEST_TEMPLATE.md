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
`test/border_beam/render/frame_budget_test.dart` and
`test/distortion_wave/render/wave_frame_budget_test.dart` must pass
unchanged. If you touched a shader's uniforms, say so: `shaders/beam.frag`
moves with `lib/src/border_beam/render/beam_frame.dart` (`beamUniformFloats`),
and `shaders/common/wave_uniforms.glsl` with
`lib/src/distortion_wave/render/wave_frame_data.dart` (`waveUniformFloats`).
The uniform-layout tests check types, counts and order.
-->

## Checklist

- [ ] `BeamOutline` still mirrors `shaders/common/outline.glsl`, and
      `BeamFrameData.tableAt` the shader's `TABLE_LOOKUP` (if either side
      changed)
- [ ] New public API has doc comments (`public_member_api_docs` is enforced)
- [ ] Docs and comments describe current behavior — no change-history prose
- [ ] `CHANGELOG.md` updated
- [ ] `doc/` updated for any user-facing change (README only if it changes what a user reaches for first)
