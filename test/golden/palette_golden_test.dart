@Tags(['golden'])
library;

import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'golden_scene.dart';

/// The palette family: every preset, and every way of building or
/// transforming colours, on one effect.
///
/// The pulse lights the whole border at once, and with the hue drift off
/// each image is the palette itself rather than a glimpse of it. Dark theme,
/// t = 1.3s.
void main() {
  setUpAll(BorderBeam.precache);

  Widget ring(BeamColors colors, {BeamStyle style = const BeamStyle()}) =>
      goldenScene(
        BorderBeam(
          effect: const BeamEffect.pulse(),
          colors: colors,
          borderRadius: 16,
          style: style.copyWith(
            theme: BeamTheme.dark,
            hueMode: BeamHueMode.none,
          ),
          child: mockSurface(Brightness.dark),
        ),
      );

  for (final MapEntry(key: name, value: colors) in BeamColors.presets.entries) {
    testWidgets('preset $name', (tester) async {
      await captureGolden(tester, 'palette_$name', ring(colors));
    });
  }

  final built = <String, BeamColors>{
    'custom': const BeamColors([
      Color(0xFFFF2D95),
      Color(0xFF00E5FF),
      Color(0xFFFFC400),
    ]),
    'custom_stops': const BeamColors(
      [Color(0xFFFF2D95), Color(0xFF00E5FF), Color(0xFFFFC400)],
      stops: [0, 0.1, 0.5],
    ),
    'solid': const BeamColors.solid(Color(0xFF7C4DFF)),
    for (final harmony in BeamSeedHarmony.values)
      'seed_${harmony.name}': BeamColors.fromSeed(
        const Color(0xFF18A8F0),
        harmony: harmony,
      ),
    'scheme': BeamColors.fromScheme(
      ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
    ),
    'lerp_ocean_sunset': const BeamColors.lerp(
      BeamColors.ocean,
      BeamColors.sunset,
      0.5,
    ),
    'scale_alpha_half': BeamColors.colorful.scaleAlpha(0.5),
  };

  for (final MapEntry(key: name, value: colors) in built.entries) {
    testWidgets(name, (tester) async {
      await captureGolden(tester, 'palette_$name', ring(colors));
    });
  }

  testWidgets('hue base', (tester) async {
    await captureGolden(
      tester,
      'palette_colorful_hue_base_120',
      ring(BeamColors.colorful, style: const BeamStyle(hueBase: 120)),
    );
  });
}
