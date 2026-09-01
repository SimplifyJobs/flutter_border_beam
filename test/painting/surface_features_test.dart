import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_options.dart';
import 'package:flutter_border_beam/src/models/beam_shape.dart';
import 'package:flutter_border_beam/src/models/beam_style.dart';
import 'package:flutter_border_beam/src/models/beam_timing.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_border_beam/src/painting/ring_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Per-feature painting tests for the Phase 3 surface options: each one
/// asserts pixels appear where the feature promises them and stay away from
/// where it does not.
///
/// The assertions are deliberately coarse — presence, absence, and ordering
/// of totals — so they pin behaviour without pinning the look, which the
/// goldens own.
void main() {
  const beamSize = ui.Size(350, 140);

  group('direction', () {
    test('reverse mirrors the rotate window about the beam angle', () async {
      final config = _config(BeamVariant.rotate);
      final forward = await _paint(
        config,
        phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
      );
      final reverse = await _paint(
        config,
        phases: const BeamFramePhases(
          fadeOpacity: 1,
          hueDegrees: 0,
          reversedNow: true,
        ),
      );
      final rect = ui.Offset.zero & beamSize;
      final a = forward.ringProfile(rect);
      final b = reverse.ringProfile(rect);
      // Sample i sits at angle i·2π/n; its mirror about the beam angle (0) is
      // sample n − i.
      var mirrored = 0.0;
      var same = 0.0;
      for (var i = 1; i < a.length; i++) {
        mirrored += (a[i] - b[a.length - i]).abs();
        same += (a[i] - b[i]).abs();
      }
      expect(
        mirrored,
        lessThan(same * 0.5),
        reason: 'the reversed window should be the forward one mirrored',
      );
    });

    test('reverse mirrors the line beam head across the edge', () async {
      // Two thirds through the cycle, where the head is well off centre and
      // a mirror is not the same picture.
      const t = 2.0;
      final forward = await _paint(_config(BeamVariant.line), t: t);
      final reverse = await _paint(
        _config(
          BeamVariant.line,
          timing: const BeamTiming(direction: BeamDirection.reverse),
        ),
        t: t,
      );
      const band = ui.Rect.fromLTRB(0, 126, 350, 140);
      final xf = forward.brightestColumn(band);
      final xr = reverse.brightestColumn(band);
      expect(
        (xf - 175).abs(),
        greaterThan(25),
        reason: 'a head at mid-edge would mirror onto itself',
      );
      expect(xr, closeTo(350 - xf, 12));
    });
  });

  group('beamCount', () {
    test('rotate paints two heads half a turn apart', () async {
      final pixels = await _paint(
        _config(BeamVariant.rotate, timing: const BeamTiming(beamCount: 2)),
        phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
      );
      final profile = pixels.ringProfile(ui.Offset.zero & beamSize);
      final arcs = _litArcs(profile);
      expect(arcs.length, 2, reason: 'two beams, two lit arcs');
      final gap = (arcs[1].centre - arcs[0].centre).abs() / profile.length;
      expect(gap, closeTo(0.5, 0.08), reason: 'half a turn apart');
    });

    test('one beam paints a single arc', () async {
      final pixels = await _paint(
        _config(BeamVariant.rotate),
        phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
      );
      expect(_litArcs(pixels.ringProfile(ui.Offset.zero & beamSize)).length, 1);
    });

    test('line paints a head per traveller', () async {
      final pixels = await _paint(
        _config(BeamVariant.line, timing: const BeamTiming(beamCount: 3)),
        t: 1.3,
      );
      final band = ui.Rect.fromLTRB(0, 120, 350, 140);
      final columns = pixels.columnProfile(band);
      expect(
        _litArcs(columns, threshold: 0.35).length,
        greaterThanOrEqualTo(2),
        reason: 'three travellers, at least two inside the edge fade',
      );
    });
  });

  group('tailLength', () {
    test('scales the lit arc about the head', () async {
      Future<int> litSamples(double tail) async {
        final pixels = await _paint(
          _config(BeamVariant.rotate, style: BeamStyle(tailLength: tail)),
          phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
        );
        final profile = pixels.ringProfile(ui.Offset.zero & beamSize);
        final peak = profile.reduce(math.max);
        return profile.where((v) => v > peak * 0.2).length;
      }

      final short = await litSamples(0.5);
      final normal = await litSamples(1);
      final long = await litSamples(2);
      expect(short, lessThan(normal));
      expect(long, greaterThan(normal));
    });
  });

  group('glowSpread', () {
    test('rotate reaches further in with a wider bloom', () async {
      // The other two layers are switched off: the bloom is the only one
      // glowSpread touches, and it is far the dimmest of the three.
      Future<double> bloomReach(double spread) async {
        final pixels = await _paint(
          _config(
            BeamVariant.rotate,
            style: BeamStyle(
              glowSpread: spread,
              innerOpacityFactor: 0,
              strokeOpacityFactor: 0,
            ),
          ),
          phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
        );
        return pixels.inwardReach();
      }

      final normal = await bloomReach(1);
      expect(normal, greaterThan(0));
      expect(await bloomReach(2), greaterThan(normal));
    });

    test('pulse-outside pushes its halo further out', () async {
      Future<double> reach(double spread) async {
        final pixels = await _paint(
          _config(
            BeamVariant.pulseOutside,
            style: BeamStyle(glowSpread: spread),
          ),
          behind: true,
          canvas: const ui.Size(550, 340),
          origin: const ui.Offset(100, 100),
        );
        return pixels.farthestLit(
          const ui.Rect.fromLTWH(100, 100, 350, 140),
          axis: Axis.vertical,
        );
      }

      expect(await reach(2), greaterThan(await reach(1) + 2));
    });
  });

  group('comet', () {
    test('paints a halo outside the shape, unlike the plain bloom', () async {
      Future<double> outside(bool comet) async {
        final pixels = await _paint(
          _config(BeamVariant.rotate, style: BeamStyle(comet: comet)),
          phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
          canvas: const ui.Size(390, 180),
          origin: const ui.Offset(20, 20),
        );
        // A strip just outside the top edge, where the beam's head sits.
        return pixels.totalAlpha(const ui.Rect.fromLTRB(20, 10, 390, 19));
      }

      expect(await outside(false), lessThan(0.5));
      expect(await outside(true), greaterThan(2));
    });
  });

  group('sparkle', () {
    test('adds pixels around the head and nowhere else', () async {
      const phases = BeamFramePhases(fadeOpacity: 1, hueDegrees: 0);
      final plain = await _paint(_config(BeamVariant.rotate), phases: phases);
      final sparkly = await _paint(
        _config(BeamVariant.rotate, style: const BeamStyle(sparkle: 1)),
        phases: phases,
      );
      // The head of the default window sits at 0.8 of a turn from the beam
      // angle — the upper left of the box at angle 0.
      const nearHead = ui.Rect.fromLTRB(0, 0, 120, 60);
      const farSide = ui.Rect.fromLTRB(200, 100, 350, 140);
      expect(
        sparkly.totalAlpha(nearHead),
        greaterThan(plain.totalAlpha(nearHead)),
      );
      expect(
        sparkly.totalAlpha(farSide),
        closeTo(plain.totalAlpha(farSide), 0.5),
      );
    });

    test('is deterministic for a given frame', () async {
      const phases = BeamFramePhases(fadeOpacity: 1, hueDegrees: 0);
      final config = _config(
        BeamVariant.rotate,
        style: const BeamStyle(sparkle: 1),
      );
      final first = await _paint(config, phases: phases);
      final second = await _paint(config, phases: phases);
      expect(first.bytes, second.bytes);
    });
  });

  group('segments', () {
    test('cuts the ring into gaps the solid ring does not have', () async {
      const phases = BeamFramePhases(fadeOpacity: 1, hueDegrees: 0);
      final solid = await _paint(_config(BeamVariant.rotate), phases: phases);
      final dashed = await _paint(
        _config(BeamVariant.rotate, style: const BeamStyle(segments: 8)),
        phases: phases,
      );
      final rect = ui.Offset.zero & beamSize;
      // Sampled right on the ring, where the stroke the mask cuts lives.
      final solidProfile = solid.ringProfile(rect, depth: 1);
      final dashedProfile = dashed.ringProfile(rect, depth: 1);
      final gaps = _runs([
        for (var i = 0; i < solidProfile.length; i++)
          solidProfile[i] > 0.05 && dashedProfile[i] < solidProfile[i] * 0.7,
      ]);
      expect(
        gaps,
        greaterThanOrEqualTo(3),
        reason: 'eight dashes leave several dark gaps across the lit arc',
      );
      expect(
        dashedProfile.reduce((a, b) => a + b),
        lessThan(solidProfile.reduce((a, b) => a + b)),
      );
    });

    test('a solid ring is left alone', () async {
      const phases = BeamFramePhases(fadeOpacity: 1, hueDegrees: 0);
      final solid = await _paint(_config(BeamVariant.rotate), phases: phases);
      final one = await _paint(
        _config(BeamVariant.rotate, style: const BeamStyle(segments: 1)),
        phases: phases,
      );
      expect(
        one.bytes,
        solid.bytes,
        reason: 'a single segment is no ring at all, so it is ignored',
      );
    });
  });

  group('edge', () {
    test('top paints the top band and leaves the bottom empty', () async {
      final pixels = await _paint(
        _config(BeamVariant.line, shape: const BeamShape(edge: BeamEdge.top)),
        t: 1.3,
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 0, 350, 20)),
        greaterThan(5),
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 120, 350, 140)),
        lessThan(0.5),
      );
    });

    test('left paints the left band and leaves the right empty', () async {
      final pixels = await _paint(
        _config(BeamVariant.line, shape: const BeamShape(edge: BeamEdge.left)),
        t: 1.3,
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 0, 20, 140)),
        greaterThan(5),
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(330, 0, 350, 140)),
        lessThan(0.5),
      );
    });

    test('right paints the right band', () async {
      final pixels = await _paint(
        _config(BeamVariant.line, shape: const BeamShape(edge: BeamEdge.right)),
        t: 1.3,
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(330, 0, 350, 140)),
        greaterThan(5),
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 0, 20, 140)),
        lessThan(0.5),
      );
    });

    test('bottom is unchanged by the transform', () async {
      final pixels = await _paint(
        _config(
          BeamVariant.line,
          shape: const BeamShape(edge: BeamEdge.bottom),
        ),
        t: 1.3,
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 120, 350, 140)),
        greaterThan(5),
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 0, 350, 20)),
        lessThan(0.5),
      );
    });
  });

  group('ringOffset', () {
    test('a positive offset paints outside the child bounds', () async {
      final pixels = await _paint(
        _config(BeamVariant.rotate, shape: const BeamShape(ringOffset: 10)),
        phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
        canvas: const ui.Size(390, 180),
        origin: const ui.Offset(20, 20),
      );
      // The ring now sits 10px out; the band just outside the child's bounds
      // carries it.
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(20, 12, 370, 19)),
        greaterThan(2),
      );
    });

    test('a negative offset pulls the ring inside them', () async {
      final pixels = await _paint(
        _config(BeamVariant.rotate, shape: const BeamShape(ringOffset: -12)),
        phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
      );
      // Nothing is left in the outermost band the ring used to occupy.
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 0, 350, 3)),
        lessThan(0.5),
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 12, 350, 20)),
        greaterThan(1),
      );
    });
  });

  group('contour', () {
    test('a star contour paints along the star, not the rect', () async {
      final pixels = await _paint(
        _config(BeamVariant.rotate, shape: BeamShape(contour: _star)),
        phases: const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0),
      );
      // The beam rides the star's arms; the box's own corners and the gaps
      // between the arms — where a rounded rect would have painted — stay
      // empty.
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(124, 112, 148, 134)),
        greaterThan(1),
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 0, 24, 24)),
        lessThan(0.05),
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(40, 90, 80, 130)),
        lessThan(0.05),
      );
    });

    test('the ring keeps an even width around a lobed contour', () {
      final path = _star.build(const ui.Rect.fromLTWH(0, 0, 200, 200));
      final widths = _insetWidths(path, 6);
      final even = widths.where((w) => (w - 6).abs() < 1.5).length;
      expect(
        even,
        greaterThan(widths.length * 3 ~/ 4),
        reason:
            'a true normal offset holds the width everywhere but the folded '
            'concave vertices, unlike a scale about the centre',
      );
    });
  });
}

