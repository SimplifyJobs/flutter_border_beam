import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/animation/beam_clock.dart';

import 'test_utils.dart';

/// The widget's core contract: it wraps a child it never gets in the way of,
/// paints the effect it is given, starts by itself, and hands playback over
/// wholesale to a [BorderBeamController] when one is attached.
void main() {
  // The pixel smoke test needs the shader; nothing else here reads pixels.
  setUpAll(() async {
    await BorderBeam.precache();
  });

  group('rendering', () {
    testWidgets('renders its child and animates by default', (tester) async {
      await tester.pumpWidget(
        beamHost(const BorderBeam(child: Text('content'))),
      );
      expect(find.text('content'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      final clock = beamPainterOf(tester).clock;
      expect(clock.isVisible, isTrue);
      expect(clock.isRunning, isTrue);
      expect(tester.binding.transientCallbackCount, 1, reason: 'one ticker');
    });

    testWidgets('with no effect anywhere it rotates', (tester) async {
      await tester.pumpWidget(beamHost(const BorderBeam(child: SizedBox())));
      expect(beamPainterOf(tester).config.effect, const BeamEffect.rotate());
    });

    for (final effect in BeamEffect.values) {
      testWidgets('${effect.name} reaches the painter config', (tester) async {
        await tester.pumpWidget(
          beamHost(BorderBeam(effect: effect, child: const SizedBox.expand())),
        );
        final painter = beamPainterOf(tester);
        expect(painter.config.effect, effect);
        expect(
          identical(painter.resolver.config, painter.config),
          isTrue,
          reason: 'the resolver samples the config the painter paints',
        );
      });
    }

    testWidgets('effect parameters reach the config', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            effect: BeamEffect.rotate(count: 3, comet: true),
            child: SizedBox.expand(),
          ),
        ),
      );
      final config = beamPainterOf(tester).config;
      expect(config.effect, const BeamEffect.rotate(count: 3, comet: true));
      expect(config.beamCount, 3);
    });

    testWidgets('pointer events reach the child', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        beamHost(
          BorderBeam(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      // On the border, where the light is.
      await tester.tapAt(
        tester.getTopLeft(find.byType(BorderBeam)) + const Offset(2, 2),
      );
      await tester.tap(find.byType(BorderBeam));
      expect(taps, 2);
    });

    testWidgets('the child sits behind its own repaint boundary', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(const BorderBeam(child: Text('content'))),
      );
      // One boundary around the beam, one around the child, so beam frames
      // never re-rasterize the child.
      expect(
        find.descendant(
          of: find.byType(BorderBeam),
          matching: find.byType(RepaintBoundary),
        ),
        findsNWidgets(2),
      );
      final childBoundary = find
          .ancestor(
            of: find.text('content'),
            matching: find.byType(RepaintBoundary),
          )
          .first;
      expect(
        find.descendant(of: find.byType(CustomPaint), matching: childBoundary),
        findsOneWidget,
        reason: 'the child boundary sits inside the beam painter',
      );
    });
  });

  group('BorderBeam.overlay', () {
    testWidgets('is sized by its parent and traces its bounds', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const Stack(
            children: [
              SizedBox(width: 300, height: 120, child: Text('content')),
              Positioned.fill(
                child: BorderBeam.overlay(
                  effect: BeamEffect.line(edge: BeamEdge.top),
                  colors: BeamColors.ocean,
                  borderRadius: 12,
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('content'), findsOneWidget);
      expect(tester.getSize(find.byType(BorderBeam)), const Size(350, 140));
      final painter = beamPainterOf(tester);
      expect(painter.config.effect, const BeamEffect.line(edge: BeamEdge.top));
      expect(painter.config.palette, BeamColors.ocean.resolve());
      expect(painter.config.borderRadius, BorderRadius.circular(12));
      await tester.pump(const Duration(milliseconds: 50));
      expect(painter.clock.isRunning, isTrue);
    });

    testWidgets('forwards its playback arguments', (tester) async {
      await tester.pumpWidget(
        beamHost(const BorderBeam.overlay(active: false)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('pixels', () {
    const surface = Color(0xFF101010);

    Widget card({bool active = true}) => beamHost(
      BorderBeam(
        active: active,
        child: const ColoredBox(color: surface, child: SizedBox.expand()),
      ),
    );

    testWidgets('a running beam lights pixels over its child', (tester) async {
      await tester.pumpWidget(card());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      final pixels = await beamPixels(tester);
      expect(pixels.width, 350);
      expect(pixels.height, 140);
      expect(
        pixels.countDifferentFrom(surface),
        greaterThan(100),
        reason: 'the beam paints over the child',
      );
    });

    testWidgets('an inactive beam leaves the child untouched', (tester) async {
      await tester.pumpWidget(card(active: false));
      await tester.pump(const Duration(milliseconds: 1300));
      final pixels = await beamPixels(tester);
      expect(pixels.countDifferentFrom(surface), 0);
    });
  });

  group('controller', () {
    for (final (name, playback) in [
      ('startAfter', const BeamPlayback(startAfter: Duration(seconds: 1))),
      ('duration', const BeamPlayback(duration: Duration(seconds: 1))),
    ]) {
      testWidgets('asserts when $name is set with a controller', (
        tester,
      ) async {
        final controller = BorderBeamController();
        addTearDown(controller.dispose);
        await pumpExpectingAssertion(
          tester,
          beamHost(
            BorderBeam(
              controller: controller,
              playback: playback,
              child: const SizedBox.expand(),
            ),
          ),
          message: 'When a BorderBeamController is attached it owns playback',
        );
      });
    }

    testWidgets('asserts when one controller drives two beams at once', (
      tester,
    ) async {
      // A controller starts its beam hidden, so neither beam starts a ticker
      // that could outlive the failed build.
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await pumpExpectingAssertion(
        tester,
        beamHost(
          Column(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: BorderBeam(
                    controller: controller,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
        message: 'already attached to another BorderBeam',
      );
    });

    testWidgets('owns playback end to end', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      var activated = 0;
      var deactivated = 0;
      await tester.pumpWidget(
        beamHost(
          BorderBeam(
            effect: const BeamEffect.rotate(count: 2),
            controller: controller,
            onActivate: () => activated++,
            onDeactivate: () => deactivated++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(controller.isAttached, isTrue);
      // With a controller the beam starts hidden, despite `active` defaulting
      // to true.
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.isActive, isFalse);
      expect(tester.binding.transientCallbackCount, 0);

      controller.start();
      expect(controller.isActive, isTrue);
      await tester.pump();
      await tester.pump(pastFadeIn);
      expect(activated, 1);
      expect(controller.isRunning, isTrue);

      final clock = beamPainterOf(tester).clock;
      controller.pause();
      final held = clock.elapsedSeconds;
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.isRunning, isFalse);
      expect(controller.isActive, isTrue, reason: 'paused but still visible');
      expect(clock.elapsedSeconds, held, reason: 'the frame is held');
      expect(tester.binding.transientCallbackCount, 0);

      controller.seek(const Duration(milliseconds: 1500));
      expect(clock.elapsedSeconds, closeTo(1.5, 1e-9));

      controller.resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isRunning, isTrue);
      expect(
        clock.elapsedSeconds,
        closeTo(1.6, 1e-9),
        reason: 'the timeline carries on from the seek',
      );

      controller.stop();
      await tester.pump(pastFadeOut);
      expect(deactivated, 1);
      expect(controller.isActive, isFalse);
      expect(controller.isRunning, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('start resumes a paused beam from its held frame', (
      tester,
    ) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        beamHost(
          BorderBeam(controller: controller, child: const SizedBox.expand()),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(pastFadeIn);
      controller.pause();
      final clock = beamPainterOf(tester).clock;
      final held = clock.elapsedSeconds;
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.isRunning, isFalse);

      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isRunning, isTrue);
      expect(
        clock.elapsedSeconds,
        closeTo(held + 0.1, 1e-9),
        reason: 'the timeline carries on rather than restarting',
      );
      expect(clock.fadeOpacity, 1, reason: 'no fade replays');

      // On a running beam it changes nothing.
      controller.start();
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock.elapsedSeconds, closeTo(held + 0.2, 1e-9));
    });

    testWidgets('ignores the active shorthand', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(bool active) => beamHost(
        BorderBeam(
          controller: controller,
          active: active,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isActive, isFalse);

      controller.start();
      await tester.pump();
      await tester.pumpWidget(build(false));
      await tester.pump(pastFadeIn);
      expect(controller.isActive, isTrue, reason: 'the controller owns it');
    });

    testWidgets('detaches cleanly on dispose', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        beamHost(
          BorderBeam(controller: controller, child: const SizedBox.expand()),
        ),
      );
      expect(controller.isAttached, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(controller.isAttached, isFalse);
      // Controls on a detached controller are safe no-ops.
      controller
        ..start()
        ..pause()
        ..resume()
        ..stop();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isActive, isFalse);
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('notifies its listeners once per playback command', (
      tester,
    ) async {
      // It is a ChangeNotifier so play/pause UI can follow it with a
      // ListenableBuilder: every command that changes playback says so.
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);
      await tester.pumpWidget(
        beamHost(
          BorderBeam(controller: controller, child: const SizedBox.expand()),
        ),
      );
      expect(notifications, 0, reason: 'attaching is not a command');

      for (final (name, command) in <(String, VoidCallback)>[
        ('start', controller.start),
        ('pulse', controller.pulse),
        ('flash', controller.flash),
        ('pause', controller.pause),
        ('resume', controller.resume),
        ('seek', () => controller.seek(const Duration(seconds: 1))),
        ('speed', () => controller.speed = 2),
        ('stop', controller.stop),
      ]) {
        final before = notifications;
        command();
        expect(notifications, before + 1, reason: name);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pump(const Duration(seconds: 1));
      expect(controller.isActive, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  testWidgets('the clock fades in over its documented window', (tester) async {
    // The fade lengths are public API (BeamClock.fadeInSeconds), so this
    // checks the widget wires the clock rather than restating the number.
    var activated = 0;
    await tester.pumpWidget(
      beamHost(
        BorderBeam(
          onActivate: () => activated++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    final fadeIn = Duration(
      microseconds: (BeamClock.fadeInSeconds * 1e6).round(),
    );
    await tester.pump(fadeIn - const Duration(milliseconds: 20));
    expect(activated, 0);
    expect(beamPainterOf(tester).clock.stage, BeamFadeStage.fadingIn);
    await tester.pump(const Duration(milliseconds: 40));
    expect(activated, 1);
  });
}
