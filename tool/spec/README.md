# Upstream spec vendoring

The React [border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam)
library publishes `spec/beam-spec.json`, a machine-readable dump of every
table its `src/styles.ts` builds its CSS from. This package's
`lib/src/constants/` is a hand transcription of those same tables, so the spec
is the only thing that can prove the transcription is still right.

- `test/fixtures/beam-spec.json` — the vendored spec.
- `test/fixtures/UPSTREAM` — the commit, versions, and `styles.ts` hash it was
  fetched at.
- `test/constants/spec_parity_test.dart` — asserts our constants against it.
- `.github/workflows/upstream_drift.yaml` — weekly alarm when upstream moves.

## Refreshing

```bash
tool/spec/refresh.sh          # from main
tool/spec/refresh.sh v1.4.0   # from a tag/branch/sha
```

Then re-check `lib/src/constants/upstream.dart` (its version strings are hand
maintained) and run:

```bash
flutter test test/constants/spec_parity_test.dart
```

A parity failure after a refresh means upstream changed a value. **Re-audit
the constants against `src/styles.ts` before touching anything** — the hard
rule in `CLAUDE.md` still stands: constants are never tweaked to make a test
pass.
