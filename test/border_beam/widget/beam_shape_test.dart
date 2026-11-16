import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/border_beam/models/beam_config.dart';

import 'test_utils.dart';

BeamConfig _config(WidgetTester tester) => beamPainterOf(tester).config;

/// How `BeamShape` reaches `BeamConfig`: inherited from a `BorderBeamTheme`,
/// overridden field by field on the widget, and — for a directional radius —
/// resolved against the ambient `Directionality`. (The `borderRadius:`
/// shorthand is covered in `beam_shorthand_test.dart`.)
void main() {
  group('inheritance', () {
    testWidgets('a bare beam falls through to the shape defaults', (
      tester,
    ) async {
      for (final effect in BeamEffect.values) {
        await tester.pumpWidget(
          beamHost(BorderBeam(effect: effect, child: const SizedBox.expand())),
        );
        final config = _config(tester);
        expect(
          config.borderRadius,
          const BeamShape().resolveRadius(TextDirection.ltr),
          reason: effect.name,
        );
        expect(config.superellipse, isFalse, reason: effect.name);
        expect(config.segment, isNull, reason: effect.name);
        expect(config.dashes, 0, reason: effect.name);
      }
    });

    testWidgets('a theme borderWidth and superellipse reach the config', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              shape: BeamShape(borderWidth: 4, superellipse: true),
            ),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      final config = _config(tester);
      expect(config.borderWidth, 4);
      expect(config.superellipse, isTrue);
      expect(
        config.borderRadius,
        const BeamShape().resolveRadius(TextDirection.ltr),
        reason: 'the radius still falls through to the default',
      );
    });

    testWidgets('the widget overrides an inherited superellipse with false', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              shape: BeamShape(superellipse: true, borderWidth: 4),
            ),
            child: BorderBeam(
              shape: BeamShape(superellipse: false),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      final config = _config(tester);
      expect(config.superellipse, isFalse, reason: 'false is a value');
      expect(config.borderWidth, 4, reason: 'the field it did not set');
    });

    testWidgets('ring offset, segment, and dashes reach the config', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(
              shape: BeamShape(ringOffset: 6, segment: BeamSegment.topHalf),
            ),
            child: BorderBeam(
              shape: BeamShape(dashes: 8, segment: BeamSegment.bottomHalf),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      final config = _config(tester);
      expect(config.ringOffset, 6);
      expect(config.segment, BeamSegment.bottomHalf);
      expect(config.dashes, 8);
    });
  });

  group('radius', () {
    testWidgets('BeamShape.all and BeamShape.circular resolve alike', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(shape: BeamShape.all(24), child: SizedBox.expand()),
        ),
      );
      final all = _config(tester);
      await tester.pumpWidget(
        beamHost(
          BorderBeam(
            shape: BeamShape.circular(24),
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(
        identical(_config(tester), all),
        isTrue,
        reason: 'equal shapes: the cached config is reused',
      );
      expect(all.borderRadius, BorderRadius.circular(24));
    });

    testWidgets('per-corner radii reach the config', (tester) async {
      const radius = BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(12),
        bottomRight: Radius.elliptical(20, 10),
      );
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            shape: BeamShape(radius: radius),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(_config(tester).borderRadius, radius);
    });

    testWidgets('a stadium reaches the config as an infinite radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeam(
            shape: BeamShape.stadium(),
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(
        _config(tester).borderRadius,
        const BorderRadius.all(Radius.circular(double.infinity)),
        reason: 'the outline, not the config, clamps it to the box',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a stadium from a theme survives a widget radius-free shape', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          const BorderBeamTheme(
            data: BorderBeamThemeData(shape: BeamShape.stadium()),
            child: BorderBeam(
              shape: BeamShape(borderWidth: 2),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      final config = _config(tester);
      expect(
        config.borderRadius,
        const BorderRadius.all(Radius.circular(double.infinity)),
      );
      expect(config.borderWidth, 2);
    });
  });

  group('directional radius', () {
    const directional = BorderRadiusDirectional.only(
      topStart: Radius.circular(20),
    );

    Widget beam(TextDirection direction) => beamHost(
      textDirection: direction,
      const BorderBeam(
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
      expect(radius.bottomLeft, Radius.zero);
      expect(radius.bottomRight, Radius.zero);
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

    testWidgets('a directional radius from a theme resolves at the beam', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          textDirection: TextDirection.rtl,
          const BorderBeamTheme(
            data: BorderBeamThemeData(shape: BeamShape(radius: directional)),
            child: BorderBeam(child: SizedBox.expand()),
          ),
        ),
      );
      expect(_config(tester).borderRadius.topRight, const Radius.circular(20));
    });

    testWidgets('a non-directional radius is unaffected by RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        beamHost(
          textDirection: TextDirection.rtl,
          const BorderBeam(
            shape: BeamShape(
              radius: BorderRadius.only(topLeft: Radius.circular(20)),
            ),
            child: SizedBox.expand(),
          ),
        ),
      );
      final radius = _config(tester).borderRadius;
      expect(radius.topLeft, const Radius.circular(20));
      expect(radius.topRight, Radius.zero);
    });
  });
}
