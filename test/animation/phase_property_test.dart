import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/constants/pulse_params.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_test/flutter_test.dart';

/// Property tests over [BeamPhaseResolver.sample].
///
/// Every animated value in this package is a pure function of elapsed time,
/// which is what lets the painter re-derive a frame from the clock alone.
/// These tests assert that purity, the periodicity the cycle duration
/// promises, and the range each phase field is allowed to occupy — over a
/// seeded random sweep rather than a handful of hand-picked instants.
void main() {
  const sampleCount = 500;

  BeamConfig configFor(BeamVariant variant, {ui.Brightness? brightness}) =>
      BeamConfig.resolve(
        variant: variant,
        palette: BeamColors.colorful.resolve(),
        brightness: brightness ?? ui.Brightness.dark,
      );

  void expectPhasesEqual(
    BeamFramePhases a,
    BeamFramePhases b, {
    required String at,
  }) {
    expect(a.fadeOpacity, b.fadeOpacity, reason: 'fadeOpacity $at');
    expect(a.hueDegrees, b.hueDegrees, reason: 'hueDegrees $at');
    expect(a.bloomHueDegrees, b.bloomHueDegrees, reason: 'bloomHue $at');
    expect(a.angleRadians, b.angleRadians, reason: 'angleRadians $at');
    expect(a.lineX, b.lineX, reason: 'lineX $at');
    expect(a.lineW, b.lineW, reason: 'lineW $at');
    expect(a.lineH, b.lineH, reason: 'lineH $at');
    expect(a.spike, b.spike, reason: 'spike $at');
    expect(a.spike2, b.spike2, reason: 'spike2 $at');
    expect(a.edge, b.edge, reason: 'edge $at');
    expect(a.pulse.bw, b.pulse.bw, reason: 'pulse.bw $at');
    expect(a.pulse.bh, b.pulse.bh, reason: 'pulse.bh $at');
    expect(a.pulse.bx, b.pulse.bx, reason: 'pulse.bx $at');
    expect(a.pulse.by, b.pulse.by, reason: 'pulse.by $at');
    expect(a.pulse.bgh, b.pulse.bgh, reason: 'pulse.bgh $at');
    expect(a.pulse.bopTl, b.pulse.bopTl, reason: 'pulse.bopTl $at');
    expect(a.pulse.bopTr, b.pulse.bopTr, reason: 'pulse.bopTr $at');
    expect(a.pulse.bopBl, b.pulse.bopBl, reason: 'pulse.bopBl $at');
    expect(a.pulse.bopBr, b.pulse.bopBr, reason: 'pulse.bopBr $at');
  }

  group('purity', () {
    for (final variant in BeamVariant.values) {
      test('$variant: the same t yields the same frame', () {
        final config = configFor(variant);
        final resolver = BeamPhaseResolver(config);
        // A second resolver over the same config must agree too: the
        // oscillator bank carries no per-frame state.
        final twin = BeamPhaseResolver(config);
        final random = math.Random(0x5EED);
        for (var i = 0; i < sampleCount; i++) {
          final t = random.nextDouble() * 1000;
          final fade = random.nextDouble();
          expectPhasesEqual(
            resolver.sample(t, fade),
            resolver.sample(t, fade),
            at: 'at t=$t',
          );
          expectPhasesEqual(
            resolver.sample(t, fade),
            twin.sample(t, fade),
            at: 'across resolvers at t=$t',
          );
        }
      });

      test('$variant: fadeOpacity passes straight through', () {
        final resolver = BeamPhaseResolver(configFor(variant));
        final random = math.Random(0xFADE);
        for (var i = 0; i < sampleCount; i++) {
          final fade = random.nextDouble();
          expect(
            resolver.sample(random.nextDouble() * 1000, fade).fadeOpacity,
            fade,
          );
        }
      });
    }
  });

  group('cycle periodicity', () {
    // Only the tracks driven by the cycle duration itself repeat every
    // cycle. The line variant's breathe/spike tracks run at ×1.3/×1.33/×1.7
    // of it, and the hue ping-pong has its own 12s period, so neither is
    // expected to line up here.
    //
    // Samples stay clear of the wrap (fraction 0.02–0.98) so a float
    // rounding of the modulo cannot land the two reads on opposite sides of
    // a keyframe seam.
    ({double a, double b}) pairFor(math.Random random, double cycleSeconds) {
      final fraction = 0.02 + random.nextDouble() * 0.96;
      final t = fraction * cycleSeconds;
      final k = 1 + random.nextInt(20);
      return (a: t, b: t + k * cycleSeconds);
    }

    for (final variant in [BeamVariant.rotate, BeamVariant.small]) {
      test('$variant: the conic angle repeats every cycle', () {
        final config = configFor(variant);
        final resolver = BeamPhaseResolver(config);
        final random = math.Random(0xC0FFEE);
        for (var i = 0; i < sampleCount; i++) {
          final (a: t, b: later) = pairFor(random, config.cycleSeconds);
          expect(
            resolver.sample(later, 1).angleRadians,
            closeTo(resolver.sample(t, 1).angleRadians, 1e-6),
            reason: 'angleRadians at t=$t vs $later',
          );
        }
      });
    }

    test('line: travel, width and edge fade repeat every cycle', () {
      final config = configFor(BeamVariant.line);
      final resolver = BeamPhaseResolver(config);
      final random = math.Random(0xBEEF);
      for (var i = 0; i < sampleCount; i++) {
        final (a: t, b: later) = pairFor(random, config.cycleSeconds);
        final first = resolver.sample(t, 1);
        final second = resolver.sample(later, 1);
        expect(second.lineX, closeTo(first.lineX, 1e-6), reason: 'lineX @$t');
        expect(second.lineW, closeTo(first.lineW, 1e-6), reason: 'lineW @$t');
        expect(second.edge, closeTo(first.edge, 1e-6), reason: 'edge @$t');
      }
    });
  });

  group('ranges', () {
    for (final variant in BeamVariant.values) {
      test('$variant: the conic angle stays in [0, 2pi)', () {
        final resolver = BeamPhaseResolver(configFor(variant));
        final random = math.Random(0xA11CE);
        for (var i = 0; i < sampleCount; i++) {
          final angle = resolver
              .sample(random.nextDouble() * 5000, 1)
              .angleRadians;
          expect(angle, greaterThanOrEqualTo(0));
          expect(angle, lessThan(2 * math.pi));
        }
      });
    }

    test('line: the edge fade stays in [0, 1]', () {
      final resolver = BeamPhaseResolver(configFor(BeamVariant.line));
      final random = math.Random(0xED6E);
      for (var i = 0; i < sampleCount; i++) {
        final edge = resolver.sample(random.nextDouble() * 5000, 1).edge;
        expect(edge, inInclusiveRange(0, 1));
      }
    });

    for (final variant in [BeamVariant.pulseInside, BeamVariant.pulseOutside]) {
      for (final brightness in ui.Brightness.values) {
        test('$variant/$brightness: breathing stays inside its params', () {
          final config = configFor(variant, brightness: brightness);
          final params = PulseParams.resolve(
            variant,
            brightness,
            config.cycleSeconds,
          );
          final resolver = BeamPhaseResolver(config);
          final random = math.Random(0xDEC0DE);
          // The widest oscillator in the size bank swings to 1 + sp × 1.15.
          final sizeSpan = params.sp * 1.15;
          for (var i = 0; i < sampleCount; i++) {
            final pulse = resolver.sample(random.nextDouble() * 5000, 1).pulse;
            for (final v in pulse.bw) {
              expect(v, inInclusiveRange(1 - sizeSpan, 1 + sizeSpan));
            }
            for (final v in pulse.bh) {
              expect(v, inInclusiveRange(1 - sizeSpan, 1 + sizeSpan));
            }
            for (final v in [...pulse.bx, ...pulse.by]) {
              expect(v, inInclusiveRange(-params.dr, params.dr));
            }
            expect(pulse.bgh, inInclusiveRange(1 - params.gh, 1 + params.gh));
            for (final v in [
              pulse.bopTl,
              pulse.bopTr,
              pulse.bopBl,
              pulse.bopBr,
            ]) {
              expect(v, inInclusiveRange(1 - params.op, 1));
            }
          }
        });
      }
    }
  });

  group('staticFrame', () {
    for (final variant in BeamVariant.values) {
      test('$variant: is deterministic', () {
        final resolver = BeamPhaseResolver(configFor(variant));
        expectPhasesEqual(
          resolver.staticFrame(),
          resolver.staticFrame(),
          at: 'in staticFrame',
        );
        expect(resolver.staticFrame().fadeOpacity, 1);
      });

      test('$variant: is hue-neutral', () {
        // Reduced motion paints one frame forever, so it must show the
        // palette's own colors rather than an arbitrary point of the hue
        // ping-pong frozen in place.
        final resolver = BeamPhaseResolver(configFor(variant));
        expect(resolver.staticFrame().hueDegrees, 0);
        expect(resolver.staticFrame().bloomHueDegrees, 0);
      });
    }
  });
}
