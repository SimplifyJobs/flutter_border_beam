import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/src/models/beam_options.dart';
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
}
