import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;

import '../constants/line_keyframes.dart';
import '../constants/pulse_params.dart';
import '../models/beam_config.dart';
import '../models/beam_variant.dart';
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

  /// Fade envelope (0–1), multiplied into every layer opacity.
  final double fadeOpacity;

  /// Animated hue rotation in degrees (excludes the static hue base).
  final double hueDegrees;

  /// The line bloom's separate hue track (±(hueRange+10)° over 8s).
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
  BeamPhaseResolver(this.config)
    : _bank = config.variant.isPulse
          ? PulseOscillatorBank(
              PulseParams.resolve(
                config.variant,
                config.brightness,
                config.cycleSeconds,
              ),
            )
          : null,
      _pulseParams = config.variant.isPulse
          ? PulseParams.resolve(
              config.variant,
              config.brightness,
              config.cycleSeconds,
            )
          : null;

  /// The resolved beam configuration.
  final BeamConfig config;
  final PulseOscillatorBank? _bank;
  final PulseParams? _pulseParams;

  /// The hue ping-pong keyframes of the rotate/line variants
  /// (0% −range, 50% +range, 100% −range, ease-in-out per segment, 12s).
  static const double huePeriodSeconds = 12;

  /// The line bloom hue period (8s).
  static const double bloomHuePeriodSeconds = 8;

  /// Samples all phases at [t] seconds with the given [fadeOpacity].
  BeamFramePhases sample(double t, double fadeOpacity) {
    final v = config.variant;
    final hue = _hue(t);
    switch (v) {
      case BeamVariant.rotate || BeamVariant.small:
        final cycle = (t / config.cycleSeconds) % 1.0;
        return BeamFramePhases(
          fadeOpacity: fadeOpacity,
          hueDegrees: hue,
          angleRadians: cycle * 2 * math.pi,
        );
      case BeamVariant.line:
        final cycle = (t / config.cycleSeconds) % 1.0;
        final breathe = (t / (config.cycleSeconds * 1.3)) % 1.0;
        final spikeT = (t / (config.cycleSeconds * 1.33)) % 1.0;
        final spike2T = (t / (config.cycleSeconds * 1.7)) % 1.0;
        return BeamFramePhases(
          fadeOpacity: fadeOpacity,
          hueDegrees: hue,
          bloomHueDegrees: _pingPongHue(
            t,
            bloomHuePeriodSeconds,
            config.hueRange + 10,
          ),
          lineX: sampleKeyframes(lineTravelX, cycle),
          lineW: sampleKeyframes(lineTravelW, cycle),
          edge: sampleKeyframes(lineEdgeFade, cycle),
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
  BeamFramePhases staticFrame() {
    final t = config.cycleSeconds / 2;
    final phases = sample(t, 1);
    if (config.variant.isPulse) {
      // Freeze the breathing at rest, matching the source's
      // prefers-reduced-motion behavior (animations disabled entirely).
      return BeamFramePhases(fadeOpacity: 1, hueDegrees: 0);
    }
    return phases;
  }

  double _hue(double t) {
    if (config.staticColors) return 0;
    if (config.variant.isPulse) {
      // Continuous full revolution (sawtooth 0→360°).
      final period = _pulseParams!.huePeriod;
      return ((t / period) % 1.0) * 360;
    }
    return _pingPongHue(t, huePeriodSeconds, config.hueRange);
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
