import 'dart:math' as math;
import 'dart:ui' show Brightness;

import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/effects/effect_emitters.dart';
import 'package:flutter_border_beam/src/render/beam_emission.dart';
import 'package:flutter_border_beam/src/render/beam_outline.dart';
import 'package:flutter_border_beam/src/render/beam_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render_utils.dart';

/// What each effect hands the shader, frame by frame: within the slot
/// budget, finite, in range, lit where the draw can reach, and confined to
/// the visible segment.
void main() {
  setUpAll(BorderBeam.precache);

  // Evenly spread across two cycles of every effect, plus the golden
  // instant.
  final instants = [for (var i = 0; i < 24; i++) 0.05 + i * 0.29, 1.3];

  group('every frame is sane', () {
    for (final MapEntry(key: name, value: effect) in effectsByName.entries) {
      test(name, () {
        final renderer = BeamRenderer();
        addTearDown(renderer.dispose);
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
              final canvas = recordFrame(renderer, config, phasesAt(config, t));
              // A frame the gap blacked out leaves the last emission behind.
              if (canvas.draws.isEmpty) continue;
              painted++;
              expectSaneEmission(
                renderer.debugEmission,
                '$name/${brightness.name}/$shapeName at ${t}s',
                drawBounds: canvas.drawBounds.single,
              );
            }
          }
        }
        expect(painted, greaterThan(0));
      });
    }

    test('effect options and glow extremes', () {
      final options = <String, BeamEffect>{
        'rotate comet': const BeamEffect.rotate(comet: true),
        'rotate count 4': const BeamEffect.rotate(count: 4),
        'rotate short tail': const BeamEffect.rotate(length: 0.25),
        'rotate long tail': const BeamEffect.rotate(length: 2),
        for (final edge in BeamEdge.values)
          'line ${edge.name}': BeamEffect.line(edge: edge),
        'shimmer 0°': const BeamEffect.shimmer(angle: 0),
        'shimmer 90°': const BeamEffect.shimmer(angle: 90),
        'shimmer -45°': const BeamEffect.shimmer(angle: -45),
      };
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final MapEntry(key: label, value: effect) in options.entries) {
        for (final glow in [0.0, 1.0, 4.0]) {
          final config = configFor(effect, style: BeamStyle(glow: glow));
          for (final t in instants) {
            final canvas = recordFrame(renderer, config, phasesAt(config, t));
            if (canvas.draws.isEmpty) continue;
            expectSaneEmission(
              renderer.debugEmission,
              '$label, glow $glow at ${t}s',
              drawBounds: canvas.drawBounds.single,
            );
          }
        }
      }
    });

    test('driven sweeps, from empty to full', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final effect in BeamEffect.values.where((e) => e.travels)) {
        final config = configFor(effect);
        for (var i = 0; i <= 20; i++) {
          final progress = i / 20;
          final canvas = recordFrame(
            renderer,
            config,
            phasesAt(config, 1.3, progress: progress),
          );
          expect(canvas.draws, hasLength(1));
          expectSaneEmission(
            renderer.debugEmission,
            '${effect.name} at progress $progress',
            drawBounds: canvas.drawBounds.single,
          );
        }
      }
    });
  });

  group('rotate', () {
    test('count beams travel evenly spaced', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final count in [1, 2, 3, 4]) {
        final config = configFor(BeamEffect.rotate(count: count));
        recordFrame(renderer, config, phasesAt(config, 1.3));
        final e = renderer.debugEmission;
        expect(e.bumpCount % count, 0, reason: 'the same bumps per beam');
        final perBeam = e.bumpCount ~/ count;
        final heads = [for (var i = 0; i < count; i++) e.bumps[i * perBeam * 4]]
          ..sort();
        for (var i = 0; i < count; i++) {
          final next = i + 1 < count ? heads[i + 1] : heads[0] + 1;
          expect(next - heads[i], closeTo(1 / count, 1e-6));
        }
      }
    });

    test('the tail trails the head, and swaps sides in reverse', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final direction in [BeamDirection.forward, BeamDirection.reverse]) {
        final config = configFor(
          const BeamEffect.rotate(),
          timing: BeamTiming(direction: direction),
        );
        recordFrame(renderer, config, phasesAt(config, 1.3));
        final e = renderer.debugEmission;
        final lead = e.bumps[1];
        final tail = e.bumps[2];
        if (direction == BeamDirection.forward) {
          expect(tail, greaterThan(lead), reason: 'clockwise: tail behind');
        } else {
          expect(lead, greaterThan(tail), reason: 'reverse: tail ahead in u');
        }
      }
    });

    test('a comet reaches outside the border; a plain beam does not', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      final plain = configFor(const BeamEffect.rotate());
      recordFrame(renderer, plain, phasesAt(plain, 1.3));
      expect(renderer.debugEmission.outer, 0);
      final comet = configFor(const BeamEffect.rotate(comet: true));
      recordFrame(renderer, comet, phasesAt(comet, 1.3));
      expect(renderer.debugEmission.outer, greaterThan(0));
      expect(renderer.debugEmission.outerReach, greaterThan(0));
    });
  });

  group('line', () {
    test('the streak stays on its edge', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final edge in BeamEdge.values) {
        final config = configFor(BeamEffect.line(edge: edge));
        final outline = BeamOutline(
          const Offset(renderMargin, renderMargin) & cardSize,
          config.borderRadius,
        );
        final range = outline.edgeRange(edge);
        final span = BeamOutline.wrapFraction(range.to - range.from);
        for (var i = 0; i <= 10; i++) {
          recordFrame(
            renderer,
            config,
            phasesAt(config, 1.3, progress: i / 10),
          );
          final e = renderer.debugEmission;
          final along = BeamOutline.wrapFraction(e.bumps[0] - range.from);
          expect(
            along,
            inInclusiveRange(-1e-6, span + 1e-6),
            reason: '${edge.name} at ${i / 10}',
          );
          // The spikes ride the edge; at the ends of the run they may round
          // into the corner, but never further than its curve reaches.
          final corner = outline.cornerSizes.reduce(math.max);
          for (var l = 0; l < e.lightCount; l++) {
            final at = Offset(e.lightPos[l * 4], e.lightPos[l * 4 + 1]);
            final edgeLine = switch (edge) {
              BeamEdge.top => (at.dy - outline.rect.top).abs(),
              BeamEdge.bottom => (at.dy - outline.rect.bottom).abs(),
              BeamEdge.left => (at.dx - outline.rect.left).abs(),
              BeamEdge.right => (at.dx - outline.rect.right).abs(),
            };
            expect(
              edgeLine,
              lessThanOrEqualTo(corner),
              reason: '${edge.name} light $l',
            );
          }
        }
      }
    });

    test('a driven streak reads left to right and top to bottom', () {
      // Whichever way the perimeter runs along an edge, progress 0 sits at
      // the reading-order start of it.
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final edge in BeamEdge.values) {
        final config = configFor(BeamEffect.line(edge: edge));
        final outline = BeamOutline(
          const Offset(renderMargin, renderMargin) & cardSize,
          config.borderRadius,
        );
        Offset head(double progress) {
          recordFrame(
            renderer,
            config,
            phasesAt(config, 1.3, progress: progress),
          );
          return outline.pointAt(renderer.debugEmission.bumps[0]);
        }

        final start = head(0.1);
        final end = head(0.9);
        switch (edge) {
          case BeamEdge.top || BeamEdge.bottom:
            expect(end.dx, greaterThan(start.dx), reason: edge.name);
          case BeamEdge.left || BeamEdge.right:
            expect(end.dy, greaterThan(start.dy), reason: edge.name);
        }
      }
    });
  });

  group('charge', () {
    test('the fill grows with progress from the top, clockwise', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      final config = configFor(const BeamEffect.charge());
      var previous = 0.0;
      for (var i = 1; i <= 10; i++) {
        recordFrame(renderer, config, phasesAt(config, 1.3, progress: i / 10));
        final e = renderer.debugEmission;
        expect(e.segmentStart, closeTo(0, 1e-9), reason: 'starts top-centre');
        expect(e.segmentSpan, closeTo(i / 10, 1e-9));
        expect(e.segmentSpan, greaterThan(previous));
        previous = e.segmentSpan;
      }
    });

    test('an empty charge lights nothing on the border', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      final config = configFor(const BeamEffect.charge());
      recordFrame(renderer, config, phasesAt(config, 1.3, progress: 0));
      final e = renderer.debugEmission;
      expect(e.stroke, 0);
      expect(e.base, 0);
      expect(e.bumpCount, 0);
      expect(e.lightCount, 0);
    });
  });

  group('shimmer', () {
    test('the glint crosses the whole box over one sweep', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final angle in [0.0, 20.0, 45.0, 90.0]) {
        final config = configFor(BeamEffect.shimmer(angle: angle));
        double at(double progress) {
          recordFrame(
            renderer,
            config,
            phasesAt(config, 0.7, progress: progress),
          );
          final e = renderer.debugEmission;
          expect(e.sweepAmplitude, greaterThan(0));
          return e.sweepPosition;
        }

        final from = at(0);
        final to = at(1);
        final e = renderer.debugEmission;
        final half = e.sweepHalfWidth;
        // In box-normalised coordinates the box spans 0.5 ± (|dx| + |dy|) / 2
        // along the sweep direction: the band starts wholly before its
        // nearest corner and ends wholly past its furthest.
        final reach =
            (e.sweepDirection.dx.abs() + e.sweepDirection.dy.abs()) / 2;
        expect(
          from + half,
          lessThanOrEqualTo(0.5 - reach + 1e-9),
          reason: 'angle $angle starts off the box',
        );
        expect(
          to - half,
          greaterThanOrEqualTo(0.5 + reach - 1e-9),
          reason: 'angle $angle ends off the box',
        );
      }
    });
  });

  group('ambient effects', () {
    test('light the whole border, so a segment is the only mask', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final effect in BeamEffect.values.where((e) => !e.travels)) {
        final config = configFor(effect);
        recordFrame(renderer, config, phasesAt(config, 1.3));
        final e = renderer.debugEmission;
        expect(e.base, greaterThan(0), reason: effect.name);
        expect(e.segmentSpan, 0, reason: '${effect.name}: no own mask');
      }
    });

    test('flow and spin stream their colours the way they are told', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final effect in [const BeamEffect.flow(), const BeamEffect.spin()]) {
        double originAt(BeamDirection direction, double t) {
          final config = configFor(
            effect,
            timing: BeamTiming(direction: direction),
          );
          recordFrame(renderer, config, phasesAt(config, t));
          return renderer.debugEmission.colorOrigin;
        }

        final forward =
            originAt(BeamDirection.forward, 1.4) -
            originAt(BeamDirection.forward, 1.3);
        final reverse =
            originAt(BeamDirection.reverse, 1.4) -
            originAt(BeamDirection.reverse, 1.3);
        expect(forward, greaterThan(0), reason: effect.name);
        expect(reverse, lessThan(0), reason: effect.name);
      }
    });
  });

  group('segments', () {
    final segments = <String, BeamSegment>{
      'bottomHalf': BeamSegment.bottomHalf,
      'topEdge': BeamSegment.topEdge,
      'rightHalf': BeamSegment.rightHalf,
      'hard cut': const BeamSegment(
        start: BeamAnchor.fraction(0.6),
        end: BeamAnchor.fraction(0.9),
        feather: 0,
      ),
      'wrapping': const BeamSegment(
        start: BeamAnchor.fraction(0.85),
        end: BeamAnchor.fraction(0.2),
      ),
    };

    double weightNear(BeamEmission track, double u) {
      // Light anchors are placed at a perimeter coordinate and read back by
      // nearest point; allow that round trip a hair of slack.
      var best = 0.0;
      for (var k = -4; k <= 4; k++) {
        best = math.max(best, segmentWeight(track, u + k * 5e-4));
      }
      return best;
    }

    for (final MapEntry(key: name, value: effect) in effectsByName.entries) {
      test('$name lights nothing outside the segment', () {
        final renderer = BeamRenderer();
        addTearDown(renderer.dispose);
        for (final MapEntry(key: label, value: segment) in segments.entries) {
          final config = configFor(effect, shape: BeamShape(segment: segment));
          final outline = BeamOutline(
            const Offset(renderMargin, renderMargin) & cardSize,
            config.borderRadius,
          );
          // The user segment as the renderer applies it, before any effect
          // narrows the visible track further.
          final track = BeamEmission()..reset();
          applySegment(track, segment, outline);
          for (final t in instants) {
            final canvas = recordFrame(renderer, config, phasesAt(config, t));
            if (canvas.draws.isEmpty) continue;
            final e = renderer.debugEmission;
            for (var l = 0; l < e.lightCount; l++) {
              final at = Offset(e.lightPos[l * 4], e.lightPos[l * 4 + 1]);
              final u = outline.nearestFraction(at);
              final weight = weightNear(track, u);
              expect(
                e.lightShape[l * 4 + 2],
                lessThanOrEqualTo(weight * 1.2 + 1e-6),
                reason:
                    '$name/$label at ${t}s: light $l at u=$u has amplitude '
                    '${e.lightShape[l * 4 + 2]} but the segment weight there '
                    'is $weight',
              );
            }
            // Effects that narrow the visible track keep it inside the
            // user's.
            if (e.segmentSpan > 0) {
              var from = BeamOutline.wrapFraction(
                e.segmentStart - track.segmentStart,
              );
              if (from > 1 - 1e-6) from = 0;
              expect(
                from + e.segmentSpan,
                lessThanOrEqualTo(track.segmentSpan + 1e-6),
                reason:
                    '$name/$label at ${t}s: track ${e.segmentStart}+'
                    '${e.segmentSpan} escapes the segment '
                    '${track.segmentStart}+${track.segmentSpan}',
              );
            }
          }
        }
      });
    }
  });
}
