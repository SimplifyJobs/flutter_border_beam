# BorderBeam — usage reference

How to use `BorderBeam` and its companions: every public type, the
parameters, defaults and precedence, and the pitfalls. Topic guides go
deeper: [effects.md](effects.md), [palettes.md](palettes.md),
[shape.md](shape.md), [motion.md](motion.md), [theming.md](theming.md),
[accessibility.md](accessibility.md), [performance.md](performance.md). How a
frame is rendered: [architecture.md](architecture.md).

Look values (glow reaches, layer strengths, fade responses) are tuned in
`lib/src/border_beam/look/`, the emitters, and
`lib/src/border_beam/animation/spring_curve.dart`. This page names fields and
describes behaviour; read the code for current numbers.

## Entry points

```dart
import 'package:prismatic/border_beam.dart'; // the beam alone
import 'package:prismatic/prismatic.dart';   // both effects
```

`lib/border_beam.dart` exports exactly: `BorderBeam`, `BorderBeamController`,
`BorderBeamTheme`, `BorderBeamThemeData`, `BeamSync`, `BeamEffect`,
`RotateEffect`, `LineEffect`, `PulseEffect`, `BeamColors`,
`BeamSeedHarmony`, `BeamDirection`, `BeamEdge`, `BeamHueMode`,
`BeamReducedMotion`, `BeamRepeat`, `BeamAnchor`, `BeamCorner`,
`BeamSegment`, `BeamTheme`, `BeamStyle`, `BeamShape`, `BeamTiming`,
`BeamPlayback`, `BeamDecoration`, `BeamFocusRing`, `BeamHover`, `BeamPress`.
Nothing under `lib/src/border_beam/render/` or `effects/effect_emitters.dart`
is public.

| Public type | File |
| --- | --- |
| `BorderBeam` | `lib/src/border_beam/border_beam.dart` |
| `BorderBeamController` | `lib/src/border_beam/border_beam_controller.dart` |
| `BorderBeamTheme`, `BorderBeamThemeData` | `lib/src/border_beam/border_beam_theme.dart` |
| `BeamSync` | `lib/src/border_beam/beam_sync.dart` |
| `BeamEffect` and subclasses | `lib/src/border_beam/effects/beam_effect.dart` |
| Value objects, `BeamColors`, options, segments, `BeamTheme` | `lib/src/border_beam/models/` |
| `BeamDecoration`, `BeamFocusRing`, `BeamHover`, `BeamPress` | `lib/src/border_beam/widgets/` |

## Setup facts

- The shader (`shaders/beam.frag`) is declared in the package's own pubspec;
  a consuming app adds nothing.
- Material is read through `package:material_ui`, not
  `package:flutter/material.dart`. Their `Theme` and `ColorScheme` are
  different types. Under an app still on `flutter/material.dart`,
  `BeamTheme.auto` finds no `material_ui` theme and tunes for a light
  surface, and `BeamColors.fromScheme` needs `material_ui`'s `ColorScheme`.
  Fix: migrate (`dart fix --apply --code=migrate_design_widgets`) or set
  `BeamStyle.theme` explicitly.
- Optional: `await BorderBeam.precache();` in `main()` (after
  `WidgetsFlutterBinding.ensureInitialized()`) loads the shader before the
  first beam. Without it, a beam paints nothing until the load resolves,
  which its fade-in hides.

## Minimal use

```dart
BorderBeam(
  borderRadius: 16,              // match the child's own radius
  colors: BeamColors.ocean,
  child: Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: const Padding(padding: EdgeInsets.all(24), child: Text('Working…')),
  ),
)
```

That is `BeamEffect.rotate()`, the default effect. Everything else lives on
four value objects:

```dart
BorderBeam(
  effect: const BeamEffect.line(),
  style: const BeamStyle(colors: BeamColors.sunset, strength: 0.8),
  shape: const BeamShape.all(24, superellipse: true),
  timing: const BeamTiming(cycleGap: Duration(seconds: 1)),
  playback: const BeamPlayback(reducedMotion: BeamReducedMotion.staticFrame),
  child: card,
)
```

