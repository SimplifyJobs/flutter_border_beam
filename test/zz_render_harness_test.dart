// Throwaway visual harness: renders every effect to PNGs for review.
// Not part of the suite — deleted before commit.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

const out =
    '/private/tmp/claude-501/-Users-rehmatsg-Desktop-Development-border-beam/60ad29b9-aa67-49c3-b5bf-373437975086/scratchpad/renders';

final _effects = <String, BeamEffect>{
  'rotate': const BeamEffect.rotate(),
  'line': const BeamEffect.line(),
  'pulse': const BeamEffect.pulse(),
  'halo': const BeamEffect.halo(),
  'flow': const BeamEffect.flow(),
  'spin': const BeamEffect.spin(),
  'shimmer': const BeamEffect.shimmer(),
  'charge': const BeamEffect.charge(),
};

Widget scene(BeamEffect effect, Brightness brightness, Duration at,
    {BeamColors colors = BeamColors.colorful, BeamShape? shape}) {
  final dark = brightness == Brightness.dark;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      backgroundColor: dark ? const Color(0xFF080808) : const Color(0xFFF4F4F5),
      body: Center(
        child: RepaintBoundary(
          key: const ValueKey('shot'),
          child: ColoredBox(
           color: dark ? const Color(0xFF080808) : const Color(0xFFF4F4F5),
           child: Padding(
            padding: const EdgeInsets.all(48),
            child: BorderBeam(
              effect: effect,
              colors: colors,
              shape: shape,
              playback: BeamPlayback(debugFrozenAt: at),
              child: Container(
                width: 350,
                height: 140,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1F1F1F) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: dark ? const Color(0xFF333333) : const Color(0xFFE4E4E7),
                  ),
                ),
              ),
            ),
           ),
          ),
        ),
      ),
    ),
  );
}

Future<void> shoot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await BorderBeam.precache();
  });

  final only = Platform.environment['ONLY'];
  for (final entry in _effects.entries) {
    if (only != null && !only.split(',').contains(entry.key)) continue;
    for (final b in Brightness.values) {
      testWidgets('${entry.key} ${b.name}', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        await tester.pumpWidget(
          scene(entry.value, b, const Duration(milliseconds: 1300)),
        );
        await tester.pump();
        await shoot(tester, '${entry.key}_${b.name}');
      });
    }
  }
}
