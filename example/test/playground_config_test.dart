import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam_example/src/playground/playground_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The playground hands the widget four value objects it assembled itself, so
/// a gating mistake there is a beam that throws rather than a snippet that
/// reads oddly. These mount the extremes the controls can reach.
void main() {
  Future<void> pumpConfig(
    WidgetTester tester,
    PlaygroundState state, {
    bool reducedMotion = false,
  }) async {
    Widget beam = SizedBox(
      width: 320,
      height: 128,
      child: BorderBeam(
        variant: state.variant,
        active: state.buildActive(),
        style: state.buildStyle(),
        shape: state.buildShape(),
        timing: state.buildTiming(),
        playback: state.buildPlayback(),
        progress: state.buildProgress(),
        child: const SizedBox.expand(),
      ),
    );
    if (reducedMotion) {
      beam = MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: beam,
      );
    }
    await tester.pumpWidget(MaterialApp(home: Center(child: beam)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    // Unmount so no ticker outlives the test.
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('a rotate beam with every ring control at once paints', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..palette = PalettePreset.lerp
        ..alphaScale = 0.7
        ..radius = 24
        ..superellipse = true
        ..borderWidth = 3
        ..ringOffset = 8
        ..contour = true
        ..hueMode = BeamHueMode.continuous
        ..tailLength = 1.8
        ..glowSpread = 2.5
        ..comet = true
        ..sparkle = 1
        ..segments = 16
        ..renderScale = 0.5
        ..direction = BeamDirection.bounce
        ..phaseOffset = 0.75
        ..beamCount = 4
        ..repeatCycles = 3
        ..cssFadeCurve = true
        ..pauseWhenOffscreen = true,
    );
  });

  testWidgets('a line beam on a non-default edge, with a contour, paints', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..variant = BeamVariant.line
        ..palette = PalettePreset.seed
        ..seedHarmony = BeamSeedHarmony.complementary
        ..edge = BeamEdge.right
        ..contour = true
        ..stadium = true
        ..sparkle = 0.6
        ..beamCount = 3
        ..cycleGapSeconds = 0.5,
    );
  });

  testWidgets('the stock pulse-outside recipe paints, tuned over', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..variant = BeamVariant.pulseOutside
        ..stockPulseOutside = true
        ..glowBoost = 1.6
        ..coreBlur = 24
        ..bloomBlur = 90
        ..segments = 12
        ..renderScale = 0.75,
    );
  });

  testWidgets('pulse-inside honours the inner wash scale', (tester) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..variant = BeamVariant.pulseInside
        ..innerSizeScale = 2
        ..glowBoost = 2.5
        ..perCorner = true
        ..radiusTopLeft = 0
        ..radiusBottomRight = 48,
    );
  });

  testWidgets('a progress-driven beam under reduced motion paints', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..driveProgress = true
        ..progress = 0.9
        ..reducedMotion = BeamReducedMotion.slow
        ..strength = 0.4,
      reducedMotion: true,
    );
  });

  testWidgets('a hidden beam under reduced motion paints nothing and does '
      'not throw', (tester) async {
    await pumpConfig(
      tester,
      PlaygroundState()..reducedMotion = BeamReducedMotion.hide,
      reducedMotion: true,
    );
  });
}
