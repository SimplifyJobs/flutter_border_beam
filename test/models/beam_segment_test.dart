import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/render/beam_outline.dart';

/// Distance between two perimeter coordinates around the ring.
double _ringDistance(double a, double b) => ((a - b + 0.5) % 1 - 0.5).abs();

/// [BeamAnchor]s and [BeamSegment]s resolve to perimeter coordinates on a
/// [BeamOutline]: `u` in `[0, 1)`, 0 at top-centre, clockwise by arc length.
void main() {
  const rect = Rect.fromLTWH(0, 0, 200, 100);
  const radius = 12.0;

  for (final superellipse in [false, true]) {
    group(superellipse ? 'superellipse outline' : 'circular outline', () {
      final outline = BeamOutline(
        rect,
        BorderRadius.circular(radius),
        superellipse: superellipse,
      );
      // How far the corner curve reaches along each edge.
      final corner = outline.cornerSizes.first;

      void expectAt(BeamAnchor anchor, Offset point, {String? reason}) {
        final u = anchor.resolve(outline);
        expect(u, inInclusiveRange(0, 1), reason: reason ?? '$anchor');
        expect(u, lessThan(1), reason: reason ?? '$anchor');
        final p = outline.pointAt(u);
        expect(p.dx, closeTo(point.dx, 1e-3), reason: reason ?? '$anchor');
        expect(p.dy, closeTo(point.dy, 1e-3), reason: reason ?? '$anchor');
      }

      test('the named anchors sit at the centre of each side', () {
        expectAt(BeamAnchor.topCenter, rect.topCenter);
        expectAt(BeamAnchor.rightCenter, rect.centerRight);
        expectAt(BeamAnchor.bottomCenter, rect.bottomCenter);
        expectAt(BeamAnchor.leftCenter, rect.centerLeft);
      });

      test('edge centres run clockwise from top-centre', () {
        final top = BeamAnchor.topCenter.resolve(outline);
        final right = BeamAnchor.rightCenter.resolve(outline);
        final bottom = BeamAnchor.bottomCenter.resolve(outline);
        final left = BeamAnchor.leftCenter.resolve(outline);
        expect(_ringDistance(top, 0), lessThan(1e-6));
        expect(right, greaterThan(0));
        expect(right, lessThan(bottom));
        expect(bottom, closeTo(0.5, 1e-6), reason: 'a symmetric box');
        expect(left, greaterThan(bottom));
        expect(left, lessThan(1));
      });

      test('edge anchors travel clockwise along the straight run', () {
        // Top: left to right.
        expectAt(
          const BeamAnchor.edge(BeamEdge.top, 0),
          Offset(rect.left + corner, rect.top),
        );
        expectAt(
          const BeamAnchor.edge(BeamEdge.top, 1),
          Offset(rect.right - corner, rect.top),
        );
        // Right: top to bottom.
        expectAt(
          const BeamAnchor.edge(BeamEdge.right, 0),
          Offset(rect.right, rect.top + corner),
        );
        // Bottom: right to left.
        expectAt(
          const BeamAnchor.edge(BeamEdge.bottom, 0),
          Offset(rect.right - corner, rect.bottom),
        );
        expectAt(
          const BeamAnchor.edge(BeamEdge.bottom, 0.25),
          Offset(rect.right - corner - (rect.width - 2 * corner) / 4, 100),
        );
        // Left: bottom to top.
        expectAt(
          const BeamAnchor.edge(BeamEdge.left, 1),
          Offset(rect.left, rect.top + corner),
        );
      });

      test('corner anchors span the curve between two edges', () {
        for (final (c, before, after) in const [
          (BeamCorner.topLeft, BeamEdge.left, BeamEdge.top),
          (BeamCorner.topRight, BeamEdge.top, BeamEdge.right),
          (BeamCorner.bottomRight, BeamEdge.right, BeamEdge.bottom),
          (BeamCorner.bottomLeft, BeamEdge.bottom, BeamEdge.left),
        ]) {
          final start = BeamAnchor.corner(c, 0).resolve(outline);
          final end = BeamAnchor.corner(c, 1).resolve(outline);
          final mid = BeamAnchor.corner(c).resolve(outline);
          expect(
            _ringDistance(start, BeamAnchor.edge(before, 1).resolve(outline)),
            lessThan(1e-9),
            reason: '$c starts where $before ends',
          );
          expect(
            _ringDistance(end, BeamAnchor.edge(after, 0).resolve(outline)),
            lessThan(1e-9),
            reason: '$c ends where $after starts',
          );
          // The midpoint is halfway along the arc, clockwise.
          expect(
            _ringDistance(mid, start),
            closeTo(_ringDistance(end, start) / 2, 1e-9),
            reason: '$c midpoint',
          );
          // And it is off both edges: inside the corner box.
          final p = outline.pointAt(mid);
          expect(
            math.min(
              math.min(p.dx - rect.left, rect.right - p.dx),
              math.min(p.dy - rect.top, rect.bottom - p.dy),
            ),
            greaterThan(0.1),
            reason: '$c midpoint leaves the straight runs',
          );
        }
      });

      test('fraction anchors wrap modulo one', () {
        double at(double t) => BeamAnchor.fraction(t).resolve(outline);
        expect(at(0.25), closeTo(0.25, 1e-12));
        expect(at(1.25), closeTo(0.25, 1e-12));
        expect(at(-0.25), closeTo(0.75, 1e-12));
        expect(at(1), 0);
        expect(at(-3), 0);
      });

      test('edge and corner positions are clamped to their run', () {
        // A fraction wraps, but t past an edge's ends stays on that edge.
        expect(
          const BeamAnchor.edge(BeamEdge.right, 1.5).resolve(outline),
          const BeamAnchor.edge(BeamEdge.right, 1).resolve(outline),
        );
        expect(
          const BeamAnchor.corner(BeamCorner.topLeft, -1).resolve(outline),
          const BeamAnchor.corner(BeamCorner.topLeft, 0).resolve(outline),
        );
      });

      test('the half segments run between opposite side centres', () {
        final top = BeamAnchor.topCenter.resolve(outline);
        final right = BeamAnchor.rightCenter.resolve(outline);
        final bottom = BeamAnchor.bottomCenter.resolve(outline);
        final left = BeamAnchor.leftCenter.resolve(outline);

        final bottomHalf = BeamSegment.bottomHalf.resolve(outline);
        expect(bottomHalf.from, closeTo(right, 1e-12));
        expect(bottomHalf.to, closeTo(left, 1e-12));
        expect(bottomHalf.to, greaterThan(bottomHalf.from));

        final topHalf = BeamSegment.topHalf.resolve(outline);
        expect(topHalf.from, closeTo(left, 1e-12));
        expect(topHalf.to, closeTo(right, 1e-12));
        expect(
          topHalf.to,
          lessThan(topHalf.from),
          reason: 'wraps through top-centre',
        );

        final rightHalf = BeamSegment.rightHalf.resolve(outline);
        expect(_ringDistance(rightHalf.from, top), lessThan(1e-6));
        expect(rightHalf.to, closeTo(bottom, 1e-12));

        final leftHalf = BeamSegment.leftHalf.resolve(outline);
        expect(leftHalf.from, closeTo(bottom, 1e-12));
        expect(_ringDistance(leftHalf.to, top), lessThan(1e-6));

        // On a symmetric box each half is half the perimeter.
        for (final s in [bottomHalf, topHalf, rightHalf, leftHalf]) {
          expect((s.to - s.from) % 1, closeTo(0.5, 1e-6));
        }
      });

      test('the edge segments cover one straight run and both corners', () {
        // One corner curve's share of the perimeter.
        final arc = outline.cornerArcs.first / outline.length;
        final horizontal = (rect.width - 2 * corner) / outline.length;
        final vertical = (rect.height - 2 * corner) / outline.length;
        for (final (segment, run) in [
          (BeamSegment.topEdge, horizontal),
          (BeamSegment.bottomEdge, horizontal),
          (BeamSegment.leftEdge, vertical),
          (BeamSegment.rightEdge, vertical),
        ]) {
          final r = segment.resolve(outline);
          expect(
            (r.to - r.from) % 1,
            closeTo(run + 2 * arc, 1e-6),
            reason: '$segment',
          );
        }
        // The bottom edge contains bottom-centre; the top edge contains 0.
        final bottomEdge = BeamSegment.bottomEdge.resolve(outline);
        expect(bottomEdge.from, lessThan(0.5));
        expect(bottomEdge.to, greaterThan(0.5));
        final topEdge = BeamSegment.topEdge.resolve(outline);
        expect(topEdge.to, lessThan(topEdge.from));
      });
    });
  }

  test('edge anchors follow per-corner radii', () {
    final outline = BeamOutline(
      rect,
      const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(30),
      ),
    );
    final mid = outline.pointAt(
      const BeamAnchor.edge(BeamEdge.top).resolve(outline),
    );
    // Halfway between the end of the top-left arc and the start of the
    // top-right one, not the box's centre.
    expect(mid.dx, closeTo((4 + (200 - 30)) / 2, 1e-3));
    expect(mid.dy, closeTo(0, 1e-3));
  });

  group('equality and toString', () {
    test('anchors compare by value, defaults included', () {
      // The right-hand sides are built at run time: two equal const
      // expressions are one canonical instance, and `==` would never get
      // past `identical`.
      final quarter = BeamAnchor.fraction(double.parse('0.25'));
      expect(const BeamAnchor.fraction(0.25), quarter);
      expect(const BeamAnchor.fraction(0.25).hashCode, quarter.hashCode);
      expect(
        const BeamAnchor.edge(BeamEdge.right),
        BeamAnchor.edge(BeamEdge.right, double.parse('0.5')),
      );
      expect(
        const BeamAnchor.corner(BeamCorner.topLeft),
        BeamAnchor.corner(BeamCorner.topLeft, double.parse('0.5')),
      );
      expect(BeamAnchor.rightCenter, const BeamAnchor.edge(BeamEdge.right));
      expect(BeamAnchor.topCenter, const BeamAnchor.fraction(0));
    });

    test('kind, side and position all count', () {
      const anchors = [
        BeamAnchor.fraction(0.5),
        BeamAnchor.fraction(0.6),
        BeamAnchor.edge(BeamEdge.bottom),
        BeamAnchor.edge(BeamEdge.top),
        BeamAnchor.edge(BeamEdge.bottom, 0.4),
        BeamAnchor.corner(BeamCorner.bottomLeft),
        BeamAnchor.corner(BeamCorner.topRight),
        BeamAnchor.corner(BeamCorner.bottomLeft, 0.2),
      ];
      for (var i = 0; i < anchors.length; i++) {
        for (var j = i + 1; j < anchors.length; j++) {
          expect(anchors[i], isNot(anchors[j]));
        }
      }
    });

    test('segments compare start, end and feather', () {
      final rightHalf = BeamSegment(
        start: BeamAnchor.fraction(double.parse('0')),
        end: BeamAnchor.edge(BeamEdge.bottom, double.parse('0.5')),
      );
      expect(identical(rightHalf, BeamSegment.rightHalf), isFalse);
      expect(rightHalf, BeamSegment.rightHalf);
      expect(rightHalf.hashCode, BeamSegment.rightHalf.hashCode);
      expect(BeamSegment.rightHalf, isNot(BeamSegment.leftHalf));
      expect(
        const BeamSegment(
          start: BeamAnchor.topCenter,
          end: BeamAnchor.bottomCenter,
          feather: 0,
        ),
        isNot(BeamSegment.rightHalf),
      );
      expect(BeamSegment.rightHalf.feather, greaterThan(0));
    });

    test('toString exposes the complete value', () {
      expect(
        const BeamSegment(
          start: BeamAnchor.fraction(0.1),
          end: BeamAnchor.edge(BeamEdge.bottom),
          feather: 8,
        ).toString(),
        'BeamSegment(start: BeamAnchor.fraction(0.1), end: '
        'BeamAnchor.edge(BeamEdge.bottom, 0.5), feather: 8.0)',
      );
      expect(
        const BeamAnchor.corner(BeamCorner.topLeft, 0).toString(),
        'BeamAnchor.corner(BeamCorner.topLeft, 0.0)',
      );
    });
  });
}
