import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/models/model_validation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The four beam value objects and the theme data share one contract: every
/// field is nullable and means *inherit*, `merge` layers the argument over
/// the receiver, `copyWith` keeps what it is not given, and equality is by
/// value so a rebuilt-inline object never re-resolves a config.
void main() {
  /// Asserts each of [variants] differs from [base] and from every other.
  void expectEveryFieldCounts<T>(T base, List<T> variants) {
    for (final v in variants) {
      expect(v, isNot(base), reason: '$v');
      expect(v.hashCode, isNot(base.hashCode), reason: '$v');
    }
    for (var i = 0; i < variants.length; i++) {
      for (var j = i + 1; j < variants.length; j++) {
        expect(variants[i], isNot(variants[j]));
      }
    }
  }

  group('BeamStyle', () {
    const full = BeamStyle(
      colors: BeamColors.ocean,
      theme: BeamTheme.dark,
      strength: 0.5,
      glow: 1.5,
      hueShift: 20,
      hueMode: BeamHueMode.continuous,
      hueBase: 10,
    );

    test('merge lets the argument win field by field', () {
      final merged = full.merge(
        const BeamStyle(colors: BeamColors.sunset, glow: 2),
      );
      expect(merged.colors, BeamColors.sunset, reason: 'argument wins');
      expect(merged.glow, 2);
      expect(merged.theme, BeamTheme.dark, reason: 'null inherits');
      expect(merged.strength, 0.5);
      expect(merged.hueShift, 20);
      expect(merged.hueMode, BeamHueMode.continuous);
      expect(merged.hueBase, 10);
    });

    test('merging onto an empty style takes every field', () {
      expect(const BeamStyle().merge(full), full);
    });

    test('merge(null) returns the receiver', () {
      expect(identical(full.merge(null), full), isTrue);
    });

    test('copyWith keeps unnamed fields', () {
      final copy = full.copyWith(strength: 0.9, hueMode: BeamHueMode.none);
      expect(copy.strength, 0.9);
      expect(copy.hueMode, BeamHueMode.none);
      expect(copy.colors, BeamColors.ocean);
      expect(copy.glow, 1.5);
      expect(copy.hueBase, 10);
      expect(full.copyWith(), full);
    });

    test('equality and hashCode are by value', () {
      const a = BeamStyle(colors: BeamColors.ocean, strength: 0.4);
      final b = BeamStyle(
        colors: BeamColors.ocean,
        strength: double.parse('0.4'),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('every field is part of the value', () {
      expectEveryFieldCounts(const BeamStyle(), const [
        BeamStyle(colors: BeamColors.ocean),
        BeamStyle(theme: BeamTheme.light),
        BeamStyle(strength: 0.5),
        BeamStyle(glow: 2),
        BeamStyle(hueShift: 12),
        BeamStyle(hueMode: BeamHueMode.none),
        BeamStyle(hueBase: 90),
      ]);
    });

    test('toString lists only the fields that are set', () {
      expect(const BeamStyle().toString(), 'BeamStyle()');
      expect(
        const BeamStyle(
          strength: 0.5,
          hueMode: BeamHueMode.pingPong,
        ).toString(),
        'BeamStyle(strength: 0.5, hueMode: BeamHueMode.pingPong)',
      );
    });

    test('rejects a negative glow', () {
      expect(() => BeamStyle(glow: double.parse('-0.1')), throwsAssertionError);
      expect(BeamStyle(glow: double.parse('0')).glow, 0);
    });
  });

  group('BeamShape', () {
    test('all and circular are the same value for the same number', () {
      expect(const BeamShape.all(24), BeamShape.circular(24));
      expect(const BeamShape.all(24).hashCode, BeamShape.circular(24).hashCode);
      expect(
        const BeamShape.all(24, borderWidth: 2, superellipse: true),
        BeamShape.circular(24, borderWidth: 2, superellipse: true),
      );
      expect(
        const BeamShape.all(24),
        const BeamShape(radius: BorderRadius.all(Radius.circular(24))),
      );
      expect(const BeamShape.all(24), isNot(BeamShape.circular(25)));
      expect(
        const BeamShape.all(24).toString(),
        BeamShape.circular(24).toString(),
      );
    });

    test('all grows its number into a uniform BorderRadius', () {
      const shape = BeamShape.all(24, superellipse: true);
      expect(shape.radius, BorderRadius.circular(24));
      expect(shape.superellipse, isTrue);
      expect(shape.borderWidth, isNull);
      expect(
        identical(shape, const BeamShape.all(24, superellipse: true)),
        isTrue,
        reason: 'const-canonicalized, so a theme holding one stays const',
      );
    });

    test('stadium is an infinite radius on every corner', () {
      const shape = BeamShape.stadium(borderWidth: 2);
      expect(
        shape.radius,
        const BorderRadius.all(Radius.circular(double.infinity)),
      );
      expect(shape.borderWidth, 2);
      expect(shape, const BeamShape.stadium(borderWidth: 2));
    });

    test('resolveRadius falls back to the default on every corner', () {
      expect(BeamShape.defaultRadius, 16);
      for (final dir in TextDirection.values) {
        expect(
          const BeamShape().resolveRadius(dir),
          const BorderRadius.all(Radius.circular(BeamShape.defaultRadius)),
        );
      }
    });

    test('resolveRadius resolves a directional radius per text direction', () {
      const shape = BeamShape(
        radius: BorderRadiusDirectional.only(
          topStart: Radius.circular(8),
          bottomEnd: Radius.circular(20),
        ),
      );
      final ltr = shape.resolveRadius(TextDirection.ltr);
      expect(ltr.topLeft, const Radius.circular(8));
      expect(ltr.bottomRight, const Radius.circular(20));
      expect(ltr.topRight, Radius.zero);
      final rtl = shape.resolveRadius(TextDirection.rtl);
      expect(rtl.topRight, const Radius.circular(8));
      expect(rtl.bottomLeft, const Radius.circular(20));
      expect(rtl.topLeft, Radius.zero);
    });

    test('resolveRadius leaves an absolute radius alone', () {
      final shape = BeamShape.circular(9);
      expect(shape.resolveRadius(TextDirection.rtl), BorderRadius.circular(9));
    });

    test('merge lets the argument win field by field', () {
      const base = BeamShape.all(
        24,
        borderWidth: 2,
        ringOffset: 4,
        segment: BeamSegment.bottomHalf,
        dashes: 6,
      );
      final merged = base.merge(const BeamShape(superellipse: true, dashes: 8));
      expect(merged.radius, BorderRadius.circular(24), reason: 'inherits');
      expect(merged.borderWidth, 2);
      expect(merged.ringOffset, 4);
      expect(merged.segment, BeamSegment.bottomHalf);
      expect(merged.superellipse, isTrue, reason: 'argument wins');
      expect(merged.dashes, 8);
      expect(identical(base.merge(null), base), isTrue);
    });

    test('copyWith keeps unnamed fields and carries a uniform radius', () {
      const base = BeamShape.all(24, segment: BeamSegment.topEdge);
      final copy = base.copyWith(borderWidth: 3);
      expect(copy.radius, BorderRadius.circular(24));
      expect(copy.segment, BeamSegment.topEdge);
      expect(copy.borderWidth, 3);
      expect(
        base.copyWith(radius: BorderRadius.zero).radius,
        BorderRadius.zero,
        reason: 'an explicit radius replaces the uniform one',
      );
      expect(
        const BeamShape(
          radius: BorderRadius.zero,
        ).merge(const BeamShape.all(8)),
        const BeamShape.all(8),
      );
    });

    test('every field is part of the value', () {
      expectEveryFieldCounts(const BeamShape(), const [
        BeamShape(radius: BorderRadius.zero),
        BeamShape(superellipse: true),
        BeamShape(borderWidth: 2),
        BeamShape(ringOffset: 3),
        BeamShape(segment: BeamSegment.bottomHalf),
        BeamShape(dashes: 4),
      ]);
    });

    test('toString lists only the fields that are set', () {
      expect(const BeamShape().toString(), 'BeamShape()');
      expect(
        const BeamShape(borderWidth: 2, dashes: 3).toString(),
        'BeamShape(borderWidth: 2.0, dashes: 3)',
      );
    });

    test('every constructor rejects negative dashes', () {
      final negative = int.parse('-1');
      expect(() => BeamShape(dashes: negative), throwsAssertionError);
      expect(() => BeamShape.all(8, dashes: negative), throwsAssertionError);
      expect(
        () => BeamShape.circular(8, dashes: negative),
        throwsAssertionError,
      );
      expect(() => BeamShape.stadium(dashes: negative), throwsAssertionError);
    });
  });

  group('BeamTiming', () {
    const full = BeamTiming(
      cycle: Duration(seconds: 2),
      cycleGap: Duration(milliseconds: 500),
      speed: 1.5,
      direction: BeamDirection.reverse,
      phaseOffset: 0.25,
      huePeriod: Duration(seconds: 6),
    );

    test('merge lets the argument win field by field', () {
      final merged = full.merge(
        const BeamTiming(speed: 3, direction: BeamDirection.bounce),
      );
      expect(merged.speed, 3, reason: 'argument wins');
      expect(merged.direction, BeamDirection.bounce);
      expect(merged.cycle, const Duration(seconds: 2), reason: 'inherits');
      expect(merged.cycleGap, const Duration(milliseconds: 500));
      expect(merged.phaseOffset, 0.25);
      expect(merged.huePeriod, const Duration(seconds: 6));
      expect(const BeamTiming().merge(full), full);
      expect(identical(full.merge(null), full), isTrue);
    });

    test('copyWith keeps unnamed fields', () {
      final copy = full.copyWith(phaseOffset: 0.75);
      expect(copy.phaseOffset, 0.75);
      expect(copy.cycle, full.cycle);
      expect(copy.huePeriod, full.huePeriod);
      expect(full.copyWith(), full);
    });

    test('every field is part of the value', () {
      expectEveryFieldCounts(const BeamTiming(), const [
        BeamTiming(cycle: Duration(seconds: 1)),
        BeamTiming(cycleGap: Duration(seconds: 1)),
        BeamTiming(speed: 2),
        BeamTiming(direction: BeamDirection.bounce),
        BeamTiming(phaseOffset: 0.5),
        BeamTiming(huePeriod: Duration(seconds: 3)),
      ]);
      expect(
        const BeamTiming(cycle: Duration(seconds: 1)).hashCode,
        const BeamTiming(cycle: Duration(seconds: 1)).hashCode,
      );
    });

    test('toString lists only the fields that are set', () {
      expect(const BeamTiming().toString(), 'BeamTiming()');
      expect(
        const BeamTiming(
          direction: BeamDirection.reverse,
          phaseOffset: 0.5,
        ).toString(),
        'BeamTiming(direction: BeamDirection.reverse, phaseOffset: 0.5)',
      );
    });

    test('rejects a rate or phase that would break the arithmetic', () {
      double v(String s) => double.parse(s);
      expect(() => BeamTiming(speed: v('0')), throwsAssertionError);
      expect(() => BeamTiming(speed: v('-1')), throwsAssertionError);
      expect(() => BeamTiming(speed: v('NaN')), throwsAssertionError);
      expect(() => BeamTiming(speed: v('Infinity')), throwsAssertionError);
      expect(() => BeamTiming(phaseOffset: v('-0.01')), throwsAssertionError);
      expect(() => BeamTiming(phaseOffset: v('1.01')), throwsAssertionError);
      expect(() => BeamTiming(phaseOffset: v('NaN')), throwsAssertionError);
      expect(BeamTiming(phaseOffset: v('0')).phaseOffset, 0);
      expect(BeamTiming(phaseOffset: v('1')).phaseOffset, 1);
    });
  });

  group('validateBeamTiming', () {
    test('accepts an empty and a fully valid timing', () {
      expect(() => validateBeamTiming(const BeamTiming()), returnsNormally);
      expect(
        () => validateBeamTiming(
          const BeamTiming(
            cycle: Duration(seconds: 2),
            cycleGap: Duration.zero,
            speed: 0.5,
            phaseOffset: 1,
            huePeriod: Duration(milliseconds: 1),
          ),
        ),
        returnsNormally,
      );
    });

    // The constructor asserts catch speed and phaseOffset in debug builds,
    // so only the durations — which carry no assert — reach the runtime
    // check in a test run.
    test('rejects a non-positive cycle', () {
      expect(
        () => validateBeamTiming(const BeamTiming(cycle: Duration.zero)),
        throwsArgumentError,
      );
      expect(
        () => validateBeamTiming(
          const BeamTiming(cycle: Duration(milliseconds: -5)),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative cycle gap', () {
      expect(
        () => validateBeamTiming(
          const BeamTiming(cycleGap: Duration(microseconds: -1)),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive hue period', () {
      expect(
        () => validateBeamTiming(const BeamTiming(huePeriod: Duration.zero)),
        throwsArgumentError,
      );
      expect(
        () => validateBeamTiming(
          const BeamTiming(huePeriod: Duration(seconds: -1)),
        ),
        throwsArgumentError,
      );
    });
  });

  group('BeamPlayback', () {
    const full = BeamPlayback(
      active: false,
      autoPlay: false,
      startAfter: Duration(milliseconds: 200),
      duration: Duration(seconds: 3),
      repeat: BeamRepeat.count(2),
      reducedMotion: BeamReducedMotion.hide,
      pauseWhenOffscreen: false,
      fadeCurve: BeamPlayback.cssEase,
      debugFrozenAt: Duration(milliseconds: 1300),
    );

    test('merge lets the argument win field by field', () {
      final merged = full.merge(
        const BeamPlayback(active: true, reducedMotion: BeamReducedMotion.slow),
      );
      expect(merged.active, isTrue, reason: 'argument wins');
      expect(merged.reducedMotion, BeamReducedMotion.slow);
      expect(merged.autoPlay, isFalse, reason: 'inherits');
      expect(merged.startAfter, const Duration(milliseconds: 200));
      expect(merged.duration, const Duration(seconds: 3));
      expect(merged.repeat, const BeamRepeat.count(2));
      expect(merged.pauseWhenOffscreen, isFalse);
      expect(merged.fadeCurve, BeamPlayback.cssEase);
      expect(merged.debugFrozenAt, const Duration(milliseconds: 1300));
      expect(const BeamPlayback().merge(full), full);
      expect(identical(full.merge(null), full), isTrue);
    });

    test('copyWith keeps unnamed fields', () {
      final copy = full.copyWith(repeat: const BeamRepeat.once());
      expect(copy.repeat, const BeamRepeat.once());
      expect(copy.reducedMotion, BeamReducedMotion.hide);
      expect(copy.debugFrozenAt, full.debugFrozenAt);
      expect(full.copyWith(), full);
    });

    test('every field is part of the value', () {
      expectEveryFieldCounts(const BeamPlayback(), const [
        BeamPlayback(active: false),
        BeamPlayback(autoPlay: false),
        BeamPlayback(startAfter: Duration(seconds: 1)),
        BeamPlayback(duration: Duration(seconds: 1)),
        BeamPlayback(repeat: BeamRepeat.once()),
        BeamPlayback(reducedMotion: BeamReducedMotion.staticFrame),
        BeamPlayback(pauseWhenOffscreen: false),
        BeamPlayback(fadeCurve: BeamPlayback.cssEase),
        BeamPlayback(debugFrozenAt: Duration(seconds: 1)),
      ]);
      expect(
        const BeamPlayback(repeat: BeamRepeat.count(2)),
        isNot(const BeamPlayback(repeat: BeamRepeat.count(3))),
      );
    });

    test('toString lists only the fields that are set', () {
      expect(const BeamPlayback().toString(), 'BeamPlayback()');
      expect(
        const BeamPlayback(
          repeat: BeamRepeat.count(2),
          reducedMotion: BeamReducedMotion.hide,
        ).toString(),
        'BeamPlayback(repeat: BeamRepeat.count(2), '
        'reducedMotion: BeamReducedMotion.hide)',
      );
    });

    test('cssEase is the web ease curve', () {
      expect(BeamPlayback.cssEase, const Cubic(0.25, 0.1, 0.25, 1));
      expect(BeamPlayback.cssEase.transform(0), 0);
      expect(BeamPlayback.cssEase.transform(1), 1);
    });
  });

  group('BeamRepeat', () {
    test('forever carries no cycle count', () {
      expect(const BeamRepeat.forever().cycles, isNull);
      expect(const BeamRepeat.forever().toString(), 'BeamRepeat.forever()');
    });

    test('once is a count of one', () {
      expect(const BeamRepeat.once().cycles, 1);
      expect(const BeamRepeat.once(), const BeamRepeat.count(1));
      expect(
        const BeamRepeat.once().hashCode,
        const BeamRepeat.count(1).hashCode,
      );
    });

    test('count keeps its cycles and rejects fewer than one', () {
      expect(const BeamRepeat.count(4).cycles, 4);
      expect(const BeamRepeat.count(4).toString(), 'BeamRepeat.count(4)');
      expect(() => BeamRepeat.count(int.parse('0')), throwsAssertionError);
      expect(() => BeamRepeat.count(int.parse('-1')), throwsAssertionError);
    });

    test('equality is by cycle count', () {
      expect(const BeamRepeat.count(2), const BeamRepeat.count(2));
      expect(const BeamRepeat.count(2), isNot(const BeamRepeat.count(3)));
      expect(const BeamRepeat.count(2), isNot(const BeamRepeat.forever()));
      expect(const BeamRepeat.forever(), const BeamRepeat.forever());
    });
  });

  group('validateRepeat', () {
    // A count below one cannot be built in a debug run (the constructor
    // asserts first), so only the passing paths are reachable here.
    test('passes the budget through', () {
      expect(validateRepeat(null), isNull);
      expect(validateRepeat(const BeamRepeat.forever()), isNull);
      expect(validateRepeat(const BeamRepeat.once()), 1);
      expect(validateRepeat(const BeamRepeat.count(5)), 5);
    });
  });

  group('BorderBeamThemeData', () {
    test('merge composes each slot field by field', () {
      const outer = BorderBeamThemeData(
        effect: BeamEffect.pulse(),
        style: BeamStyle(colors: BeamColors.ocean, strength: 0.5),
        timing: BeamTiming(cycle: Duration(seconds: 4)),
      );
      const inner = BorderBeamThemeData(
        style: BeamStyle(strength: 0.9),
        shape: BeamShape(superellipse: true),
      );
      final merged = outer.merge(inner);
      expect(merged.effect, const BeamEffect.pulse(), reason: 'inherits');
      expect(merged.style?.colors, BeamColors.ocean);
      expect(merged.style?.strength, 0.9, reason: 'inner wins');
      expect(merged.shape?.superellipse, isTrue);
      expect(merged.timing?.cycle, const Duration(seconds: 4));
      expect(merged.playback, isNull);
    });

    test('an inner effect replaces the outer one whole', () {
      const outer = BorderBeamThemeData(
        effect: BeamEffect.rotate(count: 3, comet: true),
      );
      const inner = BorderBeamThemeData(effect: BeamEffect.rotate(length: 2));
      expect(outer.merge(inner).effect, const BeamEffect.rotate(length: 2));
    });

    test('merge(null), copyWith and equality', () {
      const data = BorderBeamThemeData(style: BeamStyle(hueBase: 5));
      expect(identical(data.merge(null), data), isTrue);
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
      expect(
        const BorderBeamThemeData(effect: BeamEffect.halo()),
        isNot(const BorderBeamThemeData(effect: BeamEffect.pulse())),
      );
    });
  });
}
