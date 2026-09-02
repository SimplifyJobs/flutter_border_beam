import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/constants/line_keyframes.dart';
import 'package:flutter_border_beam/src/models/beam_blob.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_options.dart';
import 'package:flutter_border_beam/src/models/beam_segment.dart';
import 'package:flutter_border_beam/src/models/beam_shape.dart';
import 'package:flutter_border_beam/src/models/beam_style.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_border_beam/src/painting/ring_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = ui.Size.square(300);

void main() {
  group('rotate segment mask', () {
    test('bottomHalf paints only the lower half over a full cycle', () async {
      final frames = await _cycleFrames(
        _config(BeamVariant.rotate, segment: BeamSegment.bottomHalf),
      );
      expect(
        frames.totalAlpha(const ui.Rect.fromLTRB(0, 180, 300, 300)),
        greaterThan(10),
      );
      expect(frames.totalAlpha(const ui.Rect.fromLTRB(0, 0, 300, 120)), 0);
    });

    test('topHalf paints only the upper half over a full cycle', () async {
      final frames = await _cycleFrames(
        _config(BeamVariant.rotate, segment: BeamSegment.topHalf),
      );
      expect(
        frames.totalAlpha(const ui.Rect.fromLTRB(0, 0, 300, 120)),
        greaterThan(10),
      );
      expect(frames.totalAlpha(const ui.Rect.fromLTRB(0, 180, 300, 300)), 0);
    });

    test('feather zero cuts hard while feather 40 ramps', () async {
      const hard = BeamSegment(
        start: BeamAnchor.rightCenter,
        end: BeamAnchor.leftCenter,
        feather: 0,
      );
      const soft = BeamSegment(
        start: BeamAnchor.rightCenter,
        end: BeamAnchor.leftCenter,
        feather: 40,
      );
      final hardPixels = await _cycleFrames(
        _config(BeamVariant.rotate, segment: hard),
      );
      final softPixels = await _cycleFrames(
        _config(BeamVariant.rotate, segment: soft),
      );
      final geometry = BeamRingGeometry(
        rect: ui.Offset.zero & _size,
        radius: BorderRadius.circular(16),
        borderWidth: 1,
        useSuperellipse: false,
        segment: soft,
      );
      final start = geometry.segmentRange!.from;
      double sample(_Pixels pixels, double distance) {
        final point = geometry.perimeter.offsetPointAt(
          start + distance / geometry.perimeter.length,
          1,
        );
        return pixels.alphaNear(point);
      }

      // The bloom is clipped inside its blurred saveLayer, so it legitimately
      // bleeds across even a hard segment edge. The unblurred layers still
      // make the zero-feather transition much steeper than a feathered one.
      // alphaNear reads a 5x5 neighborhood, so the two sides of the step are
      // sampled 8px apart to keep their windows disjoint.
      final hardStep = sample(hardPixels, 8) - sample(hardPixels, -8);
      final softStep = sample(softPixels, 8) - sample(softPixels, -8);
      expect(sample(hardPixels, 2), greaterThan(0.05));
      expect(hardStep, greaterThan(softStep + 0.02));
      final ramp = [
        for (final d in [2.0, 10.0, 20.0, 30.0, 42.0]) sample(softPixels, d),
      ];
      for (var i = 1; i < ramp.length; i++) {
        expect(ramp[i], greaterThanOrEqualTo(ramp[i - 1] - 0.02));
      }
      expect(ramp.last, greaterThan(ramp.first));
    });
  });

  group('line path travel', () {
    test('traveller follows the bottom half perimeter', () async {
      Future<_Pixels> at(double progress) => _paint(
        _config(BeamVariant.line, segment: BeamSegment.bottomHalf),
        phases: BeamFramePhases(
          fadeOpacity: 1,
          hueDegrees: 0,
          travelProgress: progress,
          travellers: [progress],
        ),
      );

      final middle = await at(0.5);
      // The stock edge-fade is fully transparent at 0.1/0.9, so probe just
      // inside those ramps while the anchors are still on the side runs.
      final early = await at(0.15);
      final late = await at(0.85);
      expect(
        middle.totalAlpha(const ui.Rect.fromLTRB(110, 250, 190, 300)),
        greaterThan(2),
      );
      expect(
        early.totalAlpha(const ui.Rect.fromLTRB(250, 150, 300, 250)),
        greaterThan(1),
      );
      expect(
        late.totalAlpha(const ui.Rect.fromLTRB(0, 150, 50, 250)),
        greaterThan(1),
      );
    });

    test('wrapCorners bends into the bottom-right corner arc', () async {
      // A 60px radius on the 300px box gives 94px corner arcs — long enough
      // for a bent traveller to sit well inside one while the temporal edge
      // fade still carries it. Both runs travel left to right, so 0.82 puts
      // the planar anchor 9px short of the bottom-right arc, where its run
      // ends, and the wrapped anchor 28px into that same arc.
      const progress = 0.82;
      final planar = await _paint(
        _config(BeamVariant.line, radius: 60),
        phases: _linePhasesAt(progress),
      );
      final wrapped = await _paint(
        _config(BeamVariant.line, wrapCorners: true, radius: 60),
        phases: _linePhasesAt(progress),
      );
      // A 24px box straddling the bottom-right arc's 45° point — (282, 282),
      // on the arc about (240, 240).
      const arc = ui.Rect.fromLTRB(270, 270, 294, 294);
      final bent = wrapped.totalAlpha(arc);
      // The wrapped traveller rides the arc; the planar one never leaves the
      // straight run, so the arc catches only what its glow spills into it.
      expect(bent, greaterThan(1));
      expect(bent, greaterThan(planar.totalAlpha(arc) + 6));
      expect(bent, greaterThan(planar.totalAlpha(arc) * 3));
    });

    // wrapCorners is a modifier on the ordinary line variant, so turning it on
    // must never reverse the animation — only lengthen the run around the two
    // corners. Planar travel is authored bottom-edge left to right and turned
    // rigidly for the other edges, which leaves it counter-clockwise on all
    // four. [forward] is travel toward growing x (horizontal) or y (vertical).
    for (final (edge, axis, forward) in [
      (BeamEdge.bottom, Axis.horizontal, true),
      (BeamEdge.top, Axis.horizontal, false),
      (BeamEdge.left, Axis.vertical, true),
      (BeamEdge.right, Axis.vertical, false),
    ]) {
      test('wrapCorners keeps the planar travel direction on $edge', () async {
        Future<double> centre(bool wrap, double progress) async {
          final pixels = await _paint(
            _config(BeamVariant.line, edge: edge, wrapCorners: wrap),
            phases: _linePhasesAt(progress),
          );
          final centroid = pixels.centroid();
          return axis == Axis.horizontal ? centroid.dx : centroid.dy;
        }

        final planarEarly = await centre(false, 0.25);
        final planarLate = await centre(false, 0.75);
        final wrappedEarly = await centre(true, 0.25);
        final wrappedLate = await centre(true, 0.75);

        // The planar run's direction, and the wrapped run agreeing with it
        // rather than starting from the far end.
        expect(planarLate > planarEarly, forward);
        expect(wrappedLate > wrappedEarly, forward);
        expect(wrappedEarly < 150, forward);
        expect(wrappedLate > 150, forward);
        // The two anchors coincide at mid-run and stay close at the quarter
        // points: equal progress lands a little further along the wrapped run,
        // which is 327px of perimeter against the planar run's 300px of edge.
        expect(await centre(true, 0.5), closeTo(await centre(false, 0.5), 5));
        expect(wrappedEarly, closeTo(planarEarly, 25));
        expect(wrappedLate, closeTo(planarLate, 25));
      });
    }
  });

  for (final variant in [BeamVariant.pulseInside, BeamVariant.pulseOutside]) {
    test('$variant paints no pixels above center with bottomHalf', () async {
      final pixels = await _paint(
        _config(variant, segment: BeamSegment.bottomHalf),
        behindAndAbove: true,
      );
      expect(pixels.totalAlpha(const ui.Rect.fromLTRB(0, 0, 300, 140)), 0);
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 160, 300, 300)),
        greaterThan(1),
      );
    });
  }

  test('segmented stroke bands retain visible ring pixels', () async {
    for (final variant in BeamVariant.values) {
      final pixels = await _cycleFrames(
        _config(variant, segment: BeamSegment.bottomHalf),
      );
      expect(
        pixels.totalAlpha(const ui.Rect.fromLTRB(0, 250, 300, 300)),
        greaterThan(1),
        reason: '$variant',
      );
    }
  });

  test('rotate sparkles cannot spill beyond a segment band', () async {
    final pixels = await _cycleFrames(
      _config(
        BeamVariant.rotate,
        segment: BeamSegment.bottomHalf,
        style: const BeamStyle(sparkle: 1),
      ),
    );
    expect(pixels.totalAlpha(const ui.Rect.fromLTRB(0, 0, 300, 120)), 0);
  });

  test('pulse variants cycle a short spec palette without throwing', () async {
    const short = BeamColors.spec(
      border: [
        BeamBlob(
          color: ui.Color(0xFFFF0080),
          position: ui.Offset(0.5, 0.5),
          size: ui.Size(40, 24),
        ),
      ],
    );
    for (final variant in [BeamVariant.pulseInside, BeamVariant.pulseOutside]) {
      final pixels = await _paint(
        _config(variant, colors: short),
        behindAndAbove: true,
      );
      expect(
        pixels.totalAlpha(ui.Offset.zero & _size),
        greaterThan(1),
        reason: '$variant',
      );
    }
  });

  test('an omitted segment and an explicit null paint identically', () async {
    final omitted = BeamConfig.resolve(
      variant: BeamVariant.rotate,
      palette: BeamColors.colorful.resolve(),
      brightness: ui.Brightness.dark,
    );
    final explicit = BeamConfig.resolve(
      variant: BeamVariant.rotate,
      palette: BeamColors.colorful.resolve(),
      brightness: ui.Brightness.dark,
      shape: const BeamShape(segment: null, wrapCorners: false),
    );
    final a = await _paint(omitted, t: 1.3, behindAndAbove: true);
    final b = await _paint(explicit, t: 1.3, behindAndAbove: true);
    expect(a.bytes, b.bytes);
  });
}

