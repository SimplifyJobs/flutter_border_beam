import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/distortion_wave/models/wave_spec.dart';
import 'package:prismatic/src/distortion_wave/render/render_wave_stage.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_frame.dart';

import '../widget/wave_test_utils.dart';

/// Where the wave's pixels land, read off real frames through the real
/// shaders: the side it leaves ahead of the front, the side it reveals
/// behind it, colour clinging to the edges after the front has passed, and
/// the center wave's source left untouched. Regions against each other, not
/// pinned values, so retuning the look leaves these standing.
void main() {
  setUpAll(DistortionWave.precache);

  const button = Rect.fromLTWH(20, 764, 350, 56);

  Future<_Frame> frameAt(
    WidgetTester tester,
    double progress, {
    WaveType type = WaveType.vertical,
    Rect source = button,
  }) async {
    useWaveView(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      waveHost(
        RepaintBoundary(
          key: key,
          child: DistortionWave(
            progress: progress,
            type: type,
            source: WaveSource.rect(source),
            revealedChild: flatSide(incomingColor, 'in'),
            child: flatSide(outgoingColor, 'out'),
          ),
        ),
      ),
    );
    final bytes = await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData();
      image.dispose();
      return data!;
    });
    return _Frame(bytes!, (waveTestSize.width * 2).round());
  }

  /// Progress at which the vertical wave's front crosses [y] on the centre
  /// line, to within a pixel or so.
  double frontAt(double y) {
    final spec = WaveSpec.resolve(null);
    var lo = spec.anticipation / spec.duration;
    var hi = 1.0;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      final f = WaveFrame.at(
        progress: mid,
        source: button,
        size: waveTestSize,
        spec: spec,
      );
      if (f.origin.dy - f.radius > y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  testWidgets('the pictures of the sides are drawn the right way up', (
    tester,
  ) async {
    // Early in the pull, nothing is bent far from the source: the outgoing
    // side, top half red and bottom half green, shows as it is — so a
    // picture sampled upside down on some backend would show here.
    useWaveView(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      waveHost(
        RepaintBoundary(
          key: key,
          child: DistortionWave(
            progress: 0.01,
            source: const WaveSource.rect(button),
            revealedChild: flatSide(incomingColor, 'in'),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ColoredBox(color: Color(0xFFFF0000))),
                Expanded(child: ColoredBox(color: Color(0xFF00FF00))),
              ],
            ),
          ),
        ),
      ),
    );
    expect(waveStage(tester).debugLastPhase, WavePhase.distorting);
    final bytes = await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData();
      image.dispose();
      return data!;
    });
    final frame = _Frame(bytes!, (waveTestSize.width * 2).round());
    expect(frame.at(195, 120), _near(const Color(0xFFFF0000), tolerance: 8));
    expect(frame.at(195, 600), _near(const Color(0xFF00FF00), tolerance: 8));
  });

  testWidgets('at rest each side is drawn as itself', (tester) async {
    var frame = await frameAt(tester, 0);
    expect(frame.at(195, 400), _near(outgoingColor));
    frame = await frameAt(tester, 1);
    expect(frame.at(195, 400), _near(incomingColor));
    expect(frame.at(2, 420), _near(incomingColor), reason: 'edges cleared');
  });

  testWidgets('ahead of the front the outgoing side, behind it the '
      'incoming one, colour on the front', (tester) async {
    final frame = await frameAt(tester, frontAt(250));
    // Past the band's feather ahead, and past its longest tail behind.
    expect(frame.at(195, 60), _near(outgoingColor), reason: 'well ahead');
    expect(frame.at(195, 700), _near(incomingColor), reason: 'well behind');
    expect(frame.chroma(195, 240), greaterThan(0.08), reason: 'band on it');
    expect(frame.at(195, 240), isNot(_near(outgoingColor, tolerance: 24)));
    expect(frame.at(195, 240), isNot(_near(incomingColor, tolerance: 24)));
  });

  testWidgets('colour clings to the edges after the front has passed', (
    tester,
  ) async {
    final spec = WaveSpec.resolve(null);
    final p = [
      for (var p = 0.3; p < 1; p += 0.01)
        if (WaveFrame.at(
          progress: p,
          source: button,
          size: waveTestSize,
          spec: spec,
        ).contentAtRest)
          p,
    ].first;
    final frame = await frameAt(tester, p);
    expect(frame.at(195, 422), _near(incomingColor), reason: 'middle clear');
    final edges = [
      for (var y = 200.0; y < 700; y += 50)
        frame.difference(1, y, incomingColor),
    ];
    expect(
      edges.reduce((a, b) => a > b ? a : b),
      greaterThan(40),
      reason: 'the rim lights the left edge somewhere',
    );
  });

  testWidgets('the colour on the edges has no seam across a sharp corner', (
    tester,
  ) async {
    // Inside a corner the nearest point of the outline flips from one edge
    // to the other across the corner's diagonal; with a sharp corner that
    // flip runs through the lit rim. Walk across the diagonal inside the
    // rim and check the colour changes smoothly.
    // A wide, very uneven rim, so it is lit deep into the corner where the
    // flip would jump furthest.
    const style = WaveStyle(
      glow: WaveGlow(cornerRadius: 8, rimWidth: 40, rimUnevenness: 2),
    );
    final spec = WaveSpec.resolve(style);
    final p = [
      for (var p = 0.3; p < 1; p += 0.01)
        if (WaveFrame.at(
              progress: p,
              source: button,
              size: waveTestSize,
              spec: spec,
            ).contentAtRest &&
            WaveFrame.at(
                  progress: p,
                  source: button,
                  size: waveTestSize,
                  spec: spec,
                ).rim >
                0.5)
          p,
    ].first;
    useWaveView(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      waveHost(
        RepaintBoundary(
          key: key,
          child: DistortionWave(
            progress: p,
            style: style,
            source: const WaveSource.rect(button),
            revealedChild: flatSide(incomingColor, 'in'),
            child: flatSide(outgoingColor, 'out'),
          ),
        ),
      ),
    );
    final bytes = await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData();
      image.dispose();
      return data!;
    });
    final frame = _Frame(bytes!, (waveTestSize.width * 2).round());
    // Walk across each corner's diagonal at several depths, in half points:
    // wherever the walk crosses lit rim, the colour must change smoothly.
    final w = waveTestSize.width;
    final h = waveTestSize.height;
    var litWalks = 0;
    var worst = 0;
    for (final depth in [12.0, 24.0, 36.0, 48.0]) {
      for (final (cx, cy) in [(0.0, 0.0), (w, 0.0), (0.0, h), (w, h)]) {
        final sx = cx == 0 ? 1.0 : -1.0;
        final sy = cy == 0 ? 1.0 : -1.0;
        var lit = 0;
        final steps = <int>[];
        Color? last;
        // Inside the view only: from 1 pt in, across the diagonal at t = depth.
        for (var t = math.max(1.0, depth - 20); t <= depth + 20; t += 0.5) {
          final x = cx + sx * t;
          final y = cy + sy * depth;
          final c = frame.at(x, y);
          if (frame.difference(x, y, incomingColor) > 24) lit++;
          if (last != null) {
            int ch(double v) => (v * 255).round();
            final step = [
              (ch(c.r) - ch(last.r)).abs(),
              (ch(c.g) - ch(last.g)).abs(),
              (ch(c.b) - ch(last.b)).abs(),
            ].reduce((a, b) => a > b ? a : b);
            steps.add(step);
          }
          last = c;
        }
        if (lit > 10) {
          litWalks++;
          // A seam is a step far above its neighbours; a steep but smooth
          // stretch (the edge of a lump) climbs to it and back.
          for (var i = 1; i + 1 < steps.length; i++) {
            final spike = steps[i] - (steps[i - 1] + steps[i + 1]) / 2;
            if (spike > worst) worst = spike.round();
          }
        }
      }
    }
    expect(litWalks, greaterThan(1), reason: 'the walks cross lit rim');
    expect(worst, lessThan(8), reason: 'no seam on the diagonals');
  });

  testWidgets('the center wave leaves its source untouched', (tester) async {
    const avatar = Rect.fromLTWH(163, 300, 64, 64);
    final spec = WaveSpec.resolve(const WaveStyle(type: WaveType.center));
    final p = (spec.anticipation + spec.travel * 0.1) / spec.duration;
    final frame = await frameAt(
      tester,
      p,
      type: WaveType.center,
      source: avatar,
    );
    expect(frame.at(195, 332), _near(incomingColor, tolerance: 2));
    expect(
      frame.difference(195, 332 - 150, incomingColor) +
          frame.difference(195, 332 - 150, outgoingColor),
      greaterThan(0),
    );
  });
}

