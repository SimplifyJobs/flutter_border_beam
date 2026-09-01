import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Degenerate geometry and out-of-range parameters. Everything here is a
/// value a consumer can legitimately pass (or a layout can legitimately
/// produce), so no combination may throw — and `strength: 0` must paint
/// literally nothing.
void main() {
  const normal = ui.Size(350, 140);
  // Post fade-in samples spread over the cycle; the line variant paints
  // nothing at the cycle edges, so pixel checks aggregate over all of them.
  const samples = [0.0, 0.5, 1.3, 7.9];

  BeamConfig configFor(
    BeamVariant variant, {
    double? borderRadius,
    double? borderWidth,
    double strength = 1,
    double hueRange = 30,
    bool staticColors = false,
    Duration? cycleDuration,
    ui.Brightness brightness = ui.Brightness.dark,
  }) => BeamConfig.resolve(
    variant: variant,
    palette: BeamColors.colorful.resolve(),
    brightness: brightness,
    borderRadius: borderRadius,
    borderWidth: borderWidth,
    strength: strength,
    hueRange: hueRange,
    staticColors: staticColors,
    cycleDuration: cycleDuration,
  );

  /// Runs both passes across the samples, letting any exception escape.
  void paintFrames(BeamVariant variant, BeamConfig config, ui.Size size) {
    final resolver = BeamPhaseResolver(config);
    final strategy = strategyFor(variant);
    for (final t in samples) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final phases = resolver.sample(t, 1);
      strategy.paintBehind(canvas, size, config, phases);
      strategy.paintAbove(canvas, size, config, phases);
      recorder.endRecording().dispose();
    }
  }

  /// Whether any sample of the requested pass leaves a non-transparent pixel
  /// inside [size].
  Future<bool> paintsPixels(
    BeamVariant variant,
    BeamConfig config, {
    ui.Size size = normal,
    bool behind = true,
    bool above = true,
  }) async {
    final resolver = BeamPhaseResolver(config);
    final strategy = strategyFor(variant);
    for (final t in samples) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final phases = resolver.sample(t, 1);
      if (behind) strategy.paintBehind(canvas, size, config, phases);
      if (above) strategy.paintAbove(canvas, size, config, phases);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      picture.dispose();
      image.dispose();
      for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) != 0) return true;
      }
    }
    return false;
  }

  group('degenerate sizes', () {
    const sizes = <String, ui.Size>{
      'zero': ui.Size.zero,
      '1x1': ui.Size(1, 1),
      'wide sliver': ui.Size(2000, 2),
      'tall sliver': ui.Size(2, 2000),
    };
    for (final variant in BeamVariant.values) {
      for (final MapEntry(key: name, value: size) in sizes.entries) {
        test('$variant paints a $name box', () {
          paintFrames(variant, configFor(variant), size);
        });
      }
    }
  });

  group('geometry parameters', () {
    for (final variant in BeamVariant.values) {
      test('$variant: radius larger than the shortest side', () async {
        // 400 > 140: the ring geometry clamps it to half the short side.
        final config = configFor(variant, borderRadius: 400);
        paintFrames(variant, config, normal);
        expect(await paintsPixels(variant, config), isTrue);
      });

      test('$variant: border wider than the radius', () async {
        final config = configFor(variant, borderRadius: 4, borderWidth: 40);
        paintFrames(variant, config, normal);
        expect(await paintsPixels(variant, config), isTrue);
      });

      test('$variant: zero border width', () async {
        // The ring collapses to an empty path — stroke layers paint nothing,
        // but the inner/glow layers still do.
        final config = configFor(variant, borderWidth: 0);
        paintFrames(variant, config, normal);
        expect(await paintsPixels(variant, config), isTrue);
      });
    }
  });

  group('animation parameters', () {
    for (final variant in BeamVariant.values) {
      test('$variant: a 1ms cycle', () {
        paintFrames(
          variant,
          configFor(variant, cycleDuration: const Duration(milliseconds: 1)),
          normal,
        );
      });

      test('$variant: a one-hour cycle', () {
        paintFrames(
          variant,
          configFor(variant, cycleDuration: const Duration(hours: 1)),
          normal,
        );
      });

      test('$variant: hueRange 0', () async {
        final config = configFor(variant, hueRange: 0);
        paintFrames(variant, config, normal);
        expect(await paintsPixels(variant, config), isTrue);
      });

      test('$variant: staticColors', () async {
        final config = configFor(variant, staticColors: true);
        paintFrames(variant, config, normal);
        expect(await paintsPixels(variant, config), isTrue);
      });
    }
  });

  group('strength 0', () {
    for (final variant in BeamVariant.values) {
      test('$variant paints nothing at all', () async {
        final config = configFor(variant, strength: 0);
        paintFrames(variant, config, normal);
        expect(
          await paintsPixels(variant, config, above: false),
          isFalse,
          reason: 'the behind-child pass must be fully suppressed',
        );
        expect(
          await paintsPixels(variant, config, behind: false),
          isFalse,
          reason: 'the above-child pass must be fully suppressed',
        );
      });
    }
  });

  group('degenerate layouts', () {
    Widget host(Widget child) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('a beam collapsed to zero size renders', (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox.shrink(
            child: BorderBeam.rotate(child: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a beam around a zero-height child in a Column renders', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              BorderBeam.rotate(child: SizedBox(width: 120, height: 0)),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    });
  });
}
