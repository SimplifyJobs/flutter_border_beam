import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/render/beam_painter.dart';
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

Iterable<BeamPainter> _painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>();

BeamPainter _painter(WidgetTester tester) => _painters(tester).first;

BeamClock _clock(WidgetTester tester) => _painter(tester).clock;

// The phases the mounted beam's resolver gives at [t] with a full fade.
BeamFramePhases _at(WidgetTester tester, double t) =>
    _painter(tester).resolver.sample(t, 1);

// The phases the painter would draw right now.
BeamFramePhases _now(WidgetTester tester) {
  final painter = _painter(tester);
  return painter.resolver.sample(
    painter.clock.elapsedSeconds,
    1,
    progress: painter.progress?.value,
  );
}

// The signed distance from [from] to [to] round the border, in (-0.5, 0.5].
double _wrapDelta(double from, double to) => ((to - from) + 0.5) % 1.0 - 0.5;

/// Sums the alpha channel of the beam's own repaint boundary. Rasterizing is
/// real async work, so it runs outside the fake clock.
Future<int> _alphaSum(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .descendant(
          of: find.byType(BorderBeam),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  final sum = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    var total = 0;
    for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
      total += bytes.getUint8(i);
    }
    return total;
  });
  return sum!;
}

const _travelling = <BeamEffect>[BeamEffect.rotate(), BeamEffect.line()];

const _ambient = <BeamEffect>[BeamEffect.pulse()];

