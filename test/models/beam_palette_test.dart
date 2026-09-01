import 'package:flutter/material.dart';
import 'package:flutter_border_beam/src/constants/palettes.dart';
import 'package:flutter_border_beam/src/models/beam_blob.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_palette.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a palette that differs from [colorfulPreset] only in the field the
/// caller replaces, so each equality test isolates one table.
BeamPresetData _presetWith({
  List<BeamBlob>? border,
  SpikeColors? spike,
  SpikeColors? spikeLt,
  List<BeamBlob>? smallBorder,
  List<BeamBlob>? smallInner,
  List<LineBlob>? lineDark,
  List<LineBlob>? lineLight,
  List<LineBlob>? lineInner,
  List<SpikePair>? lineBloomDark,
  List<SpikePair>? lineBloomLight,
}) => BeamPresetData(
  border: border ?? colorfulPreset.border,
  spike: spike ?? colorfulPreset.spike,
  spikeLt: spikeLt ?? colorfulPreset.spikeLt,
  smallBorder: smallBorder ?? colorfulPreset.smallBorder,
  smallInner: smallInner ?? colorfulPreset.smallInner,
  lineDark: lineDark ?? colorfulPreset.lineDark,
  lineLight: lineLight ?? colorfulPreset.lineLight,
  lineInner: lineInner ?? colorfulPreset.lineInner,
  lineBloomDark: lineBloomDark ?? colorfulPreset.lineBloomDark,
  lineBloomLight: lineBloomLight ?? colorfulPreset.lineBloomLight,
);

/// A copy of a blob list with one entry recolored — enough to break equality.
List<BeamBlob> _recolored(List<BeamBlob> source) => [
  source.first.withColor(const Color(0xFF010203)),
  ...source.skip(1),
];

