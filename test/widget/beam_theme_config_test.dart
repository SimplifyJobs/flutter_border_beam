import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/constants/theme_presets.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 200,
        height: 100,
        child: RepaintBoundary(child: child),
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

/// Rasterizes the beam's repaint boundary as raw RGBA.
Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(BorderBeam),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// `BeamStyle.themeConfig` replaces the whole variant×brightness preset, so a
/// layer opacity set to zero must reach the painter's config *and* the
/// rasterized frame.
void main() {
  group('themeConfig through a mounted beam', () {
    Widget beam(BeamThemeConfig? themeConfig) => _host(
      BorderBeam.rotate(
        style: BeamStyle(themeConfig: themeConfig),
        // A frozen palette and no hue animation keeps two renders of the
        // same config byte-identical.
        colors: BeamColors.ocean,
        child: const SizedBox.expand(),
      ),
    );

    testWidgets('replaces the preset the variant would have used', (
      tester,
    ) async {
      final preset = BeamThemeConfig.presetFor(
        BeamVariant.rotate,
        Brightness.dark,
      );
      await tester.pumpWidget(beam(preset.copyWith(strokeOpacity: 0)));
      final config = _config(tester);
      expect(config.theme.strokeOpacity, 0);
      expect(
        config.theme.innerOpacity,
        preset.innerOpacity,
        reason: 'the untouched fields still come from the preset',
      );
      expect(config.theme.bloomOpacity, preset.bloomOpacity);
      expect(config.theme.innerShadow, preset.innerShadow);
    });

    testWidgets('a zero stroke opacity changes the rendered frame', (
      tester,
    ) async {
      final preset = BeamThemeConfig.presetFor(
        BeamVariant.rotate,
        Brightness.dark,
      );

      await tester.pumpWidget(beam(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      final withStroke = await _pixels(tester);

      // The same tree again: the rasterization itself is deterministic, so a
      // difference below can only come from the config.
      await tester.pumpWidget(beam(null));
      await tester.pump();
      expect(
        await _pixels(tester),
        withStroke,
        reason: 'an unchanged config renders the identical frame',
      );

      await tester.pumpWidget(beam(preset.copyWith(strokeOpacity: 0)));
      await tester.pump();
      final withoutStroke = await _pixels(tester);
      expect(
        withoutStroke,
        isNot(withStroke),
        reason: 'the stroke layer is gone',
      );
      expect(withoutStroke.length, withStroke.length);
    });

    testWidgets('a fully transparent preset paints nothing', (tester) async {
      const blank = BeamThemeConfig(
        strokeOpacity: 0,
        innerOpacity: 0,
        bloomOpacity: 0,
        innerShadow: Color(0x00000000),
        saturation: 1,
      );
      await tester.pumpWidget(beam(blank));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      final pixels = await _pixels(tester);
      var opaque = 0;
      for (var i = 3; i < pixels.length; i += 4) {
        if (pixels[i] != 0) opaque++;
      }
      expect(opaque, 0, reason: 'every beam layer opacity is zero');
    });

    testWidgets('style brightness and saturation still override it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BorderBeam.rotate(
            style: BeamStyle(
              themeConfig: BeamThemeConfig.presetFor(
                BeamVariant.rotate,
                Brightness.dark,
              ).copyWith(brightness: 2, saturation: 3),
              brightness: 0.5,
              saturation: 0.25,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final config = _config(tester);
      expect(config.brightnessFactor, 0.5);
      expect(config.saturation, 0.25);
    });

    testWidgets('a themeConfig from a BorderBeamTheme is inherited', (
      tester,
    ) async {
      final preset = BeamThemeConfig.presetFor(
        BeamVariant.line,
        Brightness.dark,
      ).copyWith(bloomOpacity: 0.05);
      await tester.pumpWidget(
        _host(
          BorderBeamTheme(
            data: BorderBeamThemeData(style: BeamStyle(themeConfig: preset)),
            child: const BorderBeam.line(child: SizedBox.expand()),
          ),
        ),
      );
      expect(_config(tester).theme.bloomOpacity, 0.05);
    });
  });

  group('BeamThemeConfig', () {
    test('presetFor matches themePresetFor for every variant × brightness', () {
      for (final variant in BeamVariant.values) {
        for (final brightness in Brightness.values) {
          final preset = BeamThemeConfig.presetFor(variant, brightness);
          final expected = themePresetFor(variant, brightness);
          expect(preset, expected, reason: '$variant $brightness');
          expect(preset.strokeOpacity, expected.strokeOpacity);
          expect(preset.innerOpacity, expected.innerOpacity);
          expect(preset.bloomOpacity, expected.bloomOpacity);
          expect(preset.innerShadow, expected.innerShadow);
          expect(preset.saturation, expected.saturation);
          expect(preset.brightness, expected.brightness);
          expect(preset.hairlineOpacity, expected.hairlineOpacity);
        }
      }
    });

    test('dark and light presets differ for every variant', () {
      for (final variant in BeamVariant.values) {
        expect(
          BeamThemeConfig.presetFor(variant, Brightness.dark),
          isNot(BeamThemeConfig.presetFor(variant, Brightness.light)),
          reason: '$variant',
        );
      }
    });

    test('copyWith keeps every field it is not given', () {
      const base = BeamThemeConfig(
        strokeOpacity: 0.26,
        innerOpacity: 0.42,
        bloomOpacity: 0.24,
        innerShadow: Color(0x44FFFFFF),
        saturation: 1.2,
        brightness: 1.1,
        hairlineOpacity: 0.3,
      );
      final copy = base.copyWith(bloomOpacity: 0.9);
      expect(copy.bloomOpacity, 0.9);
      expect(copy.strokeOpacity, base.strokeOpacity);
      expect(copy.innerOpacity, base.innerOpacity);
      expect(copy.innerShadow, base.innerShadow);
      expect(copy.saturation, base.saturation);
      expect(copy.brightness, base.brightness);
      expect(copy.hairlineOpacity, base.hairlineOpacity);
      expect(base.copyWith(), base, reason: 'an empty copy is the same value');
    });

    test('equality and hashCode are by value', () {
      const a = BeamThemeConfig(
        strokeOpacity: 0.5,
        innerOpacity: 0.4,
        bloomOpacity: 0.3,
        innerShadow: Color(0x22000000),
        saturation: 1.5,
      );
      const b = BeamThemeConfig(
        strokeOpacity: 0.5,
        innerOpacity: 0.4,
        bloomOpacity: 0.3,
        innerShadow: Color(0x22000000),
        saturation: 1.5,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.copyWith(strokeOpacity: 0.51)));
      expect(a, isNot(b.copyWith(innerOpacity: 0.41)));
      expect(a, isNot(b.copyWith(bloomOpacity: 0.31)));
      expect(a, isNot(b.copyWith(innerShadow: const Color(0x22000001))));
      expect(a, isNot(b.copyWith(saturation: 1.51)));
      expect(a, isNot(b.copyWith(brightness: 1)));
      expect(a, isNot(b.copyWith(hairlineOpacity: 0)));
      expect(a.toString(), contains('strokeOpacity: 0.5'));
    });
  });
}
