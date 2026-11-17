import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show ColorScheme, HSLColor;
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/border_beam/models/beam_palette.dart';
import 'package:prismatic/src/border_beam/models/model_validation.dart';
import 'package:prismatic/src/border_beam/render/color_math.dart';

const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);
const Color _blue = Color(0xFF0000FF);

/// Asserts [p] is a well-formed palette: 1–8 colours, one stop each,
/// ascending inside `[0, 1)`.
void _expectWellFormed(BeamPalette p, {String? reason}) {
  expect(p.colors.length, inInclusiveRange(1, maxPaletteStops), reason: reason);
  expect(p.stops, hasLength(p.colors.length), reason: reason);
  for (var i = 0; i < p.stops.length; i++) {
    expect(p.stops[i], inInclusiveRange(0, 1), reason: reason);
    expect(p.stops[i], lessThan(1), reason: reason);
    if (i > 0) {
      expect(p.stops[i], greaterThanOrEqualTo(p.stops[i - 1]), reason: reason);
    }
  }
  expect(
    () => validatePalette(p.colors, p.stops, 'test'),
    returnsNormally,
    reason: reason,
  );
}

/// [x] as a runtime value, so an expression built from it is never const.
double _rt(double x) => double.parse('$x');

/// Hue distance in degrees, around the wheel.
double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// `BeamColors` is the public colour choice: a value type that resolves to a
/// [BeamPalette] — a ring of colour stops — through a value-keyed memo.
void main() {
  group('presets', () {
    test('the map holds 19 distinct presets keyed by their names', () {
      expect(BeamColors.presets, hasLength(19));
      expect(BeamColors.presets.values.toSet(), hasLength(19));
      for (final MapEntry(:key, :value) in BeamColors.presets.entries) {
        expect(value.toString(), 'BeamColors.$key');
      }
      expect(
        BeamColors.presets.values.map((c) => c.resolve()).toSet(),
        hasLength(19),
        reason: 'no two presets resolve to the same palette',
      );
    });

    test('the map opens with the four originals', () {
      expect(BeamColors.presets.keys.take(4), [
        'colorful',
        'mono',
        'ocean',
        'sunset',
      ]);
      expect(BeamColors.presets['colorful'], BeamColors.colorful);
      expect(BeamColors.presets['ocean'], BeamColors.ocean);
    });

    for (final MapEntry(:key, :value) in BeamColors.presets.entries) {
      test('$key resolves to a well-formed palette', () {
        final palette = value.resolve();
        _expectWellFormed(palette, reason: key);
        expect(
          identical(value.resolve(), palette),
          isTrue,
          reason: 'a preset resolves to one canonical palette',
        );
      });
    }

    test('only mono and gold fix the hue', () {
      for (final MapEntry(:key, :value) in BeamColors.presets.entries) {
        expect(
          value.resolve().fixedHue,
          key == 'mono' || key == 'gold',
          reason: key,
        );
      }
    });

    test('presets compare by name', () {
      expect(BeamColors.ocean, BeamColors.presets['ocean']);
      expect(BeamColors.ocean.hashCode, BeamColors.presets['ocean'].hashCode);
      expect(BeamColors.ocean, isNot(BeamColors.sunset));
    });
  });

  group('BeamColors(colors, stops)', () {
    test('spaces the colours evenly by default', () {
      final p = const BeamColors([_red, _green, _blue, _red]).resolve();
      expect(p.colors, [_red, _green, _blue, _red]);
      expect(p.stops, BeamPalette.evenStops(4));
      expect(p.fixedHue, isFalse);
    });

    test('honours explicit stops and alpha', () {
      const translucent = Color(0x8000FF00);
      final p = const BeamColors(
        [_red, translucent],
        stops: [0.2, 0.9],
      ).resolve();
      expect(p.colors, [_red, translucent]);
      expect(p.stops, [0.2, 0.9]);
    });

    test('equal neighbouring stops are allowed — a hard edge', () {
      final p = const BeamColors(
        [_red, _blue, _green],
        stops: [0, 0.5, 0.5],
      ).resolve();
      _expectWellFormed(p);
    });

    test('a single colour is valid', () {
      final p = const BeamColors([_blue]).resolve();
      expect(p.colors, [_blue]);
      expect(p.stops, [0]);
    });

    test('equality covers colours, order and stops', () {
      expect(
        BeamColors([_red, Color(int.parse('0xFF00FF00'))]),
        const BeamColors([_red, _green]),
      );
      expect(
        BeamColors([_red, Color(int.parse('0xFF00FF00'))]).hashCode,
        const BeamColors([_red, _green]).hashCode,
      );
      expect(
        const BeamColors([_red, _green]),
        isNot(const BeamColors([_green, _red])),
      );
      expect(
        const BeamColors([_red, _green]),
        isNot(const BeamColors([_red, _green], stops: [0, 0.5])),
        reason: 'explicit stops are a different value, even when equal',
      );
      expect(
        const BeamColors([_red, _green], stops: [0, 0.3]),
        isNot(const BeamColors([_red, _green], stops: [0, 0.4])),
      );
    });
  });

  group('BeamColors.solid', () {
    test('is one colour all the way round', () {
      final p = const BeamColors.solid(_green).resolve();
      expect(p.colors, [_green]);
      expect(p.stops, [0]);
      for (final u in [0.0, 0.25, 0.9]) {
        expect(p.sample(u), _green);
      }
    });

    test('compares by colour', () {
      // Built at run time, so `==` runs instead of `identical` on one const.
      final red = BeamColors.solid(Color(_red.toARGB32()));
      expect(const BeamColors.solid(_red), red);
      expect(const BeamColors.solid(_red).hashCode, red.hashCode);
      expect(
        const BeamColors.solid(_red),
        isNot(const BeamColors.solid(_blue)),
      );
      expect(
        const BeamColors.solid(_red),
        isNot(const BeamColors([_red])),
        reason: 'a different factory is a different value',
      );
    });
  });

  group('BeamColors.fromSeed', () {
    const seeds = <String, Color>{
      'black': Color(0xFF000000),
      'white': Color(0xFFFFFFFF),
      'grey': Color(0xFF808080),
      'dark navy': Color(0xFF0A0F2E),
      'pale pink': Color(0xFFFFE6EE),
      'brand blue': Color(0xFF18A8F0),
      'red': Color(0xFFFF0000),
    };

    for (final MapEntry(key: name, value: seed) in seeds.entries) {
      for (final harmony in BeamSeedHarmony.values) {
        test('$name / ${harmony.name}: distinct colours in the glow band', () {
          final p = BeamColors.fromSeed(seed, harmony: harmony).resolve();
          _expectWellFormed(p);
          expect(
            p.colors,
            hasLength(harmony == BeamSeedHarmony.triadic ? 3 : 4),
          );
          expect(p.colors.toSet(), hasLength(p.colors.length));
          expect(p.stops, BeamPalette.evenStops(p.colors.length));
          expect(p.fixedHue, isFalse);
          // 8-bit rounding in HSLColor.toColor moves the measured values a
          // hair, hence the tolerance.
          for (final c in p.colors) {
            final hsl = HSLColor.fromColor(c);
            expect(hsl.lightness, inInclusiveRange(0.55 - 0.01, 0.70 + 0.01));
            expect(c.a, 1);
            // Monochrome's saturation floor is pinned separately below.
            if (harmony != BeamSeedHarmony.monochrome) {
              expect(hsl.saturation, greaterThanOrEqualTo(0.55 - 0.02));
            }
          }
        });
      }
    }

    test('monochrome keeps saturation at or above 0.55 for every seed', () {
      for (final MapEntry(key: name, value: seed) in seeds.entries) {
        final p = BeamColors.fromSeed(
          seed,
          harmony: BeamSeedHarmony.monochrome,
        ).resolve();
        for (final c in p.colors) {
          expect(
            HSLColor.fromColor(c).saturation,
            greaterThanOrEqualTo(0.55 - 0.02),
            reason: name,
          );
        }
      }
    });

    const seed = Color(0xFF18A8F0);
    final seedHue = HSLColor.fromColor(seed).hue;
    List<double> huesOf(BeamSeedHarmony harmony) => [
      for (final c in BeamColors.fromSeed(
        seed,
        harmony: harmony,
      ).resolve().colors)
        HSLColor.fromColor(c).hue,
    ];

    test('the default harmony is analogous', () {
      expect(
        const BeamColors.fromSeed(seed),
        const BeamColors.fromSeed(seed, harmony: BeamSeedHarmony.analogous),
      );
    });

    test('analogous stays near the seed hue', () {
      final hues = huesOf(BeamSeedHarmony.analogous);
      expect(_hueDistance(hues.first, seedHue), lessThan(2));
      for (final h in hues) {
        expect(_hueDistance(h, seedHue), lessThanOrEqualTo(52));
      }
    });

    test('complementary reaches the opposite hue', () {
      final hues = huesOf(BeamSeedHarmony.complementary);
      expect(
        hues.any((h) => _hueDistance(h, seedHue + 180) < 2),
        isTrue,
        reason: '$hues around $seedHue',
      );
    });

    test('triadic spreads three hues a third of the wheel apart', () {
      final hues = huesOf(BeamSeedHarmony.triadic);
      expect(_hueDistance(hues[0], seedHue), lessThan(2));
      expect(_hueDistance(hues[1], seedHue + 120), lessThan(2));
      expect(_hueDistance(hues[2], seedHue + 240), lessThan(2));
    });

    test('monochrome keeps the seed hue', () {
      for (final h in huesOf(BeamSeedHarmony.monochrome)) {
        expect(_hueDistance(h, seedHue), lessThan(2));
      }
    });

    test('equality covers seed and harmony', () {
      expect(
        const BeamColors.fromSeed(seed),
        isNot(const BeamColors.fromSeed(Color(0xFF18A8F1))),
      );
      expect(
        const BeamColors.fromSeed(seed, harmony: BeamSeedHarmony.triadic),
        isNot(const BeamColors.fromSeed(seed)),
      );
      expect(
        const BeamColors.fromSeed(
          seed,
          harmony: BeamSeedHarmony.triadic,
        ).resolve(),
        isNot(const BeamColors.fromSeed(seed).resolve()),
      );
    });
  });

  group('BeamColors.fromScheme', () {
    ColorScheme scheme(Color p, Color s, Color t) =>
        ColorScheme.dark(primary: p, secondary: s, tertiary: t);

    test('uses primary, secondary and tertiary, in order, evenly spaced', () {
      final p = BeamColors.fromScheme(scheme(_red, _green, _blue)).resolve();
      expect(p.colors, [_red, _green, _blue]);
      expect(p.stops, BeamPalette.evenStops(3));
    });

    test('drops a role that matches an earlier one', () {
      expect(
        BeamColors.fromScheme(scheme(_red, _red, _blue)).resolve().colors,
        [_red, _blue],
      );
      expect(
        BeamColors.fromScheme(scheme(_red, _blue, _red)).resolve().colors,
        [_red, _blue],
      );
    });

    test('drops a near-duplicate role', () {
      const almostRed = Color(0xFFFA0303);
      expect(
        BeamColors.fromScheme(scheme(_red, almostRed, _blue)).resolve().colors,
        [_red, _blue],
      );
    });

    test('keeps roles that are merely similar', () {
      const darkerRed = Color(0xFFB00000);
      expect(
        BeamColors.fromScheme(scheme(_red, darkerRed, _blue)).resolve().colors,
        [_red, darkerRed, _blue],
      );
    });

    test('an all-identical scheme collapses to one colour', () {
      expect(
        BeamColors.fromScheme(scheme(_green, _green, _green)).resolve().colors,
        [_green],
      );
    });

    test('equal schemes give equal colours', () {
      expect(
        BeamColors.fromScheme(scheme(_red, _green, _blue)),
        BeamColors.fromScheme(scheme(_red, _green, _blue)),
      );
      expect(
        BeamColors.fromScheme(scheme(_red, _green, _blue)),
        isNot(BeamColors.fromScheme(scheme(_red, _blue, _green))),
      );
    });
  });

  group('BeamColors.lerp', () {
    const a = BeamColors.ocean;
    const b = BeamColors.sunset;

    test('t = 0 and t = 1 are the ends unchanged', () {
      expect(const BeamColors.lerp(a, b, 0).resolve(), a.resolve());
      expect(const BeamColors.lerp(a, b, 1).resolve(), b.resolve());
    });

    test('t is clamped to 0–1, and NaN reads as 0', () {
      expect(const BeamColors.lerp(a, b, -2).resolve(), a.resolve());
      expect(const BeamColors.lerp(a, b, 7).resolve(), b.resolve());
      expect(const BeamColors.lerp(a, b, double.nan).resolve(), a.resolve());
    });

    test('in between, both ends are sampled at eight even positions', () {
      final p = const BeamColors.lerp(a, b, 0.5).resolve();
      expect(p.colors, hasLength(maxPaletteStops));
      expect(p.stops, BeamPalette.evenStops(maxPaletteStops));
      _expectWellFormed(p);
    });

    test('each sample lies between the two ends at that position', () {
      final pa = a.resolve();
      final pb = b.resolve();
      for (final t in [0.1, 0.5, 0.9]) {
        final p = BeamColors.lerp(a, b, t).resolve();
        for (var i = 0; i < p.length; i++) {
          final u = p.stops[i];
          final ca = pa.sample(u);
          final cb = pb.sample(u);
          final c = p.colors[i];
          for (final (x, y, z) in [
            (ca.r, cb.r, c.r),
            (ca.g, cb.g, c.g),
            (ca.b, cb.b, c.b),
            (ca.a, cb.a, c.a),
          ]) {
            final lo = x < y ? x : y;
            final hi = x < y ? y : x;
            expect(z, inInclusiveRange(lo - 1e-9, hi + 1e-9));
          }
          // Gamma-aware, the same blend the shader uses.
          expect(c, mixColor(ca, cb, t));
        }
      }
    });

    test('moves monotonically from a towards b', () {
      final pb = b.resolve();
      double distanceToB(double t) {
        final p = BeamColors.lerp(a, b, t).resolve();
        var sum = 0.0;
        for (var i = 0; i < p.length; i++) {
          final target = pb.sample(p.stops[i]);
          sum +=
              (p.colors[i].r - target.r).abs() +
              (p.colors[i].g - target.g).abs() +
              (p.colors[i].b - target.b).abs();
        }
        return sum;
      }

      expect(distanceToB(0.25), greaterThan(distanceToB(0.5)));
      expect(distanceToB(0.5), greaterThan(distanceToB(0.75)));
    });

    test('fixes the hue when the nearer end does', () {
      expect(
        const BeamColors.lerp(BeamColors.mono, b, 0.3).resolve().fixedHue,
        isTrue,
      );
      expect(
        const BeamColors.lerp(BeamColors.mono, b, 0.7).resolve().fixedHue,
        isFalse,
      );
      expect(
        const BeamColors.lerp(a, BeamColors.gold, 0.8).resolve().fixedHue,
        isTrue,
      );
      expect(
        const BeamColors.lerp(a, BeamColors.gold, 0.2).resolve().fixedHue,
        isFalse,
      );
    });

    test('equality covers both ends and t', () {
      expect(
        const BeamColors.lerp(a, b, 0.5),
        BeamColors.lerp(a, b, double.parse('0.5')),
      );
      expect(
        const BeamColors.lerp(a, b, 0.5).hashCode,
        BeamColors.lerp(a, b, double.parse('0.5')).hashCode,
      );
      expect(
        const BeamColors.lerp(a, b, 0.5),
        isNot(const BeamColors.lerp(b, a, 0.5)),
      );
      expect(
        const BeamColors.lerp(a, b, 0.5),
        isNot(const BeamColors.lerp(a, b, 0.6)),
      );
    });

    test('an invalid end throws on resolve', () {
      expect(
        () => const BeamColors.lerp(a, BeamColors(<Color>[]), 0.5).resolve(),
        throwsArgumentError,
      );
    });
  });

  group('scaleAlpha', () {
    test('multiplies every stop alpha and keeps the rest', () {
      const source = BeamColors([_red, Color(0x8000FF00)], stops: [0.1, 0.6]);
      final p = source.scaleAlpha(0.5).resolve();
      expect(p.colors[0].a, closeTo(0.5, 1e-9));
      expect(p.colors[1].a, closeTo(source.resolve().colors[1].a / 2, 1e-9));
      expect(p.stops, [0.1, 0.6]);
      for (var i = 0; i < p.length; i++) {
        final c = p.colors[i];
        final s = source.resolve().colors[i];
        expect((c.r, c.g, c.b), (s.r, s.g, s.b));
      }
    });

    test('clamps the product to 0–1', () {
      const source = BeamColors([_red, Color(0x8000FF00)]);
      final up = source.scaleAlpha(3).resolve();
      expect(up.colors.map((c) => c.a), everyElement(1));
      final down = source.scaleAlpha(0).resolve();
      expect(down.colors.map((c) => c.a), everyElement(0));
    });

    test('keeps the source palette fixedHue', () {
      expect(BeamColors.mono.scaleAlpha(0.5).resolve().fixedHue, isTrue);
      expect(BeamColors.ocean.scaleAlpha(0.5).resolve().fixedHue, isFalse);
    });

    test('stacks multiplicatively', () {
      final twice = BeamColors.ocean.scaleAlpha(0.5).scaleAlpha(0.5).resolve();
      final once = BeamColors.ocean.scaleAlpha(0.25).resolve();
      for (var i = 0; i < once.length; i++) {
        expect(twice.colors[i].a, closeTo(once.colors[i].a, 1e-9));
      }
    });

    test('a negative or NaN factor throws on resolve, not construction', () {
      final negative = BeamColors.ocean.scaleAlpha(-0.5);
      expect(negative.resolve, throwsArgumentError);
      expect(
        BeamColors.ocean.scaleAlpha(double.nan).resolve,
        throwsArgumentError,
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
    });
  });

  group('validation', () {
    // Each is a const value — construction never throws; resolution does,
    // in release builds too.
    final bad = <String, BeamColors>{
      'no colours': const BeamColors(<Color>[]),
      'nine colours': const BeamColors([
        _red,
        _green,
        _blue,
        _red,
        _green,
        _blue,
        _red,
        _green,
        _blue,
      ]),
      'fewer stops than colours': const BeamColors(
        [_red, _green, _blue],
        stops: [0, 0.5],
      ),
      'more stops than colours': const BeamColors(
        [_red, _green],
        stops: [0, 0.3, 0.6],
      ),
      'descending stops': const BeamColors([_red, _green], stops: [0.6, 0.3]),
      'a stop at 1': const BeamColors([_red, _green], stops: [0, 1]),
      'a negative stop': const BeamColors([_red, _green], stops: [-0.1, 0.5]),
      'a NaN stop': const BeamColors([_red, _green], stops: [0, double.nan]),
      'an infinite stop': const BeamColors(
        [_red, _green],
        stops: [0, double.infinity],
      ),
    };

    for (final MapEntry(:key, :value) in bad.entries) {
      test('$key throws an ArgumentError on resolve', () {
        expect(value.resolve, throwsArgumentError);
        // A failed resolve is not cached: it fails again.
        expect(value.resolve, throwsArgumentError);
      });
    }

    test('eight colours is the most that resolves', () {
      final p = const BeamColors([
        _red,
        _green,
        _blue,
        _red,
        _green,
        _blue,
        _red,
        _green,
      ]).resolve();
      expect(p.length, maxPaletteStops);
    });

    test('a scaled invalid palette throws too', () {
      expect(
        const BeamColors(<Color>[]).scaleAlpha(0.5).resolve,
        throwsArgumentError,
      );
    });
  });

  group('the resolve memo', () {
    test('equal values resolve to the identical palette', () {
      final a = BeamColors([_red, Color(int.parse('0xFF123456'))]);
      final b = BeamColors([_red, Color(int.parse('0xFF123456'))]);
      expect(identical(a, b), isFalse);
      expect(identical(a.resolve(), b.resolve()), isTrue);

      for (final (x, y) in [
        (
          BeamColors.fromSeed(Color(int.parse('0xFF18A8F0'))),
          BeamColors.fromSeed(Color(int.parse('0xFF18A8F0'))),
        ),
        (
          BeamColors.lerp(BeamColors.ocean, BeamColors.sunset, _rt(0.4)),
          BeamColors.lerp(BeamColors.ocean, BeamColors.sunset, _rt(0.4)),
        ),
        (BeamColors.ocean.scaleAlpha(0.4), BeamColors.ocean.scaleAlpha(0.4)),
        (
          BeamColors.solid(Color(int.parse('0xFF445566'))),
          BeamColors.solid(Color(int.parse('0xFF445566'))),
        ),
      ]) {
        expect(identical(x.resolve(), y.resolve()), isTrue, reason: '$x');
      }
    });

    test('unequal values resolve to unequal palettes', () {
      expect(
        const BeamColors([_red]).resolve(),
        isNot(const BeamColors([_blue]).resolve()),
      );
    });

    test('eviction past capacity still yields an equal palette', () {
      // Keys distinct from every other test in this file.
      BeamColors key(int i) => BeamColors([Color(0xFF7F0000 | i)]);
      final oldest = key(0);
      final first = oldest.resolve();
      // Far past any reasonable capacity, never touching `oldest`.
      for (var i = 1; i <= 200; i++) {
        key(i).resolve();
      }
      final again = oldest.resolve();
      expect(again, first, reason: 'rebuilt, and equal to the evicted one');
      expect(
        identical(again, first),
        isFalse,
        reason: 'the memo is bounded, so the old entry was dropped',
      );
    });

    test('a hit keeps an entry fresh: the memo drops the least recent', () {
      // Keys distinct from every other test in this file.
      BeamColors key(int i) => BeamColors([Color(0xFF5F0000 | i)]);
      final kept = BeamColors([const Color(0xFF5E0000)]);
      final first = kept.resolve();
      // The same churn that evicts an untouched entry, but `kept` is read
      // again every few resolves — well inside any capacity worth having.
      for (var i = 1; i <= 200; i++) {
        key(i).resolve();
        if (i % 8 == 0) {
          expect(identical(kept.resolve(), first), isTrue, reason: '$i');
        }
      }
    });

    test('presets survive any amount of churn', () {
      final ocean = BeamColors.ocean.resolve();
      for (var i = 0; i < 200; i++) {
        BeamColors([Color(0xFF3F0000 | i)]).resolve();
      }
      expect(identical(BeamColors.ocean.resolve(), ocean), isTrue);
    });

    test('mutating the source lists cannot corrupt a cached palette', () {
      final colors = <Color>[const Color(0xFF0A0B0C), const Color(0xFF0D0E0F)];
      final stops = <double>[0.1, 0.6];
      final choice = BeamColors(colors, stops: stops);
      final palette = choice.resolve();

      colors[0] = _green;
      stops[1] = 0.9;

      expect(palette.colors, const [Color(0xFF0A0B0C), Color(0xFF0D0E0F)]);
      expect(palette.stops, const [0.1, 0.6]);
      expect(
        identical(
          const BeamColors(
            [Color(0xFF0A0B0C), Color(0xFF0D0E0F)],
            stops: [0.1, 0.6],
          ).resolve(),
          palette,
        ),
        isTrue,
        reason: 'the original value still finds its palette',
      );
      // The mutated choice is now a different value with its own palette.
      final mutated = choice.resolve();
      expect(mutated.colors, [_green, const Color(0xFF0D0E0F)]);
      expect(mutated.stops, [0.1, 0.9]);
    });

    test('resolved palettes are unmodifiable', () {
      final p = BeamColors([_red, Color(int.parse('0xFF0F0F0F'))]).resolve();
      expect(() => p.colors[0] = _blue, throwsUnsupportedError);
      expect(() => p.stops[0] = 0.5, throwsUnsupportedError);
    });
  });

  test('toString names the factory', () {
    expect(BeamColors.ocean.toString(), 'BeamColors.ocean');
    expect(
      const BeamColors.solid(_red).toString(),
      startsWith('BeamColors.solid('),
    );
    expect(
      const BeamColors.fromSeed(
        _red,
        harmony: BeamSeedHarmony.triadic,
      ).toString(),
      endsWith('harmony: triadic)'),
    );
    expect(
      BeamColors.ocean.scaleAlpha(0.5).toString(),
      'BeamColors.ocean.scaleAlpha(0.5)',
    );
  });
}
