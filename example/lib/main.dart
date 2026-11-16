import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

import 'src/home.dart';
import 'src/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the beam shader before the first frame, so the first beam is lit.
  await BorderBeam.precache();
  runApp(const ExampleApp());
}

/// The flutter_border_beam example: one screen showing each effect on the
/// surface it is made for. Dark by default.
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
    title: 'Border Beam',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(_dark ? Brightness.dark : Brightness.light),
    themeAnimationCurve: Curves.easeOut,
    // Let a mouse drag the stage and the palette row too, on web and desktop.
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: PointerDeviceKind.values.toSet(),
      scrollbars: false,
    ),
    home: Home(
      dark: _dark,
      onToggleTheme: () => setState(() => _dark = !_dark),
    ),
  );
}
