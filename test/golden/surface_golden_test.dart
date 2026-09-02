@Tags(['golden'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden scenes for the surface options — the shape, travel, and glow
/// controls that change what a beam looks like without changing which variant
/// it is.
///
/// Same recipe as the variant goldens: the fake clock is frozen 1.3s after
/// activation, past the fade-in and mid-cycle. Every scene is the dark theme
/// with the colorful palette unless its name says otherwise, so the option
/// under test is the only thing that moves between images.
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
    double width = 350,
    double height = 140,
  }) async {
    await tester.pumpWidget(scene(beam: beam, width: width, height: height));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('line on the top edge', (tester) async {
    await capture(
      tester,
      'surface_line_edge_top',
      BorderBeam.line(
        style: const BeamStyle(theme: BeamTheme.dark),
        shape: const BeamShape(edge: BeamEdge.top),
        child: mockSurface(),
      ),
    );
  });

  testWidgets('line on the left edge', (tester) async {
    await capture(
      tester,
      'surface_line_edge_left',
      BorderBeam.line(
        style: const BeamStyle(theme: BeamTheme.dark),
        shape: const BeamShape(edge: BeamEdge.left),
        child: mockSurface(),
      ),
    );
  });

  testWidgets('rotate with three beams', (tester) async {
    await capture(
      tester,
      'surface_rotate_beamcount3',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark),
        timing: const BeamTiming(beamCount: 3),
        child: mockSurface(),
      ),
    );
  });

  testWidgets('rotate with a double-length tail', (tester) async {
    await capture(
      tester,
      'surface_rotate_tail2',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark, tailLength: 2),
        child: mockSurface(),
      ),
    );
  });

  testWidgets('rotate with a comet halo', (tester) async {
    await capture(
      tester,
      'surface_rotate_comet',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark, comet: true),
        child: mockSurface(),
      ),
    );
  });

  testWidgets('rotate with sparkles', (tester) async {
    await capture(
      tester,
      'surface_rotate_sparkle',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark, sparkle: 1),
        child: mockSurface(),
      ),
    );
  });

  testWidgets('rotate on a dashed ring', (tester) async {
    await capture(
      tester,
      'surface_rotate_segments8',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark, segments: 8),
        child: mockSurface(),
      ),
    );
  });

  testWidgets('rotate with a wider glow', (tester) async {
    await capture(
      tester,
      'surface_rotate_glowspread2',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark, glowSpread: 2),
        child: mockSurface(),
      ),
    );
  });

  testWidgets('rotate with the ring pushed out', (tester) async {
    await capture(
      tester,
      'surface_rotate_ringoffset8',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark),
        shape: const BeamShape(
          ringOffset: 8,
          radius: BorderRadius.all(Radius.circular(16)),
        ),
        child: mockSurface(),
      ),
    );
  });

  // A square box, so the inscribed star is as large as it can be, and no
  // surface behind it: the contour is the only thing the beam draws.
  testWidgets('rotate around a star contour', (tester) async {
    await capture(
      tester,
      'surface_rotate_contour_star',
      BorderBeam.rotate(
        style: const BeamStyle(theme: BeamTheme.dark, tailLength: 2),
        shape: BeamShape(contour: _star),
        child: const SizedBox.expand(),
      ),
      width: 260,
      height: 260,
    );
  });

  testWidgets('pulse-outside with a wider halo', (tester) async {
    await capture(
      tester,
      'surface_pulse_outside_glowspread2',
      BorderBeam.pulseOutside(
        style: const BeamStyle(theme: BeamTheme.dark, glowSpread: 2),
        child: mockSurface(),
      ),
    );
  });
}

/// A five-pointed star inscribed in the beam's bounds.
final _star = BeamPathContour((rect) {
  final path = Path();
  final centre = rect.center;
  final outer = rect.shortestSide / 2;
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : outer * 0.5;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = centre + Offset(math.cos(a) * r, math.sin(a) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}, key: 'golden-star');
