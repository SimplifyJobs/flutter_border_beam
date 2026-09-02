import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The options ported from the reference implementations: the stock
/// pulse-outside look, the pulse-inside wash scale, the render-scale
/// magnification, and the three playback fields (offscreen pause, frozen
/// time, fade curve).
///
/// The pixel assertions are deliberately coarse — presence, absence, and the
/// ordering of totals — so they pin behaviour without pinning the look, which
/// the goldens own.
void main() {
  const beamSize = ui.Size(350, 140);

  // ─── BeamStyle.pulseOutsideStock ──────────────────────────────────────────

  group('BeamStyle.pulseOutsideStock', () {
    test('rolls the demo tuning back through the hooks that carry it', () {
      final config = _config(
        BeamVariant.pulseOutside,
        style: BeamStyle.pulseOutsideStock,
      );
      // Each of these cancels a multiplier the strategy applies: the boost
      // (×1.05) and the glow multiplier (×1.71) on all three layer opacities.
      expect(config.glowBoost * 1.05, closeTo(1, 1e-12));
      for (final factor in [
        config.strokeOpacityFactor,
        config.innerOpacityFactor,
        config.bloomOpacityFactor,
      ]) {
        expect(factor * 1.71, closeTo(1, 1e-12));
      }
      expect(config.glowBrightness, 1.3, reason: 'the untuned preset');
      expect(config.glowSaturation, 1.2);
      expect(config.pulseOutsideTuning, BeamPulseOutsideTuning.stock);
    });

    test('leaves the blur overrides free for the caller', () {
      // The stock blurs differ by brightness (3/6 core, 22.5/15 bloom), which
      // one const double cannot say — the tuning flag carries them, and the
      // hooks stay null so a caller can still override either.
      expect(BeamStyle.pulseOutsideStock.coreBlur, isNull);
      expect(BeamStyle.pulseOutsideStock.bloomBlur, isNull);
    });

    for (final brightness in ui.Brightness.values) {
      test('$brightness: paints a dimmer glow than the demo recipe', () async {
        // The behind-child pass is the whole outward glow; give it room.
        const canvas = ui.Size(750, 540);
        const origin = ui.Offset(200, 200);
        Future<_Pixels> render(BeamStyle style) => _paint(
          _config(
            BeamVariant.pulseOutside,
            style: style,
            brightness: brightness,
          ),
          size: beamSize,
          canvas: canvas,
          origin: origin,
          behind: true,
        );
        final demo = await render(const BeamStyle());
        final stock = await render(BeamStyle.pulseOutsideStock);
        final all = ui.Offset.zero & canvas;
        final stockAlpha = stock.totalAlpha(all);
        expect(stockAlpha, greaterThan(0), reason: 'it still glows');
        expect(
          stockAlpha,
          lessThan(demo.totalAlpha(all)),
          reason: 'the demo recipe multiplies every glow layer by 1.71',
        );
      });

      test('$brightness: the tuning flag alone moves the geometry', () async {
        // Same opacities on both sides, so only the insets, the blurs, and
        // the size unit can account for the difference.
        Future<_Pixels> render(BeamPulseOutsideTuning tuning) => _paint(
          _config(
            BeamVariant.pulseOutside,
            style: BeamStyle(pulseOutsideTuning: tuning),
            brightness: brightness,
          ),
          size: beamSize,
          canvas: const ui.Size(750, 540),
          origin: const ui.Offset(200, 200),
          behind: true,
        );
        final demo = await render(BeamPulseOutsideTuning.demo);
        final stock = await render(BeamPulseOutsideTuning.stock);
        expect(stock.bytes, isNot(demo.bytes));
      });
    }

    test('is a value, and layering keeps the stock geometry', () {
      expect(BeamStyle.pulseOutsideStock, BeamStyle.pulseOutsideStock);
      final louder = BeamStyle.pulseOutsideStock.copyWith(glowBoost: 1.4);
      expect(louder.glowBoost, 1.4);
      expect(louder.pulseOutsideTuning, BeamPulseOutsideTuning.stock);
      expect(
        louder.strokeOpacityFactor,
        BeamStyle.pulseOutsideStock.strokeOpacityFactor,
      );
    });
  });

  // ─── BeamStyle.innerSizeScale ─────────────────────────────────────────────

  group('innerSizeScale', () {
    test('1 paints exactly what leaving it unset paints', () async {
      final bare = await _paint(_config(BeamVariant.pulseInside));
      final one = await _paint(
        _config(
          BeamVariant.pulseInside,
          style: const BeamStyle(innerSizeScale: 1),
        ),
      );
      expect(one.bytes, bare.bytes);
    });

    test('below 1 pulls the inner wash tighter to the border', () async {
      final rect = ui.Offset.zero & beamSize;
      // The inner wash is the only layer that moves, so read it alone.
      Future<double> innerAlpha(double scale) async {
        final pixels = await _paint(
          _config(
            BeamVariant.pulseInside,
            style: BeamStyle(
              innerSizeScale: scale,
              // Silence the ring and the bloom: their geometry is fixed.
              strokeOpacityFactor: 0,
              bloomOpacityFactor: 0,
            ),
          ),
        );
        return pixels.totalAlpha(rect);
      }

      final full = await innerAlpha(1);
      final tight = await innerAlpha(0.6);
      expect(tight, greaterThan(0), reason: 'the wash is still painted');
      expect(tight, lessThan(full * 0.9));
    });

    test('only the pulse-inside variant reads it', () async {
      for (final variant in BeamVariant.values) {
        if (variant == BeamVariant.pulseInside) continue;
        final bare = await _paint(_config(variant));
        final scaled = await _paint(
          _config(variant, style: const BeamStyle(innerSizeScale: 0.4)),
        );
        expect(scaled.bytes, bare.bytes, reason: '$variant');
      }
    });
  });

  // ─── BeamStyle.renderScale ────────────────────────────────────────────────

  group('renderScale', () {
    test('resolves clamped to 0.25-1', () {
      double resolved(double value) => _config(
        BeamVariant.rotate,
        style: BeamStyle(renderScale: value),
      ).renderScale;
      expect(resolved(0.1), 0.25);
      expect(resolved(4), 1);
      expect(resolved(0.5), 0.5);
      expect(_config(BeamVariant.rotate).renderScale, 1);
    });

    test('scaledBy moves the box-relative lengths and nothing else', () {
      final base = _config(
        BeamVariant.rotate,
        shape: const BeamShape(
          radius: BorderRadius.all(Radius.circular(24)),
          borderWidth: 2,
          ringOffset: 6,
        ),
      );
      final half = base.scaledBy(0.5);
      expect(half.borderRadius, BorderRadius.circular(12));
      expect(half.borderWidth, 1);
      expect(half.ringOffset, 3);
      expect(half.renderScale, 1, reason: 'the copy has spent the scale');
      expect(half.palette, base.palette);
      expect(half.cycleSeconds, base.cycleSeconds);
    });

    testWidgets('1 paints exactly what leaving it unset paints', (
      tester,
    ) async {
      final bare = await _paintThroughPainter(
        tester,
        _config(BeamVariant.rotate),
      );
      final one = await _paintThroughPainter(
        tester,
        _config(BeamVariant.rotate, style: const BeamStyle(renderScale: 1)),
      );
      expect(one.bytes, bare.bytes);
    });

    testWidgets('below 1 repaints the same box differently', (tester) async {
      const large = ui.Size(700, 280);
      final full = await _paintThroughPainter(
        tester,
        _config(BeamVariant.rotate),
        size: large,
      );
      final scaled = await _paintThroughPainter(
        tester,
        _config(BeamVariant.rotate, style: const BeamStyle(renderScale: 0.5)),
        size: large,
      );
      expect(scaled.bytes, isNot(full.bytes));
      expect(scaled.totalAlpha(ui.Offset.zero & large), greaterThan(0));
    });

    testWidgets('the magnified beam still lands on the box bounds', (
      tester,
    ) async {
      // The transform is the part that can silently go wrong: scaling about
      // anything but the origin slides the whole beam off its box. The
      // pulse-inside wash hugs all four edges, so a shifted beam loses one.
      const large = ui.Size(700, 280);
      final pixels = await _paintThroughPainter(
        tester,
        _config(
          BeamVariant.pulseInside,
          style: const BeamStyle(renderScale: 0.5),
        ),
        size: large,
      );
      const probe = 8.0;
      final edges = {
        'top': ui.Rect.fromLTWH(0, 0, large.width, probe),
        'bottom': ui.Rect.fromLTWH(0, large.height - probe, large.width, probe),
        'left': ui.Rect.fromLTWH(0, 0, probe, large.height),
        'right': ui.Rect.fromLTWH(large.width - probe, 0, probe, large.height),
      };
      for (final MapEntry(key: name, value: band) in edges.entries) {
        expect(pixels.totalAlpha(band), greaterThan(0), reason: name);
      }
    });
  });

  // ─── BeamPlayback.debugFrozenAt ───────────────────────────────────────────

  group('debugFrozenAt', () {
    testWidgets('never starts the clock', (tester) async {
      await tester.pumpWidget(
        _app(
          const BorderBeam.rotate(
            playback: BeamPlayback(debugFrozenAt: Duration(seconds: 2)),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final painter = _painterOf(tester);
      expect(painter.frozenAt, const Duration(seconds: 2));
      expect(painter.clock.isRunning, isFalse);
      expect(painter.clock.elapsedSeconds, 0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('two frames a wall-clock apart paint the same pixels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BorderBeam.rotate(
            playback: BeamPlayback(debugFrozenAt: Duration(milliseconds: 1300)),
            child: SizedBox.expand(),
          ),
        ),
      );
      final first = await _recordIn(tester, _painterOf(tester), beamSize);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 7));
      final later = await _recordIn(tester, _painterOf(tester), beamSize);
      expect(later.bytes, first.bytes);
      expect(first.totalAlpha(ui.Offset.zero & beamSize), greaterThan(0));
    });

    testWidgets('paints the frame the timeline holds at that instant', (
      tester,
    ) async {
      const at = Duration(milliseconds: 1300);
      final config = _config(BeamVariant.rotate);
      late _Pixels expected;
      late _Pixels actual;
      await tester.runAsync(() async {
        expected = await _paint(config, t: 1.3);
        final clock = BeamClock(createTicker: Ticker.new);
        final painter = BeamPainter(
          clock: clock,
          config: config,
          resolver: BeamPhaseResolver(config),
          strategy: strategyFor(config.variant),
          behind: false,
          staticMode: false,
          frozenAt: at,
        );
        actual = await _record(painter, beamSize);
        clock.dispose();
      });
      expect(actual.bytes, expected.bytes);
    });
  });

  // ─── BeamPlayback.fadeCurve ───────────────────────────────────────────────

  group('fadeCurve', () {
    test('cssEase is the web ease', () {
      expect(BeamPlayback.cssEase, const Cubic(0.25, 0.1, 0.25, 1));
    });

    testWidgets('a curve replaces the spring on the fade-in', (tester) async {
      final clock = BeamClock(
        createTicker: tester.createTicker,
        fadeCurve: BeamPlayback.cssEase,
      )..activate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        clock.fadeOpacity,
        closeTo(BeamPlayback.cssEase.transform(0.5), 1e-9),
      );
      clock.dispose();
    });

    testWidgets('and on the fade-out', (tester) async {
      final clock = BeamClock(
        createTicker: tester.createTicker,
        fadeCurve: BeamPlayback.cssEase,
      )..activate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(clock.fadeOpacity, 1);
      clock.deactivate();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        clock.fadeOpacity,
        closeTo(1 - BeamPlayback.cssEase.transform(0.5), 1e-9),
      );
      clock.dispose();
    });

    testWidgets('the default fade is the spring, not the ease', (tester) async {
      final clock = BeamClock(createTicker: tester.createTicker)..activate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final spring = clock.fadeOpacity;
      clock.dispose();
      expect(spring, isNot(closeTo(BeamPlayback.cssEase.transform(0.5), 1e-3)));
      expect(spring, greaterThan(0));
      expect(spring, lessThanOrEqualTo(1));
    });

    testWidgets('the widget hands its curve to the clock', (tester) async {
      await tester.pumpWidget(
        _app(
          const BorderBeam.rotate(
            playback: BeamPlayback(fadeCurve: BeamPlayback.cssEase),
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        _painterOf(tester).clock.fadeOpacity,
        closeTo(BeamPlayback.cssEase.transform(0.5), 1e-9),
      );
    });
  });

  // ─── BeamPlayback.pauseWhenOffscreen ──────────────────────────────────────

  group('pauseWhenOffscreen', () {
    // cacheExtent keeps rows built well past the 256px margin, so there is
    // something offscreen left to pause. The double form is the one every
    // supported Flutter accepts (ScrollCacheExtent arrives after 3.35).
    Widget list({bool? pause}) => _app(
      ListView.builder(
        // ignore: deprecated_member_use
        cacheExtent: 4000,
        itemCount: 12,
        itemBuilder: (context, index) => SizedBox(
          height: 200,
          child: BorderBeam.rotate(
            key: ValueKey(index),
            playback: BeamPlayback(pauseWhenOffscreen: pause),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      size: const Size(400, 600),
    );

    testWidgets('offscreen rows stop ticking, and start again on return', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      await tester.pump();
      expect(_clockAt(tester, 0).isRunning, isTrue, reason: 'in view');
      expect(_clockAt(tester, 1).isRunning, isTrue, reason: 'in view');
      expect(
        _clockAt(tester, 2).isRunning,
        isTrue,
        reason: 'inside the 256px margin',
      );
      expect(_clockAt(tester, 6).isRunning, isFalse, reason: 'far below');
      expect(_clockAt(tester, 11).isRunning, isFalse);

      // A paused beam keeps its play state and its timeline.
      final resting = _clockAt(tester, 6);
      expect(resting.isVisible, isTrue);
      final held = resting.elapsedSeconds;

      // Not pumpAndSettle: a running beam schedules frames forever, so the
      // tree never settles. Two frames are enough — one to land the scroll,
      // one to run the post-frame visibility check.
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      await tester.pump();

      expect(_clockAt(tester, 6).isRunning, isTrue, reason: 'scrolled in');
      expect(
        _clockAt(tester, 6).elapsedSeconds,
        greaterThanOrEqualTo(held),
        reason: 'it resumes rather than restarting',
      );
      expect(_clockAt(tester, 0).isRunning, isFalse, reason: 'now far above');
    });

    testWidgets('false keeps every row running', (tester) async {
      await tester.pumpWidget(list(pause: false));
      await tester.pump();
      for (final index in [0, 6, 11]) {
        expect(_clockAt(tester, index).isRunning, isTrue, reason: '$index');
      }
    });

    testWidgets('a beam outside any scrollable is never paused', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const BorderBeam.rotate(child: SizedBox.expand())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painterOf(tester).clock.isRunning, isTrue);
    });

    testWidgets('an offscreen beam disposes without leaking its ticker', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      await tester.pump();
      expect(_clockAt(tester, 11).isRunning, isFalse);
      await tester.pumpWidget(_app(const SizedBox.expand()));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}

// ─── Harness ────────────────────────────────────────────────────────────────

Widget _app(Widget child, {Size size = const Size(350, 140)}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Center(
    child: SizedBox(width: size.width, height: size.height, child: child),
  ),
);

BeamPainter _painterOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.foregroundPainter)
    .whereType<BeamPainter>()
    .first;

/// The clock of the beam keyed [index].
///
/// `skipOffstage: false`: a row parked in the scrollable's cache extent is
/// laid out but never painted, and it is exactly the row this feature is
/// about — the default finders would skip it.
BeamClock _clockAt(WidgetTester tester, int index) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byKey(ValueKey(index), skipOffstage: false),
        matching: find.byType(CustomPaint, skipOffstage: false),
      ),
    )
    .map((paint) => paint.foregroundPainter)
    .whereType<BeamPainter>()
    .first
    .clock;

