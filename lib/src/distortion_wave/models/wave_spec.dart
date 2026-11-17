import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../look/wave_defaults.dart';
import 'wave_dots.dart';
import 'wave_palette.dart';
import 'wave_style.dart';
import 'wave_type.dart';

/// A [WaveStyle] with every field settled — the widget's style over the
/// theme's over the type's tuned defaults — in the units the timeline and
/// the shaders work in: seconds and logical pixels.
///
/// Value-equal: two specs from equal styles are equal, so a renderer can
/// tell a real change from a rebuild.
@immutable
final class WaveSpec {
  /// Settles [style] (over [fallback], typically a theme's style) against
  /// the tuned defaults of its type.
  factory WaveSpec.resolve(WaveStyle? style, {WaveStyle? fallback}) {
    final layered = (fallback ?? const WaveStyle()).merge(style);
    final type = layered.type ?? WaveType.vertical;
    return WaveSpec._(waveDefaults(type).merge(layered));
  }

  WaveSpec._(this.style)
    : type = style.type!,
      palette = style.palette!,
      anticipation = _within(_seconds(style.timing!.anticipation!), 0.0),
      travel = _within(_seconds(style.timing!.travel!), 0.01),
      easing = style.timing!.easing!,
      returnSpeed = _within(style.timing!.returnSpeed!, 0.01, 100),
      linger = _seconds(style.timing!.linger!),
      rimFade = _within(_seconds(style.timing!.rimFade!), 0.01),
      rimEasing = style.timing!.rimEasing!,
      hairlineLinger = _seconds(style.timing!.hairlineLinger!),
      hairlineFade = _within(_seconds(style.timing!.hairlineFade!), 0.01),
      pull = _finite(style.motion!.pull!),
      inhale = _finite(style.motion!.inhale!),
      gatherGlow = _within(style.motion!.gatherGlow!, 0.0),
      gatherDots = _within(style.motion!.gatherDots!, 0.0, 1.0),
      launchGap = _within(style.motion!.launchGap!, 0.0),
      orientation = _within(style.motion!.orientation!, 0.0, 1.0),
      amplitude = _finite(style.lens!.amplitude!),
      lensWidth = _within(style.lens!.width!, 1.0),
      aberration = _within(style.lens!.aberration!, 0.0),
      swell = _finite(style.lens!.swell!),
      blur = _within(style.lens!.blur!, 0.0, 64.0),
      blurAhead = _within(style.lens!.blurAhead!, 1.0),
      blurBehind = _within(style.lens!.blurBehind!, 1.0),
      lead = _within(style.glow!.lead!, 1.0),
      tail = _within(style.glow!.tail!, 1.0),
      strength = _within(style.glow!.strength!, 0.0, 1.0),
      rimWidth = _within(style.glow!.rimWidth!, 0.5),
      rimUnevenness = _within(style.glow!.rimUnevenness!, 0.0, 2.0),
      rimStrength = _within(style.glow!.rimStrength!, 0.0, 1.0),
      rimSoftness = _within(style.glow!.rimSoftness!, 1.0),
      rimPulse = _within(style.glow!.rimPulse!, 0.0, 1.0),
      hairlineWidth = _within(style.glow!.hairlineWidth!, 0.0),
      hairlineOpacity = _within(style.glow!.hairlineOpacity!, 0.0, 1.0),
      hairlineWhite = _within(style.glow!.hairlineWhite!, 0.0, 1.0),
      cornerRadius = _within(style.glow!.cornerRadius!, 0.0),
      dotCount = style.dots!.count!.clamp(0, WaveDots.maxWaveDots),
      dotSize = _within(style.dots!.size!, 0.0),
      dotReach = _within(style.dots!.reach!, 0.0),
      dotFlight = _within(style.dots!.flight!, 0.0),
      dotGap = _within(style.dots!.gap!, 0.0),
      dotLife = _within(_seconds(style.dots!.life!), 0.01),
      dotSpread = _within(style.dots!.spread!, 0.0, 1.0);

  /// The fully resolved style this spec was read from.
  final WaveStyle style;

  /// Which way the wave travels.
  final WaveType type;

  /// The colours.
  final WavePalette palette;

  /// Seconds of pull before the launch.
  final double anticipation;

  /// Seconds from the launch to the front having settled.
  final double travel;

  /// The front's curve over [travel], and the collapse's.
  final Curve easing;

  /// How much faster the collapse runs than the reveal.
  final double returnSpeed;

  /// Seconds after the launch the wipe of the edges starts (may be negative).
  final double linger;

  /// Seconds the wipe of the edges takes.
  final double rimFade;