BeamConfig _config(
  BeamVariant variant, {
  BeamSegment? segment,
  bool wrapCorners = false,
  double radius = 16,
  BeamEdge edge = BeamEdge.bottom,
  BeamColors colors = BeamColors.colorful,
  BeamStyle style = const BeamStyle(),
}) => BeamConfig.resolve(
  variant: variant,
  palette: colors.resolve(),
  brightness: ui.Brightness.dark,
  style: style,
  shape: BeamShape(
    radius: BorderRadius.all(Radius.circular(radius)),
    edge: edge,
    segment: segment,
    wrapCorners: wrapCorners,
  ),
);

/// A frame of the line variant's own tracks at [progress].
///
/// Only the planar branch reads `lineX`/`lineW`/`edge` off the phases; path
/// mode re-samples the same tracks per traveller. Sampling them here is what
/// puts a planar and a path-mode run at the same point of the same cycle —
/// the hand-built defaults would otherwise freeze the planar traveller.
BeamFramePhases _linePhasesAt(double progress) => BeamFramePhases(
  fadeOpacity: 1,
  hueDegrees: 0,
  travelProgress: progress,
  travellers: [progress],
  lineX: sampleKeyframes(lineTravelX, progress),
  lineW: sampleKeyframes(lineTravelW, progress),
  edge: sampleKeyframes(lineEdgeFade, progress),
);