BeamConfig _config(
  BeamVariant variant, {
  BeamStyle style = const BeamStyle(),
  BeamShape shape = const BeamShape(),
  ui.Brightness brightness = ui.Brightness.dark,
}) => BeamConfig.resolve(
  variant: variant,
  palette: (style.colors ?? BeamColors.colorful).resolve(),
  brightness: brightness,
  style: style,
  shape: shape,
);

/// Renders one strategy frame of [config] and returns its pixels.
Future<_Pixels> _paint(
  BeamConfig config, {
  double t = 0.9,
  ui.Size size = const ui.Size(350, 140),
  ui.Size? canvas,
  ui.Offset origin = ui.Offset.zero,
  bool behind = false,
}) async {
  final target = canvas ?? size;
  final recorder = ui.PictureRecorder();
  final c = ui.Canvas(recorder);
  c.translate(origin.dx, origin.dy);
  final frame = BeamPhaseResolver(config).sample(t, 1);
  final strategy = strategyFor(config.variant);
  if (behind) {
    strategy.paintBehind(c, size, config, frame);
  } else {
    strategy.paintAbove(c, size, config, frame);
  }
  return _rasterize(recorder, target);
}

/// Renders one frame through a [BeamPainter], which is where `renderScale`
/// lives — a strategy never sees it.
Future<_Pixels> _paintThroughPainter(
  WidgetTester tester,
  BeamConfig config, {
  ui.Size size = const ui.Size(350, 140),
  Duration at = const Duration(milliseconds: 900),
}) async {
  late _Pixels pixels;
  await tester.runAsync(() async {
    final clock = BeamClock(createTicker: Ticker.new);
    final painter = BeamPainter(
      clock: clock,
      config: config,
      resolver: BeamPhaseResolver(config),
      strategy: strategyFor(config.variant),
      behind: false,
      staticMode: false,
      frozenAt: at,
    );
    pixels = await _record(painter, size);
    clock.dispose();
  });
  return pixels;
}

/// [_record], run on the real event loop: `toImage` never completes under a
/// widget test's fake async.
Future<_Pixels> _recordIn(
  WidgetTester tester,
  BeamPainter painter,
  ui.Size size,
) async {
  late _Pixels pixels;
  await tester.runAsync(() async {
    pixels = await _record(painter, size);
  });
  return pixels;
}

Future<_Pixels> _record(BeamPainter painter, ui.Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), size);
  return _rasterize(recorder, size);
}

Future<_Pixels> _rasterize(ui.PictureRecorder recorder, ui.Size size) async {
  final image = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return _Pixels(bytes!.buffer.asUint8List(), image.width, image.height);
}

/// The alpha channel of a rendered frame.
class _Pixels {
  _Pixels(this.bytes, this.width, this.height);

  final List<int> bytes;
  final int width;
  final int height;

  double _alphaAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    return bytes[(y * width + x) * 4 + 3] / 255;
  }

  /// Total alpha inside [rect], in whole-pixel units.
  double totalAlpha(ui.Rect rect) {
    var sum = 0.0;
    for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
      for (var x = rect.left.round(); x < rect.right.round(); x++) {
        sum += _alphaAt(x, y);
      }
    }
    return sum;
  }
}
