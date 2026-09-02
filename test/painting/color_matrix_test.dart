import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/src/painting/color_matrix.dart';
import 'package:flutter_border_beam/src/painting/ring_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeamColorMatrix', () {
    test('identity is a no-op', () {
      final m = BeamColorMatrix.identity();
      expect(m.isIdentity, isTrue);
      const c = Color(0x80336699);
      final out = m.transform(c);
      expect(out.a, closeTo(c.a, 1e-6));
      expect(out.r, closeTo(c.r, 1e-6));
      expect(out.g, closeTo(c.g, 1e-6));
      expect(out.b, closeTo(c.b, 1e-6));
    });

    test('hue-rotate(0) is identity, hue-rotate(360) round-trips', () {
      final zero = BeamColorMatrix.beamFilter(
        hueDegrees: 0,
        brightness: 1,
        saturation: 1,
      );
      expect(zero.isIdentity, isTrue);
      final full = BeamColorMatrix.beamFilter(
        hueDegrees: 360,
        brightness: 1,
        saturation: 1,
      );
      const c = Color(0xFFFF3264);
      final out = full.transform(c);
      expect(out.r, closeTo(c.r, 1e-4));
      expect(out.g, closeTo(c.g, 1e-4));
      expect(out.b, closeTo(c.b, 1e-4));
    });

    test('hue-rotate(180) inverts hue but preserves luminance-ish gray', () {
      final m = BeamColorMatrix.beamFilter(
        hueDegrees: 180,
        brightness: 1,
        saturation: 1,
      );
      // Pure gray is hue-invariant.
      const gray = Color(0xFF808080);
      final out = m.transform(gray);
      expect(out.r, closeTo(gray.r, 1e-3));
      expect(out.g, closeTo(gray.g, 1e-3));
      expect(out.b, closeTo(gray.b, 1e-3));
    });

    test('brightness scales channels, saturation(0) grays out', () {
      final bright = BeamColorMatrix.beamFilter(
        hueDegrees: 0,
        brightness: 2,
        saturation: 1,
      );
      const c = Color.fromRGBO(50, 100, 20, 1.0);
      final out = bright.transform(c);
      expect(out.r, closeTo(c.r * 2, 1e-6));
      expect(out.g, closeTo(c.g * 2, 1e-6));

      final gray = BeamColorMatrix.beamFilter(
        hueDegrees: 0,
        brightness: 1,
        saturation: 0,
      );
      final g = gray.transform(const Color(0xFFFF0000));
      expect(g.r, closeTo(g.g, 1e-6));
      expect(g.g, closeTo(g.b, 1e-6));
      // Red's luminance weight.
      expect(g.r, closeTo(0.213, 1e-3));
    });

    test('alpha passes through untouched', () {
      final m = BeamColorMatrix.beamFilter(
        hueDegrees: 90,
        brightness: 1.5,
        saturation: 1.2,
      );
      const c = Color(0x40FF8040);
      expect(m.transform(c).a, closeTo(c.a, 1e-6));
    });
  });

  group('BeamRingGeometry', () {
    test('ring excludes the content box for rounded rects', () {
      final g = BeamRingGeometry(
        rect: const Rect.fromLTWH(0, 0, 100, 60),
        radius: BorderRadius.circular(16),
        borderWidth: 1,
        useSuperellipse: false,
      );
      // Edge midpoint inside the 1px ring.
      expect(g.ring.contains(const Offset(50, 0.5)), isTrue);
      // Center is inside the content box, so excluded from the ring.
      expect(g.ring.contains(const Offset(50, 30)), isFalse);
      expect(g.ring.contains(const Offset(50, 2)), isFalse);
      // Outside the shape entirely.
      expect(g.ring.contains(const Offset(-1, -1)), isFalse);
    });

    test('superellipse ring behaves the same', () {
      final g = BeamRingGeometry(
        rect: const Rect.fromLTWH(0, 0, 100, 60),
        radius: BorderRadius.circular(16),
        borderWidth: 1,
        useSuperellipse: true,
      );
      expect(g.ring.contains(const Offset(50, 0.5)), isTrue);
      expect(g.ring.contains(const Offset(50, 30)), isFalse);
      // Corner exterior stays outside; interior near the edge stays in the
      // outer contour. (Sub-pixel squircle-vs-arc differences are covered by
      // golden tests, not containment probing.)
      expect(g.outer.contains(const Offset(1, 1)), isFalse);
      expect(g.outer.contains(const Offset(8, 8)), isTrue);
    });

    test('a box thinner than twice the border has no content box', () {
      for (final superellipse in [false, true]) {
        final g = BeamRingGeometry(
          rect: const Rect.fromLTWH(0, 0, 1, 1),
          radius: BorderRadius.circular(16),
          borderWidth: 1,
          useSuperellipse: superellipse,
        );
        expect(g.inner.getBounds().isEmpty, isTrue);
        // Nothing is carved out: the ring is the whole box. The ring is
        // `Path.combine`d rather than added directly, and combining
        // re-flattens the contour — a superellipse corner comes back a few
        // ten-thousandths of a pixel off the contour it was built from, by a
        // margin that varies with the engine's flattening tolerance. Compare
        // edge by edge with a tolerance instead of asking two Rects to be
        // bit-identical.
        final ring = g.ring.getBounds();
        final outer = g.outer.getBounds();
        expect(ring.left, closeTo(outer.left, 1e-3));
        expect(ring.top, closeTo(outer.top, 1e-3));
        expect(ring.right, closeTo(outer.right, 1e-3));
        expect(ring.bottom, closeTo(outer.bottom, 1e-3));
        expect(g.ring.contains(const Offset(0.5, 0.5)), isTrue);
      }
    });

    test('an empty box has no contours at all', () {
      for (final rect in const [
        Rect.zero,
        Rect.fromLTWH(0, 0, 40, 0),
        Rect.fromLTWH(0, 0, 0, 40),
      ]) {
        final g = BeamRingGeometry(
          rect: rect,
          radius: BorderRadius.circular(16),
          borderWidth: 1,
          useSuperellipse: false,
        );
        expect(g.outer.getBounds().isEmpty, isTrue);
        expect(g.inner.getBounds().isEmpty, isTrue);
        expect(g.ring.getBounds().isEmpty, isTrue);
        expect(
          g.shapeContour(rect, BorderRadius.circular(16)).getBounds().isEmpty,
          isTrue,
        );
      }
    });

    test('radius clamps to half the shortest side', () {
      final g = BeamRingGeometry(
        rect: const Rect.fromLTWH(0, 0, 40, 10),
        radius: BorderRadius.circular(32),
        borderWidth: 1,
        useSuperellipse: false,
      );
      // Must not throw and must produce a valid ring.
      expect(g.ring.getBounds().isEmpty, isFalse);
    });

    test('per-corner radii round only the corners they name', () {
      final g = BeamRingGeometry(
        rect: const Rect.fromLTWH(0, 0, 100, 60),
        radius: const BorderRadius.only(topLeft: Radius.circular(20)),
        borderWidth: 1,
        useSuperellipse: false,
      );
      // The rounded corner cuts its own square corner away…
      expect(g.outer.contains(const Offset(1, 1)), isFalse);
      // …while the other three stay right angles.
      expect(g.outer.contains(const Offset(99, 1)), isTrue);
      expect(g.outer.contains(const Offset(1, 59)), isTrue);
      expect(g.outer.contains(const Offset(99, 59)), isTrue);
    });

    test('adjacent radii that overflow a side scale down together', () {
      // 40 + 40 across a 60px-wide box: both top corners scale by 60/80.
      final g = BeamRingGeometry(
        rect: const Rect.fromLTWH(0, 0, 60, 200),
        radius: const BorderRadius.vertical(top: Radius.circular(40)),
        borderWidth: 1,
        useSuperellipse: false,
      );
      // At the scaled radius (30) the top edge is straight from x=30 on…
      expect(g.outer.contains(const Offset(30, 0.5)), isTrue);
      // …the corner is still cut away…
      expect(g.outer.contains(const Offset(1, 1)), isFalse);
      // …and the bottom corners were never rounded.
      expect(g.outer.contains(const Offset(1, 199)), isTrue);
    });

    test('a stadium radius rounds to half the shortest side', () {
      const rect = Rect.fromLTWH(0, 0, 120, 40);
      final stadium = BeamRingGeometry(
        rect: rect,
        radius: const BorderRadius.all(Radius.circular(double.infinity)),
        borderWidth: 1,
        useSuperellipse: false,
      );
      final pill = BeamRingGeometry(
        rect: rect,
        radius: BorderRadius.circular(20),
        borderWidth: 1,
        useSuperellipse: false,
      );
      // The same shape as an explicit half-shortest-side radius.
      expect(stadium.outer.getBounds(), pill.outer.getBounds());
      for (final probe in const [
        Offset(2, 2),
        Offset(20, 0.5),
        Offset(60, 0.5),
        Offset(118, 38),
      ]) {
        expect(
          stadium.outer.contains(probe),
          pill.outer.contains(probe),
          reason: 'probe $probe',
        );
      }
    });

    test('a stadium square rounds to a circle', () {
      final g = BeamRingGeometry(
        rect: const Rect.fromLTWH(0, 0, 40, 40),
        radius: const BorderRadius.all(Radius.circular(double.infinity)),
        borderWidth: 1,
        useSuperellipse: false,
      );
      // Inside the inscribed circle, outside the square's corners.
      expect(g.outer.contains(const Offset(20, 1)), isTrue);
      expect(g.outer.contains(const Offset(2, 2)), isFalse);
      expect(g.outer.contains(const Offset(38, 38)), isFalse);
    });
  });
}