## `BorderBeam`

```dart
const BorderBeam({
  Key? key,
  required Widget child,
  BeamEffect? effect,
  BeamColors? colors,          // shorthand for style.colors
  bool? active,                // shorthand for playback.active
  double? borderRadius,        // shorthand for a uniform shape.radius
  BeamStyle? style,
  BeamShape? shape,
  BeamTiming? timing,
  BeamPlayback? playback,
  BorderBeamController? controller,
  double? progress,
  Offset? follow,
  ValueListenable<double>? strengthListenable,
  ValueListenable<double>? speedListenable,
  VoidCallback? onActivate,
  VoidCallback? onDeactivate,
})
```

| Parameter | Behaviour |
| --- | --- |
| `child` | Laid out and hit-tested normally; sits in its own `RepaintBoundary`, so the beam animating never repaints it. |
| `effect` | `BeamEffect.rotate({length, count, comet})`, `.line({edge})`, `.pulse()`. Null → nearest theme's → `rotate()`. See [effects.md](effects.md). |
| `colors`, `active`, `borderRadius` | Shorthands; a non-null value wins over the same field on the value object. |
| `style`, `shape`, `timing`, `playback` | Value objects (tables below). Every field nullable = inherit. |
| `controller` | Attached, it owns playback (see below). Not allowed below a `BeamSync`. |
| `progress` | 0–1. Places the travel instead of the clock: `rotate` becomes a progress ring, `line` a progress bar. Ambient `pulse` ignores it. NaN = unset. |
| `follow` | Normalized point (0–1 per axis) in the box; the travel eases to the nearest border point. `progress` wins. Non-finite = unset. |
| `strengthListenable` | Scales opacity per frame without a rebuild; above 1 brightens, saturating at full opacity. |
| `speedListenable` | Playback rate per frame; wins over `timing.speed` and a controller's `speed`. Must stay positive. Ignored below a `BeamSync`. |
| `onActivate` / `onDeactivate` | Fire when the fade-in / fade-out completes. |
| `BorderBeam.precache()` | `static Future<void>`: loads the shader. |

`BorderBeam.overlay({...})` takes the same parameters minus `child`: the beam
paints over a `SizedBox.expand()`, so it is sized by its parent:

```dart
Stack(children: [content, const Positioned.fill(child: BorderBeam.overlay(borderRadius: 16))])
```

The beam adds no semantics and never takes part in hit-testing.

## Value objects