void main() {
  group('BeamPresetData equality', () {
    test('a field-by-field copy of a preset is ==', () {
      final copy = _presetWith();
      expect(copy, colorfulPreset);
      expect(copy.hashCode, colorfulPreset.hashCode);
    });

    test('a rebuilt table with equal values is ==', () {
      // A fresh list of fresh blobs: nothing here is identical to the preset.
      final rebuilt = _presetWith(
        border: [for (final b in colorfulPreset.border) b.withColor(b.color)],
      );
      expect(identical(rebuilt.border, colorfulPreset.border), isFalse);
      expect(rebuilt, colorfulPreset);
      expect(rebuilt.hashCode, colorfulPreset.hashCode);
    });

    test('every table participates', () {
      final variants = <String, BeamPresetData>{
        'border': _presetWith(border: _recolored(colorfulPreset.border)),
        'spike': _presetWith(
          spike: const SpikeColors(
            primary: Color(0xFF010203),
            secondary: Color(0xFF040506),
          ),
        ),
        'spikeLt': _presetWith(
          spikeLt: const SpikeColors(
            primary: Color(0xFF010203),
            secondary: Color(0xFF040506),
          ),
        ),
        'smallBorder': _presetWith(
          smallBorder: _recolored(colorfulPreset.smallBorder),
        ),
        'smallInner': _presetWith(
          smallInner: _recolored(colorfulPreset.smallInner),
        ),
        'lineDark': _presetWith(
          lineDark: [
            colorfulPreset.lineDark.first.withColor(const Color(0xFF010203)),
            ...colorfulPreset.lineDark.skip(1),
          ],
        ),
        'lineLight': _presetWith(
          lineLight: [
            colorfulPreset.lineLight.first.withColor(const Color(0xFF010203)),
            ...colorfulPreset.lineLight.skip(1),
          ],
        ),
        'lineInner': _presetWith(
          lineInner: [
            colorfulPreset.lineInner.first.withColor(const Color(0xFF010203)),
            ...colorfulPreset.lineInner.skip(1),
          ],
        ),
        'lineBloomDark': _presetWith(
          lineBloomDark: [
            const SpikePair(Color(0xFF010203), Color(0xFF040506)),
            ...colorfulPreset.lineBloomDark.skip(1),
          ],
        ),
        'lineBloomLight': _presetWith(
          lineBloomLight: [
            const SpikePair(Color(0xFF010203), Color(0xFF040506)),
            ...colorfulPreset.lineBloomLight.skip(1),
          ],
        ),
      };
      for (final MapEntry(key: field, value: data) in variants.entries) {
        expect(data, isNot(colorfulPreset), reason: '$field ignored by ==');
      }
      // Each variant differs from every other, not just from the preset.
      expect(variants.values.toSet(), hasLength(variants.length));
    });

    test('a table of different length is not equal', () {
      expect(
        _presetWith(border: colorfulPreset.border.take(8).toList()),
        isNot(colorfulPreset),
      );
    });

    test('the presets differ from one another', () {
      expect({
        colorfulPreset,
        monoPreset,
        oceanPreset,
        sunsetPreset,
      }, hasLength(4));
    });
  });

  group('BeamPalette equality', () {
    test('compares tables and every paint-time modifier', () {
      const a = BeamPalette(data: colorfulPreset);
      const b = BeamPalette(data: colorfulPreset);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const BeamPalette(data: colorfulPreset, forcesStaticColors: true),
        ),
      );
      expect(
        a,
        isNot(const BeamPalette(data: colorfulPreset, opacityMultiplier: 0.5)),
      );
      expect(
        a,
        isNot(const BeamPalette(data: colorfulPreset, monoTreatment: true)),
      );
      expect(a, isNot(const BeamPalette(data: oceanPreset)));
      expect(a.toString(), contains('BeamPalette'));
    });

    test('a palette rebuilt from equal tables is ==', () {
      final rebuilt = BeamPalette(data: _presetWith());
      expect(rebuilt, const BeamPalette(data: colorfulPreset));
      expect(
        rebuilt.hashCode,
        const BeamPalette(data: colorfulPreset).hashCode,
      );
    });
  });

  group('the resolve memo', () {
    test('equal color choices resolve to the identical palette', () {
      // Two separately built — never identical — but equal instances.
      final a = BeamColors.custom([
        const Color(0xFF123456),
        const Color(0xFF654321),
      ]);
      final b = BeamColors.custom([
        const Color(0xFF123456),
        const Color(0xFF654321),
      ]);
      expect(identical(a, b), isFalse);
      expect(identical(a.resolve(), b.resolve()), isTrue);
    });

    test('every factory shares the memo', () {
      expect(
        identical(
          BeamColors.fromSeed(const Color(0xFF18A8F0)).resolve(),
          BeamColors.fromSeed(const Color(0xFF18A8F0)).resolve(),
        ),
        isTrue,
      );
      expect(
        identical(
          BeamColors.lerp(BeamColors.ocean, BeamColors.sunset, 0.5).resolve(),
          BeamColors.lerp(BeamColors.ocean, BeamColors.sunset, 0.5).resolve(),
        ),
        isTrue,
      );
      expect(
        identical(
          BeamColors.ocean.scaleAlpha(0.5).resolve(),
          BeamColors.ocean.scaleAlpha(0.5).resolve(),
        ),
        isTrue,
      );
      expect(
        identical(
          BeamColors.fromScheme(_scheme).resolve(),
          BeamColors.fromScheme(_scheme).resolve(),
        ),
        isTrue,
      );
    });

    test('unequal color choices resolve to different palettes', () {
      final a = BeamColors.custom(const [Color(0xFF123456)]);
      final b = BeamColors.custom(const [Color(0xFF654321)]);
      expect(identical(a.resolve(), b.resolve()), isFalse);
      expect(a.resolve(), isNot(b.resolve()));
      expect(
        identical(
          const BeamColors.fromSeed(
            Color(0xFF18A8F0),
            harmony: BeamSeedHarmony.triadic,
          ).resolve(),
          const BeamColors.fromSeed(Color(0xFF18A8F0)).resolve(),
        ),
        isFalse,
      );
    });

    test('presets keep one palette for the life of the isolate', () {
      final ocean = BeamColors.ocean.resolve();
      // Flood the value cache well past its bound; a preset must survive it.
      for (var i = 0; i < 200; i++) {
        BeamColors.custom([Color(0xFF000000 | i)]).resolve();
      }
      expect(identical(BeamColors.ocean.resolve(), ocean), isTrue);
    });

    test('the value cache is bounded and evicts least-recently-used first', () {
      // Distinct from every other key used in this file.
      BeamColors key(int i) => BeamColors.custom([Color(0xFF7F0000 | i)]);

      final oldest = key(0);
      final oldestPalette = oldest.resolve();
      final newest = key(32);
      // 32 further distinct palettes: the capacity, so `oldest` — never
      // touched again — falls off the front.
      for (var i = 1; i <= 32; i++) {
        key(i).resolve();
      }
      expect(
        identical(oldest.resolve(), oldestPalette),
        isFalse,
        reason: 'the least recently used entry should have been evicted',
      );
      // An evicted palette rebuilds to an equal one, so nothing observable
      // changes for a painter comparing configs.
      expect(oldest.resolve(), oldestPalette);
      // The most recent insert is still cached.
      expect(identical(newest.resolve(), key(32).resolve()), isTrue);
    });

    test('a hit refreshes the entry, so a re-read survives eviction', () {
      BeamColors key(int i) => BeamColors.custom([Color(0xFF3F0000 | i)]);
      final kept = key(0);
      final keptPalette = kept.resolve();
      for (var i = 1; i <= 24; i++) {
        key(i).resolve();
        // Touching `kept` moves it back to the most-recent end.
        kept.resolve();
      }
      expect(identical(kept.resolve(), keptPalette), isTrue);
    });
  });
}

const ColorScheme _scheme = ColorScheme.dark(
  primary: Color(0xFFFF0000),
  secondary: Color(0xFF00FF00),
  tertiary: Color(0xFF0000FF),
);
