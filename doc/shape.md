# Shape

`BeamShape` describes the outline the light follows: its corner radii and corner family, the stroke width, how far the outline sits from the child, which part of it is lit, and whether it is broken into dashes. Every field is nullable and means *inherit*; with nothing set, the outline is a 16px rounded rectangle on the child's bounds with a 1px stroke.

## Three constructors, one shape

```dart
const BeamShape.all(24);              // const — stores the number
BeamShape.circular(24);               // not const — builds a BorderRadius
const BeamShape.stadium();            // a pill; a circle on a square box
const BeamShape(radius: someGeometry); // per-corner
```

`BeamShape.all` and `BeamShape.circular` describe the same shape and **compare equal** for the same number. The split exists because building a `BorderRadius` from a parameter is a runtime construction, so `circular` cannot be `const`; `all` stores the number and grows it into a `BorderRadius` where `radius` is read. Use `all` in a `const` widget or a `const BorderBeamThemeData`, and `circular` when you already think in `BorderRadius` terms.

`stadium` sets an infinite radius and lets the outline clamp it per corner, which is what makes it track the box as it resizes — no rebuild when a chip's label changes length.

## Per-corner radii and direction

`radius` is a `BorderRadiusGeometry`, so `BorderRadiusDirectional` works and resolves against the ambient `Directionality`:

```dart
BorderBeam(
  shape: const BeamShape(
    radius: BorderRadiusDirectional.only(
      topStart: Radius.circular(28),
      bottomStart: Radius.circular(28),
    ),
  ),
  child: card,
);
```

In an RTL subtree the same shape mirrors, exactly as the child's own decoration does.

Radii are clamped the way `RRect.scaleRadii` clamps: when two radii on one side add up to more than that side, **all four** scale down by the smallest offending ratio, so an over-large radius shrinks the whole shape proportionally instead of deforming one corner. An elliptical radius (`Radius.elliptical`) is drawn as a circular corner with the mean of its two axes.

## Match the child yourself

The beam does not read the child's decoration. It wraps widgets that have none to read (a `Text`, a `Row`, a third-party card), and guessing wrong is worse than asking. Pass the same number:

```dart
const radius = 16.0;

BorderBeam(
  borderRadius: radius,
  child: Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    child: content,
  ),
);
```

A mismatch is the most common visual complaint, and it always looks like the beam is wrong rather than the radius being out of step.

## Superellipse corners

`superellipse: true` swaps circular corner arcs for a superellipse — the Apple-style squircle, whose curvature eases into the straight edge instead of stepping. The curve follows Flutter's own `RSuperellipse` construction at every aspect ratio — cards, pills, and circles alike — so the stroke sits on the edge of a child shaped by `RoundedSuperellipseBorder` with the same radius.

```dart
BorderBeam(
  shape: const BeamShape.all(28, superellipse: true),
  child: DecoratedBox(
    decoration: ShapeDecoration(
      color: surface,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(28)),
    ),
    child: content,
  ),
);
```

The outline is computed in the shader, so the option costs no path building and no extra draw.

## Border width

`borderWidth` is the stroke's thickness in logical px, 1 by default. The stroke is drawn just inside the outline (from the outline inward by `borderWidth`), anti-aliased over one device pixel. It is independent of your child's border: on a hairline-bordered card, keeping both at 1 makes the beam read as the border lighting up rather than as a second ring.

## Ring offset

`ringOffset` moves the outline outward (positive) or inward (negative) from the child's bounds:

```dart
// The beam orbits 8px clear of the card.
BorderBeam(shape: const BeamShape.all(32, ringOffset: 8), child: card);

// Tucked inside a padded surface.
BorderBeam(shape: const BeamShape.all(12, ringOffset: -12), child: paddedSurface);
```

A positive offset paints further outside the widget's box, so leave room for it. Corner radii are not adjusted for you: an offset outline around a rounded child usually wants its radius moved by the same amount to stay concentric (24 + 8 = 32 above).

