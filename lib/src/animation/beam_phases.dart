import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;

import '../constants/line_keyframes.dart';
import '../constants/pulse_params.dart';
import '../models/beam_config.dart';
import '../models/beam_options.dart';
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
    this.travelProgress = 0,
    this.travellers = const [0],
    this.reversedNow = false,
    this.finished = false,
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

  /// Raw sweep progress (0–1) of the leading beam through the current cycle.
  ///
  /// Equal to `travellers.first`. Already carries the travel direction and
  /// the phase offset, and is the value a driven `BorderBeam.progress`
  /// replaces.
  final double travelProgress;

  /// Sweep progress (0–1) of every beam travelling the contour, spaced
  /// `1 / BeamConfig.beamCount` apart. Never empty; the first entry is
  /// [travelProgress].
  final List<double> travellers;

  /// Whether the current cycle runs mirrored — always false under
  /// [BeamDirection.forward], always true under [BeamDirection.reverse], and
  /// alternating per cycle under [BeamDirection.bounce].
  ///
  /// The geometry in [travellers] is already mirrored; this flag lets a
  /// strategy mirror asymmetric tables (a comet tail, a spike schedule) to
  /// match.
  final bool reversedNow;

  /// Whether the beam has run out its `BeamPlayback.repeat` budget.
  ///
  /// The widget reacts by deactivating the clock, so the beam fades out the
  /// way an inactive one does rather than cutting off.
  final bool finished;

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

  /// Cycles the beam is allowed to run before it reports
  /// [BeamFramePhases.finished], or null to run forever.
  ///
  /// The resolved form of `BeamPlayback.repeat`: playback is the widget's
  /// business rather than a painted value, so it rides on the resolver
  /// instead of on [BeamConfig].
  int? repeatCycles;

  /// Seconds added to the sample time of the travel tracks only.
  ///
  /// Shifts where the sweep sits without touching the hue tracks. The widget
  /// uses it to hand a `BorderBeam.follow` gesture back to the clock: the
  /// timed sweep picks up from wherever the pointer left the beam instead of
  /// snapping back to its own schedule.
  double travelTimeOffset = 0;

  /// Samples all phases at [t] seconds with the given [fadeOpacity].
  ///
  /// [progress] takes the travel over when non-null (`BorderBeam.progress`
  /// and `BorderBeam.follow`): the sweep sits at that fraction (0–1) instead
  /// of running with the clock, while the fade envelope and the hue tracks
  /// keep running. A driven progress is used as given —
  /// [BeamConfig.direction] and [BeamConfig.phaseOffset] shape the timed
  /// sweep, not this value.
  BeamFramePhases sample(double t, double fadeOpacity, {double? progress}) {
    final v = config.variant;
    final hue = _hue(t);
    final sweep = _sweep(t, progress);
    switch (v) {
      case BeamVariant.rotate || BeamVariant.small:
        return BeamFramePhases(
          fadeOpacity: fadeOpacity * sweep.envelope,
          hueDegrees: hue,
          angleRadians: sweep.travellers.first * 2 * math.pi,
          travelProgress: sweep.travellers.first,
          travellers: sweep.travellers,
          reversedNow: sweep.reversed,
          finished: sweep.finished,
        );
      case BeamVariant.line:
        final head = sweep.travellers.first;
        final cs = config.cycleSeconds;
        final breathe = (t / (cs * config.breatheFactor)) % 1.0;
        final spikeT = (t / (cs * config.spikeFactor)) % 1.0;
        final spike2T = (t / (cs * config.spike2Factor)) % 1.0;
        return BeamFramePhases(
          fadeOpacity: fadeOpacity * sweep.envelope,
          hueDegrees: hue,
          bloomHueDegrees: _pingPongHue(
            t + hueTimeOffset,
            config.bloomHuePeriodSeconds,
            config.hueRange + 10,
          ),
          travelProgress: head,
          travellers: sweep.travellers,
          reversedNow: sweep.reversed,
          finished: sweep.finished,
          lineX: sampleKeyframes(lineTravelX, head),
          lineW: sampleKeyframes(lineTravelW, head),
          edge: sampleKeyframes(lineEdgeFade, head),
          lineH: sampleKeyframes(lineBreatheH, breathe, easedSegments: true),
          spike: sampleKeyframes(lineSpike, spikeT, easedSegments: true),
          spike2: sampleKeyframes(lineSpike2, spike2T, easedSegments: true),
        );
      case BeamVariant.pulseInside || BeamVariant.pulseOutside:
        return BeamFramePhases(
          fadeOpacity: fadeOpacity,
          hueDegrees: hue,
          finished: sweep.finished,
          pulse: _bank!.sample(t),
        );
    }
  }

  /// Whether the beam has spent its [repeatCycles] budget at [t] seconds.
  ///
  /// The same test [sample] reports through [BeamFramePhases.finished],
  /// without building a frame: the widget checks it every tick.
  bool finishedAt(double t) {
    final budget = repeatCycles;
    if (budget == null) return false;
    return _cycleIndex(_shift(t)) >= budget;
  }

  /// The travel timeline at [t]: the phase offset and any follow hand-back
  /// folded in.
  double _shift(double t) =>
      t + config.phaseOffset * config.cycleSeconds + travelTimeOffset;

  int _cycleIndex(double shifted) {
    final period =
        config.cycleSeconds + (config.variant.isPulse ? 0 : config.gapSeconds);
    return period <= 0 ? 0 : (shifted / period).floor();
  }

  /// The travel state of every beam at [t]: their progress, the gap
  /// envelope, whether this cycle runs mirrored, and whether the repeat
  /// budget is spent.
  _Sweep _sweep(double t, double? driven) {
    // The phase offset moves the beam along its own timeline; the hue tracks
    // run on fixed periods of their own and stay where they are.
    final shifted = _shift(t);
    final cycleIndex = _cycleIndex(shifted);
    final budget = repeatCycles;
    final finished = budget != null && cycleIndex >= budget;
    final reversed = switch (config.direction) {
      BeamDirection.forward => false,
      BeamDirection.reverse => true,
      BeamDirection.bounce => cycleIndex.isOdd,
    };

    if (driven != null) {
      // A driven progress replaces the sweep outright, so there is no gap to
      // rest in either.
      final head = driven.clamp(0.0, 1.0);
      return _Sweep(_spread(head), 1, false, finished);
    }
    final (forward, envelope) = _travel(shifted);
    final head = reversed ? 1 - forward : forward;
    return _Sweep(
      _spread(head, reversed: reversed),
      envelope,
      reversed,
      finished,
    );
  }

  /// Places [head] and the remaining `beamCount - 1` beams evenly around the
  /// cycle, keeping [head] first.
  List<double> _spread(double head, {bool reversed = false}) {
    final n = config.beamCount;
    if (n <= 1) return [head];
    final step = 1 / n;
    return List<double>.generate(n, (i) {
      if (i == 0) return head;
      final offset = reversed ? -i * step : i * step;
      return (head + offset) % 1.0;
    });
  }

  /// A representative static frame for reduced motion: mid-cycle, no hue
  /// offset, full opacity.
  ///
  /// The frame is shown for as long as reduced motion lasts, so it carries
  /// the palette's own colors — a hue sampled from the ping-pong would tint
  /// the whole effect by an arbitrary offset.
  ///
  /// A driven [progress] is honored: a beam whose sweep is a progress
  /// readout still reads its value under reduced motion.
  BeamFramePhases staticFrame({double? progress}) {
    if (config.variant.isPulse) {
      // Freeze the breathing at rest, matching the source's
      // prefers-reduced-motion behavior (animations disabled entirely).
      return const BeamFramePhases(fadeOpacity: 1, hueDegrees: 0);
    }
    // The traveling variants keep their mid-cycle geometry.
    final phases = sample(config.cycleSeconds / 2, 1, progress: progress);
    return BeamFramePhases(
      fadeOpacity: 1,
      hueDegrees: 0,
      angleRadians: phases.angleRadians,
      travelProgress: phases.travelProgress,
      travellers: phases.travellers,
      reversedNow: phases.reversedNow,
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
    return switch (config.hueMode) {
      // Continuous full revolution (sawtooth 0→360°).
      BeamHueMode.continuous => ((hueT / config.huePeriodSeconds) % 1.0) * 360,
      BeamHueMode.pingPong => _pingPongHue(
        hueT,
        config.huePeriodSeconds,
        config.hueRange,
      ),
    };
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

/// One frame of travel: where every beam sits, the gap envelope, whether the
/// cycle is mirrored, and whether the repeat budget is spent.
class _Sweep {
  const _Sweep(this.travellers, this.envelope, this.reversed, this.finished);

  final List<double> travellers;
  final double envelope;
  final bool reversed;
  final bool finished;
}
