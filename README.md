<div align="center">
  <h1><b>prismatic</b></h1>
  <p>Light and motion for Flutter, drawn by shaders.</p>
</div>

<p align="center">
  <a href="https://pub.dev/packages/prismatic"><img src="https://img.shields.io/pub/v/prismatic?logo=dart&logoColor=white&color=0175C2" alt="pub package"></a>
  <a href="https://pub.dev/packages/prismatic/score"><img src="https://img.shields.io/pub/points/prismatic?logo=dart&logoColor=white&color=0175C2" alt="pub points"></a>
  <a href="https://docs.flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white" alt="Flutter 3.47+"></a>
  <a href="https://github.com/SimplifyJobs/prismatic/actions/workflows/ci.yaml"><img src="https://github.com/SimplifyJobs/prismatic/actions/workflows/ci.yaml/badge.svg" alt="CI"></a>
  <a href="https://codecov.io/gh/SimplifyJobs/prismatic"><img src="https://codecov.io/gh/SimplifyJobs/prismatic/branch/main/graph/badge.svg" alt="codecov"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
</p>

prismatic gives you two effects. Each is one small shader, made for
Flutter's Impeller renderer. They run on Skia and the web too.

## BorderBeam

A beam of light that travels around a widget's border. Put it on a card
while an agent works, on a search bar, or on anything that is thinking.

<p align="center">
  <img width="600" src="https://raw.githubusercontent.com/SimplifyJobs/prismatic/main/assets/showcase/showcase.gif" alt="Border beams lapping a card, riding a chat composer's edge, and breathing in from a card's border">
</p>

```dart
BorderBeam(
  borderRadius: 16,
  colors: BeamColors.ocean,
  child: card,
)
```

Pick the effect that fits:

- **`rotate`** laps the border. It's the default.
- **`line`** rides one edge. Lovely on inputs.
- **`pulse`** breathes in from every side. A calm "thinking" state.

There are 19 palettes, squircle corners, a theme and a controller. Use the
same radius as your widget, and the light sits right on its edge.

## DistortionWave

A colourful wave that bends one screen into the next. Use it when someone
pays, sends, finishes a step, or succeeds.

<table>
  <tr>
    <td width="33%" align="center">
      <img src="https://raw.githubusercontent.com/SimplifyJobs/prismatic/main/assets/demos/wave_vertical.webp" width="240" alt="A wave rising from a Send button and carrying a payment review into its receipt" /><br/>
      <sub><b>vertical</b>: up from a button</sub>
    </td>
    <td width="33%" align="center">
      <img src="https://raw.githubusercontent.com/SimplifyJobs/prismatic/main/assets/demos/wave_horizontal.webp" width="240" alt="A wave crossing from the left edge to the next sign-up step" /><br/>
      <sub><b>horizontal</b>: across from an edge</sub>
    </td>
    <td width="33%" align="center">
      <img src="https://raw.githubusercontent.com/SimplifyJobs/prismatic/main/assets/demos/wave_center.webp" width="240" alt="A ring of colour spreading from an icon inside a sheet" /><br/>
      <sub><b>center</b>: a ring from an icon</sub>
    </td>
  </tr>
</table>

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

Flip `revealed` to send the wave out. Flip it back to bring it home. The
anchor tells the wave where to start, and it leans toward your finger.

Going to a new page? Push a `DistortionWaveRoute`:

```dart
Navigator.of(context).push(
  DistortionWaveRoute<void>(
    source: WaveSource.of(context),
    builder: (_) => const ReceiptScreen(),
  ),
);
```

Five palettes come built in, and any `BorderBeam` palette works too. Or
pass your own colours:

```dart
DistortionWave(
  palette: const WavePalette(
    colors: [Color(0xFF7C5CFF), Color(0xFF39C6FF), Color(0xFF4CF2B5)],
    ahead: Color(0xFFFF8FD8),
    behind: Color(0xFF3D5AFE),
  ),
  // ...
)
```

## Get started

```console
flutter pub add prismatic
```

```dart
import 'package:prismatic/prismatic.dart';
```

You need Flutter 3.47 or newer. Load the shaders before your first frame,
so the very first beam or wave is smooth:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BorderBeam.precache();
  await DistortionWave.precache();
  runApp(const App());
}
```

## Good to know

- Give both screens of a wave an opaque background. The wave paints
  pictures of them.
- The beam reads your light or dark theme from
  [`material_ui`](https://pub.dev/packages/material_ui). Still on
  `package:flutter/material.dart`? Set `BeamStyle(theme: BeamTheme.dark)`
  yourself.
- Both effects respect the system's reduced-motion setting.

## Try it

- **[Live demo](https://simplifyjobs.github.io/prismatic/)** in your browser.
- **[The example app](example)**: `cd example && flutter run`.

## Learn more

- **[API reference](https://pub.dev/documentation/prismatic/latest/)** on
  pub.dev.
- **[Guides](doc/README.md)** for every option, written for you and your coding agent.
- **[Contributing](CONTRIBUTING.md)**: how to build, test and send a change.

## Credits

Both effects began as designs by
**[Jakub Antalik](https://x.com/jakubantalik)**:
[border-beam](https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam)
(React) and
[Distortion waves](https://github.com/Jakubantalik/Libraries.dev/tree/main/packages/distortion-waves)
(SwiftUI), both MIT. prismatic recreates their look with its own Flutter
renderer. If you like it, go star the originals.

## License

MIT. See [LICENSE](LICENSE), which also carries the original works' notices.
