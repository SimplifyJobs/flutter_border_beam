import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/render/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

double _travel(WidgetTester tester) {
  final painter = _painter(tester);
  return painter.resolver
      .sample(painter.clock.elapsedSeconds, 1)
      .travelProgress;
}

/// The playback rate: `BeamTiming.speed`, a controller's `speed`, and a live
/// `speedListenable`, which win in reverse order; reduced motion's quarter
/// rate on top of whichever is in force; and a rate change riding through
/// without re-resolving the beam or moving its timeline.
void main() {
  group('timing.speed', () {
    testWidgets('the default rate is real time', (tester) async {
      await tester.pumpWidget(
        _host(const BorderBeam(child: SizedBox.expand())),
      );
      final clock = _clock(tester);
      expect(clock.speed, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(clock.elapsedSeconds, closeTo(0.5, 1e-9));
    });

    testWidgets('speed 2 advances the timeline at twice wall time', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam(
            timing: BeamTiming(speed: 2),
            child: SizedBox.expand(),
          ),
        ),
      );
      final clock = _clock(tester);
      expect(clock.speed, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(clock.elapsedSeconds, closeTo(1, 1e-9));
    });

    testWidgets('a rate change neither moves the timeline nor re-resolves', (
      tester,
    ) async {
      Widget build(double speed) => _host(
        BorderBeam(
          timing: BeamTiming(speed: speed),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final before = _painter(tester);
      final travel = _travel(tester);
      expect(before.clock.elapsedSeconds, closeTo(1, 1e-9));

      await tester.pumpWidget(build(0.5));
      final after = _painter(tester);
      expect(after.clock.speed, 0.5);
      expect(after.clock.elapsedSeconds, closeTo(1, 1e-9));
      expect(_travel(tester), closeTo(travel, 1e-9), reason: 'no snap');
      expect(
        identical(before.config, after.config),
        isTrue,
        reason: 'the rate is applied to the clock, never painted',
      );
      expect(identical(before.resolver, after.resolver), isTrue);

      await tester.pump(const Duration(seconds: 1));
      expect(after.clock.elapsedSeconds, closeTo(1.5, 1e-9));
    });

    testWidgets('a BorderBeamTheme speed is inherited; the widget wins', (
      tester,
    ) async {
      Widget build(BeamTiming? timing) => _host(
        BorderBeamTheme(
          data: const BorderBeamThemeData(timing: BeamTiming(speed: 3)),
          child: BorderBeam(timing: timing, child: const SizedBox.expand()),
        ),
      );

      await tester.pumpWidget(build(null));
      expect(_clock(tester).speed, 3);
      await tester.pumpWidget(build(const BeamTiming(speed: 0.25)));
      expect(_clock(tester).speed, 0.25);
    });
  });

  group('precedence', () {
    testWidgets('a controller replaces the timing speed', (tester) async {
      final controller = BorderBeamController()..speed = 4;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(
            controller: controller,
            timing: const BeamTiming(speed: 0.5),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final clock = _clock(tester);
      expect(clock.speed, 4);

      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(clock.elapsedSeconds, closeTo(1, 1e-9));

      controller.speed = 2;
      expect(clock.speed, 2, reason: 'a live controller change lands at once');

      // Rejected outright, not only by a debug assertion, and the rate in
      // force is left as it was.
      for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => controller.speed = bad, throwsArgumentError);
      }
      expect(controller.speed, 2);
      expect(clock.speed, 2);
    });

    testWidgets('a rebuild does not restore the timing speed over it', (
      tester,
    ) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(BeamColors colors) => _host(
        BorderBeam(
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

    testWidgets('speedListenable wins over the timing speed', (tester) async {
      final speed = ValueNotifier<double>(3);
      addTearDown(speed.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(
            timing: const BeamTiming(speed: 0.5),
            speedListenable: speed,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(_clock(tester).speed, 3);
    });

    testWidgets('speedListenable wins over a controller', (tester) async {
      final controller = BorderBeamController()..speed = 4;
      addTearDown(controller.dispose);
      final speed = ValueNotifier<double>(2);
      addTearDown(speed.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(
            controller: controller,
            speedListenable: speed,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(_clock(tester).speed, 2);
      speed.value = 3;
      expect(_clock(tester).speed, 3);
    });

    testWidgets(
      'a controller speed change does not override a speedListenable',
      (tester) async {
        final controller = BorderBeamController();
        addTearDown(controller.dispose);
        final speed = ValueNotifier<double>(2);
        addTearDown(speed.dispose);
        await tester.pumpWidget(
          _host(
            BorderBeam(
              controller: controller,
              speedListenable: speed,
              child: const SizedBox.expand(),
            ),
          ),
        );
        controller.speed = 8;
        expect(
          _clock(tester).speed,
          2,
          reason: 'the listenable wins while it is set',
        );
      },
    );

    testWidgets('dropping each source hands the rate down the chain', (
      tester,
    ) async {
      final controller = BorderBeamController()..speed = 4;
      addTearDown(controller.dispose);
      final speed = ValueNotifier<double>(2);
      addTearDown(speed.dispose);
      Widget build({
        BorderBeamController? controller,
        ValueNotifier<double>? speed,
      }) => _host(
        BorderBeam(
          controller: controller,
          speedListenable: speed,
          timing: const BeamTiming(speed: 0.5),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(controller: controller, speed: speed));
      expect(_clock(tester).speed, 2);

      await tester.pumpWidget(build(controller: controller));
      expect(_clock(tester).speed, 4);
      speed.value = 9;
      expect(_clock(tester).speed, 4, reason: 'the old listener is gone');

      await tester.pumpWidget(build());
      expect(_clock(tester).speed, 0.5);
    });
  });

  group('speedListenable', () {
    testWidgets('drives the rate live, without a rebuild or a snap', (
      tester,
    ) async {
      final speed = ValueNotifier<double>(2);
      addTearDown(speed.dispose);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              builds++;
              return BorderBeam(
                speedListenable: speed,
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final painter = _painter(tester);
      expect(painter.clock.elapsedSeconds, closeTo(1, 1e-9));
      final travel = _travel(tester);

      speed.value = 0.5;
      await tester.pump();
      expect(painter.clock.speed, 0.5);
      expect(painter.clock.elapsedSeconds, closeTo(1, 1e-9));
      expect(_travel(tester), closeTo(travel, 1e-9));
      await tester.pump(const Duration(seconds: 1));
      expect(painter.clock.elapsedSeconds, closeTo(1.5, 1e-9));

      expect(builds, 1);
      expect(identical(_painter(tester).config, painter.config), isTrue);
    });

    testWidgets('a swap moves the listener across', (tester) async {
      final first = ValueNotifier<double>(2);
      final second = ValueNotifier<double>(4);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget build(ValueNotifier<double> speed) => _host(
        BorderBeam(speedListenable: speed, child: const SizedBox.expand()),
      );

      await tester.pumpWidget(build(first));
      await tester.pumpWidget(build(second));
      expect(_clock(tester).speed, 4);

      first.value = 9;
      expect(_clock(tester).speed, 4, reason: 'the old listener is gone');
      second.value = 0.5;
      expect(_clock(tester).speed, 0.5);
    });
  });

  group('reduced motion slow', () {
    Widget slow(Widget beam) => _host(disableAnimations: true, beam);

    testWidgets('quarters the timing speed and restores it after', (
      tester,
    ) async {
      Widget build({required bool reduced}) => _host(
        disableAnimations: reduced,
        const BorderBeam(
          timing: BeamTiming(speed: 2),
          playback: BeamPlayback(reducedMotion: BeamReducedMotion.slow),
          child: SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(reduced: true));
      final clock = _clock(tester);
      expect(clock.speed, 0.5);
      await tester.pumpWidget(build(reduced: false));
      expect(clock.speed, 2);
      await tester.pumpWidget(build(reduced: true));
      expect(clock.speed, 0.5);
    });

    testWidgets('quarters a speedListenable, live', (tester) async {
      final speed = ValueNotifier<double>(2);
      addTearDown(speed.dispose);
      await tester.pumpWidget(
        slow(
          BorderBeam(
            speedListenable: speed,
            playback: const BeamPlayback(reducedMotion: BeamReducedMotion.slow),
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(_clock(tester).speed, 0.5);
      speed.value = 4;
      expect(_clock(tester).speed, 1);
    });

    testWidgets('quarters the speed a controller had when it attached', (
      tester,
    ) async {
      final controller = BorderBeamController()..speed = 2;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        slow(
          BorderBeam(
            controller: controller,
            playback: const BeamPlayback(reducedMotion: BeamReducedMotion.slow),
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(_clock(tester).speed, 0.5);
    });

    testWidgets('quarters a live controller speed change', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        slow(
          BorderBeam(
            controller: controller,
            playback: const BeamPlayback(reducedMotion: BeamReducedMotion.slow),
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.speed = 4;
      expect(_clock(tester).speed, 1);
    });
  });

  group('under a BeamSync', () {
    testWidgets('a member leaves the rate to the group', (tester) async {
      final speed = ValueNotifier<double>(9);
      addTearDown(speed.dispose);
      await tester.pumpWidget(
        _host(
          BeamSync(
            speed: 3,
            child: BorderBeam(
              timing: const BeamTiming(speed: 0.5),
              speedListenable: speed,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      final clock = _clock(tester);
      expect(clock.speed, 3);
      speed.value = 7;
      expect(clock.speed, 3, reason: "a member's listenable is ignored");

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(clock.elapsedSeconds, closeTo(0.6, 1e-9));
    });

    testWidgets('a group speed change does not move the timeline', (
      tester,
    ) async {
      Widget build(double speed) => _host(
        BeamSync(
          speed: speed,
          child: const BorderBeam(child: SizedBox()),
        ),
      );

      await tester.pumpWidget(build(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final clock = _clock(tester);
      expect(clock.elapsedSeconds, closeTo(0.6, 1e-9));

      await tester.pumpWidget(build(0.5));
      expect(clock.speed, 0.5);
      expect(clock.elapsedSeconds, closeTo(0.6, 1e-9));
      await tester.pump(const Duration(milliseconds: 200));
      expect(clock.elapsedSeconds, closeTo(0.7, 1e-9));

      await tester.pumpWidget(_host(const SizedBox()));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
