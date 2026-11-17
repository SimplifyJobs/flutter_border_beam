import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/wave_spec.dart';
import 'wave_frame.dart';

/// One tiny white dot. Like everything else in the wave, where it is follows
/// from the frame alone, so it scrubs and reverses with the rest.
///
/// During the anticipation it makes short hops toward the source: each starts
/// somewhere off it, flies a little way in, faster and faster, and fades out
/// well short of it, while the next starts somewhere else. When the front
/// leaves, the dot is thrown out with it: the quickest ride the front, the
/// slowest trail far behind. As the wave settles each one floats on, swaying
/// and twinkling, until it burns out. No two are equally bright.
///
/// Round a ring it is the same, all the way round: the hops come in from
/// every side, and the dots are thrown out every way.
@immutable
final class WaveParticle {
  /// The [index]th dot of a wave with [spec]. Its traits come from
  /// low-discrepancy sequences: evenly scattered, and the same on every run.
  WaveParticle(int index, WaveSpec spec)
    : _index = (index + 1).toDouble(),
      column = (_scatter(index, 0.7548776662) * 2 - 1) * 0.92,
      heading = _scatter(index, 0.7548776662) * 2 * math.pi,
      // More of them toward the front, the rest thinning out behind it.
      pace = 0.35 + 0.72 * math.sqrt(_scatter(index, 0.8191725134)),
      drift = 15 + 50 * _scatter(index, 0.6710436067),
      sway = 3 + 11 * _scatter(index, 0.4142135624),
      swayRate = 2.5 + 3.5 * _scatter(index, 0.7320508076),
      twinkleRate = 8 + 12 * _scatter(index, 0.2360679775),
      phase = _scatter(index, 0.6180339887) * 2 * math.pi,
      life = spec.dotLife * (0.4 + 0.6 * _scatter(index, 0.6457513111)),
      size =
          spec.dotSize *
          (0.55 + 0.45 * math.pow(_scatter(index, 0.5497004779), 2)),
      brightness = 0.3 + 0.7 * _scatter(index, 0.6055512755),
      hop = 0.16 + 0.14 * _scatter(index, 0.1231056256),
      hopOffset = _scatter(index, 0.4721359550),
      _reach = spec.dotReach,
      _flight = spec.dotFlight,
      _gap = spec.dotGap,
      _anticipation = spec.anticipation,
      _gatherDots = spec.gatherDots,
      _spread = spec.dotSpread;

  /// Every dot of a wave with [spec], memoized for the last few specs, so
  /// waves of different styles on screen at once each keep their own.
  static List<WaveParticle> all(WaveSpec spec) {
    // Most frames ask for the spec asked for last.
    final last = _last;
    if (last != null && last.$1 == spec) return last.$2;
    var dots = _cache.remove(spec);
    dots ??= List<WaveParticle>.unmodifiable([
      for (var i = 0; i < spec.dotCount; i++) WaveParticle(i, spec),
    ]);
    // Re-inserted last: the map's order is least to most recently used.
    _cache[spec] = dots;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    _last = (spec, dots);
    return dots;
  }

  static const int _cacheSize = 4;
  static final Map<WaveSpec, List<WaveParticle>> _cache = {};
  static (WaveSpec, List<WaveParticle>)? _last;

  /// How much wider than the source the quickest end up: the front is an
  /// arc, opening.
  static const double _fan = 0.22;

  /// How much lower they fly at the source's ends than in its middle, as the
  /// front does.
  static const double _bow = 0.3;

  final double _index;

  /// Where across the source it leaves from, -1…1.
  final double column;

  /// Which way it leaves a ring, radians.
  final double heading;

  /// Its share of the front's way: 1 rides the front, less trails behind.
  final double pace;

  /// How fast it keeps rising once the front has slowed down, pt/s.
  final double drift;

  /// How far it sways from side to side, pt.
  final double sway;

  /// How fast it sways, rad/s.
  final double swayRate;

  /// How fast it twinkles, rad/s.
  final double twinkleRate;

  /// Its phase in the sway and the twinkle, radians.
  final double phase;

  /// Seconds after the launch by which it has faded out.
  final double life;

  /// Its diameter, pt.
  final double size;

  /// How bright it is at its brightest, 0–1.
  final double brightness;

  /// Seconds each hop toward the source lasts.
  final double hop;

  /// Where in its first hop it starts, 0–1.
  final double hopOffset;

  final double _reach;
  final double _flight;
  final double _gap;
  final double _anticipation;
  final double _gatherDots;
  final double _spread;

  /// Where the dot is on [frame], for a wave from [source].
  Offset pointOn(WaveFrame frame, Rect source) {
    if (frame.ring) {
      return frame.launched
          ? _ringOutflow(frame, source)
          : _ringInflow(frame, source);
    }
    return frame.launched ? _outflow(frame, source) : _inflow(frame, source);
  }

