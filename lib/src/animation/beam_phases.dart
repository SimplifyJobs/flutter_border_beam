import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;

import '../constants/line_keyframes.dart';
import '../constants/pulse_params.dart';
import '../models/beam_config.dart';
import '../models/beam_variant.dart';
import 'beam_clock.dart';
import 'oscillator.dart';

/// Samples a keyframe table at cycle progress [t] (0–1).
///
/// [easedSegments] applies ease-in-out within each segment, matching CSS
/// `animation-timing-function: ease-in-out` semantics (the timing function
/// applies per keyframe segment); linear tables pass `false`.
double sampleKeyframes(
  List<BeamKeyframe> frames,
  double t, {
  bool easedSegments = false,
}) {
  final clamped = t.clamp(0.0, 1.0);
  for (var i = 1; i < frames.length; i++) {
    final prev = frames[i - 1];
    final next = frames[i];
    if (clamped <= next.t) {
      final span = next.t - prev.t;
      if (span <= 0) return next.value;
      var local = (clamped - prev.t) / span;
      if (easedSegments) local = Curves.easeInOut.transform(local);
      return prev.value + (next.value - prev.value) * local;
    }
  }
  return frames.last.value;
}

/// Every animated value the painter needs for one frame.
class BeamFramePhases {
  /// Creates a frame phase snapshot.
  const BeamFramePhases({
    required this.fadeOpacity,
    required this.hueDegrees,
    this.bloomHueDegrees = 0,
    this.angleRadians = 0,
    this.lineX = 0.06,
    this.lineW = 0.5,
    this.lineH = 0.8,
    this.spike = 1,
    this.spike2 = 1,
    this.edge = 1,
    this.pulse = const PulsePhaseSet.identity(),
  });

  /// Fade envelope (0–1), multiplied into every layer opacity. Carries the
  /// rest between sweeps (`BeamTiming.cycleGap`) as well as the beam's own
  /// fade in and out.
  final double fadeOpacity;

  /// Animated hue rotation in degrees (excludes the static hue base).
  final double hueDegrees;

  /// The line bloom's separate hue track (±(hueRange+10)°, over
  /// `BeamConfig.bloomHuePeriodSeconds`).
  final double bloomHueDegrees;

  /// Rotating conic window angle (rotate/small), radians.
  final double angleRadians;

  /// Line beam x position, fraction of width.
  final double lineX;

  /// Line beam width factor.
  final double lineW;

  /// Line beam height factor.
  final double lineH;

  /// Line spike scale (drives spikes at 8/78/92%; inverted at 36/92%).
  final double spike;

  /// Second line spike scale (drives spikes at 22/50/64%).
  final double spike2;

  /// Line edge fade factor multiplying all three layers.
  final double edge;

  /// Pulse oscillator values.
  final PulsePhaseSet pulse;
}

/// Computes [BeamFramePhases] from elapsed time for a given config,
/// mirroring the source's CSS keyframes and JS pulse driver exactly.
class BeamPhaseResolver {
  /// Creates a resolver for [config].
  factory BeamPhaseResolver(BeamConfig config) => BeamPhaseResolver._(
    config,
    config.variant.isPulse
        ? PulseParams.resolve(
            config.variant,
            config.brightness,
            config.cycleSeconds,
          )
        : null,
  );

  BeamPhaseResolver._(this.config, PulseParams? pulseParams)
    : _bank = pulseParams == null ? null : PulseOscillatorBank(pulseParams);

  /// The resolved beam configuration.
  final BeamConfig config;
  final PulseOscillatorBank? _bank;

  /// Seconds added to the sample time of the fixed-period hue tracks only.
  ///
  /// The cycle-derived tracks (rotate angle, line travel, pulse
  /// oscillators) all scale with [BeamConfig.cycleSeconds], so a cycle
  /// change can be absorbed by rescaling elapsed time
  /// ([BeamClock.retime]) — their fractions come out unchanged. The hue
  /// tracks run on fixed periods ([BeamConfig.huePeriodSeconds],
  /// [BeamConfig.bloomHuePeriodSeconds]) and would jump under that rescale,
  /// so the widget shifts them back by the amount the timeline moved.
  double hueTimeOffset = 0;

