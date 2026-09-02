import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/constants/palettes.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

const _blobA = BeamBlob(
  color: Color(0xFFFF3264),
  position: Offset(0.33, -0.074),
  size: Size(70, 40),
);
const _blobB = BeamBlob(
  color: Color(0xFF288CFF),
  position: Offset(0.12, -0.05),
  size: Size(60, 35),
);
const _pink = Color(0xFFFF0080);
const _cyan = Color(0xFF00E5FF);
const _brand = Color(0xFF18A8F0);

const _lineBlob = LineBlob(
  color: Color(0xFFFF3264),
  sizeW: 120,
  sizeH: 30,
  offsetX: 0,
  offsetY: 2,
);

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

BeamPainter _beamPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first;

void main() {
  group('BeamBlob equality', () {
    test('compares color, position and size', () {
      expect(
        _blobA,
        const BeamBlob(
          color: Color(0xFFFF3264),
          position: Offset(0.33, -0.074),
          size: Size(70, 40),
        ),
      );
      expect(
        _blobA.hashCode,
        _blobA.withColor(const Color(0xFFFF3264)).hashCode,
      );
      expect(_blobA, isNot(_blobB));
      expect(_blobA, isNot(_blobA.withColor(const Color(0xFF000000))));
      expect(_blobA.toString(), contains('BeamBlob'));
    });

    test('LineBlob compares every geometry field', () {
      expect(
        _lineBlob,
        const LineBlob(
          color: Color(0xFFFF3264),
          sizeW: 120,
          sizeH: 30,
          offsetX: 0,
          offsetY: 2,
        ),
      );
      expect(_lineBlob.hashCode, isNot(0));
      expect(
        _lineBlob,
        isNot(
          const LineBlob(
            color: Color(0xFFFF3264),
            sizeW: 120,
            sizeH: 30,
            offsetX: 1,
            offsetY: 2,
          ),
        ),
      );
      expect(_lineBlob.toString(), contains('LineBlob'));
    });
  });

  group('BeamColors equality', () {
    test('equal custom lists are == with equal hashCodes', () {
      final a = BeamColors.custom(const [Color(0xFFFF00AA), Color(0xFF00FFEE)]);
      final b = BeamColors.custom([
        const Color(0xFFFF00AA),
        const Color(0xFF00FFEE),
      ]);
      expect(identical(a, b), isFalse, reason: 'distinct instances');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('custom order and length are significant', () {
      final a = BeamColors.custom(const [Color(0xFFFF00AA), Color(0xFF00FFEE)]);
      final reordered = BeamColors.custom(const [
        Color(0xFF00FFEE),
        Color(0xFFFF00AA),
      ]);
      final shorter = BeamColors.custom(const [Color(0xFFFF00AA)]);
      expect(a, isNot(reordered));
      expect(a, isNot(shorter));
    });

    test('presets compare by identity of their table and mono flag', () {
      expect(BeamColors.ocean, BeamColors.ocean);
      expect(BeamColors.ocean.hashCode, BeamColors.ocean.hashCode);
      expect(BeamColors.ocean, isNot(BeamColors.sunset));
      expect(BeamColors.mono, isNot(BeamColors.colorful));
      expect(
        BeamColors.colorful,
        isNot(BeamColors.custom(const [Color(0xFFFF00AA)])),
      );
    });

    test('spec compares blob tables element-wise', () {
      const a = BeamColors.spec(border: [_blobA, _blobB]);
      const b = BeamColors.spec(border: [_blobA, _blobB]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const BeamColors.spec(border: [_blobB, _blobA])));
      expect(
        a,
        isNot(const BeamColors.spec(border: [_blobA, _blobB], lineBlobs: [])),
      );
      expect(
        const BeamColors.spec(border: [_blobA], smallBorder: [_blobB]),
        const BeamColors.spec(border: [_blobA], smallBorder: [_blobB]),
      );
      expect(
        const BeamColors.spec(border: [_blobA], smallBorder: [_blobB]),
        isNot(const BeamColors.spec(border: [_blobA])),
      );
      expect(
        const BeamColors.spec(border: [_blobA], lineBlobs: [_lineBlob]),
        const BeamColors.spec(border: [_blobA], lineBlobs: [_lineBlob]),
      );
    });
  });

  group('BeamColors.resolve', () {
    test('memoizes per instance', () {
      final custom = BeamColors.custom(const [Color(0xFFFF00AA)]);
      expect(identical(custom.resolve(), custom.resolve()), isTrue);
      expect(
        identical(BeamColors.ocean.resolve(), BeamColors.ocean.resolve()),
        isTrue,
      );
      const spec = BeamColors.spec(border: [_blobA]);
      expect(identical(spec.resolve(), spec.resolve()), isTrue);
    });

    test('mutable custom inputs cannot corrupt the value cache', () {
      final colors = <Color>[const Color(0xFFFF0000)];
      final custom = BeamColors.custom(colors);
      final red = custom.resolve();

      colors[0] = const Color(0xFF0000FF);
      final blue = custom.resolve();

      expect(identical(blue, red), isFalse);
      expect(blue.data.border.first.color, const Color(0xFF0000FF));
      expect(
        identical(blue, BeamColors.custom(const [Color(0xFF0000FF)]).resolve()),
        isTrue,
        reason: 'the mutated value should use a new stable cache key',
      );
    });

    test('mutable spec inputs cannot corrupt the value cache', () {
      final border = <BeamBlob>[_blobA];
      final spec = BeamColors.spec(border: border);
      final first = spec.resolve();

      border[0] = _blobB;
      final second = spec.resolve();

      expect(identical(second, first), isFalse);
      expect(second.data.border, [_blobB]);
      expect(
        identical(second, const BeamColors.spec(border: [_blobB]).resolve()),
        isTrue,
      );
    });

    test('an empty color table is rejected in release too', () {
      expect(
        () => BeamColors.custom(<Color>[]).resolve(),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => BeamColors.spec(border: <BeamBlob>[]).resolve(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a resolved spec palette does not alias the caller lists', () {
      final border = <BeamBlob>[_blobA];
      final small = <BeamBlob>[_blobA];
      final lines = <LineBlob>[_lineBlob];
      final palette = BeamColors.spec(
        border: border,
        smallBorder: small,
        lineBlobs: lines,
      ).resolve();

      border[0] = _blobB;
      small[0] = _blobB;
      lines.clear();

      expect(palette.data.border, [_blobA]);
      expect(palette.data.smallBorder, [_blobA]);
      expect(palette.data.lineDark, [_lineBlob]);
      expect(palette.data.lineLight, [_lineBlob]);
      expect(
        () => palette.data.border.add(_blobB),
        throwsUnsupportedError,
        reason: 'the resolved tables are snapshots, not the caller list',
      );
    });

    test('custom distributes colors and preserves preset alpha', () {
      final palette = BeamColors.custom(const [Color(0xFFFF00AA)]).resolve();
      final reference = BeamColors.colorful.resolve();
      for (final (i, blob) in palette.data.smallInner.indexed) {
        expect(blob.color.r, closeTo(1, 1e-6));
        expect(blob.color.g, closeTo(0, 1e-6));
        expect(
          blob.color.a,
          closeTo(reference.data.smallInner[i].color.a, 1e-6),
        );
        expect(blob.position, reference.data.smallInner[i].position);
      }
      expect(palette.data.border.length, reference.data.border.length);
      expect(palette.data.lineBloomDark.length, 5);
      expect(palette.forcesStaticColors, isFalse);
    });

    test('mono preset carries the mono modifiers', () {
      final mono = BeamColors.mono.resolve();
      expect(mono.forcesStaticColors, isTrue);
      expect(mono.opacityMultiplier, 0.5);
      expect(mono.monoTreatment, isTrue);
    });

    test('spec keeps the given tables and derives the rest', () {
      const spec = BeamColors.spec(
        border: [_blobA, _blobB],
        smallBorder: [_blobA],
      );
      final palette = spec.resolve();
      final derived = BeamColors.custom(const [
        Color(0xFFFF3264),
        Color(0xFF288CFF),
      ]).resolve();
      expect(palette.data.border, const [_blobA, _blobB]);
      expect(palette.data.smallBorder, const [_blobA]);
      // smallInner is derived from the given smallBorder at 45% alpha.
      expect(
        palette.data.smallInner.single.color.a,
        closeTo(_blobA.color.a * 0.45, 1e-6),
      );
      // Untouched tables cycle the border colors over the default geometry.
      expect(palette.data.lineInner, derived.data.lineInner);
      expect(palette.data.lineBloomDark, derived.data.lineBloomDark);
      expect(palette.data.spike, derived.data.spike);
    });

    test('spec without a smallBorder derives one', () {
      const spec = BeamColors.spec(border: [_blobA]);
      final palette = spec.resolve();
      final derived = BeamColors.custom(const [Color(0xFFFF3264)]).resolve();
      expect(palette.data.smallBorder, derived.data.smallBorder);
      expect(palette.data.smallInner, derived.data.smallInner);
      expect(palette.data.lineDark, derived.data.lineDark);
    });
  });

  group('BeamColors.custom base', () {
    test('base selects which tables supply geometry and alpha', () {
      final overColorful = BeamColors.custom(const [_pink]).resolve();
      final overMono = BeamColors.custom(const [
        _pink,
      ], base: BeamColors.mono).resolve();
      // mono's inner-glow table is half as opaque as colorful's, and that
      // alpha structure is what `base` selects.
      expect(overColorful.data.smallInner[0].color.a, closeTo(0.5, 1e-6));
      expect(overMono.data.smallInner[0].color.a, closeTo(0.25, 1e-6));
      // The hue still comes from the caller's list either way.
      expect(overMono.data.smallInner[0].color.r, closeTo(_pink.r, 1e-6));
      expect(overMono.data.smallInner[0].color.g, closeTo(_pink.g, 1e-6));
    });

    test('a mono base does not make the result mono', () {
      final palette = BeamColors.custom(const [
        _pink,
      ], base: BeamColors.mono).resolve();
      expect(palette.forcesStaticColors, isFalse);
      expect(palette.opacityMultiplier, 1.0);
      expect(palette.monoTreatment, isFalse);
    });

    test('base participates in equality', () {
      expect(
        BeamColors.custom(const [_pink]),
        BeamColors.custom(const [_pink], base: BeamColors.colorful),
      );
      expect(
        BeamColors.custom(const [_pink]).hashCode,
        BeamColors.custom(const [_pink], base: BeamColors.colorful).hashCode,
      );
      expect(
        BeamColors.custom(const [_pink]),
        isNot(BeamColors.custom(const [_pink], base: BeamColors.mono)),
      );
      expect(
        BeamColors.custom(const [_pink], base: BeamColors.ocean),
        BeamColors.custom(const [_pink], base: BeamColors.ocean),
      );
      expect(
        BeamColors.custom(const [_pink], base: BeamColors.ocean).hashCode,
        BeamColors.custom(const [_pink], base: BeamColors.ocean).hashCode,
      );
    });

    test('a custom base nests', () {
      final nested = BeamColors.custom(const [
        _cyan,
      ], base: BeamColors.custom(const [_pink], base: BeamColors.mono));
      final palette = nested.resolve();
      // Alpha structure still comes from mono, two levels down.
      expect(palette.data.smallInner[0].color.a, closeTo(0.25, 1e-6));
      // Colors come from the outermost list.
      expect(palette.data.smallInner[0].color.b, closeTo(_cyan.b, 1e-6));
    });
  });

  group('BeamColors.fromSeed', () {
    const seeds = {
      'black': Color(0xFF000000),
      'white': Color(0xFFFFFFFF),
      'pure red': Color(0xFFFF0000),
      'brand blue': Color(0xFF18A8F0),
      'mid gray': Color(0xFF808080),
    };

    for (final MapEntry(key: name, value: seed) in seeds.entries) {
      for (final harmony in BeamSeedHarmony.values) {
        test('$name / ${harmony.name} gives 3-4 distinct in-band colors', () {
          final palette = BeamColors.fromSeed(seed, harmony: harmony).resolve();
          // The 9-slot border table cycles the derived colors, so its
          // distinct set is exactly the derived palette.
          final derived = {for (final b in palette.data.border) b.color};
          expect(derived.length, inInclusiveRange(3, 4), reason: '$derived');
          for (final c in derived) {
            final hsl = HSLColor.fromColor(c);
            expect(
              hsl.lightness,
              inInclusiveRange(0.54, 0.71),
              reason: '$c is outside the glow lightness band',
            );
            // 0.55 floor, times monochrome's 0.7 lowest saturation step.
            expect(hsl.saturation, greaterThanOrEqualTo(0.37), reason: '$c');
            expect(c.a, 1.0);
          }
        });
      }
    }

    test('geometry comes from the colorful preset', () {
      final palette = const BeamColors.fromSeed(_brand).resolve();
      for (final (i, blob) in palette.data.border.indexed) {
        expect(blob.position, colorfulPreset.border[i].position);
        expect(blob.size, colorfulPreset.border[i].size);
      }
      expect(palette.data.smallInner, hasLength(8));
      expect(palette.data.lineBloomDark, hasLength(5));
      // Preset alpha survives the substitution.
      expect(palette.data.smallInner[0].color.a, closeTo(0.5, 1e-6));
    });

    test('resolves without mono modifiers', () {
      final palette = const BeamColors.fromSeed(_brand).resolve();
      expect(palette.forcesStaticColors, isFalse);
      expect(palette.opacityMultiplier, 1.0);
      expect(palette.monoTreatment, isFalse);
    });

    test('the default harmony is analogous', () {
      expect(
        const BeamColors.fromSeed(_brand),
        const BeamColors.fromSeed(_brand, harmony: BeamSeedHarmony.analogous),
      );
    });

    test('equality covers seed and harmony', () {
      expect(
        BeamColors.fromSeed(const Color(0xFF18A8F0)),
        BeamColors.fromSeed(const Color(0xFF18A8F0)),
      );
      expect(
        BeamColors.fromSeed(const Color(0xFF18A8F0)).hashCode,
        BeamColors.fromSeed(const Color(0xFF18A8F0)).hashCode,
      );
      expect(
        const BeamColors.fromSeed(_brand),
        isNot(const BeamColors.fromSeed(Color(0xFFF018A8))),
      );
      expect(
        const BeamColors.fromSeed(_brand),
        isNot(
          const BeamColors.fromSeed(_brand, harmony: BeamSeedHarmony.triadic),
        ),
      );
      expect(
        const BeamColors.fromSeed(_brand),
        isNot(BeamColors.custom(const [_brand])),
      );
    });

    test('different harmonies produce different palettes', () {
      final tables = {
        for (final h in BeamSeedHarmony.values)
          h: BeamColors.fromSeed(_brand, harmony: h).resolve().data.border[1],
      };
      expect(tables.values.map((b) => b.color).toSet(), hasLength(4));
    });

    test('analogous harmony wraps hues below zero', () {
      final palette = const BeamColors.fromSeed(Color(0xFFFF0000)).resolve();
      expect(palette.data.border, hasLength(9));
      expect(
        HSLColor.fromColor(palette.data.border[2].color).hue,
        closeTo(335, 1),
      );
    });

    test('triadic spreads the seed hue by 120 degrees', () {
      final palette = const BeamColors.fromSeed(
        _brand,
        harmony: BeamSeedHarmony.triadic,
      ).resolve();
      final hues = [
        for (var i = 0; i < 3; i++)
          HSLColor.fromColor(palette.data.border[i].color).hue,
      ];
      expect((hues[1] - hues[0]) % 360, closeTo(120, 1));
      expect((hues[2] - hues[1]) % 360, closeTo(120, 1));
    });
  });

  group('BeamColors.fromScheme', () {
    test('uses primary, secondary and tertiary', () {
      const scheme = ColorScheme.dark(
        primary: Color(0xFFFF0000),
        secondary: Color(0xFF00FF00),
        tertiary: Color(0xFF0000FF),
      );
      expect(
        BeamColors.fromScheme(scheme),
        BeamColors.custom(const [
          Color(0xFFFF0000),
          Color(0xFF00FF00),
          Color(0xFF0000FF),
        ]),
      );
    });

    test('drops near-duplicate roles', () {
      const scheme = ColorScheme.dark(
        primary: Color(0xFFFF0000),
        secondary: Color(0xFFFF0102),
        tertiary: Color(0xFF0000FF),
      );
      expect(
        BeamColors.fromScheme(scheme),
        BeamColors.custom(const [Color(0xFFFF0000), Color(0xFF0000FF)]),
      );
    });

    test('an all-identical scheme collapses to one color', () {
      const scheme = ColorScheme.dark(
        primary: _pink,
        secondary: _pink,
        tertiary: _pink,
      );
      expect(BeamColors.fromScheme(scheme), BeamColors.custom(const [_pink]));
      expect(BeamColors.fromScheme(scheme).resolve().data.border, hasLength(9));
    });

    test('value-equal on the three roles only', () {
      const a = ColorScheme.dark(
        primary: Color(0xFFFF0000),
        secondary: Color(0xFF00FF00),
        tertiary: Color(0xFF0000FF),
        surface: Color(0xFF111111),
      );
      const b = ColorScheme.dark(
        primary: Color(0xFFFF0000),
        secondary: Color(0xFF00FF00),
        tertiary: Color(0xFF0000FF),
        surface: Color(0xFF222222),
      );
      expect(BeamColors.fromScheme(a), BeamColors.fromScheme(b));
      expect(
        BeamColors.fromScheme(a).hashCode,
        BeamColors.fromScheme(b).hashCode,
      );
      expect(
        BeamColors.fromScheme(a),
        isNot(
          BeamColors.fromScheme(
            const ColorScheme.dark(
              primary: Color(0xFF00FF00),
              secondary: Color(0xFFFF0000),
              tertiary: Color(0xFF0000FF),
            ),
          ),
        ),
      );
    });

    test('geometry comes from the colorful preset', () {
      const scheme = ColorScheme.dark(
        primary: Color(0xFFFF0000),
        secondary: Color(0xFF00FF00),
        tertiary: Color(0xFF0000FF),
      );
      final palette = BeamColors.fromScheme(scheme).resolve();
      for (final (i, blob) in palette.data.border.indexed) {
        expect(blob.position, colorfulPreset.border[i].position);
        expect(blob.size, colorfulPreset.border[i].size);
      }
    });
  });

  group('BeamColors.lerp', () {
    const ocean = BeamColors.ocean;
    const sunset = BeamColors.sunset;

    test('t = 0 reproduces the tables of a', () {
      expect(
        const BeamColors.lerp(ocean, sunset, 0).resolve().data,
        ocean.resolve().data,
      );
    });

    test('t = 1 reproduces the tables of b', () {
      expect(
        const BeamColors.lerp(ocean, sunset, 1).resolve().data,
        sunset.resolve().data,
      );
    });

    test('the midpoint is the per-entry Color.lerp of both ends', () {
      final a = ocean.resolve().data;
      final b = sunset.resolve().data;
      final mid = const BeamColors.lerp(ocean, sunset, 0.5).resolve().data;
      for (final (i, blob) in mid.border.indexed) {
        expect(
          blob.color,
          Color.lerp(a.border[i].color, b.border[i].color, .5),
        );
        expect(blob.position, a.border[i].position);
        expect(blob.size, a.border[i].size);
      }
      for (final (i, blob) in mid.lineInner.indexed) {
        expect(
          blob.color,
          Color.lerp(a.lineInner[i].color, b.lineInner[i].color, .5),
        );
        expect(blob.sizeW, a.lineInner[i].sizeW);
        expect(blob.offsetX, a.lineInner[i].offsetX);
      }
      expect(
        mid.spike.primary,
        Color.lerp(a.spike.primary, b.spike.primary, .5),
      );
      expect(
        mid.spikeLt.secondary,
        Color.lerp(a.spikeLt.secondary, b.spikeLt.secondary, .5),
      );
      expect(
        mid.lineBloomDark[2].color2,
        Color.lerp(a.lineBloomDark[2].color2, b.lineBloomDark[2].color2, .5),
      );
      expect(mid.smallInner, hasLength(8));
    });

    test('the mono modifiers come from the nearer end', () {
      final nearMono = const BeamColors.lerp(
        BeamColors.mono,
        ocean,
        0.2,
      ).resolve();
      expect(nearMono.forcesStaticColors, isTrue);
      expect(nearMono.monoTreatment, isTrue);
      expect(nearMono.opacityMultiplier, closeTo(0.6, 1e-9));

      final nearOcean = const BeamColors.lerp(
        BeamColors.mono,
        ocean,
        0.8,
      ).resolve();
      expect(nearOcean.forcesStaticColors, isFalse);
      expect(nearOcean.monoTreatment, isFalse);
      expect(nearOcean.opacityMultiplier, closeTo(0.9, 1e-9));
    });

    test('a shorter b table cycles', () {
      const spec = BeamColors.spec(border: [_blobA]);
      final lerped = const BeamColors.lerp(ocean, spec, 1).resolve().data;
      expect(lerped.border, hasLength(9));
      expect(lerped.border.map((b) => b.color).toSet(), hasLength(1));
      // Geometry still comes from a.
      expect(lerped.border[4].size, ocean.resolve().data.border[4].size);
    });

    test('equality covers both ends and t', () {
      expect(
        const BeamColors.lerp(ocean, sunset, 0.25),
        const BeamColors.lerp(ocean, sunset, 0.25),
      );
      expect(
        const BeamColors.lerp(ocean, sunset, 0.25).hashCode,
        const BeamColors.lerp(ocean, sunset, 0.25).hashCode,
      );
      expect(
        const BeamColors.lerp(ocean, sunset, 0.25),
        isNot(const BeamColors.lerp(ocean, sunset, 0.75)),
      );
      expect(
        const BeamColors.lerp(ocean, sunset, 0.25),
        isNot(const BeamColors.lerp(sunset, ocean, 0.25)),
      );
      expect(const BeamColors.lerp(ocean, sunset, 0), isNot(ocean));
    });

    test('extrapolates past 1', () {
      final past = const BeamColors.lerp(ocean, sunset, 2).resolve().data;
      final a = ocean.resolve().data;
      final b = sunset.resolve().data;
      expect(
        past.border[0].color,
        Color.lerp(a.border[0].color, b.border[0].color, 2),
      );
    });
  });

  group('BeamColors.scaleAlpha', () {
    test('multiplies every table entry alpha and keeps the hue', () {
      final base = BeamColors.colorful.resolve().data;
      final dim = BeamColors.colorful.scaleAlpha(0.5).resolve().data;
      for (final (i, blob) in dim.smallInner.indexed) {
        expect(blob.color.a, closeTo(base.smallInner[i].color.a * 0.5, 1e-6));
        expect(blob.color.r, closeTo(base.smallInner[i].color.r, 1e-6));
        expect(blob.position, base.smallInner[i].position);
        expect(blob.size, base.smallInner[i].size);
      }
      expect(dim.border.first.color.a, closeTo(0.5, 1e-6));
      expect(dim.spike.primary.a, closeTo(base.spike.primary.a * 0.5, 1e-6));
      expect(
        dim.lineBloomDark[0].color2.a,
        closeTo(base.lineBloomDark[0].color2.a * 0.5, 1e-6),
      );
      expect(dim.lineInner[3].sizeW, base.lineInner[3].sizeW);
    });

    test('clamps the product at 1', () {
      final bright = BeamColors.colorful.scaleAlpha(4).resolve().data;
      for (final blob in [...bright.border, ...bright.smallInner]) {
        expect(blob.color.a, lessThanOrEqualTo(1.0));
      }
      // colorful's smallInner[0] is 0.5 -> 2.0 before the clamp.
      expect(bright.smallInner[0].color.a, 1.0);
      expect(bright.border.first.color.a, 1.0);
    });

    test('a zero factor makes every entry transparent', () {
      final gone = BeamColors.colorful.scaleAlpha(0).resolve().data;
      for (final blob in gone.border) {
        expect(blob.color.a, 0.0);
      }
      expect(gone.spike.primary.a, 0.0);
      expect(gone.lineBloomLight[4].color1.a, 0.0);
    });

    test('keeps the source palette modifiers', () {
      final dim = BeamColors.mono.scaleAlpha(0.5).resolve();
      expect(dim.forcesStaticColors, isTrue);
      expect(dim.opacityMultiplier, 0.5);
      expect(dim.monoTreatment, isTrue);
      expect(
        BeamColors.gold.scaleAlpha(0.5).resolve().forcesStaticColors,
        isTrue,
      );
    });

    test('equality covers the source and the factor', () {
      expect(
        BeamColors.ocean.scaleAlpha(0.5),
        BeamColors.ocean.scaleAlpha(0.5),
      );
      expect(
        BeamColors.ocean.scaleAlpha(0.5).hashCode,
        BeamColors.ocean.scaleAlpha(0.5).hashCode,
      );
      expect(
        BeamColors.ocean.scaleAlpha(0.5),
        isNot(BeamColors.ocean.scaleAlpha(0.6)),
      );
      expect(
        BeamColors.ocean.scaleAlpha(0.5),
        isNot(BeamColors.sunset.scaleAlpha(0.5)),
      );
      expect(BeamColors.ocean.scaleAlpha(1), isNot(BeamColors.ocean));
    });

    test('stacks', () {
      final twice = BeamColors.colorful.scaleAlpha(0.5).scaleAlpha(0.5);
      expect(twice.resolve().data.border.first.color.a, closeTo(0.25, 1e-6));
    });

    test('rejects a negative factor', () {
      expect(
        () => BeamColors.colorful.scaleAlpha(-1).resolve(),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Flutter-only presets', () {
    test('gold pins the hue but keeps full layer opacity', () {
      final gold = BeamColors.gold.resolve();
      expect(gold.forcesStaticColors, isTrue);
      expect(gold.opacityMultiplier, 1.0);
      expect(gold.monoTreatment, isFalse);
    });

    test('every other new preset animates its hue', () {
      for (final colors in const [
        BeamColors.aurora,
        BeamColors.neon,
        BeamColors.candy,
        BeamColors.ember,
        BeamColors.ice,
        BeamColors.holographic,
      ]) {
        final palette = colors.resolve();
        expect(palette.forcesStaticColors, isFalse, reason: '$colors');
        expect(palette.opacityMultiplier, 1.0, reason: '$colors');
        expect(palette.monoTreatment, isFalse, reason: '$colors');
      }
    });

    test('the new presets are all distinct from each other', () {
      const all = [
        BeamColors.aurora,
        BeamColors.neon,
        BeamColors.candy,
        BeamColors.ember,
        BeamColors.ice,
        BeamColors.gold,
        BeamColors.holographic,
        BeamColors.colorful,
        BeamColors.mono,
        BeamColors.ocean,
        BeamColors.sunset,
      ];
      expect(all.toSet(), hasLength(all.length));
      expect(
        all.map((c) => c.resolve().data.border[0].color).toSet(),
        hasLength(all.length),
      );
    });
  });

  group('BeamBlob.size semantics', () {
    test('a spec blob keeps the radii it was given', () {
      // `size` is the ellipse RADII, not its diameters: painters pass
      // `size.width`/`size.height` straight through as radiusX/radiusY, so a
      // 70x40 blob spans 140x80 logical pixels. Nothing in the resolve path
      // may halve or double it.
      const blob = BeamBlob(
        color: Color(0xFFFF0080),
        position: Offset(0.33, -0.074),
        size: Size(70, 40),
      );
      final palette = const BeamColors.spec(border: [blob]).resolve();
      expect(palette.data.border.single.size, const Size(70, 40));
      expect(palette.data.border.single.position, const Offset(0.33, -0.074));
      // The derived tables keep the source library's radii too.
      expect(palette.data.border.single.size, colorfulPreset.border[0].size);
    });
  });

  testWidgets('equal custom colors do not re-resolve the config', (
    tester,
  ) async {
    Widget build() => _host(
      BorderBeam.rotate(
        colors: BeamColors.custom([
          const Color(0xFFFF00AA),
          const Color(0xFF00FFEE),
        ]),
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build());
    final first = _beamPainter(tester).config;
    // A fresh widget carrying a fresh — but equal — BeamColors instance.
    await tester.pumpWidget(build());
    expect(identical(_beamPainter(tester).config, first), isTrue);
  });
}
