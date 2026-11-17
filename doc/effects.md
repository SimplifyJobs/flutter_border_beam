# Effects

An effect decides where light sits along the border and how it moves. Pick one with `effect:` on `BorderBeam`, `BorderBeam.overlay`, `BeamDecoration`, or any of the interaction wrappers, or set a default for a subtree with `BorderBeamThemeData.effect`. With nothing set, a beam uses `BeamEffect.rotate()`.

```dart
BorderBeam(effect: const BeamEffect.line(), child: composer);
```

All three are drawn by the same shader in the same single draw call, so they cost the same order of GPU time. Choose for the look and the meaning.

## The two families

**Travelling** — `rotate`, `line`. A position runs along the border once per `cycle`. These respond to:

- `BeamTiming.direction` — `forward`, `reverse`, or `bounce` (alternating each cycle);
- `BeamTiming.cycleGap` — a rest after each sweep;
- `BeamTiming.phaseOffset` — where in the cycle the timeline starts;
- `BorderBeam.progress` — the position from a value instead of the clock;
- `BorderBeam.follow` — the position eased toward a point in the box.

**Ambient** — `pulse`. Light breathes around the whole border at once. It has no direction and ignores `cycleGap`, `progress`, and `follow`; `phaseOffset` puts its breathing out of step.

`BeamEffect.travels` answers the question in code.

## Defaults

| Effect | Family | `cycleGap` | `hueMode` |
| --- | --- | --- | --- |
| `rotate` | travelling | zero | `pingPong` |
| `line` | travelling | zero | `pingPong` (on a shorter period than `rotate`) |
| `pulse` | ambient | — (ignored) | `continuous` |

Each effect's default `cycle` and `huePeriod` are getters on its class in `lib/src/border_beam/effects/beam_effect.dart` — `BeamEffect.defaultCycle`, `defaultCycleGap`, `defaultHueMode`, `defaultHuePeriod` — read them there rather than hard-coding them. Every one is a fallback: `BeamTiming` and `BeamStyle` override them field by field.

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
| `comet` | false | Adds an outer glow that trails the head *outside* the border. Leave room around the widget (see [light outside the bounds](shape.md#light-outside-the-bounds)). |

The beam sweeps around the box's centre, so it rounds the corners quickly and slows along the middle of the long edges. A box whose shortest side is at most `compactMaxExtent` (`lib/src/border_beam/look/rotate_look.dart`; chip and pill-button sized) gets the compact tuning — a wider window and a glow that fills the control; pair it with `BeamShape.stadium()`.

With `progress`, the head sits at that fraction of the turn, clockwise from 12 o'clock — a glowing progress ring; `follow` points the head at the pointer. With a [segment](shape.md#segments), the beam appears at the segment's start and travels to its end.

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

The palette is spread across the streak rather than around the ring, so every colour of the palette shows at once. Under `pingPong` the drift runs on two tracks: the bloom swings over one `huePeriod`, a little wider than the stroke, and the stroke more slowly, over one and a half. Both swings are capped well inside the default `hueShift`, so a streak's colours never wander far.

## `pulse` — a contained "thinking" state

Patches of colour on the hairline and washing inward from the edges, each swelling, drifting, and ebbing on its own beat — three groups of blobs breathing in size and position and four corners breathing in strength, so neighbours never pulse in lockstep. Each corner breathes in quicker than it breathes out: its light swells over the first part of the breath and settles back over the rest, both on Apple's ease-in-out.

```dart
BorderBeam(effect: const BeamEffect.pulse(), active: isThinking, child: card);
```

Its colours rotate continuously by default (a full turn per `huePeriod`). With a segment, only the patches inside it breathe.

## Choosing at runtime

Effects are values: two `BeamEffect.rotate(count: 2)` are equal, and `BeamEffect.values` lists all three with their default parameters. Store one in state and hand it to the widget — no switch needed:

```dart
BorderBeam(effect: _effect, child: card);
```

Swapping the effect on a live beam keeps it running; the new effect picks up from the same clock.
