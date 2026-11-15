@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_scene.dart';

/// The effect family: every effect on both themes in the colorful palette,
/// the other three original palettes on the effects that show them best,
/// and the effect options.
///
/// All captured at t = 1.3s. A travelling effect is captured a second time
/// (`_late`) further along: one frame of a sweep says nothing about where it
/// is the rest of the time.
void main() {
  setUpAll(BorderBeam.precache);

  // Where the second capture of each travelling effect lands: late in a
  // rotate's turn and a line's sweep, halfway through a shimmer's second
  // sweep (its first is leaving the box at 1.3s), and a charge nearly full.
  const late = {
    'rotate': Duration(milliseconds: 2000),
    'line': Duration(milliseconds: 2000),
    'shimmer': Duration(milliseconds: 3700),
    'charge': Duration(milliseconds: 2200),
  };

  BeamTheme themeFor(Brightness b) =>
      b == Brightness.dark ? BeamTheme.dark : BeamTheme.light;

  Widget beam(
    BeamEffect effect,
    Brightness brightness, {
    BeamColors colors = BeamColors.colorful,
    BeamStyle style = const BeamStyle(),
    double radius = 16,
  }) => BorderBeam(
    effect: effect,
    colors: colors,
    borderRadius: radius,
    style: style.copyWith(theme: themeFor(brightness)),
    child: mockSurface(brightness, radius: radius),
  );

  for (final brightness in Brightness.values) {
    final theme = brightness.name;

    for (final effect in BeamEffect.values) {
      testWidgets('${effect.name} $theme colorful', (tester) async {
        await captureGolden(
          tester,
          '${effect.name}_${theme}_colorful',
          goldenScene(beam(effect, brightness), brightness: brightness),
        );
      });

      final later = late[effect.name];
      if (later != null) {
        testWidgets('${effect.name} $theme colorful late', (tester) async {
          await captureGolden(
            tester,
            '${effect.name}_${theme}_colorful_late',
            goldenScene(beam(effect, brightness), brightness: brightness),
            freeze: later,
          );
        });
      }
    }

    for (final effect in const [
      BeamEffect.rotate(),
      BeamEffect.line(),
      BeamEffect.pulse(),
      BeamEffect.halo(),
    ]) {
      for (final MapEntry(key: palette, value: colors) in {
        'mono': BeamColors.mono,
        'ocean': BeamColors.ocean,
        'sunset': BeamColors.sunset,
      }.entries) {
        testWidgets('${effect.name} $theme $palette', (tester) async {
          await captureGolden(
            tester,
            '${effect.name}_${theme}_$palette',
            goldenScene(
              beam(effect, brightness, colors: colors),
              brightness: brightness,
            ),
          );
        });
      }
    }

    // The small-chip size the old `small` variant was made for: rotate
    // scales its glow down with the box.
    testWidgets('rotate $theme chip', (tester) async {
      await captureGolden(
        tester,
        'rotate_${theme}_chip',
        goldenScene(
          beam(const BeamEffect.rotate(), brightness, radius: 18),
          brightness: brightness,
          size: const Size(70, 36),
        ),
      );
    });
  }

  testWidgets('rotate dark comet', (tester) async {
    await captureGolden(
      tester,
      'rotate_dark_comet',
      goldenScene(beam(const BeamEffect.rotate(comet: true), Brightness.dark)),
    );
  });

  testWidgets('rotate dark long tail', (tester) async {
    await captureGolden(
      tester,
      'rotate_dark_long_tail',
      goldenScene(beam(const BeamEffect.rotate(length: 2), Brightness.dark)),
    );
  });

  testWidgets('rotate dark glow 2', (tester) async {
    await captureGolden(
      tester,
      'rotate_dark_glow_2',
      goldenScene(
        beam(
          const BeamEffect.rotate(),
          Brightness.dark,
          style: const BeamStyle(glow: 2),
        ),
      ),
    );
  });

  testWidgets('shimmer dark steep', (tester) async {
    await captureGolden(
      tester,
      'shimmer_dark_angle_60',
      goldenScene(beam(const BeamEffect.shimmer(angle: 60), Brightness.dark)),
      freeze: late['shimmer']!,
    );
  });
}
