# Contributing to flutter_border_beam

Thanks for helping out. This package is a faithful Flutter port of the
[border-beam](https://github.com/Jakubantalik/border-beam) React library, and
most of its rules exist to keep that port honest. Read the two hard rules
below ([constants](#the-constants-rule) and the
[saveLayer budget](#the-savelayer-budget)) before changing anything under
`lib/src/constants/` or `lib/src/painting/` — they are what a reviewer will
check first.

## Setup

You need **Flutter ≥ 3.35** (the lower bound declared in `pubspec.yaml`; CI
tests that exact version in its `min-sdk` job) and, for goldens, **Flutter
3.44.2 on macOS**.

```bash
git clone https://github.com/SimplifyJobs/flutter_border_beam.git
cd flutter_border_beam
flutter pub get

# The demo gallery + interactive playground. It consumes the package by path,
# so it picks up your edits with a hot reload.
cd example && flutter pub get && flutter run
```

The gallery is also live at
<https://simplifyjobs.github.io/flutter_border_beam/> — useful for comparing
your build against `main`.

## Commands

```bash
dart format .                                # formatting (CI runs --set-exit-if-changed)
flutter analyze --fatal-infos                # must be ZERO issues
flutter test                                 # everything, goldens included
flutter test --exclude-tags golden           # everything but goldens (non-macOS)
flutter test --tags golden                   # goldens only (macOS)
dart pub publish --dry-run                   # archive validation
cd example && flutter analyze && flutter test # the gallery is a CI gate too
```

`flutter analyze` must report **zero** issues, infos included. The lint set
turns on `public_member_api_docs`, so every new public member — class, field,
enum value, constructor — needs a doc comment. That is not busywork: it is a
scored pub.dev signal, and CI's `pana` job fails when the score drops.

### Goldens

Golden files are **macOS-generated and pinned to Flutter 3.44.2**. Blur and
gradient rasterization shifts between Flutter releases and between platforms,
so a golden regenerated anywhere else will produce a diff that has nothing to
do with your change. CI runs them in a single `macos-latest` job.

Regenerate **only the scenes you added**, by name:

```bash
flutter test --update-goldens --tags golden --plain-name 'rotate dark aurora'
```

Never run a blanket `flutter test --update-goldens`. Rewriting existing
goldens is a rendering change, and a PR that does it must say in its
description **which** goldens changed and **why the pixels legitimately
moved** — a new blur radius, a corrected gradient stop, a Flutter pin bump.
"The test was failing" is not a justification; that is the test doing its job.
If you must bump the Flutter pin, do it in the same commit as the regenerated
goldens and update `FLUTTER_VERSION` in `.github/workflows/ci.yaml`,
`.github/workflows/release.yaml`, and `.github/workflows/pages.yaml` together.

Golden failures in CI upload as a `golden-failures` artifact — download it to
see the actual/expected/diff triple.

## The constants rule

**Everything in `lib/src/constants/` is a verbatim transcription of the React
source's `src/styles.ts`. Never tweak a value there to make something look
better.** Visual parity with the React library is the whole point of the port;
these tables are the parity. If a number looks wrong, check the source first:

```bash
git clone https://github.com/Jakubantalik/border-beam /tmp/border-beam-react
```

That covers `palettes.dart`, `theme_presets.dart`, `pulse_tables.dart`,
`pulse_params.dart`, and `line_keyframes.dart`. A change to any of them needs
a source citation in the PR description.

Flutter-only additions are fine, but they live in **clearly headed separate
files** that say up front they are not transcriptions — `extra_palettes.dart`
is the model. Do not mix an original value into a transcription table.

## The saveLayer budget

`saveLayer` is the expensive primitive in this package and the best single
proxy for the cost of a frame. One frame (`paintBehind` + `paintAbove`) is
budgeted per variant:

| variant | layers | what they are |
| --- | --- | --- |
| `rotate` | 4 | inner + inner mask + stroke + blurred bloom |
| `small` | 3 | inner + stroke + blurred bloom (single-mask inner) |
| `line` | 4 | inner + inner mask + stroke + blurred bloom |
| `pulseInside` | 4 | inner + inner mask + stroke + blurred bloom |
| `pulseOutside` | 3 | behind: core glow + bloom halo; above: stroke |

`test/painting/save_layer_budget_test.dart` measures every variant × brightness
× palette × time sample through a counting canvas and asserts the count
**exactly**, plus save/restore balance. A regression *and* an improvement both
fail until the table is updated in the test and in `CLAUDE.md`.

So: a new option must fold into a layer that already exists. If it genuinely
cannot, add a budget row and justify it in the PR — say which layer, why it is
unavoidable, and what you tried instead. Two things are never a justification:

- A `ColorFilter`. Hue, brightness, and saturation are folded into gradient
  colors on the CPU (`BeamColorMatrix.transform`). A filter may ride on a
  layer that exists anyway; it never earns one.
- Convenience. Blur is the only effect allowed to justify a layer of its own.

## Where things go

**Adding a variant** — `lib/src/models/beam_variant.dart` (the enum value, its
doc comment, and its default cycle duration), a strategy in
`lib/src/painting/strategies/` implementing `BeamVariantStrategy`, the
dispatch map at the top of `lib/src/painting/beam_painter.dart`, a named
constructor on `BorderBeam` in `lib/src/border_beam.dart`, any per-variant
defaults in `lib/src/models/beam_config.dart` — plus a budget row, a golden
scene, and a paint-smoke case.

**Adding an option** — declare it on the value object it belongs to
(`beam_style.dart`, `beam_shape.dart`, `beam_timing.dart`,
`beam_playback.dart`), extending `copyWith`/`merge`/`==`/`hashCode`. A null
field means *inherit*, so the default must be null. Small option types live in
`beam_options.dart`. Resolve it in `BeamConfig.resolve` and consume it in the
strategy. Value equality is load-bearing: `BeamPainter.shouldRepaint` compares
configs, so an option that does not participate in `==` will silently fail to
repaint.

**Adding a palette** — source colors in
`lib/src/constants/extra_palettes.dart`, exposed as a `static const BeamColors`
on `BeamColors` in `lib/src/models/beam_colors.dart`, plus a palette golden and
a playground entry (`example/lib/src/playground/`).

Anything public also needs a doc comment, a `CHANGELOG.md` entry, and a README
mention if it changes what a user would reach for first.

## Tests

Tests are grouped by what they protect. Put a new test with its family:

| directory | covers |
| --- | --- |
| `test/models/` | value objects, `BeamConfig.resolve`, palettes, equality |
| `test/widget/` | `BorderBeam` behavior — lifecycle, theming, shorthands, speed, sync |
| `test/widgets/` | the surface widgets (`BeamDecoration`, `BeamFocusRing`, `BeamHover`, `BeamPress`) |
| `test/painting/` | paint smoke, boundary geometry, ring geometry, color matrix, the saveLayer budget |
| `test/animation/` | the clock, oscillators, phase sampling, spring curves |
| `test/golden/*_golden_test.dart` | pixel scenes (macOS only, `@Tags(['golden'])`) |

Two conventions worth knowing:

- The first tick after `Ticker.start()` reports elapsed 0 — pump once before
  pumping durations.
- A test that documents behavior the code does not have yet is marked
  `skip: 'defect: <one line>'`, not rewritten to match the bug. (`testWidgets`
  only takes a bool, so the reason goes in a comment beside it.)

Every bug fix ships with a regression test.

## Writing prose

Docs and code comments **describe how the code works now**. No change-history
prose — no "no longer", "was removed", "previously", "this used to". Git
carries the history; a comment that narrates a change goes stale the moment
someone reads it out of context. Describe the current behavior and why it is
that way.

## Commits and PRs

Conventional Commits, for both commit subjects and PR titles:

```
<type>(<scope>): <summary>
```

Lowercase type (`feat`, `fix`, `refactor`, `docs`, `chore`, `ci`, `test`,
`perf`), an optional short scope (`painting`, `motion`, `colors`, `widgets`,
`api`), imperative summary under 72 characters. For example:

```
feat(painting): add a comet tail to the rotate strategy
fix(motion): keep the line beam inside its edge-fade plateau
```

Before opening a PR:

- [ ] `dart format .` — clean
- [ ] `flutter analyze --fatal-infos` — zero issues (package **and** `example/`)
- [ ] `flutter test` — green (say if you could not run goldens)
- [ ] Goldens: none regenerated, or the PR names which and why
- [ ] saveLayer budget: unchanged, or the new rows are justified
- [ ] Public API is documented, and the README covers anything user-facing
- [ ] `CHANGELOG.md` has an entry under the unreleased version

The PR template asks for exactly this. Open the PR as a draft while it is in
progress.

## Releases

Maintainers only. The recipe lives in [CLAUDE.md](CLAUDE.md) under "Cutting a
release": bump `version:` in `pubspec.yaml`, add a matching `## <version>`
section to `CHANGELOG.md`, merge to `main`, then push the tag:

```bash
git tag v0.2.0 && git push origin v0.2.0
```

`.github/workflows/release.yaml` verifies the tag against the pubspec and the
changelog, re-runs format/analyze/test, publishes to pub.dev over GitHub OIDC
(no secrets), and cuts the GitHub Release from that changelog section. Goldens
are verified by the macOS `goldens` job in `ci.yaml`, not by the release job —
so only tag a commit that is green on `main`.

## Code of Conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
Security issues go through [SECURITY.md](SECURITY.md), not the issue tracker.
