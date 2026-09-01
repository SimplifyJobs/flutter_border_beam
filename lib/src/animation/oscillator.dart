import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/pulse_params.dart';

/// The cosine ping-pong easing of the source's pulse driver:
/// 0 at integer phases, 1 at half-integer phases, smooth in between.
/// Negative phases (from positive delays) are valid — cosine is even.
double pingPong(double phase) => (1 - math.cos(2 * math.pi * phase)) / 2;

/// A single sinusoidal oscillator ping-ponging between [a] and [b] over
/// [period] seconds, phase-shifted by [delay] seconds.
class PulseOscillator {
  /// Creates an oscillator.
  const PulseOscillator({
    required this.a,
    required this.b,
    required this.period,
    this.delay = 0,
  });

  /// Value at phase 0 (and every full period).
  final double a;

  /// Value at half period.
  final double b;

  /// Full period in seconds.
  final double period;

  /// Phase offset in seconds (desyncs otherwise-identical oscillators).
  final double delay;

  /// Samples the oscillator at [t] seconds.
  double sample(double t) => a + (b - a) * pingPong((t - delay) / period);
}

/// The animated pulse values for one frame: three blob size/drift groups, a
/// global height factor, and four corner opacity factors.
class PulsePhaseSet {
  /// Creates a phase set. See [PulseOscillatorBank.sample].
  const PulsePhaseSet({
    required this.bw,
    required this.bh,
    required this.bx,
    required this.by,
    required this.bgh,
    required this.bopTl,
    required this.bopTr,
    required this.bopBl,
    required this.bopBr,
  });

  /// A static set with every factor at rest (used for reduced motion).
  const PulsePhaseSet.identity()
    : bw = const [1, 1, 1],
      bh = const [1, 1, 1],
      bx = const [0, 0, 0],
      by = const [0, 0, 0],
      bgh = 1,
      bopTl = 1,
      bopTr = 1,
      bopBl = 1,
      bopBr = 1;

  /// Width factors for regions 1–3 (index 0–2).
  final List<double> bw;

  /// Height factors for regions 1–3.
  final List<double> bh;

  /// Horizontal drift in px for regions 1–3.
  final List<double> bx;

  /// Vertical drift in px for regions 1–3.
  final List<double> by;

  /// Global height breathing factor.
  final double bgh;

  /// Top-left corner opacity factor.
  final double bopTl;

  /// Top-right corner opacity factor.
  final double bopTr;

  /// Bottom-left corner opacity factor.
  final double bopBl;

  /// Bottom-right corner opacity factor.
  final double bopBr;
}

/// The 17-oscillator table of the source's pulse driver
/// (React `pulseOscillatorDefs`), parameterized by [PulseParams].
class PulseOscillatorBank {
  /// Builds the bank for tuned parameters [p].
  PulseOscillatorBank(PulseParams p)
    : _bw = [
        PulseOscillator(a: 1 - p.sp, b: 1 + p.sp * 1.1, period: p.ss * 0.9),
        PulseOscillator(a: 1 + p.sp, b: 1 - p.sp * 0.85, period: p.ss * 1.1),
        PulseOscillator(
          a: 1 - p.sp * 0.6,
          b: 1 + p.sp * 1.15,
          period: p.ss * 0.98,
        ),
      ],
      _bh = [
        PulseOscillator(
          a: 1 + p.sp * 0.9,
          b: 1 - p.sp * 0.85,
          period: p.ss * 1.26,
        ),
        PulseOscillator(
          a: 1 - p.sp * 0.8,
          b: 1 + p.sp * 1.05,
          period: p.ss * 0.81,
        ),
        PulseOscillator(a: 1 + p.sp * 0.75, b: 1 - p.sp, period: p.ss * 1.4),
      ],
      _bx = [
        PulseOscillator(a: -p.dr, b: p.dr * 0.9, period: p.bs * 1.6),
        PulseOscillator(a: p.dr * 0.8, b: -p.dr * 0.9, period: p.bs * 1.88),
        PulseOscillator(a: -p.dr * 0.6, b: p.dr, period: p.bs * 1.45),
      ],
      _by = [
        PulseOscillator(a: p.dr * 0.55, b: -p.dr * 0.7, period: p.bs * 1.6),
        PulseOscillator(a: -p.dr, b: p.dr * 0.65, period: p.bs * 1.88),
        PulseOscillator(a: -p.dr * 0.85, b: p.dr * 0.45, period: p.bs * 1.45),
      ],
      _bgh = PulseOscillator(a: 1 - p.gh, b: 1 + p.gh, period: p.ghs),
      _bop = [
        PulseOscillator(a: 1 - p.op, b: 1, period: p.bs),
        PulseOscillator(
          a: 1 - p.op,
          b: 1,
          period: p.bs * 1.32,
          delay: p.bs * 0.28,
        ),
        PulseOscillator(
          a: 1 - p.op,
          b: 1,
          period: p.bs * 0.84,
          delay: p.bs * 0.55,
        ),
        PulseOscillator(
          a: 1 - p.op,
          b: 1,
          period: p.bs * 1.58,
          delay: p.bs * 0.83,
        ),
      ];

  final List<PulseOscillator> _bw;
  final List<PulseOscillator> _bh;
  final List<PulseOscillator> _bx;
  final List<PulseOscillator> _by;
  final PulseOscillator _bgh;
  final List<PulseOscillator> _bop;

  /// The bank's 17 oscillators keyed by the source's CSS custom-property
  /// name, in the source's declaration order.
  ///
  /// Exposed so `test/constants/spec_parity_test.dart` can assert the whole
  /// table against `pulse.<variant>.<theme>.oscillators` in the upstream
  /// spec, which carries the same names.
  @visibleForTesting
  Map<String, PulseOscillator> get oscillators => {
    'bw1': _bw[0],
    'bh1': _bh[0],
    'bx1': _bx[0],
    'by1': _by[0],
    'bw2': _bw[1],
    'bh2': _bh[1],
    'bx2': _bx[1],
    'by2': _by[1],
    'bw3': _bw[2],
    'bh3': _bh[2],
    'bx3': _bx[2],
    'by3': _by[2],
    'bgh': _bgh,
    'bop-tl': _bop[0],
    'bop-tr': _bop[1],
    'bop-bl': _bop[2],
    'bop-br': _bop[3],
  };

  /// Samples every oscillator at [t] seconds.
  PulsePhaseSet sample(double t) => PulsePhaseSet(
    bw: [for (final o in _bw) o.sample(t)],
    bh: [for (final o in _bh) o.sample(t)],
    bx: [for (final o in _bx) o.sample(t)],
    by: [for (final o in _by) o.sample(t)],
    bgh: _bgh.sample(t),
    bopTl: _bop[0].sample(t),
    bopTr: _bop[1].sample(t),
    bopBl: _bop[2].sample(t),
    bopBr: _bop[3].sample(t),
  );
}
