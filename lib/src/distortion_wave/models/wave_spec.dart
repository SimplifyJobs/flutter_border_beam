import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../look/wave_defaults.dart';
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
      anticipation = math.max(_seconds(style.timing!.anticipation!), 0),
      travel = math.max(_seconds(style.timing!.travel!), 0.01),
      easing = style.timing!.easing!,
      returnSpeed = style.timing!.returnSpeed!,
      linger = _seconds(style.timing!.linger!),
      rimFade = math.max(_seconds(style.timing!.rimFade!), 0.01),
      rimEasing = style.timing!.rimEasing!,
      hairlineLinger = _seconds(style.timing!.hairlineLinger!),
      hairlineFade = math.max(_seconds(style.timing!.hairlineFade!), 0.01),
      pull = style.motion!.pull!,
      inhale = style.motion!.inhale!,
      gatherGlow = math.max(style.motion!.gatherGlow!, 0),
      gatherDots = style.motion!.gatherDots!.clamp(0.0, 1.0),
      launchGap = math.max(style.motion!.launchGap!, 0),
      orientation = style.motion!.orientation!.clamp(0.0, 1.0),
      amplitude = style.lens!.amplitude!,
      lensWidth = math.max(style.lens!.width!, 1),
      aberration = math.max(style.lens!.aberration!, 0),
      swell = style.lens!.swell!,
      blur = style.lens!.blur!.clamp(0.0, 64.0),
      blurAhead = math.max(style.lens!.blurAhead!, 1),
      blurBehind = math.max(style.lens!.blurBehind!, 1),
      lead = math.max(style.glow!.lead!, 1),
      tail = math.max(style.glow!.tail!, 1),
      strength = style.glow!.strength!.clamp(0.0, 1.0),
      rimWidth = math.max(style.glow!.rimWidth!, 0.5),
      rimUnevenness = style.glow!.rimUnevenness!.clamp(0.0, 2.0),
      rimStrength = style.glow!.rimStrength!.clamp(0.0, 1.0),
      rimSoftness = math.max(style.glow!.rimSoftness!, 1),
      rimPulse = style.glow!.rimPulse!.clamp(0.0, 1.0),
      hairlineWidth = math.max(style.glow!.hairlineWidth!, 0),
      hairlineOpacity = style.glow!.hairlineOpacity!.clamp(0.0, 1.0),
      hairlineWhite = style.glow!.hairlineWhite!.clamp(0.0, 1.0),
      cornerRadius = math.max(style.glow!.cornerRadius!, 0),
      dotCount = style.dots!.count!.clamp(0, 256),
      dotSize = math.max(style.dots!.size!, 0),
      dotReach = math.max(style.dots!.reach!, 0),
      dotFlight = math.max(style.dots!.flight!, 0),
      dotGap = math.max(style.dots!.gap!, 0),
      dotLife = math.max(_seconds(style.dots!.life!), 0.01),
      dotSpread = style.dots!.spread!.clamp(0.0, 1.0);

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
        math.max(travel * 0.6, linger + rimFade),
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

  static double _seconds(Duration duration) =>
      duration.inMicroseconds / Duration.microsecondsPerSecond;
}
