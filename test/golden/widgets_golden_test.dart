@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden scenes for the surface and interaction wrappers, frozen at the same
/// 1.3s instant the variant goldens use (past the 0.6s fade-in, mid-cycle).
/// They pin what the wrappers *compose* — the decoration form painting the
/// same beam a widget does, and the focus ring lit — not the beam frames
/// themselves, which `beam_golden_test.dart` owns.
///
/// Regenerate with:
///   flutter test --update-goldens --tags golden
void main() {
  const surfaceRadius = 16.0;

  Widget scene(Widget body) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark),
    home: ColoredBox(
      // The demo backdrop of the source library.
      color: const Color(0xFF070707),
      child: Center(child: body),
    ),
  );

  BoxDecoration surface({double radius = surfaceRadius}) => BoxDecoration(
    color: const Color(0xFF1D1D1D),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0x14FFFFFF)),
  );

  testWidgets('decoration rotate', (tester) async {
    await tester.pumpWidget(
      scene(
        Container(
          width: 350,
          height: 140,
          decoration: surface(),
          // rotate paints over its child, so the beam takes the foreground
          // slot and the surface takes the background one.
          foregroundDecoration: const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
            style: BeamStyle(theme: BeamTheme.dark),
            borderRadius: surfaceRadius,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/widgets_decoration_rotate.png'),
    );
  });

  testWidgets('focus ring active', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      scene(
        BeamFocusRing(
          borderRadius: 32,
          style: const BeamStyle(theme: BeamTheme.dark),
          child: Focus(
            focusNode: node,
            child: Container(
              width: 220,
              height: 56,
              decoration: surface(radius: 32),
            ),
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/widgets_focus_ring_active.png'),
    );
  });
}
