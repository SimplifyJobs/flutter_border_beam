import 'package:flutter/gestures.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/render/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// [BeamHover] turns a [MouseRegion] into two values on the [BorderBeam] it
/// wraps: `active` (lit while hovered, held for `holdAfterExit` after) and
/// `follow` (the cursor in normalized box coordinates).
void main() {
  const size = Size(200, 80);

  BorderBeam beamOf(WidgetTester tester) =>
      tester.widget<BorderBeam>(find.byType(BorderBeam));

  BeamPainter painterOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find
                    .descendant(
                      of: find.byType(BorderBeam),
                      matching: find.byType(CustomPaint),
                    )
                    .first,
              )
              .foregroundPainter!
          as BeamPainter;

  Widget scene({
    bool followPointer = true,
    Duration holdAfterExit = const Duration(milliseconds: 300),
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: BeamHover(
          followPointer: followPointer,
          holdAfterExit: holdAfterExit,
          child: SizedBox.fromSize(size: size),
        ),
      ),
    ),
  );

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    return gesture;
  }

  // A point well clear of the hovered box.
  const away = Offset(5, 5);

  group('hover tracking', () {
    testWidgets('entering lights the beam and follows the cursor', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      expect(beamOf(tester).active, isFalse);
      expect(beamOf(tester).follow, isNull);
      expect(tester.binding.transientCallbackCount, 0);

      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();

      expect(beamOf(tester).active, isTrue);
      expect(beamOf(tester).follow, const Offset(0.5, 0.5));
    });

    testWidgets('moving inside re-aims the follow point', (tester) async {
      await tester.pumpWidget(scene());
      final gesture = await mouse(tester);
      final topLeft = tester.getTopLeft(find.byType(BeamHover));

      await gesture.moveTo(topLeft + const Offset(50, 20));
      await tester.pump();
      expect(beamOf(tester).follow, const Offset(0.25, 0.25));

      await gesture.moveTo(topLeft + const Offset(150, 60));
      await tester.pump();
      expect(beamOf(tester).follow, const Offset(0.75, 0.75));
    });

    testWidgets('the follow point is normalized to 0–1 on both axes', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      final gesture = await mouse(tester);
      final rect = tester.getRect(find.byType(BeamHover));

      for (final point in [
        rect.topLeft,
        rect.bottomRight - const Offset(0.5, 0.5),
        rect.centerLeft,
        rect.topCenter,
      ]) {
        await gesture.moveTo(point);
        await tester.pump();
        final follow = beamOf(tester).follow!;
        expect(follow.dx, inInclusiveRange(0, 1), reason: '$point');
        expect(follow.dy, inInclusiveRange(0, 1), reason: '$point');
      }
      await gesture.moveTo(rect.topLeft);
      await tester.pump();
      expect(beamOf(tester).follow, Offset.zero);
    });

    testWidgets('the follow reaches the painter as a driven sweep', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      expect(painterOf(tester).progress?.value, isNull);

      final gesture = await mouse(tester);
      // Just inside the right edge's centre: a quarter of the way round from
      // top-centre, where the sweep settles once it has eased over.
      final rect = tester.getRect(find.byType(BeamHover));
      await gesture.moveTo(rect.centerRight - const Offset(1, 0));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final early = painterOf(tester).progress?.value;
      expect(early, isNotNull);
      expect(early, inInclusiveRange(0, 0.25));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(painterOf(tester).progress?.value, closeTo(0.25, 0.01));

      // Leaving hands the sweep straight back to the clock.
      await gesture.moveTo(away);
      await tester.pump();
      expect(painterOf(tester).progress?.value, isNull);
    });

    testWidgets('followPointer false lights without ever steering', (
      tester,
    ) async {
      await tester.pumpWidget(scene(followPointer: false));
      final gesture = await mouse(tester);
      final rect = tester.getRect(find.byType(BeamHover));

      for (final point in [rect.center, rect.topLeft, rect.centerRight]) {
        await gesture.moveTo(point);
        await tester.pump();
        expect(beamOf(tester).active, isTrue);
        expect(beamOf(tester).follow, isNull, reason: '$point');
      }
      await gesture.moveTo(away);
      await tester.pump();
      expect(beamOf(tester).follow, isNull);
    });

    testWidgets('turning followPointer off mid-hover releases the follow', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();
      expect(beamOf(tester).follow, isNotNull);

      await tester.pumpWidget(scene(followPointer: false));
      expect(beamOf(tester).follow, isNull);
      expect(beamOf(tester).active, isTrue);
    });
  });

  group('exit', () {
    testWidgets('releases the follow at once and fades out after the hold', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();

      await gesture.moveTo(away);
      await tester.pump();
      expect(beamOf(tester).follow, isNull, reason: 'released on exit');
      expect(beamOf(tester).active, isTrue, reason: 'still inside the hold');

      await tester.pump(const Duration(milliseconds: 250));
      expect(beamOf(tester).active, isTrue);

      await tester.pump(const Duration(milliseconds: 100));
      expect(beamOf(tester).active, isFalse);
    });

    testWidgets('a zero hold deactivates on exit', (tester) async {
      await tester.pumpWidget(scene(holdAfterExit: Duration.zero));
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();

      await gesture.moveTo(away);
      await tester.pump();
      expect(beamOf(tester).active, isFalse);
      expect(beamOf(tester).follow, isNull);
    });

    testWidgets('re-entering within the hold cancels the fade', (tester) async {
      await tester.pumpWidget(scene());
      final gesture = await mouse(tester);
      final center = tester.getCenter(find.byType(BeamHover));
      await gesture.moveTo(center);
      await tester.pump();

      await gesture.moveTo(away);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(center);
      await tester.pump();
      // Well past where the first exit's hold would have ended.
      await tester.pump(const Duration(milliseconds: 400));

      expect(beamOf(tester).active, isTrue);
      expect(beamOf(tester).follow, const Offset(0.5, 0.5));
    });

    testWidgets('the beam winds down to no ticker after the fade', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await gesture.moveTo(away);
      await tester.pump();
      // Past the 300ms hold, then past the beam's fade-out
      // (BeamClock.fadeOutSeconds), with room to spare.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(beamOf(tester).active, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('unmounting during the hold cancels the timer', (tester) async {
      await tester.pumpWidget(scene());
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await gesture.moveTo(away);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
      // Ending inside the hold: a timer dispose failed to cancel fails the
      // binding's no-pending-timers invariant.
    });
  });

  group('pass-through', () {
    testWidgets('defaults to a rotating beam', (tester) async {
      await tester.pumpWidget(scene());
      expect(beamOf(tester).effect, const BeamEffect.rotate());
    });

    testWidgets('hands its effect, style, shape and timing to the beam', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BeamHover(
                effect: BeamEffect.rotate(count: 2, comet: true),
                colors: BeamColors.sunset,
                borderRadius: 18,
                style: BeamStyle(strength: 0.7),
                shape: BeamShape(borderWidth: 2),
                timing: BeamTiming(speed: 2),
                child: SizedBox(width: 200, height: 80),
              ),
            ),
          ),
        ),
      );

      final beam = beamOf(tester);
      expect(beam.effect, const BeamEffect.rotate(count: 2, comet: true));
      expect(beam.colors, BeamColors.sunset);
      expect(beam.borderRadius, 18);
      expect(beam.style, const BeamStyle(strength: 0.7));
      expect(beam.shape, const BeamShape(borderWidth: 2));
      expect(beam.timing, const BeamTiming(speed: 2));
    });

    testWidgets('describes itself for the inspector', (tester) async {
      await tester.pumpWidget(scene(followPointer: false));
      final description = tester
          .widget<BeamHover>(find.byType(BeamHover))
          .toDiagnosticsNode()
          .toStringDeep();
      expect(description, contains('does not follow the pointer'));
      expect(description, contains('effect: BeamEffect.rotate('));
    });
  });
}
