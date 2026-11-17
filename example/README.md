# prismatic examples

## A beam around a card

```dart
BorderBeam(
  borderRadius: 16,
  colors: BeamColors.ocean,
  child: const Card(child: Padding(
    padding: EdgeInsets.all(24),
    child: Text('Working on it…'),
  )),
)
```

Pick another effect with `effect: const BeamEffect.line()` or
`const BeamEffect.pulse()`.

## A wave from a button

Flip `revealed` to send the wave out. Flip it back to bring it home.

```dart
DistortionWave(
  revealed: sent,
  revealedChild: const ReceiptScreen(),
  child: ReviewScreen(
    send: DistortionWaveAnchor(
      child: FilledButton(
        onPressed: () => setState(() => sent = true),
        child: const Text('Send'),
      ),
    ),
  ),
)
```

Give both screens an opaque background.

## A wave between pages

```dart
Navigator.of(context).push(
  DistortionWaveRoute<void>(
    source: WaveSource.of(context),
    builder: (_) => const ReceiptScreen(),
  ),
);
```

## Load the shaders early

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BorderBeam.precache();
  await DistortionWave.precache();
  runApp(const App());
}
```

## The showcase app

This folder is a full app that shows both effects.

```bash
flutter run            # a phone or desktop
flutter run -d chrome  # the web
```

- **Home** shows each beam effect on the widget it suits: `rotate` on a task
  card, `line` on a chat composer, and `pulse` on a "thinking" card. Swipe
  between them, pick a palette, pause the beam, or flip the theme.
- **The wave button** in the header opens the wave page, on a
  `DistortionWaveRoute`. Each wave type has its own demo screen:
  - **Send money** (`vertical`): Send reveals the receipt.
  - **Next step** (`horizontal`): the tab on the left edge goes on.
  - **Success sheet** (`center`): the icon turns the sheet into its paid
    state.
- On a phone the demo fills the screen, so the wave follows your display's
  corners. The tab on the right edge slides in the options: the demo, its
  palette, a bar that holds the wave at any moment, and a page pushed on a
  route. On a wide screen the options sit in a side bar.

Three `--dart-define`s set the opening state, which helps with screenshots:

```bash
flutter run --dart-define=START=pulse --dart-define=PALETTE=ocean --dart-define=THEME=light
```

### Where things are

| File | What it holds |
| --- | --- |
| `lib/main.dart` | `main()` and the app |
| `lib/src/home.dart` | the beam screen |
| `lib/src/surfaces.dart` | the mock widgets the beams wrap |
| `lib/src/wave_page.dart` | the wave screen, and the page its route pushes |
| `lib/src/wave_scenes.dart` | the wave demos, shared with the reel |
| `lib/src/display_corners.dart` | the display's corner radii on iOS |
| `lib/src/controls.dart` | selectors, swatches, toggles and the scrub bar |
| `lib/src/tokens.dart` | dark and light colour tokens |

### Demo reels

`lib/showcase.dart` (the beams) and `lib/wave_reel.dart` (the waves) play
themselves for recording. From the package root, with a booted iOS simulator
and ffmpeg:

```bash
tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
tool/record_demo.sh --target lib/wave_reel.dart --prefix WAVE --no-crop --contact
```

Videos land in `.demos/`.
