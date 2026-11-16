import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/models/beam_config.dart';
import 'package:prismatic/src/models/beam_palette.dart';

double _seconds(Duration d) =>
    d.inMicroseconds / Duration.microsecondsPerSecond;

BeamConfig _resolve({
  BeamEffect effect = const BeamEffect.rotate(),
  BeamPalette? palette,
  Brightness brightness = Brightness.dark,
  BeamStyle style = const BeamStyle(),
  BeamShape shape = const BeamShape(),
  BeamTiming timing = const BeamTiming(),
  TextDirection textDirection = TextDirection.ltr,
}) => BeamConfig.resolve(
  effect: effect,
  palette: palette ?? BeamColors.colorful.resolve(),
  brightness: brightness,
  style: style,
  shape: shape,
  timing: timing,
  textDirection: textDirection,
);

/// `BeamConfig` is the settled value the renderer paints from: every
/// inherited field filled in from the effect's defaults, every number
/// clamped to what the shader can use, and the whole thing value-equal so a
/// rebuilt-inline style never repaints.
void main() {
  group('effect defaults', () {
    for (final effect in BeamEffect.values) {
      test(
        '${effect.name}: unset timing and hue mode come from the effect',
        () {
          final config = _resolve(effect: effect);
          expect(config.effect, effect);
          expect(
            config.cycleSeconds,
            closeTo(_seconds(effect.defaultCycle), 1e-12),
          );
          expect(
            config.gapSeconds,
            closeTo(_seconds(effect.defaultCycleGap), 1e-12),
          );
          expect(
            config.huePeriodSeconds,
            closeTo(_seconds(effect.defaultHuePeriod), 1e-12),
          );
          expect(config.hueMode, effect.defaultHueMode);
          expect(config.cycleSeconds, greaterThan(0));
          expect(config.huePeriodSeconds, greaterThan(0));
        },
      );

      test('${effect.name}: explicit timing and hue mode win', () {
        final config = _resolve(
          effect: effect,
          style: const BeamStyle(hueMode: BeamHueMode.continuous),
          timing: const BeamTiming(
            cycle: Duration(milliseconds: 1234),
            cycleGap: Duration(milliseconds: 321),
            huePeriod: Duration(seconds: 5),
          ),
        );
        expect(config.cycleSeconds, closeTo(1.234, 1e-12));
        expect(config.gapSeconds, closeTo(0.321, 1e-12));
        expect(config.huePeriodSeconds, closeTo(5, 1e-12));
        expect(config.hueMode, BeamHueMode.continuous);
      });
    }
  });

  group('hue', () {
    test('a fixed-hue palette never drifts, whatever the style asks', () {
      for (final colors in [BeamColors.mono, BeamColors.gold]) {
        for (final mode in [null, ...BeamHueMode.values]) {
          for (final effect in BeamEffect.values) {
            final config = _resolve(
              effect: effect,
              palette: colors.resolve(),
              style: BeamStyle(hueMode: mode),
            );
            expect(
              config.hueMode,
              BeamHueMode.none,
              reason: '$colors / $mode / ${effect.name}',
            );
          }
        }
      }
    });

    test('a drifting palette keeps the requested mode', () {
      for (final mode in BeamHueMode.values) {
        expect(_resolve(style: BeamStyle(hueMode: mode)).hueMode, mode);
      }
    });

    test('hueShift and hueBase pass through', () {
      final config = _resolve(
        style: const BeamStyle(hueShift: 12, hueBase: -40),
      );
      expect(config.hueShift, 12);
      expect(config.hueBase, -40);
      expect(_resolve().hueShift, greaterThan(0));
      expect(_resolve().hueBase, 0);
    });
  });

  group('defaults and pass-through', () {
    test(
      'an empty style, shape and timing resolve to the documented defaults',
      () {
        final c = _resolve();
        expect(c.strength, 1);
        expect(c.glow, 1);
        expect(c.borderWidth, 1);
        expect(c.ringOffset, 0);
        expect(c.superellipse, isFalse);
        expect(c.segment, isNull);
        expect(c.dashes, 0);
        expect(c.direction, BeamDirection.forward);
        expect(c.phaseOffset, 0);
      },
    );

    test('set fields pass through unchanged', () {
      final c = _resolve(
        style: const BeamStyle(strength: 0.4, glow: 2.5),
        shape: const BeamShape(
          superellipse: true,
          borderWidth: 3,
          ringOffset: -6,
          segment: BeamSegment.bottomEdge,
          dashes: 12,
        ),
        timing: const BeamTiming(
          direction: BeamDirection.bounce,
          phaseOffset: 0.3,
        ),
      );
      expect(c.strength, 0.4);
      expect(c.glow, 2.5);
      expect(c.superellipse, isTrue);
      expect(c.borderWidth, 3);
      expect(c.ringOffset, -6);
      expect(c.segment, BeamSegment.bottomEdge);
      expect(c.dashes, 12);
      expect(c.direction, BeamDirection.bounce);
      expect(c.phaseOffset, 0.3);
    });

    test('the palette is carried as given', () {
      final palette = BeamColors.ocean.resolve();
      expect(identical(_resolve(palette: palette).palette, palette), isTrue);
    });

    test('isDark follows the brightness', () {
      expect(_resolve().isDark, isTrue);
      expect(_resolve(brightness: Brightness.light).isDark, isFalse);
    });
  });

  group('clamping', () {
    test('strength is clamped to 0–1', () {
      expect(_resolve(style: const BeamStyle(strength: 1.7)).strength, 1);
      expect(_resolve(style: const BeamStyle(strength: -0.5)).strength, 0);
      expect(_resolve(style: const BeamStyle(strength: 0)).strength, 0);
    });

    test('glow 0 is kept — a bare stroke', () {
      expect(_resolve(style: const BeamStyle(glow: 0)).glow, 0);
    });

    test('a negative border width becomes 0', () {
      expect(_resolve(shape: const BeamShape(borderWidth: -2)).borderWidth, 0);
    });

    test('a negative gap becomes 0', () {
      final c = _resolve(
        timing: const BeamTiming(cycleGap: Duration(milliseconds: -400)),
      );
      expect(c.gapSeconds, 0);
    });

    test('a vanishing cycle or hue period is floored above zero', () {
      final c = _resolve(
        timing: const BeamTiming(
          cycle: Duration(microseconds: 1),
          huePeriod: Duration(microseconds: 1),
        ),
      );
      expect(c.cycleSeconds, greaterThan(1e-6));
      expect(c.huePeriodSeconds, greaterThan(1e-6));
      // The floor is a floor, not a replacement: an ordinary cycle is kept.
      expect(
        _resolve(timing: const BeamTiming(cycle: Duration(milliseconds: 250)))
            .cycleSeconds,
        closeTo(0.25, 1e-12),
      );
    });
  });

  group('radius', () {
    test('defaults to 16 on every corner', () {
      for (final dir in TextDirection.values) {
        expect(
          _resolve(textDirection: dir).borderRadius,
          const BorderRadius.all(Radius.circular(16)),
        );
      }
    });

    test('a uniform radius resolves to itself', () {
      expect(
        _resolve(shape: const BeamShape.all(24)).borderRadius,
        BorderRadius.circular(24),
      );
    });

    test('a directional radius resolves for the text direction', () {
      const shape = BeamShape(
        radius: BorderRadiusDirectional.only(topStart: Radius.circular(10)),
      );
      final ltr = _resolve(shape: shape).borderRadius;
      final rtl = _resolve(
        shape: shape,
        textDirection: TextDirection.rtl,
      ).borderRadius;
      expect(ltr.topLeft, const Radius.circular(10));
      expect(ltr.topRight, Radius.zero);
      expect(rtl.topRight, const Radius.circular(10));
      expect(rtl.topLeft, Radius.zero);
      expect(ltr, isNot(rtl));
    });
  });

  group('beamCount', () {
    test('rotate carries its count', () {
      for (var n = 1; n <= 4; n++) {
        expect(_resolve(effect: BeamEffect.rotate(count: n)).beamCount, n);
      }
    });

    test('every other effect is a single beam', () {
      for (final effect in BeamEffect.values.where((e) => e is! RotateEffect)) {
        expect(_resolve(effect: effect).beamCount, 1, reason: effect.name);
      }
    });
  });

  group('equality', () {
    test('two resolutions of the same inputs are equal', () {
      final a = _resolve(
        style: BeamStyle(strength: double.parse('0.5')),
        shape: BeamShape.circular(20),
      );
      final b = _resolve(
        style: BeamStyle(strength: double.parse('0.5')),
        shape: BeamShape.circular(20),
      );
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    // Every input that reaches a painted value, one at a time.
    final mutations = <String, BeamConfig Function()>{
      'effect': () => _resolve(effect: const BeamEffect.line()),
      'effect parameter': () =>
          _resolve(effect: const BeamEffect.rotate(comet: true)),
      'palette': () => _resolve(palette: BeamColors.ocean.resolve()),
      'brightness': () => _resolve(brightness: Brightness.light),
      'strength': () => _resolve(style: const BeamStyle(strength: 0.8)),
      'glow': () => _resolve(style: const BeamStyle(glow: 2)),
      'hueMode': () =>
          _resolve(style: const BeamStyle(hueMode: BeamHueMode.none)),
      'hueShift': () => _resolve(style: const BeamStyle(hueShift: 7)),
      'hueBase': () => _resolve(style: const BeamStyle(hueBase: 7)),
      'radius': () => _resolve(shape: const BeamShape.all(4)),
      'superellipse': () =>
          _resolve(shape: const BeamShape(superellipse: true)),
      'borderWidth': () => _resolve(shape: const BeamShape(borderWidth: 2)),
      'ringOffset': () => _resolve(shape: const BeamShape(ringOffset: 2)),
      'segment': () =>
          _resolve(shape: const BeamShape(segment: BeamSegment.topHalf)),
      'dashes': () => _resolve(shape: const BeamShape(dashes: 3)),
      'cycle': () =>
          _resolve(timing: const BeamTiming(cycle: Duration(seconds: 9))),
      'cycleGap': () =>
          _resolve(timing: const BeamTiming(cycleGap: Duration(seconds: 1))),
      'direction': () =>
          _resolve(timing: const BeamTiming(direction: BeamDirection.reverse)),
      'phaseOffset': () => _resolve(timing: const BeamTiming(phaseOffset: 0.5)),
      'huePeriod': () =>
          _resolve(timing: const BeamTiming(huePeriod: Duration(seconds: 2))),
    };

    for (final MapEntry(key: name, value: build) in mutations.entries) {
      test('$name breaks equality', () {
        // Only equality: unequal configs may share a hash code.
        expect(build(), isNot(_resolve()));
      });
    }

    test('the mutations differ from each other too', () {
      final configs = [for (final build in mutations.values) build()];
      expect(configs.toSet(), hasLength(configs.length));
    });

    test('text direction only matters for a directional radius', () {
      expect(_resolve(textDirection: TextDirection.rtl), _resolve());
      const shape = BeamShape(
        radius: BorderRadiusDirectional.only(topStart: Radius.circular(10)),
      );
      expect(
        _resolve(shape: shape, textDirection: TextDirection.rtl),
        isNot(_resolve(shape: shape)),
      );
    });

    test('speed is not part of the painted value', () {
      expect(_resolve(timing: const BeamTiming(speed: 3)), _resolve());
    });

    test('an equal but separately resolved palette keeps equality', () {
      final a = _resolve(
        palette: BeamColors([
          const Color(0xFF102030),
          Color(int.parse('0xFF405060')),
        ]).resolve(),
      );
      final b = _resolve(
        palette: BeamPalette(
          colors: const [Color(0xFF102030), Color(0xFF405060)],
          stops: BeamPalette.evenStops(2),
        ),
      );
      expect(a, b);
    });
  });
}
