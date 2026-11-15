import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

/// The three shorthands (`colors`, `active`, `borderRadius`) sit at the top
/// of the resolution order: they beat the value-object field they abbreviate
/// on the same widget, and everything a `BorderBeamTheme` supplies — and they
/// leave every other field of that value object alone.
void main() {
  group('colors', () {
    testWidgets('beats style.colors on the same widget', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            colors: BeamColors.sunset,
            style: BeamStyle(colors: BeamColors.ocean, strength: 0.3, glow: 2),
            child: SizedBox.expand(),
          ),
        ),
      );
      final config = beamPainterOf(tester).config;
      expect(config.palette, BeamColors.sunset.resolve());
      expect(config.strength, 0.3, reason: 'the rest of the style survives');
      expect(config.glow, 2);
    });

    testWidgets('beats a theme and the widget style together', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              style: BeamStyle(colors: BeamColors.ocean, hueBase: 40),
            ),
            child: BorderBeam(
              colors: BeamColors.sunset,
              style: BeamStyle(colors: BeamColors.mono),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      final config = beamPainterOf(tester).config;
      expect(config.palette, BeamColors.sunset.resolve());
      expect(
        config.hueMode,
        isNot(BeamHueMode.none),
        reason: 'the fixed-hue mono palette never took effect',
      );
      expect(config.hueBase, 40, reason: 'the theme fills the rest');
    });

    testWidgets('a null shorthand leaves style.colors in charge', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            style: BeamStyle(colors: BeamColors.ocean),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(beamPainterOf(tester).config.palette, BeamColors.ocean.resolve());
    });

    testWidgets('a custom palette passes through', (tester) async {
      const custom = BeamColors([Color(0xFFFF0000), Color(0xFF0000FF)]);
      await tester.pumpWidget(
        beamHost(const BorderBeam(colors: custom, child: SizedBox.expand())),
      );
      final palette = beamPainterOf(tester).config.palette;
      expect(palette, custom.resolve());
      expect(palette.colors, hasLength(2));
    });
  });

  group('active', () {
    testWidgets('true beats playback.active: false', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            active: true,
            playback: BeamPlayback(active: false),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
      expect(tester.binding.transientCallbackCount, 1);
    });

    testWidgets('false beats playback.active: true', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            active: false,
            playback: BeamPlayback(active: true),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('beats a theme playback', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(active: false)),
            child: BorderBeam(active: true, child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(beamPainterOf(tester).clock.isVisible, isTrue);
    });

    testWidgets('a theme active: false keeps a plain beam idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(active: false)),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(beamPainterOf(tester).clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('keeps the rest of the playback', (tester) async {
      var deactivated = 0;
      await tester.pumpWidget(
        beamHost(
          BorderBeam(
            active: true,
            playback: const BeamPlayback(
              active: false,
              duration: Duration(seconds: 1),
            ),
            onDeactivate: () => deactivated++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(deactivated, 1, reason: 'playback.duration still applies');
    });
  });

  group('borderRadius', () {
    testWidgets('beats shape.radius on the same widget', (tester) async {
      await tester.pumpWidget(
        beamHost(
          BorderBeam(
            borderRadius: 8,
            shape: BeamShape(radius: BorderRadius.circular(40)),
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(
        beamPainterOf(tester).config.borderRadius,
        BorderRadius.circular(8),
      );
    });

    testWidgets('beats a theme radius', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(shape: BeamShape.all(40)),
            child: BorderBeam(borderRadius: 8, child: SizedBox.expand()),
          ),
        ),
      );
      expect(
        beamPainterOf(tester).config.borderRadius,
        BorderRadius.circular(8),
      );
    });

    testWidgets('beats a per-corner radius, not just a uniform one', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            borderRadius: 8,
            shape: BeamShape(
              radius: BorderRadiusDirectional.only(
                topStart: Radius.circular(30),
              ),
            ),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(
        beamPainterOf(tester).config.borderRadius,
        BorderRadius.circular(8),
      );
    });

    testWidgets('leaves the other shape fields alone', (tester) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            borderRadius: 8,
            shape: BeamShape(
              borderWidth: 6,
              superellipse: true,
              ringOffset: 4,
              dashes: 6,
            ),
            child: SizedBox.expand(),
          ),
        ),
      );
      final config = beamPainterOf(tester).config;
      expect(config.borderRadius, BorderRadius.circular(8));
      expect(config.borderWidth, 6);
      expect(config.superellipse, isTrue);
      expect(config.ringOffset, 4);
      expect(config.dashes, 6);
    });
  });
}
