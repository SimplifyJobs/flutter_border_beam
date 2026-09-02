import 'dart:ui' show Brightness, Path, Rect;

import 'package:flutter/animation.dart';
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

    test('the beam-shaping fields follow the inherit contract', () {
      const base = BeamStyle(
        hueMode: BeamHueMode.continuous,
        tailLength: 2,
        glowSpread: 1.5,
        comet: true,
        sparkle: 0.4,
        segments: 8,
      );
      final merged = base.merge(
        const BeamStyle(tailLength: 3, comet: false, segments: 12),
      );
      expect(merged.hueMode, BeamHueMode.continuous, reason: 'null inherits');
      expect(merged.tailLength, 3, reason: 'argument wins');
      expect(merged.glowSpread, 1.5);
      expect(merged.comet, isFalse, reason: 'false is a value, not a null');
      expect(merged.sparkle, 0.4);
      expect(merged.segments, 12);

      final copy = base.copyWith(sparkle: 0.9);
      expect(copy.sparkle, 0.9);
      expect(copy.hueMode, BeamHueMode.continuous);
      expect(copy.tailLength, 2);
      expect(copy.glowSpread, 1.5);
      expect(copy.comet, isTrue);
      expect(copy.segments, 8);
    });

    test('every beam-shaping field is part of the value', () {
      const base = BeamStyle();
      const variants = <BeamStyle>[
        BeamStyle(hueMode: BeamHueMode.continuous),
        BeamStyle(tailLength: 2),
        BeamStyle(glowSpread: 2),
        BeamStyle(comet: true),
        BeamStyle(sparkle: 0.5),
        BeamStyle(segments: 6),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base), reason: '$variant');
        expect(variant.hashCode, isNot(base.hashCode), reason: '$variant');
      }
      expect(
        const BeamStyle(tailLength: 2, comet: true),
        const BeamStyle(tailLength: 2, comet: true),
      );
    });

    test('toString lists only the fields that are set', () {
      expect(
        const BeamStyle(
          hueMode: BeamHueMode.pingPong,
          tailLength: 2,
          glowSpread: 1.5,
          comet: true,
          sparkle: 0.25,
          segments: 4,
        ).toString(),
        'BeamStyle(hueMode: BeamHueMode.pingPong, tailLength: 2.0, '
        'glowSpread: 1.5, comet: true, sparkle: 0.25, segments: 4)',
      );
      expect(const BeamStyle().toString(), 'BeamStyle()');
    });
  });

  test('the reference-port fields follow the inherit contract', () {
    const base = BeamStyle(
      innerSizeScale: 0.6,
      renderScale: 0.5,
      pulseOutsideTuning: BeamPulseOutsideTuning.stock,
    );
    final merged = base.merge(const BeamStyle(renderScale: 0.25));
    expect(merged.innerSizeScale, 0.6, reason: 'null inherits');
    expect(merged.renderScale, 0.25, reason: 'argument wins');
    expect(merged.pulseOutsideTuning, BeamPulseOutsideTuning.stock);

    final copy = base.copyWith(innerSizeScale: 1.4);
    expect(copy.innerSizeScale, 1.4);
    expect(copy.renderScale, 0.5);
    expect(copy.pulseOutsideTuning, BeamPulseOutsideTuning.stock);
  });

  test('every reference-port field is part of the value', () {
    const base = BeamStyle();
    const variants = <BeamStyle>[
      BeamStyle(innerSizeScale: 0.6),
      BeamStyle(renderScale: 0.5),
      BeamStyle(pulseOutsideTuning: BeamPulseOutsideTuning.stock),
    ];
    for (final variant in variants) {
      expect(variant, isNot(base), reason: '$variant');
      expect(variant.hashCode, isNot(base.hashCode), reason: '$variant');
    }
    expect(
      const BeamStyle(innerSizeScale: 0.6, renderScale: 0.5),
      const BeamStyle(innerSizeScale: 0.6, renderScale: 0.5),
    );
    expect(
      const BeamStyle(pulseOutsideTuning: BeamPulseOutsideTuning.demo),
      isNot(const BeamStyle(pulseOutsideTuning: BeamPulseOutsideTuning.stock)),
    );
  });

  test('toString lists the reference-port fields', () {
    expect(
      const BeamStyle(
        innerSizeScale: 0.6,
        renderScale: 0.5,
        pulseOutsideTuning: BeamPulseOutsideTuning.stock,
      ).toString(),
      'BeamStyle(innerSizeScale: 0.6, renderScale: 0.5, '
      'pulseOutsideTuning: BeamPulseOutsideTuning.stock)',
    );
  });

  test('pulseOutsideStock cancels the demo tuning it can reach', () {
    const stock = BeamStyle.pulseOutsideStock;
    expect(stock.pulseOutsideTuning, BeamPulseOutsideTuning.stock);
    expect(stock.glowBoost, closeTo(1 / 1.05, 1e-12));
    expect(stock.strokeOpacityFactor, closeTo(1 / 1.71, 1e-12));
    expect(stock.innerOpacityFactor, stock.strokeOpacityFactor);
    expect(stock.bloomOpacityFactor, stock.strokeOpacityFactor);
    expect(stock.glowBrightness, 1.3);
    expect(stock.glowSaturation, 1.2);
    expect(
      stock.merge(const BeamStyle(glowBrightness: 2)).glowBrightness,
      2,
      reason: 'it is a starting point, not a lock',
    );
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

    test('all is the const path to a uniform radius', () {
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

    test('all and circular are the same value', () {
      expect(const BeamShape.all(24), BeamShape.circular(24));
      expect(const BeamShape.all(24).hashCode, BeamShape.circular(24).hashCode);
      expect(
        const BeamShape.all(24, borderWidth: 2),
        BeamShape.circular(24, borderWidth: 2),
      );
      expect(const BeamShape.all(24), isNot(BeamShape.circular(25)));
      expect(
        const BeamShape.all(24),
        const BeamShape(radius: BorderRadius.all(Radius.circular(24))),
      );
      expect(
        const BeamShape.all(24).toString(),
        BeamShape.circular(24).toString(),
      );
    });

    test('copyWith and merge carry a uniform radius through', () {
      const base = BeamShape.all(24);
      expect(base.copyWith(borderWidth: 2).radius, BorderRadius.circular(24));
      expect(
        base.merge(const BeamShape(superellipse: true)).radius,
        BorderRadius.circular(24),
      );
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

    test('the geometry fields follow the inherit contract', () {
      final contour = BeamPathContour(
        (rect) => Path()..addRect(rect),
        key: 'rect',
      );
      final base = BeamShape(
        edge: BeamEdge.top,
        ringOffset: 4,
        contour: contour,
      );
      final merged = base.merge(const BeamShape(edge: BeamEdge.left));
      expect(merged.edge, BeamEdge.left, reason: 'argument wins');
      expect(merged.ringOffset, 4, reason: 'null inherits');
      expect(merged.contour, contour);
      expect(base.copyWith(ringOffset: -2).edge, BeamEdge.top);
      expect(base.copyWith(ringOffset: -2).ringOffset, -2);
    });

    test('every geometry field is part of the value', () {
      const base = BeamShape();
      final variants = <BeamShape>[
        const BeamShape(edge: BeamEdge.top),
        const BeamShape(ringOffset: 3),
        BeamShape(
          contour: BeamPathContour(
            (rect) => Path()..addOval(rect),
            key: 'oval',
          ),
        ),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base), reason: '$variant');
        expect(variant.hashCode, isNot(base.hashCode), reason: '$variant');
      }
    });

    test('toString lists only the fields that are set', () {
      expect(
        const BeamShape(edge: BeamEdge.right, ringOffset: 2).toString(),
        'BeamShape(edge: BeamEdge.right, ringOffset: 2.0)',
      );
      expect(const BeamShape().toString(), 'BeamShape()');
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

    test('the travel fields follow the inherit contract', () {
      const base = BeamTiming(
        direction: BeamDirection.reverse,
        phaseOffset: 0.25,
        beamCount: 3,
      );
      final merged = base.merge(const BeamTiming(beamCount: 5));
      expect(merged.direction, BeamDirection.reverse);
      expect(merged.phaseOffset, 0.25);
      expect(merged.beamCount, 5);

      final copy = base.copyWith(phaseOffset: 0.75);
      expect(copy.phaseOffset, 0.75);
      expect(copy.direction, BeamDirection.reverse);
      expect(copy.beamCount, 3);
    });

    test('every travel field is part of the value', () {
      const base = BeamTiming();
      const variants = <BeamTiming>[
        BeamTiming(direction: BeamDirection.bounce),
        BeamTiming(phaseOffset: 0.5),
        BeamTiming(beamCount: 2),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base), reason: '$variant');
        expect(variant.hashCode, isNot(base.hashCode), reason: '$variant');
      }
      expect(
        const BeamTiming(direction: BeamDirection.bounce, beamCount: 2),
        const BeamTiming(direction: BeamDirection.bounce, beamCount: 2),
      );
    });

    test('toString lists only the fields that are set', () {
      expect(
        const BeamTiming(
          direction: BeamDirection.reverse,
          phaseOffset: 0.5,
          beamCount: 2,
        ).toString(),
        'BeamTiming(direction: BeamDirection.reverse, phaseOffset: 0.5, '
        'beamCount: 2)',
      );
      expect(const BeamTiming().toString(), 'BeamTiming()');
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
      const base = BeamPlayback(
        active: false,
        reducedMotion: BeamReducedMotion.animate,
      );
      expect(
        base.copyWith(active: true).reducedMotion,
        BeamReducedMotion.animate,
      );
    });

    test('repeat and reducedMotion follow the inherit contract', () {
      const base = BeamPlayback(
        repeat: BeamRepeat.count(3),
        reducedMotion: BeamReducedMotion.hide,
      );
      final merged = base.merge(
        const BeamPlayback(reducedMotion: BeamReducedMotion.slow),
      );
      expect(merged.repeat, const BeamRepeat.count(3), reason: 'null inherits');
      expect(merged.reducedMotion, BeamReducedMotion.slow);
      expect(base.copyWith(active: false).repeat, const BeamRepeat.count(3));
    });

    test('repeat and reducedMotion are part of the value', () {
      const base = BeamPlayback();
      const variants = <BeamPlayback>[
        BeamPlayback(repeat: BeamRepeat.once()),
        BeamPlayback(reducedMotion: BeamReducedMotion.staticFrame),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base), reason: '$variant');
        expect(variant.hashCode, isNot(base.hashCode), reason: '$variant');
      }
      expect(
        const BeamPlayback(repeat: BeamRepeat.count(2)),
        isNot(const BeamPlayback(repeat: BeamRepeat.count(3))),
      );
      expect(
        const BeamPlayback(repeat: BeamRepeat.once()),
        const BeamPlayback(repeat: BeamRepeat.once()),
      );
    });

    test('toString lists only the fields that are set', () {
      expect(
        const BeamPlayback(
          repeat: BeamRepeat.count(2),
          reducedMotion: BeamReducedMotion.hide,
        ).toString(),
        'BeamPlayback(repeat: BeamRepeat.count(2), '
        'reducedMotion: BeamReducedMotion.hide)',
      );
      expect(const BeamPlayback().toString(), 'BeamPlayback()');
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

  test('the playback-only fields follow the inherit contract', () {
    const base = BeamPlayback(
      pauseWhenOffscreen: false,
      fadeCurve: BeamPlayback.cssEase,
      debugFrozenAt: Duration(milliseconds: 1300),
    );
    final merged = base.merge(
      const BeamPlayback(debugFrozenAt: Duration(seconds: 2)),
    );
    expect(merged.pauseWhenOffscreen, isFalse, reason: 'null inherits');
    expect(merged.fadeCurve, BeamPlayback.cssEase);
    expect(merged.debugFrozenAt, const Duration(seconds: 2));

    final copy = base.copyWith(active: true);
    expect(copy.pauseWhenOffscreen, isFalse);
    expect(copy.fadeCurve, BeamPlayback.cssEase);
    expect(copy.debugFrozenAt, const Duration(milliseconds: 1300));
  });

  test('every playback-only field is part of the value', () {
    const base = BeamPlayback();
    const variants = <BeamPlayback>[
      BeamPlayback(pauseWhenOffscreen: false),
      BeamPlayback(fadeCurve: BeamPlayback.cssEase),
      BeamPlayback(debugFrozenAt: Duration(seconds: 1)),
    ];
    for (final variant in variants) {
      expect(variant, isNot(base), reason: '$variant');
      expect(variant.hashCode, isNot(base.hashCode), reason: '$variant');
    }
    expect(
      const BeamPlayback(debugFrozenAt: Duration(seconds: 1)),
      const BeamPlayback(debugFrozenAt: Duration(seconds: 1)),
    );
    expect(
      const BeamPlayback(debugFrozenAt: Duration(seconds: 1)),
      isNot(const BeamPlayback(debugFrozenAt: Duration(seconds: 2))),
    );
  });

  test('toString lists the playback-only fields', () {
    expect(
      const BeamPlayback(
        pauseWhenOffscreen: false,
        debugFrozenAt: Duration(milliseconds: 1300),
      ).toString(),
      'BeamPlayback(pauseWhenOffscreen: false, '
      'debugFrozenAt: 0:00:01.300000)',
    );
  });

  test('cssEase is the web easing, and compares by value', () {
    expect(BeamPlayback.cssEase, const Cubic(0.25, 0.1, 0.25, 1));
    expect(BeamPlayback.cssEase.transform(0), 0);
    expect(BeamPlayback.cssEase.transform(1), 1);
  });

  group('BeamRepeat', () {
    test('forever carries no cycle count', () {
      expect(const BeamRepeat.forever().cycles, isNull);
      expect(const BeamRepeat.forever().toString(), 'BeamRepeat.forever()');
    });

    test('once is one cycle', () {
      expect(const BeamRepeat.once().cycles, 1);
      expect(const BeamRepeat.once(), const BeamRepeat.count(1));
    });

    test('count keeps its cycle count and rejects zero', () {
      expect(const BeamRepeat.count(4).cycles, 4);
      expect(const BeamRepeat.count(4).toString(), 'BeamRepeat.count(4)');
      expect(() => BeamRepeat.count(0), throwsAssertionError);
      expect(() => BeamRepeat.count(-1), throwsAssertionError);
    });

    test('equality is by cycle count', () {
      expect(const BeamRepeat.count(2), const BeamRepeat.count(2));
      expect(
        const BeamRepeat.count(2).hashCode,
        const BeamRepeat.count(2).hashCode,
      );
      expect(const BeamRepeat.count(2), isNot(const BeamRepeat.count(3)));
      expect(const BeamRepeat.count(2), isNot(const BeamRepeat.forever()));
      expect(const BeamRepeat.forever(), const BeamRepeat.forever());
    });
  });

  group('BeamPathContour', () {
    Path rectBuilder(Rect rect) => Path()..addRect(rect);

    test('build delegates to the builder', () {
      const rect = Rect.fromLTWH(0, 0, 10, 20);
      final contour = BeamPathContour(rectBuilder, key: 'rect');
      expect(contour.build(rect).getBounds(), rect);
    });

    test('equality is by key, not by builder identity', () {
      expect(
        BeamPathContour((rect) => Path()..addRect(rect), key: 'rect'),
        BeamPathContour((rect) => Path()..addOval(rect), key: 'rect'),
        reason: 'two closures are never equal; the key is the value',
      );
      expect(
        BeamPathContour(rectBuilder, key: 'rect').hashCode,
        BeamPathContour(rectBuilder, key: 'rect').hashCode,
      );
      expect(
        BeamPathContour(rectBuilder, key: 'rect'),
        isNot(BeamPathContour(rectBuilder, key: 'oval')),
      );
    });

    test('a record key compares by its fields', () {
      expect(
        BeamPathContour(rectBuilder, key: ('notch', 12.0)),
        BeamPathContour(rectBuilder, key: ('notch', 12.0)),
      );
      expect(
        BeamPathContour(rectBuilder, key: ('notch', 12.0)),
        isNot(BeamPathContour(rectBuilder, key: ('notch', 13.0))),
      );
    });

    test('toString names the key', () {
      expect(
        BeamPathContour(rectBuilder, key: 'oval').toString(),
        'BeamPathContour(oval)',
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
