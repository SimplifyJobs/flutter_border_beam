import 'package:flutter/widgets.dart';
import 'package:flutter_border_beam/src/constants/palettes.dart';
import 'package:flutter_border_beam/src/constants/pulse_tables.dart';
import 'package:flutter_border_beam/src/constants/theme_presets.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const presets = {
    'colorful': colorfulPreset,
    'mono': monoPreset,
    'ocean': oceanPreset,
    'sunset': sunsetPreset,
  };

  group('palette table shapes', () {
    for (final MapEntry(key: name, value: p) in presets.entries) {
      test('$name has the source table cardinalities', () {
        expect(p.border, hasLength(9));
        expect(p.smallBorder, hasLength(8));
        expect(p.smallInner, hasLength(8));
        expect(p.lineDark, hasLength(9));
        expect(p.lineLight, hasLength(9));
        expect(p.lineInner, hasLength(9));
        expect(p.lineBloomDark, hasLength(5));
        expect(p.lineBloomLight, hasLength(5));
      });

      test('$name shares the border geometry of the source', () {
        // Geometry (positions/sizes) is identical across presets — only
        // colors differ. Spot-check against colorful.
        for (final (i, blob) in p.border.indexed) {
          expect(blob.position, colorfulPreset.border[i].position);
          expect(blob.size, colorfulPreset.border[i].size);
        }
      });
    }

    test('spot-check verbatim values from styles.ts', () {
      // colorful border[0]: rgb(255,50,100) at 33% -7.4%, 70x40
      final b0 = colorfulPreset.border[0];
      expect(b0.color, const Color.fromRGBO(255, 50, 100, 1));
      expect(b0.position, const Offset(0.33, -0.074));
      expect(b0.size, const Size(70, 40));
      // ocean lineLight[8]: rgb(120,90,245) 30x30 at -110,-1
      final o8 = oceanPreset.lineLight[8];
      expect(o8.color, const Color.fromRGBO(120, 90, 245, 1));
      expect(o8.offsetX, -110);
      expect(o8.offsetY, -1);
      // sunset lineBloomDark[3]: rgba(255,120,50,0.91) / 0.45
      final s3 = sunsetPreset.lineBloomDark[3];
      expect(s3.color1.a, closeTo(0.91, 0.005));
      expect(s3.color2.a, closeTo(0.45, 0.005));
    });
  });

  group('pulse tables', () {
    test('cardinalities and index bounds', () {
      expect(pulseRingMap, hasLength(9));
      expect(pulseInnerSizes, hasLength(9));
      expect(pulseInnerBloom, hasLength(7));
      expect(pulseOuterCore, hasLength(8));
      expect(pulseOuterBloom, hasLength(7));
      for (final spec in [
        ...pulseInnerBloom,
        ...pulseOuterCore,
        ...pulseOuterBloom,
      ]) {
        expect(spec.ci, inInclusiveRange(0, 8));
      }
      // Outer tables always carry explicit positions.
      for (final spec in [...pulseOuterCore, ...pulseOuterBloom]) {
        expect(spec.x, isNotNull);
        expect(spec.y, isNotNull);
      }
    });
  });

  group('theme presets', () {
    test('every variant has dark and light entries', () {
      for (final v in BeamVariant.values) {
        expect(beamThemePresets[v], isNotNull, reason: '$v missing');
      }
    });

    test('verbatim spot checks', () {
      final lineDark = themePresetFor(BeamVariant.line, Brightness.dark);
      expect(lineDark.strokeOpacity, 1.14);
      final poLight = themePresetFor(
        BeamVariant.pulseOutside,
        Brightness.light,
      );
      expect(poLight.strokeOpacity, 1.96);
      expect(poLight.brightness, 1.7);
      expect(poLight.hairlineOpacity, 0);
    });
  });

  group('BeamColors', () {
    test('presets resolve with mono flags', () {
      final mono = BeamColors.mono.resolve();
      expect(mono.forcesStaticColors, isTrue);
      expect(mono.opacityMultiplier, 0.5);
      final colorful = BeamColors.colorful.resolve();
      expect(colorful.forcesStaticColors, isFalse);
      expect(colorful.opacityMultiplier, 1.0);
    });

    test('custom cycles colors and preserves preset alpha', () {
      const pink = Color(0xFFFF0080);
      const cyan = Color(0xFF00FFEE);
      final palette = const BeamColors.custom([pink, cyan]).resolve();
      expect(palette.data.border, hasLength(9));
      // Cycled: index 0 pink, 1 cyan, 2 pink...
      expect(palette.data.border[0].color.r, closeTo(pink.r, 1e-6));
      expect(palette.data.border[1].color.b, closeTo(cyan.b, 1e-6));
      // Geometry preserved from colorful preset.
      expect(palette.data.border[4].size, colorfulPreset.border[4].size);
      // Inner alpha pattern preserved (smallInner[0] alpha 0.5).
      expect(palette.data.smallInner[0].color.a, closeTo(0.5, 0.005));
    });
  });
}
