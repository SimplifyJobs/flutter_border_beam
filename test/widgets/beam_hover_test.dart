import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// [BeamHover] turns a [MouseRegion] into two values on the [BorderBeam] it
/// wraps: `active` (lit while hovered, held for `holdAfterExit` after) and
/// `follow` (the cursor in normalized box coordinates).
void main() {
  const size = Size(200, 80);

  BorderBeam beamOf(WidgetTester tester) =>
      tester.widget<BorderBeam>(find.byType(BorderBeam));

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

  Future<TestGesture> hoverGesture(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    return gesture;
  }

  group('hover tracking', () {
    testWidgets('entering lights the beam and follows the cursor', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      expect(beamOf(tester).active, isFalse);
      expect(beamOf(tester).follow, isNull);

      final gesture = await hoverGesture(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();

      expect(beamOf(tester).active, isTrue);
      expect(beamOf(tester).follow, const Offset(0.5, 0.5));
    });

    testWidgets('moving inside re-aims the follow point', (tester) async {
      await tester.pumpWidget(scene());
      final gesture = await hoverGesture(tester);
      final topLeft = tester.getTopLeft(find.byType(BeamHover));

      await gesture.moveTo(topLeft + const Offset(50, 20));
      await tester.pump();
      expect(beamOf(tester).follow, const Offset(0.25, 0.25));

      await gesture.moveTo(topLeft + const Offset(150, 60));
      await tester.pump();
      expect(beamOf(tester).follow, const Offset(0.75, 0.75));
    });

    testWidgets('the follow point stays inside the box at the edges', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      final gesture = await hoverGesture(tester);
      final topLeft = tester.getTopLeft(find.byType(BeamHover));

      await gesture.moveTo(topLeft);
      await tester.pump();
      final follow = beamOf(tester).follow!;
      expect(follow.dx, inInclusiveRange(0, 1));
      expect(follow.dy, inInclusiveRange(0, 1));
    });

    testWidgets('followPointer false lights without steering', (tester) async {
      await tester.pumpWidget(scene(followPointer: false));
      final gesture = await hoverGesture(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();

      expect(beamOf(tester).active, isTrue);
      expect(beamOf(tester).follow, isNull);
    });
  });

  group('exit', () {
    testWidgets('releases the follow at once and fades out after the hold', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      final gesture = await hoverGesture(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();

      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(beamOf(tester).follow, isNull, reason: 'released on exit');
      expect(beamOf(tester).active, isTrue, reason: 'still inside the hold');

      await tester.pump(const Duration(milliseconds: 250));
      expect(beamOf(tester).active, isTrue);

      await tester.pump(const Duration(milliseconds: 100));
      expect(beamOf(tester).active, isFalse);
    });

    testWidgets('re-entering within the hold keeps the beam lit', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      final gesture = await hoverGesture(tester);
      final center = tester.getCenter(find.byType(BeamHover));
      await gesture.moveTo(center);
      await tester.pump();

      await gesture.moveTo(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 400));

      expect(beamOf(tester).active, isTrue);
      expect(beamOf(tester).follow, const Offset(0.5, 0.5));
    });

    testWidgets('a zero hold fades out on exit', (tester) async {
      await tester.pumpWidget(scene(holdAfterExit: Duration.zero));
      final gesture = await hoverGesture(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();

      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(beamOf(tester).active, isFalse);
      expect(beamOf(tester).follow, isNull);
    });

    testWidgets('unmounting during the hold leaves no timer or ticker', (
      tester,
    ) async {
      await tester.pumpWidget(scene());
      final gesture = await hoverGesture(tester);
      await gesture.moveTo(tester.getCenter(find.byType(BeamHover)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));

      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('pass-through', () {
    testWidgets('hands its style, shape and timing to the beam', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BeamHover(
                variant: BeamVariant.small,
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
      expect(beam.variant, BeamVariant.small);
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
      expect(description, contains('variant: rotate'));
    });
  });
}