// ─── Fixtures ─────────────────────────────────────────────────────────────

BeamConfig _config(
  BeamVariant variant, {
  BeamStyle style = const BeamStyle(),
  BeamShape shape = const BeamShape(),
  BeamTiming timing = const BeamTiming(),
  ui.Brightness brightness = ui.Brightness.dark,
}) => BeamConfig.resolve(
  variant: variant,
  palette: BeamColors.colorful.resolve(),
  brightness: brightness,
  style: style,
  shape: shape,
  timing: timing,
);

final _star = BeamPathContour((rect) {
  final path = Path();
  final centre = rect.center;
  final outer = rect.shortestSide / 2;
  final inner = outer * 0.5;
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = centre + ui.Offset(math.cos(a) * r, math.sin(a) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}, key: 'test-star');

/// Renders one frame of [config] and returns its pixels.
///
/// [canvas]/[origin] make room for anything painted outside the beam's own
/// bounds — a comet halo or a pushed-out ring — which the widget's
/// `CustomPaint` does not clip either.
Future<_Pixels> _paint(
  BeamConfig config, {
  double t = 0.9,
  BeamFramePhases? phases,
  ui.Size size = const ui.Size(350, 140),
  ui.Size? canvas,
  ui.Offset origin = ui.Offset.zero,
  bool behind = false,
}) async {
  final target = canvas ?? size;
  final recorder = ui.PictureRecorder();
  final c = ui.Canvas(recorder);
  c.translate(origin.dx, origin.dy);
  final frame = phases ?? BeamPhaseResolver(config).sample(t, 1);
  final strategy = strategyFor(config.variant);
  if (behind) {
    strategy.paintBehind(c, size, config, frame);
  } else {
    strategy.paintAbove(c, size, config, frame);
  }
  final image = await recorder.endRecording().toImage(
    target.width.toInt(),
    target.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Pixels(bytes!.buffer.asUint8List(), image.width, image.height);
}

/// The alpha channel of a rendered frame, with the sampling helpers the
/// feature assertions are phrased in.
class _Pixels {
  _Pixels(this.bytes, this.width, this.height);

  final List<int> bytes;
  final int width;
  final int height;

  double alphaAt(double x, double y) {
    final px = x.round();
    final py = y.round();
    if (px < 0 || py < 0 || px >= width || py >= height) return 0;
    return bytes[(py * width + px) * 4 + 3] / 255;
  }

  /// Total alpha inside [rect], in whole-pixel units.
  double totalAlpha(ui.Rect rect) {
    var sum = 0.0;
    for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
      for (var x = rect.left.round(); x < rect.right.round(); x++) {
        sum += alphaAt(x.toDouble(), y.toDouble());
      }
    }
    return sum;
  }

  /// Alpha sampled just inside the border of [rect], once per angle around
  /// it — the ring as the rotating beam sees it.
  ///
  /// [depth] is how far in the sample looks: 1 reads the stroke alone, while
  /// a deeper probe also reaches the rounded corners, where the contour sits
  /// several px inside the box.
  List<double> ringProfile(ui.Rect rect, {int samples = 144, int depth = 10}) =>
      [
        for (var i = 0; i < samples; i++)
          _ringSample(rect, i * 2 * math.pi / samples, depth),
      ];

  double _ringSample(ui.Rect rect, double angle, int depth) {
    final dx = math.sin(angle);
    final dy = -math.cos(angle);
    final tx = dx.abs() < 1e-6 ? double.infinity : (rect.width / 2) / dx.abs();
    final ty = dy.abs() < 1e-6 ? double.infinity : (rect.height / 2) / dy.abs();
    final t = math.min(tx, ty);
    if (!t.isFinite) return 0;
    final edge = rect.center + ui.Offset(dx * t, dy * t);
    var best = 0.0;
    for (var inward = 1; inward <= depth; inward++) {
      final p = edge - ui.Offset(dx, dy) * inward.toDouble();
      best = math.max(best, alphaAt(p.dx, p.dy));
    }
    return best;
  }

  /// Column-by-column alpha totals inside [rect], normalised to 0–1.
  List<double> columnProfile(ui.Rect rect) {
    final columns = <double>[];
    for (var x = rect.left.round(); x < rect.right.round(); x++) {
      var sum = 0.0;
      for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
        sum += alphaAt(x.toDouble(), y.toDouble());
      }
      columns.add(sum);
    }
    final peak = columns.fold(0.0, math.max);
    return peak <= 0 ? columns : [for (final v in columns) v / peak];
  }

  /// The x of the brightest column inside [rect].
  double brightestColumn(ui.Rect rect) {
    final columns = columnProfile(rect);
    var best = 0;
    for (var i = 1; i < columns.length; i++) {
      if (columns[i] > columns[best]) best = i;
    }
    return rect.left + best;
  }

  /// How far in from the nearest image edge the farthest lit pixel sits.
  double inwardReach() {
    var reach = 0.0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (alphaAt(x.toDouble(), y.toDouble()) <= 0) continue;
        final d = math
            .min(math.min(x, width - 1 - x), math.min(y, height - 1 - y))
            .toDouble();
        reach = math.max(reach, d);
      }
    }
    return reach;
  }

  /// How far past [rect] the farthest lit pixel sits on the given axis.
  double farthestLit(ui.Rect rect, {required Axis axis}) {
    var reach = 0.0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (alphaAt(x.toDouble(), y.toDouble()) <= 0.02) continue;
        final d = axis == Axis.vertical
            ? math.max(rect.top - y, y - rect.bottom)
            : math.max(rect.left - x, x - rect.right);
        reach = math.max(reach, d);
      }
    }
    return reach;
  }
}

