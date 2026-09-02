import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/painting/ring_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final perimeter = BeamPerimeter(
    Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100)),
    const Rect.fromLTWH(0, 0, 100, 100),
    radii: BorderRadius.zero,
  );

  test('anchors and segments compare by value', () {
    expect(const BeamAnchor.fraction(0.25), const BeamAnchor.fraction(0.25));
    expect(
      const BeamAnchor.edge(BeamEdge.right),
      const BeamAnchor.edge(BeamEdge.right, 0.5),
    );
    expect(
      const BeamSegment(
        start: BeamAnchor.topCenter,
        end: BeamAnchor.bottomCenter,
      ),
      BeamSegment.rightHalf,
    );
    expect(BeamSegment.rightHalf, isNot(BeamSegment.leftHalf));
    expect(
      BeamSegment.rightHalf.hashCode,
      isNot(BeamSegment.leftHalf.hashCode),
    );
  });

  test('fraction anchors wrap modulo one when resolved', () {
    expect(
      const BeamAnchor.fraction(1.25).resolve(perimeter),
      closeTo(0.25, 1e-9),
    );
    expect(
      const BeamAnchor.fraction(-0.25).resolve(perimeter),
      closeTo(0.75, 1e-9),
    );
  });

  test('half presets use the documented clockwise anchors', () {
    expect(BeamSegment.bottomHalf.start, BeamAnchor.rightCenter);
    expect(BeamSegment.bottomHalf.end, BeamAnchor.leftCenter);
    expect(BeamSegment.topHalf.start, BeamAnchor.leftCenter);
    expect(BeamSegment.topHalf.end, BeamAnchor.rightCenter);
    expect(BeamSegment.leftHalf.start, BeamAnchor.bottomCenter);
    expect(BeamSegment.leftHalf.end, BeamAnchor.topCenter);
    expect(BeamSegment.rightHalf.start, BeamAnchor.topCenter);
    expect(BeamSegment.rightHalf.end, BeamAnchor.bottomCenter);
  });

  test('edge presets include both adjoining corner arcs', () {
    expect(
      BeamSegment.bottomEdge.start,
      const BeamAnchor.corner(BeamCorner.bottomRight, 0),
    );
    expect(
      BeamSegment.bottomEdge.end,
      const BeamAnchor.corner(BeamCorner.bottomLeft, 1),
    );
    expect(
      BeamSegment.topEdge.start,
      const BeamAnchor.corner(BeamCorner.topLeft, 0),
    );
    expect(
      BeamSegment.rightEdge.end,
      const BeamAnchor.corner(BeamCorner.bottomRight, 1),
    );
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
  });
}
