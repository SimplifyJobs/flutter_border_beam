import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// The four beam value objects and the theme data share one contract: every
/// field is nullable and means *inherit*, `merge` layers the argument over
/// the receiver, `copyWith` keeps what it is not given, and equality is by
/// value so a rebuilt-inline object never re-resolves a config.
void main() {
  group('BeamStyle', () {
    test('merge lets the argument win field by field', () {
      const base = BeamStyle(
        colors: BeamColors.ocean,
        strength: 0.5,
        hueBase: 10,
      );
      const over = BeamStyle(colors: BeamColors.sunset, glowBoost: 2);
      final merged = base.merge(over);
      expect(merged.colors, BeamColors.sunset, reason: 'argument wins');
      expect(merged.strength, 0.5, reason: 'null inherits');
      expect(merged.hueBase, 10);
      expect(merged.glowBoost, 2);
    });

    test('merge(null) returns the receiver unchanged', () {
      const base = BeamStyle(strength: 0.25);
      expect(base.merge(null), base);
    });

    test('copyWith keeps unnamed fields', () {
      const base = BeamStyle(colors: BeamColors.mono, saturation: 2);
      final copy = base.copyWith(saturation: 3);
      expect(copy.colors, BeamColors.mono);
      expect(copy.saturation, 3);
    });

    test('equality and hashCode are by value', () {
      const a = BeamStyle(colors: BeamColors.ocean, strength: 0.4);
      const b = BeamStyle(colors: BeamColors.ocean, strength: 0.4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const BeamStyle(colors: BeamColors.ocean)));
    });

    test('themeConfig is part of the value', () {
      final preset = BeamThemeConfig.presetFor(
        BeamVariant.rotate,
        Brightness.dark,
      );
      expect(
        BeamStyle(themeConfig: preset),
        BeamStyle(themeConfig: preset.copyWith()),
      );
      expect(
        BeamStyle(themeConfig: preset),
        isNot(BeamStyle(themeConfig: preset.copyWith(bloomOpacity: 0.1))),
      );
    });
  });

  group('BeamShape', () {
    test('circular fills all four corners', () {
      final shape = BeamShape.circular(12, superellipse: true);
      expect(shape.radius, BorderRadius.circular(12));
      expect(shape.superellipse, isTrue);
      expect(shape.borderWidth, isNull);
    });

    test('stadium is an infinite radius the geometry clamps', () {
      const shape = BeamShape.stadium();
      expect(
        shape.radius,
        const BorderRadius.all(Radius.circular(double.infinity)),
      );
    });

    test('merge and copyWith follow the inherit contract', () {
      const base = BeamShape(borderWidth: 2);
      final merged = base.merge(
        const BeamShape(radius: BorderRadius.zero, superellipse: true),
      );
      expect(merged.borderWidth, 2);
      expect(merged.radius, BorderRadius.zero);
      expect(merged.superellipse, isTrue);
      expect(base.copyWith(superellipse: false).borderWidth, 2);
    });

    test('equality is by value', () {
      expect(
        const BeamShape(radius: BorderRadius.zero, borderWidth: 1),
        const BeamShape(radius: BorderRadius.zero, borderWidth: 1),
      );
      expect(
        const BeamShape(radius: BorderRadius.zero, borderWidth: 1).hashCode,
        const BeamShape(radius: BorderRadius.zero, borderWidth: 1).hashCode,
      );
      expect(BeamShape.circular(4), isNot(BeamShape.circular(5)));
    });
  });

  group('BeamTiming', () {
    test('merge lets the argument win field by field', () {
      const base = BeamTiming(cycle: Duration(seconds: 2), speed: 2);
      const over = BeamTiming(cycleGap: Duration(seconds: 1));
      final merged = base.merge(over);
      expect(merged.cycle, const Duration(seconds: 2));
      expect(merged.speed, 2);
      expect(merged.cycleGap, const Duration(seconds: 1));
      expect(merged.huePeriod, isNull);
    });

    test('copyWith keeps unnamed fields', () {
      const base = BeamTiming(breatheFactor: 1.5, spikeFactor: 2);
      final copy = base.copyWith(spikeFactor: 3);
      expect(copy.breatheFactor, 1.5);
      expect(copy.spikeFactor, 3);
    });

    test('equality is by value', () {
      expect(
        const BeamTiming(cycle: Duration(seconds: 1)),
        const BeamTiming(cycle: Duration(seconds: 1)),
      );
      expect(
        const BeamTiming(cycle: Duration(seconds: 1)).hashCode,
        const BeamTiming(cycle: Duration(seconds: 1)).hashCode,
      );
      expect(
        const BeamTiming(cycle: Duration(seconds: 1)),
        isNot(const BeamTiming(cycle: Duration(seconds: 2))),
      );
    });
  });

  group('BeamPlayback', () {
    test('merge lets the argument win field by field', () {
      const base = BeamPlayback(active: false, autoPlay: false);
      const over = BeamPlayback(active: true, duration: Duration(seconds: 3));
      final merged = base.merge(over);
      expect(merged.active, isTrue);
      expect(merged.autoPlay, isFalse);
      expect(merged.duration, const Duration(seconds: 3));
      expect(merged.startAfter, isNull);
    });

    test('copyWith keeps unnamed fields', () {
      const base = BeamPlayback(active: false, respectReducedMotion: false);
      expect(base.copyWith(active: true).respectReducedMotion, isFalse);
    });

    test('equality is by value', () {
      expect(
        const BeamPlayback(active: false),
        const BeamPlayback(active: false),
      );
      expect(
        const BeamPlayback(active: false).hashCode,
        const BeamPlayback(active: false).hashCode,
      );
      expect(
        const BeamPlayback(active: false),
        isNot(const BeamPlayback(active: true)),
      );
    });
  });

  group('BorderBeamThemeData', () {
    test('merge composes each slot field by field', () {
      const outer = BorderBeamThemeData(
        style: BeamStyle(colors: BeamColors.ocean, strength: 0.5),
        timing: BeamTiming(cycle: Duration(seconds: 4)),
      );
      const inner = BorderBeamThemeData(
        style: BeamStyle(strength: 0.9),
        shape: BeamShape(superellipse: true),
      );
      final merged = outer.merge(inner);
      expect(merged.style?.colors, BeamColors.ocean, reason: 'outer survives');
      expect(merged.style?.strength, 0.9, reason: 'inner wins');
      expect(merged.shape?.superellipse, isTrue);
      expect(merged.timing?.cycle, const Duration(seconds: 4));
      expect(merged.playback, isNull);
    });

    test('merge takes the argument slot when the receiver has none', () {
      const inner = BorderBeamThemeData(playback: BeamPlayback(active: false));
      expect(
        const BorderBeamThemeData().merge(inner).playback,
        const BeamPlayback(active: false),
      );
    });

    test('merge(null) returns the receiver unchanged', () {
      const data = BorderBeamThemeData(shape: BeamShape(borderWidth: 3));
      expect(data.merge(null), data);
    });

    test('copyWith and equality are by value', () {
      const data = BorderBeamThemeData(style: BeamStyle(hueBase: 5));
      expect(
        data.copyWith(shape: const BeamShape(borderWidth: 2)),
        const BorderBeamThemeData(
          style: BeamStyle(hueBase: 5),
          shape: BeamShape(borderWidth: 2),
        ),
      );
      expect(
        data.hashCode,
        const BorderBeamThemeData(style: BeamStyle(hueBase: 5)).hashCode,
      );
      expect(data, isNot(const BorderBeamThemeData()));
    });
  });
}
