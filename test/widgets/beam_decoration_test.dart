import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// [BeamDecoration] runs the beam engine from a [BoxPainter] instead of a
/// widget: it owns a raw [Ticker], repaints its box through `onChanged`, and
/// must give that ticker back when the render object drops it.
void main() {
  const boundaryKey = ValueKey<String>('boundary');

  Widget scene(Decoration decoration, {bool foreground = true}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark),
    home: Center(
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: 350,
          height: 140,
          foregroundDecoration: foreground ? decoration : null,
          decoration: foreground ? null : decoration,
        ),
      ),
    ),
  );

  // Non-transparent pixels inside the boundary. Nothing else in the scene
  // paints, so a count above zero is the beam and only the beam.
  Future<int> paintedPixels(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    var painted = 0;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) != 0) painted++;
      }
    });
    return painted;
  }

  group('painting', () {
    testWidgets('paints the beam through a DecoratedBox', (tester) async {
      await tester.pumpWidget(
        scene(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
            borderRadius: 16,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(await paintedPixels(tester), greaterThan(0));
    });

    testWidgets('paints nothing while inactive', (tester) async {
      await tester.pumpWidget(
        scene(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
            active: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(await paintedPixels(tester), 0);
    });

    testWidgets('paints every variant, in the slot its docs name', (
      tester,
    ) async {
      for (final variant in BeamVariant.values) {
        // pulse-outside blooms behind the child; every other variant paints
        // over it. Both land in whichever slot the decoration is given.
        final foreground = variant != BeamVariant.pulseOutside;
        await tester.pumpWidget(
          scene(
            BeamDecoration(variant: variant, brightness: Brightness.dark),
            foreground: foreground,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1300));

        expect(
          await paintedPixels(tester),
          greaterThan(0),
          reason: '$variant painted nothing',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('holds the beam back until startAfter elapses', (tester) async {
      await tester.pumpWidget(
        scene(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
            playback: BeamPlayback(startAfter: Duration(seconds: 1)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(await paintedPixels(tester), 0);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(await paintedPixels(tester), greaterThan(0));
    });
  });

  group('ticking', () {
    testWidgets('calls onChanged on every clock tick', (tester) async {
      var changes = 0;
      final painter = const BeamDecoration(
        variant: BeamVariant.rotate,
        brightness: Brightness.dark,
      ).createBoxPainter(() => changes++);

      // The first tick after Ticker.start() reports elapsed 0; pump once
      // before pumping durations.
      await tester.pump();
      expect(changes, greaterThan(0));

      final afterFirst = changes;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(changes, greaterThan(afterFirst));
      painter.dispose();
    });

    testWidgets('an inactive decoration never ticks', (tester) async {
      var changes = 0;
      final painter = const BeamDecoration(
        variant: BeamVariant.rotate,
        brightness: Brightness.dark,
        playback: BeamPlayback(autoPlay: false),
      ).createBoxPainter(() => changes++);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(changes, 0);
      expect(tester.binding.transientCallbackCount, 0);
      painter.dispose();
    });

    testWidgets('gives its ticker back when the render object goes', (
      tester,
    ) async {
      await tester.pumpWidget(
        scene(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('disposing the painter mid-fade leaves no ticker', (
      tester,
    ) async {
      final painter = const BeamDecoration(
        variant: BeamVariant.pulseInside,
        brightness: Brightness.light,
      ).createBoxPainter(() {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      painter.dispose();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('swapping decorations keeps exactly one ticker', (
      tester,
    ) async {
      await tester.pumpWidget(
        scene(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
          ),
        ),
      );
      await tester.pump();
      final before = tester.binding.transientCallbackCount;

      await tester.pumpWidget(
        scene(
          const BeamDecoration(
            variant: BeamVariant.line,
            brightness: Brightness.dark,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(tester.binding.transientCallbackCount, before);
      expect(await paintedPixels(tester), greaterThan(0));
    });
  });

  group('value semantics', () {
    const base = BeamDecoration(
      variant: BeamVariant.rotate,
      brightness: Brightness.dark,
      colors: BeamColors.ocean,
      borderRadius: 16,
    );

    test('equal field-for-field', () {
      const same = BeamDecoration(
        variant: BeamVariant.rotate,
        brightness: Brightness.dark,
        colors: BeamColors.ocean,
        borderRadius: 16,
      );
      expect(base, equals(same));
      expect(base.hashCode, same.hashCode);
    });

    test('each field participates', () {
      expect(
        base,
        isNot(
          const BeamDecoration(
            variant: BeamVariant.line,
            brightness: Brightness.dark,
            colors: BeamColors.ocean,
            borderRadius: 16,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.light,
            colors: BeamColors.ocean,
            borderRadius: 16,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
            colors: BeamColors.sunset,
            borderRadius: 16,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
            colors: BeamColors.ocean,
            borderRadius: 24,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const BeamDecoration(
            variant: BeamVariant.rotate,
            brightness: Brightness.dark,
            colors: BeamColors.ocean,
            borderRadius: 16,
            timing: BeamTiming(speed: 2),
          ),
        ),
      );
    });

    test('does not interpolate between two beam decorations', () {
      const other = BeamDecoration(
        variant: BeamVariant.line,
        brightness: Brightness.dark,
      );
      // lerp falls back to the halfway snap Decoration.lerp does when
      // neither side can interpolate.
      expect(Decoration.lerp(base, other, 0.25), same(base));
      expect(Decoration.lerp(base, other, 0.75), same(other));
    });

    testWidgets('never absorbs a pointer', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 80,
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                  ),
                  // Laid over the target. A Decoration whose hitTest returns
                  // true would swallow the tap here.
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BeamDecoration(
                        variant: BeamVariant.rotate,
                        brightness: Brightness.dark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(Stack));
      expect(taps, 1);
    });

    test('shorthands fold into the value objects for diagnostics', () {
      final description = base.toDiagnosticsNode().toStringDeep();
      expect(description, contains('variant: rotate'));
      expect(description, contains('brightness: dark'));
      expect(description, contains('BeamStyle(colors:'));
      expect(description, contains('BorderRadius.circular(16.0)'));
    });
  });

  group('theme inheritance', () {
    testWidgets('takes its defaults from the BorderBeamThemeData passed in', (
      tester,
    ) async {
      const themed = BeamDecoration(
        variant: BeamVariant.rotate,
        brightness: Brightness.dark,
        theme: BorderBeamThemeData(playback: BeamPlayback(active: false)),
      );
      await tester.pumpWidget(scene(themed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(await paintedPixels(tester), 0);
    });

    testWidgets('a decoration value wins over the theme it was given', (
      tester,
    ) async {
      const themed = BeamDecoration(
        variant: BeamVariant.rotate,
        brightness: Brightness.dark,
        active: true,
        theme: BorderBeamThemeData(playback: BeamPlayback(active: false)),
      );
      await tester.pumpWidget(scene(themed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      expect(await paintedPixels(tester), greaterThan(0));
    });
  });
}
