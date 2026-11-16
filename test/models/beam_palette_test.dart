import 'dart:ui';

import 'package:flutter/foundation.dart' show describeIdentity;
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/look/palette_tables.dart';
import 'package:prismatic/src/models/beam_palette.dart';
import 'package:prismatic/src/render/color_math.dart';

const Color _red = Color(0xFFFF0000);
const Color _green = Color(0xFF00FF00);
const Color _blue = Color(0xFF0000FF);

void _expectColor(Color actual, Color expected, {String? reason}) {
  expect(actual.a, closeTo(expected.a, 1e-9), reason: reason);
  expect(actual.r, closeTo(expected.r, 1e-9), reason: reason);
  expect(actual.g, closeTo(expected.g, 1e-9), reason: reason);
  expect(actual.b, closeTo(expected.b, 1e-9), reason: reason);
}

/// [BeamPalette] is the resolved ring of colour stops the shader shades by;
/// its `sample` is the CPU mirror of the shader's palette lookup.
void main() {
  const palette = BeamPalette(
    colors: [_red, _green, _blue],
    stops: [0.1, 0.4, 0.7],
  );

  group('sample', () {
    test('returns each stop colour at its stop', () {
      for (var i = 0; i < palette.length; i++) {
        _expectColor(
          palette.sample(palette.stops[i]),
          palette.colors[i],
          reason: 'stop $i',
        );
      }
    });

    test('matches samplePalette everywhere in [0, 1)', () {
      for (var i = 0; i < 200; i++) {
        final u = i / 200;
        expect(
          palette.sample(u),
          samplePalette(palette.colors, palette.stops, u, wrap: true),
          reason: 'u = $u',
        );
      }
    });

    test('wraps any coordinate into the ring', () {
      for (final u in [0.05, 0.3, 0.55, 0.85]) {
        for (final turns in [-2, -1, 1, 3]) {
          _expectColor(
            palette.sample(u + turns),
            palette.sample(u),
            reason: 'u = $u, turns = $turns',
          );
        }
      }
      _expectColor(palette.sample(1), palette.sample(0));
    });

    test('blends the last stop back into the first across top-centre', () {
      // Halfway between the last stop (0.7) and the first (0.1 + 1).
      _expectColor(palette.sample(0.9), mixColor(_blue, _red, 0.5));
      // Top-centre sits on that same blend, three quarters of the way across.
      _expectColor(palette.sample(0), mixColor(_blue, _red, 0.75));
    });

    test('blends neighbouring stops in between', () {
      _expectColor(palette.sample(0.25), mixColor(_red, _green, 0.5));
      final mid = palette.sample(0.55);
      expect(mid.g, greaterThan(0));
      expect(mid.b, greaterThan(0));
      expect(mid.r, closeTo(0, 1e-9));
    });

    test('a single stop is that colour all the way round', () {
      const solid = BeamPalette(colors: [_green], stops: [0.3]);
      for (final u in [0.0, 0.3, 0.6, 0.99, 1.5]) {
        expect(solid.sample(u), _green);
      }
    });
  });

  group('evenStops', () {
    test('spaces n stops evenly from zero', () {
      for (var n = 1; n <= maxPaletteStops; n++) {
        final stops = BeamPalette.evenStops(n);
        expect(stops, hasLength(n));
        expect(stops.first, 0);
        for (var i = 0; i < n; i++) {
          expect(stops[i], closeTo(i / n, 1e-12));
          expect(stops[i], lessThan(1));
        }
      }
    });

    test('is unmodifiable', () {
      expect(() => BeamPalette.evenStops(3).add(0.9), throwsUnsupportedError);
    });
  });

  group('equality', () {
    test('compares colours, stops, and fixedHue by value', () {
      final rebuilt = BeamPalette(
        colors: List<Color>.of(palette.colors),
        stops: List<double>.of(palette.stops),
      );
      expect(rebuilt, palette);
      expect(rebuilt.hashCode, palette.hashCode);

      for (final other in [
        const BeamPalette(
          colors: [_red, _green, _blue],
          stops: [0.1, 0.4, 0.8],
        ),
        const BeamPalette(colors: [_red, _blue, _blue], stops: [0.1, 0.4, 0.7]),
        const BeamPalette(
          colors: [_red, _green, _blue],
          stops: [0.1, 0.4, 0.7],
          fixedHue: true,
        ),
        const BeamPalette(colors: [_red, _green], stops: [0.1, 0.4]),
      ]) {
        expect(other, isNot(palette), reason: '$other');
      }
    });

    test('length counts the stops', () {
      expect(palette.length, 3);
      expect(const BeamPalette(colors: [_red], stops: [0]).length, 1);
    });

    test('toString names every field', () {
      final s = palette.toString();
      expect(s, startsWith('BeamPalette('));
      expect(s, contains('colors: ${palette.colors}'));
      expect(s, contains('stops: [0.1, 0.4, 0.7]'));
      expect(s, contains('fixedHue: false'));
      expect(s, contains('mono: false'));
      // Unset tables are left out, as an unset value-object field is.
      expect(s, isNot(contains('tables')));

      const drawn = BeamPalette(
        colors: [_red],
        stops: [0],
        tables: colorfulTables,
        tableColors: [_green, _blue],
        mono: true,
      );
      final d = drawn.toString();
      expect(d, contains('mono: true'));
      expect(d, contains('tables: ${describeIdentity(colorfulTables)}'));
      expect(d, contains('tableColors: [$_green, $_blue]'));
    });

    test('toString tells apart palettes that paint differently', () {
      // Equal colours and stops, each drawn another way: every one of these
      // compares unequal, so none may print the same.
      const plain = BeamPalette(colors: [_red], stops: [0]);
      final variants = [
        plain,
        const BeamPalette(colors: [_red], stops: [0], mono: true),
        const BeamPalette(colors: [_red], stops: [0], tables: colorfulTables),
        const BeamPalette(colors: [_red], stops: [0], tables: monoTables),
        const BeamPalette(colors: [_red], stops: [0], tableColors: [_blue]),
      ];
      final printed = {for (final p in variants) p.toString()};
      expect(printed, hasLength(variants.length));
    });
  });
}