Future<_Pixels> _cycleFrames(BeamConfig config) async {
  final frames = <_Pixels>[];
  for (final progress in [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]) {
    frames.add(
      await _paint(
        config,
        phases: BeamFramePhases(
          fadeOpacity: 1,
          hueDegrees: 0,
          angleRadians: progress * 2 * math.pi,
          travelProgress: progress,
          travellers: [progress],
        ),
      ),
    );
  }
  return _Pixels.max(frames);
}

Future<_Pixels> _paint(
  BeamConfig config, {
  double t = 1.3,
  BeamFramePhases? phases,
  bool behindAndAbove = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final frame = phases ?? BeamPhaseResolver(config).sample(t, 1);
  final strategy = strategyFor(config.variant);
  if (behindAndAbove) strategy.paintBehind(canvas, _size, config, frame);
  strategy.paintAbove(canvas, _size, config, frame);
  final image = await recorder.endRecording().toImage(300, 300);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Pixels(data!.buffer.asUint8List(), image.width, image.height);
}

class _Pixels {
  _Pixels(this.bytes, this.width, this.height);

  factory _Pixels.max(List<_Pixels> frames) {
    final bytes = List<int>.filled(frames.first.bytes.length, 0);
    for (final frame in frames) {
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = math.max(bytes[i], frame.bytes[i]);
      }
    }
    return _Pixels(bytes, frames.first.width, frames.first.height);
  }

  final List<int> bytes;
  final int width;
  final int height;

  double alphaAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    return bytes[(y * width + x) * 4 + 3] / 255;
  }

  double alphaNear(ui.Offset point) {
    var best = 0.0;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        best = math.max(
          best,
          alphaAt(point.dx.round() + dx, point.dy.round() + dy),
        );
      }
    }
    return best;
  }

  double totalAlpha(ui.Rect rect) {
    var sum = 0.0;
    for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
      for (var x = rect.left.round(); x < rect.right.round(); x++) {
        sum += alphaAt(x, y);
      }
    }
    return sum;
  }

  /// The alpha-weighted centre of everything painted — where the traveller
  /// sits, for a frame holding one beam.
  ui.Offset centroid() {
    var sumX = 0.0;
    var sumY = 0.0;
    var weight = 0.0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final alpha = alphaAt(x, y);
        sumX += x * alpha;
        sumY += y * alpha;
        weight += alpha;
      }
    }
    return weight == 0
        ? ui.Offset.zero
        : ui.Offset(sumX / weight, sumY / weight);
  }
}
