import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {TextDirection? textDirection}) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 350,
        height: 140,
        child: textDirection == null
            ? child
            : Directionality(textDirection: textDirection, child: child),
      ),
    ),
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

/// How `BeamShape` reaches `BeamConfig`: inherited from a `BorderBeamTheme`,
/// overridden field by field on the widget, short-circuited by the
/// `borderRadius:` shorthand, and — for a directional radius — resolved
/// against the ambient `Directionality`.
void main() {
  group('inheritance', () {
    testWidgets('a theme borderWidth and superellipse reach the config', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              shape: BeamShape(borderWidth: 4, superellipse: true),
            ),
            child: BorderBeam.rotate(child: SizedBox.expand()),
          ),
        ),
      );
      final config = _config(tester);
      expect(config.borderWidth, 4);
      expect(config.useSuperellipse, isTrue);
      expect(
        config.borderRadius,
        BorderRadius.circular(16),
        reason: 'the radius still falls through to the rotate preset',
      );
    });

    testWidgets('the widget overrides an inherited superellipse with false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              shape: BeamShape(superellipse: true, borderWidth: 4),
            ),
            child: BorderBeam.rotate(
              shape: BeamShape(superellipse: false),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      final config = _config(tester);
      expect(config.useSuperellipse, isFalse, reason: 'false is a value');
      expect(config.borderWidth, 4, reason: 'the field it did not set');
    });

    testWidgets('each variant keeps its own default radius and width', (
      tester,
    ) async {
      for (final variant in BeamVariant.values) {
        await tester.pumpWidget(
          _host(BorderBeam(variant: variant, child: const SizedBox.expand())),
        );
        final config = _config(tester);
        expect(
          config.borderRadius,
          BorderRadius.circular(variant == BeamVariant.small ? 32 : 16),
          reason: '$variant',
        );
        expect(config.borderWidth, 1, reason: '$variant');
        expect(config.useSuperellipse, isFalse, reason: '$variant');
      }
    });
  });

  group('borderRadius shorthand', () {
    testWidgets('beats shape.radius on the same widget', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            borderRadius: 8,
            shape: BeamShape(radius: BorderRadius.circular(40)),
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(_config(tester).borderRadius, BorderRadius.circular(8));
    });

    testWidgets('beats a theme radius', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeamTheme(
            data: BorderBeamThemeData(
              shape: BeamShape(radius: BorderRadius.circular(40)),
            ),
            child: const BorderBeam.rotate(
              borderRadius: 8,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      expect(_config(tester).borderRadius, BorderRadius.circular(8));
    });

    testWidgets('leaves the other shape fields alone', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            borderRadius: 8,
            shape: BeamShape(borderWidth: 6, superellipse: true),
            child: SizedBox.expand(),
          ),
        ),
      );
      final config = _config(tester);
      expect(config.borderRadius, BorderRadius.circular(8));
      expect(config.borderWidth, 6);
      expect(config.useSuperellipse, isTrue);
    });

    testWidgets('a stadium shape survives to the config as an infinite '
        'radius', (tester) async {
      await tester.pumpWidget(
        _host(
          const BorderBeam.rotate(
            shape: BeamShape.stadium(),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(
        _config(tester).borderRadius,
        const BorderRadius.all(Radius.circular(double.infinity)),
        reason: 'the ring geometry, not the config, clamps it to the box',
      );
    });
  });

  group('directional radius', () {
    const directional = BorderRadiusDirectional.only(
      topStart: Radius.circular(20),
    );

    Widget beam(TextDirection direction) => _host(
      textDirection: direction,
      const BorderBeam.rotate(
        shape: BeamShape(radius: directional),
        child: SizedBox.expand(),
      ),
    );

    testWidgets('topStart resolves to the top-left corner in LTR', (
      tester,
    ) async {
      await tester.pumpWidget(beam(TextDirection.ltr));
      final radius = _config(tester).borderRadius;
      expect(radius.topLeft, const Radius.circular(20));
      expect(radius.topRight, Radius.zero);
    });

    testWidgets('topStart resolves to the top-right corner in RTL', (
      tester,
    ) async {
      await tester.pumpWidget(beam(TextDirection.rtl));
      final radius = _config(tester).borderRadius;
      expect(radius.topRight, const Radius.circular(20));
      expect(radius.topLeft, Radius.zero);
      expect(radius.bottomLeft, Radius.zero);
      expect(radius.bottomRight, Radius.zero);
    });

    testWidgets('flipping the direction re-resolves the config', (
      tester,
    ) async {
      await tester.pumpWidget(beam(TextDirection.ltr));
      final ltr = _config(tester);

      await tester.pumpWidget(beam(TextDirection.rtl));
      final rtl = _config(tester);
      expect(identical(rtl, ltr), isFalse, reason: 'a fresh config object');
      expect(rtl.borderRadius.topRight, const Radius.circular(20));

      await tester.pumpWidget(beam(TextDirection.ltr));
      final back = _config(tester);
      expect(identical(back, rtl), isFalse);
      expect(back.borderRadius, ltr.borderRadius);
    });

    testWidgets('a non-directional radius is unaffected by RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          textDirection: TextDirection.rtl,
          BorderBeam.rotate(
            shape: BeamShape(
              radius: const BorderRadius.only(topLeft: Radius.circular(20)),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final radius = _config(tester).borderRadius;
      expect(radius.topLeft, const Radius.circular(20));
      expect(radius.topRight, Radius.zero);
    });
  });
}
