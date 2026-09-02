# Theming

Two different things are called "theme" here, and keeping them apart is most of the work:

- **`BeamTheme`** (`dark` / `light` / `auto`) is how one beam adapts to the background it sits on. It selects a preset.
- **`BorderBeamTheme`** is an `InheritedWidget` supplying default field values to every beam below it.

## Background adaptation — `BeamTheme`

Each variant has one tuned config per brightness: layer opacities, an inset shadow color, and default brightness/saturation multipliers. `style.theme` picks which:

```dart
// Always the dark-background tuning, whatever the app theme says.
BorderBeam.rotate(
  style: const BeamStyle(theme: BeamTheme.dark),
  child: card,
);
```

`BeamTheme.auto` — the default — follows `Theme.of(context).brightness`. That is a deliberate deviation from the original, which follows the OS color scheme: in Flutter the app's own theme is the thing a widget sits on, and a card in a dark sheet inside a light app should get the dark tuning. Force `dark` or `light` when a surface's brightness differs from the ambient theme's.

### Replacing a preset

`BeamThemeConfig` is public, so the whole preset can be replaced through `style.themeConfig`. Start from a preset and move the one field you want:

```dart
BorderBeam.rotate(
  style: BeamStyle(
    themeConfig: BeamThemeConfig.presetFor(
      BeamVariant.rotate,
      Brightness.dark,
    ).copyWith(bloomOpacity: 0.4, innerShadow: const Color(0x00000000)),
  ),
  child: card,
);
```

Its fields are `strokeOpacity`, `innerOpacity`, `bloomOpacity`, `innerShadow`, `saturation`, `brightness`, and `hairlineOpacity` (pulse-outside's static 1px edge, preset to 0 so the child's own border provides it). Opacities may legitimately exceed 1 — the source overdrives line/dark's stroke to 1.14 — and the painted product is clamped.

`style.brightness` and `style.saturation` still apply **on top of** a replaced config, so a `themeConfig` sets the baseline rather than the last word.

## Defaults for a subtree — `BorderBeamTheme`

`BorderBeamThemeData` has one slot per value object, and each slot's fields are nullable, so a theme fills in only what it names:

```dart
BorderBeamTheme(
  data: const BorderBeamThemeData(
    style: BeamStyle(colors: BeamColors.ocean, strength: 0.85),
    shape: BeamShape.all(20, superellipse: true),
    timing: BeamTiming(cycle: Duration(seconds: 3)),
  ),
  child: MaterialApp(home: home),
);
```

Every beam below now defaults to the ocean palette at 85% strength, a 20px squircle, and a 3s cycle — and each can still override any single field.

### Nesting and merge

`BorderBeamTheme.of` walks **every** enclosing scope, registers the context as a dependent of each, and merges them outside-in. An inner theme therefore overrides only the fields it sets, and a change to an *outer* theme rebuilds the beam just as an inner one does.

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

That is the point of the all-nullable value objects: `merge` is field-by-field, so themes compose instead of replacing each other wholesale.

### Where a theme sits in the order

```text
flat shorthand  >  value object on the widget  >  BorderBeamTheme (inner→outer)  >  variant default
```

`colors`, `active`, and `borderRadius` on the widget are shorthands that fold into `style.colors`, `playback.active`, and `shape.radius` respectively, and win over the same field set in the object next to them.

### Const-friendly by design

`BeamShape.all` exists so a `BorderBeamThemeData` can be `const` — `BeamShape.circular` builds a `BorderRadius` at runtime and cannot be. `const BorderBeamThemeData(shape: BeamShape.all(20))` therefore costs nothing per rebuild, and `updateShouldNotify` compares by value, so a rebuilt-but-equal theme notifies nobody.

### Themeing playback

The playback slot is a genuine default, not an override: putting `startAfter` or `duration` in a theme applies them to every beam below, including beams that also take a `BorderBeamController`. The controller asserts in that case — it owns playback exclusively — so keep scheduling out of app-wide themes and set `reducedMotion` there instead, which is the field that genuinely benefits from being set once:

```dart
BorderBeamTheme(
  data: const BorderBeamThemeData(
    playback: BeamPlayback(reducedMotion: BeamReducedMotion.hide),
  ),
  child: app,
);
```

## `BeamDecoration` and themes

A `BoxPainter` has no `BuildContext`, so a `BeamDecoration` inherits nothing on its own. Pass the theme in explicitly:

```dart
BeamDecoration(
  variant: BeamVariant.rotate,
  brightness: Theme.of(context).brightness,
  theme: BorderBeamTheme.of(context),
);
```

Without `theme:` the decoration resolves against variant presets only.
