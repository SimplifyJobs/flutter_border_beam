@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden scenes for the options ported from the reference implementations:
/// the stock pulse-outside look, the pulse-inside wash scale, and the
/// render-scale magnification.
///
/// They share the frozen-clock convention of `beam_golden_test.dart`
/// (colorful palette, t = 1.3s), so each image can be read against the plain
/// frame it varies — `pulse_outside_*_colorful` for the stock pair,
/// `pulse_inside_dark_colorful` for the wash scale, and the large default
/// captured here for the render scale.
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
    Widget beam, {
    Brightness brightness = Brightness.dark,
    double width = 350,
    double height = 140,
  }) async {
    await tester.pumpWidget(
      scene(beam: beam, brightness: brightness, width: width, height: height),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  // The React library's own pulse-outside defaults: a tighter, dimmer halo
  // than the demo recipe every other pulse-outside golden captures.
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark ? 'dark' : 'light';
    testWidgets('pulse-outside stock $theme', (tester) async {
      await capture(
        tester,
        'research_pulse_outside_stock_$theme',
        BorderBeam.pulseOutside(
          style: BeamStyle.pulseOutsideStock.copyWith(
            theme: brightness == Brightness.dark
                ? BeamTheme.dark
                : BeamTheme.light,
          ),
          child: mockSurface(brightness),
        ),
        brightness: brightness,
      );
    });
  }

  // The inward wash at 0.6: the same border, less flood.
  testWidgets('pulse-inside inner scale 0.6', (tester) async {
    await capture(
      tester,
      'research_pulse_inside_inner_scale_0_6',
      BorderBeam.pulseInside(
        style: const BeamStyle(theme: BeamTheme.dark, innerSizeScale: 0.6),
        child: mockSurface(Brightness.dark),
      ),
    );
  });

  // The render-scale pair, on a box twice the width the palettes were drawn
  // for: the default frame is the reference, the scaled one is the same beam
  // painted at half size and magnified back.
  testWidgets('rotate on a large box', (tester) async {
    await capture(
      tester,
      'research_rotate_large_default',
      BorderBeam.rotate(
        borderRadius: 24,
        style: const BeamStyle(theme: BeamTheme.dark),
        child: mockSurface(Brightness.dark, radius: 24),
      ),
      width: 700,
      height: 280,
    );
  });

  testWidgets('rotate on a large box at render scale 0.5', (tester) async {
    await capture(
      tester,
      'research_rotate_render_scale_0_5',
      BorderBeam.rotate(
        // The radius is a box-relative length: scaledBy halves it for the
        // small canvas, so it still lands on the child's 24 once magnified.
        borderRadius: 24,
        style: const BeamStyle(theme: BeamTheme.dark, renderScale: 0.5),
        child: mockSurface(Brightness.dark, radius: 24),
      ),
      width: 700,
      height: 280,
    );
  });
}
