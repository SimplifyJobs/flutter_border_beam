# Contributing to prismatic

Thanks for helping out. This package draws every beam with one fragment
shader in a single draw call, and most of its rules exist to keep it that
cheap. Read [the rendering rules](#the-rendering-rules) before changing
anything under `lib/src/render/`, `lib/src/effects/`, or `shaders/` — they are
what a reviewer will check first. [doc/architecture.md](doc/architecture.md)
explains how a frame is built.

## Setup

You need **Flutter ≥ 3.47** (the lower bound declared in `pubspec.yaml`, set
by `material_ui`; CI tests that exact version in its `min-sdk` job) and, for goldens, **Flutter
3.50.0 on macOS**.

```bash
git clone https://github.com/SimplifyJobs/prismatic.git
cd prismatic
flutter pub get

# The one-screen showcase. It consumes the package by path, so it picks up
# your edits with a hot reload — shader edits included.
cd example && flutter pub get && flutter run
```

The showcase is also live at
<https://simplifyjobs.github.io/prismatic/> — useful for comparing
your build against `main`.

## Commands

```bash
dart format .                                # formatting (CI runs --set-exit-if-changed)
flutter analyze --fatal-infos                # must be ZERO issues
flutter test                                 # everything, goldens included
flutter test --exclude-tags golden           # everything but goldens (non-macOS)
flutter test --tags golden                   # goldens only (macOS)
dart pub publish --dry-run                   # archive validation

# The example has no tests; CI gates it on analyze and a web build.
cd example && flutter analyze --fatal-infos && flutter build web
```

`flutter analyze` must report **zero** issues, infos included. The lint set
turns on `public_member_api_docs`, so every new public member — class, field,
enum value, constructor — needs a doc comment. That is a scored pub.dev
signal, and CI's `pana` job fails when the score drops.

### Goldens

Golden files are **macOS-generated and pinned to Flutter 3.50.0**. Shader
compilation and rasterization shift between Flutter releases and between
platforms, so a golden regenerated anywhere else produces a diff that has
nothing to do with your change. CI runs them in a single `macos-latest` job.

Regenerate **only the scenes you added or deliberately changed**, by name:

```bash
flutter test --update-goldens --tags golden --plain-name 'rotate dark colorful'
```

Never run a blanket `flutter test --update-goldens` to make a failure go away.
Rewriting existing goldens is a rendering change, and a PR that does it must
say in its description **which** goldens changed and **why the pixels
legitimately moved** — a retuned effect, a shader fix, a Flutter pin bump.
"The test was failing" is not a justification; that is the test doing its job.
If you bump the Flutter pin, do it in the same commit as the regenerated
goldens and update `FLUTTER_VERSION` in `.github/workflows/ci.yaml`,
`.github/workflows/release.yaml`, and `.github/workflows/pages.yaml` together.

Golden failures in CI upload as a `golden-failures` artifact — download it to
see the actual/expected/diff triple.

## The rendering rules

### One draw, no offscreen work

A beam frame is **one** `drawRect` or `drawDRRect` with the beam shader, and
nothing else: no `saveLayer`, no clip, no `ImageFilter`, no `MaskFilter`.
`test/render/frame_budget_test.dart` records every effect across themes,
palettes, shape families, options, and instants through a counting canvas and
asserts exactly that. A new look is new shader maths or new data in
`BeamFrameData` — never a layer, a blur, or a second draw. If something truly
cannot be expressed that way, open an issue before writing it.

### The uniform contract

The `uniform` block in `shaders/beam.frag` and the offsets and slot counts in
`lib/src/render/beam_frame.dart` (`BeamFrameData`, `beamUniformFloats`) agree
float for float. Change both in the same commit. Uniforms are `vec4`s and
`vec4` arrays only, so the layout is the same on every backend, and arrays are
indexed only by constants and loop indices (SkSL's strict ES2), which is why
each layer has its own blob array. `test/render/uniform_layout_test.dart`
parses the shader and checks the types, the array lengths, the loop bounds,
and the total — but it cannot see the order, so check that by hand: a uniform
reordered on one side only shifts every value after it.

### The CPU mirrors

Two pieces of shader maths also run in Dart, and must match exactly:

- **`BeamOutline`** (`lib/src/render/beam_outline.dart`) mirrors the shader's
  `outline()` — the corner model, the signed distance, the nearest-piece
  choice, and the perimeter coordinate `u`. Emitters lay blobs along the
  outline with it, segments resolve against it, and `follow` maps the pointer
  with it.
- **Conic tables** — `BeamFrameData.tableAt` reads a table exactly as the
  shader's `TABLE_LOOKUP` does.

### Slots and light

- **Fixed slots:** 14 blobs in layer 0, 10 in layers 1 and 2, and 16 stops per
  conic table; `addBlob` drops anything past a layer's slots. A palette
  carries at most 8 colour stops.
- Glows that reach **inside** the shape are planar blobs, or path-space blobs
  kept within the edge fade. Never shade an inward glow from `u`: inside the
  shape it jumps across the medial axis and shows a seam.
- Emitters are **pure** (a function of the config, the phases, the outline,
  and the palette's blob tables) and **allocation-light per frame**: they
  write into the renderer's reused `BeamFrameData`; table transforms use
  scratch lists, oscillator banks are cached per tuning, and derived tables
  are memoized per palette.

## Where things go

**Adding an effect** — a `final class` extending `BeamEffect` in
`lib/src/effects/beam_effect.dart` (with a `const factory` on `BeamEffect`, a
doc comment, `travels`, `defaultCycle`, and any non-default `defaultCycleGap` /
`defaultHueMode` / `defaultHuePeriod`, plus `==` / `hashCode`), an entry in
`BeamEffect.values`, the export in `lib/prismatic.dart`, and an
emitter in `lib/src/effects/effect_emitters.dart`. The `switch` statements over
`BeamEffect` (the emitter dispatch, `BorderBeam.follow`) are exhaustive, so the
analyzer lists every place that needs a case; `BeamConfig.beamCount` falls
back to one beam for anything but `rotate`. Then a golden scene, and the
effect shows up in the render tests automatically through `render_utils.dart`'s
`effectsByName`.

**Adding an option** — declare it on the value object it belongs to
(`beam_style.dart`, `beam_shape.dart`, `beam_timing.dart`,
`beam_playback.dart`), extending `copyWith` / `merge` / `==` / `hashCode`. A
null field means *inherit*, so the default must be null. Small option types
live in `beam_options.dart`. Resolve it in `BeamConfig.resolve` and consume it
in the emitter or the renderer. Value equality is load-bearing:
`BeamPainter.shouldRepaint` compares configs, so an option that does not take
part in `==` silently fails to repaint. An option parameter that belongs to one
effect goes on that effect's class instead (`BeamEffect.rotate(length:)`).

**Adding a palette** — a `const BeamPalette` in
`lib/src/models/beam_presets.dart` (at most 8 stops, ascending, in `[0, 1)`),
exposed as a `static const BeamColors` on `BeamColors` and added to
`BeamColors.presets`, plus a palette golden (the example's swatch row picks
it up from `BeamColors.presets`). Without blob tables of its own, a preset
is drawn by sampling its stops over `colorful`'s tables. Presets are design
data: edit freely, and check the result on both dark and light surfaces.

Anything public also needs a doc comment, a `CHANGELOG.md` entry, and a README
mention if it changes what a user would reach for first.

## Tests

Tests are grouped by what they protect. Put a new test with its family:

| directory | covers |
| --- | --- |
| `test/models/` | value objects, `BeamConfig.resolve`, palettes, effects, segments, equality |
| `test/animation/` | the clock, the spring, phase sampling, travel |
| `test/render/` | the frame budget, the uniform layout, the outline mirror, emission sanity, boundaries, paint smoke, where light lands |
| `test/widget/` | `BorderBeam` behaviour — lifecycle, theming, shorthands, speed, sync, progress, follow |
| `test/widgets/` | the surface widgets (`BeamDecoration`, `BeamFocusRing`, `BeamHover`, `BeamPress`) |
| `test/golden/*_golden_test.dart` | pixel scenes (macOS only, `@Tags(['golden'])`) |

Conventions worth knowing:

- Anything that reads pixels needs the shader loaded:
  `setUpAll(BorderBeam.precache)`.
- For new rendering behaviour, prefer comparing regions of a real frame
  against each other (see `test/render/paint_structure_test.dart`) over
  pinning pixel values — those survive a retune; goldens are for the look.
- The first tick after `Ticker.start()` reports elapsed 0 — pump once before
  pumping durations.
- A test that documents behaviour the code does not have yet is marked
  `skip: 'defect: <one line>'`, not rewritten to match the bug. (`testWidgets`
  only takes a bool, so the reason goes in a comment beside it.)

Every bug fix ships with a regression test.

## Writing prose

Docs and code comments **describe how the code works now**. No change-history
prose — no "no longer", "was removed", "previously", "this used to". Git and
`CHANGELOG.md` carry the history; a comment that narrates a change goes stale
the moment someone reads it out of context. Describe the current behaviour and
why it is that way. Don't quote tuning values (glow reaches, layer weights) in
docs — they live in `lib/src/look/` and the emitters, and they change.

## Commits and PRs

Conventional Commits, for both commit subjects and PR titles:

```
<type>(<scope>): <summary>
```

Lowercase type (`feat`, `fix`, `refactor`, `docs`, `chore`, `ci`, `test`,
`perf`, `style`), an optional short scope (`render`, `shader`, `effects`,
`motion`, `colors`, `widgets`, `api`), imperative summary under 72
characters. For example:

```
feat(effects): add a comet tail to the rotate effect
fix(shader): keep the dash ends soft on the bloom
```

Before opening a PR:

- [ ] `dart format .` — clean
- [ ] `flutter analyze --fatal-infos` — zero issues (package **and** `example/`)
- [ ] `flutter test` — green (say if you could not run goldens)
- [ ] Goldens: none regenerated, or the PR names which and why
- [ ] Frame budget: still one draw, no layers, clips, or filters
- [ ] Shader uniforms and `beam_frame.dart`'s offsets and slot counts changed together (if touched)
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
