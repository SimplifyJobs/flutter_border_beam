import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

/// A field left null on a beam falls through to the nearest
/// [BorderBeamTheme] (themes merged outside-in), then to the effect's
/// default; a value set on the beam always wins.
void main() {
  group('BorderBeamThemeData', () {
    const full = BorderBeamThemeData(
      effect: BeamEffect.flow(),
      style: BeamStyle(colors: BeamColors.ocean, strength: 0.5),
      shape: BeamShape(borderWidth: 2),
      timing: BeamTiming(cycle: Duration(seconds: 3)),
      playback: BeamPlayback(autoPlay: false),
    );

    test('copyWith replaces the given slots and keeps the rest', () {
      final copy = full.copyWith(
        effect: const BeamEffect.spin(),
        shape: const BeamShape(superellipse: true),
      );
      expect(copy.effect, const BeamEffect.spin());
      expect(copy.shape, const BeamShape(superellipse: true));
      expect(copy.style, full.style);
      expect(copy.timing, full.timing);
      expect(copy.playback, full.playback);
      expect(full.copyWith(), full);
    });

    test('merge layers the other data over this one, field by field', () {
      const over = BorderBeamThemeData(
        style: BeamStyle(strength: 0.9),
        shape: BeamShape(superellipse: true),
      );
      final merged = full.merge(over);
      expect(merged.effect, const BeamEffect.flow(), reason: 'not set over');
      expect(
        merged.style,
        const BeamStyle(colors: BeamColors.ocean, strength: 0.9),
        reason: 'value objects merge field by field',
      );
      expect(merged.shape, const BeamShape(borderWidth: 2, superellipse: true));
      expect(merged.timing, full.timing);
      expect(merged.playback, full.playback);
    });

    test('merge replaces the effect whole', () {
      final merged = const BorderBeamThemeData(
        effect: BeamEffect.rotate(count: 2, comet: true),
      ).merge(const BorderBeamThemeData(effect: BeamEffect.rotate()));
      expect(merged.effect, const BeamEffect.rotate());
    });

    test('merge fills slots this data leaves empty', () {
      final merged = const BorderBeamThemeData().merge(full);
      expect(merged, full);
    });

    test('merging null is the identity', () {
      expect(identical(full.merge(null), full), isTrue);
    });

    test('== and hashCode follow the slots', () {
      const same = BorderBeamThemeData(
        effect: BeamEffect.flow(),
        style: BeamStyle(colors: BeamColors.ocean, strength: 0.5),
        shape: BeamShape(borderWidth: 2),
        timing: BeamTiming(cycle: Duration(seconds: 3)),
        playback: BeamPlayback(autoPlay: false),
      );
      expect(same, full);
      expect(same.hashCode, full.hashCode);
      expect(full.copyWith(effect: const BeamEffect.halo()), isNot(full));
      expect(
        full.copyWith(timing: const BeamTiming(cycle: Duration(seconds: 4))),
        isNot(full),
      );
      expect(const BorderBeamThemeData(), const BorderBeamThemeData());
    });

    test('toString names every slot', () {
      final text = full.toString();
      for (final slot in ['effect', 'style', 'shape', 'timing', 'playback']) {
        expect(text, contains('$slot:'));
      }
      expect(text, contains('flow'));
    });
  });

  group('lookup', () {
    testWidgets('of is empty and maybeOf null without a theme', (tester) async {
      late BorderBeamThemeData data;
      late BorderBeamThemeData? maybe;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            data = BorderBeamTheme.of(context);
            maybe = BorderBeamTheme.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(data, const BorderBeamThemeData());
      expect(maybe, isNull);
    });

    testWidgets('nested themes merge outside-in', (tester) async {
      late BorderBeamThemeData data;
      await tester.pumpWidget(
        BorderBeamTheme(
          data: const BorderBeamThemeData(
            effect: BeamEffect.pulse(),
            style: BeamStyle(colors: BeamColors.ocean, strength: 0.5),
          ),
          child: BorderBeamTheme(
            data: const BorderBeamThemeData(style: BeamStyle(strength: 0.8)),
            child: BorderBeamTheme(
              data: const BorderBeamThemeData(effect: BeamEffect.halo()),
              child: Builder(
                builder: (context) {
                  data = BorderBeamTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(data.effect, const BeamEffect.halo(), reason: 'innermost wins');
      expect(
        data.style,
        const BeamStyle(colors: BeamColors.ocean, strength: 0.8),
      );
    });
  });

  group('inheritance through a beam', () {
    testWidgets('a theme supplies the fields the beam leaves null', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              style: BeamStyle(colors: BeamColors.ocean, strength: 0.4),
              shape: BeamShape(borderWidth: 3),
              timing: BeamTiming(cycle: Duration(seconds: 4)),
            ),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      final config = beamPainterOf(tester).config;
      expect(config.palette, BeamColors.ocean.resolve());
      expect(config.strength, 0.4);
      expect(config.borderWidth, 3);
      expect(config.cycleSeconds, closeTo(4, 1e-9));
    });

    testWidgets('a beam field wins over the theme, field by field', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              style: BeamStyle(colors: BeamColors.ocean, strength: 0.4),
              timing: BeamTiming(
                cycle: Duration(seconds: 4),
                direction: BeamDirection.reverse,
              ),
            ),
            child: BorderBeam(
              style: BeamStyle(strength: 0.7),
              timing: BeamTiming(cycle: Duration(seconds: 1)),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      final config = beamPainterOf(tester).config;
      expect(config.strength, 0.7);
      expect(config.palette, BeamColors.ocean.resolve());
      expect(config.cycleSeconds, closeTo(1, 1e-9));
      expect(config.direction, BeamDirection.reverse);
    });

    testWidgets('nested themes merge, inner over outer', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              style: BeamStyle(colors: BeamColors.ocean, strength: 0.5),
              shape: BeamShape(borderWidth: 2),
            ),
            child: BorderBeamTheme(
              data: BorderBeamThemeData(style: BeamStyle(strength: 0.9)),
              child: BorderBeam(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      final config = beamPainterOf(tester).config;
      expect(
        config.palette,
        BeamColors.ocean.resolve(),
        reason: 'the outer theme still supplies colors',
      );
      expect(config.strength, 0.9, reason: 'the inner theme wins');
      expect(config.borderWidth, 2, reason: 'slots the inner theme omits');
    });

    testWidgets('changing an outer theme rebuilds beams under an inner one', (
      tester,
    ) async {
      Widget build(BeamColors colors) => beamHost(
        BorderBeamTheme(
          data: BorderBeamThemeData(style: BeamStyle(colors: colors)),
          child: const BorderBeamTheme(
            data: BorderBeamThemeData(style: BeamStyle(strength: 0.7)),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );

      await tester.pumpWidget(build(BeamColors.ocean));
      final ocean = beamPainterOf(tester).config;
      expect(ocean.palette, BeamColors.ocean.resolve());

      await tester.pumpWidget(build(BeamColors.sunset));
      final sunset = beamPainterOf(tester).config;
      expect(identical(sunset, ocean), isFalse);
      expect(sunset.palette, BeamColors.sunset.resolve());
      expect(sunset.strength, 0.7);
    });
  });

  group('effect', () {
    testWidgets('a theme effect reaches a beam that sets none', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(effect: BeamEffect.flow()),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      expect(beamPainterOf(tester).config.effect, const BeamEffect.flow());
    });

    testWidgets('a beam effect wins over the theme', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(effect: BeamEffect.flow()),
            child: BorderBeam(
              effect: BeamEffect.shimmer(angle: 45),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      expect(
        beamPainterOf(tester).config.effect,
        const BeamEffect.shimmer(angle: 45),
      );
    });

    testWidgets('an inner theme effect wins, an outer one fills in', (
      tester,
    ) async {
      Widget build({BeamEffect? inner}) => beamHost(
        BorderBeamTheme(
          data: const BorderBeamThemeData(effect: BeamEffect.pulse()),
          child: BorderBeamTheme(
            data: BorderBeamThemeData(
              effect: inner,
              style: const BeamStyle(strength: 0.5),
            ),
            child: const BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );

      await tester.pumpWidget(build(inner: const BeamEffect.spin()));
      expect(beamPainterOf(tester).config.effect, const BeamEffect.spin());

      await tester.pumpWidget(build());
      expect(beamPainterOf(tester).config.effect, const BeamEffect.pulse());
    });

    testWidgets('a theme effect change rebuilds the config and resolver', (
      tester,
    ) async {
      Widget build(BeamEffect effect) => beamHost(
        BorderBeamTheme(
          data: BorderBeamThemeData(effect: effect),
          child: const BorderBeam(child: SizedBox.expand()),
        ),
      );

      await tester.pumpWidget(build(const BeamEffect.rotate()));
      await tester.pump(const Duration(milliseconds: 100));
      final before = beamPainterOf(tester);
      expect(before.config.effect, const BeamEffect.rotate());

      await tester.pumpWidget(build(const BeamEffect.charge()));
      await tester.pump(const Duration(milliseconds: 100));
      final after = beamPainterOf(tester);
      expect(after.config.effect, const BeamEffect.charge());
      expect(
        after.config.cycleSeconds,
        closeTo(
          const BeamEffect.charge().defaultCycle.inMicroseconds / 1e6,
          1e-9,
        ),
        reason: 'the timing defaults follow the new effect',
      );
      expect(identical(after.resolver, before.resolver), isFalse);
      expect(identical(after.resolver.config, after.config), isTrue);
      expect(tester.binding.transientCallbackCount, 1);
    });

    testWidgets('the effect default cycle applies under a theme effect', (
      tester,
    ) async {
      for (final effect in BeamEffect.values) {
        await tester.pumpWidget(
          beamHost(
            BorderBeamTheme(
              data: BorderBeamThemeData(effect: effect),
              child: const BorderBeam(child: SizedBox.expand()),
            ),
          ),
        );
        final config = beamPainterOf(tester).config;
        expect(
          config.cycleSeconds,
          closeTo(effect.defaultCycle.inMicroseconds / 1e6, 1e-9),
          reason: effect.name,
        );
      }
    });
  });

  group('playback through a theme', () {
    testWidgets('a theme autoPlay: false keeps a beam idle', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(autoPlay: false)),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('an active shorthand still respects a theme autoPlay: false', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(autoPlay: false)),
            child: BorderBeam(active: true, child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        beamPainterOf(tester).clock.isVisible,
        isFalse,
        reason: 'active says what to play, autoPlay says whether to start it',
      );
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a beam autoPlay: true overrides a theme autoPlay: false', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(autoPlay: false)),
            child: BorderBeam(
              playback: BeamPlayback(autoPlay: true),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
    });

    testWidgets('a theme startAfter delays the start', (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        beamHost(
          BorderBeamTheme(
            data: const BorderBeamThemeData(
              playback: BeamPlayback(startAfter: Duration(seconds: 2)),
            ),
            child: BorderBeam(
              onActivate: () => activated++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(activated, 0);
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pump();
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 700));
      expect(activated, 1);
    });

    testWidgets('a beam startAfter overrides a theme one', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              playback: BeamPlayback(startAfter: Duration(seconds: 5)),
            ),
            child: BorderBeam(
              playback: BeamPlayback(startAfter: Duration(milliseconds: 100)),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
    });

    testWidgets('an outer theme startAfter reaches a beam under an inner '
        'theme', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              playback: BeamPlayback(startAfter: Duration(seconds: 2)),
            ),
            child: BorderBeamTheme(
              data: BorderBeamThemeData(style: BeamStyle(strength: 0.5)),
              child: BorderBeam(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pump();
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
    });

    testWidgets('a theme duration bounds the total play time', (tester) async {
      var deactivated = 0;
      await tester.pumpWidget(
        beamHost(
          BorderBeamTheme(
            data: const BorderBeamThemeData(
              playback: BeamPlayback(duration: Duration(seconds: 1)),
            ),
            child: BorderBeam(
              onDeactivate: () => deactivated++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a theme reducedMotion: animate keeps the beam moving', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          disableAnimations: true,
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              playback: BeamPlayback(reducedMotion: BeamReducedMotion.animate),
            ),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(beamPainterOf(tester).clock.isRunning, isTrue);
      expect(beamPainterOf(tester).staticMode, isFalse);
    });

    testWidgets('a theme fadeCurve reaches the clock', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              playback: BeamPlayback(fadeCurve: Curves.linear),
            ),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      expect(beamPainterOf(tester).clock.fadeCurve, Curves.linear);
    });

    for (final (name, playback) in [
      ('startAfter', const BeamPlayback(startAfter: Duration(seconds: 1))),
      ('duration', const BeamPlayback(duration: Duration(seconds: 1))),
    ]) {
      testWidgets('a controller with a theme $name asserts', (tester) async {
        final controller = BorderBeamController();
        addTearDown(controller.dispose);
        await pumpExpectingAssertion(
          tester,
          beamHost(
            BorderBeamTheme(
              data: BorderBeamThemeData(playback: playback),
              child: BorderBeam(
                controller: controller,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          message: 'When a BorderBeamController is attached it owns playback',
        );
      });
    }
  });
}
