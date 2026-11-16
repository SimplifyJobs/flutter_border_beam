import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';

/// [BeamDecoration] runs the beam engine from a [BoxPainter] instead of a
/// widget: it owns a raw `Ticker`, repaints its box through `onChanged`, and
/// must give that ticker (and any scheduling timer) back when the render
/// object drops it.
///
/// Pending timers and running tickers that outlive the tree also fail a test
/// through the binding's own post-test invariants, so every test here doubles
/// as a leak check.
void main() {
  // Without the shader program a beam paints nothing; load it up front so
  // the pixel assertions do not depend on asset-load timing.
  setUpAll(() async {
    await BorderBeam.precache();
  });

  const boundaryKey = ValueKey<String>('boundary');
  const frozen = BeamPlayback(debugFrozenAt: Duration(milliseconds: 1300));

  Widget scene({Decoration? foreground, Decoration? background}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Center(
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: 240,
          height: 120,
          foregroundDecoration: foreground,
          decoration: background,
        ),
      ),
    ),
  );

  // The boundary's RGBA bytes. Nothing else in the scene paints, so any
  // non-transparent pixel is the beam.
  Future<Uint8List> capture(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    late Uint8List rgba;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      rgba = bytes!.buffer.asUint8List();
    });
    return rgba;
  }

  int litPixels(Uint8List rgba) {
    var lit = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 0) lit++;
    }
    return lit;
  }

  Future<Uint8List> frame(
    WidgetTester tester,
    BeamDecoration decoration,
  ) async {
    await tester.pumpWidget(scene(foreground: decoration));
    await tester.pump();
    return capture(tester);
  }

  // The properties the decoration reports, with the shorthands and theme
  // already folded in — the values its painter resolves.
  T resolved<T>(BeamDecoration decoration, String name) =>
      decoration
              .toDiagnosticsNode()
              .getProperties()
              .singleWhere((p) => p.name == name)
              .value
          as T;

  group('painting', () {
    testWidgets('paints over the box in either decoration slot', (
      tester,
    ) async {
      const beam = BeamDecoration(
        brightness: Brightness.dark,
        borderRadius: 16,
      );
      for (final foreground in [true, false]) {
        await tester.pumpWidget(
          foreground ? scene(foreground: beam) : scene(background: beam),
        );
        // The first tick after Ticker.start() reports elapsed 0.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1300));

        expect(
          litPixels(await capture(tester)),
          greaterThan(0),
          reason: foreground ? 'foregroundDecoration' : 'decoration',
        );
        await tester.pumpWidget(const SizedBox());
        expect(tester.binding.transientCallbackCount, 0);
      }
    });

    testWidgets('paints every effect, in both brightnesses', (tester) async {
      for (final effect in BeamEffect.values) {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            scene(
              foreground: BeamDecoration(
                effect: effect,
                brightness: brightness,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1300));

          final reason = '$effect on ${brightness.name}';
          expect(tester.takeException(), isNull, reason: reason);
          expect(
            litPixels(await capture(tester)),
            greaterThan(0),
            reason: reason,
          );
          await tester.pumpWidget(const SizedBox());
          expect(tester.binding.transientCallbackCount, 0, reason: reason);
        }
      }
    });

    testWidgets('debugFrozenAt paints one fixed frame and never ticks', (
      tester,
    ) async {
      final first = await frame(
        tester,
        const BeamDecoration(brightness: Brightness.dark, playback: frozen),
      );
      expect(litPixels(first), greaterThan(0));
      expect(tester.binding.transientCallbackCount, 0);

      // Let time pass, then force the painter to paint again.
      await tester.pump(const Duration(milliseconds: 700));
      tester
          .renderObject<RenderDecoratedBox>(find.byType(DecoratedBox))
          .markNeedsPaint();
      await tester.pump();
      final again = await capture(tester);
      expect(listEquals(first, again), isTrue, reason: 'same instant twice');
      expect(tester.binding.transientCallbackCount, 0);

      // A different instant is a different frame: the freeze picks the time.
      final later = await frame(
        tester,
        const BeamDecoration(
          brightness: Brightness.dark,
          playback: BeamPlayback(debugFrozenAt: Duration(milliseconds: 2000)),
        ),
      );
      expect(listEquals(first, later), isFalse);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('autoPlay false or active false: no ticker, no pixels', (
      tester,
    ) async {
      const idle = [
        BeamDecoration(
          brightness: Brightness.dark,
          playback: BeamPlayback(autoPlay: false),
        ),
        BeamDecoration(brightness: Brightness.dark, active: false),
        BeamDecoration(
          brightness: Brightness.dark,
          playback: BeamPlayback(active: false),
        ),
      ];
      for (final decoration in idle) {
        await tester.pumpWidget(scene(foreground: decoration));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1300));

        expect(tester.binding.transientCallbackCount, 0);
        expect(litPixels(await capture(tester)), 0);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('scheduling', () {
    testWidgets('startAfter holds the start back until it elapses', (
      tester,
    ) async {
      await tester.pumpWidget(
        scene(
          foreground: const BeamDecoration(
            brightness: Brightness.dark,
            playback: BeamPlayback(startAfter: Duration(seconds: 1)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, 0);
      expect(litPixels(await capture(tester)), 0);

      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(litPixels(await capture(tester)), greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('duration ends the beam and stops its ticker', (tester) async {
      await tester.pumpWidget(
        scene(
          foreground: const BeamDecoration(
            brightness: Brightness.dark,
            playback: BeamPlayback(duration: Duration(seconds: 1)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(litPixels(await capture(tester)), greaterThan(0));

      // Past the duration, and past the fade-out it starts
      // (BeamClock.fadeOutSeconds), with room to spare.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.binding.transientCallbackCount, 0);
      expect(litPixels(await capture(tester)), 0);
    });

    testWidgets('repeat ends the beam after its cycles', (tester) async {
      await tester.pumpWidget(
        scene(
          foreground: const BeamDecoration(
            brightness: Brightness.dark,
            timing: BeamTiming(cycle: Duration(seconds: 1)),
            playback: BeamPlayback(repeat: BeamRepeat.once()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(litPixels(await capture(tester)), greaterThan(0));

      // Past the one cycle, and past the fade-out it starts.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.binding.transientCallbackCount, 0);
      expect(litPixels(await capture(tester)), 0);
    });

    testWidgets('repeat runs out even while there is nothing to paint', (
      tester,
    ) async {
      // The same decoration throughout, so the box keeps one painter: it
      // ticks at zero size, then is given room once its cycle is spent.
      const beam = BeamDecoration(
        brightness: Brightness.dark,
        timing: BeamTiming(cycle: Duration(seconds: 1)),
        playback: BeamPlayback(repeat: BeamRepeat.once()),
      );
      Widget sized(double width, double height) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 240,
              height: 120,
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: width,
                  height: height,
                  foregroundDecoration: beam,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(sized(0, 0));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      // Past the one cycle, and past the fade-out it starts.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'the budget ran out with no frame painted',
      );

      await tester.pumpWidget(sized(240, 120));
      await tester.pump();
      expect(litPixels(await capture(tester)), 0, reason: 'no spent beam');
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('removal cancels a pending startAfter timer', (tester) async {
      await tester.pumpWidget(
        scene(
          foreground: const BeamDecoration(
            brightness: Brightness.dark,
            playback: BeamPlayback(startAfter: Duration(seconds: 5)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
      // Ending here, before the 5s mark: a timer the painter failed to
      // cancel fails the binding's no-pending-timers invariant.
    });

    testWidgets('removal cancels a running duration timer', (tester) async {
      await tester.pumpWidget(
        scene(
          foreground: const BeamDecoration(
            brightness: Brightness.dark,
            playback: BeamPlayback(duration: Duration(seconds: 5)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('ticking', () {
    // A painter from [decoration] and the way to dispose it. Each test
    // disposes its painter itself — flutter_test checks for live tickers
    // before tear-downs run — and the tear-down only catches one that a
    // failed expectation left behind.
    VoidCallback paintWith(BeamDecoration decoration, VoidCallback onChanged) {
      final painter = decoration.createBoxPainter(onChanged);
      var disposed = false;
      void dispose() {
        if (disposed) return;
        disposed = true;
        painter.dispose();
      }

      addTearDown(dispose);
      return dispose;
    }

    testWidgets('calls onChanged on every clock tick', (tester) async {
      var changes = 0;
      final disposePainter = paintWith(
        const BeamDecoration(brightness: Brightness.dark),
        () => changes++,
      );

      await tester.pump();
      final afterFirst = changes;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(changes, greaterThan(afterFirst));

      disposePainter();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('disposing the painter mid-fade leaves no ticker', (
      tester,
    ) async {
      final disposePainter = paintWith(
        const BeamDecoration(
          effect: BeamEffect.pulse(),
          brightness: Brightness.light,
        ),
        () {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      disposePainter();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('replacing the decoration disposes the old ticker', (
      tester,
    ) async {
      await tester.pumpWidget(
        scene(foreground: const BeamDecoration(brightness: Brightness.dark)),
      );
      await tester.pump();
      final running = tester.binding.transientCallbackCount;
      expect(running, greaterThan(0));

      for (final effect in [
        const BeamEffect.line(),
        const BeamEffect.pulse(),
        const BeamEffect.rotate(comet: true),
      ]) {
        await tester.pumpWidget(
          scene(
            foreground: BeamDecoration(
              effect: effect,
              brightness: Brightness.dark,
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.binding.transientCallbackCount,
          running,
          reason: '$effect',
        );
      }
      await tester.pump(const Duration(milliseconds: 1300));
      expect(litPixels(await capture(tester)), greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('value semantics', () {
    const base = BeamDecoration(
      effect: BeamEffect.rotate(),
      brightness: Brightness.dark,
      colors: BeamColors.ocean,
      borderRadius: 16,
    );

    test('equal field-for-field', () {
      // Built at run time: an equal const would be the same canonical
      // instance, and `==` would never get past `identical`.
      final same = BeamDecoration(
        effect: const BeamEffect.rotate(),
        brightness: Brightness.dark,
        colors: BeamColors.ocean,
        borderRadius: double.parse('16'),
      );
      expect(identical(base, same), isFalse);
      expect(base, equals(same));
      expect(base.hashCode, same.hashCode);
    });

    test('each field participates', () {
      const variants = <String, BeamDecoration>{
        'effect': BeamDecoration(
          effect: BeamEffect.line(),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
        ),
        'effect (unset)': BeamDecoration(
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
        ),
        'effect parameters': BeamDecoration(
          effect: BeamEffect.rotate(count: 2),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
        ),
        'brightness': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.light,
          colors: BeamColors.ocean,
          borderRadius: 16,
        ),
        'colors': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          colors: BeamColors.sunset,
          borderRadius: 16,
        ),
        'borderRadius': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 24,
        ),
        'active': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
          active: false,
        ),
        'theme': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
          theme: BorderBeamThemeData(effect: BeamEffect.pulse()),
        ),
        'style': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
          style: BeamStyle(strength: 0.5),
        ),
        'shape': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
          shape: BeamShape(borderWidth: 2),
        ),
        'timing': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
          timing: BeamTiming(speed: 2),
        ),
        'playback': BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          colors: BeamColors.ocean,
          borderRadius: 16,
          playback: BeamPlayback(autoPlay: false),
        ),
      };
      for (final MapEntry(:key, :value) in variants.entries) {
        expect(base, isNot(equals(value)), reason: key);
        expect(base.hashCode, isNot(value.hashCode), reason: key);
      }
    });

    test('does not interpolate between two beam decorations', () {
      const other = BeamDecoration(
        effect: BeamEffect.line(),
        brightness: Brightness.dark,
      );
      // Decoration.lerp falls back to a halfway snap when neither side can
      // interpolate.
      expect(Decoration.lerp(base, other, 0.25), same(base));
      expect(Decoration.lerp(base, other, 0.75), same(other));
    });

    test('hitTest is always false', () {
      const size = Size(200, 80);
      for (final position in const [
        Offset(100, 40),
        Offset.zero,
        Offset(199, 79),
        Offset(-10, 300),
      ]) {
        expect(base.hitTest(size, position), isFalse, reason: '$position');
      }
    });

    testWidgets('taps reach the widget beneath', (tester) async {
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
                  // Laid over the target. A decoration whose hitTest
                  // returned true would swallow the tap here.
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BeamDecoration(brightness: Brightness.dark),
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

    test('describes its resolved values for diagnostics', () {
      final description = base.toDiagnosticsNode().toStringDeep();
      expect(description, contains('effect: BeamEffect.rotate('));
      expect(description, contains('brightness: dark'));
      expect(description, contains('BeamStyle(colors:'));
      expect(description, contains('BorderRadius.circular(16.0)'));
    });
  });

  group('theme slot', () {
    test('value objects merge under the decoration\'s own', () {
      const theme = BorderBeamThemeData(
        style: BeamStyle(colors: BeamColors.sunset, strength: 0.5, glow: 0.8),
        shape: BeamShape(borderWidth: 2, superellipse: true),
        timing: BeamTiming(cycle: Duration(seconds: 3), speed: 2),
        playback: BeamPlayback(
          autoPlay: false,
          startAfter: Duration(seconds: 2),
        ),
      );
      const decoration = BeamDecoration(
        brightness: Brightness.dark,
        theme: theme,
        colors: BeamColors.ocean,
        style: BeamStyle(colors: BeamColors.candy, glow: 0.2),
        borderRadius: 24,
        shape: BeamShape(borderWidth: 3),
        timing: BeamTiming(speed: 4),
        active: false,
        playback: BeamPlayback(autoPlay: true),
      );

      // Own fields win (the shorthands over their value objects), every
      // field left null falls through to the theme.
      expect(
        resolved<BeamStyle>(decoration, 'style'),
        const BeamStyle(colors: BeamColors.ocean, strength: 0.5, glow: 0.2),
      );
      expect(
        resolved<BeamShape>(decoration, 'shape'),
        const BeamShape.all(24, borderWidth: 3, superellipse: true),
      );
      expect(
        resolved<BeamTiming>(decoration, 'timing'),
        const BeamTiming(cycle: Duration(seconds: 3), speed: 4),
      );
      expect(
        resolved<BeamPlayback>(decoration, 'playback'),
        const BeamPlayback(
          active: false,
          autoPlay: true,
          startAfter: Duration(seconds: 2),
        ),
      );
    });

    test('the theme\'s effect is inherited; the decoration\'s own wins', () {
      const theme = BorderBeamThemeData(effect: BeamEffect.pulse());
      expect(
        resolved<BeamEffect>(
          const BeamDecoration(brightness: Brightness.dark, theme: theme),
          'effect',
        ),
        const BeamEffect.pulse(),
      );
      expect(
        resolved<BeamEffect>(
          const BeamDecoration(
            effect: BeamEffect.line(edge: BeamEdge.top),
            brightness: Brightness.dark,
            theme: theme,
          ),
          'effect',
        ),
        const BeamEffect.line(edge: BeamEdge.top),
      );
      expect(
        resolved<BeamEffect>(
          const BeamDecoration(brightness: Brightness.dark),
          'effect',
        ),
        const BeamEffect.rotate(),
      );
    });

    testWidgets('the painter draws the effect the theme resolves to', (
      tester,
    ) async {
      const lineTheme = BorderBeamThemeData(effect: BeamEffect.line());
      final inherited = await frame(
        tester,
        const BeamDecoration(
          brightness: Brightness.dark,
          theme: lineTheme,
          playback: frozen,
        ),
      );
      final explicit = await frame(
        tester,
        const BeamDecoration(
          effect: BeamEffect.line(),
          brightness: Brightness.dark,
          playback: frozen,
        ),
      );
      final rotate = await frame(
        tester,
        const BeamDecoration(brightness: Brightness.dark, playback: frozen),
      );
      final overridden = await frame(
        tester,
        const BeamDecoration(
          effect: BeamEffect.rotate(),
          brightness: Brightness.dark,
          theme: lineTheme,
          playback: frozen,
        ),
      );

      expect(litPixels(inherited), greaterThan(0));
      expect(listEquals(inherited, explicit), isTrue);
      expect(listEquals(overridden, rotate), isTrue);
      expect(listEquals(inherited, rotate), isFalse);
    });

    testWidgets('theme playback is inherited; the own active wins', (
      tester,
    ) async {
      const dormant = BorderBeamThemeData(
        playback: BeamPlayback(active: false),
      );
      for (final (active, lit) in [(null, false), (true, true)]) {
        await tester.pumpWidget(
          scene(
            foreground: BeamDecoration(
              brightness: Brightness.dark,
              active: active,
              theme: dormant,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1300));

        final pixels = litPixels(await capture(tester));
        expect(pixels, lit ? greaterThan(0) : 0, reason: 'active: $active');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('brightness', () {
    testWidgets('style.theme overrides the ambient brightness', (tester) async {
      final dark = await frame(
        tester,
        const BeamDecoration(brightness: Brightness.dark, playback: frozen),
      );
      final light = await frame(
        tester,
        const BeamDecoration(brightness: Brightness.light, playback: frozen),
      );
      final forcedLight = await frame(
        tester,
        const BeamDecoration(
          brightness: Brightness.dark,
          style: BeamStyle(theme: BeamTheme.light),
          playback: frozen,
        ),
      );
      final forcedDark = await frame(
        tester,
        const BeamDecoration(
          brightness: Brightness.light,
          style: BeamStyle(theme: BeamTheme.dark),
          playback: frozen,
        ),
      );
      final auto = await frame(
        tester,
        const BeamDecoration(
          brightness: Brightness.light,
          style: BeamStyle(theme: BeamTheme.auto),
          playback: frozen,
        ),
      );

      // The two surfaces really do render differently...
      expect(listEquals(dark, light), isFalse);
      // ...and an explicit theme picks one regardless of the ambient value,
      // while auto follows it.
      expect(listEquals(forcedLight, light), isTrue);
      expect(listEquals(forcedDark, dark), isTrue);
      expect(listEquals(auto, light), isTrue);
    });
  });
}
