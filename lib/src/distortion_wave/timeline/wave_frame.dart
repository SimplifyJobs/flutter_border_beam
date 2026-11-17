import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/wave_spec.dart';
import '../models/wave_type.dart';

/// Half the zone over which the two sides crossfade at the front, pt.
///
/// The shaders use the same value; see `shaders/common/wave_field.glsl`.
const double waveCoverZone = 60;

/// The most an arc's x axis is ever squashed; a ring's never is.
const double _arcSquash = 1.4;

/// Seconds gravity takes to let go after the launch.
const double _release = 0.22;

/// How strong the colour gathering around the source gets before the launch,
/// at `gatherGlow` 1.
const double _gatheredGlow = 0.5;

/// How far past the point of having crossed the view the front settles, pt:
/// enough to see the easing slow down, and to stop drawing the outgoing side
/// well before the front stops.
const double _overshoot = 100;

/// How far the wave turns, at full orientation, when touched at the end of
/// the source (about 26°).
const double _maxTilt = 0.45;

/// The part of the travel over which the swell, the blur and the colour die
/// away. The front has crossed the view by its start, and from there on it
/// is slowing down too much to carry them off.
const double _settleStart = 0.2;
const double _settleEnd = 0.55;

/// Hermite smoothstep of [x] between [a] and [b].
double waveSmooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Where a distortion wave is at one moment of its life — a pure function of
/// progress, so the wave can be scrubbed, reversed and frozen for a golden.
///
/// Its life, in order: gravity pulls everything toward the source; the front
/// launches off the source's outline, crosses the view on the spec's easing,
/// and settles past the far side as its swell, blur and colour die away; the
/// colour it left on the view's edges is wiped away by a second front,
/// `linger` seconds behind, and the hairline by a third, later still.
///
/// The front is an offset of a pill: a straight spine of half-length
/// [spine], centred on [origin] and turned by [tilt], with the front [radius]
/// out from it, its x axis squashed by [squash] so it bows. A ring is a pill
/// with no spine and no squash.
@immutable
final class WaveFrame {
  /// The wave at [progress] (0–1 over the spec's whole duration), opening
  /// from [source] in a view of [size], leaning toward [focus] if given.
  factory WaveFrame.at({
    required double progress,
    required Rect source,
    required Size size,
    required WaveSpec spec,
    Offset? focus,
  }) {
    final t = progress.clamp(0.0, 1.0) * spec.duration;
    final sinceLaunch = t - spec.anticipation;
    // Eased at both ends: a snap into the pull would read as a jolt.
    final gathered = waveSmooth(0, math.max(spec.anticipation, 0.001), t);
    final x = (sinceLaunch / spec.travel).clamp(0.0, 1.0);
    final moved = spec.easing.transform(x);

    final ring = spec.type == WaveType.center;
    final sideways = spec.type == WaveType.horizontal;
    final fullSquash = ring ? 1.0 : _arcSquash;
    final startRadius = math.min(source.width, source.height) / 2;
    // The source's long side, along which the front starts as a pill.
    final length = sideways ? source.height : source.width;
    // A ring spreads from the source's centre, whatever the source's shape.
    final startSpine = ring ? 0.0 : math.max(0.0, length / 2 - startRadius);
    // The horizontal wave is the vertical one turned a quarter: its frame's
    // up is the view's right.
    final turned = sideways ? math.pi / 2 : 0.0;
    final axis = Offset(math.cos(turned), math.sin(turned));

    // Touched off-centre, the wave opens from under the finger and leans its
    // way. It leans only as the pill opens into an arc, so it still leaves
    // the source's own outline.
    var lean = 0.0;
    if (!ring && focus != null) {
      final off = sideways
          ? focus.dy - source.center.dy
          : focus.dx - source.center.dx;
      lean = (off / math.max(length / 2, 1)).clamp(-1.0, 1.0);
    }
    final fullShift = lean * length / 2 * spec.orientation;
    final fullLean = lean * spec.orientation * _maxTilt;
    final fullTilt = turned + fullLean;
    final opening = waveSmooth(0, 0.45, moved);

    // The radius at which the front has left the view's farthest corner, in
    // the wave's own frame once it has finished leaning.
    final cs = math.cos(fullTilt);
    final sn = math.sin(fullTilt);
    var reach = 0.0;
    for (final corner in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final dx = corner.dx - source.center.dx - fullShift * axis.dx;
      final dy = corner.dy - source.center.dy - fullShift * axis.dy;
      reach = math.max(
        reach,
        _hypot((cs * dx + sn * dy) * fullSquash, -sn * dx + cs * dy),
      );
    }
    // …and has taken the outgoing side with it. The field divides by its
    // gradient, at most fullSquash.
    final crossed = reach + (spec.swell + waveCoverZone) * fullSquash;
    final settling = 1 - waveSmooth(_settleStart, _settleEnd, x);

    // Before the launch a ring of colour falls in, onto where the front will
    // start: the spec's gap out from the source's outline.
    final launchRadius = startRadius + spec.launchGap;
    final radius = sinceLaunch < 0
        ? launchRadius + spec.inhale * (1 - gathered)
        : launchRadius + (crossed + _overshoot - launchRadius) * moved;

    final gatheredGlow = math.min(_gatheredGlow * spec.gatherGlow, 1.0);
    // Starts far enough back that the colour is whole all the way to the
    // source, and ends just as the softness of its edge has left the
    // farthest corner, so the whole of the easing plays out on screen.
    final clearStart = startRadius - spec.rimSoftness;
    final clearEnd = reach + (spec.rimSoftness + spec.swell) * fullSquash;
    double wipe(double delay, double fade) =>
        clearStart +
        (clearEnd - clearStart) *
            spec.rimEasing.transform(
              ((sinceLaunch - delay) / fade).clamp(0.0, 1.0),
            );
    // Falling: slowly at first, then faster and faster, as under gravity.
    final falling = math.min(t / math.max(spec.anticipation, 0.001), 1.0);

    return WaveFrame._(
      origin: Offset(
        source.center.dx + fullShift * opening * axis.dx,
        source.center.dy + fullShift * opening * axis.dy,
      ),
      tilt: turned + fullLean * opening,
      // The pill opens into an arc only as the front travels, so its sides
      // never pull back in while the radius is still small.
      spine: startSpine * (1 - opening),
      radius: radius,
      moved: moved,
      squash: 1 + (fullSquash - 1) * waveSmooth(0, 0.5, moved),
      time: t,
      energy: waveSmooth(0, 0.05, x) * settling,
      swell: spec.swell * waveSmooth(0, 0.3, moved),
      size: size,
      gravity:
          spec.pull * gathered * (1 - waveSmooth(0, _release, sinceLaunch)),
      // From what has gathered on the source, so nothing pops at the launch.
      glow: sinceLaunch < 0
          ? gatheredGlow * gathered
          : (gatheredGlow + (1 - gatheredGlow) * waveSmooth(0, 0.07, x)) *
                settling,
      clearRadius: wipe(spec.linger, spec.rimFade),
      hairClearRadius: wipe(
        spec.linger + spec.hairlineLinger,
        spec.hairlineFade,
      ),
      rim:
          spec.rimStrength *
          waveSmooth(0, 0.1, x) *
          (1 - waveSmooth(0.9, 1, t / spec.duration)),
      fallen: falling * falling,
      sparkle: waveSmooth(0, math.max(spec.anticipation, 0.001) * 0.35, t),
      flying: math.max(sinceLaunch, 0),
      launched: sinceLaunch > 0,
      hasCleared: radius > crossed,
      ring: ring,
      sideways: sideways,
      hold: ring ? startRadius : 0,
    );
  }

