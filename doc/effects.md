# Effects

An effect decides where light sits along the border and how it moves. Pick one with `effect:` on `BorderBeam`, `BorderBeam.overlay`, `BeamDecoration`, or any of the interaction wrappers, or set a default for a subtree with `BorderBeamThemeData.effect`. With nothing set, a beam uses `BeamEffect.rotate()`.

```dart
BorderBeam(effect: const BeamEffect.flow(), child: composer);
```

All eight are drawn by the same shader in the same single draw call, so they cost the same order of GPU time. Choose for the look and the meaning.

## The two families

**Travelling** — `rotate`, `line`, `shimmer`, `charge`. A position runs along the border (or, for `shimmer`, across the box) once per `cycle`. These respond to:

- `BeamTiming.direction` — `forward`, `reverse`, or `bounce` (alternating each cycle);
- `BeamTiming.cycleGap` — a rest after each sweep;
- `BeamTiming.phaseOffset` — where in the cycle the timeline starts;
- `BorderBeam.progress` — the position from a value instead of the clock;
- `BorderBeam.follow` — the position eased toward a point in the box.

**Ambient** — `pulse`, `halo`, `flow`, `spin`. Light breathes or streams around the whole border at once. They ignore `cycleGap`, `phaseOffset`, `progress`, and `follow`. `flow` and `spin` stream counter-clockwise under `BeamDirection.reverse`; `bounce` does not alternate them, and `pulse` and `halo` have no direction.

`BeamEffect.travels` answers the question in code.

## Defaults

| Effect | Family | `cycle` | `cycleGap` | `hueMode` | `huePeriod` |
| --- | --- | --- | --- | --- | --- |
| `rotate` | travelling | 2.4s | 0 | `pingPong` | 12s |
| `line` | travelling | 3.1s | 0 | `pingPong` | 8s |
| `pulse` | ambient | 2.3s | — | `continuous` | 16s |
| `halo` | ambient | 2.3s | — | `continuous` | 14s |
| `flow` | ambient | 6s | — | `none` | — |
| `spin` | ambient | 3s | — | `none` | — |
| `shimmer` | travelling | 1.4s | 1.6s | `none` | — |
| `charge` | travelling | 2.6s | 0.6s | `none` | — |

Every one of these is a fallback: `BeamTiming` and `BeamStyle` override them field by field. `BeamEffect.defaultCycle`, `defaultCycleGap`, `defaultHueMode`, and `defaultHuePeriod` expose them in code.

Each effect is also tuned twice — once for dark surfaces and once for light ones — and `BeamStyle.theme` picks which (see [theming](theming.md)).

## `rotate` — the default

A beam laps the whole border, trailing a soft tail and lighting the inside edge as it passes, with a hot core just behind its head. For cards, panels, and surfaces.

```dart
BorderBeam(
  effect: const BeamEffect.rotate(length: 1.4, count: 2, comet: true),
  child: card,
);
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `length` | 1 | Tail length multiplier, clamped to 0.25–2. Must be positive. |
| `count` | 1 | How many beams lap the border at once, evenly spaced. 1–4. |
| `comet` | false | Adds an outer glow that trails the head *outside* the border. Leave room around the widget. |

Its inner glow scales with the box, so the same effect reads on a chip and on a full-screen surface. On a small, round control, pair it with `BeamShape.stadium()`.

With `progress`, the head sits at that fraction of the border — a glowing progress ring. With a [segment](shape.md#segments), the beam appears at the segment's start and travels to its end.

## `line` — inputs

A streak rides one edge, its colours spread across it, with soft spikes of light rising inward from the edge, each breathing on its own beat. For text fields, search bars, and composers, where a full lap would fight the caret for attention.

```dart
BorderBeam(effect: const BeamEffect.line(edge: BeamEdge.top), child: searchBar);
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `edge` | `BeamEdge.bottom` | The edge the streak rides. |

A timed streak eases along the edge, widening through the middle of its run and fading in and out near the ends. It runs in reading order — left to right on the top and bottom edges, top to bottom on the side edges — under `BeamDirection.forward`; `reverse` mirrors it.

With `progress`, the streak sits at that fraction of the edge and stays lit: a progress bar. With `follow`, only the coordinate along the edge counts.

With a [segment](shape.md#segments), the streak rides the segment instead of `edge`, rounding its corners: `BeamSegment.bottomEdge` carries it around both bottom corners, `BeamSegment.bottomHalf` up both sides.

The palette is spread across the streak rather than around the ring, so every colour of the palette shows at once.

## `pulse` — a contained "thinking" state

A dim ring all the way round, with patches of colour swelling and ebbing at the four corners and the centres of the top and bottom edges, washing a little way inward. Each patch breathes on its own beat, so neighbours never pulse in lockstep.

```dart
BorderBeam(effect: const BeamEffect.pulse(), active: isThinking, child: card);
```

Its colours rotate continuously by default (a full turn every 16s). With a segment, only the patches inside it breathe.

## `halo` — light around the widget

A thin coloured rim with large, soft clouds of light standing off the border outside it, breathing in turn. The light is painted **outside the widget's bounds**, so give it room — padding in the parent and no tight `ClipRRect` above the beam. The clouds scale with the widget's size, capped so a full-screen surface does not throw light across the whole screen.

```dart
Padding(
  padding: const EdgeInsets.all(32),
  child: BorderBeam(effect: const BeamEffect.halo(), child: card),
);
```

`halo` paints in the same single pass over the child as every other effect, so the child does not need to be opaque.

## `flow` — listening

The palette streams continuously around the whole border — half a turn per cycle — with an inner glow that drifts more slowly, so the colour flows through it, and each patch of it swells and ebbs on its own beat. The look of an assistant that is listening.

```dart
BorderBeam(effect: const BeamEffect.flow(), colors: BeamColors.aurora, child: composer);
```

Because the colours already move, the hue drift is off by default.

## `spin` — the animated gradient border

A full gradient ring of the palette spinning around the border, once per cycle, with a narrow glow on both sides of the stroke. The classic animated gradient border, for buttons, badges, and focus — `BeamFocusRing` uses it by default.

```dart
BorderBeam(
  effect: const BeamEffect.spin(),
  shape: const BeamShape.stadium(),
  child: button,
);
```

It pairs well with `BeamShape.dashes` for a "marching" ring.

## `shimmer` — a glint

A band of light sweeps across the box at an angle, lighting the border where it crosses it and catching each crossing with a soft inner light, then rests for the cycle gap (1.6s by default). For calls to action and new items.

```dart
BorderBeam(effect: const BeamEffect.shimmer(angle: 30), child: cta);
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `angle` | 20 | The sweep's tilt in degrees from vertical; 0 sweeps straight left to right. The angle is kept true in pixels on any aspect ratio. |

`reverse` sweeps the other way. `progress` places the band at that fraction of its sweep.

## `charge` — progress

The border fills clockwise from top-centre, with a hot leading edge. Without a driven value it fills once per cycle and rests for the cycle gap (0.6s by default) before starting again.

```dart
BorderBeam(effect: const BeamEffect.charge(), progress: uploaded / total, child: card);
```

Drive it with `BorderBeam.progress` for determinate progress. With a segment it fills the segment from its start; `BeamDirection.reverse` fills from the other end.

## Choosing at runtime

Effects are values: two `BeamEffect.rotate(count: 2)` are equal, and `BeamEffect.values` lists all eight with their default parameters. Store one in state and hand it to the widget — no switch needed:

```dart
BorderBeam(effect: _effect, child: card);
```

Swapping the effect on a live beam keeps it running; the new effect picks up from the same clock.
