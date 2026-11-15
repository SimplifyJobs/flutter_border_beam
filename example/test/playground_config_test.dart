import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam_example/src/playground/playground_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The playground hands the widget an effect and four value objects it
/// assembled itself, so a gating mistake there is a beam that throws rather
/// than a snippet that reads oddly. These mount the extremes the controls
/// can reach.
void main() {
  setUpAll(BorderBeam.precache);

  Future<void> pumpConfig(
    WidgetTester tester,
    PlaygroundState state, {
    bool reducedMotion = false,
  }) async {
    Widget beam = SizedBox(
      width: 320,
      height: 128,
      child: BorderBeam(
        effect: state.buildEffect(),
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

  testWidgets('every effect paints with its defaults', (tester) async {
    for (final kind in EffectKind.values) {
      await pumpConfig(tester, PlaygroundState()..effect = kind);
    }
  });

  testWidgets('a rotate beam with every ring control at once paints', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..rotateLength = 2
        ..rotateCount = 4
        ..rotateComet = true
        ..paletteMode = PaletteMode.lerp
        ..lerpFrom = 'cosmic'
        ..lerpTo = 'citrus'
        ..alphaScale = 0.7
        ..radius = 24
        ..superellipse = true
        ..borderWidth = 3
        ..ringOffset = 8
        ..dashes = 24
        ..hueMode = BeamHueMode.continuous
        ..glow = 3
        ..direction = BeamDirection.bounce
        ..phaseOffset = 0.75
        ..repeatCycles = 3
        ..cssFadeCurve = true
        ..pauseWhenOffscreen = true,
    );
  });

  testWidgets('a line beam on a side edge, in a stadium, paints', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..effect = EffectKind.line
        ..lineEdge = BeamEdge.right
        ..paletteMode = PaletteMode.seed
        ..seedHarmony = BeamSeedHarmony.complementary
        ..stadium = true
        ..cycleGapSeconds = 0.5
        ..beamTheme = BeamTheme.light,
    );
  });

  testWidgets('a steep shimmer under a custom segment paints', (tester) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..effect = EffectKind.shimmer
        ..shimmerAngle = -90
        ..paletteMode = PaletteMode.custom
        ..customColors = [0, 1, 2, 3, 4, 5]
        ..segmentPreset = SegmentPreset.custom
        ..segmentFeather = 0
        ..cycleGapSeconds = 0,
    );
  });

  testWidgets('a halo pulled inside, per corner, with no glow paints', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..effect = EffectKind.halo
        ..glow = 0
        ..ringOffset = -12
        ..perCorner = true
        ..radiusTopLeft = 0
        ..radiusBottomRight = 48,
    );
  });

  testWidgets('a progress-driven charge under reduced motion paints', (
    tester,
  ) async {
    await pumpConfig(
      tester,
      PlaygroundState()
        ..effect = EffectKind.charge
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
