import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;

import '../models/beam_config.dart';
import '../models/beam_options.dart';

/// The time-driven values one frame is painted from.
///
/// Effects turn these into light; nothing here knows what an effect looks
/// like.
class BeamFramePhases {
  /// Creates a frame phase snapshot.
  const BeamFramePhases({
    required this.fadeOpacity,
    required this.hueDegrees,
    this.travelProgress = 0,
    this.travellers = const [0],
    this.reversedNow = false,
    this.finished = false,
    this.cycles = 0,
    this.driven = false,
  });

  /// Fade envelope (0–1), multiplied into the whole beam. Carries the rest
  /// between sweeps (`BeamTiming.cycleGap`) as well as the beam's own fade in
  /// and out.
  final double fadeOpacity;

  /// Animated hue rotation in degrees (excludes the static hue base).
  final double hueDegrees;

  /// Sweep progress (0–1) of the leading beam through the current cycle.
  ///
  /// Equal to `travellers.first`. Already carries the travel direction and
  /// the phase offset, and is the value a driven `BorderBeam.progress`
  /// replaces.
  final double travelProgress;

  /// Sweep progress (0–1) of every beam travelling the border, spaced
  /// `1 / BeamConfig.beamCount` apart. Never empty; the first entry is
  /// [travelProgress].
  final List<double> travellers;

  /// Whether the current cycle runs mirrored — always false under
  /// [BeamDirection.forward], always true under [BeamDirection.reverse], and
  /// alternating per cycle under [BeamDirection.bounce].
  final bool reversedNow;

  /// Whether the beam has run out its `BeamPlayback.repeat` budget.
  final bool finished;

  /// Elapsed time in cycles (continuous, never wraps): the clock the ambient
  /// effects breathe and stream by.
  final double cycles;

  /// Whether [travelProgress] comes from `BorderBeam.progress` or `follow`
  /// rather than the clock. Effects map a driven position linearly (a
  /// readout) and a timed one with their own easing.
  final bool driven;
}

/// Computes [BeamFramePhases] from elapsed time for a given config.
class BeamPhaseResolver {
  /// Creates a resolver for [config].
  BeamPhaseResolver(this.config);

  /// The resolved beam configuration.
  final BeamConfig config;

  /// Seconds added to the sample time of the fixed-period hue track only.
  ///
  /// The cycle-derived tracks all scale with [BeamConfig.cycleSeconds], so a
  /// cycle change is absorbed by rescaling elapsed time (`BeamClock.retime`).
  /// The hue track runs on a fixed period and would jump under that rescale,
  /// so the widget shifts it back by the amount the timeline moved.
  double hueTimeOffset = 0;

  /// Cycles the beam is allowed to run before it reports
  /// [BeamFramePhases.finished], or null to run forever.
  int? repeatCycles;

  /// Seconds added to the sample time of the travel track only.
  ///
  /// The widget uses it to hand a `BorderBeam.follow` gesture back to the
  /// clock: the timed sweep picks up from wherever the pointer left the beam.
  double travelTimeOffset = 0;

  /// Seconds added to the sample time of the ambient track
  /// ([BeamFramePhases.cycles]) only.
  ///
  /// A retime is a pure rescale only without a gap, phase offset, or follow
  /// hand-back in play; otherwise the clock is moved to put the *sweep* where
  /// it belongs. The widget sets this to the difference, so the ambient track
  /// reads the timeline it would have had.
  double breatheTimeOffset = 0;

  bool get _travels => config.effect.travels;

  /// Samples all phases at [t] seconds with the given [fadeOpacity].
  ///
  /// [progress] takes the travel over when non-null (`BorderBeam.progress`
  /// and `BorderBeam.follow`): the sweep sits at that fraction (0–1) instead
  /// of running with the clock, while the fade and hue keep running.
  BeamFramePhases sample(double t, double fadeOpacity, {double? progress}) {
    final hue = _hue(t);
    final cycles = (t + breatheTimeOffset) / config.cycleSeconds;
    if (!_travels) {
      return BeamFramePhases(
        fadeOpacity: fadeOpacity,
        hueDegrees: hue,
        reversedNow: config.direction == BeamDirection.reverse,
        finished: _finished(_shift(t)),
        cycles: cycles,
      );
    }
    final sweep = _sweep(t, progress);
    return BeamFramePhases(
      fadeOpacity: fadeOpacity * sweep.envelope,
      hueDegrees: hue,
      travelProgress: sweep.travellers.first,
      travellers: sweep.travellers,
      reversedNow: sweep.reversed,
      finished: sweep.finished,
      cycles: cycles,
      driven: progress != null,
    );
  }

  /// Whether the beam has spent its [repeatCycles] budget at [t] seconds.
  bool finishedAt(double t) => _finished(_shift(t));

  bool _finished(double shifted) {
    final budget = repeatCycles;
    return budget != null && _cycleIndex(shifted) >= budget;
  }

  double _shift(double t) =>
      t + config.phaseOffset * config.cycleSeconds + travelTimeOffset;

  int _cycleIndex(double shifted) {
    final period = config.cycleSeconds + (_travels ? config.gapSeconds : 0);
    return period <= 0 ? 0 : (shifted / period).floor();
  }

  _Sweep _sweep(double t, double? driven) {
    final shifted = _shift(t);
    final cycleIndex = _cycleIndex(shifted);
    final finished = _finished(shifted);
    final reversed = switch (config.direction) {
      BeamDirection.forward => false,
      BeamDirection.reverse => true,
      BeamDirection.bounce => cycleIndex.isOdd,
    };
    if (driven != null) {
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

  /// A representative static frame for reduced motion: full opacity, the
  /// palette's own colours, travelling effects mid-sweep.
  ///
  /// A driven [progress] is honored: a beam whose sweep is a progress
  /// readout still reads its value under reduced motion.
  BeamFramePhases staticFrame({double? progress}) {
    if (!_travels) {
      return BeamFramePhases(
        fadeOpacity: 1,
        hueDegrees: 0,
        cycles: 0.3,
        reversedNow: config.direction == BeamDirection.reverse,
      );
    }
    final head = progress?.clamp(0.0, 1.0) ?? 0.35;
    return BeamFramePhases(
      fadeOpacity: 1,
      hueDegrees: 0,
      travelProgress: head,
      travellers: _spread(head),
      cycles: 0.3,
      driven: progress != null,
    );
  }

  /// Travel progress through one sweep (0–1) and the gap envelope at [t].
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

  static double _smoothstep(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  double _hue(double t) {
    final hueT = t + hueTimeOffset;
    return switch (config.hueMode) {
      BeamHueMode.none => 0,
      BeamHueMode.continuous => ((hueT / config.huePeriodSeconds) % 1.0) * 360,
      BeamHueMode.pingPong => _pingPongHue(
        hueT,
        config.huePeriodSeconds,
        config.hueShift,
      ),
    };
  }

  // −range at 0%, +range at 50%, −range at 100%, eased per half.
  static double _pingPongHue(double t, double period, double range) {
    final cycle = (t / period) % 1.0;
    final local = cycle < 0.5 ? cycle / 0.5 : (1 - cycle) / 0.5;
    final eased = Curves.easeInOut.transform(local.clamp(0.0, 1.0));
    return -range + 2 * range * eased;
  }
}

class _Sweep {
  const _Sweep(this.travellers, this.envelope, this.reversed, this.finished);

  final List<double> travellers;
  final double envelope;
  final bool reversed;
  final bool finished;
}
