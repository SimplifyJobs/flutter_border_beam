import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/src/models/beam_options.dart';
import 'package:flutter_border_beam/src/models/beam_segment.dart';
import 'package:flutter_border_beam/src/render/beam_outline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final squircle in [false, true]) {
    for (final radius in [0.0, 6.0, 16.0, 40.0, 70.0]) {
      test('round trip, squircle: $squircle, r: $radius', () {
        final o = BeamOutline(
          const Rect.fromLTWH(10, 20, 350, 140),
          BorderRadius.circular(radius),
          superellipse: squircle,
        );
        for (var i = 0; i < 400; i++) {
          final u = i / 400;
          final p = o.pointAt(u);
          final hit = o.locate(p);
          expect(hit.distance.abs(), lessThan(0.05), reason: 'u=$u d');
          final du = (hit.u - u + 0.5) % 1 - 0.5;
          expect(du.abs(), lessThan(1e-3), reason: 'u=$u got ${hit.u}');
          // A point pushed out along the normal stays at that u.
          final out = o.locate(p + o.normalAt(u) * 7);
          expect(out.distance, closeTo(7, 0.35), reason: 'u=$u out');
          final duo = (out.u - u + 0.5) % 1 - 0.5;
          expect(duo.abs(), lessThan(0.02), reason: 'u=$u out u');
        }
      });
    }
  }

  test('edges run clockwise from top-centre', () {
    final o = BeamOutline(
      const Rect.fromLTWH(0, 0, 300, 100),
      BorderRadius.circular(10),
    );
    expect(o.fractionOfEdge(BeamEdge.top, 0.5), closeTo(0, 1e-6));
    final right = o.fractionOfEdge(BeamEdge.right, 0.5);
    final bottom = o.fractionOfEdge(BeamEdge.bottom, 0.5);
    final left = o.fractionOfEdge(BeamEdge.left, 0.5);
    expect(bottom, closeTo(0.5, 1e-6));
    expect(right, lessThan(bottom));
    expect(left, greaterThan(bottom));
    expect(o.pointAt(bottom).dy, closeTo(100, 1e-6));
    expect(o.length, closeTo(2 * (280 + 80) + 2 * math.pi * 10, 1e-6));
  });

  const rect = Rect.fromLTWH(0, 0, 300, 100);

  group('radii', () {
    test('per-corner radii stay on the corners they name', () {
      final o = BeamOutline(
        rect,
        const BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomRight: Radius.circular(10),
        ),
      );
      expect(o.radii, [30, 0, 10, 0]);
      // A square corner keeps the box corner on the outline; a rounded one
      // pulls the outline away from it.
      expect(o.locate(rect.topRight).distance.abs(), lessThan(0.01));
      expect(o.locate(rect.topLeft).distance, greaterThan(5));
      expect(o.locate(rect.bottomRight).distance, greaterThan(1));
    });

    test('overflowing radii scale down the way RRect.scaleRadii does', () {
      const radius = BorderRadius.only(
        topLeft: Radius.circular(200),
        topRight: Radius.circular(200),
        bottomLeft: Radius.circular(40),
      );
      final o = BeamOutline(rect, radius);
      final scaled = radius.toRRect(rect).scaleRadii();
      expect(o.radii[0], closeTo(scaled.tlRadiusX, 1e-9));
      expect(o.radii[1], closeTo(scaled.trRadiusX, 1e-9));
      expect(o.radii[3], closeTo(scaled.blRadiusX, 1e-9));
      // Both overflowing radii shrink by the same ratio.
      expect(o.radii[0], o.radii[1]);
    });

    test('an infinite radius rounds to half the short side', () {
      final pill = BeamOutline(
        rect,
        const BorderRadius.all(Radius.circular(double.infinity)),
      );
      expect(pill.radii, everyElement(closeTo(50, 1e-9)));
      final circle = BeamOutline(
        const Rect.fromLTWH(0, 0, 80, 80),
        const BorderRadius.all(Radius.circular(double.infinity)),
      );
      expect(circle.length, closeTo(math.pi * 80, 1e-6));
      for (var i = 0; i < 64; i++) {
        final p = circle.pointAt(i / 64);
        expect((p - const Offset(40, 40)).distance, closeTo(40, 1e-6));
      }
    });

    test('superellipse corners span radius × inset, capped by the box', () {
      final o = BeamOutline(
        rect,
        BorderRadius.circular(20),
        superellipse: true,
      );
      expect(o.cornerSizes, everyElement(closeTo(20 * squircleInset, 1e-9)));
      final capped = BeamOutline(
        rect,
        BorderRadius.circular(45),
        superellipse: true,
      );
      expect(capped.cornerSizes, everyElement(closeTo(50, 1e-9)));
    });
  });

  test('the superellipse follows RoundedSuperellipseBorder', () {
    // The beam's stroke must sit on the edge of a child clipped by
    // Flutter's own superellipse, or the two visibly part at the corners.
    for (final r in [8.0, 24.0, 40.0]) {
      const box = Rect.fromLTWH(10, 10, 320, 120);
      final o = BeamOutline(box, BorderRadius.circular(r), superellipse: true);
      final path = Path()
        ..addRSuperellipse(
          RSuperellipse.fromRectAndRadius(box, Radius.circular(r)),
        );
      var sampled = 0;
      for (final metric in path.computeMetrics()) {
        for (var s = 0.0; s < metric.length; s += 2) {
          final p = metric.getTangentForOffset(s)!.position;
          expect(
            o.locate(p).distance.abs(),
            lessThan(0.02 * r + 0.05),
            reason: 'r=$r at $p',
          );
          sampled++;
        }
      }
      expect(sampled, greaterThan(100));
    }
  });

  test('distance is negative inside and positive outside', () {
    for (final squircle in [false, true]) {
      final o = BeamOutline(
        rect,
        BorderRadius.circular(20),
        superellipse: squircle,
      );
      expect(o.locate(rect.center).distance, lessThan(0));
      expect(o.locate(const Offset(150, -10)).distance, closeTo(10, 1e-6));
      expect(o.locate(const Offset(150, 10)).distance, closeTo(-10, 1e-6));
      expect(o.locate(const Offset(-5, -5)).distance, greaterThan(5));
    }
  });

  test('u runs clockwise and covers the whole perimeter', () {
    final o = BeamOutline(rect, BorderRadius.circular(24));
    var area = 0.0;
    var travelled = 0.0;
    var prev = o.pointAt(0);
    for (var i = 1; i <= 1000; i++) {
      final p = o.pointAt(i / 1000);
      // Shoelace sum: positive for clockwise in a y-down frame.
      area += prev.dx * p.dy - p.dx * prev.dy;
      travelled += (p - prev).distance;
      prev = p;
    }
    expect(area, greaterThan(0));
    expect(travelled, closeTo(o.length, 0.5));
    expect(o.pointAt(0).dx, closeTo(rect.topCenter.dx, 1e-6));
    expect(o.pointAt(0).dy, closeTo(rect.topCenter.dy, 1e-6));
  });

  test('edge and corner ranges tile the perimeter in order', () {
    final o = BeamOutline(
      rect,
      const BorderRadius.only(
        topLeft: Radius.circular(10),
        topRight: Radius.circular(30),
        bottomRight: Radius.circular(5),
      ),
    );
    final pieces = [
      o.edgeRange(BeamEdge.top),
      o.cornerRange(BeamCorner.topRight),
      o.edgeRange(BeamEdge.right),
      o.cornerRange(BeamCorner.bottomRight),
      o.edgeRange(BeamEdge.bottom),
      o.cornerRange(BeamCorner.bottomLeft),
      o.edgeRange(BeamEdge.left),
      o.cornerRange(BeamCorner.topLeft),
    ];
    var total = 0.0;
    for (var i = 0; i < pieces.length; i++) {
      final next = pieces[(i + 1) % pieces.length];
      final gap = (next.from - pieces[i].to + 0.5) % 1 - 0.5;
      expect(gap.abs(), lessThan(1e-6), reason: 'piece $i meets piece $i+1');
      total += BeamOutline.wrapFraction(pieces[i].to - pieces[i].from);
    }
    expect(total, closeTo(1, 1e-6));
    // A square corner has (next to) no curve at all.
    final bl = o.cornerRange(BeamCorner.bottomLeft);
    expect(BeamOutline.wrapFraction(bl.to - bl.from), lessThan(1e-4));
  });

  test('wrapFraction wraps into [0, 1)', () {
    expect(BeamOutline.wrapFraction(0), 0);
    expect(BeamOutline.wrapFraction(1), 0);
    expect(BeamOutline.wrapFraction(-0.25), closeTo(0.75, 1e-12));
    expect(BeamOutline.wrapFraction(3.5), closeTo(0.5, 1e-12));
  });

  test('an empty box is safe', () {
    final o = BeamOutline(Rect.zero, BorderRadius.circular(16));
    expect(o.length.isFinite, isTrue);
    expect(o.pointAt(0.3).dx.isFinite, isTrue);
    expect(o.normalAt(0.3).dx.isFinite, isTrue);
    expect(o.nearestFraction(const Offset(4, 4)).isFinite, isTrue);
  });

  test('outlines are values', () {
    BeamOutline make({bool squircle = false}) =>
        BeamOutline(rect, BorderRadius.circular(12), superellipse: squircle);
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(make(), isNot(make(squircle: true)));
    expect(
      make(),
      isNot(BeamOutline(rect.inflate(1), BorderRadius.circular(12))),
    );
  });
}