final class _Frame {
  _Frame(this.data, this.stride);

  final ByteData data;
  final int stride;

  /// The colour at logical point ([x], [y]).
  Color at(double x, double y) {
    final i = ((y * 2).round() * stride + (x * 2).round()) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  /// The largest channel difference, 0–255, from [color] at ([x], [y]).
  int difference(double x, double y, Color color) {
    final c = at(x, y);
    int ch(double v) => (v * 255).round();
    return [
      (ch(c.r) - ch(color.r)).abs(),
      (ch(c.g) - ch(color.g)).abs(),
      (ch(c.b) - ch(color.b)).abs(),
    ].reduce((a, b) => a > b ? a : b);
  }

  /// A rough chroma, 0–1, at ([x], [y]): the spread of the channels.
  double chroma(double x, double y) {
    final c = at(x, y);
    final values = [c.r, c.g, c.b];
    return values.reduce((a, b) => a > b ? a : b) -
        values.reduce((a, b) => a < b ? a : b);
  }
}

Matcher _near(Color expected, {int tolerance = 4}) => predicate<Color>((c) {
  int ch(double v) => (v * 255).round();
  return (ch(c.r) - ch(expected.r)).abs() <= tolerance &&
      (ch(c.g) - ch(expected.g)).abs() <= tolerance &&
      (ch(c.b) - ch(expected.b)).abs() <= tolerance;
}, 'within $tolerance of $expected');
