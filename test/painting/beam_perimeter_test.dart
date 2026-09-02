import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/painting/ring_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 200, 100);
  const radii = BorderRadius.all(Radius.circular(20));

  BeamPerimeter rounded({bool superellipse = false}) {
    final geometry = BeamRingGeometry(
      rect: rect,
      radius: radii,
      borderWidth: 1,
      useSuperellipse: superellipse,
    );
    return geometry.perimeter;
  }

  test('measures and aligns a rounded rectangle clockwise', () {
    final perimeter = rounded();
    final analytic = 2 * (160 + 60) + 2 * math.pi * 20;
    expect(perimeter.length, closeTo(analytic, analytic * 0.01));
    expect(perimeter.pointAt(0), within(distance: 0.5, from: rect.topCenter));
    expect(
      perimeter.pointAt(0.5),
      within(distance: 0.5, from: rect.bottomCenter),
    );
    expect(perimeter.pointAt(0.25).dx, closeTo(rect.right, 1));
    expect(perimeter.pointAt(0.25).dy, inInclusiveRange(20, 80));
    expect(perimeter.pointAt(0.75).dx, closeTo(rect.left, 1));
    expect(perimeter.tangentAt(0).dx, closeTo(1, 0.02));
    expect(perimeter.normalAt(0).dy, closeTo(-1, 0.02));
    expect(perimeter.offsetPointAt(0, 5).dy, closeTo(5, 0.5));
  });

  test('resolves straight edges and corner arcs', () {
    final perimeter = rounded();
    expect(perimeter.fractionOfEdge(BeamEdge.right, 0.5), closeTo(0.25, 0.01));
    expect(perimeter.fractionOfEdge(BeamEdge.bottom, 0.5), closeTo(0.5, 0.01));
    expect(perimeter.fractionOfEdge(BeamEdge.left, 0.5), closeTo(0.75, 0.01));
    final corner = perimeter.fractionOfCorner(BeamCorner.topRight, 0.5);
    final topEnd = perimeter.fractionOfEdge(BeamEdge.top, 1);
    final rightStart = perimeter.fractionOfEdge(BeamEdge.right, 0);
    expect(corner, greaterThan(topEnd));
    expect(corner, lessThan(rightStart));
  });

  test('nearestFraction recovers sampled points', () {
    final perimeter = rounded();
    for (final fraction in [0.03, 0.2, 0.49, 0.72, 0.94]) {
      expect(
        perimeter.nearestFraction(perimeter.pointAt(fraction)),
        closeTo(fraction, 0.002),
      );
    }
  });

  test('alignment works for square, wide, and superellipse contours', () {
    final squareRect = const Rect.fromLTWH(10, 20, 100, 100);
    final square = BeamPerimeter(
      Path()..addRRect(
        RRect.fromRectAndRadius(squareRect, const Radius.circular(12)),
      ),
      squareRect,
      radii: const BorderRadius.all(Radius.circular(12)),
    );
    expect(
      square.pointAt(0),
      within(distance: 0.5, from: squareRect.topCenter),
    );
    expect(rounded().pointAt(0.25).dx, closeTo(rect.right, 1));
    expect(
      rounded(superellipse: true).pointAt(0),
      within(distance: 0.7, from: rect.topCenter),
    );
  });

  test('counter-clockwise source paths are flipped', () {
    final path = Path()
      ..moveTo(rect.topCenter.dx, rect.topCenter.dy)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right, rect.top)
      ..close();
    final perimeter = BeamPerimeter(path, rect, radii: BorderRadius.zero);
    expect(perimeter.pointAt(0), within(distance: 0.5, from: rect.topCenter));
    expect(perimeter.tangentAt(0).dx, closeTo(1, 0.01));
    expect(perimeter.pointAt(0.25).dx, closeTo(rect.right, 1));
  });

  test('bands select lower and wrapping upper halves', () {
    final perimeter = rounded();
    final lower = perimeter.band(from: 0.25, to: 0.75, inward: 4, outward: 4);
    final upper = perimeter.band(from: 0.75, to: 0.25, inward: 4, outward: 4);
    expect(lower.getBounds().top, greaterThan(40));
    expect(lower.getBounds().bottom, greaterThan(rect.bottom));
    expect(upper.getBounds().top, lessThan(rect.top));
    expect(upper.getBounds().bottom, lessThan(60));
  });

  test('weightAt feathers, wraps, and clamps overlapping ramps', () {
    final perimeter = rounded();
    double weight(double f) =>
        perimeter.weightAt(f, from: 0.25, to: 0.75, featherFraction: 0.1);
    expect(weight(0.1), 0);
    expect(weight(0.5), 1);
    expect(weight(0.3), closeTo(0.5, 1e-9));
    expect(perimeter.weightAt(0, from: 0.75, to: 0.25, featherFraction: 0), 1);
    expect(
      perimeter.weightAt(0.225, from: 0.2, to: 0.3, featherFraction: 0.2),
      closeTo(0.5, 1e-9),
    );
  });

  test('zero-length paths are safe', () {
    final perimeter = BeamPerimeter(Path(), rect);
    expect(perimeter.length, 0);
    expect(perimeter.pointAt(0.5), rect.topCenter);
    expect(perimeter.tangentAt(0.5), Offset.zero);
    expect(perimeter.normalAt(0.5), Offset.zero);
    expect(perimeter.nearestFraction(const Offset(20, 20)), 0);
    expect(perimeter.featherFractionFor(20), 0);
    expect(
      perimeter.band(from: 0, to: 1, inward: 1, outward: 1).getBounds().isEmpty,
      isTrue,
    );
  });
}
