# Shape

`BeamShape` describes the geometry the beam travels: corner radii, ring thickness, the corner family, how far the ring sits from the child, and — when a rounded rectangle is not enough — an arbitrary path. The [README's shape table](../README.md#shape) lists the fields and defaults; this guide covers the parts with sharp edges.

## Three constructors, one shape

```dart
const BeamShape.all(24);              // const — stores the number
BeamShape.circular(24);               // not const — builds a BorderRadius
const BeamShape.stadium();            // a pill; a circle on a square box
const BeamShape(radius: someGeometry) // per-corner
```

`BeamShape.all` and `BeamShape.circular` describe the same shape and **compare equal** for the same number. The split exists because building a `BorderRadius` from a parameter is a runtime construction, so `circular` cannot be `const`; `all` stores the double and grows it into a `BorderRadius` where `radius` is read. Use `all` in a `const` widget or a `const BorderBeamThemeData`, and `circular` when you already have a radius in `BorderRadius` terms.

`stadium` sets an infinite radius and lets the ring geometry clamp it per corner, which is what makes it track the box as it resizes — no rebuild needed when the chip's label changes length.

## Per-corner radii and direction

`radius` is a `BorderRadiusGeometry`, so `BorderRadiusDirectional` works and resolves against the ambient `Directionality`:

```dart
BorderBeam.rotate(
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

Radii are clamped the way `RRect.scaleRadii` clamps: when two radii on one side exceed that side's length, **all four** scale down by the smallest offending ratio — so an over-large radius shrinks the whole shape proportionally instead of deforming one corner.

## Match the child yourself

The beam does not read the child's decoration. That is deliberate: it wraps widgets that have no decoration to read (a `Text`, a `Row`, a third-party card), and guessing wrong is worse than asking. Pass the same number:

```dart
const radius = 16.0;

BorderBeam.rotate(
  borderRadius: radius,
  child: Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    child: content,
  ),
);
```

A mismatch is the single most common visual complaint, and it always looks like the beam is "wrong" rather than the radius being out of sync.

## Superellipse corners

`superellipse: true` swaps circular corner arcs for a rounded superellipse — the Apple-style squircle, whose curvature is continuous where it meets the straight edge instead of stepping. It needs Flutter ≥ 3.35, the package's declared minimum, where `RSuperellipse` is stable.

```dart
BorderBeam.rotate(
  shape: const BeamShape.all(28, superellipse: true),
  child: card,
);
```

It is a Flutter-only addition — the original's CSS `border-radius` produces circular arcs — so use it when your child is a squircle too, and leave it off when you want the source's exact contour.

## Ring offset

`ringOffset` moves the beam's ring outward (positive) or inward (negative) from the child's bounds:

```dart
// The beam orbits 8px clear of the card.
BorderBeam.rotate(
  shape: const BeamShape.all(24, ringOffset: 8),
  child: card,
);

// Tucked inside a padded surface.
BorderBeam.rotate(
  shape: const BeamShape.all(12, ringOffset: -12),
  child: paddedSurface,
);
```

A positive offset paints further outside the widget's box, so it needs the same clip-free room `pulseOutside` does — add padding in the parent, and check for a `ClipRRect` above the beam. Corner radii are not adjusted for you; an offset ring around a rounded child usually wants its radius moved by the same amount to stay concentric.

## Arbitrary contours

When the shape is not a rounded rectangle at all, hand the beam a path. `BeamContour.build(Rect)` is called with the beam's bounds — already grown or shrunk by `ringOffset` — and returns a closed path in the same coordinate space. `radius` and `superellipse` are ignored while a contour is set.

`BeamPathContour` is the ready-made implementation:

```dart
BorderBeam.rotate(
  shape: BeamShape(
    contour: BeamPathContour((rect) => Path()..addOval(rect), key: 'oval'),
  ),
  child: card,
);
```

The `key` is not optional garnish. **A contour is a config-cache key**, so every implementer must override `==` and `hashCode`; a contour that compares by identity re-resolves the whole beam configuration on every rebuild. Dart closures compare by identity, so an inline builder would be a new value each time — the key is what makes two contours drawing the same path equal. Any value-equal object works: a string, an enum, or a record of the parameters the builder closes over.

For a shape parameterized at runtime, put the parameters in the key:

```dart
class NotchedContour extends BeamContour {
  const NotchedContour(this.notch);

  final double notch;

  @override
  Path build(Rect rect) {
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.center.dx - notch, rect.top)
      ..lineTo(rect.center.dx, rect.top + notch)
      ..lineTo(rect.center.dx + notch, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotchedContour && other.notch == notch;

  @override
  int get hashCode => notch.hashCode;
}
```

The traveling variants walk the path's perimeter, so a contour with a very uneven perimeter distribution (a long thin spur, say) will pass through it quickly — that is arc-length behavior, not a bug.

## Border width

`borderWidth` is the stroke ring's thickness, 1px by default and in the source. It is independent of your child's border: the beam's ring is a painted glow, not a border you can lay out against. On a hairline-bordered card, keeping both at 1 makes the beam read as the border lighting up rather than as a second ring around it.