/// How the mounted beam moves: travel direction, phase offset, several
/// travellers, the one-shot pulse and flash accents, the live strength
/// listenable, and what reduced motion and a repeat budget do to it.
void main() {
  setUpAll(() async {
    await BorderBeam.precache();
  });

  // A one-second sweep with no rest, so instants map straight to progress.
  BeamTiming oneSecond([BeamDirection? direction]) => BeamTiming(
    cycle: const Duration(seconds: 1),
    cycleGap: Duration.zero,
    direction: direction,
  );

  group('direction', () {
    testWidgets('forward runs the sweep clockwise, every cycle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(BorderBeam(timing: oneSecond(), child: const SizedBox.expand())),
      );
      for (final t in [0.1, 0.25, 0.6, 1.3, 2.9]) {
        final phases = _at(tester, t);
        expect(phases.travelProgress, closeTo(t % 1.0, 1e-9), reason: 't=$t');
        expect(phases.reversedNow, isFalse, reason: 't=$t');
      }
    });

    for (final effect in _travelling) {
      testWidgets('reverse runs the ${effect.name} sweep the other way', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            BorderBeam(
              effect: effect,
              timing: oneSecond(BeamDirection.reverse),
              child: const SizedBox.expand(),
            ),
          ),
        );
        for (final t in [0.1, 0.25, 0.6, 1.3]) {
          final phases = _at(tester, t);
          expect(
            phases.travelProgress,
            closeTo(1 - t % 1.0, 1e-9),
            reason: 't=$t',
          );
          expect(phases.reversedNow, isTrue, reason: 't=$t');
        }
      });
    }

    testWidgets('bounce alternates direction every cycle', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            timing: oneSecond(BeamDirection.bounce),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final first = _at(tester, 0.25);
      expect(first.travelProgress, closeTo(0.25, 1e-9));
      expect(first.reversedNow, isFalse);

      final second = _at(tester, 1.25);
      expect(second.travelProgress, closeTo(0.75, 1e-9));
      expect(second.reversedNow, isTrue);

      final third = _at(tester, 2.25);
      expect(third.travelProgress, closeTo(0.25, 1e-9));
      expect(third.reversedNow, isFalse);
    });

    testWidgets('bounce counts the rest between sweeps into the cycle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam(
            timing: BeamTiming(
              cycle: Duration(seconds: 1),
              cycleGap: Duration(seconds: 1),
              direction: BeamDirection.bounce,
            ),
            child: SizedBox.expand(),
          ),
        ),
      );
      // One period is sweep + rest (2s), so the second sweep starts at 2s.
      expect(_at(tester, 1.5).reversedNow, isFalse, reason: 'still resting');
      final second = _at(tester, 2.25);
      expect(second.reversedNow, isTrue);
      expect(second.travelProgress, closeTo(0.75, 1e-9));
    });

    testWidgets('the live sweep runs the configured way', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            timing: oneSecond(BeamDirection.reverse),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final earlier = _now(tester).travelProgress;
      expect(earlier, closeTo(0.75, 1e-9));

      await tester.pump(const Duration(milliseconds: 100));
      final later = _now(tester).travelProgress;
      expect(
        _wrapDelta(earlier, later),
        closeTo(-0.1, 1e-9),
        reason: 'a reversed beam moves counter-clockwise',
      );
    });
  });

  group('phaseOffset', () {
    testWidgets('shifts where the sweep starts', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam(
            timing: BeamTiming(cycle: Duration(seconds: 1), phaseOffset: 0.25),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(_at(tester, 0).travelProgress, closeTo(0.25, 1e-9));
      expect(_at(tester, 0.5).travelProgress, closeTo(0.75, 1e-9));
      expect(_at(tester, 0.9).travelProgress, closeTo(0.15, 1e-9));
    });

    testWidgets('a mirrored beam starts the same fraction into its cycle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam(
            timing: BeamTiming(
              cycle: Duration(seconds: 1),
              direction: BeamDirection.reverse,
              phaseOffset: 0.25,
            ),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(_at(tester, 0).travelProgress, closeTo(0.75, 1e-9));
    });
  });

  group('rotate count', () {
    for (var n = 1; n <= 4; n++) {
      testWidgets('count $n spaces the travellers evenly', (tester) async {
        await tester.pumpWidget(
          _host(
            BorderBeam(
              effect: BeamEffect.rotate(count: n),
              timing: oneSecond(),
              child: const SizedBox.expand(),
            ),
          ),
        );
        for (final t in [0.0, 0.3, 0.95]) {
          final phases = _at(tester, t);
          expect(phases.travellers, hasLength(n), reason: 't=$t');
          expect(phases.travellers.first, phases.travelProgress);
          for (var i = 0; i < n; i++) {
            final traveller = phases.travellers[i];
            expect(traveller, inInclusiveRange(0, 1), reason: 't=$t');
            expect(
              (traveller - phases.travelProgress) % 1.0,
              closeTo(i / n, 1e-9),
              reason: 'traveller $i at t=$t',
            );
          }
        }
      });
    }

    testWidgets('a reversed beam spreads its travellers the other way', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            effect: const BeamEffect.rotate(count: 3),
            timing: oneSecond(BeamDirection.reverse),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final phases = _at(tester, 0.3);
      for (var i = 1; i < 3; i++) {
        expect(
          (phases.travellers[i] - phases.travelProgress) % 1.0,
          closeTo(1 - i / 3, 1e-9),
          reason: 'traveller $i trails the head counter-clockwise',
        );
      }
    });

    for (final effect in _travelling.skip(1)) {
      testWidgets('${effect.name} runs a single traveller', (tester) async {
        await tester.pumpWidget(
          _host(BorderBeam(effect: effect, child: const SizedBox.expand())),
        );
        expect(_at(tester, 0.4).travellers, hasLength(1));
      });
    }
  });

  group('ambient effects', () {
    for (final effect in _ambient) {
      testWidgets('${effect.name} has no travel for a direction to turn', (
        tester,
      ) async {
        for (final direction in BeamDirection.values) {
          await tester.pumpWidget(
            _host(
              BorderBeam(
                effect: effect,
                timing: oneSecond(direction),
                child: const SizedBox.expand(),
              ),
            ),
          );
          for (final t in [0.3, 1.3, 2.7]) {
            final phases = _at(tester, t);
            final where = '$direction at t=$t';
            expect(phases.travelProgress, 0, reason: where);
            expect(phases.travellers, [0], reason: where);
            expect(phases.driven, isFalse, reason: where);
            expect(phases.fadeOpacity, 1, reason: where);
            expect(phases.cycles, closeTo(t, 1e-9), reason: where);
          }
        }
      });
    }
  });

  group('pulse and flash', () {
    Future<BorderBeamController> runningBeam(WidgetTester tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(controller: controller, child: const SizedBox.expand()),
        ),
      );
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      return controller;
    }

    testWidgets('pulse lifts the boost and settles back to 1', (tester) async {
      final controller = await runningBeam(tester);
      final clock = _clock(tester);
      expect(clock.boost, 1);

      controller.pulse();
      expect(clock.isBoosting, isTrue);
      var peak = 1.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        // The rise is spring-eased, so it may crest a hair past the peak.
        expect(clock.boost, greaterThanOrEqualTo(1));
        expect(clock.boost, lessThan(BeamClock.pulsePeak * 1.1));
        if (clock.boost > peak) peak = clock.boost;
      }
      expect(peak, greaterThan(1.5), reason: 'the pulse visibly rises');

      await tester.pump(const Duration(milliseconds: 400));
      expect(clock.boost, 1);
      expect(clock.isBoosting, isFalse);
    });

    testWidgets('flash jumps to its peak, holds, and settles back to 1', (
      tester,
    ) async {
      final controller = await runningBeam(tester);
      final clock = _clock(tester);

      controller.flash();
      expect(clock.boost, greaterThan(1), reason: 'a flash has no rise');
      final peak = clock.boost;
      await tester.pump(const Duration(milliseconds: 60));
      expect(clock.boost, closeTo(peak, 1e-9), reason: 'held at the peak');

      await tester.pump(const Duration(milliseconds: 500));
      expect(clock.boost, 1);
      expect(clock.isBoosting, isFalse);
    });

    testWidgets('a boost brightens the painted frame', (tester) async {
      final controller = await runningBeam(tester);
      final rest = await _alphaSum(tester);
      expect(rest, greaterThan(0));

      controller.flash();
      // A zero-length pump repaints at the same instant: only the boost moved.
      await tester.pump();
      expect(await _alphaSum(tester), greaterThan(rest));
    });

    testWidgets('a cycle retime carries a boost in progress', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      Widget build(Duration cycle) => _host(
        BorderBeam(
          controller: controller,
          timing: BeamTiming(cycle: cycle),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(const Duration(seconds: 2)));
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final clock = _clock(tester);
      controller.pulse();
      await tester.pump(const Duration(milliseconds: 100));
      final before = clock.boost;
      expect(before, greaterThan(1));

      await tester.pumpWidget(build(const Duration(seconds: 4)));
      expect(clock.boost, closeTo(before, 1e-9));
      await tester.pump(const Duration(milliseconds: 700));
      expect(clock.boost, 1);
    });

    testWidgets('both are no-ops while the beam is hidden', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(controller: controller, child: const SizedBox.expand()),
        ),
      );
      final clock = _clock(tester);
      expect(clock.isVisible, isFalse);

      controller
        ..pulse()
        ..flash();
      expect(clock.isBoosting, isFalse);
      expect(clock.boost, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a paused beam takes no boost', (tester) async {
      final controller = await runningBeam(tester);
      controller.pause();
      await tester.pump();

      controller.pulse();
      expect(_clock(tester).isBoosting, isFalse);
    });
  });

  group('strengthListenable', () {
    testWidgets('scales the painted frame live, without a rebuild', (
      tester,
    ) async {
      final strength = ValueNotifier<double>(1);
      addTearDown(strength.dispose);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              builds++;
              return BorderBeam(
                strengthListenable: strength,
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final painter = _painter(tester);
      expect(identical(painter.strength, strength), isTrue);
      final full = await _alphaSum(tester);
      expect(full, greaterThan(0));

      strength.value = 0.4;
      await tester.pump();
      final dimmed = await _alphaSum(tester);
      expect(dimmed, greaterThan(0));
      expect(dimmed, lessThan(full));

      expect(builds, 1, reason: 'the value never goes through a rebuild');
      expect(identical(_painter(tester).config, painter.config), isTrue);
      expect(identical(_painter(tester).resolver, painter.resolver), isTrue);
    });

    testWidgets('zero paints nothing, and lifting it paints again', (
      tester,
    ) async {
      final strength = ValueNotifier<double>(0);
      addTearDown(strength.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(
            strengthListenable: strength,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(await _alphaSum(tester), 0);

      strength.value = 1;
      await tester.pump();
      expect(await _alphaSum(tester), greaterThan(0));

      await tester.pumpWidget(_host(const SizedBox.expand()));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('scales a debug-frozen frame too', (tester) async {
      final strength = ValueNotifier<double>(0);
      addTearDown(strength.dispose);
      await tester.pumpWidget(
        _host(
          BorderBeam(
            playback: const BeamPlayback(
              debugFrozenAt: Duration(milliseconds: 1300),
            ),
            strengthListenable: strength,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      expect(await _alphaSum(tester), 0);

      strength.value = 1;
      await tester.pump();
      expect(await _alphaSum(tester), greaterThan(0));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('reduced motion', () {
    testWidgets('animate ignores the platform request', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam(
            playback: BeamPlayback(reducedMotion: BeamReducedMotion.animate),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_clock(tester).isRunning, isTrue);
      expect(_clock(tester).elapsedSeconds, closeTo(0.5, 1e-9));
      expect(_painter(tester).staticMode, isFalse);
    });

    testWidgets('staticFrame is the default and never ticks', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam(child: SizedBox.expand()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final painter = _painter(tester);
      expect(painter.staticMode, isTrue);
      expect(painter.clock.isRunning, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      expect(await _alphaSum(tester), greaterThan(0), reason: 'still lit');
    });

    testWidgets('hide mounts no painter and never ticks', (tester) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeam(
            playback: BeamPlayback(reducedMotion: BeamReducedMotion.hide),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_painters(tester), isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('repeat', () {
    testWidgets('once fades out after a single cycle', (tester) async {
      var deactivated = 0;
      await tester.pumpWidget(
        _host(
          BorderBeam(
            timing: oneSecond(),
            playback: const BeamPlayback(repeat: BeamRepeat.once()),
            onDeactivate: () => deactivated++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      expect(_clock(tester).stage, isNot(BeamFadeStage.fadingOut));

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _clock(tester).stage,
        BeamFadeStage.fadingOut,
        reason: 'the last cycle ends on a fade, not a cut',
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);
      expect(_clock(tester).isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('count(3) runs three cycles', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            timing: oneSecond(),
            playback: const BeamPlayback(repeat: BeamRepeat.count(3)),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2950));
      expect(_clock(tester).stage, isNot(BeamFadeStage.fadingOut));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_clock(tester).stage, BeamFadeStage.fadingOut);
    });
  });
}
