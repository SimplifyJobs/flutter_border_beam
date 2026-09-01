import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// [BeamFocusRing] is a thin composition: it only decides `active` on the
/// [BorderBeam] it wraps, from focus plus [FocusManager.highlightMode]. Every
/// assertion below reads that decision off the inner beam.
void main() {
  // The test binding reports the Android platform, whose automatic highlight
  // mode is `touch` — the mode under which the ring deliberately stays dark.
  // Focus tracking is asserted under traditional highlighting; the
  // highlight-mode group sets its own.
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  bool? ringActive(WidgetTester tester) =>
      tester.widget<BorderBeam>(find.byType(BorderBeam)).active;

  // A focus change lands over two frames: the manager applies it during the
  // first, and the node's notification rebuilds the ring in the second.
  Future<void> settleFocus(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Widget scene(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );

  group('focus tracking', () {
    testWidgets('lights while the wrapped subtree holds focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        scene(
          BeamFocusRing(
            child: SizedBox(
              width: 200,
              height: 60,
              child: TextField(focusNode: node),
            ),
          ),
        ),
      );
      expect(ringActive(tester), isFalse);

      node.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);

      node.unfocus();
      await settleFocus(tester);
      expect(ringActive(tester), isFalse);
    });

    testWidgets('follows an explicitly given node instead', (tester) async {
      final node = FocusNode();
      final other = FocusNode();
      addTearDown(node.dispose);
      addTearDown(other.dispose);

      await tester.pumpWidget(
        scene(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Focus(focusNode: other, child: const SizedBox(height: 20)),
              BeamFocusRing(
                focusNode: node,
                child: Focus(
                  focusNode: node,
                  child: const SizedBox(width: 200, height: 60),
                ),
              ),
            ],
          ),
        ),
      );
      expect(ringActive(tester), isFalse);

      other.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isFalse);

      node.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);
    });

    testWidgets('an explicit node adds no Focus of its own', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        scene(
          BeamFocusRing(
            focusNode: node,
            child: const SizedBox(width: 200, height: 60),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(BeamFocusRing),
          matching: find.byType(Focus),
        ),
        findsNothing,
      );
    });

    testWidgets('swapping the node moves the ring with it', (tester) async {
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget build(FocusNode node) => scene(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(focusNode: first, child: const SizedBox(height: 20)),
            Focus(focusNode: second, child: const SizedBox(height: 20)),
            BeamFocusRing(
              focusNode: node,
              child: const SizedBox(width: 200, height: 60),
            ),
          ],
        ),
      );

      await tester.pumpWidget(build(first));
      first.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);

      await tester.pumpWidget(build(second));
      await settleFocus(tester);
      expect(ringActive(tester), isFalse);

      second.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);
    });

    testWidgets('disposal with focus held leaves no ticker behind', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        scene(
          BeamFocusRing(
            child: Focus(
              focusNode: node,
              child: const SizedBox(width: 200, height: 60),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('highlight mode', () {
    testWidgets('stays dark under touch highlighting', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        scene(
          BeamFocusRing(
            child: Focus(
              focusNode: node,
              child: const SizedBox(width: 200, height: 60),
            ),
          ),
        ),
      );
      node.requestFocus();
      await settleFocus(tester);

      expect(ringActive(tester), isFalse);
    });

    testWidgets('alwaysShow lights it under touch highlighting too', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        scene(
          BeamFocusRing(
            alwaysShow: true,
            child: Focus(
              focusNode: node,
              child: const SizedBox(width: 200, height: 60),
            ),
          ),
        ),
      );
      node.requestFocus();
      await settleFocus(tester);

      expect(ringActive(tester), isTrue);
    });

    testWidgets('a mode change while focused flips the ring', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        scene(
          BeamFocusRing(
            child: Focus(
              focusNode: node,
              child: const SizedBox(width: 200, height: 60),
            ),
          ),
        ),
      );
      node.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isFalse);

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);
    });
  });

  group('pass-through', () {
    testWidgets('hands its style, shape and timing to the beam', (
      tester,
    ) async {
      await tester.pumpWidget(
        scene(
          const BeamFocusRing(
            variant: BeamVariant.line,
            colors: BeamColors.sunset,
            borderRadius: 12,
            style: BeamStyle(strength: 0.5),
            shape: BeamShape(borderWidth: 2),
            timing: BeamTiming(speed: 2),
            child: SizedBox(width: 200, height: 60),
          ),
        ),
      );

      final beam = tester.widget<BorderBeam>(find.byType(BorderBeam));
      expect(beam.variant, BeamVariant.line);
      expect(beam.colors, BeamColors.sunset);
      expect(beam.borderRadius, 12);
      expect(beam.style, const BeamStyle(strength: 0.5));
      expect(beam.shape, const BeamShape(borderWidth: 2));
      expect(beam.timing, const BeamTiming(speed: 2));
    });

    testWidgets('defaults to the compact ocean ring', (tester) async {
      await tester.pumpWidget(
        scene(const BeamFocusRing(child: SizedBox(width: 200, height: 60))),
      );

      final beam = tester.widget<BorderBeam>(find.byType(BorderBeam));
      expect(beam.variant, BeamVariant.small);
      expect(beam.colors, BeamColors.ocean);
    });

    testWidgets('describes itself for the inspector', (tester) async {
      await tester.pumpWidget(
        scene(
          const BeamFocusRing(
            alwaysShow: true,
            child: SizedBox(width: 200, height: 60),
          ),
        ),
      );

      final description = tester
          .widget<BeamFocusRing>(find.byType(BeamFocusRing))
          .toDiagnosticsNode()
          .toStringDeep();
      expect(description, contains('alwaysShow'));
      expect(description, contains('variant: small'));
    });
  });
}
