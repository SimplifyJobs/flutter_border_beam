import 'dart:math' as math;
import 'dart:ui' as ui;

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

/// Whether the painter leaves a non-transparent pixel in a 350x140 box.
///
/// Rasterizing is real async work, so it runs outside the fake clock.
Future<bool> _paintsPixels(WidgetTester tester, BeamPainter painter) async {
  const size = ui.Size(350, 140);
  final painted = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
      if (bytes.getUint8(i) != 0) return true;
    }
    return false;
  });
  return painted!;
}

/// The three ways something other than the clock moves the beam — a driven
/// [BorderBeam.progress], a [BorderBeam.follow] pointer, and the live
/// strength/speed listenables — plus the childless overlay constructor.
void main() {
  group('progress', () {
    testWidgets('drives the sweep from the value', (tester) async {
      await tester.pumpWidget(
        _host(const BorderBeam.rotate(progress: 0.25, child: SizedBox())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final painter = _painter(tester);
      expect(painter.progress?.value, 0.25);
      expect(
        painter.resolver
            .sample(painter.clock.elapsedSeconds, 1, progress: 0.25)
            .angleRadians,
        closeTo(math.pi / 2, 1e-9),
      );
    });

    testWidgets('changing it does not re-resolve the config', (tester) async {
      Widget build(double progress) =>
          _host(BorderBeam.rotate(progress: progress, child: const SizedBox()));

      await tester.pumpWidget(build(0.1));
      final before = _painter(tester);
      await tester.pumpWidget(build(0.9));
      final after = _painter(tester);
      expect(identical(before.config, after.config), isTrue);
      expect(identical(before.resolver, after.resolver), isTrue);
      expect(after.progress?.value, 0.9);
    });

    testWidgets('clamps out-of-range values', (tester) async {
      await tester.pumpWidget(
        _host(const BorderBeam.rotate(progress: 1.7, child: SizedBox())),
      );
      expect(_painter(tester).progress?.value, 1);
    });

    testWidgets('the clock still runs underneath', (tester) async {
      await tester.pumpWidget(
        _host(const BorderBeam.line(progress: 0.5, child: SizedBox())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final painter = _painter(tester);
      expect(painter.clock.isRunning, isTrue);
      final early = painter.resolver.sample(0.7, 1, progress: 0.5);
      final late = painter.resolver.sample(3.7, 1, progress: 0.5);
      expect(early.lineX, closeTo(late.lineX, 1e-9));
      expect(early.hueDegrees, isNot(closeTo(late.hueDegrees, 1e-6)));
    });

    testWidgets('null hands the travel back to the clock', (tester) async {
      Widget build(double? progress) =>
          _host(BorderBeam.rotate(progress: progress, child: const SizedBox()));

      await tester.pumpWidget(build(0.25));
      await tester.pumpWidget(build(null));
      expect(_painter(tester).progress?.value, isNull);
    });
  });

  group('follow', () {
    testWidgets('eases the sweep toward the pointer', (tester) async {
      Widget build(Offset? follow) =>
          _host(BorderBeam.rotate(follow: follow, child: const SizedBox()));

      await tester.pumpWidget(build(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // The right edge of the box: a quarter of the way round from 12
      // o'clock.
      await tester.pumpWidget(build(const Offset(1, 0.5)));
      final painter = _painter(tester);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final part = painter.progress?.value;
      expect(part, isNotNull);
      expect(
        part,
        isNot(closeTo(0.25, 0.005)),
        reason: 'the beam eases rather than snapping',
      );

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(painter.progress?.value, closeTo(0.25, 0.01));
    });

    testWidgets('takes the short way round', (tester) async {
      Widget build(Offset? follow) =>
          _host(BorderBeam.rotate(follow: follow, child: const SizedBox()));

      await tester.pumpWidget(build(null));
      await tester.pump();
      // 100ms into the 1.96s cycle: the beam is just past 12 o'clock.
      await tester.pump(const Duration(milliseconds: 100));
      // The left edge is progress 0.75 — a short hop backwards through 0,
      // not three quarters of a lap forwards.
      await tester.pumpWidget(build(const Offset(0, 0.5)));
      final painter = _painter(tester);
      await tester.pump(const Duration(milliseconds: 16));
      var previous = painter.progress!.value!;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final now = painter.progress!.value!;
        final step = ((now - previous) + 0.5) % 1.0 - 0.5;
        expect(
          step,
          lessThanOrEqualTo(1e-9),
          reason: 'every step runs backwards toward the target',
        );
        previous = now;
      }
      expect(previous, closeTo(0.75, 0.01));
    });

    testWidgets('releasing resumes from where the pointer left it', (
      tester,
    ) async {
      Widget build(Offset? follow) =>
          _host(BorderBeam.rotate(follow: follow, child: const SizedBox()));

      await tester.pumpWidget(build(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpWidget(build(const Offset(1, 0.5)));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final painter = _painter(tester);
      final held = painter.progress!.value!;

      await tester.pumpWidget(build(null));
      expect(painter.progress?.value, isNull);
      final resumed = painter.resolver
          .sample(painter.clock.elapsedSeconds, 1)
          .travelProgress;
      expect(
        resumed,
        closeTo(held, 1e-6),
        reason: 'the timed sweep picks up where the follow ended',
      );
      expect(painter.resolver.travelTimeOffset, isNot(0));

      // And it keeps travelling from there.
      await tester.pump(const Duration(milliseconds: 100));
      final later = painter.resolver
          .sample(painter.clock.elapsedSeconds, 1)
          .travelProgress;
      expect(later, greaterThan(resumed));
    });

    testWidgets('the line variant follows the axis it travels', (tester) async {
      Widget build(Offset? follow) =>
          _host(BorderBeam.line(follow: follow, child: const SizedBox()));

      await tester.pumpWidget(build(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpWidget(build(const Offset(0.8, 0.2)));
      final painter = _painter(tester);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(painter.progress?.value, closeTo(0.8, 0.01));
    });

    testWidgets('the pulse variants have no travel to steer', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.pulseInside(
            follow: Offset(1, 0.5),
            child: SizedBox(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_painter(tester).progress?.value, isNull);
    });

    testWidgets('an explicit progress wins over it', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            progress: 0.5,
            follow: Offset(1, 0.5),
            child: SizedBox(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_painter(tester).progress?.value, 0.5);
    });
  });

  group('strengthListenable', () {
    testWidgets('scales the painted layers without a rebuild', (tester) async {
      final strength = ValueNotifier<double>(1);
      addTearDown(strength.dispose);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              builds++;
              return BorderBeam.rotate(
                strengthListenable: strength,
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final painter = _painter(tester);
      expect(await _paintsPixels(tester, painter), isTrue);
      expect(builds, 1);

      strength.value = 0;
      await tester.pump();
      expect(
        await _paintsPixels(tester, _painter(tester)),
        isFalse,
        reason: 'a strength of 0 suppresses every layer',
      );
      expect(builds, 1, reason: 'the value never goes through a rebuild');
      expect(identical(_painter(tester).config, painter.config), isTrue);
    });

    testWidgets('reaches the painter as the listenable itself', (tester) async {
      final strength = ValueNotifier<double>(0.4);
      addTearDown(strength.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            strengthListenable: strength,
            child: const SizedBox(),
          ),
        ),
      );
      expect(identical(_painter(tester).strength, strength), isTrue);
    });
  });

  group('speedListenable', () {
    testWidgets('drives the clock rate without a rebuild', (tester) async {
      final speed = ValueNotifier<double>(2);
      addTearDown(speed.dispose);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              builds++;
              return BorderBeam.rotate(
                speedListenable: speed,
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
      final clock = _clock(tester);
      expect(clock.speed, 2);

      speed.value = 0.5;
      await tester.pump();
      expect(clock.speed, 0.5);
      expect(builds, 1);
    });

    testWidgets('wins over the timing speed', (tester) async {
      final speed = ValueNotifier<double>(3);
      addTearDown(speed.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            timing: const BeamTiming(speed: 0.5),
            speedListenable: speed,
            child: const SizedBox(),
          ),
        ),
      );
      expect(_clock(tester).speed, 3);
    });

    testWidgets('a swap moves the listener across', (tester) async {
      final first = ValueNotifier<double>(2);
      final second = ValueNotifier<double>(4);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget build(ValueNotifier<double> speed) => _host(
        BorderBeam.rotate(speedListenable: speed, child: const SizedBox()),
      );

      await tester.pumpWidget(build(first));
      await tester.pumpWidget(build(second));
      expect(_clock(tester).speed, 4);

      first.value = 9;
      await tester.pump();
      expect(_clock(tester).speed, 4, reason: 'the old listener is gone');
      second.value = 0.5;
      await tester.pump();
      expect(_clock(tester).speed, 0.5);
    });
  });

  group('BorderBeam.overlay', () {
    testWidgets('fills its parent in a Stack and paints', (tester) async {
      await tester.pumpWidget(
        _host(
          const Stack(
            children: [
              Center(child: Text('content')),
              Positioned.fill(child: BorderBeam.overlay(borderRadius: 16)),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('content'), findsOneWidget);
      expect(tester.getSize(find.byType(BorderBeam)), const Size(350, 140));
      expect(await _paintsPixels(tester, _painter(tester)), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('takes the same options as the generic constructor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Stack(
            children: [
              Positioned.fill(
                child: BorderBeam.overlay(
                  variant: BeamVariant.line,
                  colors: BeamColors.ocean,
                  progress: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
      final painter = _painter(tester);
      expect(painter.config.variant, BeamVariant.line);
      expect(painter.progress?.value, 0.3);
    });
  });
}
