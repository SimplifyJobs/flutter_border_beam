import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';

/// `WavePalette`: the presets are DistortionWavesKit's, channel for
/// channel; `single` lightens ahead and deepens behind as the reference's
/// does; `fromBeamColors` carries a border-beam palette over.
void main() {
  /// [color]'s channels on the reference's 0–255 scale.
  List<int> rgb(Color color) => [
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
  ];

  /// The reference's `mixed(with:_:)`: a straight sRGB blend, per channel.
  Color mixed(Color a, Color b, double t) => Color.from(
    alpha: 1,
    red: a.r + (b.r - a.r) * t,
    green: a.g + (b.g - a.g) * t,
    blue: a.b + (b.b - a.b) * t,
  );

  void expectSameColor(Color actual, Color expected, String reason) {
    expect(actual.a, closeTo(expected.a, 1e-9), reason: '$reason alpha');
    expect(actual.r, closeTo(expected.r, 1e-9), reason: '$reason red');
    expect(actual.g, closeTo(expected.g, 1e-9), reason: '$reason green');
    expect(actual.b, closeTo(expected.b, 1e-9), reason: '$reason blue');
  }

  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);

  group('presets equal the reference', () {
    // `DistortionWavePalette`'s presets, as the Swift writes them.
    const swift = <String, (List<List<int>>, List<int>, List<int>)>{
      'colorful': (
        [
          [255, 201, 21],
          [126, 196, 255],
          [180, 40, 230],
          [235, 100, 160],
          [255, 176, 122],
          [154, 160, 255],
          [127, 217, 238],
        ],
        [255, 122, 182],
        [90, 190, 255],
      ),
      'green': (
        [
          [53, 186, 0],
          [140, 235, 90],
          [0, 196, 110],
          [190, 250, 130],
          [40, 160, 60],
          [110, 225, 160],
          [90, 210, 40],
        ],
        [196, 255, 120],
        [0, 150, 70],
      ),
      'ocean': (
        [
          [40, 120, 255],
          [90, 200, 255],
          [20, 80, 200],
          [120, 230, 240],
          [60, 150, 255],
          [150, 180, 255],
          [0, 180, 220],
        ],
        [150, 230, 255],
        [30, 70, 220],
      ),
      'sunset': (
        [
          [255, 140, 60],
          [255, 90, 120],
          [255, 200, 80],
          [240, 70, 90],
          [255, 170, 120],
          [220, 90, 200],
          [255, 120, 80],
        ],
        [255, 220, 120],
        [200, 60, 160],
      ),
      'mono': (
        [
          [240, 240, 245],
          [200, 205, 215],
          [255, 255, 255],
          [170, 175, 190],
          [225, 228, 235],
          [190, 195, 205],
          [245, 245, 250],
        ],
        [255, 255, 255],
        [160, 165, 180],
      ),
    };

    test('every preset is named, in order', () {
      expect(WavePalette.presets.keys, swift.keys);
      expect(WavePalette.presets['colorful'], same(WavePalette.colorful));
      expect(WavePalette.presets['green'], same(WavePalette.green));
      expect(WavePalette.presets['ocean'], same(WavePalette.ocean));
      expect(WavePalette.presets['sunset'], same(WavePalette.sunset));
      expect(WavePalette.presets['mono'], same(WavePalette.mono));
    });

    for (final MapEntry(key: name, value: (colors, ahead, behind))
        in swift.entries) {
      test(name, () {
        final palette = WavePalette.presets[name]!;
        expect(palette.colors.map(rgb).toList(), colors);
        expect(rgb(palette.ahead), ahead);
        expect(rgb(palette.behind), behind);
        for (final c in [...palette.colors, palette.ahead, palette.behind]) {
          expect(c.a, 1, reason: 'opaque');
        }
        expect(palette.colors.length, lessThanOrEqualTo(maxWavePaletteColors));
      });
    }
  });

  group('single', () {
    test('lightens ahead and deepens behind, as the reference does', () {
      const base = Color(0xFF35BA00);
      final palette = WavePalette.single(base);
      expect(palette.colors, hasLength(4));
      expectSameColor(palette.colors[0], base, 'colors[0]');
      expectSameColor(palette.colors[1], mixed(base, white, 0.25), 'colors[1]');
      expectSameColor(palette.colors[2], base, 'colors[2]');
      expectSameColor(palette.colors[3], mixed(base, black, 0.15), 'colors[3]');
      expectSameColor(palette.ahead, mixed(base, white, 0.45), 'ahead');
      expectSameColor(palette.behind, mixed(base, black, 0.3), 'behind');
    });

    test('is drawn opaque', () {
      final palette = WavePalette.single(const Color(0x8035BA00));
      for (final c in [...palette.colors, palette.ahead, palette.behind]) {
        expect(c.a, 1);
      }
      expect(palette, WavePalette.single(const Color(0xFF35BA00)));
    });
  });

  group('fromBeamColors', () {
    void expectDerived(WavePalette palette, List<Color> stops, String label) {
      expect(palette.colors, hasLength(stops.length), reason: label);
      for (var i = 0; i < stops.length; i++) {
        expectSameColor(
          palette.colors[i],
          stops[i].withValues(alpha: 1),
          '$label colors[$i]',
        );
      }
      final first = palette.colors.first;
      final middle = palette.colors[palette.colors.length ~/ 2];
      expectSameColor(palette.ahead, mixed(first, white, 0.4), '$label ahead');
      expectSameColor(
        palette.behind,
        mixed(middle, black, 0.25),
        '$label behind',
      );
    }

    test('carries every stop of a preset, and derives the fringes', () {
      for (final MapEntry(:key, :value) in BeamColors.presets.entries) {
        final stops = value.resolve().colors;
        final palette = WavePalette.fromBeamColors(value);
        expect(
          palette.colors.length,
          lessThanOrEqualTo(maxWavePaletteColors),
          reason: key,
        );
        expectDerived(palette, stops, key);
      }
    });

    test('takes at most eight stops', () {
      // A lerp is sampled at the most stops a beam palette holds.
      final lerp = BeamColors.lerp(BeamColors.ocean, BeamColors.sunset, 0.5);
      final palette = WavePalette.fromBeamColors(lerp);
      expect(palette.colors, hasLength(maxWavePaletteColors));
      expectDerived(palette, lerp.resolve().colors, 'lerp');
    });

    test('one solid colour is its own middle', () {
      const color = Color(0xFF2878FF);
      final palette = WavePalette.fromBeamColors(const BeamColors.solid(color));
      expectDerived(palette, const [color], 'solid');
    });

    test('is drawn opaque', () {
      final palette = WavePalette.fromBeamColors(
        BeamColors.colorful.scaleAlpha(0.5),
      );
      for (final c in [...palette.colors, palette.ahead, palette.behind]) {
        expect(c.a, 1);
      }
      expect(palette, WavePalette.fromBeamColors(BeamColors.colorful));
    });
  });

  group('equality', () {
    test('is by value', () {
      final copy = WavePalette(
        colors: List.of(WavePalette.ocean.colors),
        ahead: WavePalette.ocean.ahead,
        behind: WavePalette.ocean.behind,
      );
      expect(identical(copy, WavePalette.ocean), isFalse);
      expect(copy, WavePalette.ocean);
      expect(copy.hashCode, WavePalette.ocean.hashCode);
    });

    test('every field counts', () {
      const base = WavePalette.ocean;
      final variants = [
        WavePalette(
          colors: List.of(base.colors)..[3] = black,
          ahead: base.ahead,
          behind: base.behind,
        ),
        WavePalette(
          colors: base.colors.sublist(1),
          ahead: base.ahead,
          behind: base.behind,
        ),
        WavePalette(colors: base.colors, ahead: black, behind: base.behind),
        WavePalette(colors: base.colors, ahead: base.ahead, behind: white),
      ];
      for (final v in variants) {
        expect(v, isNot(base));
        expect(v.hashCode, isNot(base.hashCode));
      }
      for (final (index, a) in WavePalette.presets.values.indexed) {
        for (final b in WavePalette.presets.values.skip(index + 1)) {
          expect(a, isNot(b));
        }
      }
    });
  });

  group('toString', () {
    test('names a preset', () {
      for (final MapEntry(:key, :value) in WavePalette.presets.entries) {
        expect(value.toString(), 'WavePalette.$key');
      }
    });

    test('names a preset rebuilt by value', () {
      final copy = WavePalette(
        colors: List.of(WavePalette.sunset.colors),
        ahead: WavePalette.sunset.ahead,
        behind: WavePalette.sunset.behind,
      );
      expect(copy.toString(), 'WavePalette.sunset');
    });

    test('counts the colours of any other', () {
      expect(
        WavePalette.single(const Color(0xFF35BA00)).toString(),
        'WavePalette(4 colours)',
      );
    });
  });
}
