import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/distortion_wave/look/wave_defaults.dart';
import 'package:prismatic/src/distortion_wave/models/wave_dots.dart';
import 'package:prismatic/src/distortion_wave/models/wave_glow.dart';
import 'package:prismatic/src/distortion_wave/models/wave_lens.dart';
import 'package:prismatic/src/distortion_wave/models/wave_motion.dart';
import 'package:prismatic/src/distortion_wave/models/wave_palette.dart';
import 'package:prismatic/src/distortion_wave/models/wave_spec.dart';
import 'package:prismatic/src/distortion_wave/models/wave_style.dart';
import 'package:prismatic/src/distortion_wave/models/wave_timing.dart';
import 'package:prismatic/src/distortion_wave/models/wave_type.dart';

/// The wave's value objects share the beam's contract: every field is
/// nullable and means *inherit*, `merge` layers the argument over the
/// receiver, `copyWith` keeps what it is not given, and equality is by
/// value. `WaveSpec.resolve` settles a style over a fallback over the
/// type's tuned defaults, which must equal DistortionWavesKit's.
void main() {
  /// Asserts each of [variants] differs from [base] and from every other.
  void expectEveryFieldCounts<T>(T base, List<T> variants) {
    for (final v in variants) {
      expect(v, isNot(base), reason: '$v');
      expect(v.hashCode, isNot(base.hashCode), reason: '$v');
    }
    for (var i = 0; i < variants.length; i++) {
      for (var j = i + 1; j < variants.length; j++) {
        expect(variants[i], isNot(variants[j]), reason: '$i vs $j');
      }
    }
  }

  /// The contract every group shares. [copy] is `copyWith()` with nothing
  /// given: a new object at run time, equal to [full] without being the
  /// same canonical const — comparing two equal const expressions never
  /// gets past `identical` and pins nothing about `==`.
  void groupContract<T extends Object>({
    required T full,
    required T empty,
    required T Function(T) copy,
    required T? Function(T, T?) merge,
    required List<T> variants,
    required List<String> fieldNames,
    required String emptyString,
  }) {
    test('copyWith with nothing given is an equal copy', () {
      final copied = copy(full);
      expect(identical(copied, full), isFalse);
      expect(copied, full);
      expect(copied.hashCode, full.hashCode);
    });

    test('every field counts in == and hashCode', () {
      expectEveryFieldCounts(full, variants);
    });

    test('merge(null) returns the receiver', () {
      expect(identical(merge(full, null), full), isTrue);
    });

    test('merging onto an empty one takes every field', () {
      expect(merge(empty, full), full);
    });

    test('merging an empty one changes nothing', () {
      expect(merge(full, empty), full);
    });

    test('toString lists only the fields that are set', () {
      expect(empty.toString(), emptyString);
      final text = full.toString();
      for (final name in fieldNames) {
        expect(text, contains('$name: '), reason: text);
      }
    });
  }

  group('WaveTiming', () {
    const full = WaveTiming(
      anticipation: Duration(milliseconds: 500),
      travel: Duration(seconds: 2),
      easing: Curves.easeIn,
      returnSpeed: 1.5,
      linger: Duration(milliseconds: -100),
      rimFade: Duration(seconds: 3),
      rimEasing: Curves.easeOut,
      hairlineLinger: Duration(milliseconds: 400),
      hairlineFade: Duration(seconds: 4),
    );

    groupContract<WaveTiming>(
      full: full,
      empty: const WaveTiming(),
      copy: (t) => t.copyWith(),
      merge: (a, b) => a.merge(b),
      variants: [
        full.copyWith(anticipation: const Duration(milliseconds: 501)),
        full.copyWith(travel: const Duration(seconds: 3)),
        full.copyWith(easing: Curves.linear),
        full.copyWith(returnSpeed: 2),
        full.copyWith(linger: const Duration(milliseconds: 100)),
        full.copyWith(rimFade: const Duration(seconds: 2)),
        full.copyWith(rimEasing: Curves.ease),
        full.copyWith(hairlineLinger: const Duration(milliseconds: 401)),
        full.copyWith(hairlineFade: const Duration(seconds: 5)),
      ],
      fieldNames: const [
        'anticipation',
        'travel',
        'easing',
        'returnSpeed',
        'linger',
        'rimFade',
        'rimEasing',
        'hairlineLinger',
        'hairlineFade',
      ],
      emptyString: 'WaveTiming()',
    );

    test('merge lets the argument win field by field', () {
      final merged = full.merge(
        const WaveTiming(travel: Duration(seconds: 9), returnSpeed: 3),
      );
      expect(merged.travel, const Duration(seconds: 9), reason: 'wins');
      expect(merged.returnSpeed, 3);
      expect(merged.anticipation, full.anticipation, reason: 'inherits');
      expect(merged.easing, full.easing);
      expect(merged.linger, full.linger);
      expect(merged.rimFade, full.rimFade);
      expect(merged.rimEasing, full.rimEasing);
      expect(merged.hairlineLinger, full.hairlineLinger);
      expect(merged.hairlineFade, full.hairlineFade);
    });

    test('copyWith replaces only what it is given', () {
      final changed = full.copyWith(linger: const Duration(seconds: 1));
      expect(changed.linger, const Duration(seconds: 1));
      expect(
        changed,
        full.merge(const WaveTiming(linger: Duration(seconds: 1))),
      );
    });

    test('toString names a field with its value', () {
      expect(
        const WaveTiming(returnSpeed: 2).toString(),
        'WaveTiming(returnSpeed: 2.0)',
      );
    });
  });

  group('WaveMotion', () {
    const full = WaveMotion(
      pull: 24,
      inhale: 56,
      gatherGlow: 0.33,
      gatherDots: 1,
      launchGap: 4,
      orientation: 0.91,
    );

    groupContract<WaveMotion>(
      full: full,
      empty: const WaveMotion(),
      copy: (m) => m.copyWith(),
      merge: (a, b) => a.merge(b),
      variants: [
        full.copyWith(pull: 25),
        full.copyWith(inhale: 57),
        full.copyWith(gatherGlow: 0.5),
        full.copyWith(gatherDots: 0.5),
        full.copyWith(launchGap: 5),
        full.copyWith(orientation: 0.5),
      ],
      fieldNames: const [
        'pull',
        'inhale',
        'gatherGlow',
        'gatherDots',
        'launchGap',
        'orientation',
      ],
      emptyString: 'WaveMotion()',
    );

    test('merge lets the argument win field by field', () {
      final merged = full.merge(const WaveMotion(pull: 3, orientation: 0));
      expect(merged.pull, 3);
      expect(merged.orientation, 0);
      expect(merged.inhale, 56);
      expect(merged.gatherGlow, 0.33);
      expect(merged.gatherDots, 1);
      expect(merged.launchGap, 4);
    });
  });

  group('WaveLens', () {
    const full = WaveLens(
      amplitude: 34,
      width: 150,
      aberration: 0.78,
      swell: 22,
      blur: 18,
      blurAhead: 90,
      blurBehind: 240,
    );

    groupContract<WaveLens>(
      full: full,
      empty: const WaveLens(),
      copy: (l) => l.copyWith(),
      merge: (a, b) => a.merge(b),
      variants: [
        full.copyWith(amplitude: 35),
        full.copyWith(width: 151),
        full.copyWith(aberration: 0.5),
        full.copyWith(swell: 23),
        full.copyWith(blur: 19),
        full.copyWith(blurAhead: 91),
        full.copyWith(blurBehind: 241),
      ],
      fieldNames: const [
        'amplitude',
        'width',
        'aberration',
        'swell',
        'blur',
        'blurAhead',
        'blurBehind',
      ],
      emptyString: 'WaveLens()',
    );

    test('merge lets the argument win field by field', () {
      final merged = full.merge(const WaveLens(blur: 0));
      expect(merged.blur, 0);
      expect(merged, full.copyWith(blur: 0));
    });
  });

  group('WaveGlow', () {
    const full = WaveGlow(
      lead: 130,
      tail: 300,
      strength: 0.92,
      rimWidth: 14,
      rimUnevenness: 1,
      rimStrength: 0.82,
      rimSoftness: 343,
      rimPulse: 0.6,
      hairlineWidth: 1.5,
      hairlineOpacity: 0.9,
      hairlineWhite: 0.95,
      cornerRadius: 62,
    );

    groupContract<WaveGlow>(
      full: full,
      empty: const WaveGlow(),
      copy: (g) => g.copyWith(),
      merge: (a, b) => a.merge(b),
      variants: [
        full.copyWith(lead: 131),
        full.copyWith(tail: 301),
        full.copyWith(strength: 0.5),
        full.copyWith(rimWidth: 15),
        full.copyWith(rimUnevenness: 1.5),
        full.copyWith(rimStrength: 0.5),
        full.copyWith(rimSoftness: 344),
        full.copyWith(rimPulse: 0.2),
        full.copyWith(hairlineWidth: 2),
        full.copyWith(hairlineOpacity: 0.5),
        full.copyWith(hairlineWhite: 0.5),
        full.copyWith(cornerRadius: 40),
      ],
      fieldNames: const [
        'lead',
        'tail',
        'strength',
        'rimWidth',
        'rimUnevenness',
        'rimStrength',
        'rimSoftness',
        'rimPulse',
        'hairlineWidth',
        'hairlineOpacity',
        'hairlineWhite',
        'cornerRadius',
      ],
      emptyString: 'WaveGlow()',
    );

    test('merge lets the argument win field by field', () {
      final merged = full.merge(const WaveGlow(cornerRadius: 32, rimPulse: 0));
      expect(merged, full.copyWith(cornerRadius: 32, rimPulse: 0));
    });
  });

  group('WaveDots', () {
    const full = WaveDots(
      count: 64,
      size: 1.8,
      reach: 150,
      flight: 30,
      gap: 24,
      life: Duration(milliseconds: 2190),
      spread: 1,
    );

    groupContract<WaveDots>(
      full: full,
      empty: const WaveDots(),
      copy: (d) => d.copyWith(),
      merge: (a, b) => a.merge(b),
      variants: [
        full.copyWith(count: 65),
        full.copyWith(size: 2),
        full.copyWith(reach: 151),
        full.copyWith(flight: 31),
        full.copyWith(gap: 25),
        full.copyWith(life: const Duration(seconds: 1)),
        full.copyWith(spread: 0.5),
      ],
      fieldNames: const [
        'count',
        'size',
        'reach',
        'flight',
        'gap',
        'life',
        'spread',
      ],
      emptyString: 'WaveDots()',
    );

    test('merge lets the argument win field by field', () {
      final merged = full.merge(const WaveDots(count: 0));
      expect(merged, full.copyWith(count: 0));
    });
  });

  group('WaveStyle', () {
    const full = WaveStyle(
      type: WaveType.center,
      palette: WavePalette.ocean,
      timing: WaveTiming(travel: Duration(seconds: 2)),
      motion: WaveMotion(pull: 10),
      lens: WaveLens(blur: 4),
      glow: WaveGlow(cornerRadius: 30),
      dots: WaveDots(count: 12),
    );

    groupContract<WaveStyle>(
      full: full,
      empty: const WaveStyle(),
      copy: (s) => s.copyWith(),
      merge: (a, b) => a.merge(b),
      variants: [
        full.copyWith(type: WaveType.vertical),
        full.copyWith(palette: WavePalette.sunset),
        full.copyWith(timing: const WaveTiming(travel: Duration(seconds: 3))),
        full.copyWith(motion: const WaveMotion(pull: 11)),
        full.copyWith(lens: const WaveLens(blur: 5)),
        full.copyWith(glow: const WaveGlow(cornerRadius: 31)),
        full.copyWith(dots: const WaveDots(count: 13)),
      ],
      fieldNames: const [
        'type',
        'palette',
        'timing',
        'motion',
        'lens',
        'glow',
        'dots',
      ],
      emptyString: 'WaveStyle()',
    );

    test('copyWith replaces whole groups', () {
      final changed = full.copyWith(lens: const WaveLens(swell: 3));
      expect(changed.lens, const WaveLens(swell: 3), reason: 'not merged');
      expect(changed.type, full.type);
      expect(changed.palette, full.palette);
      expect(changed.timing, full.timing);
      expect(changed.motion, full.motion);
      expect(changed.glow, full.glow);
      expect(changed.dots, full.dots);
    });

    test('merge: type and palette win; groups merge field by field', () {
      const base = WaveStyle(
        type: WaveType.vertical,
        palette: WavePalette.ocean,
        timing: WaveTiming(
          travel: Duration(seconds: 2),
          linger: Duration(seconds: 1),
        ),
        lens: WaveLens(blur: 4, swell: 5),
        dots: WaveDots(count: 10),
      );
      final merged = base.merge(
        const WaveStyle(
          palette: WavePalette.sunset,
          timing: WaveTiming(travel: Duration(seconds: 3)),
          lens: WaveLens(blur: 8),
          glow: WaveGlow(lead: 9),
        ),
      );
      expect(merged.type, WaveType.vertical, reason: 'null inherits');
      expect(merged.palette, WavePalette.sunset, reason: 'argument wins');
      expect(
        merged.timing,
        const WaveTiming(
          travel: Duration(seconds: 3),
          linger: Duration(seconds: 1),
        ),
      );
      expect(merged.lens, const WaveLens(blur: 8, swell: 5));
      expect(merged.glow, const WaveGlow(lead: 9), reason: 'over nothing');
      expect(merged.dots, const WaveDots(count: 10), reason: 'kept');
      expect(merged.motion, isNull);
    });

    test('toString names the type and a preset palette', () {
      expect(
        const WaveStyle(
          type: WaveType.center,
          palette: WavePalette.ocean,
        ).toString(),
        'WaveStyle(type: WaveType.center, palette: WavePalette.ocean)',
      );
    });
  });

  group('WaveSpec.resolve', () {
    test('settles values the constructors do not check to finite ones, '
        'which holds in release builds too', () {
      final spec = WaveSpec.resolve(
        const WaveStyle(
          motion: WaveMotion(pull: double.nan, launchGap: double.infinity),
          lens: WaveLens(
            amplitude: double.nan,
            width: double.nan,
            swell: double.infinity,
          ),
          glow: WaveGlow(lead: double.infinity, cornerRadius: double.nan),
          dots: WaveDots(size: double.nan, reach: double.negativeInfinity),
        ),
      );
      final settled = {
        'pull': spec.pull,
        'launchGap': spec.launchGap,
        'amplitude': spec.amplitude,
        'lensWidth': spec.lensWidth,
        'swell': spec.swell,
        'lead': spec.lead,
        'cornerRadius': spec.cornerRadius,
        'dotSize': spec.dotSize,
        'dotReach': spec.dotReach,
        'duration': spec.duration,
        'returnDuration': spec.returnDuration,
      };
      for (final MapEntry(:key, :value) in settled.entries) {
        expect(value.isFinite, isTrue, reason: key);
      }
      expect(spec.lensWidth, greaterThanOrEqualTo(1));
      expect(spec.dotReach, 0);
    });

    // Every number of the reference's `DistortionWaveStyle()`, keyed by its
    // Swift name, read off a spec in seconds and points.
    final readers = <String, num Function(WaveSpec)>{
      'anticipation': (s) => s.anticipation,
      'travel': (s) => s.travel,
      'launchGap': (s) => s.launchGap,
      'linger': (s) => s.linger,
      'rimFade': (s) => s.rimFade,
      'returnSpeed': (s) => s.returnSpeed,
      'pull': (s) => s.pull,
      'inhale': (s) => s.inhale,
      'gatherGlow': (s) => s.gatherGlow,
      'gatherDots': (s) => s.gatherDots,
      'amplitude': (s) => s.amplitude,
      'lensWidth': (s) => s.lensWidth,
      'aberration': (s) => s.aberration,
      'swell': (s) => s.swell,
      'blur': (s) => s.blur,
      'blurAhead': (s) => s.blurAhead,
      'blurBehind': (s) => s.blurBehind,
      'lead': (s) => s.lead,
      'tail': (s) => s.tail,
      'strength': (s) => s.strength,
      'rimWidth': (s) => s.rimWidth,
      'rimUnevenness': (s) => s.rimUnevenness,
      'rimStrength': (s) => s.rimStrength,
      'rimSoftness': (s) => s.rimSoftness,
      'cornerRadius': (s) => s.cornerRadius,
      'rimPulse': (s) => s.rimPulse,
      'hairlineWidth': (s) => s.hairlineWidth,
      'hairlineOpacity': (s) => s.hairlineOpacity,
      'hairlineWhite': (s) => s.hairlineWhite,
      'hairlineLinger': (s) => s.hairlineLinger,
      'hairlineFade': (s) => s.hairlineFade,
      'orientation': (s) => s.orientation,
      'particleCount': (s) => s.dotCount,
      'particleSize': (s) => s.dotSize,
      'particleReach': (s) => s.dotReach,
      'particleFlight': (s) => s.dotFlight,
      'particleGap': (s) => s.dotGap,
      'particleLife': (s) => s.dotLife,
      'particleSpread': (s) => s.dotSpread,
    };

    const swiftVertical = <String, num>{
      'anticipation': 0.5,
      'travel': 2.28,
      'launchGap': 0,
      'linger': -0.35,
      'rimFade': 3.03,
      'returnSpeed': 1.45,
      'pull': 24,
      'inhale': 56,
      'gatherGlow': 0.33,
      'gatherDots': 1,
      'amplitude': 34,
      'lensWidth': 150,
      'aberration': 0.78,
      'swell': 22,
      'blur': 18,
      'blurAhead': 90,
      'blurBehind': 240,
      'lead': 130,
      'tail': 300,
      'strength': 0.92,
      'rimWidth': 14,
      'rimUnevenness': 1,
      'rimStrength': 0.82,
      'rimSoftness': 343,
      'cornerRadius': 62,
      'rimPulse': 0.6,
      'hairlineWidth': 1.5,
      'hairlineOpacity': 0.9,
      'hairlineWhite': 0.95,
      'hairlineLinger': 0.47,
      'hairlineFade': 3,
      'orientation': 0.91,
      'particleCount': 64,
      'particleSize': 1.8,
      'particleReach': 150,
      'particleFlight': 30,
      'particleGap': 24,
      'particleLife': 2.19,
      'particleSpread': 1,
    };

    // `DistortionWaveStyle(type: .center)` changes these and keeps the rest.
    final swiftCenter = <String, num>{
      ...swiftVertical,
      'anticipation': 0.25,
      'travel': 3.43,
      'rimFade': 2.51,
      'hairlineLinger': 0.96,
      'strength': 0.6,
      'rimStrength': 0.6,
      'aberration': 0,
      'gatherGlow': 0,
      'gatherDots': 0,
      'particleCount': 89,
      'particleLife': 3.93,
      'particleSpread': 0.64,
      'cornerRadius': 48,
      'pull': 14.4,
      'inhale': 33.6,
      'amplitude': 20.4,
      'lensWidth': 90,
      'swell': 13.2,
      'blur': 10.8,
      'blurAhead': 54,
      'blurBehind': 144,
      'lead': 78,
      'tail': 180,
      'rimSoftness': 205.8,
      'particleReach': 90,
      'particleFlight': 18,
      'particleGap': 11,
    };

    void expectValues(WaveSpec spec, Map<String, num> expected) {
      expect(readers.keys, unorderedEquals(expected.keys));
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(readers[key]!(spec), closeTo(value, 1e-9), reason: key);
      }
    }

    void expectCubic(Curve curve, List<double> points) {
      expect(curve, isA<Cubic>());
      final cubic = curve as Cubic;
      expect([cubic.a, cubic.b, cubic.c, cubic.d], points);
    }

    /// The reference's `duration`, from its own numbers.
    double swiftDuration(Map<String, num> v) =>
        (v['anticipation']! +
                [
                  v['travel']! * 0.6,
                  v['linger']! + v['rimFade']!,
                  v['linger']! + v['hairlineLinger']! + v['hairlineFade']!,
                  v['particleLife']!,
                ].reduce(math.max))
            .toDouble();

    test('with nothing set, resolves to the vertical defaults', () {
      final spec = WaveSpec.resolve(null);
      expect(spec.type, WaveType.vertical);
      expect(spec.palette, WavePalette.colorful);
      expectValues(spec, swiftVertical);
      expectCubic(spec.easing, const [0.22, 1, 0.36, 1]);
      expectCubic(spec.rimEasing, const [0.42, 0, 0.58, 1]);
      expect(spec.style, waveDefaults(WaveType.vertical));
    });

    test('horizontal is the vertical wave on its side', () {
      final spec = WaveSpec.resolve(const WaveStyle(type: WaveType.horizontal));
      expect(spec.type, WaveType.horizontal);
      expect(spec.palette, WavePalette.colorful);
      expectValues(spec, swiftVertical);
    });

    test('center picks its own tuned defaults', () {
      final spec = WaveSpec.resolve(const WaveStyle(type: WaveType.center));
      expect(spec.type, WaveType.center);
      expect(spec.palette, WavePalette.green);
      expect(spec.aberration, 0);
      expectValues(spec, swiftCenter);
      expectCubic(spec.easing, const [0.22, 1, 0.36, 1]);
      expectCubic(spec.rimEasing, const [0.42, 0, 0.58, 1]);
    });

    test('every type default is fully set', () {
      for (final type in WaveType.values) {
        final d = waveDefaults(type);
        expect(d.type, type);
        for (final (name, group) in [
          ('palette', d.palette),
          ('timing', d.timing),
          ('motion', d.motion),
          ('lens', d.lens),
          ('glow', d.glow),
          ('dots', d.dots),
        ]) {
          expect(group, isNotNull, reason: '$type $name');
        }
        // Resolving it must not hit a null anywhere.
        expect(() => WaveSpec.resolve(d), returnsNormally, reason: '$type');
      }
    });

    test('the widget style wins over the fallback, which wins over the '
        'type defaults', () {
      final spec = WaveSpec.resolve(
        const WaveStyle(lens: WaveLens(blur: 5)),
        fallback: const WaveStyle(
          palette: WavePalette.ocean,
          lens: WaveLens(blur: 9, swell: 7),
        ),
      );
      expect(spec.blur, 5, reason: 'widget');
      expect(spec.swell, 7, reason: 'fallback');
      expect(spec.palette, WavePalette.ocean, reason: 'fallback');
      expect(spec.amplitude, 34, reason: 'type default');
      expect(spec.type, WaveType.vertical);
    });

    test(
      "the fallback's type picks the defaults when the widget sets none",
      () {
        final spec = WaveSpec.resolve(
          const WaveStyle(glow: WaveGlow(lead: 1)),
          fallback: const WaveStyle(type: WaveType.center),
        );
        expect(spec.type, WaveType.center);
        expect(spec.palette, WavePalette.green);
        expect(spec.lead, 1);
        expect(spec.tail, 180, reason: "center's");
      },
    );

    test("the widget's type wins over the fallback's", () {
      final spec = WaveSpec.resolve(
        const WaveStyle(type: WaveType.center),
        fallback: const WaveStyle(
          type: WaveType.horizontal,
          lens: WaveLens(blur: 3),
        ),
      );
      expect(spec.type, WaveType.center);
      expect(spec.palette, WavePalette.green);
      expect(spec.blur, 3, reason: 'a fallback field survives the switch');
      expect(spec.swell, closeTo(13.2, 1e-9), reason: "center's");
    });

    test('out-of-range values are clamped', () {
      final spec = WaveSpec.resolve(
        const WaveStyle(
          timing: WaveTiming(
            anticipation: Duration(seconds: -1),
            travel: Duration.zero,
            linger: Duration(seconds: -2),
            rimFade: Duration.zero,
            hairlineFade: Duration(milliseconds: -5),
          ),
          motion: WaveMotion(launchGap: -10),
          lens: WaveLens(
            width: 0,
            aberration: -1,
            blurAhead: 0,
            blurBehind: -3,
          ),
          glow: WaveGlow(
            lead: 0,
            tail: -1,
            rimWidth: 0,
            rimSoftness: 0,
            hairlineWidth: -1,
            cornerRadius: -8,
          ),
          dots: WaveDots(
            size: -1,
            reach: -1,
            flight: -1,
            gap: -1,
            life: Duration.zero,
          ),
        ),
      );
      expect(spec.anticipation, 0);
      expect(spec.travel, 0.01);
      expect(spec.linger, -2, reason: 'a negative linger is allowed');
      expect(spec.rimFade, 0.01);
      expect(spec.hairlineFade, 0.01);
      expect(spec.launchGap, 0);
      expect(spec.lensWidth, 1);
      expect(spec.aberration, 0);
      expect(spec.blurAhead, 1);
      expect(spec.blurBehind, 1);
      expect(spec.lead, 1);
      expect(spec.tail, 1);
      expect(spec.rimWidth, 0.5);
      expect(spec.rimSoftness, 1);
      expect(spec.hairlineWidth, 0);
      expect(spec.cornerRadius, 0);
      expect(spec.dotSize, 0);
      expect(spec.dotReach, 0);
      expect(spec.dotFlight, 0);
      expect(spec.dotGap, 0);
      expect(spec.dotLife, 0.01);
    });

    test('constructors assert their documented ranges', () {
      // Built from run-time values: a const with a failing assert does not
      // compile.
      double v(double x) => x;
      expect(() => WaveMotion(orientation: v(1.5)), throwsAssertionError);
      expect(() => WaveMotion(gatherGlow: v(2.5)), throwsAssertionError);
      expect(() => WaveMotion(gatherDots: v(-0.1)), throwsAssertionError);
      expect(() => WaveLens(blur: v(65)), throwsAssertionError);
      expect(() => WaveGlow(strength: v(1.1)), throwsAssertionError);
      expect(() => WaveGlow(rimStrength: v(-1)), throwsAssertionError);
      expect(() => WaveGlow(rimUnevenness: v(2.5)), throwsAssertionError);
      expect(() => WaveGlow(rimPulse: v(2)), throwsAssertionError);
      expect(() => WaveGlow(hairlineOpacity: v(2)), throwsAssertionError);
      expect(() => WaveGlow(hairlineWhite: v(-1)), throwsAssertionError);
      expect(() => WaveDots(spread: v(1.5)), throwsAssertionError);
      expect(
        () => WaveDots(count: WaveDots.maxWaveDots + v(1).round()),
        throwsAssertionError,
      );
      expect(() => WaveTiming(returnSpeed: v(0)), throwsAssertionError);
    });

    test('duration follows the reference formula for each type', () {
      for (final (type, swift) in [
        (WaveType.vertical, swiftVertical),
        (WaveType.horizontal, swiftVertical),
        (WaveType.center, swiftCenter),
      ]) {
        final spec = WaveSpec.resolve(WaveStyle(type: type));
        expect(spec.duration, closeTo(swiftDuration(swift), 1e-9));
        expect(
          spec.returnDuration,
          closeTo(swiftDuration(swift) / swift['returnSpeed']!, 1e-9),
        );
      }
      // The defaults: the hairline's wipe sets the vertical wave's length,
      // the last dot the center wave's.
      expect(WaveSpec.resolve(null).duration, closeTo(3.62, 1e-9));
      expect(
        WaveSpec.resolve(const WaveStyle(type: WaveType.center)).duration,
        closeTo(4.18, 1e-9),
      );
    });

    test('duration is set by whichever part of the wave ends last', () {
      Duration s(double seconds) => Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round(),
      );
      for (final (label, timing, dots, swift) in [
        (
          'travel',
          WaveTiming(travel: s(10)),
          const WaveDots(),
          {...swiftVertical, 'travel': 10},
        ),
        (
          'edges',
          WaveTiming(linger: s(1), rimFade: s(6)),
          const WaveDots(),
          {...swiftVertical, 'linger': 1, 'rimFade': 6},
        ),
        (
          'hairline',
          WaveTiming(hairlineLinger: s(2), hairlineFade: s(5)),
          const WaveDots(),
          {...swiftVertical, 'hairlineLinger': 2, 'hairlineFade': 5},
        ),
        (
          'dots',
          const WaveTiming(),
          WaveDots(life: s(8)),
          {...swiftVertical, 'particleLife': 8},
        ),
      ]) {
        final spec = WaveSpec.resolve(WaveStyle(timing: timing, dots: dots));
        expect(
          spec.duration,
          closeTo(swiftDuration(swift), 1e-9),
          reason: label,
        );
      }
    });

    test('equal styles resolve to equal specs', () {
      final a = WaveSpec.resolve(const WaveStyle(type: WaveType.center));
      final b = WaveSpec.resolve(
        const WaveStyle(lens: WaveLens(blur: 1))
            .copyWith(type: WaveType.center, lens: const WaveLens()),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(WaveSpec.resolve(null)));
      expect(a.toString(), 'WaveSpec(WaveType.center)');
    });
  });
}
