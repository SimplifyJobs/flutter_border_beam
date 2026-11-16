# Motion

Timing, direction, rest, synchronization, and taking the travel off the clock. The [README's `BeamTiming` table](../README.md#beamtiming) lists the fields and defaults; this guide is about how they interact.

## The clock

One `Ticker` accumulates elapsed seconds. Every animated value — the travel position, the hue, the breathing of the ambient effects — is recomputed from that one number each frame. There are no `AnimationController`s and no per-track state, which is what makes a beam a pure function of time: the same instant always paints the same frame.

The clock ticks on every frame the engine produces. Nothing is capped, so a beam runs at 120Hz on a 120Hz display (on ProMotion iPhones, once the app opts in — see [performance](performance.md#120hz)).

`speed` scales how fast the elapsed time advances. It is applied to the clock rather than to the config, so changing it never re-resolves the beam — a rate change is free. Three things can set the rate, in order: a `speedListenable`, then an attached `BorderBeamController`'s `speed`, then `timing.speed`. Under a `BeamSync` the group's `speed` owns all of them.

## Cycle and retiming

`cycle` is one sweep of a travelling effect and one breath of `pulse` and `halo`. Each effect has its own default — see [effects](effects.md#defaults).

Changing `cycle` on a live beam **retimes it in place**: the travel keeps the position it was at, so the beam speeds up or slows down instead of jumping to the new cycle's start.

```dart
BorderBeam(
  timing: BeamTiming(
    cycle: isUrgent
        ? const Duration(milliseconds: 900)
        : const Duration(milliseconds: 2400),
  ),
  child: card,
);
```

That is the tool when a beam should react to state: toggling `active` fades out and back in, while changing `cycle` keeps the light on and changes its urgency.

## Rest between sweeps

`cycleGap` parks a travelling effect at the end of its travel after each sweep:

```dart
BorderBeam(
  timing: const BeamTiming(cycleGap: Duration(milliseconds: 1200)),
  child: card,
);
```

The sweep still takes `cycle`; the gap is added after it. The beam fades out and back in over `min(0.25s, gap / 2)` at each end of the rest, so it reads as breathing rather than blinking off. The hue drift keeps running through the gap.

No effect rests by default. Changing the gap needs no retime: the current sweep keeps its position and the rest appears at the next cycle end. Ambient effects ignore it — their motion has no cycle boundary to rest at.

## Direction, offset, and count

```dart
BorderBeam(
  effect: const BeamEffect.rotate(count: 3),
  timing: const BeamTiming(
    direction: BeamDirection.bounce,
    phaseOffset: 0.25,
  ),
  child: card,
);
```

- **`direction`** — `forward` (clockwise; reading order for `line`), `reverse` (the mirror), or `bounce` (alternating each cycle). It applies to the travelling effects; `pulse` and `halo` have no direction.
- **`phaseOffset`** — the fraction of a cycle, 0–1, the timeline starts at. Two beams on the same cycle with different offsets run out of step — a travelling beam sits further along its sweep, an ambient one breathes out of phase.
- **`BeamEffect.rotate(count:)`** — how many beams lap the border at once, 1–4, spaced evenly. They share one clock and one draw, so the count costs nothing extra.

`count` with `bounce` is worth trying on a wide card: the beams meet and part rather than chasing each other.

Segments compose with the same controls. A segment always names a clockwise span; `direction` decides which way a traveller crosses it, and `cycleGap` adds the usual rest. Two beams with opposite directions make a counter-sweep:

```dart
Stack(
  children: [
    BorderBeam(
      shape: const BeamShape(segment: BeamSegment.bottomHalf),
      child: card,
    ),
    const Positioned.fill(
      child: BorderBeam.overlay(
        shape: BeamShape(segment: BeamSegment.bottomHalf),
        timing: BeamTiming(direction: BeamDirection.reverse),
      ),
    ),
  ],
);
```

## Hue drift

The hue is a separate track from the travel, on its own period (`huePeriod`):

| `hueMode` | What it does | Default for |
| --- | --- | --- |
| `pingPong` | Swings ±`hueShift` degrees (30 by default) and back, eased at each end. | `rotate` (12s), `line` (8s) |
| `continuous` | Turns a full 360° per period, never reversing. | `pulse` (16s), `halo` (14s) |
| `none` | No drift. | — (`mono` and `gold` force it) |

Any effect accepts any mode: `continuous` on `rotate` turns a subtle swing into a full rainbow, and `pingPong` on `pulse` calms it. `mono` and `gold` never drift. `hueBase` shifts the whole palette by a fixed number of degrees, independent of the drift.

Changing `huePeriod` mid-run re-phases the drift: the colours jump once to where the new period puts them, then continue smoothly.

## Reduced motion

Reduced motion is a playback concern rather than a timing one — the field lives on `BeamPlayback` and has four behaviours. See [accessibility](accessibility.md).

## `BeamSync`

Beams that belong together should move together. `BeamSync` gives its whole subtree one clock — one ticker, one timeline, identical phases:

```dart
BeamSync(
  speed: 0.8,
  child: Column(
    children: [
      for (final (i, row) in rows.indexed)
        BorderBeam(
          effect: const BeamEffect.line(),
          timing: BeamTiming(phaseOffset: i / rows.length),
          child: row,
        ),
    ],
  ),
);
```

The group owns playback: `active`, `autoPlay`, `startAfter`, `duration`, and `repeat` are ignored below it, and a `BorderBeamController` asserts rather than fighting for the clock. Everything visual stays per beam — effect, palette, shape — as does `phaseOffset`, which is what spaces a synced group evenly rather than stacking it.

Reduced motion is group-owned too, because every beam shares one clock: set `BeamSync.reducedMotion` (`staticFrame` by default). Per-beam settings are ignored while synchronized.

## Driving the travel yourself

Two inputs take the travel off the clock without stopping the clock.

### `progress`

```dart
BorderBeam(progress: received / total, child: card);
```

The travel sits where the value says: `rotate` becomes a glowing progress ring, `line` a progress bar. A driven value maps linearly — no easing — and keeps the beam fully lit. The clock keeps running underneath, so the fade, the hue drift, and `line`'s spikes stay alive. Changing it repaints without re-resolving the configuration, so driving it from an `AnimationController` every frame is cheap.

### `follow`

```dart
// In a State:
Offset? _follow;

@override
Widget build(BuildContext context) {
  return MouseRegion(
    onHover: (event) {
      final box = context.findRenderObject()! as RenderBox;
      final local = box.globalToLocal(event.position);
      setState(() {
        _follow = Offset(
          local.dx / box.size.width,
          local.dy / box.size.height,
        );
      });
    },
    onExit: (_) => setState(() => _follow = null),
    child: BorderBeam(follow: _follow, child: card),
  );
}
```

The travel leaves its schedule and eases toward the given normalized point — critically damped, about 150ms, so a jittery pointer is smoothed without a lag you can feel. `rotate` turns its head toward it, the shortest way round (on a segment, to the border point nearest it); `line` follows the coordinate along its edge. Setting it back to null hands the travel back to the clock from wherever it is, without a snap.

`progress` wins over `follow`, and the ambient effects ignore both. `BeamHover` is this wired up for you.

### Live listenables

`strengthListenable` and `speedListenable` are the per-frame twins of `style.strength` and `timing.speed`: they change the beam without rebuilding the widget, which is what you want when the source is a microphone level, a download rate, or a tempo.

```dart
BorderBeam(
  strengthListenable: level, // ValueListenable<double>
  child: card,
);
```

Values of `strengthListenable` above 1 brighten the beam, saturating at full opacity.

### Accents

A `BorderBeamController` adds two one-shot accents on a running beam: `pulse()` lifts its brightness and lets it settle over about 0.6s, and `flash()` blinks it brighter, holds 120ms, and decays. Neither touches the timeline.