  /// How visible the dot is on [frame], 0–1.
  double opacityOn(WaveFrame frame) {
    final twinkle = 0.5 + 0.5 * math.sin(frame.time * twinkleRate + phase);
    final glint = brightness * (0.7 + 0.3 * twinkle);
    if (!frame.launched) {
      // In and out within each hop, and all of them gone by the launch.
      final along = hopAt(frame.time).along;
      final hopping =
          waveSmooth(0, 0.25, along) * (1 - waveSmooth(0.55, 1, along));
      final ending =
          1 - waveSmooth(_anticipation * 0.75, _anticipation, frame.time);
      return frame.sparkle * hopping * ending * glint * _gatherDots;
    }
    final burning = 1 - waveSmooth(life * 0.55, life, frame.flying);
    return burning * glint;
  }

  /// Which hop the dot is on at [time], and how far through it, 0–1.
  ({double count, double along}) hopAt(double time) {
    final hops = time / hop + hopOffset;
    final count = hops.floorToDouble();
    return (count: count, along: hops - count);
  }

  /// A point in the source's own frame: [along] its long side, [out] the way
  /// the wave will travel (up for the vertical wave, right for the
  /// horizontal one).
  static Offset _onSource(
    Rect source,
    bool sideways,
    double along,
    double out,
  ) => sideways
      ? Offset(source.center.dx + out, source.center.dy + along)
      : Offset(source.center.dx + along, source.center.dy - out);

  Offset _inflow(WaveFrame frame, Rect source) {
    final (:count, :along) = hopAt(frame.time);
    final half = (frame.sideways ? source.height : source.width) / 2;
    final face = (frame.sideways ? source.width : source.height) / 2;
    // Born somewhere off the source's face, never nearer than the hop and
    // the gap.
    final x = (_hash(_index, count, 1) * 2 - 1) * (half + 24);
    final nearest = _gap + _flight;
    final away =
        nearest + math.max(_reach - nearest, 0) * _hash(_index, count, 2);
    final start = _onSource(source, frame.sideways, x, face + away);
    // Flying for the nearest point of the source's face, faster and faster.
    final corner = math.min(source.width, source.height) / 2;
    final target = _onSource(
      source,
      frame.sideways,
      x.clamp(-half + corner, math.max(half - corner, -half + corner)),
      face,
    );
    final d = target - start;
    final length = math.max(d.distance, 1);
    final travelled = _flight * along * along;
    return start + d / length.toDouble() * travelled;
  }

  Offset _outflow(WaveFrame frame, Rect source) {
    final start = math.min(source.width, source.height) / 2;
    final widening = 1 + _fan * frame.moved * pace * _spread;
    final swaying =
        sway *
        math.sin(swayRate * frame.flying + phase) *
        math.min(frame.flying / 0.25, 1);
    final x =
        column *
            (frame.sideways ? source.height : source.width) /
            2 *
            widening +
        swaying;
    final height =
        (start + (frame.radius - start) * pace * _spread) *
            (1 - _bow * column * column) +
        drift * frame.flying * _spread;
    // Into the wave's frame, which leans with the touch.
    final cs = math.cos(frame.tilt);
    final sn = math.sin(frame.tilt);
    return Offset(
      frame.origin.dx + cs * x + sn * height,
      frame.origin.dy + sn * x - cs * height,
    );
  }

  /// A hop toward a round source's centre from somewhere round it.
  Offset _ringInflow(WaveFrame frame, Rect source) {
    final (:count, :along) = hopAt(frame.time);
    final angle = _hash(_index, count, 1) * 2 * math.pi;
    final nearest = math.min(source.width, source.height) / 2 + _gap + _flight;
    final away =
        nearest + math.max(_reach - nearest, 0) * _hash(_index, count, 2);
    final distance = away - _flight * along * along;
    return source.center +
        Offset(math.cos(angle) * distance, math.sin(angle) * distance);
  }

  /// Thrown straight out with the ring, swaying across its way.
  Offset _ringOutflow(WaveFrame frame, Rect source) {
    final edge = math.min(source.width, source.height) / 2;
    final distance =
        edge + ((frame.radius - edge) * pace + drift * frame.flying) * _spread;
    final swaying =
        sway *
        math.sin(swayRate * frame.flying + phase) *
        math.min(frame.flying / 0.25, 1);
    final dx = math.cos(heading);
    final dy = math.sin(heading);
    return frame.origin +
        Offset(dx * distance - dy * swaying, dy * distance + dx * swaying);
  }

  static double _scatter(int index, double step) {
    final i = (index + 1).toDouble();
    final x = i * step;
    return x - x.floorToDouble();
  }

  static double _hash(double i, double n, double salt) {
    final x = math.sin(i * 12.9898 + n * 78.233 + salt * 37.719) * 43758.5453;
    return x - x.floorToDouble();
  }
}
