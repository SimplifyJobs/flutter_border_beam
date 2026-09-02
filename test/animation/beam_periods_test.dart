import 'dart:ui';

import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_style.dart';
import 'package:flutter_border_beam/src/models/beam_timing.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_test/flutter_test.dart';

BeamConfig _config(
  BeamVariant variant, {
  BeamTiming timing = const BeamTiming(),
  double hueRange = 30,
}) => BeamConfig.resolve(
  variant: variant,
  palette: BeamColors.colorful.resolve(),
  brightness: Brightness.dark,
  style: BeamStyle(hueRange: hueRange),
  timing: timing,
);

BeamPhaseResolver _resolver(
  BeamVariant variant, {
  BeamTiming timing = const BeamTiming(),
  double hueRange = 30,
}) => BeamPhaseResolver(_config(variant, timing: timing, hueRange: hueRange));

/// `BeamTiming` exposes the tracks that do not ride the cycle: the hue
/// ping-pong (or revolution), the line bloom's own hue, and the line's
/// breathe/spike periods expressed as multiples of the cycle. Each was a
/// fixed constant in the phase resolver before; each must now follow what
/// the timing asks for, and only that track.
void main() {
  group('huePeriod', () {
    test('the traveling default is a 12s ping-pong', () {
      final config = _config(BeamVariant.rotate);
      expect(config.huePeriodSeconds, 12);
      final r = BeamPhaseResolver(config);
      expect(r.sample(0, 1).hueDegrees, closeTo(-30, 1e-9));
      expect(r.sample(6, 1).hueDegrees, closeTo(30, 1e-6));
    });

    test('a custom period puts +hueRange at half of it', () {
      const timing = BeamTiming(huePeriod: Duration(seconds: 4));
      final config = _config(BeamVariant.rotate, timing: timing);
      expect(config.huePeriodSeconds, closeTo(4, 1e-9));
      final r = BeamPhaseResolver(config);
      expect(r.sample(0, 1).hueDegrees, closeTo(-30, 1e-9));
      expect(r.sample(2, 1).hueDegrees, closeTo(30, 1e-6));
      expect(r.sample(4, 1).hueDegrees, closeTo(-30, 1e-6));
      expect(
        r.sample(1, 1).hueDegrees,
        closeTo(0, 1e-6),
        reason: 'the ease-in-out curve crosses zero at a quarter period',
      );
    });

    test('it does not move the cycle-driven tracks', () {
      final fast = _resolver(
        BeamVariant.rotate,
        timing: const BeamTiming(huePeriod: Duration(seconds: 3)),
      );
      final slow = _resolver(
        BeamVariant.rotate,
        timing: const BeamTiming(huePeriod: Duration(seconds: 30)),
      );
      expect(
        fast.sample(1.2, 1).angleRadians,
        closeTo(slow.sample(1.2, 1).angleRadians, 1e-9),
      );
      expect(
        fast.sample(1.2, 1).hueDegrees,
        isNot(closeTo(slow.sample(1.2, 1).hueDegrees, 1e-3)),
      );
    });

    test('the pulse defaults are the preset periods', () {
      expect(_config(BeamVariant.pulseInside).huePeriodSeconds, 16);
      expect(_config(BeamVariant.pulseOutside).huePeriodSeconds, 14);
      // A continuous revolution, not a ping-pong.
      expect(
        _resolver(BeamVariant.pulseInside).sample(8, 1).hueDegrees,
        closeTo(180, 1e-6),
      );
      expect(
        _resolver(BeamVariant.pulseOutside).sample(7, 1).hueDegrees,
        closeTo(180, 1e-6),
      );
    });

    test('a custom period replaces the pulse preset period', () {
      const timing = BeamTiming(huePeriod: Duration(seconds: 5));
      for (final variant in [
        BeamVariant.pulseInside,
        BeamVariant.pulseOutside,
      ]) {
        final config = _config(variant, timing: timing);
        expect(config.huePeriodSeconds, closeTo(5, 1e-9), reason: '$variant');
        final r = BeamPhaseResolver(config);
        expect(r.sample(1.25, 1).hueDegrees, closeTo(90, 1e-6));
        expect(r.sample(2.5, 1).hueDegrees, closeTo(180, 1e-6));
        expect(
          r.sample(5, 1).hueDegrees,
          closeTo(0, 1e-6),
          reason: 'it wraps at the custom period, not at 14s or 16s',
        );
      }
    });

    test('a sub-second period is still a full ping-pong', () {
      final r = _resolver(
        BeamVariant.small,
        timing: const BeamTiming(huePeriod: Duration(milliseconds: 200)),
      );
      expect(r.sample(0.1, 1).hueDegrees, closeTo(30, 1e-6));
      expect(r.sample(0.2, 1).hueDegrees, closeTo(-30, 1e-6));
    });
  });

  group('bloomHuePeriod', () {
    // The line variant caps hueRange at 13°, so its bloom track spans ±23°.
    const bloomRange = 23.0;

    test('the default is an 8s ping-pong over ±(hueRange + 10)', () {
      final config = _config(BeamVariant.line);
      expect(config.bloomHuePeriodSeconds, 8);
      final r = BeamPhaseResolver(config);
      expect(r.sample(0, 1).bloomHueDegrees, closeTo(-bloomRange, 1e-9));
      expect(r.sample(4, 1).bloomHueDegrees, closeTo(bloomRange, 1e-6));
    });

    test('a custom period retimes only the bloom hue', () {
      const timing = BeamTiming(bloomHuePeriod: Duration(seconds: 4));
      final config = _config(BeamVariant.line, timing: timing);
      expect(config.bloomHuePeriodSeconds, closeTo(4, 1e-9));
      expect(config.huePeriodSeconds, 12, reason: 'the main hue is untouched');

      final r = BeamPhaseResolver(config);
      final reference = _resolver(BeamVariant.line);
      expect(r.sample(2, 1).bloomHueDegrees, closeTo(bloomRange, 1e-6));
      expect(
        r.sample(1.3, 1).hueDegrees,
        closeTo(reference.sample(1.3, 1).hueDegrees, 1e-9),
      );
      expect(
        r.sample(1.3, 1).lineX,
        closeTo(reference.sample(1.3, 1).lineX, 1e-9),
      );
    });

    test('a wider hueRange is capped before the bloom range is derived', () {
      final r = _resolver(BeamVariant.line, hueRange: 90);
      expect(r.config.hueRange, 13);
      expect(r.sample(4, 1).bloomHueDegrees, closeTo(bloomRange, 1e-6));
    });
  });

  group('line breathe and spike factors', () {
    const cycle = Duration(seconds: 2);
    const cycleSeconds = 2.0;

    test('the defaults are 1.3, 1.33 and 1.7 cycles', () {
      final config = _config(
        BeamVariant.line,
        timing: const BeamTiming(cycle: cycle),
      );
      expect(config.breatheFactor, 1.3);
      expect(config.spikeFactor, 1.33);
      expect(config.spike2Factor, 1.7);
    });

    test('lineH completes one breathe cycle at cycle × breatheFactor', () {
      const factor = 2.0;
      final r = _resolver(
        BeamVariant.line,
        timing: const BeamTiming(cycle: cycle, breatheFactor: factor),
      );
      const period = cycleSeconds * factor;
      for (final t in [0.0, 0.7, 1.9, 3.4]) {
        expect(
          r.sample(t + period, 1).lineH,
          closeTo(r.sample(t, 1).lineH, 1e-9),
          reason: 't=$t repeats after $period s',
        );
      }
      expect(
        r.sample(period / 2, 1).lineH,
        isNot(closeTo(r.sample(0, 1).lineH, 1e-3)),
        reason: 'the track actually moves inside the period',
      );
    });

    test('halving the factor halves the time to the same breathe phase', () {
      final slow = _resolver(
        BeamVariant.line,
        timing: const BeamTiming(cycle: cycle, breatheFactor: 2),
      );
      final fast = _resolver(
        BeamVariant.line,
        timing: const BeamTiming(cycle: cycle, breatheFactor: 1),
      );
      expect(slow.sample(2, 1).lineH, closeTo(fast.sample(1, 1).lineH, 1e-9));
    });

    test('spikeFactor and spike2Factor drive their own tracks only', () {
      final base = _resolver(
        BeamVariant.line,
        timing: const BeamTiming(cycle: cycle),
      );
      final spiked = _resolver(
        BeamVariant.line,
        timing: const BeamTiming(cycle: cycle, spikeFactor: 3),
      );
      final spiked2 = _resolver(
        BeamVariant.line,
        timing: const BeamTiming(cycle: cycle, spike2Factor: 3),
      );

      const t = 1.1;
      expect(
        spiked.sample(t, 1).spike,
        isNot(closeTo(base.sample(t, 1).spike, 1e-3)),
      );
      expect(
        spiked.sample(t, 1).spike2,
        closeTo(base.sample(t, 1).spike2, 1e-9),
      );
      expect(spiked.sample(t, 1).lineH, closeTo(base.sample(t, 1).lineH, 1e-9));

      expect(
        spiked2.sample(t, 1).spike2,
        isNot(closeTo(base.sample(t, 1).spike2, 1e-3)),
      );
      expect(
        spiked2.sample(t, 1).spike,
        closeTo(base.sample(t, 1).spike, 1e-9),
      );

      const period = cycleSeconds * 3;
      expect(
        spiked.sample(0.4 + period, 1).spike,
        closeTo(spiked.sample(0.4, 1).spike, 1e-9),
      );
      expect(
        spiked2.sample(0.4 + period, 1).spike2,
        closeTo(spiked2.sample(0.4, 1).spike2, 1e-9),
      );
    });

    test('the factors scale with the cycle they multiply', () {
      final short = _resolver(
        BeamVariant.line,
        timing: const BeamTiming(cycle: Duration(seconds: 1), breatheFactor: 2),
      );
      final long = _resolver(
        BeamVariant.line,
        timing: const BeamTiming(cycle: Duration(seconds: 2), breatheFactor: 2),
      );
      expect(
        long.sample(2.4, 1).lineH,
        closeTo(short.sample(1.2, 1).lineH, 1e-9),
        reason: 'twice the cycle is twice the breathe period',
      );
    });
  });
}
