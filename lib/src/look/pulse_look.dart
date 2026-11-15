import 'dart:math' as math;

// The pulse and halo breathing: tuned parameters per surface, the 17
// oscillators they drive, and the geometry constants of both glows.

/// Breathing parameters for one effect and surface, scaled to a cycle.
class PulseParams {
  const PulseParams._({
    required this.sp,
    required this.dr,
    required this.op,
    required this.gh,
    required this.bs,
    required this.ss,
    required this.ghs,
  });

  /// The inward pulse's parameters on a [dark] or light surface, for a cycle
  /// of [cycleSeconds] (the tuning is authored at 2.3s).
  factory PulseParams.pulse({
    required bool dark,
    required double cycleSeconds,
  }) {
    final k = cycleSeconds / 2.3;
    return PulseParams._(
      sp: 0.28,
      dr: dark ? 33 : 40,
      op: dark ? 0.48 : 0.45,
      gh: dark ? 0.34 : 0.22,
      bs: (dark ? 1.9 : 2.6) * k,
      ss: (dark ? 2.6 : 4.6) * k,
      ghs: (dark ? 2.4 : 5.5) * k,
    );
  }

  /// The halo's parameters on a [dark] or light surface, for a cycle of
  /// [cycleSeconds].
  factory PulseParams.halo({required bool dark, required double cycleSeconds}) {
    final k = cycleSeconds / 2.3;
    return PulseParams._(
      sp: dark ? 0.28 : 0.36,
      dr: dark ? 14 : 19,
      op: dark ? 0.46 : 0,
      gh: dark ? 0.16 : 0.58,
      bs: (dark ? 2.3 : 3.7) * k,
      ss: (dark ? 6.4 : 4.6) * k,
      ghs: (dark ? 2.4 : 3.8) * k,
    );
  }

  /// Blob size breathing amplitude (fraction).
  final double sp;

  /// Blob drift amplitude in px.
  final double dr;

  /// Corner opacity breathing depth (0 holds the corners steady).
  final double op;

  /// Global height breathing amplitude (fraction).
  final double gh;

  /// Base period of the drift and opacity oscillators, seconds.
  final double bs;

  /// Base period of the size oscillators, seconds.
  final double ss;

  /// Period of the global height oscillator, seconds.
  final double ghs;

  /// The alpha the static bloom blobs hold: the time average of the corner
  /// breathing.
  double get frozenBloomAlpha => 1 - op * 0.5;
}

/// The cosine ping-pong: 0 at whole phases, 1 at half phases.
double pingPong(double phase) => (1 - math.cos(2 * math.pi * phase)) / 2;

/// One oscillator: ping-pongs from [a] to [b] and back over [period]
/// seconds, delayed by [delay].
class PulseOscillator {
  /// Creates an oscillator.
  const PulseOscillator({
    required this.a,
    required this.b,
    required this.period,
    this.delay = 0,
  });

  /// Value at phase 0.
  final double a;

  /// Value at half period.
  final double b;

  /// Full period, seconds.
  final double period;

  /// Phase delay, seconds.
  final double delay;

  /// The value at [t] seconds.
  double sample(double t) => a + (b - a) * pingPong((t - delay) / period);
}

/// One frame of breathing: the three blob size/drift groups, the global
/// height factor, and the four corner opacities.
class PulseFrame {
  /// A frame at rest.
  PulseFrame();

  /// Width factors of groups 1–3.
  final List<double> bw = [1, 1, 1];

  /// Height factors of groups 1–3.
  final List<double> bh = [1, 1, 1];

  /// Horizontal drift of groups 1–3, px.
  final List<double> bx = [0, 0, 0];

  /// Vertical drift of groups 1–3, px.
  final List<double> by = [0, 0, 0];

  /// Global height factor.
  double bgh = 1;

  /// Corner opacities: top-left, top-right, bottom-left, bottom-right.
  final List<double> bop = [1, 1, 1, 1];
}

/// The 17 oscillators of one breathing tuning.
class PulseOscillatorBank {
  /// Builds the bank for [p].
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

  /// Samples every oscillator at [t] seconds into [out].
  void sample(double t, PulseFrame out) {
    for (var i = 0; i < 3; i++) {
      out.bw[i] = _bw[i].sample(t);
      out.bh[i] = _bh[i].sample(t);
      out.bx[i] = _bx[i].sample(t);
      out.by[i] = _by[i].sample(t);
    }
    out.bgh = _bgh.sample(t);
    for (var i = 0; i < 4; i++) {
      out.bop[i] = _bop[i].sample(t);
    }
  }
}

// ─── The inward pulse ──────────────────────────────────────────────────────

/// Radius of the corner accents of the pulse's inner glow, px.
const double pulseCornerRadius = 60;

/// Alpha of a corner accent on a dark surface.
const double pulseCornerAlphaDark = 0.18;

/// Alpha of a corner accent on a light surface.
const double pulseCornerAlphaLight = 0.08;

/// Where a corner accent has faded out (a fraction of its radius).
const double pulseCornerEndStop = 0.70;

/// Blur of the pulse's bloom, px.
const double pulseBloomBlur = 8;

// ─── The halo ──────────────────────────────────────────────────────────────

/// The halo glows' constant shrink about the box centre, horizontally.
const double haloScaleX = 0.95;

/// The halo glows' constant shrink, vertically.
const double haloScaleY = 0.9;

/// The box size the halo geometry is authored for.
const double haloReferenceWidth = 350;

/// See [haloReferenceWidth].
const double haloReferenceHeight = 140;

/// Lower clamp of the halo's size scale.
const double haloMinScale = 0.35;

/// Upper clamp of the halo's size scale.
const double haloMaxScale = 4;

/// Damping of the size-derived halo unit, which scales the glows' reach and
/// blur with the box.
const double haloUnitDamping = 0.7;

/// Growth of the halo blobs.
const double haloBoost = 1.05;

/// Multiplier on the halo glows' opacity, brightness, and saturation.
const double haloGlowMultiplier = 1.71;

/// How far past the box the core glow's shape reaches, in units.
const double haloCoreInset = 6;

/// How far past the box the bloom's shape reaches, in units.
const double haloBloomInset = 14;

/// Blur of the core glow, in units: what melts its blobs into one glow.
const double haloCoreBlur = 10;

/// Blur of the bloom, in units.
const double haloBloomBlur = 19;

/// Brightness of the halo glows before [haloGlowMultiplier].
const double haloGlowBrightness = 1.3;

/// Saturation of the halo glows before [haloGlowMultiplier].
const double haloGlowSaturation = 1.2;
