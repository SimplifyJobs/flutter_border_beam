import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: app!,
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

BeamPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first;

BeamConfig _config(WidgetTester tester) => _painter(tester).config;

BeamClock _clock(WidgetTester tester) => _painter(tester).clock;

/// A field left null on a beam falls through to the nearest
/// [BorderBeamTheme], then to the variant preset; a value set on the beam
/// always wins.
void main() {
  testWidgets('a theme supplies defaults the beam leaves null', (tester) async {
    await tester.pumpWidget(
      _host(
        const BorderBeamTheme(
          data: BorderBeamThemeData(
            style: BeamStyle(colors: BeamColors.ocean, strength: 0.4),
            shape: BeamShape(borderWidth: 3),
            timing: BeamTiming(cycle: Duration(seconds: 4)),
          ),
          child: BorderBeam.rotate(child: SizedBox.expand()),
        ),
      ),
    );
    final config = _config(tester);
    expect(identical(config.palette, BeamColors.ocean.resolve()), isTrue);
    expect(config.strength, 0.4);
    expect(config.borderWidth, 3);
    expect(config.cycleSeconds, closeTo(4, 1e-9));
  });

  testWidgets('a shorthand on the beam wins over the theme', (tester) async {
    await tester.pumpWidget(
      _host(
        const BorderBeamTheme(
          data: BorderBeamThemeData(style: BeamStyle(colors: BeamColors.ocean)),
          child: BorderBeam.rotate(
            colors: BeamColors.sunset,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(
      identical(_config(tester).palette, BeamColors.sunset.resolve()),
      isTrue,
    );
  });

  testWidgets('nested themes merge, inner over outer', (tester) async {
    await tester.pumpWidget(
      _host(
        const BorderBeamTheme(
          data: BorderBeamThemeData(
            style: BeamStyle(colors: BeamColors.ocean, strength: 0.5),
            shape: BeamShape(borderWidth: 2),
          ),
          child: BorderBeamTheme(
            data: BorderBeamThemeData(style: BeamStyle(strength: 0.9)),
            child: BorderBeam.rotate(child: SizedBox.expand()),
          ),
        ),
      ),
    );
    final config = _config(tester);
    expect(
      identical(config.palette, BeamColors.ocean.resolve()),
      isTrue,
      reason: 'the outer theme still supplies colors',
    );
    expect(config.strength, 0.9, reason: 'the inner theme wins');
    expect(config.borderWidth, 2, reason: 'slots the inner theme omits');
  });

  testWidgets('changing an outer theme rebuilds beams under an inner one', (
    tester,
  ) async {
    Widget build(BeamColors colors) => _host(
      BorderBeamTheme(
        data: BorderBeamThemeData(style: BeamStyle(colors: colors)),
        child: const BorderBeamTheme(
          data: BorderBeamThemeData(style: BeamStyle(strength: 0.7)),
          child: BorderBeam.rotate(child: SizedBox.expand()),
        ),
      ),
    );

    await tester.pumpWidget(build(BeamColors.ocean));
    expect(
      identical(_config(tester).palette, BeamColors.ocean.resolve()),
      isTrue,
    );

    await tester.pumpWidget(build(BeamColors.sunset));
    expect(
      identical(_config(tester).palette, BeamColors.sunset.resolve()),
      isTrue,
    );
  });

  testWidgets('a theme playback keeps a beam idle', (tester) async {
    await tester.pumpWidget(
      _host(
        const BorderBeamTheme(
          data: BorderBeamThemeData(playback: BeamPlayback(autoPlay: false)),
          child: BorderBeam.rotate(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  group('playback through a theme', () {
    testWidgets('an active shorthand still respects a theme autoPlay: false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(autoPlay: false)),
            child: BorderBeam.rotate(active: true, child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        _clock(tester).isVisible,
        isFalse,
        reason: 'active says what to play, autoPlay says whether to start it',
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a beam autoPlay: true overrides a theme autoPlay: false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(autoPlay: false)),
            child: BorderBeam.rotate(
              playback: BeamPlayback(autoPlay: true),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_clock(tester).isVisible, isTrue);
    });

    testWidgets('a theme startAfter delays the start', (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        _host(
          BorderBeamTheme(
            data: const BorderBeamThemeData(
              playback: BeamPlayback(startAfter: Duration(seconds: 2)),
            ),
            child: BorderBeam.rotate(
              onActivate: () => activated++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(activated, 0);
      expect(_clock(tester).isVisible, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pump();
      expect(_clock(tester).isVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 700));
      expect(activated, 1);
    });

    testWidgets('a beam startAfter overrides a theme one', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              playback: BeamPlayback(startAfter: Duration(seconds: 5)),
            ),
            child: BorderBeam.rotate(
              playback: BeamPlayback(startAfter: Duration(milliseconds: 100)),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_clock(tester).isVisible, isTrue);
    });

    testWidgets('a theme duration bounds the total play time', (tester) async {
      var deactivated = 0;
      await tester.pumpWidget(
        _host(
          BorderBeamTheme(
            data: const BorderBeamThemeData(
              playback: BeamPlayback(duration: Duration(seconds: 1)),
            ),
            child: BorderBeam.rotate(
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
    });

    testWidgets('a theme reducedMotion: animate keeps the beam moving', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              playback: BeamPlayback(reducedMotion: BeamReducedMotion.animate),
            ),
            child: BorderBeam.rotate(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_clock(tester).isRunning, isTrue);
    });

    testWidgets('a controller with a theme startAfter asserts', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await pumpExpectingAssertion(
        tester,
        _host(
          BorderBeamTheme(
            data: const BorderBeamThemeData(
              playback: BeamPlayback(startAfter: Duration(seconds: 1)),
            ),
            child: BorderBeam.rotate(
              controller: controller,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        message: 'When a BorderBeamController is attached it owns playback',
      );
    });

    testWidgets('a controller with a theme duration asserts', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      await pumpExpectingAssertion(
        tester,
        _host(
          BorderBeamTheme(
            data: const BorderBeamThemeData(
              playback: BeamPlayback(duration: Duration(seconds: 1)),
            ),
            child: BorderBeam.rotate(
              controller: controller,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        message: 'When a BorderBeamController is attached it owns playback',
      );
    });

    testWidgets('an outer theme startAfter reaches a beam under an inner '
        'theme', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              playback: BeamPlayback(startAfter: Duration(seconds: 2)),
            ),
            child: BorderBeamTheme(
              data: BorderBeamThemeData(style: BeamStyle(strength: 0.5)),
              child: BorderBeam.rotate(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_clock(tester).isVisible, isFalse);
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pump();
      expect(_clock(tester).isVisible, isTrue);
    });
  });
}