  /// Samples all phases at [t] seconds with the given [fadeOpacity].
  BeamFramePhases sample(double t, double fadeOpacity) {
    final v = config.variant;
    final hue = _hue(t);
    switch (v) {
      case BeamVariant.rotate || BeamVariant.small:
        final (progress, envelope) = _travel(t);
        return BeamFramePhases(
          fadeOpacity: fadeOpacity * envelope,
          hueDegrees: hue,
          angleRadians: progress * 2 * math.pi,
        );
      case BeamVariant.line:
        final (progress, envelope) = _travel(t);
        final cs = config.cycleSeconds;
        final breathe = (t / (cs * config.breatheFactor)) % 1.0;
        final spikeT = (t / (cs * config.spikeFactor)) % 1.0;
        final spike2T = (t / (cs * config.spike2Factor)) % 1.0;
        return BeamFramePhases(
          fadeOpacity: fadeOpacity * envelope,
          hueDegrees: hue,
          bloomHueDegrees: _pingPongHue(
            t + hueTimeOffset,
            config.bloomHuePeriodSeconds,
            config.hueRange + 10,
          ),
          lineX: sampleKeyframes(lineTravelX, progress),
          lineW: sampleKeyframes(lineTravelW, progress),
          edge: sampleKeyframes(lineEdgeFade, progress),
          lineH: sampleKeyframes(lineBreatheH, breathe, easedSegments: true),
          spike: sampleKeyframes(lineSpike, spikeT, easedSegments: true),
          spike2: sampleKeyframes(lineSpike2, spike2T, easedSegments: true),
        );
      case BeamVariant.pulseInside || BeamVariant.pulseOutside:
        return BeamFramePhases(
          fadeOpacity: fadeOpacity,
          hueDegrees: hue,
          pulse: _bank!.sample(t),
        );
    }
  }

  /// A representative static frame for reduced motion: mid-cycle, no hue
  /// offset, full opacity.
  ///
  /// The frame is shown for as long as reduced motion lasts, so it carries
  /// the palette's own colors — a hue sampled from the ping-pong would tint
  /// the whole effect by an arbitrary offset.
  BeamFramePhases staticFrame() {
    if (config.variant.isPulse) {
      // Freeze the breathing at rest, matching the source's
      // prefers-reduced-motion behavior (animations disabled entirely).
      return const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0);
    }
    // The traveling variants keep their mid-cycle geometry.
    final phases = sample(config.cycleSeconds / 2, 1);
    return BeamFramePhases(
      fadeOpacity: 1,
      hueDegrees: 0,
      angleRadians: phases.angleRadians,
      lineX: phases.lineX,
      lineW: phases.lineW,
      lineH: phases.lineH,
      spike: phases.spike,
      spike2: phases.spike2,
      edge: phases.edge,
    );
  }

  /// Travel progress through one sweep (0–1) and the gap envelope that
  /// multiplies into the fade at [t].
  ///
  /// Without a gap this is the plain `t / cycle` wrap. With one, the sweep
  /// runs over the first `cycleSeconds` of each `cycle + gap` period and then
  /// parks at progress 1 while the envelope eases out and back in over
  /// `min(0.25s, gap / 2)` at each end of the rest.
  (double progress, double envelope) _travel(double t) {
    final cycle = config.cycleSeconds;
    final gap = config.gapSeconds;
    if (gap <= 0) return ((t / cycle) % 1.0, 1.0);
    final local = t % (cycle + gap);
    if (local < cycle) return (local / cycle, 1.0);
    final intoGap = local - cycle;
    final fade = math.min(0.25, gap / 2);
    if (fade <= 0) return (1.0, 0.0);
    if (intoGap < fade) return (1.0, 1 - _smoothstep(intoGap / fade));
    final outFrom = gap - fade;
    if (intoGap > outFrom) {
      return (1.0, _smoothstep((intoGap - outFrom) / fade));
    }
    return (1.0, 0.0);
  }

  // Smoothstep: zero slope at both ends, so the rest opens and closes without
  // a visible corner.
  static double _smoothstep(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  double _hue(double t) {
    if (config.staticColors) return 0;
    final hueT = t + hueTimeOffset;
    if (config.variant.isPulse) {
      // Continuous full revolution (sawtooth 0→360°).
      return ((hueT / config.huePeriodSeconds) % 1.0) * 360;
    }
    return _pingPongHue(hueT, config.huePeriodSeconds, config.hueRange);
  }

  // CSS `beam-hue-shift`: keyframes −range @0%, +range @50%, −range @100%,
  // ease-in-out per segment.
  static double _pingPongHue(double t, double period, double range) {
    final cycle = (t / period) % 1.0;
    final local = cycle < 0.5 ? cycle / 0.5 : (1 - cycle) / 0.5;
    final eased = Curves.easeInOut.transform(local.clamp(0.0, 1.0));
    return -range + 2 * range * eased;
  }
}
