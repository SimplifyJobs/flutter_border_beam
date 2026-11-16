import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/render/beam_renderer.dart';

import 'render_utils.dart';

/// Degenerate geometry and out-of-range parameters: nothing throws, nothing
/// the shader is handed is non-finite, and a beam at zero strength paints no
/// pixel at all.
void main() {
  setUpAll(BorderBeam.precache);

  final boxes = <String, Size>{
    'zero': Size.zero,
    '1px': const Size(1, 1),
    '2px': const Size(2, 2),
    'vertical sliver': const Size(1, 120),
    'horizontal sliver': const Size(240, 1),
    'thin strip': const Size(300, 3),
    'tiny square': const Size(6, 6),
    'huge': const Size(4000, 3000),
  };

  // Mid-sweep, deep into a gap-carrying period, and many cycles in.
  const instants = [0.7, 1.3, 2.2, 61.7];

  /// Paints [effect] at every instant, in both brightnesses, at each of
  /// [sizes], checking every frame that draws. Returns how many frames at
  /// [cardSize] drew, so a case that should light the card can require it —
  /// a renderer that bailed out on every frame would otherwise pass.
  int paintEverywhere(
    BeamEffect effect,
    String label, {
    BeamStyle style = const BeamStyle(),
    BeamShape shape = const BeamShape(),
    BeamTiming timing = const BeamTiming(),
    Iterable<Size>? sizes,
  }) {
    final renderer = BeamRenderer();
    addTearDown(renderer.dispose);
    var paintedCards = 0;
    for (final brightness in Brightness.values) {
      final config = configFor(
        effect,
        brightness: brightness,
        style: style,
        shape: shape,
        timing: timing,
      );
      for (final size in sizes ?? [cardSize]) {
        for (final t in instants) {
          final canvas = recordFrame(
            renderer,
            config,
            phasesAt(config, t),
            size: size,
          );
          expect(canvas.draws.length, lessThanOrEqualTo(1));
          if (canvas.draws.isEmpty) continue;
          if (size == cardSize) paintedCards++;
          expectSaneFrame(
            renderer.debugFrame,
            '${effect.name}: $label, $size at ${t}s',
            drawBounds: canvas.drawBounds.single,
          );
        }
      }
    }
    return paintedCards;
  }

  for (final MapEntry(key: name, value: effect) in effectsByName.entries) {
    group(name, () {
      test('degenerate boxes', () {
        paintEverywhere(effect, 'boxes', sizes: boxes.values);
        paintEverywhere(
          effect,
          'stadium boxes',
          shape: const BeamShape.stadium(),
          sizes: boxes.values,
        );
        paintEverywhere(
          effect,
          'superellipse boxes',
          shape: const BeamShape.all(30, superellipse: true),
          sizes: boxes.values,
        );
      });

      test('a radius past half the short side', () {
        expect(
          paintEverywhere(
            effect,
            'radius 500',
            shape: const BeamShape.all(500),
          ),
          greaterThan(0),
        );
        paintEverywhere(
          effect,
          'per-corner overflow',
          shape: const BeamShape(
            radius: BorderRadius.only(
              topLeft: Radius.circular(300),
              topRight: Radius.circular(300),
              bottomLeft: Radius.elliptical(400, 10),
            ),
          ),
        );
      });

      test('border widths from zero to wider than the box', () {
        for (final width in [0.0, 0.25, 70.0, 500.0]) {
          paintEverywhere(
            effect,
            'borderWidth $width',
            shape: BeamShape(borderWidth: width),
            sizes: [cardSize, const Size(4, 4)],
          );
        }
      });

      test('ring offsets that grow or collapse the outline', () {
        for (final offset in [-69.0, -70.0, -500.0, 40.0]) {
          final painted = paintEverywhere(
            effect,
            'ringOffset $offset',
            shape: BeamShape(ringOffset: offset),
          );
          if (offset > 0) expect(painted, greaterThan(0), reason: '$offset');
        }
      });

      test('segments, dashes, and feathers at their extremes', () {
        final segments = [
          const BeamSegment(
            start: BeamAnchor.fraction(0.3),
            end: BeamAnchor.fraction(0.3),
          ),
          const BeamSegment(
            start: BeamAnchor.fraction(0.3),
            end: BeamAnchor.fraction(0.3001),
            feather: 0,
          ),
          const BeamSegment(
            start: BeamAnchor.fraction(-2.25),
            end: BeamAnchor.fraction(7.5),
            feather: 1e6,
          ),
          BeamSegment.bottomEdge,
        ];
        for (final segment in segments) {
          paintEverywhere(
            effect,
            '$segment',
            shape: BeamShape(segment: segment),
            sizes: [cardSize, const Size(1, 1)],
          );
        }
        for (final dashes in [1, 2, 1000]) {
          expect(
            paintEverywhere(
              effect,
              'dashes $dashes',
              shape: BeamShape(dashes: dashes),
            ),
            greaterThan(0),
            reason: 'dashes $dashes',
          );
        }
      });

      test('style and timing at their extremes', () {
        for (final glow in [0.0, 25.0]) {
          expect(
            paintEverywhere(effect, 'glow $glow', style: BeamStyle(glow: glow)),
            greaterThan(0),
            reason: 'glow $glow',
          );
        }
        for (final strength in [-1.0, 1e-6, 7.0]) {
          final painted = paintEverywhere(
            effect,
            'strength $strength',
            style: BeamStyle(strength: strength),
          );
          if (strength > 0) {
            expect(painted, greaterThan(0), reason: 'strength $strength');
          }
        }
        for (final bad in [double.nan, double.infinity]) {
          // Each falls back to its default, and the strength to full: the
          // beam still lights the card.
          expect(
            paintEverywhere(
              effect,
              'non-finite $bad',
              style: BeamStyle(
                strength: bad,
                // NaN fails the constructor's `glow >= 0` assertion.
                glow: bad.isNaN ? null : bad,
                hueShift: bad,
                hueBase: bad,
                hueMode: BeamHueMode.pingPong,
              ),
              shape: BeamShape(borderWidth: bad, ringOffset: bad),
            ),
            greaterThan(0),
            reason: 'non-finite $bad',
          );
        }
        expect(
          paintEverywhere(
            effect,
            'hue extremes',
            style: const BeamStyle(
              hueShift: 3600,
              hueBase: -720,
              hueMode: BeamHueMode.pingPong,
            ),
          ),
          greaterThan(0),
        );
        for (final cycle in [
          const Duration(microseconds: 1),
          const Duration(milliseconds: 1),
          const Duration(hours: 1),
        ]) {
          paintEverywhere(
            effect,
            'cycle $cycle',
            timing: BeamTiming(
              cycle: cycle,
              cycleGap: const Duration(hours: 1),
              huePeriod: const Duration(microseconds: 1),
            ),
          );
        }
      });

      test('zero strength paints no pixel at all', () async {
        for (final brightness in Brightness.values) {
          final config = configFor(
            effect,
            brightness: brightness,
            style: const BeamStyle(strength: 0, glow: 3),
            shape: const BeamShape(ringOffset: 12),
          );
          final frame = await renderFrame(config, phasesAt(config, 1.3));
          expect(frame.lit(), 0, reason: '$name/${brightness.name}');
        }
      });
    });
  }

  group('mounted', () {
    testWidgets('a beam collapsed to zero size builds and paints', (
      tester,
    ) async {
      for (final effect in BeamEffect.values) {
        await tester.pumpWidget(
          Center(
            child: BorderBeam(effect: effect, child: const SizedBox.shrink()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull, reason: effect.name);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a zero-height child in a Column', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              for (final effect in BeamEffect.values)
                BorderBeam(
                  effect: effect,
                  shape: const BeamShape(ringOffset: 6),
                  child: const SizedBox(width: 200, height: 0),
                ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
