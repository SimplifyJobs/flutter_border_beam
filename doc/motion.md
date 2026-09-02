# Motion

Timing, direction, rest, synchronization, and taking the sweep off the clock entirely. The [README's timing table](../README.md#timing) lists the fields and defaults; this guide is about how they interact.

## The clock

One `Ticker` accumulates elapsed seconds. Every animated value — sweep position, hue, the line variant's breathe and spike scales, the pulse oscillator bank — is recomputed from that single number each frame. There are no `AnimationController`s and no per-track state, which is what makes the whole engine a pure function of time.

`speed` scales how fast that number advances. It is applied to the clock rather than to the config, so changing it never re-resolves the beam or rebuilds the phase resolver — a rate change is free.

Three things can drive the rate, in order: a `speedListenable`, then an attached `BorderBeamController`'s `speed`, then `timing.speed`. Under a `BeamSync` the group's rate owns all of them.

## Cycle and retiming

`cycle` is one lap for a traveling variant and one breath for a pulse variant. Changing it on a live beam **retimes in place**: every track keeps the phase it was at, so the beam smoothly speeds up or slows down instead of jumping to the new cycle's start.

```dart
BorderBeam.rotate(
  timing: BeamTiming(cycle: isUrgent
      ? const Duration(milliseconds: 900)
      : const Duration(milliseconds: 1960)),
  child: card,
);
```

That is the mechanism to reach for when a beam should react to state. Toggling `active` fades out and back in; changing `cycle` keeps the light on and changes its urgency.

## Rest between sweeps

`cycleGap` parks the beam at the end of its travel after each lap:

```dart
BorderBeam.rotate(
  timing: const BeamTiming(cycleGap: Duration(milliseconds: 1200)),
  child: card,
);
```

The sweep itself still takes `cycle`; the gap is added after it. The beam's fade envelope eases out and back in over `min(0.25s, gap / 2)` at each end, so the rest reads as the beam breathing rather than blinking off. Hue, breathe, and spike are textures rather than the sweep, so they keep running through the gap — the beam is dark, not frozen.

Changing the gap needs no retime: the current sweep keeps its position and the gap simply appears at the next cycle end. The pulse variants ignore it — their breathing has no cycle boundary to rest at.

## Direction, offset, and count

```dart
BorderBeam.rotate(
  timing: const BeamTiming(
    direction: BeamDirection.bounce,
    phaseOffset: 0.25,
    beamCount: 3,
  ),
  child: card,
);
```

- **`direction`** — `forward` (clockwise; left-to-right for `line`), `reverse` (the mirror), or `bounce` (alternating each cycle). The pulse variants have no travel to direct.
- **`phaseOffset`** — a fraction of a cycle, 0–1, that the timeline starts at. Two beams on the same cycle with different offsets run out of step.
- **`beamCount`** — how many beams travel the contour at once, spaced equally along the cycle. Every beam shares one clock and one config, so the count costs geometry, not tickers.

`beamCount` with `bounce` is worth trying on a wide card: the beams meet and part rather than chasing each other around.

Segments compose with the same travel controls. The segment always names a clockwise span; `direction` controls which way a traveler crosses it, and `cycleGap` adds the normal rest after a traveling sweep. Two beams with opposite directions make a counter-sweep:

```dart
Stack(
  children: [
    BorderBeam.rotate(
      shape: const BeamShape(segment: BeamSegment.bottomHalf),
      child: card,
    ),
    BorderBeam.rotate(
      shape: const BeamShape(segment: BeamSegment.bottomHalf),
      timing: const BeamTiming(direction: BeamDirection.reverse),
      child: card,
    ),
  ],
);
```

Add the same `cycleGap` to both timings when the arcs should disappear between passes.

## The hue tracks

The hue is a separate track from the sweep, on its own period.

| | Traveling (`rotate`, `small`, `line`) | Pulse |
| --- | --- | --- |
| Default `hueMode` | `pingPong` — swings ±`hueRange` | `continuous` — a full 360° revolution |
| Default `huePeriod` | 12s | 16s (`pulseInside`) · 14s (`pulseOutside`) |

`hueMode` is settable on either family, and swapping it is the cheapest way to change a palette's character: `continuous` on a traveling variant turns a subtle shimmer into a full rainbow cycle, and `pingPong` on a pulse variant calms it down.

`line` has a second hue track for its bloom (`bloomHuePeriod`, 8s), swinging across ±(`hueRange` + 10)°, and its `hueRange` is capped at 13° regardless of what you set — see [variants](variants.md).

`hueBase` shifts the whole palette by a fixed number of degrees, independent of the animation. It has no upstream counterpart and is the quickest way to nudge a preset toward your brand without leaving the preset.

## Reduced motion

Reduced motion is a *playback* concern rather than a timing one — the field lives on `BeamPlayback` and has four behaviors. See [accessibility](accessibility.md).

## `BeamSync`

Beams that belong together should move together. `BeamSync` gives its whole subtree one clock — one ticker, one timeline, identical phases:

```dart
BeamSync(
  speed: 0.8,
  child: Column(
    children: [
      for (final (i, row) in rows.indexed)
        BorderBeam.line(
          timing: BeamTiming(phaseOffset: i / rows.length),
          child: row,
        ),
    ],
  ),
);
```

The group owns playback: `active`, `autoPlay`, `startAfter`, `duration`, and `repeat` are ignored below it, and a `BorderBeamController` asserts rather than fighting for the clock. Everything visual stays per beam — palette, variant, shape — as does `phaseOffset`, which is what lets a synced group be evenly spaced rather than perfectly stacked.

Reduced motion is group-owned because every beam shares one clock. Set `BeamSync.reducedMotion` to `staticFrame` (the default), `hide`, `slow`, or `animate`; per-beam settings are ignored while synchronized.

## Driving the sweep yourself

Two inputs take the sweep off the clock without stopping it.

### `progress`

```dart
BorderBeam.rotate(progress: received / total, child: card);
```

The sweep sits where the value says, turning `rotate` into a glowing progress ring and `line` into a progress bar. The clock keeps running underneath, so the fade envelope, the hue shift, and the line variant's breathe and spike tracks are all still alive — the beam reads as lit rather than frozen. Changing it repaints without re-resolving the configuration, so driving it from an `AnimationController` every frame is cheap.

### `follow`

```dart
class _Card extends StatefulWidget { /* … */ }

// In the State:
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
    child: BorderBeam.rotate(follow: _follow, child: card),
  );
}
```

The beam leaves its schedule and eases to the perimeter point nearest the given normalized point — critically damped, about 150ms, so a jittery pointer stream is smoothed without lag you can feel. Setting it back to null hands the sweep back to the clock from wherever it is, with no snap.

`progress` wins over `follow`, and the pulse variants ignore both. `BeamHover` is this wired up for you.

### Live listenables

`strengthListenable` and `speedListenable` are the per-frame twins of `style.strength` and `timing.speed`: they change the beam without rebuilding the widget, which is what you want when the source is a mic level, a download rate, or a tempo.

```dart
BorderBeam.rotate(
  strengthListenable: level, // ValueListenable<double>
  child: card,
);
```
