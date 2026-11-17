import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';

import 'wave_test_utils.dart';

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

  group('lookup', () {
    testWidgets('of is empty and maybeOf null without a theme', (tester) async {
      late DistortionWaveThemeData data;
      late DistortionWaveThemeData? maybe;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            data = DistortionWaveTheme.of(context);
            maybe = DistortionWaveTheme.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(data, const DistortionWaveThemeData());
      expect(maybe, isNull);
    });

    testWidgets('nested themes merge outside-in', (tester) async {
      late DistortionWaveThemeData data;
      await tester.pumpWidget(
        DistortionWaveTheme(
          data: const DistortionWaveThemeData(
            style: WaveStyle(
              palette: WavePalette.ocean,
              lens: WaveLens(blur: 9),
            ),
            snapshots: WaveSnapshots.everyFrame,
          ),
          child: DistortionWaveTheme(
            data: const DistortionWaveThemeData(
              style: WaveStyle(lens: WaveLens(blur: 4)),
            ),
            child: Builder(
              builder: (context) {
                data = DistortionWaveTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(
        data.style,
        const WaveStyle(palette: WavePalette.ocean, lens: WaveLens(blur: 4)),
        reason: 'the inner style merges over the outer one, field by field',
      );
      expect(
        data.snapshots,
        WaveSnapshots.everyFrame,
        reason: 'fields the inner theme omits',
      );
    });
  });

  group('inheritance through a wave', () {
    Widget wave({WaveSnapshots? snapshots}) => DistortionWave(
      progress: 0.3,
      snapshots: snapshots,
      revealedChild: flatSide(incomingColor, 'in'),
      child: flatSide(outgoingColor, 'out'),
    );

    testWidgets('changing an outer theme rebuilds a wave under an inner one', (
      tester,
    ) async {
      useWaveView(tester);
      // All const below the outer theme, so only the theme's dependency
      // rebuilds the wave.
      Widget build(WavePalette palette) => waveHost(
        DistortionWaveTheme(
          data: DistortionWaveThemeData(style: WaveStyle(palette: palette)),
          child: const DistortionWaveTheme(
            data: DistortionWaveThemeData(
              style: WaveStyle(lens: WaveLens(blur: 9)),
            ),
            child: DistortionWave(
              progress: 0.3,
              revealedChild: ColoredBox(color: incomingColor),
              child: ColoredBox(color: outgoingColor),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(WavePalette.ocean));
      expect(waveStage(tester).spec.palette, WavePalette.ocean);

      await tester.pumpWidget(build(WavePalette.sunset));
      expect(waveStage(tester).spec.palette, WavePalette.sunset);
      expect(waveStage(tester).spec.blur, 9, reason: 'the inner theme holds');
    });

    testWidgets("a theme's snapshots reach a wave that sets none, and the "
        "wave's win", (tester) async {
      useWaveView(tester);
      Widget build({WaveSnapshots? own}) => waveHost(
        DistortionWaveTheme(
          data: const DistortionWaveThemeData(
            snapshots: WaveSnapshots.everyFrame,
          ),
          child: DistortionWaveTheme(
            data: const DistortionWaveThemeData(
              style: WaveStyle(palette: WavePalette.ocean),
            ),
            child: wave(snapshots: own),
          ),
        ),
      );
      await tester.pumpWidget(build());
      expect(waveStage(tester).snapshots, WaveSnapshots.everyFrame);

      await tester.pumpWidget(build(own: WaveSnapshots.onChange));
      expect(waveStage(tester).snapshots, WaveSnapshots.onChange);
    });
  });
}
