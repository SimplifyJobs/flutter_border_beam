import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: app!,
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

void main() {
  testWidgets('renders child and animates by default', (tester) async {
    await tester.pumpWidget(
      _host(const BorderBeam.rotate(child: Text('content'))),
    );
    expect(find.text('content'), findsOneWidget);
    // The beam is animating: frames keep being scheduled.
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('onActivate fires when the fade-in completes', (tester) async {
    var activated = 0;
    await tester.pumpWidget(
      _host(
        BorderBeam.rotate(
          onActivate: () => activated++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(activated, 1);
  });

  testWidgets('active: false stays idle until toggled', (tester) async {
    var activated = 0;
    var deactivated = 0;
    Widget build(bool active) => _host(
      BorderBeam.rotate(
        active: active,
        onActivate: () => activated++,
        onDeactivate: () => deactivated++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(seconds: 1));
    expect(activated, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(build(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(activated, 1);

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 600));
    expect(deactivated, 1);
    // Fade-out finished: animation halts.
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('startAfter delays the start', (tester) async {
    var activated = 0;
    await tester.pumpWidget(
      _host(
        BorderBeam.rotate(
          playback: const BeamPlayback(startAfter: Duration(seconds: 2)),
          onActivate: () => activated++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(activated, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(activated, 1);
  });

  testWidgets('duration bounds total play time', (tester) async {
    var deactivated = 0;
    await tester.pumpWidget(
      _host(
        BorderBeam.rotate(
          playback: const BeamPlayback(duration: Duration(seconds: 2)),
          onDeactivate: () => deactivated++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(deactivated, 0);
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(deactivated, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('autoPlay: false never starts by itself', (tester) async {
    await tester.pumpWidget(
      _host(
        const BorderBeam.pulseInside(
          playback: BeamPlayback(autoPlay: false),
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion paints a static frame without animating', (
    tester,
  ) async {
    var activated = 0;
    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        BorderBeam.rotate(
          onActivate: () => activated++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(activated, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TickerMode disabled pauses the beam', (tester) async {
    await tester.pumpWidget(
      _host(
        const TickerMode(
          enabled: false,
          child: BorderBeam.rotate(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  group('controller', () {
    testWidgets('asserts when startAfter is set with a controller', (
      tester,
    ) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await pumpExpectingAssertion(
        tester,
        _host(
          BorderBeam.rotate(
            controller: controller,
            playback: const BeamPlayback(startAfter: Duration(seconds: 1)),
            child: const SizedBox.expand(),
          ),
        ),
        message: 'When a BorderBeamController is attached it owns playback',
      );
    });

    testWidgets('asserts when duration is set with a controller', (
      tester,
    ) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await pumpExpectingAssertion(
        tester,
        _host(
          BorderBeam.rotate(
            controller: controller,
            playback: const BeamPlayback(duration: Duration(seconds: 1)),
            child: const SizedBox.expand(),
          ),
        ),
        message: 'When a BorderBeamController is attached it owns playback',
      );
    });

    testWidgets('controller owns playback end to end', (tester) async {
      final controller = BorderBeamController();
      var activated = 0;
      var deactivated = 0;
      await tester.pumpWidget(
        _host(
          BorderBeam.pulseOutside(
            controller: controller,
            onActivate: () => activated++,
            onDeactivate: () => deactivated++,
            child: const ColoredBox(color: Color(0xFF1D1D1D)),
          ),
        ),
      );
      // With a controller the beam starts hidden, despite active default.
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.isActive, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      controller.start();
      expect(controller.isActive, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(activated, 1);
      expect(controller.isRunning, isTrue);

      controller.pause();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isRunning, isFalse);
      expect(controller.isActive, isTrue, reason: 'paused but still visible');
      expect(tester.binding.hasScheduledFrame, isFalse);

      controller.resume();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isRunning, isTrue);

      controller.speed = 3;
      expect(controller.speed, 3);

      controller.stop();
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);
      expect(controller.isActive, isFalse);
      expect(controller.isRunning, isFalse);
    });

    testWidgets('detaches cleanly on dispose', (tester) async {
      final controller = BorderBeamController();
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(controller.isAttached, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(controller.isAttached, isFalse);
      // Controls on a detached controller are safe no-ops.
      controller.start();
      controller.stop();
    });
  });
}
