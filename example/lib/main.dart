import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';

import 'src/display_corners.dart';
import 'src/home.dart';
import 'src/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the shaders before the first frame, so the first beam is lit and
  // the first wave bends.
  // …and learn the display's corner radius where Flutter is not told it.
  await Future.wait([
    BorderBeam.precache(),
    DistortionWave.precache(),
    DisplayCorners.load(),
  ]);
  runApp(const ExampleApp());
}

/// The prismatic example: one screen showing each beam effect on the
/// surface it is made for, and a second, a tap away, showing each distortion
/// wave on the screen it is made for. Dark by default.
class ExampleApp extends StatefulWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  bool _dark = const String.fromEnvironment('THEME') != 'light';

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'prismatic',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(_dark ? Brightness.dark : Brightness.light),
    themeAnimationCurve: Curves.easeOut,
    // Let a mouse drag the stage and the palette row too, on web and desktop.
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: PointerDeviceKind.values.toSet(),
      scrollbars: false,
    ),
    builder: (context, child) =>
        DisplayCornersScope(child: child ?? const SizedBox.shrink()),
    home: Home(
      dark: _dark,
      onToggleTheme: () => setState(() => _dark = !_dark),
    ),
  );
}
