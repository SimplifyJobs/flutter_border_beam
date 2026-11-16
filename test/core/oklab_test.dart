import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/core/oklab.dart';
import 'package:prismatic/src/distortion_wave/models/wave_palette.dart';

/// `Oklab`: sRGB in and out of OKLab, where the shaders blend palette
/// colours. Known values are Björn Ottosson's, from the OKLab write-up.
void main() {
  const oneLevel = 1 / 255;

  void expectRoundTrip(Color color) {
    final back = Oklab.fromColor(color).toColor();
    expect(back.a, 1, reason: '$color');
    expect(
      (back.r - color.r).abs(),
      lessThanOrEqualTo(oneLevel),
      reason: '$color red',
    );
    expect(
      (back.g - color.g).abs(),
      lessThanOrEqualTo(oneLevel),
      reason: '$color green',
    );
    expect(
      (back.b - color.b).abs(),
      lessThanOrEqualTo(oneLevel),
      reason: '$color blue',
    );
  }

  void expectOklab(Oklab actual, double l, double a, double b, double within) {
    expect(actual.l, closeTo(l, within), reason: 'L of $actual');
    expect(actual.a, closeTo(a, within), reason: 'a of $actual');
    expect(actual.b, closeTo(b, within), reason: 'b of $actual');
  }

  test('round trips sRGB within one level, across the cube', () {
    const levels = [0, 1, 17, 51, 102, 128, 153, 204, 254, 255];
    for (final r in levels) {
      for (final g in levels) {
        for (final b in levels) {
          expectRoundTrip(Color.fromARGB(255, r, g, b));
        }
      }
    }
  });

  test('round trips every wave palette colour', () {
    for (final palette in WavePalette.presets.values) {
      for (final c in [...palette.colors, palette.ahead, palette.behind]) {
        expectRoundTrip(c);
      }
    }
  });

  test('white is L 1 with no colour; black is all zero', () {
    expectOklab(Oklab.fromColor(const Color(0xFFFFFFFF)), 1, 0, 0, 1e-4);
    final black = Oklab.fromColor(const Color(0xFF000000));
    expect(black.l, 0);
    expect(black.a, 0);
    expect(black.b, 0);
  });

  test('the primaries match the reference values', () {
    expectOklab(
      Oklab.fromColor(const Color(0xFFFF0000)),
      0.627955,
      0.224863,
      0.125846,
      1e-4,
    );
    expectOklab(
      Oklab.fromColor(const Color(0xFF00FF00)),
      0.866440,
      -0.233888,
      0.179498,
      1e-4,
    );
    expectOklab(
      Oklab.fromColor(const Color(0xFF0000FF)),
      0.452014,
      -0.032457,
      -0.311528,
      1e-4,
    );
  });

  test('a grey has no colour, and lightness rises with it', () {
    var last = -1.0;
    for (var v = 0; v <= 255; v += 15) {
      final grey = Oklab.fromColor(Color.fromARGB(255, v, v, v));
      expect(grey.a.abs(), lessThan(1e-4), reason: 'grey $v');
      expect(grey.b.abs(), lessThan(1e-4), reason: 'grey $v');
      expect(grey.l, greaterThan(last), reason: 'grey $v');
      last = grey.l;
    }
  });

  test('alpha is ignored on the way in and opaque on the way out', () {
    final translucent = Oklab.fromColor(const Color(0x4035BA00));
    final opaque = Oklab.fromColor(const Color(0xFF35BA00));
    expect(translucent, opaque);
    expect(translucent.toColor().a, 1);
  });

  test('toColor clips out of gamut', () {
    for (final lab in const [
      Oklab(2, 0, 0),
      Oklab(-1, 0, 0),
      Oklab(0.6, 0.5, 0),
      Oklab(0.6, -0.5, -0.5),
    ]) {
      final c = lab.toColor();
      for (final channel in [c.r, c.g, c.b]) {
        expect(channel, inInclusiveRange(0, 1), reason: '$lab');
      }
    }
    // Clipped to 1 before encoding, which lands within an ulp of 1.
    final white = const Oklab(2, 0, 0).toColor();
    for (final channel in [white.r, white.g, white.b]) {
      expect(channel, closeTo(1, 1e-12));
    }
    final black = const Oklab(-1, 0, 0).toColor();
    expect([black.r, black.g, black.b], [0, 0, 0]);
  });

  group('mix', () {
    final yellow = Oklab.fromColor(const Color(0xFFFFC915));
    final violet = Oklab.fromColor(const Color(0xFFB428E6));

    test('at 0 is the first colour', () {
      expect(yellow.mix(violet, 0), yellow);
    });

    test('at 1 is the second colour', () {
      expectOklab(yellow.mix(violet, 1), violet.l, violet.a, violet.b, 1e-12);
    });

    test('halfway is the midpoint of each coordinate', () {
      final mid = yellow.mix(violet, 0.5);
      expectOklab(
        mid,
        (yellow.l + violet.l) / 2,
        (yellow.a + violet.a) / 2,
        (yellow.b + violet.b) / 2,
        1e-12,
      );
    });

    test('black to white halfway is a mid grey', () {
      final mid = Oklab.fromColor(const Color(0xFF000000))
          .mix(Oklab.fromColor(const Color(0xFFFFFFFF)), 0.5);
      expectOklab(mid, 0.5, 0, 0, 1e-4);
    });
  });

  test('== and hashCode are by value; toString shows four places', () {
    final a = Oklab(double.parse('0.5'), 0.1, -0.2);
    const b = Oklab(0.5, 0.1, -0.2);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const Oklab(0.5, 0.1, -0.21)));
    expect(b.toString(), 'Oklab(0.5000, 0.1000, -0.2000)');
  });
}
