import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/border_beam/render/beam_frame.dart';
import 'package:prismatic/src/border_beam/render/beam_outline.dart';
import 'package:prismatic/src/border_beam/render/beam_program.dart';

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

    test('superellipse corners reach radius × squircleReach along each '
        'edge, capped at half that side', () {
      final o = BeamOutline(
        rect,
        BorderRadius.circular(16),
        superellipse: true,
      );
      expect(o.cornerSizes, everyElement(closeTo(16 * squircleReach, 1e-9)));
      // A pill's corners take the full height but still ease into the long
      // edges: each side caps the reach separately.
      final pill = BeamOutline(
        const Rect.fromLTWH(0, 0, 270, 56),
        BorderRadius.circular(28),
        superellipse: true,
      );
      expect(pill.cornerSizes, everyElement(closeTo(28 * squircleReach, 1e-9)));
      final top = pill.edgeRange(BeamEdge.top);
      expect(pill.pointAt(top.to).dx, closeTo(270 - 28 * squircleReach, 1e-6));
      expect(pill.pointAt(top.to).dy, closeTo(0, 1e-9));
      final right = pill.edgeRange(BeamEdge.right);
      expect(BeamOutline.wrapFraction(right.to - right.from), lessThan(1e-9));
    });
  });

  group("the superellipse is Flutter's RSuperellipse", () {
    // The beam's stroke must sit on the edge of a child clipped or decorated
    // by RoundedSuperellipseBorder with the same radii, at every aspect
    // ratio: Flutter's corner changes shape as the radius nears half the
    // side, so one fixed corner curve parts from it on pills and circles.
    final shapes = <String, (Rect, BorderRadius)>{
      'card r8': (const Rect.fromLTWH(10, 10, 300, 200), _r(8)),
      'card r24': (const Rect.fromLTWH(10, 10, 300, 200), _r(24)),
      'wide card r16': (const Rect.fromLTWH(0, 0, 350, 140), _r(16)),
      'large card r4': (const Rect.fromLTWH(0, 0, 1000, 600), _r(4)),
      'square r16': (const Rect.fromLTWH(0, 0, 100, 100), _r(16)),
      'r = 0.3 short side': (const Rect.fromLTWH(0, 0, 300, 200), _r(60)),
      'r = 0.4 short side': (const Rect.fromLTWH(0, 0, 300, 200), _r(80)),
      'square, r = 0.4 side': (const Rect.fromLTWH(0, 0, 200, 200), _r(80)),
      'chip, r = 0.4 short side': (const Rect.fromLTWH(0, 0, 120, 60), _r(24)),
      'pill 270×56': (const Rect.fromLTWH(0, 0, 270, 56), _r(28)),
      // BeamShape.stadium: Flutter spells the same pill with half the
      // short side (it reads an infinite radius as no radius at all).
      'stadium pill': (const Rect.fromLTWH(0, 0, 270, 56), _stadium),
      'stadium circle': (const Rect.fromLTWH(0, 0, 120, 120), _stadium),
      'thin pill 300×40': (const Rect.fromLTWH(0, 0, 300, 40), _r(20)),
      'short pill 70×56': (const Rect.fromLTWH(0, 0, 70, 56), _r(28)),
      'tall pill 56×270': (const Rect.fromLTWH(0, 0, 56, 270), _r(28)),
      'stadium 200×100': (const Rect.fromLTWH(0, 0, 200, 100), _r(50)),
      'circle 56': (const Rect.fromLTWH(0, 0, 56, 56), _r(28)),
      'circle 200': (const Rect.fromLTWH(0, 0, 200, 200), _r(100)),
      'uneven radii': (
        const Rect.fromLTWH(0, 0, 300, 180),
        const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(8),
          bottomLeft: Radius.circular(20),
        ),
      ),
      'chat bubble': (
        const Rect.fromLTWH(0, 0, 200, 60),
        const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
        ),
      ),
    };

    for (final MapEntry(key: name, value: (box, radius)) in shapes.entries) {
      test("$name: the outline lies on Flutter's path", () {
        final o = BeamOutline(box, radius, superellipse: true);
        final flutter = _flutterOutline(box, radius);
        // Flutter's points are on the outline...
        var worst = 0.0;
        for (final p in flutter) {
          worst = math.max(worst, o.locate(p).distance.abs());
        }
        // ...and the outline's points are on Flutter's path. Flutter's own
        // path approximates its curve with conics to within ~0.06 px here.
        for (var i = 0; i < 1500; i++) {
          worst = math.max(worst, _distanceTo(flutter, o.pointAt(i / 1500)));
        }
        expect(worst, lessThan(0.1), reason: name);
      });
    }

    test('inside and outside agree with RSuperellipse.contains', () {
      for (final MapEntry(key: name, value: (box, radius)) in shapes.entries) {
        final o = BeamOutline(box, radius, superellipse: true);
        final rse = _flutterRadius(box, radius).toRSuperellipse(box);
        for (var y = box.top - 3; y <= box.bottom + 3; y += 1.5) {
          for (var x = box.left - 3; x <= box.right + 3; x += 1.5) {
            final p = Offset(x, y);
            final d = o.locate(p).distance;
            if (d.abs() < 0.1) continue;
            expect(d < 0, rse.contains(p), reason: '$name at $p (d = $d)');
          }
        }
      }
    });

    test('distance is continuous near the border, inside and out', () {
      // A soft glow or inset shadow shades by the distance tens of px from
      // the stroke; a step where the curve's pieces meet would show as a
      // seam. Neighbouring samples may differ by at most their spacing.
      for (final name in ['card r24', 'r = 0.4 short side', 'pill 270×56']) {
        final (box, radius) = shapes[name]!;
        final o = BeamOutline(box, radius, superellipse: true);
        const step = 0.5;
        final corner = box.topRight;
        double at(double x, double y) => o.locate(Offset(x, y)).distance;
        for (var y = corner.dy - 30; y <= corner.dy + 60; y += step) {
          for (var x = corner.dx - 160; x <= corner.dx + 30; x += step) {
            final d = at(x, y);
            if (d < -20 || d > 30) continue;
            expect(
              (at(x + step, y) - d).abs(),
              lessThan(step + 0.02),
              reason: '$name at ($x, $y)',
            );
            expect(
              (at(x, y + step) - d).abs(),
              lessThan(step + 0.02),
              reason: '$name at ($x, $y)',
            );
          }
        }
      }
    });

    test('distance off the border matches the nearest point of the path', () {
      for (final name in ['card r24', 'pill 270×56', 'circle 56']) {
        final (box, radius) = shapes[name]!;
        final o = BeamOutline(box, radius, superellipse: true);
        final flutter = _flutterOutline(box, radius);
        for (var i = 0; i < 200; i++) {
          final u = i / 200;
          for (final offset in [-12.0, -4.0, 4.0, 12.0, 24.0]) {
            final p = o.pointAt(u) + o.normalAt(u) * offset;
            expect(
              o.locate(p).distance,
              closeTo(offset.sign * _distanceTo(flutter, p), 0.2),
              reason: '$name u=$u offset $offset',
            );
          }
        }
      }
    });
  });

  group("the shader's outline() is BeamOutline", () {
    // Rule 3: the GPU and the CPU must agree on where the outline is, or
    // lights placed along it on the CPU drift off the stroke the GPU draws.
    // A filled layer's anti-aliased edge encodes the shader's distance:
    // alpha = 0.5 − d / px.
    setUpAll(BorderBeam.precache);

    final shapes = <String, (Size, BorderRadius)>{
      'pill': (const Size(270, 56), _r(28)),
      'card': (const Size(300, 200), _r(24)),
      'r = 0.4 short side': (const Size(300, 200), _r(80)),
      'circle': (const Size(120, 120), _r(60)),
      'uneven radii': (
        const Size(300, 180),
        const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(8),
          bottomLeft: Radius.circular(20),
        ),
      ),
    };

    for (final superellipse in [false, true]) {
      for (final MapEntry(key: name, value: (size, radius)) in shapes.entries) {
        test('$name, superellipse: $superellipse', () async {
          // An iPhone's 3x, where a few device px of gap show.
          const scale = 3.0;
          const margin = 6.0;
          final box = const Offset(margin, margin) & size;
          final o = BeamOutline(box, radius, superellipse: superellipse);
          final frame = BeamFrameData()
            ..reset()
            ..setOutline(o, 1, 1 / scale)
            ..setLayer(0, BeamGeometry.fill, opacity: 1)
            ..setTable(BeamTable.overlayA, const [0, 1], const [1, 1], 2)
            ..setOverlay(0, BeamTable.overlayA, white: true)
            ..finish();
          final shader = beamProgram.program!.fragmentShader();
          for (var i = 0; i < beamUniformFloats; i++) {
            shader.setFloat(i, frame.data[i]);
          }
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder)
            ..scale(scale)
            ..drawRect(box.inflate(margin), ui.Paint()..shader = shader);
          final picture = recorder.endRecording();
          final w = (box.inflate(margin).width * scale).ceil();
          final h = (box.inflate(margin).height * scale).ceil();
          final image = await picture.toImage(w, h);
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          picture.dispose();
          image.dispose();
          shader.dispose();

          var edge = 0;
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              final alpha = bytes[(y * w + x) * 4 + 3] / 255;
              final p = Offset((x + 0.5) / scale, (y + 0.5) / scale);
              final d = o.locate(p).distance;
              if (alpha > 0.02 && alpha < 0.98) {
                edge++;
                expect(
                  (0.5 - alpha) / scale,
                  closeTo(d, 0.02),
                  reason: '$name at $p',
                );
              } else if (d.abs() > 1 / scale) {
                expect(alpha > 0.5, d < 0, reason: '$name at $p (d = $d)');
              }
            }
          }
          expect(edge, greaterThan(300));
        });
      }
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