  /// The wipe's curve.
  final Curve rimEasing;

  /// Seconds the hairline holds on after the colour starts to be wiped.
  final double hairlineLinger;

  /// Seconds the hairline's wipe takes.
  final double hairlineFade;

  /// Pull toward the source, pt.
  final double pull;

  /// Starting radius of the ring of colour that falls in, pt.
  final double inhale;

  /// Colour gathered before the launch, 0–2.
  final double gatherGlow;

  /// Visibility of the dots hopping in before the launch, 0–1.
  final double gatherDots;

  /// Gap between the source's outline and the front's start, pt.
  final double launchGap;

  /// How much the wave leans with the touch, 0–1.
  final double orientation;

  /// Lift of the swell, pt.
  final double amplitude;

  /// Width of the swell, pt.
  final double lensWidth;

  /// Colour fringing, as a share of the displacement.
  final double aberration;

  /// Bend of the front along its length, pt.
  final double swell;

  /// Blur radius on the front, pt.
  final double blur;

  /// Distance ahead of the front over which the blur gathers, pt.
  final double blurAhead;

  /// Distance behind the front over which the blur clears, pt.
  final double blurBehind;

  /// Feather of the band ahead of the front, pt.
  final double lead;

  /// Length of the band behind the front, pt.
  final double tail;

  /// Peak opacity of the band.
  final double strength;

  /// Reach of the colour in from the edges, pt.
  final double rimWidth;

  /// Unevenness of the colour along the edges, 0–2.
  final double rimUnevenness;

  /// Peak opacity of the colour on the edges.
  final double rimStrength;

  /// Softness of the wipe's edge, pt.
  final double rimSoftness;

  /// Liveliness of the edges, 0–1.
  final double rimPulse;

  /// Width of the hairline, pt.
  final double hairlineWidth;

  /// Peak opacity of the hairline.
  final double hairlineOpacity;

  /// Whitening of the hairline under the pulse, 0–1.
  final double hairlineWhite;

  /// Corner radius of the view the wave fills, pt.
  final double cornerRadius;

  /// Number of dots.
  final int dotCount;

  /// Diameter of the largest dot, pt.
  final double dotSize;

  /// Farthest a dot is born from the source, pt.
  final double dotReach;

  /// Length of one hop toward the source, pt.
  final double dotFlight;

  /// Closest a dot comes to the source, pt.
  final double dotGap;

  /// Seconds after the launch by which the last dot has faded.
  final double dotLife;

  /// How far the dots are thrown, as a share of the front's way.
  final double dotSpread;

  /// Seconds for the whole of a reveal: by then the swell has settled, the
  /// edges have cleared and the last dot has faded.
  double get duration =>
      anticipation +
      math.max(
        math.max(travel * _travelShare, linger + rimFade),
        math.max(linger + hairlineLinger + hairlineFade, dotLife),
      );

  /// Seconds for a full collapse back into the source.
  double get returnDuration => duration / returnSpeed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WaveSpec && other.style == style;

  @override
  int get hashCode => style.hashCode;

  @override
  String toString() => 'WaveSpec($type)';

  /// The share of [travel] a reveal plays out: by then the front has moved
  /// as far as the tuned easing has at 0.6 of it — past every corner of the
  /// view — so switching to the revealed side at the end cannot be seen.
  late final double _travelShare = _travelShareFor(easing);

  static const double _tunedTravelShare = 0.6;

  static double _travelShareFor(Curve easing) {
    if (identical(easing, waveTravelEasing)) return _tunedTravelShare;
    final level = waveTravelEasing.transform(_tunedTravelShare);
    // Scanned back from the end, so a curve that overshoots and comes back
    // counts only from where it stays at the level. Never shorter than the
    // tuned share.
    const steps = 256;
    for (var i = steps - 1; i >= 0; i--) {
      if (easing.transform(i / steps) < level) {
        return math.max(_tunedTravelShare, (i + 1) / steps);
      }
    }
    return _tunedTravelShare;
  }

  static double _seconds(Duration duration) =>
      duration.inMicroseconds / Duration.microsecondsPerSecond;

  // The value objects assert their ranges, but only in debug builds. These
  // hold in release too, where a NaN, an infinity or a value out of range
  // would otherwise reach the timeline's arithmetic and the shaders.

  /// [value] kept within [min]–[max]; NaN becomes [min].
  static double _within(double value, double min, [double max = 1e6]) =>
      value.isNaN ? min : value.clamp(min, max);

  /// [value], or 0 when it is NaN or infinite.
  static double _finite(double value) => value.isFinite ? value : 0;
}
