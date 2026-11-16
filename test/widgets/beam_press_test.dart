import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// [BeamPress] observes raw pointers and only flips `active` on the
/// [BorderBeam] it wraps. The two things it must never get wrong: a tap
/// shorter than [BeamPress.minimumDuration] still shows a full pulse, and the
/// child's own gestures keep working.
void main() {
  BorderBeam beamOf(WidgetTester tester) =>
      tester.widget<BorderBeam>(find.byType(BorderBeam));

  bool? pressActive(WidgetTester tester) => beamOf(tester).active;

  Widget scene(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );

  Widget press({
    VoidCallback? onTap,
    Duration minimumDuration = const Duration(milliseconds: 600),
    Widget child = const SizedBox(width: 200, height: 80),
  }) => scene(
    BeamPress(onTap: onTap, minimumDuration: minimumDuration, child: child),
  );

  Future<TestGesture> pressDown(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(BeamPress)),
    );
    await tester.pump();
    return gesture;
  }

  Widget pressableList(ScrollController controller) => scene(
    SizedBox(
      height: 300,
      child: ListView(
        controller: controller,
        children: [
          for (var i = 0; i < 12; i++)
            const BeamPress(child: SizedBox(height: 80)),
        ],
      ),
    ),
  );

  group('press lifecycle', () {
    testWidgets('lights on pointer down', (tester) async {
      await tester.pumpWidget(press());
      expect(pressActive(tester), isFalse);
      expect(tester.binding.transientCallbackCount, 0);

      final gesture = await pressDown(tester);
      expect(pressActive(tester), isTrue);

      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a quick tap stays lit until the minimum since the press', (
      tester,
    ) async {
      await tester.pumpWidget(press());
      final gesture = await pressDown(tester);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();
      expect(pressActive(tester), isTrue, reason: 'released before minimum');

      // 50ms + 500ms: the minimum runs from the press, not the release.
      await tester.pump(const Duration(milliseconds: 500));
      expect(pressActive(tester), isTrue, reason: 'still inside minimum');

      await tester.pump(const Duration(milliseconds: 100));
      expect(pressActive(tester), isFalse);
    });

    testWidgets('a long press releases the moment the pointer lifts', (
      tester,
    ) async {
      await tester.pumpWidget(press());
      final gesture = await pressDown(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(pressActive(tester), isTrue, reason: 'held past the minimum');

      await gesture.up();
      await tester.pump();
      expect(pressActive(tester), isFalse);
    });

    testWidgets('a zero minimum releases on pointer up', (tester) async {
      await tester.pumpWidget(press(minimumDuration: Duration.zero));
      final gesture = await pressDown(tester);
      expect(pressActive(tester), isTrue);

      await gesture.up();
      await tester.pump();
      expect(pressActive(tester), isFalse);
    });

    testWidgets('a cancel drops the beam without waiting out the minimum', (
      tester,
    ) async {
      await tester.pumpWidget(press());
      final gesture = await pressDown(tester);
      expect(pressActive(tester), isTrue);

      await gesture.cancel();
      await tester.pump();
      expect(pressActive(tester), isFalse);

      // And the cancelled hold's timer does not resurrect or re-drop it.
      await tester.pump(const Duration(seconds: 1));
      expect(pressActive(tester), isFalse);
    });

    testWidgets('a second finger does not restart the hold', (tester) async {
      await tester.pumpWidget(press());
      final center = tester.getCenter(find.byType(BeamPress));
      final first = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final second = await tester.startGesture(center + const Offset(10, 10));
      await tester.pump();
      await first.up();
      await tester.pump(const Duration(milliseconds: 300));

      // The minimum runs from the first press, so 700ms in it has elapsed —
      // the second pointer never re-armed it.
      expect(pressActive(tester), isFalse);
      await second.up();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the beam winds down to no ticker after release', (
      tester,
    ) async {
      await tester.pumpWidget(press());
      final gesture = await pressDown(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await gesture.up();
      // Past the 600ms minimum, then past the beam's 0.5s fade-out.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(pressActive(tester), isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('disposal mid-hold leaves no ticker and no pending timer', (
      tester,
    ) async {
      await tester.pumpWidget(press());
      final gesture = await pressDown(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();
      expect(pressActive(tester), isTrue, reason: 'held by the minimum timer');

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
      // Ending inside the minimum: a timer dispose failed to cancel fails
      // the binding's no-pending-timers invariant.
    });
  });

  group('gestures', () {
    testWidgets('onTap fires when the pointer lifts inside', (tester) async {
      var taps = 0;
      await tester.pumpWidget(press(onTap: () => taps++));

      await tester.tap(find.byType(BeamPress));
      expect(taps, 1);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('onTap does not fire when the pointer lifts outside', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(press(onTap: () => taps++));

      final gesture = await pressDown(tester);
      await gesture.moveTo(const Offset(5, 5));
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      expect(taps, 0);
    });

    testWidgets('a cancelled press does not tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(press(onTap: () => taps++));

      final gesture = await pressDown(tester);
      await gesture.cancel();
      await tester.pump(const Duration(seconds: 1));

      expect(taps, 0);
    });

    testWidgets('the child keeps receiving its own taps', (tester) async {
      var childTaps = 0;
      var pressTaps = 0;
      await tester.pumpWidget(
        press(
          onTap: () => pressTaps++,
          child: GestureDetector(
            key: const ValueKey<String>('child'),
            behavior: HitTestBehavior.opaque,
            onTap: () => childTaps++,
            child: const SizedBox(width: 200, height: 80),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('child')));
      await tester.pump(const Duration(seconds: 1));

      expect(childTaps, 1);
      // The Listener never enters the arena, so both fire — which is why a
      // child with its own tap handling should leave onTap null.
      expect(pressTaps, 1);
    });

    testWidgets('a drag over it still scrolls the list underneath', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(pressableList(controller));

      await tester.drag(find.byType(BeamPress).first, const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
    });

    testWidgets('a scroll that steals the gesture cancels the press', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(pressableList(controller));

      bool? firstActive() =>
          tester.widget<BorderBeam>(find.byType(BorderBeam).first).active;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BeamPress).first),
      );
      await tester.pump();
      expect(firstActive(), isTrue);

      await gesture.moveBy(const Offset(0, -120));
      await tester.pump();
      expect(firstActive(), isFalse);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('pass-through', () {
    testWidgets('defaults to a pulse', (tester) async {
      await tester.pumpWidget(press());
      expect(beamOf(tester).effect, const BeamEffect.pulse());
    });

    testWidgets('hands its effect, style, shape and timing to the beam', (
      tester,
    ) async {
      await tester.pumpWidget(
        scene(
          const BeamPress(
            effect: BeamEffect.rotate(count: 2),
            colors: BeamColors.sunset,
            borderRadius: 20,
            style: BeamStyle(strength: 0.4),
            shape: BeamShape(borderWidth: 2),
            timing: BeamTiming(speed: 2),
            child: SizedBox(width: 200, height: 80),
          ),
        ),
      );

      final beam = beamOf(tester);
      expect(beam.effect, const BeamEffect.rotate(count: 2));
      expect(beam.colors, BeamColors.sunset);
      expect(beam.borderRadius, 20);
      expect(beam.style, const BeamStyle(strength: 0.4));
      expect(beam.shape, const BeamShape(borderWidth: 2));
      expect(beam.timing, const BeamTiming(speed: 2));
    });

    testWidgets('is translucent to hit testing', (tester) async {
      await tester.pumpWidget(press());
      final listener = tester.widget<Listener>(
        find
            .descendant(
              of: find.byType(BeamPress),
              matching: find.byType(Listener),
            )
            .first,
      );
      expect(listener.behavior, HitTestBehavior.translucent);
    });

    testWidgets('describes itself for the inspector', (tester) async {
      await tester.pumpWidget(press(onTap: () {}));
      final description = tester
          .widget<BeamPress>(find.byType(BeamPress))
          .toDiagnosticsNode()
          .toStringDeep();
      expect(description, contains('tappable'));
      expect(description, contains('effect: BeamEffect.pulse()'));
    });
  });
}
