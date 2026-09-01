import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The travel half of the phase resolver: which way the beam runs, where its
/// timeline starts, how many beams share the contour, which shape the hue
/// track takes, and when the repeat budget is spent.
///
/// Every one of these is a pure function of elapsed time, so they are tested
/// against the resolver directly rather than through a mounted widget.
void main() {
  const cycle = Duration(milliseconds: 1960);
  const cycleSeconds = 1.96;

  BeamPhaseResolver resolverFor({
    BeamVariant variant = BeamVariant.rotate,
    BeamDirection? direction,
    double? phaseOffset,
    int? beamCount,
    Duration? cycleGap,
    BeamHueMode? hueMode,
    double? hueRange,
    BeamEdge? edge,
  }) => BeamPhaseResolver(
    BeamConfig.resolve(
      variant: variant,
      palette: BeamColors.colorful.resolve(),
      brightness: Brightness.dark,
      style: BeamStyle(hueMode: hueMode, hueRange: hueRange),
      shape: BeamShape(edge: edge),
      timing: BeamTiming(
        cycle: cycle,
        cycleGap: cycleGap,
        direction: direction,
        phaseOffset: phaseOffset,
        beamCount: beamCount,
      ),
    ),
  );

  group('direction', () {
    test('forward runs the sweep from 0 to 1 across the cycle', () {
      final resolver = resolverFor();
      expect(resolver.sample(0, 1).travelProgress, closeTo(0, 1e-9));
      expect(
        resolver.sample(cycleSeconds * 0.25, 1).travelProgress,
        closeTo(0.25, 1e-9),
      );
      expect(
        resolver.sample(cycleSeconds * 0.25, 1).angleRadians,
        closeTo(math.pi / 2, 1e-9),
      );
      expect(resolver.sample(cycleSeconds * 0.25, 1).reversedNow, isFalse);
    });

    test('reverse mirrors every traveller and flags the frame', () {
      final forward = resolverFor();
      final reverse = resolverFor(direction: BeamDirection.reverse);
      for (final t in [0.0, 0.4, 1.1, cycleSeconds * 0.75, 5.3]) {
        expect(
          reverse.sample(t, 1).travelProgress,
          closeTo(1 - forward.sample(t, 1).travelProgress, 1e-9),
          reason: 'the mirror of the forward sweep at ${t}s',
        );
      }
      expect(reverse.sample(1.3, 1).reversedNow, isTrue);
    });

    test('reverse runs the angle counter-clockwise', () {
      final resolver = resolverFor(direction: BeamDirection.reverse);
      final early = resolver.sample(cycleSeconds * 0.1, 1).angleRadians;
      final later = resolver.sample(cycleSeconds * 0.2, 1).angleRadians;
      expect(later, lessThan(early));
    });

    test('bounce alternates per cycle, starting forward', () {
      final resolver = resolverFor(direction: BeamDirection.bounce);
      // Quarter of the way into cycles 0, 1, and 2.
      expect(
        resolver.sample(cycleSeconds * 0.25, 1).travelProgress,
        closeTo(0.25, 1e-9),
      );
      expect(resolver.sample(cycleSeconds * 0.25, 1).reversedNow, isFalse);
      expect(
        resolver.sample(cycleSeconds * 1.25, 1).travelProgress,
        closeTo(0.75, 1e-9),
      );
      expect(resolver.sample(cycleSeconds * 1.25, 1).reversedNow, isTrue);
      expect(
        resolver.sample(cycleSeconds * 2.25, 1).travelProgress,
        closeTo(0.25, 1e-9),
      );
      expect(resolver.sample(cycleSeconds * 2.25, 1).reversedNow, isFalse);
    });

    test('bounce counts cycles including the gap', () {
      final resolver = resolverFor(
        direction: BeamDirection.bounce,
        cycleGap: const Duration(seconds: 1),
      );
      // The sweep ends at 1.96s but the cycle only does at 2.96s, so the
      // rest between them still belongs to the forward cycle.
      expect(resolver.sample(2.5, 1).reversedNow, isFalse);
      expect(
        resolver.sample(2.96 + cycleSeconds * 0.25, 1).reversedNow,
        isTrue,
      );
      expect(
        resolver.sample(2 * 2.96 + cycleSeconds * 0.25, 1).reversedNow,
        isFalse,
      );
    });

    test('reverse parks at the mirrored end through a cycle gap', () {
      final resolver = resolverFor(
        direction: BeamDirection.reverse,
        cycleGap: const Duration(seconds: 1),
      );
      final resting = resolver.sample(cycleSeconds + 0.5, 1);
      expect(resting.travelProgress, closeTo(0, 1e-9));
      expect(resting.fadeOpacity, 0, reason: 'the gap still rests the beam');
    });

    test('the line variant reverses its travel table', () {
      final forward = resolverFor(variant: BeamVariant.line);
      final reverse = resolverFor(
        variant: BeamVariant.line,
        direction: BeamDirection.reverse,
      );
      final at = cycleSeconds * 0.3;
      expect(
        reverse.sample(at, 1).lineX,
        closeTo(forward.sample(cycleSeconds * 0.7, 1).lineX, 1e-9),
      );
    });
  });

  group('phaseOffset', () {
    test('starts the timeline that fraction of a cycle in', () {
      final resolver = resolverFor(phaseOffset: 0.25);
      expect(resolver.sample(0, 1).travelProgress, closeTo(0.25, 1e-9));
      expect(
        resolver.sample(cycleSeconds * 0.5, 1).travelProgress,
        closeTo(0.75, 1e-9),
      );
    });

    test('leaves the hue track where it was', () {
      final plain = resolverFor();
      final shifted = resolverFor(phaseOffset: 0.5);
      expect(
        shifted.sample(1.3, 1).hueDegrees,
        closeTo(plain.sample(1.3, 1).hueDegrees, 1e-9),
      );
    });

    test('a whole-cycle offset is the identity', () {
      final plain = resolverFor();
      final shifted = resolverFor(phaseOffset: 1);
      expect(
        shifted.sample(0.7, 1).travelProgress,
        closeTo(plain.sample(0.7, 1).travelProgress, 1e-9),
      );
    });
  });

  group('beamCount', () {
    test('one beam is a single-entry list holding the head', () {
      final phases = resolverFor().sample(0.5, 1);
      expect(phases.travellers, hasLength(1));
      expect(phases.travellers.single, phases.travelProgress);
    });

    test('spaces the beams evenly and keeps the head first', () {
      final phases = resolverFor(beamCount: 3).sample(cycleSeconds * 0.1, 1);
      expect(phases.travellers, hasLength(3));
      expect(phases.travellers.first, closeTo(0.1, 1e-9));
      expect(phases.travellers[1], closeTo(0.1 + 1 / 3, 1e-9));
      expect(phases.travellers[2], closeTo(0.1 + 2 / 3, 1e-9));
      expect(phases.travelProgress, phases.travellers.first);
    });

    test('wraps the trailing beams into 0–1', () {
      final phases = resolverFor(beamCount: 4).sample(cycleSeconds * 0.9, 1);
      expect(phases.travellers, hasLength(4));
      for (final p in phases.travellers) {
        expect(p, inInclusiveRange(0, 1));
      }
      expect(phases.travellers[1], closeTo(0.15, 1e-9));
    });

    test('reverse spaces the beams the other way round', () {
      final phases = resolverFor(
        beamCount: 2,
        direction: BeamDirection.reverse,
      ).sample(cycleSeconds * 0.1, 1);
      expect(phases.travellers.first, closeTo(0.9, 1e-9));
      expect(phases.travellers[1], closeTo(0.4, 1e-9));
    });

    test('the spacing holds all the way round the cycle', () {
      final resolver = resolverFor(beamCount: 5);
      for (final t in [0.0, 0.3, 1.1, 1.9, 4.4]) {
        final travellers = resolver.sample(t, 1).travellers;
        for (var i = 1; i < travellers.length; i++) {
          final gap = (travellers[i] - travellers[i - 1]) % 1.0;
          expect(gap, closeTo(0.2, 1e-9), reason: 'beams $i and ${i - 1}');
        }
      }
    });
  });

  group('hueMode', () {
    test('the traveling variants ping-pong by default', () {
      final resolver = resolverFor(hueRange: 30);
      // 12s period: a quarter in is the middle of the upward swing.
      expect(resolver.sample(0, 1).hueDegrees, closeTo(-30, 1e-9));
      expect(resolver.sample(6, 1).hueDegrees, closeTo(30, 1e-9));
      expect(resolver.sample(12, 1).hueDegrees, closeTo(-30, 1e-9));
    });

    test('the pulse variants revolve by default', () {
      final resolver = resolverFor(variant: BeamVariant.pulseInside);
      // 16s period for pulse-inside.
      expect(resolver.sample(0, 1).hueDegrees, closeTo(0, 1e-9));
      expect(resolver.sample(8, 1).hueDegrees, closeTo(180, 1e-9));
      expect(resolver.sample(16, 1).hueDegrees, closeTo(0, 1e-9));
    });

    for (final variant in BeamVariant.values) {
      test('$variant: continuous revolves through 360°', () {
        final resolver = resolverFor(
          variant: variant,
          hueMode: BeamHueMode.continuous,
        );
        final period = resolver.config.huePeriodSeconds;
        expect(resolver.sample(0, 1).hueDegrees, closeTo(0, 1e-9));
        expect(resolver.sample(period / 4, 1).hueDegrees, closeTo(90, 1e-9));
        expect(resolver.sample(period * 0.999, 1).hueDegrees, greaterThan(359));
      });

      test('$variant: pingPong stays inside ±hueRange', () {
        final resolver = resolverFor(
          variant: variant,
          hueMode: BeamHueMode.pingPong,
          hueRange: 20,
        );
        final range = resolver.config.hueRange;
        for (var i = 0; i <= 40; i++) {
          final hue = resolver.sample(i * 0.7, 1).hueDegrees;
          expect(hue, inInclusiveRange(-range - 1e-9, range + 1e-9));
        }
      });
    }

    test('static colors beat both modes', () {
      final resolver = BeamPhaseResolver(
        BeamConfig.resolve(
          variant: BeamVariant.rotate,
          palette: BeamColors.colorful.resolve(),
          brightness: Brightness.dark,
          style: const BeamStyle(
            staticColors: true,
            hueMode: BeamHueMode.continuous,
          ),
        ),
      );
      expect(resolver.sample(5, 1).hueDegrees, 0);
    });
  });

  group('repeat budget', () {
    test('no budget never finishes', () {
      final resolver = resolverFor();
      expect(resolver.finishedAt(1000), isFalse);
      expect(resolver.sample(1000, 1).finished, isFalse);
    });

    test('one cycle finishes at the cycle boundary', () {
      final resolver = resolverFor()..repeatCycles = 1;
      expect(resolver.finishedAt(cycleSeconds - 0.001), isFalse);
      expect(resolver.finishedAt(cycleSeconds + 0.001), isTrue);
      expect(resolver.sample(cycleSeconds + 0.001, 1).finished, isTrue);
    });

    test('a count finishes after that many cycles', () {
      final resolver = resolverFor()..repeatCycles = 3;
      expect(resolver.finishedAt(3 * cycleSeconds - 0.001), isFalse);
      expect(resolver.finishedAt(3 * cycleSeconds + 0.001), isTrue);
    });

    test('the gap counts toward a cycle', () {
      final resolver = resolverFor(cycleGap: const Duration(seconds: 1))
        ..repeatCycles = 1;
      expect(resolver.finishedAt(cycleSeconds + 0.5), isFalse);
      expect(resolver.finishedAt(cycleSeconds + 1.1), isTrue);
    });

    test('a phase offset moves the finish with the timeline', () {
      final resolver = resolverFor(phaseOffset: 0.5)..repeatCycles = 1;
      expect(resolver.finishedAt(cycleSeconds * 0.4), isFalse);
      expect(resolver.finishedAt(cycleSeconds * 0.6), isTrue);
    });

    test('the pulse variants report it too', () {
      final resolver = resolverFor(variant: BeamVariant.pulseInside)
        ..repeatCycles = 2;
      final period = resolver.config.cycleSeconds;
      expect(resolver.sample(2 * period - 0.01, 1).finished, isFalse);
      expect(resolver.sample(2 * period + 0.01, 1).finished, isTrue);
    });
  });

  group('driven progress', () {
    test('replaces the sweep with the given value', () {
      final resolver = resolverFor();
      final phases = resolver.sample(0.9, 1, progress: 0.25);
      expect(phases.travelProgress, closeTo(0.25, 1e-9));
      expect(phases.angleRadians, closeTo(math.pi / 2, 1e-9));
    });

    test('the same value paints the same frame at any time', () {
      final resolver = resolverFor();
      expect(
        resolver.sample(0.3, 1, progress: 0.6).angleRadians,
        closeTo(resolver.sample(7.4, 1, progress: 0.6).angleRadians, 1e-9),
      );
    });

    test('clamps out-of-range values', () {
      final resolver = resolverFor();
      expect(resolver.sample(0, 1, progress: 1.4).travelProgress, 1);
      expect(resolver.sample(0, 1, progress: -0.3).travelProgress, 0);
    });

    test('ignores the cycle gap — a readout never rests', () {
      final resolver = resolverFor(cycleGap: const Duration(seconds: 1));
      final resting = resolver.sample(cycleSeconds + 0.5, 1, progress: 0.4);
      expect(resting.fadeOpacity, 1);
      expect(resting.travelProgress, closeTo(0.4, 1e-9));
    });

    test('keeps the hue and the line texture tracks running', () {
      final resolver = resolverFor(variant: BeamVariant.line);
      final early = resolver.sample(0.4, 1, progress: 0.5);
      final late = resolver.sample(3.4, 1, progress: 0.5);
      expect(early.hueDegrees, isNot(closeTo(late.hueDegrees, 1e-6)));
      expect(early.lineH, isNot(closeTo(late.lineH, 1e-6)));
      expect(early.lineX, closeTo(late.lineX, 1e-9));
    });

    test('spreads multiple beams around the driven position', () {
      final phases = resolverFor(beamCount: 2).sample(0, 1, progress: 0.25);
      expect(phases.travellers, hasLength(2));
      expect(phases.travellers[1], closeTo(0.75, 1e-9));
    });

    test('the static frame honors it', () {
      final resolver = resolverFor();
      expect(
        resolver.staticFrame(progress: 0.25).angleRadians,
        closeTo(math.pi / 2, 1e-9),
      );
      expect(resolver.staticFrame().angleRadians, closeTo(math.pi, 1e-9));
    });
  });

  group('travelTimeOffset', () {
    test('shifts the sweep without touching the hue', () {
      final plain = resolverFor();
      final shifted = resolverFor()..travelTimeOffset = cycleSeconds * 0.25;
      expect(shifted.sample(0, 1).travelProgress, closeTo(0.25, 1e-9));
      expect(
        shifted.sample(1.3, 1).hueDegrees,
        closeTo(plain.sample(1.3, 1).hueDegrees, 1e-9),
      );
    });

    test('a negative offset runs the sweep behind', () {
      final resolver = resolverFor()..travelTimeOffset = -cycleSeconds * 0.25;
      expect(
        resolver.sample(cycleSeconds * 0.5, 1).travelProgress,
        closeTo(0.25, 1e-9),
      );
    });
  });
}
