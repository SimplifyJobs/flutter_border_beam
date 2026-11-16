# Accessibility

A border beam is decoration. It should make a state easier to notice for people who can see it, and cost nothing for everyone else. Three rules follow from that, and the package enforces two of them for you.

## Reduced motion

When the platform asks for reduced motion — `MediaQuery.disableAnimationsOf`, which Flutter maps to *Reduce Motion* on iOS and *Remove animations* on Android — every effect obeys by default.

| `BeamReducedMotion` | Behaviour | Reach for it when |
| --- | --- | --- |
| `staticFrame` | Paints one static frame and stops ticking. **The default.** | Almost always. The beam still marks the state; it just stops moving. |
| `hide` | Paints nothing; the child is left bare, and no ticker runs. | The beam is pure decoration and the state is fully carried elsewhere. |
| `slow` | Keeps animating at a quarter speed. | Motion carries meaning that a still frame cannot. |
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

Details worth knowing:

- **The static frame is representative.** A travelling effect is shown partway through its sweep; an ambient one mid-breath; the palette in its own colours, without hue drift. A beam driven by `progress` still shows its value, so a progress ring stays a readout.
- **A still beam stops ticking.** `staticFrame` and `hide` pause the clock rather than animating invisibly, so respecting the setting also saves the battery it was meant to save.
- **Groups decide together.** Under a [`BeamSync`](motion.md#beamsync) every beam shares one clock, so reduced motion is set once on `BeamSync.reducedMotion` (`staticFrame` by default) and per-beam settings are ignored.
- **`BeamDecoration` cannot observe it.** A `BoxPainter` has no `BuildContext`, so `reducedMotion` is inert there. If a surface must honour the setting, use `BorderBeam`.

## Semantics

Beams add **no** semantics. A screen reader describes your child exactly as it would without the beam, and nothing is announced when a beam starts, stops, or changes.

That is the right default, and it puts one obligation on you: **never let the beam be the only signal.** A beam marks a state that is already stated somewhere a screen reader can reach — the button's label ("Generating…"), the field's helper text, a status line, a `Semantics` live region. Treat the beam as emphasis on information that already exists.

```dart
// The beam emphasizes; the label states.
BorderBeam(
  effect: const BeamEffect.pulse(),
  active: isGenerating,
  child: FilledButton(
    onPressed: isGenerating ? null : generate,
    child: Text(isGenerating ? 'Generating…' : 'Generate'),
  ),
);
```

If you catch yourself writing "the glowing one is selected", add a non-visual signal.

## Pointers and focus

Nothing a beam paints takes part in hit-testing. `BorderBeam` paints through a `CustomPaint` foreground painter, and `BeamDecoration.hitTest` returns false. Hit-testing, focus traversal, and gestures behave exactly as they would without the beam, so a beam can go around an existing interactive widget without auditing its gestures.

`BeamPress` is the one wrapper that reads input, and it does so through a translucent `Listener` that never enters the gesture arena — a button inside keeps its own taps, and a scrollable above keeps its drags.

## Focus indication

`BeamFocusRing` is a *visual* focus indicator. It complements what the focused widget already reports; it does not replace it:

```dart
BeamFocusRing(
  borderRadius: 12,
  child: TextField(decoration: decoration),
);
```

It follows `FocusManager.highlightMode`, the same rule `FocusableActionDetector` uses: it lights for keyboard and mouse focus and stays dark for touch, where a ring around a tapped field is noise. `alwaysShow: true` overrides that.

Because it only flips `BorderBeam`'s `active`, focus arrives and leaves on the beam's fades (about 0.5s in, 0.6s out) rather than as a cut. A fade is still a state change, so keep the underlying widget's own focus decoration if your design needs an instant indicator.

## Contrast and legibility

The beam paints around content and only a short way into it, so it does not change text contrast directly. Two things still deserve a look:

- **A bright beam next to small text** raises the luminance around it and can make a thin label feel lower-contrast than it measures. `style.strength` is the dial; 0.6–0.8 often sits better on dense UI than the full 1.0.
- **Inward glows** (the inner glow of `rotate` and `pulse`, `line`'s spikes) reach into the child. Keep important content clear of the border by the child's own padding, or turn the reach down with `style.glow`.

For anyone sensitive to flicker, the relevant settings are the same: prefer longer cycles, and honour reduced motion with `staticFrame` or `hide`. At the default timings nothing in the package repeats faster than about once a second, but a very short `cycle` combined with `BorderBeamController.flash()` can, so treat sub-second cycles as a deliberate choice.
