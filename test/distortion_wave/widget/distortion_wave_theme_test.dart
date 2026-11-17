import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';

/// `DistortionWaveThemeData` and `DistortionWaveTheme`: a field left null
/// inherits, from an enclosing theme and then from the type's defaults.
void main() {
  group('DistortionWaveThemeData', () {
    const full = DistortionWaveThemeData(
      style: WaveStyle(palette: WavePalette.ocean, lens: WaveLens(blur: 9)),
      snapshots: WaveSnapshots.everyFrame,
    );

    test('merge layers the other data over this one, field by field', () {
      final merged = full.merge(
        const DistortionWaveThemeData(
          style: WaveStyle(lens: WaveLens(blur: 4)),
        ),
      );
      expect(
        merged.style,
        const WaveStyle(palette: WavePalette.ocean, lens: WaveLens(blur: 4)),
      );
      expect(merged.snapshots, WaveSnapshots.everyFrame);
    });

    test('merge fills slots this data leaves empty', () {
      expect(const DistortionWaveThemeData().merge(full), full);
    });

    test('merge keeps an unset style unset', () {
      final merged = const DistortionWaveThemeData().merge(
        const DistortionWaveThemeData(snapshots: WaveSnapshots.everyFrame),
      );
      expect(merged.style, isNull);
      expect(merged.snapshots, WaveSnapshots.everyFrame);
    });

    test('merging null is the identity', () {
      expect(identical(full.merge(null), full), isTrue);
    });
  });
}
