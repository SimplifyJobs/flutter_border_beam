## Summary

<!--
What changed and why, in a short paragraph. Link the issue it closes
(`Closes #12`). If this changes what a beam looks like, say so here — that is
the first thing a reviewer needs to know.
-->

## Changes

<!--
Bullets, each opening with a bold lead-in naming the area:

- **Painting** (`lib/src/painting/`) — …
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
moved (a new blur radius, a corrected gradient stop, a Flutter pin bump).
Goldens are macOS-only and pinned to Flutter 3.44.2; regenerate only your own
new scenes, with `--plain-name`.
-->

**saveLayer budget** — unchanged / changed:

<!--
If `test/painting/save_layer_budget_test.dart`'s table changed: which variants,
the new counts, and what the added layer composites that no existing layer
could. Both the test and CLAUDE.md's table have to move together.
-->

## Checklist

- [ ] No values in `lib/src/constants/` were tweaked (they are verbatim
      transcriptions of the React source); Flutter-only additions live in a
      clearly headed file
- [ ] New public API has doc comments (`public_member_api_docs` is enforced)
- [ ] Docs and comments describe current behavior — no change-history prose
- [ ] `CHANGELOG.md` updated
- [ ] README updated if this changes what a user reaches for first
