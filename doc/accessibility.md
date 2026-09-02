# Accessibility

A border beam is decoration. It should make a state easier to notice for people who can see it, and cost nothing for everyone else. Three rules follow from that, and the package enforces two of them for you.

## Reduced motion

When the platform asks for reduced motion — `MediaQuery.disableAnimationsOf`, which Flutter maps to *Reduce Motion* on iOS and *Remove animations* on Android — the beam obeys by default.

| `BeamReducedMotion` | Behavior | Reach for it when |
| --- | --- | --- |
| `staticFrame` | Paints one static frame and stops ticking. **The default.** | Almost always. The beam still marks the state; it just stops moving. |
| `hide` | Paints nothing; the child is left bare, and no ticker runs. | The beam is pure decoration and the state is fully carried elsewhere. |
| `slow` | Keeps animating at a quarter speed. | Motion carries meaning that a still frame cannot (a progress ring). |
| `animate` | Ignores the request. | Essentially never in product code. |

```dart
// App-wide: hide beams for anyone who asked for less motion.
BorderBeamTheme(
  data: const BorderBeamThemeData(
    playback: BeamPlayback(reducedMotion: BeamReducedMotion.hide),
  ),
  child: app,
);
```

Two details worth knowing:

- **All five variants honor it.** The original applies reduced motion to the pulse variants only; this package applies it everywhere, which is why `staticFrame` — a frame that still communicates — is the default rather than `hide`. See [parity](parity.md).
- **A frozen beam stops ticking.** `staticFrame` and `hide` pause the clock rather than animating invisibly, so respecting the setting also saves the battery it was meant to save.

Under a [`BeamSync`](motion.md#beamsync), reduced motion pauses the shared clock for the whole group, and each beam still paints according to its own setting.

`BeamDecoration` **cannot** observe reduced motion — a `BoxPainter` has no `BuildContext` — so `reducedMotion` is inert there. If a surface must honor the setting, use the widget.

## Semantics

Beams add **no** semantics. A screen reader describes your child exactly as it would without the beam, and nothing is announced when a beam starts, stops, or changes.

That is the correct default, and it puts one obligation on the caller: **never let the beam be the only signal.** A beam marks a state that is already stated somewhere a screen reader can reach — the button's label ("Generating…"), the field's helper text, a status line, a `Semantics` liveRegion. Treat the beam as emphasis on information that already exists.

```dart
// The beam emphasizes; the label states.
BorderBeam.pulseInside(
  active: isGenerating,
  child: FilledButton(
    onPressed: isGenerating ? null : generate,
    child: Text(isGenerating ? 'Generating…' : 'Generate'),
  ),
);
```

If you catch yourself writing "the glowing one is selected", add a non-visual signal.

## Pointers and focus

No beam layer intercepts a pointer. `BorderBeam` paints through a `CustomPaint` whose layers are decorative, and `BeamDecoration.hitTest` returns false. Hit-testing, focus traversal, and gesture handling behave exactly as they would without the beam, so a beam can be dropped around an existing interactive widget without auditing its gestures.

`BeamPress` is the one wrapper that touches input, and it does so through a translucent `Listener` that never enters the gesture arena — a button inside keeps its own taps, and a scrollable above keeps its drags.

## Focus indication

`BeamFocusRing` is a *visual* focus indicator, complementing what the focused widget already reports rather than replacing it:

```dart
BeamFocusRing(
  borderRadius: 12,
  child: TextField(decoration: decoration),
);
```

It follows `FocusManager.highlightMode`, the same rule `FocusableActionDetector` uses: it lights for keyboard and mouse focus and stays dark for touch, where a focus ring around a tapped field is noise. `alwaysShow: true` overrides that.

Because it only flips `BorderBeam`'s `active`, focus arrives and leaves on the beam's own fades rather than as a cut — but a fade is still a state change, so keep the underlying widget's own focus decoration if your design depends on an instant indicator. The ring does not replace the platform focus ring; it sits alongside it.

## Contrast and legibility

The beam paints *around* content, never over text, so it does not affect text contrast directly. Two things still deserve a look:

- **A bright beam next to small text** raises the local luminance around it and can make a thin label feel lower-contrast than it measures. `style.strength` is the dial; 0.6–0.8 is often better on dense UI than the full 1.0.
- **`pulseOutside` changes the perceived edge of a card.** Its contract already asks for the child's own 1px border, which is what keeps the card's boundary legible when the halo is at its dimmest.

For anyone sensitive to flicker, the relevant settings are the same ones above: prefer longer cycles, and honor reduced motion with `staticFrame` or `hide`. Nothing in the package flashes faster than roughly one cycle per second at the default timings, but a very short `cycle` combined with `flash()` can, so treat sub-second cycles as a deliberate choice.
