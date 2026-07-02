@Tags(['golden'])
library;

import 'package:border_beam/border_beam.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden scenes freeze the (fake) test clock at 1.3s after activation —
/// past the 0.6s fade-in, mid-cycle for every variant — so each image
/// captures a representative animated frame deterministically.
///
/// Regenerate with:
///   flutter test --update-goldens --tags golden
void main() {
  Widget scene({
    required Widget beam,
    required Brightness brightness,
    double width = 350,
    double height = 140,
  }) {
    final isDark = brightness == Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      home: ColoredBox(
        // The demo backdrops of the source library.
        color: isDark ? const Color(0xFF070707) : const Color(0xFFFDFDFD),
        child: Center(
          child: SizedBox(width: width, height: height, child: beam),
        ),
      ),
    );
  }

  Widget mockSurface(Brightness brightness, {double radius = 16}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? const Color(0xFF1D1D1D)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: brightness == Brightness.dark
                ? const Color(0x14FFFFFF)
                : const Color(0x14000000),
          ),
        ),
      );

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget Function(Brightness) beam, {
    required Brightness brightness,
    double width = 350,
    double height = 140,
  }) async {
    await tester.pumpWidget(
      scene(
        beam: beam(brightness),
        brightness: brightness,
        width: width,
        height: height,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark ? 'dark' : 'light';
    final beamTheme = brightness == Brightness.dark
        ? BeamTheme.dark
        : BeamTheme.light;

    for (final MapEntry(key: paletteName, value: colors) in {
      'colorful': BeamColors.colorful,
      'mono': BeamColors.mono,
    }.entries) {
      testWidgets('rotate $theme $paletteName', (tester) async {
        await capture(
          tester,
          'rotate_${theme}_$paletteName',
          brightness: brightness,
          (b) => BorderBeam.rotate(
            colors: colors,
            theme: beamTheme,
            child: mockSurface(b),
          ),
        );
      });

      testWidgets('small $theme $paletteName', (tester) async {
        await capture(
          tester,
          'small_${theme}_$paletteName',
          brightness: brightness,
          width: 70,
          height: 36,
          (b) => BorderBeam.small(
            colors: colors,
            theme: beamTheme,
            child: mockSurface(b, radius: 32),
          ),
        );
      });

      testWidgets('line $theme $paletteName', (tester) async {
        await capture(
          tester,
          'line_${theme}_$paletteName',
          brightness: brightness,
          (b) => BorderBeam.line(
            colors: colors,
            theme: beamTheme,
            child: mockSurface(b),
          ),
        );
      });

      testWidgets('pulseInside $theme $paletteName', (tester) async {
        await capture(
          tester,
          'pulse_inside_${theme}_$paletteName',
          brightness: brightness,
          (b) => BorderBeam.pulseInside(
            colors: colors,
            theme: beamTheme,
            child: mockSurface(b),
          ),
        );
      });

      testWidgets('pulseOutside $theme $paletteName', (tester) async {
        await capture(
          tester,
          'pulse_outside_${theme}_$paletteName',
          brightness: brightness,
          (b) => BorderBeam.pulseOutside(
            colors: colors,
            theme: beamTheme,
            child: mockSurface(b),
          ),
        );
      });
    }

    testWidgets('rotate $theme ocean superellipse', (tester) async {
      await capture(
        tester,
        'rotate_${theme}_ocean_squircle',
        brightness: brightness,
        (b) => BorderBeam.rotate(
          colors: BeamColors.ocean,
          theme: beamTheme,
          useSuperellipse: true,
          borderRadius: 28,
          child: mockSurface(b, radius: 28),
        ),
      );
    });
  }

  testWidgets('rotate dark custom palette', (tester) async {
    await capture(
      tester,
      'rotate_dark_custom',
      brightness: Brightness.dark,
      (b) => BorderBeam.rotate(
        colors: const BeamColors.custom([
          Color(0xFFFF0080),
          Color(0xFF00E5FF),
          Color(0xFFFFC400),
        ]),
        theme: BeamTheme.dark,
        child: mockSurface(b),
      ),
    );
  });
}
