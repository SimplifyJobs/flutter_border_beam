import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lifecycle coverage for the widget's one-ticker-per-beam contract: every
/// path that ends a beam — disposal mid-fade, a variant swap that rebuilds
/// the clock, `TickerMode`, controller detach — must leave no scheduled
/// frame callback behind.
void main() {
  Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: app!,
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: 350, height: 140, child: child)),
    ),
  );

  Widget beamFor(
    BeamVariant variant, {
    bool active = true,
    Widget child = const SizedBox.expand(),
    VoidCallback? onActivate,
    BorderBeamController? controller,
  }) => switch (variant) {
    BeamVariant.rotate => BorderBeam.rotate(
      active: active,
      onActivate: onActivate,
      controller: controller,
      child: child,
    ),
    BeamVariant.small => BorderBeam.small(
      active: active,
      onActivate: onActivate,
      controller: controller,
      child: child,
    ),
    BeamVariant.line => BorderBeam.line(
      active: active,
      onActivate: onActivate,
      controller: controller,
      child: child,
    ),
    BeamVariant.pulseInside => BorderBeam.pulseInside(
      active: active,
      onActivate: onActivate,
      controller: controller,
      child: child,
    ),
    BeamVariant.pulseOutside => BorderBeam.pulseOutside(
      active: active,
      onActivate: onActivate,
      controller: controller,
      child: child,
    ),
  };

  group('disposal', () {
    // Pulse variants build their clock with an fps cap, so the tick path
    // differs per family — every variant is checked.
    for (final variant in BeamVariant.values) {
      testWidgets('$variant disposed mid fade-in leaves no ticker', (
        tester,
      ) async {
        await tester.pumpWidget(host(beamFor(variant)));
        await tester.pump();
        // 200ms into the 600ms fade-in.
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.binding.transientCallbackCount,
          greaterThan(0),
          reason: 'the beam should be ticking here',
        );

        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('$variant disposed mid fade-out leaves no ticker', (
        tester,
      ) async {
        await tester.pumpWidget(host(beamFor(variant)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        await tester.pumpWidget(host(beamFor(variant, active: false)));
        // 200ms into the 500ms fade-out.
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.binding.transientCallbackCount, greaterThan(0));

        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  });

  testWidgets('a variant swap rebuilds the clock without leaking the old one', (
    tester,
  ) async {
    // rotate runs uncapped, pulseInside caps at the source's ~30fps driver:
    // the swap must replace the clock, not keep two of them running.
    await tester.pumpWidget(host(beamFor(BeamVariant.rotate)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(host(beamFor(BeamVariant.pulseInside)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(
      tester.binding.transientCallbackCount,
      1,
      reason: 'exactly one clock ticks after the swap',
    );

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('TickerMode pauses frames and resumes them', (tester) async {
    var activated = 0;
    Widget build(bool enabled) => host(
      TickerMode(
        enabled: enabled,
        child: beamFor(BeamVariant.rotate, onActivate: () => activated++),
      ),
    );

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(activated, 0, reason: 'a muted clock never completes its fade-in');

    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    expect(activated, 1);
    // Still animating after the fade finished.
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('reduced-motion static frames dispose without a ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(beamFor(BeamVariant.rotate), disableAnimations: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a controller outliving its beam is an inert no-op', (
    tester,
  ) async {
    final controller = BorderBeamController();
    await tester.pumpWidget(
      host(beamFor(BeamVariant.rotate, controller: controller)),
    );
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.isAttached, isTrue);
    expect(controller.isRunning, isTrue);

    // Disposed mid fade-in, with the controller still referenced.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(controller.isAttached, isFalse);
    expect(controller.isActive, isFalse);
    expect(controller.isRunning, isFalse);

    controller.start();
    controller.resume();
    controller.seek(const Duration(seconds: 1));
    controller.speed = 2;
    controller.stop();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('replacing the child keeps the beam painting', (tester) async {
    Widget build(String label) =>
        host(beamFor(BeamVariant.rotate, child: Text(label)));

    await tester.pumpWidget(build('before'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.pumpWidget(build('after'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('before'), findsNothing);
    expect(find.text('after'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The clock survives a child swap: no restart, no stall.
    expect(tester.binding.hasScheduledFrame, isTrue);

    // The child keeps its own repaint boundary, so beam frames never
    // re-rasterize it: one boundary around the CustomPaint, one around the
    // child itself.
    expect(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(RepaintBoundary),
      ),
      findsNWidgets(2),
    );
    expect(
      find.ancestor(
        of: find.text('after'),
        matching: find.byType(RepaintBoundary),
      ),
      findsAtLeastNWidgets(2),
    );
  });
}
