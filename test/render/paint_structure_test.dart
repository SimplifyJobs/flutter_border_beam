import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

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
    for (final (label, effect) in [
      ('halo', const BeamEffect.halo()),
      ('rotate comet', const BeamEffect.rotate(comet: true)),
      ('spin', const BeamEffect.spin()),
    ]) {
      test('$label paints past the bounds', () async {
        final config = configFor(effect);
        final frame = await renderFrame(config, phasesAt(config, 1.3));
        expect(
          frame.lit(threshold: 8) - frame.litIn(box.inflate(4), threshold: 8),
          greaterThan(0),
        );
      });
    }

    test('a halo reaches further out than a comet', () async {
      Future<int> farOut(BeamEffect effect) async {
        final config = configFor(effect);
        final frame = await renderFrame(config, phasesAt(config, 1.3));
        return frame.lit(threshold: 8) -
            frame.litIn(box.inflate(16), threshold: 8);
      }

      expect(
        await farOut(const BeamEffect.halo()),
        greaterThan(await farOut(const BeamEffect.rotate(comet: true))),
      );
    });
  });

  group('dashes', () {
    // The straight run of the top edge, one pixel row inside the stroke.
    Future<List<int>> topRow(BeamShape shape) async {
      final config = configFor(const BeamEffect.spin(), shape: shape);
      final frame = await renderFrame(config, phasesAt(config, 1.3));
      final y = box.top.toInt();
      return [
        for (var x = box.left.toInt() + 24; x < box.right.toInt() - 24; x++)
          frame.levelAt(x, y),
      ];
    }

    test('a solid ring lights the whole edge', () async {
      final row = await topRow(const BeamShape());
      expect(row.where((level) => level <= 2), isEmpty);
    });

    test('dashes cut gaps into it', () async {
      final row = await topRow(const BeamShape(dashes: 12));
      final dark = row.where((level) => level <= 2).length;
      final lit = row.where((level) => level > 16).length;
      expect(dark, greaterThan(0), reason: 'no gap between dashes');
      expect(lit, greaterThan(0), reason: 'no dash');
    });
  });

  group('direction', () {
    test('reverse paints the mirror image of forward', () async {
      // Colours are fixed to perimeter positions, so only the light's shape
      // mirrors: compare coverage (alpha), on a light theme where all light
      // is blended.
      Future<RenderedFrame> at(BeamDirection direction) {
        final config = configFor(
          const BeamEffect.rotate(),
          brightness: Brightness.light,
          timing: BeamTiming(direction: direction),
        );
        return renderFrame(config, phasesAt(config, 1.3));
      }

      final forward = await at(BeamDirection.forward);
      final reverse = await at(BeamDirection.reverse);
      var compared = 0;
      var mismatched = 0;
      for (var y = 0; y < forward.height; y++) {
        for (var x = 0; x < forward.width; x++) {
          final a = forward.rgba[(y * forward.width + x) * 4 + 3];
          final mx = forward.width - 1 - x;
          final b = reverse.rgba[(y * reverse.width + mx) * 4 + 3];
          if (a == 0 && b == 0) continue;
          compared++;
          if ((a - b).abs() > 3) mismatched++;
        }
      }
      expect(compared, greaterThan(0));
      expect(
        mismatched,
        lessThan(compared * 0.01),
        reason: '$mismatched of $compared pixels are not mirrored',
      );
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
