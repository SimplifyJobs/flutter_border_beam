import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

BeamPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first;

BeamClock _clock(WidgetTester tester) => _painter(tester).clock;

/// `BeamTiming.speed` is the declarative playback rate: the beam's timeline
/// advances by `speed` seconds of animation per second of wall time. A
/// `BorderBeamController` owns the rate instead whenever one is attached.
void main() {
  testWidgets('speed 2 advances the timeline at twice wall time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BorderBeam.rotate(
          timing: BeamTiming(speed: 2),
          child: SizedBox.expand(),
        ),
      ),
    );
    final clock = _clock(tester);
    expect(clock.speed, 2);
    // The first tick after Ticker.start reports elapsed 0.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.elapsedSeconds, closeTo(1, 1e-9));
    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.elapsedSeconds, closeTo(2, 1e-9));
  });

  testWidgets('the default rate is real time', (tester) async {
    await tester.pumpWidget(
      _host(const BorderBeam.rotate(child: SizedBox.expand())),
    );
    final clock = _clock(tester);
    expect(clock.speed, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.elapsedSeconds, closeTo(0.5, 1e-9));
  });

  testWidgets('changing speed on rebuild takes effect from the next frame', (
    tester,
  ) async {
    Widget build(double speed) => _host(
      BorderBeam.rotate(
        timing: BeamTiming(speed: speed),
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final clock = _clock(tester);
    expect(clock.elapsedSeconds, closeTo(1, 1e-9));

    await tester.pumpWidget(build(0.5));
    expect(clock.speed, 0.5);
    expect(
      clock.elapsedSeconds,
      closeTo(1, 1e-9),
      reason: 'a rate change does not move the timeline',
    );
    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsedSeconds, closeTo(1.5, 1e-9));
  });

  testWidgets('changing only the speed keeps the resolved config', (
    tester,
  ) async {
    Widget build(double speed) => _host(
      BorderBeam.rotate(
        timing: BeamTiming(speed: speed),
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build(2));
    final before = _painter(tester);
    await tester.pumpWidget(build(0.5));
    final after = _painter(tester);
    expect(
      identical(before.config, after.config),
      isTrue,
      reason: 'the rate is applied to the clock, not painted',
    );
    expect(identical(before.resolver, after.resolver), isTrue);
  });

  testWidgets('changing the cycle does re-resolve the config', (tester) async {
    Widget build(Duration cycle) => _host(
      BorderBeam.rotate(
        timing: BeamTiming(cycle: cycle),
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build(const Duration(seconds: 2)));
    final before = _painter(tester);
    await tester.pumpWidget(build(const Duration(seconds: 3)));
    expect(identical(before.config, _painter(tester).config), isFalse);
  });

  testWidgets('a BorderBeamTheme speed is inherited', (tester) async {
    await tester.pumpWidget(
      _host(
        const BorderBeamTheme(
          data: BorderBeamThemeData(timing: BeamTiming(speed: 3)),
          child: BorderBeam.rotate(child: SizedBox.expand()),
        ),
      ),
    );
    final clock = _clock(tester);
    expect(clock.speed, 3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(clock.elapsedSeconds, closeTo(0.6, 1e-9));
  });

  testWidgets('a widget speed beats an inherited one', (tester) async {
    await tester.pumpWidget(
      _host(
        const BorderBeamTheme(
          data: BorderBeamThemeData(timing: BeamTiming(speed: 3)),
          child: BorderBeam.rotate(
            timing: BeamTiming(speed: 0.25),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(_clock(tester).speed, 0.25);
  });

  test('a non-positive speed asserts at the value-object boundary', () {
    final zero = double.parse('0');
    expect(
      () => BeamTiming(speed: zero),
      throwsA(
        isA<AssertionError>().having(
          (error) => error.message,
          'message',
          contains('speed must be finite and positive'),
        ),
      ),
    );
  });

  group('with a controller attached', () {
    testWidgets('the widget speed is ignored', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            controller: controller,
            timing: const BeamTiming(speed: 5),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final clock = _clock(tester);
      expect(clock.speed, 1, reason: "the controller's own rate wins");

      controller.speed = 4;
      expect(clock.speed, 4);
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(clock.elapsedSeconds, closeTo(1, 1e-9));
    });

    testWidgets('a rebuild does not restore the widget speed', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(BeamColors colors) => _host(
        BorderBeam.rotate(
          controller: controller,
          colors: colors,
          timing: const BeamTiming(speed: 5),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(BeamColors.ocean));
      controller.speed = 2;
      await tester.pumpWidget(build(BeamColors.sunset));
      expect(_clock(tester).speed, 2);
    });

    testWidgets('detaching hands the rate back to the widget', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(BorderBeamController? c) => _host(
        BorderBeam.rotate(
          controller: c,
          timing: const BeamTiming(speed: 5),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(controller));
      controller.speed = 2;
      expect(_clock(tester).speed, 2);

      await tester.pumpWidget(build(null));
      expect(_clock(tester).speed, 5);
    });
  });
}
