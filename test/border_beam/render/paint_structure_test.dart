import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';

import 'render_utils.dart';

/// Where light lands, read back from real shader frames: the shape options
/// put it where they say and nowhere else. These compare regions of one
/// frame (or two frames) against each other rather than pinning pixel
/// values, so retuning the look leaves them standing.
void main() {
  setUpAll(BorderBeam.precache);

  final box = const Offset(renderMargin, renderMargin) & cardSize;

  // Two cycles of every effect, sampled densely enough to catch a sweep in
  // any part of the border.
  final sweep = [for (var i = 0; i < 16; i++) 0.7 + i * 0.37];

  group('a segment', () {
    // The straight run of the top edge and the space above it — border
    // light only. Inward glow from the visible lower half may legitimately
    // reach up through the box, so the band stops at the stroke.
    final topRun = Rect.fromLTRB(
      box.left + 24,
      box.top - 40,
      box.right - 24,
      box.top + 2,
    );

    for (final effect in BeamEffect.values) {
      // A line rides its user segment rather than its edge; start it on the
      // top edge so the unsegmented reference lights the band.
      final subject = effect is LineEffect
          ? const BeamEffect.line(edge: BeamEdge.top)
          : effect;
      test('${effect.name}: bottomHalf hides the top of the border', () async {
        var segmented = 0;
        var whole = 0;
        var visible = 0;
        for (final t in sweep) {
          final masked = configFor(
            subject,
            shape: const BeamShape(segment: BeamSegment.bottomHalf),
          );
          final frame = await renderFrame(masked, phasesAt(masked, t));
          segmented += frame.energyIn(topRun);
          visible += frame.energyIn(
            Rect.fromLTRB(
              0,
              box.center.dy,
              frame.width * 1.0,
              frame.height * 1.0,
            ),
          );
          final full = configFor(subject);
          whole += (await renderFrame(
            full,
            phasesAt(full, t),
          )).energyIn(topRun);
        }
        expect(visible, greaterThan(0), reason: 'the lower half is lit');
        expect(whole, greaterThan(0), reason: 'the reference lights the top');
        expect(
          segmented,
          lessThan(whole * 0.05),
          reason: 'the top run kept $segmented of $whole',
        );
      });
    }

    // Ends that meet run the whole way round: there is no end to fade, so
    // the join is lit like the rest of the border. (The line rides a
    // segment instead of its edge, so it has no unsegmented twin here.)
    for (final effect in [
      const BeamEffect.rotate(),
      const BeamEffect.pulse(),
    ]) {
      test('${effect.name}: ends that meet leave no gap at the join', () async {
        const closed = BeamShape(
          segment: BeamSegment(
            start: BeamAnchor.topCenter,
            end: BeamAnchor.topCenter,
          ),
        );
        // The stroke, the bloom, and the inner glow around top-centre.
        final join = Rect.fromLTRB(
          box.center.dx - 48,
          box.top - 8,
          box.center.dx + 48,
          box.top + 24,
        );
        var looped = 0;
        var whole = 0;
        for (final t in sweep) {
          final masked = configFor(effect, shape: closed);
          looped += (await renderFrame(
            masked,
            phasesAt(masked, t),
          )).energyIn(join);
          final full = configFor(effect);
          whole += (await renderFrame(full, phasesAt(full, t))).energyIn(join);
        }
        expect(whole, greaterThan(0), reason: 'the reference lights the join');
        expect(
          looped,
          greaterThanOrEqualTo(whole * 0.98),
          reason: 'the join kept $looped of $whole',
        );
      });
    }
  });

  group('line', () {
    for (final edge in BeamEdge.values) {
      test('rides the ${edge.name} edge', () async {
        final near = switch (edge) {
          BeamEdge.top => Rect.fromLTRB(
            box.left,
            box.top - 4,
            box.right,
            box.top + 6,
          ),
          BeamEdge.bottom => Rect.fromLTRB(
            box.left,
            box.bottom - 6,
            box.right,
            box.bottom + 4,
          ),
          BeamEdge.left => Rect.fromLTRB(
            box.left - 4,
            box.top,
            box.left + 6,
            box.bottom,
          ),
          BeamEdge.right => Rect.fromLTRB(
            box.right - 6,
            box.top,
            box.right + 4,
            box.bottom,
          ),
        };
        // The band along the opposite edge.
        final far = switch (edge) {
          BeamEdge.top => near.shift(Offset(0, box.height - 10)),
          BeamEdge.bottom => near.shift(Offset(0, -(box.height - 10))),
          BeamEdge.left => near.shift(Offset(box.width - 10, 0)),
          BeamEdge.right => near.shift(Offset(-(box.width - 10), 0)),
        };
        final config = configFor(BeamEffect.line(edge: edge));
        var onEdge = 0;
        var opposite = 0;
        for (final progress in [0.2, 0.5, 0.8]) {
          final frame = await renderFrame(
            config,
            phasesAt(config, 1.3, progress: progress),
          );
          onEdge += frame.energyIn(near);
          opposite += frame.energyIn(far);
        }
        expect(onEdge, greaterThan(0));
        expect(
          opposite,
          lessThan(onEdge * 0.05),
          reason: 'the ${edge.name} streak lit the opposite edge',
        );
      });
    }
  });

  group('ringOffset', () {
    // A ring this far from the box, in either direction.
    const shift = 12.0;

    Future<RenderedFrame> rotateWith(double offset) {
      final config = configFor(
        const BeamEffect.rotate(),
        brightness: Brightness.light,
        shape: BeamShape(ringOffset: offset),
      );
      return renderFrame(config, phasesAt(config, 1.3));
    }

    // Light strictly outside the box, past anti-aliasing.
    int outside(RenderedFrame f) =>
        f.lit(threshold: 2) - f.litIn(box.inflate(3), threshold: 2);

    test('0 keeps an inward beam within the bounds', () async {
      expect(outside(await rotateWith(0)), 0);
    });

    test('a positive offset moves the ring outside the bounds', () async {
      final frame = await rotateWith(shift);
      expect(outside(frame), greaterThan(0));
    });

    test('a negative offset pulls the ring inside them', () async {
      final frame = await rotateWith(-shift);
      expect(outside(frame), 0);
      // The band between the box edge and the pulled-in ring stays dark.
      final band =
          frame.litIn(box, threshold: 2) -
          frame.litIn(box.deflate(shift - 3), threshold: 2);
      expect(band, 0);
    });
  });

  group('outward light', () {
    test('a rotate comet paints past the bounds', () async {
      final config = configFor(const BeamEffect.rotate(comet: true));
      final frame = await renderFrame(config, phasesAt(config, 1.3));
      expect(
        frame.lit(threshold: 8) - frame.litIn(box.inflate(4), threshold: 8),
        greaterThan(0),
      );
    });

    test('without a comet the light stays inside the bounds', () async {
      final config = configFor(const BeamEffect.rotate());
      final frame = await renderFrame(config, phasesAt(config, 1.3));
      expect(
        frame.lit(threshold: 8) - frame.litIn(box.inflate(4), threshold: 8),
        0,
      );
    });
  });

  group('dashes', () {
    // The straight run of the top edge, one pixel row inside the stroke,
    // under a pulse with the glows off — the hairline alone, lit along long
    // stretches of the edge, so dashes have light to cut.
    Future<List<int>> topRow(BeamShape shape) async {
      final config = configFor(
        const BeamEffect.pulse(),
        shape: shape,
        style: const BeamStyle(glow: 0),
      );
      final frame = await renderFrame(config, phasesAt(config, 1.3));
      final y = box.top.toInt();
      return [
        for (var x = box.left.toInt() + 24; x < box.right.toInt() - 24; x++)
          frame.levelAt(x, y),
      ];
    }

    test('dashes only take light away', () async {
      final solid = await topRow(const BeamShape());
      final dashed = await topRow(const BeamShape(dashes: 12));
      for (var i = 0; i < solid.length; i++) {
        expect(dashed[i], lessThanOrEqualTo(solid[i] + 1), reason: 'x+$i');
      }
    });

    test('dashes cut gaps into a lit ring', () async {
      final solid = await topRow(const BeamShape());
      final dashed = await topRow(const BeamShape(dashes: 12));
      // A gap is a run the solid ring lights and the dashes leave dark.
      var gaps = 0;
      var inGap = false;
      for (var i = 0; i < solid.length; i++) {
        final cut = solid[i] > 16 && dashed[i] <= 2;
        if (cut && !inGap) gaps++;
        inGap = cut;
      }
      expect(gaps, greaterThan(1), reason: 'no gaps between dashes');
      expect(
        dashed.where((level) => level > 16),
        isNotEmpty,
        reason: 'no dash',
      );
    });
  });

  group('direction', () {
    test('reverse sweeps the mirror image of forward', () async {
      // The colour field is fixed to the box, so the pixels themselves do
      // not mirror; where the light sits does. Compare the centre of its
      // coverage in both axes, off the quarter turns: there a sweep that
      // runs the wrong way round, or trails its tail the wrong way, lands
      // well away from the mirror image, while on a quarter turn the two
      // can nearly coincide. The windows' exact mirror is checked in
      // beam_frame_test.dart.
      Future<Offset> centre(BeamDirection direction, double turn) async {
        final config = configFor(
          const BeamEffect.rotate(),
          brightness: Brightness.light,
          timing: BeamTiming(direction: direction),
        );
        final frame = await renderFrame(
          config,
          phasesAt(config, config.cycleSeconds * turn),
        );
        var sumX = 0.0;
        var sumY = 0.0;
        var weight = 0.0;
        for (var y = 0; y < frame.height; y++) {
          for (var x = 0; x < frame.width; x++) {
            final a = frame.rgba[(y * frame.width + x) * 4 + 3];
            sumX += a * x;
            sumY += a * y;
            weight += a;
          }
        }
        expect(weight, greaterThan(0));
        return Offset(sumX / weight, sumY / weight);
      }

      // The image is the box with an even margin, so its centre line is
      // the box's.
      final width = renderMargin * 2 + cardSize.width;
      for (final turn in [0.1, 0.4, 0.6]) {
        final forward = await centre(BeamDirection.forward, turn);
        final reverse = await centre(BeamDirection.reverse, turn);
        final mirrored = Offset(width - 1 - reverse.dx, reverse.dy);
        expect(
          (forward - mirrored).distance,
          lessThan(cardSize.width * 0.08),
          reason: '$turn of a turn: forward $forward, reverse $mirrored',
        );
      }
    });
  });

  group('glow', () {
    // Light deep inside the box, well past the stroke and the bloom that
    // hugs it.
    Future<int> deepInside(double glow) async {
      final config = configFor(
        const BeamEffect.rotate(),
        style: BeamStyle(glow: glow),
      );
      final frame = await renderFrame(config, phasesAt(config, 1.3));
      return frame.litIn(box.deflate(24), threshold: 4);
    }

    test('a bigger glow reaches further in', () async {
      expect(await deepInside(2), greaterThan(await deepInside(1)));
    });

    // BeamStyle.glow documents "0 leaves only the stroke".
    test('0 leaves only the stroke', () async {
      final config = configFor(
        const BeamEffect.rotate(),
        style: const BeamStyle(glow: 0),
        shape: const BeamShape(borderWidth: 1),
      );
      final frame = await renderFrame(config, phasesAt(config, 1.3));
      // The stroke is 1px wide, but a 16px corner bows it up to 4.7px in from
      // each edge; 6px clears it with room for anti-aliasing.
      expect(frame.litIn(box.deflate(6), threshold: 2), 0);
      expect(frame.lit(threshold: 2), greaterThan(0));
    });
  });
}
