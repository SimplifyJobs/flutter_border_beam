@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden scenes for the motion options — travel direction, several beams on
/// one contour, and a sweep driven from a value instead of the clock.
///
/// They share the frozen-clock convention of `beam_golden_test.dart` (dark
/// theme, colorful palette, t = 1.3s) so each image can be read against the
/// plain `rotate_dark_colorful` / `line_dark_colorful` frame it varies.
///
/// Regenerate with:
///   flutter test --update-goldens --tags golden
void main() {
  Widget scene({
    required Widget beam,
    double width = 350,
    double height = 140,
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark),
    home: ColoredBox(
      // The demo backdrop of the source library.
      color: const Color(0xFF070707),
      child: Center(
        child: SizedBox(width: width, height: height, child: beam),
      ),
    ),
  );

  Widget mockSurface({double radius = 16}) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF1D1D1D),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0x14FFFFFF)),
    ),
  );

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget beam, {
    Duration freeze = const Duration(milliseconds: 1300),
  }) async {
    await tester.pumpWidget(scene(beam: beam));
    await tester.pump();
    await tester.pump(freeze);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  // The mirror of `rotate_dark_colorful`: same instant, same hue, the head
  // the same distance round the border — the other way.
  testWidgets('rotate reverse', (tester) async {
    await capture(
      tester,
      'motion_rotate_reverse',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark),
        timing: const BeamTiming(direction: BeamDirection.reverse),
        child: mockSurface(),
      ),
    );
  });

  // Two beams half a cycle apart: opposite sides of the border at every
  // instant.
  testWidgets('rotate with two beams', (tester) async {
    await capture(
      tester,
      'motion_rotate_beamcount2',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark),
        timing: const BeamTiming(beamCount: 2),
        child: mockSurface(),
      ),
    );
  });

  // A driven sweep: the beam sits at half its travel no matter how long the
  // clock has run, which is what makes rotate readable as a progress ring.
  testWidgets('rotate driven to half progress', (tester) async {
    await capture(
      tester,
      'motion_progress_0_5',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark),
        progress: 0.5,
        child: mockSurface(),
      ),
    );
  });

  // The line beam travelling right-to-left, against `line_dark_colorful`.
  testWidgets('line reverse', (tester) async {
    await capture(
      tester,
      'motion_line_reverse',
      BorderBeam.line(
        style: const BeamStyle(theme: BeamTheme.dark),
        timing: const BeamTiming(direction: BeamDirection.reverse),
        child: mockSurface(),
      ),
    );
  });
}
