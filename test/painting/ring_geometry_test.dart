import 'dart:math' as math;
import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/painting/ring_geometry.dart';
import 'package:flutter_border_beam/src/painting/variant_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Per-corner ring geometry: the beam contour takes a full [BorderRadius],
/// clamps it the way `RRect.scaleRadii` does, resolves an infinite radius
/// ([BeamShape.stadium]) to half the shortest side, and derives the inner
/// contour by shrinking every corner by the border width.
///
/// Corner size is probed rather than read back: each test walks inward along
/// a corner's 45° diagonal and finds where the path starts containing
/// points. For a circular corner of radius r that entry sits at
/// `r * (sqrt2 - 1)` — the distance from the corner to the arc — which makes
/// the probe an exact measurement of the radius the geometry actually used.
void main() {
  // Distance from the corner to the shape's boundary, along the inward 45°
  // diagonal.
  double diagonalEntry(Path path, Offset corner, Offset inward, double reach) {
    expect(
      path.contains(corner + inward * reach),
      isTrue,
      reason: 'the probe must end inside the shape',
    );
    var outside = 0.0;
    var inside = reach;
    for (var i = 0; i < 60; i++) {
      final mid = (outside + inside) / 2;
      if (path.contains(corner + inward * mid)) {
        inside = mid;
      } else {
        outside = mid;
      }
    }
    return inside;
  }

  // The four corners as (point, inward unit vector) pairs.
  final diagonal = 1 / math.sqrt2;
  Map<String, (Offset, Offset)> cornersOf(Rect r) => {
    'topLeft': (r.topLeft, Offset(diagonal, diagonal)),
    'topRight': (r.topRight, Offset(-diagonal, diagonal)),
    'bottomLeft': (r.bottomLeft, Offset(diagonal, -diagonal)),
    'bottomRight': (r.bottomRight, Offset(-diagonal, -diagonal)),
  };

  // What `diagonalEntry` reads back for a circular corner of radius [r].
  double circularEntry(double r) => r * (math.sqrt2 - 1);

  BeamRingGeometry geometry(
    Rect rect,
    BorderRadius radius, {
    double borderWidth = 1,
    bool superellipse = false,
  }) => BeamRingGeometry(
    rect: rect,
    radius: radius,
    borderWidth: borderWidth,
    useSuperellipse: superellipse,
  );

  void expectBounds(Path path, Rect rect) {
    final bounds = path.getBounds();
    expect(bounds.left, closeTo(rect.left, 0.01));
    expect(bounds.top, closeTo(rect.top, 0.01));
    expect(bounds.right, closeTo(rect.right, 0.01));
    expect(bounds.bottom, closeTo(rect.bottom, 0.01));
  }

  group('per-corner radii', () {
    const rect = Rect.fromLTWH(0, 0, 200, 100);
    const radius = BorderRadius.only(
      topLeft: Radius.circular(40),
      topRight: Radius.zero,
      bottomLeft: Radius.circular(10),
      bottomRight: Radius.circular(40),
    );

    for (final superellipse in [false, true]) {
      final family = superellipse ? 'superellipse' : 'circular';

      test('$family: the outer contour still spans the whole rect', () {
        expectBounds(
          geometry(rect, radius, superellipse: superellipse).outer,
          rect,
        );
      });

      test('$family: a rounded corner drops a point a square corner keeps', () {
        final outer = geometry(rect, radius, superellipse: superellipse).outer;
        // The same offset from each corner: cut away where the radius is
        // large, kept where the corner is square.
        expect(
          outer.contains(const Offset(3, 3)),
          isFalse,
          reason: 'inside the 40px topLeft corner',
        );
        expect(
          outer.contains(const Offset(197, 3)),
          isTrue,
          reason: 'the topRight corner is square',
        );
        expect(
          outer.contains(const Offset(197, 97)),
          isFalse,
          reason: 'inside the 40px bottomRight corner',
        );
        expect(
          outer.contains(const Offset(100, 50)),
          isTrue,
          reason: 'the middle is always inside',
        );
      });
    }

    test('circular: every corner measures the radius it was given', () {
      final outer = geometry(rect, radius).outer;
      final corners = cornersOf(rect);
      double entryAt(String corner) {
        final (point, inward) = corners[corner]!;
        return diagonalEntry(outer, point, inward, 50);
      }

      expect(entryAt('topLeft'), closeTo(circularEntry(40), 0.05));
      expect(entryAt('topRight'), lessThan(0.05), reason: 'a square corner');
      expect(entryAt('bottomLeft'), closeTo(circularEntry(10), 0.05));
      expect(entryAt('bottomRight'), closeTo(circularEntry(40), 0.05));
    });

    test('superellipse: corner size still follows the per-corner radii', () {
      final outer = geometry(rect, radius, superellipse: true).outer;
      final corners = cornersOf(rect);
      double entryAt(String corner) {
        final (point, inward) = corners[corner]!;
        return diagonalEntry(outer, point, inward, 50);
      }

      expect(entryAt('topRight'), lessThan(0.05), reason: 'a square corner');
      expect(entryAt('topLeft'), closeTo(entryAt('bottomRight'), 0.05));
      expect(
        entryAt('topLeft'),
        greaterThan(entryAt('bottomLeft')),
        reason: '40px cuts deeper than 10px',
      );
    });
  });

  group('scaleRadii clamping', () {
    // 80 + 40 on a 100px top edge: both scale by 100/120, keeping their 2:1
    // proportion instead of one being clipped.
    const rect = Rect.fromLTWH(0, 0, 100, 100);
    const radius = BorderRadius.only(
      topLeft: Radius.circular(80),
      topRight: Radius.circular(40),
    );
    const scale = 100 / 120;

    test('matches what RRect.scaleRadii would produce', () {
      final reference = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(80),
        topRight: const Radius.circular(40),
      ).scaleRadii();
      expect(reference.tlRadiusX, closeTo(80 * scale, 1e-9));
      expect(reference.trRadiusX, closeTo(40 * scale, 1e-9));

      final outer = geometry(rect, radius).outer;
      final corners = cornersOf(rect);
      final (tlPoint, tlInward) = corners['topLeft']!;
      final (trPoint, trInward) = corners['topRight']!;
      expect(
        diagonalEntry(outer, tlPoint, tlInward, 50),
        closeTo(circularEntry(80 * scale), 0.05),
      );
      expect(
        diagonalEntry(outer, trPoint, trInward, 50),
        closeTo(circularEntry(40 * scale), 0.05),
      );
    });

    test('both radii shrink by the same ratio', () {
      final outer = geometry(rect, radius).outer;
      final corners = cornersOf(rect);
      final (tlPoint, tlInward) = corners['topLeft']!;
      final (trPoint, trInward) = corners['topRight']!;
      final tl = diagonalEntry(outer, tlPoint, tlInward, 50);
      final tr = diagonalEntry(outer, trPoint, trInward, 50);
      expect(tl / tr, closeTo(2, 0.02), reason: 'the 2:1 proportion survives');
    });

    test('superellipse clamps too and stays inside the rect', () {
      final outer = geometry(rect, radius, superellipse: true).outer;
      expectBounds(outer, rect);
      final corners = cornersOf(rect);
      final (tlPoint, tlInward) = corners['topLeft']!;
      final (trPoint, trInward) = corners['topRight']!;
      final tl = diagonalEntry(outer, tlPoint, tlInward, 50);
      final tr = diagonalEntry(outer, trPoint, trInward, 50);
      expect(tl, greaterThan(tr));
      expect(
        tl,
        lessThan(circularEntry(80) * 1.6),
        reason: 'an unclamped 80px corner would cut deeper',
      );
    });
  });

  group('stadium (infinite radius)', () {
    const infinite = BorderRadius.all(Radius.circular(double.infinity));

    test('a 200x40 rect resolves to a 20px radius on every corner', () {
      const rect = Rect.fromLTWH(0, 0, 200, 40);
      final outer = geometry(rect, infinite).outer;
      expectBounds(outer, rect);
      for (final MapEntry(key: name, value: (point, inward)) in cornersOf(
        rect,
      ).entries) {
        expect(
          diagonalEntry(outer, point, inward, 20),
          closeTo(circularEntry(20), 0.05),
          reason: name,
        );
      }
      expect(outer.contains(const Offset(1, 1)), isFalse, reason: 'pill end');
      expect(
        outer.contains(const Offset(100, 1)),
        isTrue,
        reason: 'the straight top edge',
      );
    });

    test('the radius tracks the box as it resizes', () {
      const tall = Rect.fromLTWH(0, 0, 200, 100);
      final corners = cornersOf(tall);
      final (point, inward) = corners['topLeft']!;
      expect(
        diagonalEntry(geometry(tall, infinite).outer, point, inward, 60),
        closeTo(circularEntry(50), 0.05),
        reason: 'half the 100px short side',
      );
    });

    test('a square box comes out a circle', () {
      const square = Rect.fromLTWH(0, 0, 80, 80);
      final outer = geometry(square, infinite).outer;
      // Every point at radius 40 from the centre is on the boundary: just
      // inside is contained, just outside is not.
      for (final angle in [0.0, 0.7, 1.9, 3.4, 5.2]) {
        final unit = Offset(math.cos(angle), math.sin(angle));
        expect(outer.contains(const Offset(40, 40) + unit * 39), isTrue);
        expect(outer.contains(const Offset(40, 40) + unit * 41), isFalse);
      }
    });

    test('superellipse stadium is symmetric across all four corners', () {
      const rect = Rect.fromLTWH(0, 0, 200, 40);
      final outer = geometry(rect, infinite, superellipse: true).outer;
      expectBounds(outer, rect);
      final entries = [
        for (final (point, inward) in cornersOf(rect).values)
          diagonalEntry(outer, point, inward, 20),
      ];
      for (final entry in entries) {
        expect(entry, closeTo(entries.first, 0.05));
      }
      expect(entries.first, greaterThan(0));
    });
  });

  group('inner contour', () {
    const rect = Rect.fromLTWH(0, 0, 200, 100);

    test('every corner shrinks by the border width', () {
      const radius = BorderRadius.only(
        topLeft: Radius.circular(40),
        bottomRight: Radius.circular(12),
      );
      final ring = geometry(rect, radius, borderWidth: 5);
      final inner = rect.deflate(5);
      expectBounds(ring.inner, inner);
      final corners = cornersOf(inner);
      final (tlPoint, tlInward) = corners['topLeft']!;
      final (brPoint, brInward) = corners['bottomRight']!;
      expect(
        diagonalEntry(ring.inner, tlPoint, tlInward, 50),
        closeTo(circularEntry(35), 0.05),
      );
      expect(
        diagonalEntry(ring.inner, brPoint, brInward, 50),
        closeTo(circularEntry(7), 0.05),
      );
    });

    test('a corner smaller than the border width floors at square', () {
      const radius = BorderRadius.all(Radius.circular(3));
      final ring = geometry(rect, radius, borderWidth: 5);
      final corners = cornersOf(rect.deflate(5));
      final (point, inward) = corners['topLeft']!;
      expect(diagonalEntry(ring.inner, point, inward, 20), lessThan(0.05));
    });

    test('a box thinner than twice the border has no inner contour', () {
      const sliver = Rect.fromLTWH(0, 0, 200, 8);
      final ring = geometry(sliver, BorderRadius.circular(4), borderWidth: 5);
      expect(ring.inner.getBounds().isEmpty, isTrue);
      expect(
        ring.ring.contains(const Offset(100, 4)),
        isTrue,
        reason: 'the ring is then the whole shape',
      );
    });

    test('the ring is the band between the two contours', () {
      final ring = geometry(rect, BorderRadius.circular(16), borderWidth: 4);
      expect(ring.ring.contains(const Offset(100, 2)), isTrue);
      expect(ring.ring.contains(const Offset(100, 50)), isFalse);
    });

    test('an empty rect has no ring at all', () {
      final ring = geometry(Rect.zero, BorderRadius.circular(8));
      expect(ring.ring.getBounds().isEmpty, isTrue);
      expect(ring.outer.getBounds().isEmpty, isTrue);
    });
  });

  group('contour', () {
    test('builds an arbitrary rect in the same shape family', () {
      const rect = Rect.fromLTWH(0, 0, 200, 100);
      final ring = geometry(rect, BorderRadius.circular(16));
      const other = Rect.fromLTWH(10, 10, 100, 60);
      final path = ring.shapeContour(other, BorderRadius.circular(20));
      expectBounds(path, other);
      final corners = cornersOf(other);
      final (point, inward) = corners['topLeft']!;
      expect(
        diagonalEntry(path, point, inward, 30),
        closeTo(circularEntry(20), 0.05),
      );
    });
  });

  group('segment integration', () {
    const rect = Rect.fromLTWH(0, 0, 200, 100);

    for (final superellipse in [false, true]) {
      test('${superellipse ? 'superellipse' : 'rrect'} band and weight', () {
        final geometry = BeamRingGeometry(
          rect: rect,
          radius: BorderRadius.circular(20),
          borderWidth: 2,
          useSuperellipse: superellipse,
          segment: BeamSegment.bottomHalf,
        );
        expect(geometry.segmentRange?.from, closeTo(0.25, 0.02));
        expect(geometry.segmentRange?.to, closeTo(0.75, 0.02));
        expect(
          geometry.segmentBand(inward: 3, outward: 3).getBounds().top,
          greaterThan(35),
        );
        expect(geometry.segmentWeightAt(0.5), 1);
        expect(geometry.segmentWeightAt(0), 0);
      });
    }

    test('no segment leaves band and weight neutral', () {
      final geometry = BeamRingGeometry(
        rect: rect,
        radius: BorderRadius.circular(20),
        borderWidth: 2,
        useSuperellipse: false,
      );
      expect(geometry.segmentRange, isNull);
      expect(geometry.segmentBand(inward: 2, outward: 2).getBounds(), rect);
      expect(geometry.segmentWeightAt(0.9), 1);
    });
  });

  group('beamGeometry memo', () {
    BeamConfig config({double radius = 12}) => BeamConfig.resolve(
      variant: BeamVariant.rotate,
      palette: BeamColors.colorful.resolve(),
      brightness: Brightness.dark,
      shape: BeamShape.circular(radius, segment: BeamSegment.bottomHalf),
    );

    test('equal rect and config return the identical geometry', () {
      const rect = Rect.fromLTWH(0, 0, 180, 80);
      final first = beamGeometry(rect, config());
      final second = beamGeometry(rect, config());
      expect(identical(first, second), isTrue);
    });

    test('a changed rect or config returns new geometry', () {
      const rect = Rect.fromLTWH(0, 0, 180, 80);
      final baseConfig = config();
      final first = beamGeometry(rect, baseConfig);
      expect(
        identical(
          first,
          beamGeometry(const Rect.fromLTWH(0, 0, 181, 80), baseConfig),
        ),
        isFalse,
      );
      expect(identical(first, beamGeometry(rect, config(radius: 13))), isFalse);
    });
  });
}