/// How many runs of `true` [flags] holds.
int _runs(List<bool> flags) {
  var n = 0;
  for (var i = 0; i < flags.length; i++) {
    if (flags[i] && (i == 0 || !flags[i - 1])) n++;
  }
  return n;
}

/// The runs of a profile that are lit above [threshold] of its peak, as
/// (centre index, length) pairs — the arcs a beam leaves on the ring.
List<({double centre, int length})> _litArcs(
  List<double> profile, {
  double threshold = 0.25,
}) {
  // Smoothed first: a sample sitting right on the threshold would otherwise
  // split one arc into several, and an arc count is the whole assertion.
  final smooth = [
    for (var i = 0; i < profile.length; i++)
      [
            for (var k = -2; k <= 2; k++)
              profile[(i + k + profile.length) % profile.length],
          ].reduce((a, b) => a + b) /
          5,
  ];
  final peak = smooth.fold(0.0, math.max);
  if (peak <= 0) return const [];
  final lit = [for (final v in smooth) v > peak * threshold];
  final arcs = <({double centre, int length})>[];
  var start = -1;
  for (var i = 0; i < lit.length; i++) {
    if (lit[i] && start < 0) start = i;
    if (!lit[i] && start >= 0) {
      arcs.add((centre: (start + i - 1) / 2, length: i - start));
      start = -1;
    }
  }
  if (start >= 0) {
    arcs.add((
      centre: (start + lit.length - 1) / 2,
      length: lit.length - start,
    ));
    // A run that wraps the end joins the one at the start.
    if (arcs.length > 1 && lit.first) {
      final first = arcs.removeAt(0);
      final last = arcs.removeLast();
      arcs.insert(0, (centre: last.centre, length: first.length + last.length));
    }
  }
  return arcs;
}

/// Distances from a sample of points on [path] to the nearest point of the
/// path inset by [inset] — the realised border width around a contour.
List<double> _insetWidths(Path path, double inset) {
  final inner = BeamRingGeometry.insetPath(path, inset);
  final innerPoints = <ui.Offset>[];
  for (final metric in inner.computeMetrics()) {
    for (var i = 0; i < 200; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / 200);
      if (tangent != null) innerPoints.add(tangent.position);
    }
  }
  final widths = <double>[];
  for (final metric in path.computeMetrics()) {
    for (var i = 0; i < 40; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / 40);
      if (tangent == null) continue;
      var nearest = double.infinity;
      for (final p in innerPoints) {
        nearest = math.min(nearest, (p - tangent.position).distance);
      }
      widths.add(nearest);
    }
  }
  return widths;
}
