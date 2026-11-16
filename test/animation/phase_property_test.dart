import 'dart:math' as math;
import 'dart:ui' show Brightness;

import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Property tests over [BeamPhaseResolver.sample].
///
/// Every animated value in this package is a pure function of elapsed time,
/// which is what lets the painter re-derive a frame from the clock alone.
/// These tests assert that purity, the periodicity the cycle promises, and
/// the range every phase field may occupy — over a seeded random sweep of
/// times across every effect and every timing option that shapes the
/// travel, rather than a handful of hand-picked instants.
void main() {
  const samplesPerConfig = 60;

  // Every effect, with rotate fanned out over its beam counts.
  final effects = <BeamEffect>[
    for (final e in BeamEffect.values)
      if (e is RotateEffect)
        for (var n = 1; n <= 4; n++) BeamEffect.rotate(count: n)
      else
        e,
  ];

  /// Every timing/style combination exercised for one effect.
  List<BeamConfig> configsFor(BeamEffect effect) => [
    for (final direction in BeamDirection.values)
      for (final gap in const [Duration.zero, Duration(milliseconds: 700)])
        for (final phaseOffset in const [0.0, 0.37])
          for (final hueMode in BeamHueMode.values)
            BeamConfig.resolve(
              effect: effect,
              palette: BeamColors.colorful.resolve(),
              brightness: Brightness.dark,
              style: BeamStyle(hueMode: hueMode, hueShift: 24),
              timing: BeamTiming(
                cycle: const Duration(milliseconds: 1700),
                cycleGap: gap,
                direction: direction,
                phaseOffset: phaseOffset,
                huePeriod: const Duration(milliseconds: 5300),
              ),
            ),
  ];

  String describe(BeamConfig c) =>
      '${c.effect} ${c.direction.name} gap=${c.gapSeconds} '
      'offset=${c.phaseOffset} hue=${c.hueMode.name}';

  void expectIdentical(BeamFramePhases a, BeamFramePhases b, String at) {
    expect(a.fadeOpacity, b.fadeOpacity, reason: 'fadeOpacity $at');
    expect(a.hueDegrees, b.hueDegrees, reason: 'hueDegrees $at');
    expect(a.travelProgress, b.travelProgress, reason: 'travel $at');
    expect(a.travellers, b.travellers, reason: 'travellers $at');
    expect(a.reversedNow, b.reversedNow, reason: 'reversedNow $at');
    expect(a.finished, b.finished, reason: 'finished $at');
    expect(a.cycles, b.cycles, reason: 'cycles $at');
    expect(a.driven, b.driven, reason: 'driven $at');
  }

  /// Distance between two sweep positions around the ring.
  double ringDistance(double a, double b) => ((a - b + 0.5) % 1 - 0.5).abs();

  for (final effect in effects) {
    final configs = configsFor(effect);

    group('$effect', () {
      test('purity: the same inputs give the same frame', () {
        final random = math.Random(0x5EED);
        for (final config in configs) {
          final resolver = BeamPhaseResolver(config)..repeatCycles = 3;
          // A second resolver over the same config must agree too: nothing
          // is carried from one frame to the next.
          final twin = BeamPhaseResolver(config)..repeatCycles = 3;
          for (var i = 0; i < samplesPerConfig; i++) {
            final t = random.nextDouble() * 1000;
            final fade = random.nextDouble();
            final progress = random.nextBool() ? random.nextDouble() : null;
            final first = resolver.sample(t, fade, progress: progress);
            final at = '${describe(config)} t=$t';
            expectIdentical(
              first,
              resolver.sample(t, fade, progress: progress),
              at,
            );
            expectIdentical(
              first,
              twin.sample(t, fade, progress: progress),
              at,
            );
          }
        }
      });

      test('ranges: every field stays in bounds', () {
        final random = math.Random(0xA11CE);
        for (final config in configs) {
          final resolver = BeamPhaseResolver(config);
          for (var i = 0; i < samplesPerConfig; i++) {
            final t = random.nextDouble() * 5000;
            final fade = random.nextDouble();
            final p = resolver.sample(t, fade);
            final at = '${describe(config)} t=$t';

            expect(p.fadeOpacity.isFinite, isTrue, reason: at);
            expect(p.fadeOpacity, inInclusiveRange(0, 1), reason: at);
            expect(p.fadeOpacity, lessThanOrEqualTo(fade), reason: at);
            if (!effect.travels) {
              expect(p.fadeOpacity, fade, reason: 'ambient never rests $at');
            }

            expect(p.travelProgress, inInclusiveRange(0, 1), reason: at);
            expect(p.travellers, hasLength(config.beamCount), reason: at);
            expect(p.travellers.first, p.travelProgress, reason: at);
            for (final traveller in p.travellers) {
              expect(traveller.isFinite, isTrue, reason: at);
              expect(traveller, inInclusiveRange(0, 1), reason: at);
            }
            if (!effect.travels) {
              expect(p.travelProgress, 0, reason: at);
            }

            expect(p.hueDegrees.isFinite, isTrue, reason: at);
            switch (config.hueMode) {
              case BeamHueMode.none:
                expect(p.hueDegrees, 0, reason: at);
              case BeamHueMode.continuous:
                expect(p.hueDegrees, greaterThanOrEqualTo(0), reason: at);
                expect(p.hueDegrees, lessThan(360), reason: at);
              case BeamHueMode.pingPong:
                expect(
                  p.hueDegrees,
                  inInclusiveRange(
                    -config.hueShift - 1e-9,
                    config.hueShift + 1e-9,
                  ),
                  reason: at,
                );
            }

            expect(p.cycles.isFinite, isTrue, reason: at);
            expect(p.cycles, greaterThanOrEqualTo(0), reason: at);
            expect(p.driven, isFalse, reason: at);
          }
        }
      });

      test('cycles: advances by exactly 1 per cycle', () {
        final random = math.Random(0xC1C1E);
        for (final config in configs) {
          final resolver = BeamPhaseResolver(config);
          for (var i = 0; i < samplesPerConfig; i++) {
            final t = random.nextDouble() * 1000;
            final k = 1 + random.nextInt(20);
            expect(
              resolver.sample(t + k * config.cycleSeconds, 1).cycles -
                  resolver.sample(t, 1).cycles,
              closeTo(k, 1e-9),
              reason: '${describe(config)} t=$t k=$k',
            );
          }
        }
      });

      if (effect.travels) {
        test('periodicity: the travel repeats every cycle + gap', () {
          final random = math.Random(0xC0FFEE);
          for (final config in configs) {
            final resolver = BeamPhaseResolver(config);
            final cycle = config.cycleSeconds + config.gapSeconds;
            // Bounce only repeats after a forward and a reverse cycle.
            final period = config.direction == BeamDirection.bounce
                ? 2 * cycle
                : cycle;
            final shift = config.phaseOffset * config.cycleSeconds;
            for (var i = 0; i < samplesPerConfig; i++) {
              // A position within the period, clear of the boundaries
              // between cycles, so float rounding of the modulo cannot land
              // the two reads on opposite sides of a wrap.
              final whichCycle = config.direction == BeamDirection.bounce
                  ? random.nextInt(2)
                  : 0;
              final local =
                  (whichCycle + 0.02 + random.nextDouble() * 0.96) * cycle;
              final t = period + local - shift;
              final later = t + (1 + random.nextInt(20)) * period;
              final a = resolver.sample(t, 1);
              final b = resolver.sample(later, 1);
              final at = '${describe(config)} t=$t vs $later';

              expect(
                b.travelProgress,
                closeTo(a.travelProgress, 1e-6),
                reason: 'travelProgress $at',
              );
              expect(
                b.fadeOpacity,
                closeTo(a.fadeOpacity, 1e-6),
                reason: 'fadeOpacity $at',
              );
              expect(b.reversedNow, a.reversedNow, reason: 'reversed $at');
              expect(b.travellers, hasLength(a.travellers.length));
              for (var j = 0; j < a.travellers.length; j++) {
                expect(
                  ringDistance(a.travellers[j], b.travellers[j]),
                  lessThan(1e-6),
                  reason: 'traveller $j $at',
                );
              }
            }
          }
        });
      }
    });
  }
}
