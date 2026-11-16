@Tags(['golden'])
library;

import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'golden_scene.dart';

/// The motion family: travel direction, several beams on one border, the
/// rest between sweeps, phase offset, and a sweep driven from a value
/// instead of the clock.
///
/// Dark theme, colorful palette, t = 1.3s unless a scene says otherwise, so
/// each image reads against the plain `<effect>_dark_colorful` frame it
/// varies.
void main() {
  setUpAll(BorderBeam.precache);

  Widget beam(BeamEffect effect, {BeamTiming? timing, double? progress}) =>
      goldenScene(
        BorderBeam(
          effect: effect,
          borderRadius: 16,
          style: const BeamStyle(theme: BeamTheme.dark),
          timing: timing,
          progress: progress,
          child: mockSurface(Brightness.dark),
        ),
      );

  const reverse = BeamTiming(direction: BeamDirection.reverse);

  // The mirror of `rotate_dark_colorful`: same instant, the head the same
  // distance round the border, the other way.
  testWidgets('rotate reverse', (tester) async {
    await captureGolden(
      tester,
      'motion_rotate_reverse',
      beam(const BeamEffect.rotate(), timing: reverse),
    );
  });

  testWidgets('line reverse', (tester) async {
    await captureGolden(
      tester,
      'motion_line_reverse',
      beam(const BeamEffect.line(), timing: reverse),
    );
  });

  // Bounce runs its second cycle backwards: 0.4s into it.
  testWidgets('rotate bounce, second cycle', (tester) async {
    await captureGolden(
      tester,
      'motion_rotate_bounce_second_cycle',
      beam(
        const BeamEffect.rotate(),
        timing: const BeamTiming(
          cycle: Duration(seconds: 1),
          direction: BeamDirection.bounce,
        ),
      ),
      freeze: const Duration(milliseconds: 1400),
    );
  });

  for (final count in [2, 4]) {
    testWidgets('rotate count $count', (tester) async {
      await captureGolden(
        tester,
        'motion_rotate_count_$count',
        beam(BeamEffect.rotate(count: count)),
      );
    });
  }

  testWidgets('rotate phase offset', (tester) async {
    await captureGolden(
      tester,
      'motion_rotate_phase_offset_half',
      beam(
        const BeamEffect.rotate(),
        timing: const BeamTiming(phaseOffset: 0.5),
      ),
    );
  });

  // A 1s sweep and a 1s rest, caught 0.1s into the rest: parked at the end
  // of its travel and fading out.
  testWidgets('rotate cycle gap', (tester) async {
    await captureGolden(
      tester,
      'motion_rotate_cycle_gap_fading',
      beam(
        const BeamEffect.rotate(),
        timing: const BeamTiming(
          cycle: Duration(seconds: 1),
          cycleGap: Duration(seconds: 1),
        ),
      ),
      freeze: const Duration(milliseconds: 1100),
    );
  });

  for (final effect in const [BeamEffect.rotate(), BeamEffect.line()]) {
    testWidgets('${effect.name} progress 0.5', (tester) async {
      await captureGolden(
        tester,
        'motion_progress_${effect.name}_0_5',
        beam(effect, progress: 0.5),
      );
    });
  }
}
