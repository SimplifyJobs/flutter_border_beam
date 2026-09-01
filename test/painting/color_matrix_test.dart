import 'dart:ui';

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
        radius: 16,
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
        radius: 16,
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

    test('radius clamps to half the shortest side', () {
      final g = BeamRingGeometry(
        rect: const Rect.fromLTWH(0, 0, 40, 10),
        radius: 32,
        borderWidth: 1,
        useSuperellipse: false,
      );
      // Must not throw and must produce a valid ring.
      expect(g.ring.getBounds().isEmpty, isFalse);
    });
  });
}
