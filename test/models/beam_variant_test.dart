import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// `BeamVariant` carries every per-variant default a beam resolves against,
/// so tooling reads them from the enum rather than transcribing them out of
/// doc comments.
void main() {
  group('BeamVariant', () {
    test('isPulse splits the two families', () {
      expect(BeamVariant.rotate.isPulse, isFalse);
      expect(BeamVariant.small.isPulse, isFalse);
      expect(BeamVariant.line.isPulse, isFalse);
      expect(BeamVariant.pulseInside.isPulse, isTrue);
      expect(BeamVariant.pulseOutside.isPulse, isTrue);
    });

    test('cycle, radius, and border width match the source presets', () {
      expect(
        BeamVariant.rotate.defaultCycleDuration,
        const Duration(milliseconds: 1960),
      );
      expect(
        BeamVariant.small.defaultCycleDuration,
        const Duration(milliseconds: 1960),
      );
      expect(
        BeamVariant.line.defaultCycleDuration,
        const Duration(milliseconds: 3100),
      );
      expect(
        BeamVariant.pulseInside.defaultCycleDuration,
        const Duration(milliseconds: 2300),
      );
      expect(
        BeamVariant.pulseOutside.defaultCycleDuration,
        const Duration(milliseconds: 2300),
      );
      expect(BeamVariant.small.defaultBorderRadius, 32);
      for (final variant in BeamVariant.values) {
        if (variant != BeamVariant.small) {
          expect(variant.defaultBorderRadius, 16, reason: '$variant');
        }
        expect(variant.defaultBorderWidth, 1, reason: '$variant');
      }
    });

    test('the traveling variants share the 12s hue period', () {
      for (final variant in [
        BeamVariant.rotate,
        BeamVariant.small,
        BeamVariant.line,
      ]) {
        expect(
          variant.defaultHuePeriod,
          const Duration(seconds: 12),
          reason: '$variant',
        );
      }
    });

    test('the pulse variants carry their own hue periods', () {
      expect(
        BeamVariant.pulseInside.defaultHuePeriod,
        const Duration(seconds: 16),
      );
      expect(
        BeamVariant.pulseOutside.defaultHuePeriod,
        const Duration(seconds: 14),
      );
    });

    test('the bloom hue period is 8s for every variant', () {
      for (final variant in BeamVariant.values) {
        expect(
          variant.defaultBloomHuePeriod,
          const Duration(seconds: 8),
          reason: '$variant',
        );
      }
    });
  });
}
