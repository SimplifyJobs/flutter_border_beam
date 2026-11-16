import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/effects/effect_emitters.dart';
import 'package:flutter_border_beam/src/look/beam_look.dart';
import 'package:flutter_border_beam/src/look/palette_tables.dart';
import 'package:flutter_border_beam/src/look/rotate_look.dart';
import 'package:flutter_border_beam/src/render/beam_frame.dart';
import 'package:flutter_border_beam/src/render/beam_outline.dart';
import 'package:flutter_border_beam/src/render/beam_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render_utils.dart';

/// What each effect writes for the shader, frame by frame: finite and in
/// range, its layers built the way the design builds them, its windows where
/// the travel says, and its track inside the user's segment.
void main() {
  setUpAll(BorderBeam.precache);

  // Evenly spread across two cycles of every effect, plus the golden
  // instant.
  final instants = [for (var i = 0; i < 24; i++) 0.05 + i * 0.29, 1.3];
  final box = const Offset(renderMargin, renderMargin) & cardSize;

  BeamRenderer renderer() {
    final r = BeamRenderer();
    addTearDown(r.dispose);
    return r;
  }

  int litLayers(BeamFrameData d) => [
    for (var k = 0; k < beamLayerCount; k++)
      if (d.geometryOf(k) != BeamGeometry.none && d.opacityOf(k) > 0) k,
  ].length;

  group('every frame is sane', () {
    for (final MapEntry(key: name, value: effect) in effectsByName.entries) {
      test(name, () {
        final r = renderer();
        var painted = 0;
        for (final brightness in Brightness.values) {
          for (final MapEntry(key: shapeName, value: shape)
              in shapeVariety.entries) {
            final config = configFor(
              effect,
              brightness: brightness,
              shape: shape,
            );
            for (final t in instants) {
              final canvas = recordFrame(r, config, phasesAt(config, t));
              final label = '$name/${brightness.name}/$shapeName at ${t}s';
              // The golden instant is mid-sweep for every effect: any shape
              // but a segment, which may hide all of the light, draws there.
              // (Elsewhere a frame can be dark — the line fades its streak in
              // and out of each sweep.)
              if (t == 1.3 && shape.segment == null) {
                expect(canvas.draws, hasLength(1), reason: '$label: no draw');
              }
              if (canvas.draws.isEmpty) continue;
              painted++;
              expectSaneFrame(
                r.debugFrame,
                label,
                drawBounds: canvas.drawBounds.single,
              );
            }
          }
        }
        expect(painted, greaterThan(0));
      });
    }

    test('effect options, palettes, and glow extremes', () {
      final options = <String, BeamEffect>{
        'rotate comet': const BeamEffect.rotate(comet: true),
        'rotate count 4': const BeamEffect.rotate(count: 4),
        'rotate short tail': const BeamEffect.rotate(length: 0.25),
        'rotate long tail': const BeamEffect.rotate(length: 2),
        for (final edge in BeamEdge.values)
          'line ${edge.name}': BeamEffect.line(edge: edge),
      };
      final r = renderer();
      for (final MapEntry(key: label, value: effect) in options.entries) {
        for (final glow in [0.0, 1.0, 4.0]) {
          for (final MapEntry(key: palette, value: colors)
              in paletteSubset.entries) {
            final config = configFor(
              effect,
              colors: colors,
              style: BeamStyle(glow: glow),
            );
            for (final t in [0.4, 1.3, 2.9]) {
              final canvas = recordFrame(r, config, phasesAt(config, t));
              final where = '$label, $palette, glow $glow at ${t}s';
              if (t == 1.3) {
                expect(canvas.draws, hasLength(1), reason: '$where: no draw');
              }
              if (canvas.draws.isEmpty) continue;
              expectSaneFrame(
                r.debugFrame,
                where,
                drawBounds: canvas.drawBounds.single,
              );
            }
          }
        }
      }
    });

    test('driven sweeps, from empty to full', () {
      final r = renderer();
      for (final effect in BeamEffect.values.where((e) => e.travels)) {
        final config = configFor(effect);
        for (var i = 0; i <= 20; i++) {
          final progress = i / 20;
          final canvas = recordFrame(
            r,
            config,
            phasesAt(config, 1.3, progress: progress),
          );
          expect(canvas.draws, hasLength(1));
          expectSaneFrame(
            r.debugFrame,
            '${effect.name} at progress $progress',
            drawBounds: canvas.drawBounds.single,
          );
        }
      }
    });
  });

  group('rotate', () {
    test('paints an inner glow, a hairline, and a blurred bloom', () {
      final r = renderer();
      final config = configFor(const BeamEffect.rotate());
      recordFrame(r, config, phasesAt(config, 1.3));
      final d = r.debugFrame;
      expect(d.geometryOf(0), BeamGeometry.fill);
      expect(d.edgeFadeOf(0), innerEdgeFade);
      expect(d.hasShadow(0), isTrue);
      expect(d.windowOf(0), BeamWindow.conicA);
      expect(d.blobCount(0), colorfulTables.border.length);
      expect(d.geometryOf(1), BeamGeometry.ring);
      expect(d.windowOf(1), BeamWindow.conicA);
      expect(d.overlayOf(1), BeamTable.overlayA);
      expect(d.blobCount(1), colorfulTables.border.length);
      expect(d.geometryOf(2), BeamGeometry.blurredRing);
      expect(d.sigmaOf(2), rotateBloomBlur);
      expect(d.overlayOf(2), BeamTable.overlayB);
      expect(d.blobCount(2), 0);
    });

    test('a compact chip takes the chip tables', () {
      final r = renderer();
      final config = configFor(
        const BeamEffect.rotate(),
        shape: const BeamShape.stadium(),
      );
      recordFrame(r, config, phasesAt(config, 1.3), size: const Size(120, 36));
      final d = r.debugFrame;
      expect(d.windowOf(0), BeamWindow.conicB, reason: 'the wider window');
      expect(d.edgeFadeOf(0), 0, reason: 'no edge fade on a chip');
      expect(d.blobCount(0), colorfulTables.smallInner.length);
      expect(d.blobCount(1), colorfulTables.smallBorder.length);
    });

    test('the head rides the travel around the turn', () {
      final r = renderer();
      final config = configFor(const BeamEffect.rotate());
      for (final p in [0.0, 0.2, 0.55, 0.9]) {
        recordFrame(r, config, phasesAt(config, 1.3, progress: p));
        final head = r.debugFrame.conicStart + rotateHeadStop;
        expect(BeamOutline.wrapFraction(head - p), closeTo(0, 1e-6));
      }
    });

    test('count beams repeat the tables around the turn', () {
      final r = renderer();
      for (final count in [1, 2, 3, 4]) {
        final config = configFor(BeamEffect.rotate(count: count));
        recordFrame(r, config, phasesAt(config, 1.3));
        expect(r.debugFrame.conicRepeats, count);
      }
    });

    test('length stretches the tail; reverse mirrors the tables', () {
      final r = renderer();
      double lit(BeamFrameData d) {
        var n = 0;
        for (var i = 0; i < 400; i++) {
          if (d.tableAt(BeamTable.windowA, i / 400) > 0.05) n++;
        }
        return n / 400;
      }

      final short = configFor(const BeamEffect.rotate(length: 0.5));
      recordFrame(r, short, phasesAt(short, 1.3));
      final shortWidth = lit(r.debugFrame);
      final long = configFor(const BeamEffect.rotate(length: 1.3));
      recordFrame(r, long, phasesAt(long, 1.3));
      expect(lit(r.debugFrame), greaterThan(shortWidth));

      final forward = configFor(const BeamEffect.rotate());
      recordFrame(r, forward, phasesAt(forward, 1.3));
      final f = [
        for (var i = 1; i < 20; i++)
          r.debugFrame.tableAt(BeamTable.overlayA, i / 20),
      ];
      final reverse = configFor(
        const BeamEffect.rotate(),
        timing: const BeamTiming(direction: BeamDirection.reverse),
      );
      recordFrame(r, reverse, phasesAt(reverse, 1.3));
      for (var i = 1; i < 20; i++) {
        expect(
          r.debugFrame.tableAt(BeamTable.overlayA, 1 - i / 20),
          closeTo(f[i - 1], 1e-6),
        );
      }
    });

    test('reverse mirrors the windows on screen', () {
      // Where the light sits, and which way its tail runs: every table read
      // at a screen angle (clockwise from 12 o'clock) through the conic
      // start and repeats, as the shader reads it, is the forward one
      // reflected left to right, at every instant and beam count.
      final r = renderer();
      double seen(BeamTable table, double angle) {
        final d = r.debugFrame;
        var t = (angle - d.conicStart) % 1.0;
        if (d.conicRepeats > 1) t = (t * d.conicRepeats) % 1.0;
        return d.tableAt(table, t);
      }

      const steps = 360;
      for (final count in [1, 2]) {
        for (final turn in [0.1, 0.25, 0.4, 0.6, 0.9]) {
          final forward = configFor(BeamEffect.rotate(count: count));
          recordFrame(
            r,
            forward,
            phasesAt(forward, forward.cycleSeconds * turn),
          );
          final expected = {
            for (final t in BeamTable.values)
              t: [for (var i = 0; i < steps; i++) seen(t, i / steps)],
          };
          final reverse = configFor(
            BeamEffect.rotate(count: count),
            timing: const BeamTiming(direction: BeamDirection.reverse),
          );
          recordFrame(
            r,
            reverse,
            phasesAt(reverse, reverse.cycleSeconds * turn),
          );
          for (final t in BeamTable.values) {
            for (var i = 0; i < steps; i++) {
              expect(
                seen(t, (steps - i) % steps / steps),
                closeTo(expected[t]![i], 1e-4),
                reason: '×$count, $turn of a turn: ${t.name} at $i/$steps',
              );
            }
          }
        }
      }
    });

    test('a comet glows outside the border; a plain beam stays in', () {
      final r = renderer();
      final plain = configFor(const BeamEffect.rotate());
      recordFrame(r, plain, phasesAt(plain, 1.3));
      expect(r.debugFrame.geometryOf(2), BeamGeometry.blurredRing);
      expect(r.debugFrame.reachOutside, 0);
      final comet = configFor(const BeamEffect.rotate(comet: true));
      recordFrame(r, comet, phasesAt(comet, 1.3));
      expect(r.debugFrame.geometryOf(2), BeamGeometry.glow);
      expect(r.debugFrame.reachOutside, greaterThan(cometReach));
    });

    test('mono paints its layers at half strength', () {
      final r = renderer();
      final colorful = configFor(const BeamEffect.rotate());
      recordFrame(r, colorful, phasesAt(colorful, 1.3));
      final full = [for (var k = 0; k < 3; k++) r.debugFrame.opacityOf(k)];
      final mono = configFor(
        const BeamEffect.rotate(),
        colors: BeamColors.mono,
      );
      recordFrame(r, mono, phasesAt(mono, 1.3));
      for (var k = 0; k < 3; k++) {
        expect(r.debugFrame.opacityOf(k), closeTo(full[k] / 2, 1e-6));
      }
    });
  });

  group('line', () {
    // A fixed hue (the gold preset, or hueMode: none) once dropped the
    // bloom's blur, leaving the spikes as hard needles.
    test('the bloom stays blurred when the hue is fixed', () {
      final r = renderer();
      double bloomBlur(BeamColors colors, {BeamHueMode? hueMode}) {
        final config = configFor(
          const BeamEffect.line(),
          colors: colors,
          style: BeamStyle(hueMode: hueMode),
        );
        recordFrame(r, config, phasesAt(config, 1.3));
        return r.debugFrame.blobBlurOf(2);
      }

      final drifting = bloomBlur(BeamColors.ember);
      expect(drifting, greaterThan(0));
      expect(bloomBlur(BeamColors.gold), drifting);
      expect(bloomBlur(BeamColors.ember, hueMode: BeamHueMode.none), drifting);
    });

    // The line runs two hue tracks of its own beside the beam's; a static
    // frame promises the palette's own colours, so neither may swing.
    test('a static frame paints the palette as given, whatever the drift', () {
      final r = renderer();
      List<double> still(BeamHueMode hueMode) {
        final config = configFor(
          const BeamEffect.line(),
          style: BeamStyle(hueMode: hueMode),
        );
        recordFrame(r, config, BeamPhaseResolver(config).staticFrame());
        return List.of(r.debugFrame.data);
      }

      // Continuous drift has no track of the line's own: its static frame
      // is the palette at hue 0, which ping-pong's must match.
      expect(still(BeamHueMode.pingPong), still(BeamHueMode.continuous));
    });

    test('the windows ride the edge with the streak', () {
      final r = renderer();
      for (final edge in BeamEdge.values) {
        final config = configFor(BeamEffect.line(edge: edge));
        for (final p in [0.2, 0.5, 0.8]) {
          recordFrame(r, config, phasesAt(config, 1.3, progress: p));
          final d = r.debugFrame;
          for (final k in [0, 1, 2]) {
            expect(d.windowOf(k), BeamWindow.radial);
            final w = d.windowParamsOf(k);
            final at = Offset(w[0], w[1]);
            final onEdge = switch (edge) {
              BeamEdge.top => (at.dy - box.top).abs(),
              BeamEdge.bottom => (at.dy - box.bottom).abs(),
              BeamEdge.left => (at.dx - box.left).abs(),
              BeamEdge.right => (at.dx - box.right).abs(),
            };
            expect(onEdge, lessThan(1e-3), reason: '${edge.name} $k');
          }
        }
      }
    });

    test('a driven streak reads left to right and top to bottom', () {
      final r = renderer();
      for (final edge in BeamEdge.values) {
        final config = configFor(BeamEffect.line(edge: edge));
        Offset centre(double p) {
          recordFrame(r, config, phasesAt(config, 1.3, progress: p));
          final w = r.debugFrame.windowParamsOf(1);
          return Offset(w[0], w[1]);
        }

        final start = centre(0.1);
        final end = centre(0.9);
        if (edge == BeamEdge.top || edge == BeamEdge.bottom) {
          expect(end.dx, greaterThan(start.dx), reason: edge.name);
        } else {
          expect(end.dy, greaterThan(start.dy), reason: edge.name);
        }
      }
    });

    test('fades in and out at the ends of a timed sweep', () {
      final r = renderer();
      final config = configFor(const BeamEffect.line());
      double strokeAt(double t) {
        recordFrame(r, config, phasesAt(config, t));
        return r.debugFrame.opacityOf(1);
      }

      final cycle = config.cycleSeconds;
      expect(strokeAt(cycle * 0.5), greaterThan(0.9));
      expect(strokeAt(cycle * 0.2), lessThan(strokeAt(cycle * 0.5)));
      expect(strokeAt(cycle * 0.8), lessThan(strokeAt(cycle * 0.5)));
    });

    // Mono tones the line down through its spikes (shorter, fainter), which
    // the `line_*_mono` goldens pin; what this pins is the other half — it
    // does not do it by halving whole layers, as rotate's mono does.
    test("mono leaves the line's layer opacities alone", () {
      final r = renderer();
      final colorful = configFor(const BeamEffect.line());
      recordFrame(r, colorful, phasesAt(colorful, 1.5));
      final full = [for (var k = 0; k < 3; k++) r.debugFrame.opacityOf(k)];
      final mono = configFor(const BeamEffect.line(), colors: BeamColors.mono);
      recordFrame(r, mono, phasesAt(mono, 1.5));
      for (var k = 0; k < 3; k++) {
        expect(r.debugFrame.opacityOf(k), closeTo(full[k], 1e-6));
      }
    });
  });

  group('ambient effects', () {
    test('light the whole border, so a segment is the only mask', () {
      final r = renderer();
      for (final effect in BeamEffect.values.where((e) => !e.travels)) {
        final config = configFor(effect);
        recordFrame(r, config, phasesAt(config, 1.3));
        expect(litLayers(r.debugFrame), 3, reason: effect.name);
        expect(r.debugFrame.trackSpan, 0, reason: '${effect.name}: own mask');
      }
    });
  });

  group('palettes', () {
    test('the originals draw with their own tables', () {
      for (final colors in [
        BeamColors.colorful,
        BeamColors.mono,
        BeamColors.ocean,
        BeamColors.sunset,
      ]) {
        final palette = colors.resolve();
        expect(identical(BeamLook.tablesFor(palette), palette.tables), isTrue);
      }
    });

    test("the extras cycle their colours over colorful's tables", () {
      final tables = BeamLook.tablesFor(BeamColors.aurora.resolve());
      for (final (i, b) in tables.border.indexed) {
        expect(b.position, colorfulTables.border[i].position);
        expect(b.size, colorfulTables.border[i].size);
      }
      expect(tables.border.first.color, isNot(colorfulTables.border[0].color));
    });

    test("custom palettes sample their stops into colorful's geometry", () {
      const red = Color(0xFFFF0000);
      final tables = BeamLook.tablesFor(const BeamColors.solid(red).resolve());
      for (final (i, b) in tables.border.indexed) {
        expect(b.position, colorfulTables.border[i].position);
        expect(b.color.r, closeTo(1, 1e-6));
        expect(b.color.g, closeTo(0, 1e-6));
      }
      for (final s in tables.lineBloomDark) {
        expect(s.color1.r, closeTo(1, 1e-6));
      }
      // Resolved once per palette.
      final palette = const BeamColors.solid(red).resolve();
      expect(
        identical(BeamLook.tablesFor(palette), BeamLook.tablesFor(palette)),
        isTrue,
      );
    });

    test('custom palettes spread each line table across its own streak', () {
      // Black to white once round the ring: a blob's grey level says where
      // across the streak it sampled the palette.
      final tables = BeamLook.tablesFor(
        const BeamColors(
          [Color(0xFF000000), Color(0xFFFFFFFF)],
          stops: [0, 0.999],
        ).resolve(),
      );
      for (final (name, blobs) in [
        ('lineDark', tables.lineDark),
        ('lineLight', tables.lineLight),
        ('lineInner', tables.lineInner),
      ]) {
        final across = [...blobs]
          ..sort((a, b) => a.offsetX.compareTo(b.offsetX));
        expect(across.first.color.r, closeTo(0, 1e-3), reason: '$name: start');
        expect(across.last.color.r, greaterThan(0.99), reason: '$name: end');
        for (var i = 1; i < across.length; i++) {
          expect(
            across[i].color.r,
            greaterThan(across[i - 1].color.r),
            reason:
                '$name: the blobs at ${across[i - 1].offsetX} and '
                '${across[i].offsetX} px sampled the same point',
          );
        }
      }
    });

    test('scaleAlpha keeps a preset tables, scaled', () {
      final half = BeamLook.tablesFor(
        BeamColors.ocean.scaleAlpha(0.5).resolve(),
      );
      for (final (i, b) in half.border.indexed) {
        expect(b.position, oceanTables.border[i].position);
        expect(b.color.a, closeTo(oceanTables.border[i].color.a * 0.5, 1e-6));
      }
    });
  });

  group('segments', () {
    final segments = <String, BeamSegment>{
      'bottomHalf': BeamSegment.bottomHalf,
      'topEdge': BeamSegment.topEdge,
      'wrapping': const BeamSegment(
        start: BeamAnchor.fraction(0.85),
        end: BeamAnchor.fraction(0.2),
      ),
    };

    for (final MapEntry(key: name, value: effect) in effectsByName.entries) {
      test('$name keeps its track inside the segment', () {
        final r = renderer();
        for (final MapEntry(key: label, value: segment) in segments.entries) {
          final config = configFor(effect, shape: BeamShape(segment: segment));
          final outline = BeamOutline(box, config.borderRadius);
          final range = segment.resolve(outline);
          final userStart = range.from;
          final userSpan = BeamOutline.wrapFraction(range.to - range.from);
          for (final t in instants) {
            final canvas = recordFrame(r, config, phasesAt(config, t));
            if (canvas.draws.isEmpty) continue;
            final d = r.debugFrame;
            expect(d.trackSpan, greaterThan(0), reason: '$name/$label');
            var from = BeamOutline.wrapFraction(d.trackStart - userStart);
            if (from > 1 - 1e-6) from = 0;
            expect(
              from + d.trackSpan,
              lessThanOrEqualTo(userSpan + 1e-6),
              reason: '$name/$label at ${t}s',
            );
          }
        }
      });
    }
  });

  test('applyTrack writes the user segment, or the whole border', () {
    final outline = BeamOutline(
      box,
      const BorderRadius.all(Radius.circular(16)),
    );
    final d = BeamFrameData()..reset();
    applyTrack(d, null, outline, 0);
    expect(d.trackSpan, 0);
    applyTrack(d, BeamSegment.bottomHalf, outline, 6);
    expect(d.trackSpan, closeTo(0.5, 1e-6));
    expect(d.trackFeather, greaterThan(0));
    expect(segmentTrack(d).span, closeTo(0.5, 1e-6));
  });

  test('a lit frame is written for the box it paints', () {
    final r = renderer();
    for (final effect in BeamEffect.values) {
      final config = configFor(effect);
      final canvas = recordFrame(
        r,
        config,
        phasesAt(config, litSeconds(effect)),
      );
      expect(canvas.draws, hasLength(1), reason: effect.name);
      expect(r.debugFrame.outlineRect, box, reason: effect.name);
    }
  });
}
