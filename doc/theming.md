# Theming

Two different things are called "theme" here, and keeping them apart is most of the work:

- **`BeamTheme`** (`dark` / `light` / `auto`) is how one beam adapts to the surface it sits on.
- **`BorderBeamTheme`** is an `InheritedWidget` supplying defaults — including the effect — to every beam below it.

## Surface adaptation — `BeamTheme`

Light reads differently on a dark surface and on a light one, so every effect is tuned twice. On a dark surface the hottest light whitens and part of it is *added* to what is underneath, so it glows; on a light surface the light is blended, the hottest part deepens toward its own colour instead of washing to white, and glows are lifted so they read as a tint rather than a smudge. `style.theme` picks which tuning a beam uses:

```dart
// The dark-surface tuning, whatever the app theme says.
BorderBeam(
  style: const BeamStyle(theme: BeamTheme.dark),
  child: card,
);
```

`BeamTheme.auto` — the default — follows `Theme.of(context).brightness`. Force `dark` or `light` when a surface's brightness differs from the app's: a dark card inside a light app wants `BeamTheme.dark`.

## Defaults for a subtree — `BorderBeamTheme`

`BorderBeamThemeData` has a slot for the effect and one per value object. Each value object's fields are nullable, so a theme fills in only what it names:

```dart
BorderBeamTheme(
  data: const BorderBeamThemeData(
    effect: BeamEffect.flow(),
    style: BeamStyle(colors: BeamColors.ocean, strength: 0.85),
    shape: BeamShape.all(20, superellipse: true),
    timing: BeamTiming(cycle: Duration(seconds: 3)),
  ),
  child: MaterialApp(home: home),
);
```

Every beam below now defaults to `flow` in the ocean palette at 85% strength, on a 20px squircle with a 3s cycle — and each can still override any single field. A beam that sets `effect:` replaces the theme's effect whole; effects do not merge.

### Nesting and merge

`BorderBeamTheme.of` walks **every** enclosing theme, registers the context as a dependent of each, and merges them outside-in. An inner theme therefore overrides only the fields it sets, and a change to an *outer* theme rebuilds the beam just as an inner one does.

```dart
BorderBeamTheme(
  data: const BorderBeamThemeData(
    style: BeamStyle(colors: BeamColors.ocean, strength: 0.85),
  ),
  child: BorderBeamTheme(
    // Keeps strength 0.85; overrides only the palette.
    data: const BorderBeamThemeData(style: BeamStyle(colors: BeamColors.ember)),
    child: section,
  ),
);
```

That is the point of the all-nullable value objects: `merge` is field by field, so themes compose instead of replacing each other.

### Where a theme sits in the order

```text
shorthand  >  value object on the widget  >  BorderBeamTheme (inner over outer)  >  effect default
```

`colors`, `active`, and `borderRadius` on the widget are shorthands that fold into `style.colors`, `playback.active`, and `shape.radius`, and win over the same field set in the object next to them. The effect follows the same order: the widget's `effect:`, then the nearest theme's, then `BeamEffect.rotate()`.

### Const-friendly by design

`BeamShape.all` exists so a `BorderBeamThemeData` can be `const` — `BeamShape.circular` builds a `BorderRadius` at runtime and cannot be. Effects are `const` too. `const BorderBeamThemeData(shape: BeamShape.all(20))` costs nothing per rebuild, and `updateShouldNotify` compares by value, so a rebuilt-but-equal theme notifies nobody.

### Theming playback

The playback slot is a genuine default, not an override: putting `startAfter` or `duration` in a theme applies them to every beam below, including beams that take a `BorderBeamController`. The controller asserts in that case — it owns playback exclusively — so keep scheduling out of app-wide themes and set `reducedMotion` there instead, which is the field that genuinely benefits from being set once:

```dart
BorderBeamTheme(
  data: const BorderBeamThemeData(
    playback: BeamPlayback(reducedMotion: BeamReducedMotion.hide),
  ),
  child: app,
);
```

## `BeamDecoration` and themes

A `BoxPainter` has no `BuildContext`, so a `BeamDecoration` inherits nothing by itself. Pass the brightness and the theme in:

```dart
BeamDecoration(
  effect: const BeamEffect.rotate(),
  brightness: Theme.of(context).brightness,
  theme: BorderBeamTheme.of(context),
);
```

`effect:` falls back to the passed theme's effect, then to `BeamEffect.rotate()`. Without `theme:` the decoration resolves against the effect's defaults only.
