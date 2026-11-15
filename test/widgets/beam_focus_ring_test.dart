import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// [BeamFocusRing] is a thin composition: it only decides `active` on the
/// [BorderBeam] it wraps, from focus plus [FocusManager.highlightMode]. Every
/// assertion below reads that decision off the inner beam.
void main() {
  // The test binding reports the Android platform, whose automatic highlight
  // mode is `touch` — the mode under which the ring deliberately stays dark.
  // Focus tracking is asserted under traditional highlighting; the groups
  // that care about the mode set their own.
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  BorderBeam beamOf(WidgetTester tester) =>
      tester.widget<BorderBeam>(find.byType(BorderBeam));

  bool? ringActive(WidgetTester tester) => beamOf(tester).active;

  // The Focus the ring inserts around its child when given no node.
  FocusNode internalNode(WidgetTester tester) => tester
      .widget<Focus>(
        find
            .descendant(
              of: find.byType(BeamFocusRing),
              matching: find.byType(Focus),
            )
            .first,
      )
      .focusNode!;

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

  Widget box() => const SizedBox(width: 200, height: 60);

  group('focus tracking', () {
    testWidgets('focus lights the ring and blur darkens it', (tester) async {
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
      // An unfocused ring costs nothing: its beam never started a clock.
      expect(tester.binding.transientCallbackCount, 0);

      node.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);

      node.unfocus();
      await settleFocus(tester);
      expect(ringActive(tester), isFalse);
    });

    testWidgets('lights for focus anywhere inside its subtree', (tester) async {
      final deep = FocusNode();
      addTearDown(deep.dispose);

      await tester.pumpWidget(
        scene(
          BeamFocusRing(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Focus(focusNode: deep, child: box()),
                ),
              ],
            ),
          ),
        ),
      );
      deep.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);
    });

    testWidgets('keyboard traversal moves the ring with focus', (tester) async {
      // Automatic highlighting, as in an app: the key presses themselves
      // switch the highlight mode to traditional.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      final inside = FocusNode(debugLabel: 'inside');
      final outside = FocusNode(debugLabel: 'outside');
      addTearDown(inside.dispose);
      addTearDown(outside.dispose);

      await tester.pumpWidget(
        scene(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeamFocusRing(
                child: Focus(focusNode: inside, child: box()),
              ),
              Focus(focusNode: outside, child: box()),
            ],
          ),
        ),
      );
      expect(ringActive(tester), isFalse);

      // The ring's own Focus is skipped by traversal, so the first Tab lands
      // on the field inside it, not on the ring.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleFocus(tester);
      expect(inside.hasPrimaryFocus, isTrue);
      expect(
        FocusManager.instance.highlightMode,
        FocusHighlightMode.traditional,
      );
      expect(ringActive(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleFocus(tester);
      expect(outside.hasPrimaryFocus, isTrue);
      expect(ringActive(tester), isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await settleFocus(tester);
      expect(inside.hasPrimaryFocus, isTrue);
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
            child: Focus(focusNode: node, child: box()),
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

  group('focus node ownership', () {
    testWidgets('without a node it inserts a non-focusable Focus it owns', (
      tester,
    ) async {
      await tester.pumpWidget(scene(BeamFocusRing(child: box())));

      final internal = internalNode(tester);
      expect(internal.canRequestFocus, isFalse);
      expect(internal.skipTraversal, isTrue);

      await tester.pumpWidget(const SizedBox());
      // Disposed with the ring: a disposed node rejects new listeners.
      expect(() => internal.addListener(() {}), throwsFlutterError);
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
              // The followed node lives outside the ring's subtree.
              Focus(focusNode: node, child: const SizedBox(height: 20)),
              BeamFocusRing(focusNode: node, child: box()),
            ],
          ),
        ),
      );
      expect(ringActive(tester), isFalse);
      expect(
        find.descendant(
          of: find.byType(BeamFocusRing),
          matching: find.byType(Focus),
        ),
        findsNothing,
        reason: 'an explicit node adds no Focus of its own',
      );

      other.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isFalse);

      node.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);
    });

    testWidgets('never disposes a node it was given', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        scene(
          BeamFocusRing(
            focusNode: node,
            child: Focus(focusNode: node, child: box()),
          ),
        ),
      );
      node.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);

      await tester.pumpWidget(const SizedBox());
      // Still alive: it takes listeners and can be focused again elsewhere.
      void listener() {}
      expect(() => node.addListener(listener), returnsNormally);
      node.removeListener(listener);

      await tester.pumpWidget(scene(Focus(focusNode: node, child: box())));
      node.requestFocus();
      await settleFocus(tester);
      expect(node.hasPrimaryFocus, isTrue);
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
            BeamFocusRing(focusNode: node, child: box()),
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

    testWidgets('switching to a given node disposes the internal one', (
      tester,
    ) async {
      final given = FocusNode();
      addTearDown(given.dispose);

      Widget build({FocusNode? node}) => scene(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(focusNode: given, child: const SizedBox(height: 20)),
            BeamFocusRing(focusNode: node, child: box()),
          ],
        ),
      );

      await tester.pumpWidget(build());
      final internal = internalNode(tester);

      await tester.pumpWidget(build(node: given));
      expect(() => internal.addListener(() {}), throwsFlutterError);

      given.requestFocus();
      await settleFocus(tester);
      expect(ringActive(tester), isTrue);

      // And back: a fresh internal node takes over.
      await tester.pumpWidget(build());
      await settleFocus(tester);
      expect(internalNode(tester), isNot(same(internal)));
      expect(ringActive(tester), isFalse);
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
            child: Focus(focusNode: node, child: box()),
          ),
        ),
      );
      node.requestFocus();
      await settleFocus(tester);

      expect(node.hasFocus, isTrue);
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
            child: Focus(focusNode: node, child: box()),
          ),
        ),
      );
      expect(
        ringActive(tester),
        isFalse,
        reason: 'alwaysShow still needs focus',
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
            child: Focus(focusNode: node, child: box()),
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

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await settleFocus(tester);
      expect(ringActive(tester), isFalse);
    });
  });

  group('pass-through', () {
    testWidgets('defaults to an ocean spin ring', (tester) async {
      await tester.pumpWidget(scene(BeamFocusRing(child: box())));

      final beam = beamOf(tester);
      expect(beam.effect, const BeamEffect.spin());
      expect(beam.colors, BeamColors.ocean);
    });

    testWidgets('hands its effect, style, shape and timing to the beam', (
      tester,
    ) async {
      await tester.pumpWidget(
        scene(
          const BeamFocusRing(
            effect: BeamEffect.line(edge: BeamEdge.top),
            colors: BeamColors.sunset,
            borderRadius: 12,
            style: BeamStyle(strength: 0.5),
            shape: BeamShape(borderWidth: 2),
            timing: BeamTiming(speed: 2),
            child: SizedBox(width: 200, height: 60),
          ),
        ),
      );

      final beam = beamOf(tester);
      expect(beam.effect, const BeamEffect.line(edge: BeamEdge.top));
      expect(beam.colors, BeamColors.sunset);
      expect(beam.borderRadius, 12);
      expect(beam.style, const BeamStyle(strength: 0.5));
      expect(beam.shape, const BeamShape(borderWidth: 2));
      expect(beam.timing, const BeamTiming(speed: 2));
    });

    testWidgets('describes itself for the inspector', (tester) async {
      await tester.pumpWidget(
        scene(BeamFocusRing(alwaysShow: true, child: box())),
      );

      final description = tester
          .widget<BeamFocusRing>(find.byType(BeamFocusRing))
          .toDiagnosticsNode()
          .toStringDeep();
      expect(description, contains('alwaysShow'));
      expect(description, contains('effect: BeamEffect.spin()'));
    });
  });
}