  const WaveFrame._({
    required this.origin,
    required this.tilt,
    required this.spine,
    required this.radius,
    required this.moved,
    required this.squash,
    required this.time,
    required this.energy,
    required this.swell,
    required this.size,
    required this.gravity,
    required this.glow,
    required this.clearRadius,
    required this.hairClearRadius,
    required this.rim,
    required this.fallen,
    required this.sparkle,
    required this.flying,
    required this.launched,
    required this.hasCleared,
    required this.ring,
    required this.sideways,
    required this.hold,
  });

  /// Centre of the pill the front is an offset of.
  final Offset origin;

  /// How far the wave's frame is turned, radians; positive leans it right.
  final double tilt;

  /// Half-length of the pill's straight part.
  final double spine;

  /// Distance of the front from the spine, pt.
  final double radius;

  /// How far the front is along its way, 0–1, eased.
  final double moved;

  /// Scale of the x axis in the field: above 1 the front bows.
  final double squash;

  /// Seconds into the wave's life.
  final double time;

  /// How strongly the swell and the blur act, 0–1: 0 at either end of their
  /// part in the wave, so nothing pops as they switch off.
  final double energy;

  /// How far the front bends along its length right now, pt.
  final double swell;

  /// The view the wave fills.
  final Size size;

  /// How far content is pulled toward the source, pt.
  final double gravity;

  /// How strong the colour on the front is, 0–1.
  final double glow;

  /// Distance of the later front that wipes the colour off the edges.
  final double clearRadius;

  /// Distance of the front that wipes the hairline off them, later still.
  final double hairClearRadius;

  /// Opacity of the colour on the edges, 0–1.
  final double rim;

  /// How far the dots have fallen into the source, 0–1.
  final double fallen;

  /// How far the dots have faded in, 0–1.
  final double sparkle;

  /// Seconds since the front left the source; 0 before that.
  final double flying;

  /// Whether the front has left the source.
  final bool launched;

  /// Whether the front has crossed the whole view: nothing of the side it
  /// leaves behind can show any more, so that side need not be drawn.
  final bool hasCleared;

  /// Whether the front is a ring spreading from the source's centre.
  final bool ring;

  /// Whether the front travels left to right.
  final bool sideways;

  /// Radius of the source the wave leaves alone, pt: a ring's; 0 for an arc.
  final double hold;

  /// Whether the outgoing side still shows anywhere.
  bool get showsOutgoing => !hasCleared;

  /// Whether the incoming side shows anywhere.
  bool get showsIncoming => launched;

  /// Whether anything on screen is moved or blurred: the pull before the
  /// launch, or the swell after it.
  bool get bendsContent => energy > 0 || gravity > 0;

  /// Whether the view's content can be drawn as it is, with only colour over
  /// it: the front has crossed and no longer bends anything.
  bool get contentAtRest => hasCleared && !bendsContent;

  static double _hypot(double x, double y) => math.sqrt(x * x + y * y);
}
