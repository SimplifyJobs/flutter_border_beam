# DistortionWave — usage reference

How to use `DistortionWave` and `DistortionWaveRoute`: every public type,
what each parameter does, the rules that decide where a wave opens from, and
the pitfalls. How the wave is rendered is in
[distortion_wave.md](distortion_wave.md); its cost in
[performance.md](performance.md#distortionwave); accessibility in
[accessibility.md](accessibility.md#distortionwave).

Look values (durations, distances, strengths) are tuned per type in
`lib/src/distortion_wave/look/wave_defaults.dart`. This page names fields and
describes behaviour; read that file for current numbers.

## Entry points

```dart
import 'package:prismatic/distortion_wave.dart'; // the wave alone
import 'package:prismatic/prismatic.dart';       // both effects
```

`lib/distortion_wave.dart` exports exactly: `DistortionWave`,
`DistortionWaveRoute`, `DistortionWaveController`, `DistortionWaveTheme`,
`DistortionWaveThemeData`, `DistortionWaveAnchor`,
`DistortionWaveAnchorState`, `WaveSource`, `WaveType`, `WaveStyle`,
`WaveTiming`, `WaveMotion`, `WaveLens`, `WaveGlow`, `WaveDots`,
`WavePalette`, `maxWavePaletteColors`, `WaveSnapshots`. Nothing under
`lib/src/distortion_wave/render/`, `timeline/` or `look/` is public.

| Public type | File |
| --- | --- |
| `DistortionWave` | `lib/src/distortion_wave/distortion_wave.dart` |
| `DistortionWaveRoute` | `lib/src/distortion_wave/distortion_wave_route.dart` |
| `DistortionWaveController` | `lib/src/distortion_wave/distortion_wave_controller.dart` |
| `DistortionWaveTheme`, `DistortionWaveThemeData` | `lib/src/distortion_wave/distortion_wave_theme.dart` |
| `WaveSource`, `DistortionWaveAnchor`, `DistortionWaveAnchorState` | `lib/src/distortion_wave/wave_source.dart` |
| `WaveStyle` and its groups, `WavePalette`, `WaveType`, `WaveSnapshots` | `lib/src/distortion_wave/models/` |

## Minimal use

```dart
DistortionWave(
  revealed: sent,                     // flip to run the wave
  revealedChild: const ReceiptScreen(),
  child: ReviewScreen(
    send: DistortionWaveAnchor(       // the wave opens from this button
      child: FilledButton(
        onPressed: () => setState(() => sent = true),
        child: const Text('Send'),
      ),
    ),
  ),
)
```

Flip `revealed` to `true` to send the wave out to `revealedChild`; flip it
back to `false` to collapse it into its source. Flipping mid-run turns the
wave back from wherever it is.

Optional, in `main()` after `WidgetsFlutterBinding.ensureInitialized()`:
`await DistortionWave.precache();` — loads both wave shaders and draws each
once into a 4 × 4 offscreen image so the GPU has built its pipelines before
the first wave. Without it, a wave started before the shaders load shows its
sides plainly (the side the wave is on) until they do.

## `DistortionWave`

```dart
const DistortionWave({
  Key? key,
  bool revealed = false,
  required Widget revealedChild,
  required Widget child,
  WaveSource? source,
  WaveType? type,
  WavePalette? palette,
  WaveStyle? style,
  DistortionWaveController? controller,
  double? progress,            // asserted 0–1
  WaveSnapshots? snapshots,
  bool maintainState = true,
  VoidCallback? onFinish,
})
```

| Parameter | Behaviour |
| --- | --- |
| `revealed` | Target side. `true` runs toward `revealedChild`, `false` back to `child`. Ignored while a `controller` is attached. The initial value sets the side the wave starts resting on. |
| `child` | The side shown at progress 0 (the "outgoing" side). |
| `revealedChild` | The side shown at progress 1 (the "incoming" side). |
| `source` | Where the wave opens from. Null → the anchor rules below. Read only when a run starts from rest. |
| `type` | Shorthand for `style.type`; wins over it. |
| `palette` | Shorthand for `style.palette`; wins over it. |
| `style` | Everything else; over the nearest `DistortionWaveTheme`'s style, over the type's tuned defaults. |
| `controller` | Attached, it owns playback; `revealed` is ignored. |
| `progress` | Non-null holds the wave at that point of its life (0–1) instead of animating. Back to null plays on from the held point toward `revealed` (or the controller's `isRevealed`). |
| `snapshots` | When the sides are pictured again while bent. Null → theme's → `WaveSnapshots.onChange`. |
| `maintainState` | `true`: the hidden side stays mounted at rest, tickers muted. `false`: the hidden side is built only while a wave runs (it loses its state). |
| `onFinish` | Called when a run arrives (reveal: the edges have cleared; collapse: back at rest), the reduced-motion crossfade included. Not called for a run interrupted by another run or by `controller.seek`. |
| `DistortionWave.precache()` | `static Future<void>`. See above. |

### Layout, touches, focus, semantics

- **Layout.** With bounded constraints the wave takes the biggest size; with
  an unbounded axis it takes the larger of its two children. Both sides are
  then laid out tight to that size — each side fills the wave.
- **Opaque sides.** Both sides are drawn from pictures of themselves while the
  wave bends them; transparent pixels in a side show nothing behind the wave.
  Give both sides an opaque background (a `ColoredBox`, a `Scaffold`).
- **Touches.** At rest, the visible side. While a wave runs, neither — except
  that once a reveal no longer bends the revealed side (the `glowing` phase:
  the front has crossed the whole view), the revealed side takes touches
  while colour lingers on the edges. Under reduced motion no side takes
  touches until the crossfade ends.
- **Focus.** The side off screen — at rest, or held at either end by
  `progress` — is wrapped in `ExcludeFocus`: Tab and autofocus never land on
  it. During a run neither side is excluded.
- **Tickers.** At rest the hidden side sits under `TickerMode(enabled:
  false)`. While a wave runs, or while held by `progress`, both tick.
- **Semantics.** The semantics tree contains only the side at rest, or, while
  a wave runs, the side it is heading for.

## Where the wave opens from

A wave opens from a **source**: a rect (the button, edge or avatar that
started it) and optionally a **focus** point (the touch), which the
`vertical` and `horizontal` waves lean toward (`WaveMotion.orientation`; the
`center` wave never leans).

The source of a run is taken **once, when the run starts from rest** (also
when `controller.seek` or a non-null `progress` picks the wave up at rest).
Changing `source` mid-run has no effect until the next run from rest. Order:

1. the `source:` argument of `controller.reveal` / `collapse` / `toggle`
   (honoured only at rest);
2. `DistortionWave.source`;
3. a `DistortionWaveAnchor` inside the wave (rules below);
4. the type's usual spot (`defaultWaveSource` in `wave_source.dart`): a wide
   button along the bottom for `vertical`, the left edge for `horizontal`, a
   small square in the centre for `center`. Also used when a source cannot be
   measured (its widget is gone).

### `WaveSource`

| Constructor | Coordinates | Measured |
| --- | --- | --- |
| `WaveSource.rect(Rect rect, {Offset? focus})` | the wave's own (local) | never — used as given |
| `WaveSource.key(GlobalKey key, {Offset? focus})` | widget measured globally; `focus` global | at the first frame of each run that needs it |
| `WaveSource.of(BuildContext context)` | global | immediately, at the call |

`WaveSource.of(context)` measures the widget at `context`; if `context` is
inside a `DistortionWaveAnchor`, it measures the anchor instead and carries
the anchor's last touch as the focus. Call it where the wave starts (a
button's `onPressed`), not in `build`. All sources are value-equal.

The stage (`RenderWaveStage`) measures its source on the first frame of a
run that needs it, keeps that measurement until the run ends (so nothing
jumps mid-wave), and drops it whenever it paints at rest. A
`WaveSource.key` handed in unchanged is therefore re-measured every run,
and finds a widget that moved since (a scroll, a rotation). Pinned by
`a source by key is measured afresh each run` in
`test/distortion_wave/widget/distortion_wave_test.dart`.

### `DistortionWaveAnchor`

```dart
DistortionWaveAnchor(child: FilledButton(onPressed: send, child: const Text('Send')))
```

Marks its child as a candidate source and records where it was touched.
`DistortionWaveAnchorState.lastTouch` is the last pointer-down position
(global), or null.

An anchor counts as **pressed** when:

- a pointer goes down on it (a `Listener`; never enters the gesture arena);
- focus lands anywhere inside it (`Focus.onFocusChange`; the anchor's own
  `Focus` is not focusable, skips traversal, adds no semantics). When the
  focus arrives in keyboard highlight mode (`FocusHighlightMode.traditional`),
  the anchor drops its stale `lastTouch`, so the wave opens evenly instead of
  leaning toward an old touch.

Each side of a wave has its own `WaveAnchorScope` (one shared
`WaveAnchorRegistry` per wave, which records each anchor's side). When a run
starts, the side on screen picks:

1. the anchor pressed or focused last, if it is on the side on screen;
2. else the **only** anchor on the side on screen, if there is exactly one —
   this covers a screen reader activating a button without touching or
   focusing it;
3. else the anchor pressed or focused last on the other side — so a collapse
   started by something other than an anchor goes back into the anchor the
   wave opened from;
4. else none (→ `source:` was null too → the type's usual spot).

With two or more anchors on the side on screen and none pressed there, rule
3 applies. Anchors inside a `DistortionWaveRoute`'s page register with the
route's own scope, not with any enclosing `DistortionWave`.

## `DistortionWaveRoute`

```dart
DistortionWaveAnchor(
  // A context inside the anchor, so WaveSource.of measures the anchor and
  // carries its touch.
  child: Builder(
    builder: (context) => FilledButton(
      onPressed: () => Navigator.of(context).push(
        DistortionWaveRoute<void>(
          source: WaveSource.of(context),
          builder: (context) => const ReceiptScreen(),
        ),
      ),
      child: const Text('Send'),
    ),
  ),
)
```

```dart
DistortionWaveRoute({
  required WidgetBuilder builder,
  WaveSource? source,
  WaveType? type,
  WavePalette? palette,
  WaveStyle? style,
  WaveSnapshots? snapshots,
  bool maintainState = true,      // PageRoute.maintainState
  RouteSettings? settings,
  bool fullscreenDialog = false,
})
```

- A `PageRoute`, `opaque`, no barrier. The push plays the wave from `source`
  into the new page; a pop collapses it back into the same source.
- **No anchor discovery.** The route opens from `source` or, when null, the
  type's usual spot. Pass `WaveSource.of(context)` from the button that
  pushes.
- **The page underneath** is pictured from its route's own page
  `RepaintBoundary` (`toImageSync`) after the push's first frame, and again
  after a pop starts; the wave bends that picture. Until the first picture
  exists the outgoing side draws nothing, so the page underneath shows
  through unchanged. `canTransitionFrom` is false: the page underneath plays
  no exit transition of its own. In debug builds a page that still needs
  paint is skipped (`debugNeedsPaint`); in release it is pictured as last
  painted.
- **Durations:** `transitionDuration` is the spec's full reveal
  (`WaveSpec.duration`), `reverseTransitionDuration` the collapse
  (`duration / returnSpeed`); both 300 ms under reduced motion. The route's
  animation runs linearly forward and on `timing.easing.flipped` in
  reverse — the same timeline as `DistortionWave`.
- **Theme:** the look (`spec`) is resolved **once**, lazily, against
  `DistortionWaveTheme.of(navigator.context)`. Put the theme above the
  `Navigator` (around `MaterialApp`, or in its `builder`) for routes to see
  it; a theme inside another page does not reach the route.
- The new page needs an opaque background, as a `DistortionWave` side does.
- `maintainState` here is `PageRoute.maintainState` (keep the route alive
  when covered), not the widget's hidden-side switch.

## `DistortionWaveController`

```dart
final wave = DistortionWaveController(); // or DistortionWaveController(revealed: true)

DistortionWave(controller: wave, revealedChild: receipt, child: review);

wave.reveal();                          // send it out (from `source:` if given, at rest)
wave.collapse();                        // back into the source it opened from
wave.toggle();                          // reveal or collapse by isRevealed
wave.seek(0.4);                         // hold at 0.4; stops any run
```

| Member | Behaviour |
| --- | --- |
| `DistortionWaveController({bool revealed = false})` | Starts resting on the first side, or the revealed side. |
| `reveal({WaveSource? source})` | Runs toward the revealed side. |
| `collapse({WaveSource? source})` | Runs back to the first side, into `source` if given and the wave is at rest, else into the source it opened from. |
| `toggle({WaveSource? source})` | `collapse` when `isRevealed`, else `reveal`. |
| `seek(double progress)` | Holds the wave at `progress` (clamped 0–1), stopping any run; `isRevealed` becomes `progress >= 0.5`. A later `reveal`/`collapse` continues from there. |
| `isRevealed` | On, or heading for, the revealed side. |
| `progress` | 0–1; without a wave attached, 0 or 1 by `isRevealed`. |
| `isRunning` | A run is in flight. |

- Attached, it **owns playback**: `DistortionWave.revealed` is ignored.
- **One wave at a time** (asserted). Moving it to another wave and outliving
  its wave are both fine; dispose it yourself.
- A `ChangeNotifier`: notifies on every `reveal` / `collapse` / `toggle` /
  `seek` call, and when a run arrives.

## Holding and scrubbing: `progress`

`progress` is the wave's whole life on one 0–1 axis (anticipation, launch,
travel, lingering edges). Non-null holds the frame there; `WaveFrame.at` is a
pure function of it, so a held frame is deterministic (goldens use this).
Driving it from a gesture:

```dart
GestureDetector(
  onVerticalDragUpdate: (d) => setState(() {
    // dragExtent: how far a drag travels for the whole wave, in px.
    _held = ((_held ?? 0) - d.primaryDelta! / dragExtent).clamp(0.0, 1.0);
  }),
  onVerticalDragEnd: (_) => setState(() {
    _revealed = (_held ?? 0) >= 0.5; // where to play on to
    _held = null;                    // let go: plays on from the held point
  }),
  child: DistortionWave(
    progress: _held,
    revealed: _revealed,
    revealedChild: next,
    child: current,
  ),
)
```

Picking a resting wave up with `progress` takes the run's source as a run
would (anchor rules included).

## Timeline and durations

A reveal runs linearly over its whole duration; the curve shaping the front's
travel is `WaveTiming.easing`, applied inside the timeline. A collapse runs
back on `WaveTiming.easing`, `returnSpeed` times faster, so it answers at
once (it is quick through the end of the wave's life, where little is on
screen). A partial run (flipped mid-way) takes its share of a full run's
time. `WaveSpec.duration` is the anticipation plus whichever part ends last:
the swell, the colour on the edges, the hairline, or the last dot. Under
reduced motion a full run takes 0.3 s and is a crossfade.

## `WaveType`

| Value | Front | Use |
| --- | --- | --- |
| `WaveType.vertical` (default) | Leaves a wide source (a bottom button) as its own outline and opens into an arc that bows up the view; leans with the touch. | Confirming a payment, sending, submitting. |
| `WaveType.horizontal` | The vertical wave on its side, from a tall source at the left; leans with the touch. Same tuned values as `vertical`. | An edge swipe, a side tab, going on to the next step. |
| `WaveType.center` | A ring spreading from the centre of a round source. The source is left alone — no pull, swell, blur or colour on it — so it can change in plain view. Its own tuning: shorter lengths (for a sheet or card rather than a full screen), `WavePalette.green`, no colour fringing, no colour or dots gathered before launch. | A success state on an avatar or icon, inside a sheet or card. |

`type` also selects the defaults every unset style field falls back to.

## Palettes: `WavePalette`

```dart
DistortionWave(palette: WavePalette.ocean, ...);
DistortionWave(palette: WavePalette.single(const Color(0xFF35BA00)), ...);
DistortionWave(palette: WavePalette.fromBeamColors(BeamColors.aurora), ...);
DistortionWave(
  palette: const WavePalette(
    colors: [Color(0xFF6B2BFF), Color(0xFFF02BD9), Color(0xFF33A1FF)],
    ahead: Color(0xFFFFB6F0),   // fringe riding just ahead of the front
    behind: Color(0xFF2B3BFF),  // fringe trailing behind it
  ),
  ...
);
```

| API | Behaviour |
| --- | --- |
| `const WavePalette({required List<Color> colors, required Color ahead, required Color behind})` | `colors` flow along the front and round the edges, wrapping last → first. Only the first `maxWavePaletteColors` (8) are used; fewer are cycled to fill the shader's 8 slots; an empty list uses `ahead` alone. All colours are drawn opaque (alpha ignored). |
| `WavePalette.single(Color)` | One colour, with lightened and deepened neighbours; `ahead` lighter, `behind` deeper. Opaque. |
| `WavePalette.fromBeamColors(BeamColors)` | The beam palette's resolved stops (first 8) along the front; `ahead` is a lightened first stop, `behind` a deepened middle stop. Opaque. |
| Presets | `colorful` (default for `vertical` and `horizontal`), `green` (default for `center`), `ocean`, `sunset`, `mono`. |
| `WavePalette.presets` | `Map<String, WavePalette>` of the five, in that order. |

Colours are mixed in OKLab (`lib/src/core/oklab.dart`), so neighbouring hues
never pass through grey. Palettes are value-equal; `toString` names a preset.

## Style: `WaveStyle` and its groups

```dart
const WaveStyle({
  WaveType? type,
  WavePalette? palette,
  WaveTiming? timing,
  WaveMotion? motion,
  WaveLens? lens,
  WaveGlow? glow,
  WaveDots? dots,
})
```

Every field of every group is nullable and means *inherit*. All are `const`,
value-equal, with `copyWith` (null keeps) and `merge` (the argument's
non-null fields win; `WaveStyle.merge` merges the groups field by field, so
`WaveStyle(lens: WaveLens(blur: 0))` over a theme changes only the blur).

**Precedence**, per field:

```text
widget shorthand (type:, palette:)  >  widget style  >  DistortionWaveTheme (inner over outer)  >  waveDefaults(type)
```

The type is settled first (from the widget and theme, else `vertical`), and
that type's tuned style fills every remaining field. The settled result is
the internal `WaveSpec` (`models/wave_spec.dart`): seconds and logical
pixels, value-equal, so a rebuild with an equal style changes nothing.

**Validation.** In debug builds the constructors assert the bounded ranges
they document: the 0–1 and 0–2 fields, `blur`, `returnSpeed` and dot
`count`. The minimums on lengths (the "At least" entries below, such as
`lead`, `tail`, `rimWidth` and `rimSoftness`) are not asserted: a smaller
value is raised to the minimum. `WaveSpec` settles every value this way in
every build mode, so release builds stay safe too: a NaN becomes the field's
floor, out-of-range values are clamped (lengths to their minimums, 0–1
fields to 0–1, `blur` to 0–64, `returnSpeed` to 0.01–100, dot `count` to
0–256), and a non-finite `pull`, `inhale`, `amplitude` or `swell` becomes 0.

### `WaveTiming` — the wave's life

| Field | Type | Meaning |
| --- | --- | --- |
| `anticipation` | `Duration?` | Pull toward the source before the wave leaves it. |
| `travel` | `Duration?` | From leaving the source to the front having settled past the far side. |
| `easing` | `Curve?` | How the front covers its way over `travel` (default leaves at full speed, settles softly); also the collapse's curve. |
| `returnSpeed` | `double?` | How much faster the collapse runs than the reveal. Asserted > 0 and ≤ 100. |
| `linger` | `Duration?` | After launch, when the wipe of the edge colour starts. Negative starts it before launch, so the wipe follows close behind the front. |
| `rimFade` | `Duration?` | How long the wipe of the edge colour takes. |
| `rimEasing` | `Curve?` | The wipe's curve (default ease-in-out). |
| `hairlineLinger` | `Duration?` | How long the hairline holds on after the colour starts to go. |
| `hairlineFade` | `Duration?` | How long the hairline's wipe takes. |

### `WaveMotion` — before the launch, and the lean

| Field | Type | Meaning |
| --- | --- | --- |
| `pull` | `double?` pt | How far the anticipation pulls content toward the source. |
| `inhale` | `double?` pt | How far out the ring of colour that falls onto the source starts. |
| `gatherGlow` | `double?` 0–2 | Colour gathered through the anticipation: 1 = half the front's colour by launch, 2 = all, 0 = none. |
| `gatherDots` | `double?` 0–1 | Visibility of dots hopping toward the source before launch; 0 leaves only the dots that fly out with the front. |
| `launchGap` | `double?` pt | How far out from the source's outline the front starts; 0 = from the source itself. |
| `orientation` | `double?` 0–1 | Lean toward the touch: 0 opens evenly from the whole source, 1 from under the finger. `center` never leans. |

### `WaveLens` — the bend and the blur

| Field | Type | Meaning |
| --- | --- | --- |
| `amplitude` | `double?` pt | How far the swell lifts content as it passes. |
| `width` | `double?` pt | Width of the swell. |
| `aberration` | `double?` | Colour fringing: how far red and blue part, as a share of how far content moved. 0 turns it off. |
| `swell` | `double?` pt | How far the front bends along its length. |
| `blur` | `double?` pt, 0–64 | Blur radius on the front; 0 turns the blur off (and skips the blurred copies). |
| `blurAhead` | `double?` pt | Distance ahead of the front over which the blur gathers. |
| `blurBehind` | `double?` pt | Distance behind the front over which the blur clears. |

### `WaveGlow` — colour on the front and the edges

| Field | Type | Meaning |
| --- | --- | --- |
| `lead` | `double?` pt | How far the colour feathers ahead of the front. At least 1. |
| `tail` | `double?` pt | Length of the colour trailing behind the front. At least 1. |
| `strength` | `double?` 0–1 | Peak opacity of the band on the front; 0 hides it. |
| `rimWidth` | `double?` pt | How far in from the view's edges the lingering colour reaches. At least 0.5. |
| `rimUnevenness` | `double?` 0–2 | 0 = even thickness all round; 1 = drifting lumps with thin stretches; past 1 the thinnest stretches break off. |
| `rimStrength` | `double?` 0–1 | Peak opacity of the edge colour; 0 leaves none behind. |
| `rimSoftness` | `double?` pt | How softly the edge colour is wiped away. At least 1. |
| `rimPulse` | `double?` 0–1 | How alive the edge colour is (lumps drift and breathe, brightness runs round, colours flow); 0 keeps a slow drift. |
| `hairlineWidth` | `double?` pt | Width of a hairline on the view's edge, over the colour; 0 draws none. |
| `hairlineOpacity` | `double?` 0–1 | Peak opacity of the hairline. |
| `hairlineWhite` | `double?` 0–1 | How far the hairline whitens where the pulse's light runs. |
| `cornerRadius` | `double?` pt | Corner radius of the view the wave fills; the edge colour and hairline follow it (rounded superellipse corners). Setting it anywhere (widget or theme) opts out of the display's corners. |

### `WaveDots` — the sparks

| Field | Type | Meaning |
| --- | --- | --- |
| `count` | `int?` 0–`WaveDots.maxWaveDots` (256) | How many dots; 0 draws none. |
| `size` | `double?` pt | Diameter of the largest dot. |
| `reach` | `double?` pt | How far from the source the farthest dot is born in the anticipation. |
| `flight` | `double?` pt | How far a dot flies toward the source in one hop. |
| `gap` | `double?` pt | How close to the source a dot comes before it has faded. |
| `life` | `Duration?` | After launch, when the last dot has faded. |
| `spread` | `double?` 0–1 | How far the dots are thrown, as a share of the front's way: 1 lets the quickest ride off the view. |

## Display corners

A wave that **fills the view** puts its edge colour and hairline on the
display's own corners, each corner its own radius, read from
`MediaQuery.displayCornerRadii` (via `MediaQuery.maybeDisplayCornerRadiiOf`).
"Fills the view" means the wave's top-left is at the global origin and its
size equals `MediaQuery.sizeOf` (both within half a pixel). Otherwise — a
wave in a sheet or a card, or a platform that reports no radii — the edges
use `WaveGlow.cornerRadius` (the type's default when unset) on all four
corners.

- Android reports display corners to Flutter. iOS does not: an app supplies
  them with `MediaQueryData.applyDisplayCornerRadii`
  (`example/lib/src/display_corners.dart` measures them through a method
  channel and re-measures on rotation).
- Setting `WaveGlow.cornerRadius` on the widget's style or any
  `DistortionWaveTheme` style turns display corners off for that wave. For a
  route, only the route's `style` and the theme count.

## Theme: `DistortionWaveTheme`

```dart
DistortionWaveTheme(
  data: const DistortionWaveThemeData(
    style: WaveStyle(palette: WavePalette.ocean, lens: WaveLens(aberration: 0)),
    snapshots: WaveSnapshots.onChange,
  ),
  child: MaterialApp(home: home),   // above the Navigator, so routes see it too
)
```

- `DistortionWaveThemeData({WaveStyle? style, WaveSnapshots? snapshots})`,
  value-equal, `copyWith`, `merge` (style merges field by field; snapshots:
  the argument's wins when set).
- `DistortionWaveTheme.of(context)` merges **every** enclosing theme outer to
  inner and depends on each (empty data when there is none);
  `maybeOf(context)` returns null when there is none.
- Applies to every `DistortionWave` below it, and to `DistortionWaveRoute`s
  pushed on a `Navigator` below it (resolved once per route).

## Snapshots: `WaveSnapshots`

While the wave bends content it draws both sides from GPU pictures of them.

| Value | A side is pictured again… | Use when |
| --- | --- | --- |
| `WaveSnapshots.onChange` (default) | when content under it repaints — a repaint that travels up through the side to the stage. | Almost always. |
| `WaveSnapshots.everyFrame` | on every frame the wave bends it. | Content inside a nested `RepaintBoundary` (a list item, a spinner wrapped in one, a video) must keep moving through the wave: such repaints stop at their boundary, so under `onChange` that content holds still while it is bent. |

Each new picture is one offscreen rasterisation of the side, plus two small
blurred copies baked with `ImageFilter.blur` once the frame has blur to
show. `everyFrame` pays that every frame for each side shown. Exact costs:
[performance.md](performance.md#distortionwave).

## Fallbacks

| Situation | What the wave does |
| --- | --- |
| Reduced motion (`MediaQuery.disableAnimations`) | A plain crossfade, the outgoing side fading over the incoming one; a full run takes 0.3 s. Routes too. |
| A side holding a platform view (map, web view) | It cannot be pictured (`OffsetLayer.supportsRasterization()` is false): that run crossfades. The next run from rest tries the wave again. |
| A `DistortionWaveRoute` over a page holding a platform view | The page underneath cannot be pictured: the new page fades in over it, and out on pop. |
| Shaders still loading | The side the wave is on is shown plainly until they load. |
| A source that cannot be measured | The type's usual spot. |

## Recipes

**Success ring on an avatar inside a sheet:**

```dart
DistortionWave(
  type: WaveType.center,
  style: const WaveStyle(glow: WaveGlow(cornerRadius: 28)), // the sheet's corners
  revealed: done,
  revealedChild: const DoneSheet(),
  child: PendingSheet(avatar: DistortionWaveAnchor(child: avatar)),
)
```

**One-shot, then back:** use `onFinish` to collapse after a reveal arrives,
or drive both from a controller:

```dart
controller.reveal();
// later
controller.collapse();
```

**Brand palette from the beam's colours:**
`WavePalette.fromBeamColors(BeamColors.fromSeed(brand))`.

**No fringing, no blur, no dots:**
`WaveStyle(lens: WaveLens(aberration: 0, blur: 0), dots: WaveDots(count: 0))`.

## Pitfalls

- **A black or empty area while the wave runs** — a side (or the route's new
  page) has a transparent background. Give it an opaque one.
- **Part of the screen holds still while the wave passes** — it sits in a
  nested `RepaintBoundary`. Use `snapshots: WaveSnapshots.everyFrame`.
- **The wave opens from the wrong place** — the source is read only at the
  start of a run from rest; with several anchors on one side, only a pressed
  or focused one is picked. Pass `source:` (or `controller.reveal(source:)`)
  explicitly when in doubt.
- **A route ignores the theme** — the theme is below the `Navigator`. Move it
  above.
- **The edge colour misses the screen's corners on iOS** — iOS does not
  report display corners; supply them with
  `MediaQueryData.applyDisplayCornerRadii`, or set `WaveGlow.cornerRadius`.
- **`revealed` does nothing** — a controller is attached; it owns playback.
- **Two waves, one controller** — asserts. One controller per wave.

## Testing a wave

- `setUpAll(DistortionWave.precache)` before anything that reads pixels or
  counts draws; before the shaders load, a wave shows its sides plainly.
- Hold frames with `progress:` for goldens and pixel checks (see
  `test/distortion_wave/golden/wave_golden_test.dart`).
- Reduced motion: wrap in `MediaQuery(data: …copyWith(disableAnimations: true))`.
- Helpers: `test/distortion_wave/widget/wave_test_utils.dart`. Lifecycle and
  route tests run under `leak_tracker_flutter_testing`
  (`LeakTesting.enable()`): dispose every controller a test creates
  (`addTearDown(controller.dispose)`).
