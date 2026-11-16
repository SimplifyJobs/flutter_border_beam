@Tags(['golden'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'golden_scene.dart';

/// The widgets family: what the decoration form and the three interaction
/// wrappers compose — the decoration painting the same beam a widget does,
/// the focus ring lit, the hover beam pulled toward the cursor, the press
/// beam held down. The beam frames themselves belong to
/// `beam_golden_test.dart`.
///
/// Dark theme, t = 1.3s after the interaction starts.
void main() {
  setUpAll(BorderBeam.precache);

  BoxDecoration surface({double radius = 16}) => BoxDecoration(
    color: const Color(0xFF1D1D1D),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0x14FFFFFF)),
  );

  testWidgets('decoration rotate', (tester) async {
    await captureGolden(
      tester,
      'widgets_decoration_rotate',
      goldenScene(
        Container(
          decoration: surface(),
          // The beam paints over its child, so it takes the foreground slot
          // and the surface the background one.
          foregroundDecoration: const BeamDecoration(
            brightness: Brightness.dark,
            effect: BeamEffect.rotate(),
            style: BeamStyle(theme: BeamTheme.dark),
            borderRadius: 16,
          ),
        ),
      ),
    );
  });

  testWidgets('decoration pulse', (tester) async {
    await captureGolden(
      tester,
      'widgets_decoration_pulse',
      goldenScene(
        Container(
          decoration: surface(),
          foregroundDecoration: const BeamDecoration(
            brightness: Brightness.dark,
            effect: BeamEffect.pulse(),
            colors: BeamColors.ocean,
            borderRadius: 16,
          ),
        ),
      ),
    );
  });

  testWidgets('focus ring focused', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    final node = FocusNode();
    addTearDown(node.dispose);
    await captureGolden(
      tester,
      'widgets_focus_ring_focused',
      goldenScene(
        BeamFocusRing(
          borderRadius: 28,
          style: const BeamStyle(theme: BeamTheme.dark),
          child: Focus(
            focusNode: node,
            child: Container(decoration: surface(radius: 28)),
          ),
        ),
        size: const Size(220, 56),
      ),
      beforeFreeze: () async {
        node.requestFocus();
        await tester.pump();
      },
    );
  });

  testWidgets('hover follows the cursor', (tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await captureGolden(
      tester,
      'widgets_hover_following',
      goldenScene(
        BeamHover(
          borderRadius: 16,
          style: const BeamStyle(theme: BeamTheme.dark),
          child: Container(decoration: surface()),
        ),
      ),
      beforeFreeze: () async {
        // Into the card near its top-right corner: the beam eases there.
        final card = tester.getRect(find.byType(BeamHover));
        await mouse.moveTo(card.topRight + const Offset(-40, 20));
        await tester.pump();
      },
      frameByFrame: true,
    );
    // Leave, and let the hold and the fade-out run down. One long pump only
    // starts the fade on its single frame: wait out the hold, then play the
    // fade frame by frame.
    await mouse.removePointer();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('press held down', (tester) async {
    late TestGesture finger;
    await captureGolden(
      tester,
      'widgets_press_held',
      goldenScene(
        BeamPress(
          borderRadius: 16,
          style: const BeamStyle(theme: BeamTheme.dark),
          child: Container(decoration: surface()),
        ),
      ),
      beforeFreeze: () async {
        finger = await tester.startGesture(
          tester.getCenter(find.byType(BeamPress)),
        );
        await tester.pump();
      },
    );
    await finger.up();
    // Let the minimum-duration timer and the release's fade-out run down,
    // the fade frame by frame.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });
}
