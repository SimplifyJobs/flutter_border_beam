import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

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

BeamPainter _beamPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first;

// The frame the painter would draw right now.
({BeamPainter painter, BeamFramePhases phases}) _frame(WidgetTester tester) {
  final painter = _beamPainter(tester);
  return (
    painter: painter,
    phases: painter.resolver.sample(
      painter.clock.elapsedSeconds,
      painter.clock.fadeOpacity,
    ),
  );
}

void main() {
  group('cycleDuration change', () {
    testWidgets('retimes the rotate beam without a phase jump', (tester) async {
      Widget build(Duration cycle) => _host(
        BorderBeam.rotate(cycleDuration: cycle, child: const SizedBox.expand()),
      );

      await tester.pumpWidget(build(const Duration(seconds: 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final before = _frame(tester);
      expect(before.painter.clock.elapsedSeconds, closeTo(0.9, 1e-9));

      await tester.pumpWidget(build(const Duration(seconds: 4)));
      final after = _frame(tester);

      expect(
        after.painter.config.cycleSeconds,
        closeTo(4, 1e-9),
        reason: 'the new cycle is in effect',
      );
      expect(
        after.painter.clock.elapsedSeconds,
        closeTo(1.8, 1e-9),
        reason: 'elapsed time is rescaled by the cycle ratio',
      );
      expect(
        after.phases.angleRadians,
        closeTo(before.phases.angleRadians, 1e-6),
      );
      expect(after.phases.hueDegrees, closeTo(before.phases.hueDegrees, 1e-6));
    });

    testWidgets('retimes the line beam without a phase jump', (tester) async {
      Widget build(Duration cycle) => _host(
        BorderBeam.line(cycleDuration: cycle, child: const SizedBox.expand()),
      );

      await tester.pumpWidget(build(const Duration(seconds: 3)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      final before = _frame(tester);

      await tester.pumpWidget(build(const Duration(milliseconds: 1500)));
      final after = _frame(tester);

      expect(after.phases.lineX, closeTo(before.phases.lineX, 1e-6));
      expect(after.phases.lineW, closeTo(before.phases.lineW, 1e-6));
      expect(after.phases.lineH, closeTo(before.phases.lineH, 1e-6));
      expect(after.phases.spike, closeTo(before.phases.spike, 1e-6));
      expect(after.phases.edge, closeTo(before.phases.edge, 1e-6));
      expect(after.phases.hueDegrees, closeTo(before.phases.hueDegrees, 1e-6));
      expect(
        after.phases.bloomHueDegrees,
        closeTo(before.phases.bloomHueDegrees, 1e-6),
      );
    });

    testWidgets('keeps every pulse oscillator continuous', (tester) async {
      Widget build(Duration cycle) => _host(
        BorderBeam.pulseInside(
          cycleDuration: cycle,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(milliseconds: 2300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
      final before = _frame(tester);

      await tester.pumpWidget(build(const Duration(seconds: 5)));
      final after = _frame(tester);

      for (var i = 0; i < 3; i++) {
        expect(
          after.phases.pulse.bw[i],
          closeTo(before.phases.pulse.bw[i], 1e-6),
        );
        expect(
          after.phases.pulse.bh[i],
          closeTo(before.phases.pulse.bh[i], 1e-6),
        );
        expect(
          after.phases.pulse.bx[i],
          closeTo(before.phases.pulse.bx[i], 1e-6),
        );
        expect(
          after.phases.pulse.by[i],
          closeTo(before.phases.pulse.by[i], 1e-6),
        );
      }
      expect(after.phases.pulse.bgh, closeTo(before.phases.pulse.bgh, 1e-6));
      expect(
        after.phases.pulse.bopTl,
        closeTo(before.phases.pulse.bopTl, 1e-6),
      );
      expect(
        after.phases.pulse.bopBr,
        closeTo(before.phases.pulse.bopBr, 1e-6),
      );
      expect(after.phases.hueDegrees, closeTo(before.phases.hueDegrees, 1e-6));
    });

    testWidgets('keeps the fade envelope continuous mid fade-in', (
      tester,
    ) async {
      var activated = 0;
      Widget build(Duration cycle) => _host(
        BorderBeam.rotate(
          cycleDuration: cycle,
          onActivate: () => activated++,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(seconds: 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final before = _beamPainter(tester).clock;
      final opacity = before.fadeOpacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      expect(before.stage, BeamFadeStage.fadingIn);

      await tester.pumpWidget(build(const Duration(seconds: 6)));
      final after = _beamPainter(tester).clock;
      expect(after.fadeOpacity, closeTo(opacity, 1e-6));
      expect(after.stage, BeamFadeStage.fadingIn);

      // The remaining fade time is unchanged too: 0.45s left of the 0.6s
      // fade-in, not 0.45s scaled by the cycle ratio.
      await tester.pump(const Duration(milliseconds: 400));
      expect(activated, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(activated, 1);
      expect(after.fadeOpacity, 1);
    });

    testWidgets('an unchanged cycle leaves the timeline alone', (tester) async {
      Widget build(double strength) => _host(
        BorderBeam.rotate(
          strength: strength,
          cycleDuration: const Duration(seconds: 2),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpWidget(build(0.5));
      expect(_beamPainter(tester).clock.elapsedSeconds, closeTo(0.9, 1e-9));
    });
  });

  group('reduced motion', () {
    testWidgets('turning it off starts a beam that never got to start', (
      tester,
    ) async {
      Widget build(bool reduced) => _host(
        disableAnimations: reduced,
        const BorderBeam.rotate(child: SizedBox.expand()),
      );

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_beamPainter(tester).clock.isVisible, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(build(false));
      expect(_beamPainter(tester).clock.isVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(_beamPainter(tester).clock.isRunning, isTrue);
    });

    testWidgets('turning it off respects a pending startAfter delay', (
      tester,
    ) async {
      Widget build(bool reduced) => _host(
        disableAnimations: reduced,
        const BorderBeam.rotate(
          startAfter: Duration(seconds: 2),
          child: SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(build(false));
      expect(_beamPainter(tester).clock.isVisible, isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(_beamPainter(tester).clock.isVisible, isTrue);
    });

    testWidgets('toggling it on pauses and off resumes a running beam', (
      tester,
    ) async {
      Widget build(bool reduced) => _host(
        disableAnimations: reduced,
        const BorderBeam.rotate(child: SizedBox.expand()),
      );

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final clock = _beamPainter(tester).clock;
      expect(clock.isRunning, isTrue);
      final frozenAt = clock.elapsedSeconds;

      await tester.pumpWidget(build(true));
      expect(clock.isRunning, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(clock.elapsedSeconds, closeTo(frozenAt, 1e-9));
      expect(clock.isVisible, isTrue, reason: 'the frame stays on screen');

      await tester.pumpWidget(build(false));
      expect(clock.isRunning, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        clock.elapsedSeconds,
        greaterThan(frozenAt),
        reason: 'the timeline continues where it was frozen',
      );
    });

    testWidgets('turning it off does not replay a beam that already ran', (
      tester,
    ) async {
      var deactivated = 0;
      Widget build(bool reduced) => _host(
        disableAnimations: reduced,
        BorderBeam.rotate(
          duration: const Duration(seconds: 1),
          onDeactivate: () => deactivated++,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);
      expect(_beamPainter(tester).clock.isVisible, isFalse);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        _beamPainter(tester).clock.isVisible,
        isFalse,
        reason: 'its play time is spent',
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('turning it off does not resume a controller-paused beam', (
      tester,
    ) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(bool reduced) => _host(
        disableAnimations: reduced,
        BorderBeam.rotate(
          controller: controller,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(false));
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.isRunning, isTrue);
      controller.pause();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isRunning, isFalse);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        controller.isRunning,
        isFalse,
        reason: 'the controller owns the pause',
      );
      expect(controller.isActive, isTrue);
    });
  });

  group('widget updates', () {
    testWidgets('a variant swap keeps visibility and restarts the clock', (
      tester,
    ) async {
      Widget build(bool pulse) => _host(
        pulse
            ? const BorderBeam.pulseInside(child: SizedBox.expand())
            : const BorderBeam.rotate(child: SizedBox.expand()),
      );

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final first = _beamPainter(tester).clock;
      expect(first.elapsedSeconds, closeTo(0.9, 1e-9));

      await tester.pumpWidget(build(true));
      final second = _beamPainter(tester).clock;
      expect(identical(second, first), isFalse, reason: 'a fresh clock');
      expect(second.isVisible, isTrue);
      expect(second.elapsedSeconds, 0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(second.isRunning, isTrue);
    });

    testWidgets('a controller swap detaches the old and attaches the new', (
      tester,
    ) async {
      final first = BorderBeamController();
      final second = BorderBeamController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget build(BorderBeamController? controller) => _host(
        BorderBeam.rotate(
          controller: controller,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(first));
      expect(first.isAttached, isTrue);

      await tester.pumpWidget(build(second));
      expect(first.isAttached, isFalse);
      expect(second.isAttached, isTrue);

      second.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(second.isActive, isTrue);
      expect(_beamPainter(tester).clock.isVisible, isTrue);

      await tester.pumpWidget(build(null));
      expect(second.isAttached, isFalse);
    });

    testWidgets('re-activating mid fade-out resumes from the current opacity', (
      tester,
    ) async {
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

      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final clock = _beamPainter(tester).clock;
      expect(clock.stage, BeamFadeStage.fadingIn);

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 80));
      expect(clock.stage, BeamFadeStage.fadingOut);
      final mid = clock.fadeOpacity;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      final elapsed = clock.elapsedSeconds;

      await tester.pumpWidget(build(true));
      expect(clock.stage, BeamFadeStage.fadingIn);
      expect(
        clock.fadeOpacity,
        closeTo(mid, 1e-9),
        reason: 'no jump back to zero',
      );
      expect(
        clock.elapsedSeconds,
        closeTo(elapsed, 1e-9),
        reason: 'a mid-fade re-activation keeps the timeline',
      );

      await tester.pump(const Duration(milliseconds: 700));
      expect(activated, 1);
      expect(deactivated, 0);
      expect(clock.fadeOpacity, 1);
    });

    testWidgets('a colors change resolves a new config exactly once', (
      tester,
    ) async {
      Widget build(BeamColors colors) => _host(
        BorderBeam.rotate(colors: colors, child: const SizedBox.expand()),
      );

      await tester.pumpWidget(build(BeamColors.ocean));
      final ocean = _beamPainter(tester).config;

      await tester.pumpWidget(build(BeamColors.sunset));
      final sunset = _beamPainter(tester).config;
      expect(identical(sunset, ocean), isFalse);
      expect(identical(sunset.palette, BeamColors.sunset.resolve()), isTrue);

      // Rebuilding with the same colors reuses the resolved config.
      await tester.pumpWidget(build(BeamColors.sunset));
      expect(identical(_beamPainter(tester).config, sunset), isTrue);
    });
  });
}