All four are `const`, all-nullable, value-equal, with `copyWith` (a null
argument keeps the value) and `merge` (the argument's non-null fields win).
The defaults below are what a field resolves to when nothing sets it
(`BeamConfig.resolve` in `lib/src/border_beam/models/beam_config.dart`).

### `BeamStyle`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `colors` | `BeamColors?` | `BeamColors.colorful` | See [palettes.md](palettes.md). |
| `theme` | `BeamTheme?` | `BeamTheme.auto` | `dark` / `light` / `auto` (follows `material_ui`'s `Theme.of(context).brightness`). Picks the dark- or light-surface tuning. |
| `strength` | `double?` | 1 | Overall opacity, clamped 0–1; NaN = 1. |
| `glow` | `double?` | 1 | Scales every glow's reach and, below 1, brightness; 0 leaves only the stroke. Not negative. |
| `hueMode` | `BeamHueMode?` | `effect.defaultHueMode` | `pingPong`, `continuous`, `none`. `mono` and `gold` force `none`. |
| `hueShift` | `double?` | 30 | Degrees either side, `pingPong` only. |
| `hueBase` | `double?` | 0 | Fixed hue rotation, degrees, on top of any drift. |

Non-finite `glow`, `hueShift`, `hueBase` count as unset.

### `BeamShape`

| Field / constructor | Type | Default | Notes |
| --- | --- | --- | --- |
| `BeamShape({radius, superellipse, borderWidth, ringOffset, segment, dashes})` | | | Per-corner. |
| `BeamShape.all(double r, {...})` | | | `const` uniform radius; equal to `circular(r)`. |
| `BeamShape.circular(double r, {...})` | | | Same shape as `all`, built as a `BorderRadius` (not const). |
| `BeamShape.stadium({...})` | | | Each corner half the shortest side; tracks resizes. |
| `radius` | `BorderRadiusGeometry?` | `BeamShape.defaultRadius` (16) on every corner | Direction-aware; clamped like `RRect.scaleRadii`. Not read from the child. |
| `superellipse` | `bool?` | false | Flutter's `RSuperellipse` (matches `RoundedSuperellipseBorder`). |
| `borderWidth` | `double?` | 1 | Stroke thickness, drawn inward from the outline. |
| `ringOffset` | `double?` | 0 | Outline pushed out (+) or in (−) from the bounds; radii are not adjusted. |
| `segment` | `BeamSegment?` | whole border | Clockwise span from top-centre. See [shape.md](shape.md#segments). |
| `dashes` | `int?` | 0 | 2+ = that many dashes; 0/1 solid. Not negative. |

### `BeamTiming`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `cycle` | `Duration?` | `effect.defaultCycle` | Positive. Changing it live retimes in place. Floored at `BeamConfig.minCycleSeconds`. |
| `cycleGap` | `Duration?` | `effect.defaultCycleGap` (zero) | Rest after each sweep; travelling effects only. Not negative. |
| `speed` | `double?` | 1 | Finite, positive. Replaced by a controller's `speed`; `speedListenable` wins over both. Scales the animation, never the fades. |
| `direction` | `BeamDirection?` | `forward` | `forward`, `reverse`, `bounce`. Travelling effects only. |
| `phaseOffset` | `double?` | 0 | Fraction of a cycle, 0–1. |
| `huePeriod` | `Duration?` | `effect.defaultHuePeriod` | Positive. Changing it live re-phases the drift (one jump). |

The effects' own defaults are getters on `BeamEffect` (`defaultCycle`,
`defaultCycleGap`, `defaultHueMode`, `defaultHuePeriod`) in
`effects/beam_effect.dart`.

### `BeamPlayback`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `active` | `bool?` | true | Toggling fades in / out on springs. |
| `autoPlay` | `bool?` | true | Starts by itself. |
| `startAfter` | `Duration?` | none | Delay before autoplay. Must be null with a controller. |
| `duration` | `Duration?` | none | Total play time, then a fade-out. Must be null with a controller. |
| `repeat` | `BeamRepeat?` | `BeamRepeat.forever()` | `forever()`, `once()`, `count(n)` (n ≥ 1) cycles, then a fade-out. |
| `reducedMotion` | `BeamReducedMotion?` | `staticFrame` | `staticFrame`, `hide`, `slow` (quarter speed), `animate`. See [accessibility.md](accessibility.md). |
| `pauseWhenOffscreen` | `bool?` | true | Stops the clock while the beam is more than 256 px outside its nearest `Scrollable`'s viewport; resumes where it left off. No `Scrollable` → no effect. |
| `fadeCurve` | `Curve?` | critically damped springs | Replaces both fades. `BeamPlayback.cssEase` is the web's `ease`. |
| `debugFrozenAt` | `Duration?` | none | Pins the beam to one instant and never starts its clock; for goldens and captures. |

**Release-mode validation.** `BeamTiming` values, a controller's `speed`,
`BeamRepeat.count`, and palette lists are checked at resolve time in release
builds too, and throw `ArgumentError` (`models/model_validation.dart`).

## Shorthands and precedence

```text
shorthand (colors:, active:, borderRadius:)  >  value object on the widget  >  BorderBeamTheme (inner over outer)  >  effect default
```

The effect follows the same order: widget `effect:` → nearest theme's
`effect` → `BeamEffect.rotate()`. Effects never merge; a widget's effect
replaces the theme's whole. Details: [theming.md](theming.md).

## `BorderBeamController`

```dart
final controller = BorderBeamController();
BorderBeam(controller: controller, child: card);

controller.start();                         // fade in, play; resumes a paused, showing beam
controller.pause();                         // freeze the frame (no fade)
controller.resume();
controller.speed = 2;                       // finite, positive (throws otherwise)
controller.seek(const Duration(seconds: 1)); // jump the timeline; fades unaffected
controller.pulse();                         // one brightness bump that settles
controller.flash();                         // a sharper blink: hold, then decay
controller.stop();                          // fade out, halt
```

- **Ownership.** Attached, the controller owns playback exclusively:
  `playback.startAfter` and `playback.duration` must be null (on the widget
  *and* any theme — asserted), `active` and `autoPlay` are ignored, the
  controller's `speed` replaces `timing.speed`, and the beam starts hidden
  until `start()`.
- `speed` and `seek` move the animation only; fades and accents run on real
  time. `speedListenable` still wins over the controller's rate;
  `BeamReducedMotion.slow` still quarters it.
- `pulse()` / `flash()` are no-ops while the beam is hidden or frozen;
  repeated calls each start a fresh accent.
- `isAttached`, `isActive` (visible, fading counts), `isRunning` (producing
  frames). It notifies when one of its methods is called — not when the beam
  changes state by itself; use `onActivate` / `onDeactivate` for that.
- **One controller, one beam** (asserted). Handing it to another beam in the
  same frame is fine. A beam under a `BeamSync` cannot take one.

## Driving the beam: `progress`, `follow`, listenables

Summary; details in [motion.md](motion.md#driving-the-travel-yourself).

| Input | Type | What it does |
| --- | --- | --- |
| `progress` | `double?` 0–1 | Places the travel; the clock keeps running underneath (fade, hue, `line`'s spikes stay alive). Linear, stays lit (no gap rest, no end fades). Repaints without re-resolving the config. |
| `follow` | `Offset?` | Eases the travel to the border point nearest the point (critically damped). Null hands it back to the clock without a snap, keeping its direction. `BeamHover` wires it to the mouse. |
| `strengthListenable` | `ValueListenable<double>?` | Per-frame opacity scale. |
| `speedListenable` | `ValueListenable<double>?` | Per-frame rate. |

Ambient effects (`pulse`) ignore `progress` and `follow`.

## `BeamSync`

```dart
BeamSync(
  child: Row(children: [
    for (final (i, card) in cards.indexed)
      BorderBeam(timing: BeamTiming(phaseOffset: i / cards.length), child: card),
  ]),
)
```

`const BeamSync({required Widget child, bool active = true, double speed = 1,
BeamReducedMotion reducedMotion = BeamReducedMotion.staticFrame})`. One
ticker and one timeline for every beam below. The group owns playback:
`active`, `autoPlay`, `startAfter`, `duration`, `repeat`, `fadeCurve`,
`pauseWhenOffscreen`, `timing.speed`, `speedListenable`, and per-beam
`reducedMotion` are ignored below it; a member's `BorderBeamController`
asserts. Effect, palette, shape, `phaseOffset` and `cycle` stay per beam (a
member changing its `cycle` retimes only itself). Details:
[motion.md](motion.md#beamsync).

## `BeamDecoration`

The renderer as a `Decoration`, for an existing `Container`. Put it in
`foregroundDecoration:` (paints over the child, as `BorderBeam` does):

```dart
Container(
  foregroundDecoration: BeamDecoration(
    effect: const BeamEffect.rotate(),
    brightness: Theme.of(context).brightness, // required
    theme: BorderBeamTheme.of(context),       // optional: inherit app defaults
    colors: BeamColors.ocean,
    borderRadius: 16,
  ),
  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
  child: content,
)
```

Takes `effect`, `brightness` (required), `theme`, `colors`, `active`,
`borderRadius`, `style`, `shape`, `timing`, `playback`. A `BoxPainter` has no
`BuildContext`, so compared with `BorderBeam`:

- ambient theming is passed in, not read (`effect` falls back to
  `theme.effect`, then `rotate()`);
- its ticker is not muted by `TickerMode` (keeps ticking in a scrollable's
  cache extent or under an inactive route);
- `reducedMotion` and `pauseWhenOffscreen` are inert;
- `active` is a starting state: changing any field replaces the painter, so
  flipping `active` cuts instead of fading;
- `lerpFrom`/`lerpTo` return null, so an `AnimatedContainer` snaps;
- `hitTest` returns false.

Prefer `BorderBeam` when any of these matter.

## Interaction wrappers

```dart
BeamFocusRing(borderRadius: 12, child: TextField(decoration: decoration));
BeamHover(borderRadius: 20, child: pricingCard);
BeamPress(borderRadius: 20, onTap: submit, child: card);
```

| Widget | Lights when | `effect` default | Other parameters |
| --- | --- | --- | --- |
| `BeamFocusRing` | `child`'s subtree (or `focusNode`) has focus and `FocusManager.highlightMode` is traditional (keyboard/mouse) | `rotate()` | `focusNode`, `alwaysShow` (also under touch focus). `colors` falls back to `style.colors`, the theme's colours, then `BeamColors.ocean`. |
| `BeamHover` | the cursor is over `child`; the travel follows it | `rotate()` | `followPointer` (default true), `holdAfterExit` (default 300 ms). |
| `BeamPress` | a pointer is down on `child`, held at least `minimumDuration` | `pulse()` | `minimumDuration` (default 600 ms; `Duration.zero` releases on pointer-up), `onTap` (pointer lifts inside; bypasses the gesture arena). |

All three also take `colors`, `borderRadius`, `style`, `shape`, `timing` and
pass them to an inner `BorderBeam`; transitions use the beam's own fades.
Their `effect` is a non-nullable parameter with a default, so a
`BorderBeamTheme`'s `effect` does **not** apply to them — pass `effect:`
explicitly. `BeamPress` listens through a translucent `Listener` and never
enters the gesture arena: buttons inside keep their taps, scrollables above
keep their drags.

## Pitfalls

- **Corners don't match the child.** The beam never reads the child's
  decoration. Pass the same radius (`borderRadius:` / `shape.radius`) and
  `superellipse: true` for a `RoundedSuperellipseBorder` child.
- **Beam clipped.** `rotate(comet: true)` and a positive `ringOffset` paint
  outside the child's box. Leave room (padding in the parent); remove tight
  `ClipRRect`/`ClipPath` above it.
- **Nothing shows.** Reduced motion with `BeamReducedMotion.hide`; `strength:
  0`; or, in a widget test, the shader not loaded — `setUpAll(BorderBeam.precache)`.
- **Translucent child.** Fine: the beam paints in one pass over the child.
- **Segment runs the wrong way.** Segments always run clockwise from `start`
  to `end`, wrapping through top-centre; swap the anchors.
- **Fading a beam with `Opacity`.** Forces an offscreen pass every frame. Use
  `style.strength`, `strengthListenable`, or `active`. See
  [performance.md](performance.md#impeller-keep-the-beam-off-offscreen-ancestors).
- **Palette rebuilt unequal every build** (e.g. a fresh `List` of computed
  colours that differ) re-resolves the config each frame. `BeamColors` is
  value-equal, so inline `const`/equal palettes are free.
- **Animating between configurations.** `BorderBeam` retimes `cycle` in place
  and `BeamColors.lerp` crossfades palettes; `BeamDecoration` snaps.
- **Controller + theme scheduling.** `startAfter`/`duration` in an app-wide
  `BorderBeamTheme` assert on every controller-driven beam below it.
- **Web.** Supported; the example app's web build is the live demo and CI
  builds it.

## Testing a beam

- `setUpAll(BorderBeam.precache)` before reading pixels or counting draws.
- `playback: BeamPlayback(debugFrozenAt: …)` pins a frame; goldens freeze the
  fake clock at t = 1.3 s instead (`test/border_beam/golden/golden_scene.dart`).
- The first tick after `Ticker.start()` reports elapsed 0: pump once before
  pumping durations.
- No ticker may survive disposal: `tester.binding.transientCallbackCount`
  returns to 0 (`test/border_beam/widget/border_beam_lifecycle_test.dart`).
