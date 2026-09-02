import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
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

/// The three shorthands (`colors`, `active`, `borderRadius`) are the top of
/// the resolution order: they beat the value object they abbreviate on the
/// same widget, and everything a `BorderBeamTheme` supplies. The generic
/// `BorderBeam(variant:)` constructor must build exactly what the matching
/// named constructor does.
///
/// The `borderRadius` shorthand is covered in `beam_shape_test.dart`, next
/// to the rest of the shape resolution.
void main() {
  group('colors shorthand', () {
    testWidgets('beats style.colors on the same widget', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            colors: BeamColors.sunset,
            style: BeamStyle(colors: BeamColors.ocean, strength: 0.3),
            child: SizedBox.expand(),
          ),
        ),
      );
      final config = _painter(tester).config;
      expect(identical(config.palette, BeamColors.sunset.resolve()), isTrue);
      expect(config.strength, 0.3, reason: 'the rest of the style survives');
    });

    testWidgets('beats a theme colors and the widget style together', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              style: BeamStyle(colors: BeamColors.ocean),
            ),
            child: BorderBeam.rotate(
              colors: BeamColors.sunset,
              style: BeamStyle(colors: BeamColors.mono),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      final config = _painter(tester).config;
      expect(identical(config.palette, BeamColors.sunset.resolve()), isTrue);
      expect(
        config.staticColors,
        isFalse,
        reason: 'the mono palette never took effect',
      );
    });

    testWidgets('a null shorthand leaves style.colors in charge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            style: BeamStyle(colors: BeamColors.ocean),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(
        identical(_painter(tester).config.palette, BeamColors.ocean.resolve()),
        isTrue,
      );
    });
  });

  group('active shorthand', () {
    testWidgets('beats playback.active on the same widget', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            active: true,
            playback: BeamPlayback(active: false),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_painter(tester).clock.isVisible, isTrue);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('active: false wins over playback.active: true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            active: false,
            playback: BeamPlayback(active: true),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).clock.isVisible, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('beats a theme playback', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(active: false)),
            child: BorderBeam.rotate(active: true, child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_painter(tester).clock.isVisible, isTrue);
    });

    testWidgets('a theme active: false keeps a plain beam idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(playback: BeamPlayback(active: false)),
            child: BorderBeam.rotate(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).clock.isVisible, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the shorthand keeps the rest of the playback', (tester) async {
      var deactivated = 0;
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
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

  group('the generic constructor', () {
    Widget named(BeamVariant variant) => switch (variant) {
      BeamVariant.rotate => const BorderBeam.rotate(
        colors: BeamColors.ocean,
        child: SizedBox.expand(),
      ),
      BeamVariant.small => const BorderBeam.small(
        colors: BeamColors.ocean,
        child: SizedBox.expand(),
      ),
      BeamVariant.line => const BorderBeam.line(
        colors: BeamColors.ocean,
        child: SizedBox.expand(),
      ),
      BeamVariant.pulseInside => const BorderBeam.pulseInside(
        colors: BeamColors.ocean,
        child: SizedBox.expand(),
      ),
      BeamVariant.pulseOutside => const BorderBeam.pulseOutside(
        colors: BeamColors.ocean,
        child: SizedBox.expand(),
      ),
    };

    for (final variant in BeamVariant.values) {
      testWidgets('$variant matches its named constructor', (tester) async {
        await tester.pumpWidget(
          _host(
            BorderBeam(
              variant: variant,
              colors: BeamColors.ocean,
              child: const SizedBox.expand(),
            ),
          ),
        );
        final generic = _painter(tester);
        expect(generic.config.variant, variant);
        expect(
          identical(generic.strategy, strategyFor(variant)),
          isTrue,
          reason: 'the strategy for $variant',
        );

        await tester.pumpWidget(_host(named(variant)));
        final byName = _painter(tester);
        expect(byName.config, generic.config);
        expect(identical(byName.strategy, generic.strategy), isTrue);
        expect(byName.behind, generic.behind);
      });
    }

    testWidgets('pulseOutside is the only variant that paints behind', (
      tester,
    ) async {
      for (final variant in BeamVariant.values) {
        await tester.pumpWidget(
          _host(BorderBeam(variant: variant, child: const SizedBox.expand())),
        );
        final custom = tester.widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(BorderBeam),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        expect(
          custom.painter,
          variant == BeamVariant.pulseOutside ? isA<BeamPainter>() : isNull,
          reason: '$variant',
        );
        expect(
          custom.foregroundPainter,
          isA<BeamPainter>(),
          reason: '$variant',
        );
      }
    });
  });
}
