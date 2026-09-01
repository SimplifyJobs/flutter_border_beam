import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = BeamStyle(
  strength: 0.8,
  brightness: 1.1,
  saturation: 1.4,
  hueRange: 20,
  hueBase: 5,
  staticColors: false,
  strokeOpacityFactor: 0.9,
  innerOpacityFactor: 0.8,
  bloomOpacityFactor: 0.7,
  glowBoost: 1.2,
  coreBlur: 3,
  bloomBlur: 4,
  glowBrightness: 1.5,
  glowSaturation: 1.6,
);

const _shape = BeamShape(
  radius: BorderRadius.all(Radius.circular(10)),
  borderWidth: 2,
  superellipse: false,
);

const _timing = BeamTiming(
  cycle: Duration(seconds: 2),
  cycleGap: Duration(seconds: 1),
  speed: 1,
  huePeriod: Duration(seconds: 5),
  bloomHuePeriod: Duration(seconds: 6),
  breatheFactor: 1.1,
  spikeFactor: 1.2,
  spike2Factor: 1.3,
);

BeamConfig _resolve({
  BeamVariant variant = BeamVariant.rotate,
  BeamColors colors = BeamColors.colorful,
  Brightness brightness = Brightness.dark,
  BeamStyle style = _style,
  BeamShape shape = _shape,
  BeamTiming timing = _timing,
  TextDirection textDirection = TextDirection.ltr,
}) => BeamConfig.resolve(
  variant: variant,
  palette: colors.resolve(),
  brightness: brightness,
  style: style,
  shape: shape,
  timing: timing,
  textDirection: textDirection,
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

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

/// `BeamConfig` is the value the painter compares: two resolutions of the
/// same inputs must be `==` (so a rebuilt-inline style never repaints), and
/// every input that reaches a painted value must break that equality.
void main() {
  group('equality', () {
    test('two resolutions of the same inputs are equal', () {
      final a = _resolve();
      final b = _resolve();
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    // Every input the painter reads, one at a time.
    final mutations = <String, BeamConfig Function()>{
      'variant': () => _resolve(variant: BeamVariant.small),
      'palette': () => _resolve(colors: BeamColors.ocean),
      'brightness': () => _resolve(brightness: Brightness.light),
      'style.strength': () => _resolve(style: _style.copyWith(strength: 0.81)),
      'style.brightness': () =>
          _resolve(style: _style.copyWith(brightness: 1.11)),
      'style.saturation': () =>
          _resolve(style: _style.copyWith(saturation: 1.41)),
      'style.hueRange': () => _resolve(style: _style.copyWith(hueRange: 21)),
      'style.hueBase': () => _resolve(style: _style.copyWith(hueBase: 6)),
      'style.staticColors': () =>
          _resolve(style: _style.copyWith(staticColors: true)),
      'style.strokeOpacityFactor': () =>
          _resolve(style: _style.copyWith(strokeOpacityFactor: 0.91)),
      'style.innerOpacityFactor': () =>
          _resolve(style: _style.copyWith(innerOpacityFactor: 0.81)),
      'style.bloomOpacityFactor': () =>
          _resolve(style: _style.copyWith(bloomOpacityFactor: 0.71)),
      'style.glowBoost': () => _resolve(style: _style.copyWith(glowBoost: 1.3)),
      'style.coreBlur': () => _resolve(style: _style.copyWith(coreBlur: 3.5)),
      'style.bloomBlur': () => _resolve(style: _style.copyWith(bloomBlur: 4.5)),
      'style.glowBrightness': () =>
          _resolve(style: _style.copyWith(glowBrightness: 1.51)),
      'style.glowSaturation': () =>
          _resolve(style: _style.copyWith(glowSaturation: 1.61)),
      'style.themeConfig': () => _resolve(
        style: _style.copyWith(
          themeConfig: BeamThemeConfig.presetFor(
            BeamVariant.rotate,
            Brightness.dark,
          ).copyWith(bloomOpacity: 0.99),
        ),
      ),
      'shape.radius': () =>
          _resolve(shape: _shape.copyWith(radius: BorderRadius.circular(11))),
      'shape.radius (one corner)': () => _resolve(
        shape: _shape.copyWith(
          radius: const BorderRadius.only(topLeft: Radius.circular(10)),
        ),
      ),
      'shape.borderWidth': () =>
          _resolve(shape: _shape.copyWith(borderWidth: 2.5)),
      'shape.superellipse': () =>
          _resolve(shape: _shape.copyWith(superellipse: true)),
      'timing.cycle': () => _resolve(
        timing: _timing.copyWith(cycle: const Duration(milliseconds: 2001)),
      ),
      'timing.cycleGap': () => _resolve(
        timing: _timing.copyWith(cycleGap: const Duration(milliseconds: 1001)),
      ),
      'timing.huePeriod': () => _resolve(
        timing: _timing.copyWith(huePeriod: const Duration(seconds: 6)),
      ),
      'timing.bloomHuePeriod': () => _resolve(
        timing: _timing.copyWith(bloomHuePeriod: const Duration(seconds: 7)),
      ),
      'timing.breatheFactor': () =>
          _resolve(timing: _timing.copyWith(breatheFactor: 1.15)),
      'timing.spikeFactor': () =>
          _resolve(timing: _timing.copyWith(spikeFactor: 1.25)),
      'timing.spike2Factor': () =>
          _resolve(timing: _timing.copyWith(spike2Factor: 1.35)),
      'style.hueMode': () =>
          _resolve(style: _style.copyWith(hueMode: BeamHueMode.continuous)),
      'style.tailLength': () =>
          _resolve(style: _style.copyWith(tailLength: 1.5)),
      'style.glowSpread': () =>
          _resolve(style: _style.copyWith(glowSpread: 1.5)),
      'style.comet': () => _resolve(style: _style.copyWith(comet: true)),
      'style.sparkle': () => _resolve(style: _style.copyWith(sparkle: 0.5)),
      'style.segments': () => _resolve(style: _style.copyWith(segments: 6)),
      'shape.edge': () => _resolve(shape: _shape.copyWith(edge: BeamEdge.top)),
      'shape.ringOffset': () => _resolve(shape: _shape.copyWith(ringOffset: 4)),
      'shape.contour': () => _resolve(
        shape: _shape.copyWith(
          contour: BeamPathContour(
            (rect) => Path()..addOval(rect),
            key: 'oval',
          ),
        ),
      ),
      'timing.direction': () =>
          _resolve(timing: _timing.copyWith(direction: BeamDirection.reverse)),
      'timing.phaseOffset': () =>
          _resolve(timing: _timing.copyWith(phaseOffset: 0.5)),
      'timing.beamCount': () =>
          _resolve(timing: _timing.copyWith(beamCount: 2)),
    };

    for (final MapEntry(key: name, value: mutate) in mutations.entries) {
      test('$name breaks equality', () {
        final base = _resolve();
        final mutated = mutate();
        expect(mutated, isNot(base), reason: name);
        expect(mutated.hashCode, isNot(base.hashCode), reason: name);
      });
    }

    test('textDirection breaks equality for a directional radius', () {
      const shape = BeamShape(
        radius: BorderRadiusDirectional.only(topStart: Radius.circular(20)),
      );
      final ltr = _resolve(shape: shape);
      final rtl = _resolve(shape: shape, textDirection: TextDirection.rtl);
      expect(rtl, isNot(ltr));
      expect(rtl.borderRadius.topRight, const Radius.circular(20));
      expect(
        _resolve(textDirection: TextDirection.rtl),
        _resolve(),
        reason: 'a non-directional radius resolves the same either way',
      );
    });

    test('two contours with the same key resolve equal', () {
      BeamShape shaped(String key) => _shape.copyWith(
        contour: BeamPathContour((rect) => Path()..addOval(rect), key: key),
      );
      expect(_resolve(shape: shaped('oval')), _resolve(shape: shaped('oval')));
      expect(
        _resolve(shape: shaped('oval')),
        isNot(_resolve(shape: shaped('notch'))),
      );
    });

    test('speed is not part of the painted value', () {
      expect(
        _resolve(timing: _timing.copyWith(speed: 4)),
        _resolve(),
        reason: 'the clock owns the rate; the painter never reads it',
      );
    });
  });

  group('defaults', () {
    BeamConfig bare(BeamVariant variant) => BeamConfig.resolve(
      variant: variant,
      palette: BeamColors.colorful.resolve(),
      brightness: Brightness.dark,
    );

    test('the hue mode follows the variant family', () {
      for (final variant in BeamVariant.values) {
        expect(
          bare(variant).hueMode,
          variant.isPulse ? BeamHueMode.continuous : BeamHueMode.pingPong,
          reason: '$variant',
        );
      }
    });

    test('an explicit hue mode overrides the family default', () {
      expect(
        BeamConfig.resolve(
          variant: BeamVariant.rotate,
          palette: BeamColors.colorful.resolve(),
          brightness: Brightness.dark,
          style: const BeamStyle(hueMode: BeamHueMode.continuous),
        ).hueMode,
        BeamHueMode.continuous,
      );
    });

    test('the hue periods come from the variant accessors', () {
      for (final variant in BeamVariant.values) {
        final config = bare(variant);
        expect(
          config.huePeriodSeconds,
          variant.defaultHuePeriod.inMicroseconds /
              Duration.microsecondsPerSecond,
          reason: '$variant',
        );
        expect(
          config.bloomHuePeriodSeconds,
          variant.defaultBloomHuePeriod.inMicroseconds /
              Duration.microsecondsPerSecond,
          reason: '$variant',
        );
      }
    });

    test('every new field resolves to a render-neutral default', () {
      for (final variant in BeamVariant.values) {
        final config = bare(variant);
        expect(config.tailLength, 1, reason: '$variant');
        expect(config.glowSpread, 1, reason: '$variant');
        expect(config.comet, isFalse, reason: '$variant');
        expect(config.sparkle, 0, reason: '$variant');
        expect(config.segments, isNull, reason: '$variant');
        expect(config.edge, BeamEdge.bottom, reason: '$variant');
        expect(config.ringOffset, 0, reason: '$variant');
        expect(config.contour, isNull, reason: '$variant');
        expect(config.direction, BeamDirection.forward, reason: '$variant');
        expect(config.phaseOffset, 0, reason: '$variant');
        expect(config.beamCount, 1, reason: '$variant');
      }
    });

    test('sparkle is clamped to 0-1', () {
      BeamConfig withSparkle(double sparkle) => BeamConfig.resolve(
        variant: BeamVariant.rotate,
        palette: BeamColors.colorful.resolve(),
        brightness: Brightness.dark,
        style: BeamStyle(sparkle: sparkle),
      );
      expect(withSparkle(-1).sparkle, 0);
      expect(withSparkle(2).sparkle, 1);
      expect(withSparkle(0.5).sparkle, 0.5);
    });
  });

  group('BeamPainter.shouldRepaint', () {
    late BeamClock clock;

    setUp(() {
      clock = BeamClock(createTicker: Ticker.new);
    });
    tearDown(() => clock.dispose());

    BeamPainter painter(BeamConfig config, {bool staticMode = false}) =>
        BeamPainter(
          clock: clock,
          config: config,
          resolver: BeamPhaseResolver(config),
          strategy: strategyFor(config.variant),
          behind: false,
          staticMode: staticMode,
        );

    test('is false for an equal config', () {
      final a = painter(_resolve());
      final b = painter(_resolve());
      expect(b.shouldRepaint(a), isFalse);
    });

    test('is true for any differing config', () {
      final base = painter(_resolve());
      expect(
        painter(
          _resolve(style: _style.copyWith(strength: 0.5)),
        ).shouldRepaint(base),
        isTrue,
      );
      expect(
        painter(_resolve(variant: BeamVariant.line)).shouldRepaint(base),
        isTrue,
      );
    });

    test('is true when the pass, the static mode, or the clock changes', () {
      final config = _resolve();
      final base = painter(config);
      expect(painter(config, staticMode: true).shouldRepaint(base), isTrue);

      final behind = BeamPainter(
        clock: clock,
        config: config,
        resolver: BeamPhaseResolver(config),
        strategy: strategyFor(config.variant),
        behind: true,
        staticMode: false,
      );
      expect(behind.shouldRepaint(base), isTrue);

      final otherClock = BeamClock(createTicker: Ticker.new);
      addTearDown(otherClock.dispose);
      final rebound = BeamPainter(
        clock: otherClock,
        config: config,
        resolver: BeamPhaseResolver(config),
        strategy: strategyFor(config.variant),
        behind: false,
        staticMode: false,
      );
      expect(rebound.shouldRepaint(base), isTrue);
    });
  });

  group("the widget's config cache", () {
    testWidgets('an equal style rebuilt inline keeps the same config object', (
      tester,
    ) async {
      // A runtime value, so each build allocates a fresh BeamStyle rather
      // than reusing a canonicalized const one.
      Widget build(double strength) => _host(
        BorderBeam.rotate(
          style: BeamStyle(strength: strength),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(0.5));
      final first = _beamPainter(tester).config;

      await tester.pumpWidget(build(0.5));
      expect(
        identical(_beamPainter(tester).config, first),
        isTrue,
        reason: 'equal value objects must not re-resolve',
      );
    });

    testWidgets('a differing style resolves a new config object', (
      tester,
    ) async {
      Widget build(double strength) => _host(
        BorderBeam.rotate(
          style: BeamStyle(strength: strength),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(0.5));
      final first = _beamPainter(tester).config;

      await tester.pumpWidget(build(0.6));
      final second = _beamPainter(tester).config;
      expect(identical(second, first), isFalse);
      expect(second, isNot(first));
      expect(second.strength, 0.6);
    });

    testWidgets('an equal shape and timing rebuilt inline keep the config', (
      tester,
    ) async {
      Widget build(double radius, int cycleMs) => _host(
        BorderBeam.rotate(
          shape: BeamShape.circular(radius, superellipse: true),
          timing: BeamTiming(
            cycle: Duration(milliseconds: cycleMs),
            cycleGap: const Duration(milliseconds: 400),
          ),
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(build(24, 1500));
      final first = _beamPainter(tester).config;
      await tester.pumpWidget(build(24, 1500));
      expect(identical(_beamPainter(tester).config, first), isTrue);
    });

    testWidgets('an unrelated rebuild keeps the config and the resolver', (
      tester,
    ) async {
      Widget build(String label) => _host(
        BorderBeam.rotate(colors: BeamColors.ocean, child: Text(label)),
      );

      await tester.pumpWidget(build('a'));
      final painter = _beamPainter(tester);

      await tester.pumpWidget(build('b'));
      final next = _beamPainter(tester);
      expect(identical(next.config, painter.config), isTrue);
      expect(identical(next.resolver, painter.resolver), isTrue);
      expect(next.shouldRepaint(painter), isFalse);
    });
  });
}
