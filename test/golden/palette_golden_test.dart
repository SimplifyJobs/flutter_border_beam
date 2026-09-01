@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// One scene per palette the Flutter port adds on top of the React source's
/// four, plus the two derivation entry points ([BeamColors.fromSeed] and
/// [BeamColors.lerp]).
///
/// Every scene uses the same frame the variant goldens do — rotate, dark
/// theme, clock frozen at 1.3s — so the only thing that varies between these
/// images is the palette, which is what they are here to pin.
///
/// Regenerate with:
///   flutter test --update-goldens --tags golden
void main() {
  Widget scene(Widget beam) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark),
    home: ColoredBox(
      // The demo backdrop of the source library.
      color: const Color(0xFF070707),
      child: Center(child: SizedBox(width: 350, height: 140, child: beam)),
    ),
  );

  Widget mockSurface() => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF1D1D1D),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x14FFFFFF)),
    ),
  );

  Future<void> capture(
    WidgetTester tester,
    String name,
    BeamColors colors,
  ) async {
    await tester.pumpWidget(
      scene(
        BorderBeam.rotate(
          colors: colors,
          style: const BeamStyle(theme: BeamTheme.dark),
          child: mockSurface(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/palette_$name.png'),
    );
  }

  for (final MapEntry(key: name, value: colors) in const {
    'aurora': BeamColors.aurora,
    'neon': BeamColors.neon,
    'candy': BeamColors.candy,
    'ember': BeamColors.ember,
    'ice': BeamColors.ice,
    'gold': BeamColors.gold,
    'holographic': BeamColors.holographic,
  }.entries) {
    testWidgets('rotate dark $name', (tester) async {
      await capture(tester, name, colors);
    });
  }

  // The brand blue of the package's own demo, spread by the default
  // (analogous) harmony.
  testWidgets('rotate dark fromSeed', (tester) async {
    await capture(
      tester,
      'from_seed',
      const BeamColors.fromSeed(Color(0xFF18A8F0)),
    );
  });

  // Halfway between two source presets: neither end's colors, both ends'
  // geometry (they share it).
  testWidgets('rotate dark lerp ocean to sunset', (tester) async {
    await capture(
      tester,
      'lerp_ocean_sunset',
      const BeamColors.lerp(BeamColors.ocean, BeamColors.sunset, 0.5),
    );
  });
}
