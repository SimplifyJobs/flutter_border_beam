import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

/// The one-ticker-per-beam contract: every path that ends a beam — disposal
/// mid-fade, an effect swap, `TickerMode`, a controller that outlives its
/// beam, a pending start delay — must leave no frame callback behind.
void main() {
  Widget beam(
    BeamEffect effect, {
    bool active = true,
    BorderBeamController? controller,
    VoidCallback? onActivate,
    BeamPlayback? playback,
    Widget child = const SizedBox.expand(),
  }) => BorderBeam(
    effect: effect,
    active: active,
    controller: controller,
    onActivate: onActivate,
    playback: playback,
    child: child,
  );

  group('disposal', () {
    for (final effect in BeamEffect.values) {
      testWidgets('${effect.name} disposed mid fade-in leaves no ticker', (
        tester,
      ) async {
        await tester.pumpWidget(beamHost(beam(effect)));
        await tester.pump();
        // 200ms into the 600ms fade-in.
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.binding.transientCallbackCount,
          1,
          reason: 'the beam should be ticking here',
        );

        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('${effect.name} disposed mid fade-out leaves no ticker', (
        tester,
      ) async {
        await tester.pumpWidget(beamHost(beam(effect)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        await tester.pumpWidget(beamHost(beam(effect, active: false)));
        // 200ms into the 500ms fade-out.
        await tester.pump(const Duration(milliseconds: 200));
        expect(beamPainterOf(tester).clock.isVisible, isTrue);
        expect(tester.binding.transientCallbackCount, 1);

        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }

    testWidgets('a pending startAfter is cancelled with the beam', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          beam(
            const BeamEffect.rotate(),
            playback: const BeamPlayback(startAfter: Duration(seconds: 2)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      // Stay short of the 2s deadline: a timer the beam failed to cancel is
      // still pending when the test ends, and the binding fails the test for
      // it. Pumping past the deadline would let it fire into the State's
      // `mounted` guard and pass whether or not it was cancelled.
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a reduced-motion static frame disposes without a ticker', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(beam(const BeamEffect.rotate()), disableAnimations: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  testWidgets('an effect swap keeps exactly one ticker', (tester) async {
    await tester.pumpWidget(beamHost(beam(const BeamEffect.rotate())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final effect in BeamEffect.values.reversed) {
      await tester.pumpWidget(beamHost(beam(effect)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(beamPainterOf(tester).config.effect, effect);
      expect(beamPainterOf(tester).clock.isRunning, isTrue);
      expect(
        tester.binding.transientCallbackCount,
        1,
        reason: 'exactly one clock ticks after swapping to ${effect.name}',
      );
    }

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('TickerMode mutes frames and unmuting resumes them', (
    tester,
  ) async {
    var activated = 0;
    Widget build(bool enabled) => beamHost(
      TickerMode(
        enabled: enabled,
        child: beam(const BeamEffect.rotate(), onActivate: () => activated++),
      ),
    );

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.binding.transientCallbackCount, 0);
    expect(activated, 0, reason: 'a muted clock never completes its fade-in');

    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pump(const Duration(milliseconds: 700));
    expect(activated, 1);
    expect(tester.binding.transientCallbackCount, 1, reason: 'still animating');

    await tester.pumpWidget(build(false));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a beam disposed under TickerMode leaves no ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      beamHost(
        TickerMode(enabled: false, child: beam(const BeamEffect.pulse())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a controller outliving its beam is an inert no-op', (
    tester,
  ) async {
    final controller = BorderBeamController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      beamHost(beam(const BeamEffect.rotate(), controller: controller)),
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
    expect(tester.binding.transientCallbackCount, 0);

    controller
      ..start()
      ..pause()
      ..resume()
      ..seek(const Duration(seconds: 1))
      ..pulse()
      ..flash()
      ..speed = 2
      ..stop();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'a controller handed to a new beam in the same frame follows it',
    (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        beamHost(beam(const BeamEffect.rotate(), controller: controller)),
      );
      // A different parent: the old State is disposed and a new one mounted
      // within the one frame.
      await tester.pumpWidget(
        beamHost(
          Padding(
            padding: EdgeInsets.zero,
            child: beam(const BeamEffect.rotate(), controller: controller),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      controller.start();
      await tester.pump();
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
    },
  );

  testWidgets('a controller moves to a new beam after the old one is gone', (
    tester,
  ) async {
    final controller = BorderBeamController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      beamHost(beam(const BeamEffect.rotate(), controller: controller)),
    );
    controller.start();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(controller.isAttached, isFalse);

    await tester.pumpWidget(
      beamHost(beam(const BeamEffect.pulse(), controller: controller)),
    );
    expect(controller.isAttached, isTrue);
    expect(controller.isActive, isFalse, reason: 'the new beam starts hidden');
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(beamPainterOf(tester).clock.isRunning, isTrue);
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('replacing the child keeps the beam running', (tester) async {
    Widget build(String label) =>
        beamHost(beam(const BeamEffect.rotate(), child: Text(label)));

    await tester.pumpWidget(build('before'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final clock = beamPainterOf(tester).clock;
    final elapsed = clock.elapsedSeconds;

    await tester.pumpWidget(build('after'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('before'), findsNothing);
    expect(find.text('after'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(identical(beamPainterOf(tester).clock, clock), isTrue);
    expect(
      clock.elapsedSeconds,
      greaterThan(elapsed),
      reason: 'no restart, no stall',
    );
    expect(tester.binding.transientCallbackCount, 1);
  });
}
