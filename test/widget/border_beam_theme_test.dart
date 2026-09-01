import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

BeamConfig _config(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first
    .config;

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
}