## Segments

`BeamShape.segment` limits the light to part of the border. It is a mask over the unchanged animation: the effect still runs on the whole border, and the segment shows the part inside it.

Perimeter positions are arc-length fractions measured clockwise from top-centre:

```text
                  0 / 1
                    ↓
            ┌──────────────┐
       0.75 →              ← 0.25
            │              │
            └──────────────┘
                    ↑
                   0.5
```

On a square, `0.25`, `0.5`, and `0.75` are right-centre, bottom-centre, and left-centre. On other boxes, and with rounded corners, landmarks sit at other fractions, because every position is measured along the outline, not by angle.

### Anchors

- `BeamAnchor.fraction(t)` — an arc-length fraction, taken modulo one.
- `BeamAnchor.edge(edge, t)` — `t` of the way along an edge's straight run, clockwise: left to right on top, top to bottom on the right, right to left on the bottom, bottom to top on the left. `t` defaults to 0.5.
- `BeamAnchor.corner(corner, t)` — `t` of the way through a corner curve, clockwise. `t` defaults to 0.5; corners are `BeamCorner.topLeft`, `topRight`, `bottomRight`, `bottomLeft`.
- `BeamAnchor.topCenter`, `rightCenter`, `bottomCenter`, `leftCenter` name the four common landmarks.

`BeamSegment(start: …, end: …, feather: 32)` covers the clockwise span from `start` to `end`, wrapping through top-centre when the end comes before the start. Swapping the two selects the rest of the border. `feather` is the distance in logical px along the border over which each end fades; `0` is a hard cut. A glow fades out toward the end of the track rather than stopping at a hard line across it.

```dart
BorderBeam(
  shape: const BeamShape(
    radius: BorderRadius.all(Radius.circular(24)),
    segment: BeamSegment.bottomHalf,
  ),
  child: square,
);
```

### Presets

| Preset | Clockwise coverage |
| --- | --- |
| `bottomHalf` | right-centre → bottom-centre → left-centre |
| `topHalf` | left-centre → top-centre → right-centre |
| `leftHalf` | bottom-centre → left-centre → top-centre |
| `rightHalf` | top-centre → right-centre → bottom-centre |
| `bottomEdge` | bottom-right corner + bottom straight run + bottom-left corner |
| `topEdge` | top-left corner + top straight run + top-right corner |
| `leftEdge` | bottom-left corner + left straight run + top-left corner |
| `rightEdge` | top-right corner + right straight run + bottom-right corner |

### How each effect reads a segment

- **`rotate`** travels the segment: in forward travel it appears at the start and moves clockwise to the end, then begins again.
- **`line`** rides the segment instead of its `edge`, in border space — `bottomEdge` carries the streak around both bottom corners; `bottomHalf` takes it down the right side, along the bottom, and up the left.
- **`pulse`** lights only the part of the border inside the segment, and its glows fade near its ends.

`BeamTiming.direction` changes which way a traveller crosses the segment, not which span the segment selects. Stack a forward beam and a `reverse` one on the same segment for two arcs sweeping toward each other. `ringOffset` moves the outline before positions are measured, so a segment follows an offset ring.

## Dashes

`dashes` breaks the border into that many evenly spaced dashes. 2 or more paints dashes; null, 0, and 1 keep the border solid. A dash's ends are crisp on the stroke and soften the further its glow reaches from it, the way a blur would.

```dart
BorderBeam(
  shape: const BeamShape.all(16, dashes: 12),
  child: badge,
);
```

Dashes combine with segments and with every effect.

## Light outside the bounds

Most light stays on the border and inside it. Two things paint outside the child's box: `BeamEffect.rotate(comet: true)` and a positive `ringOffset`. Give those room — padding in the parent — and check for a `ClipRRect`, `ClipPath`, or a scroll view's clip above the beam.