BorderRadius _r(double radius) => BorderRadius.circular(radius);

const BorderRadius _stadium = BorderRadius.all(
  Radius.circular(double.infinity),
);

/// The radii Flutter needs for the shape the beam draws with [radius]:
/// the same, except a stadium's infinite radius is half the short side.
BorderRadius _flutterRadius(Rect box, BorderRadius radius) =>
    radius == _stadium ? _r(box.shortestSide / 2) : radius;

/// Flutter's own superellipse for [box], sampled every quarter pixel.
List<Offset> _flutterOutline(Rect box, BorderRadius radius) {
  final path = RoundedSuperellipseBorder(
    borderRadius: _flutterRadius(box, radius),
  ).getOuterPath(box);
  return [
    for (final metric in path.computeMetrics())
      for (var s = 0.0; s < metric.length; s += 0.25)
        metric.getTangentForOffset(s)!.position,
  ];
}

/// Distance from [p] to the closed polyline through [points].
double _distanceTo(List<Offset> points, Offset p) {
  var best = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    if ((a - p).distance > best + 1) continue;
    final ab = points[(i + 1) % points.length] - a;
    final t = ab.distanceSquared == 0
        ? 0.0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared)
              .clamp(0.0, 1.0);
    best = math.min(best, (p - (a + ab * t)).distance);
  }
  return best;
}
