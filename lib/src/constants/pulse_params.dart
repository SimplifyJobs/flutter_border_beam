import 'dart:ui';

import '../models/beam_variant.dart';

// Verbatim port of `pulseParams` from the React library (border-beam v1.3.0,
// src/styles.ts lines ~925-952). Breathing parameters tuned per variant,
// theme, and cycle duration.

/// Theme/size/duration-tuned breathing parameters shared by the oscillator
/// table and the frozen bloom alpha.
class PulseParams {
  const PulseParams._({
    required this.sp,
    required this.dr,
    required this.op,
    required this.gh,
    required this.bs,
    required this.ss,
    required this.ghs,
    required this.huePeriod,
  });

  /// Blob size breathing amplitude (fraction).
  final double sp;

  /// Drift amplitude in logical px.
  final double dr;

  /// Quadrant opacity breathing depth (0 disables opacity breathing).
  final double op;

  /// Global height breathing amplitude (fraction).
  final double gh;

  /// Base period for drift/opacity oscillators, seconds.
  final double bs;

  /// Base period for size oscillators, seconds.
  final double ss;

  /// Period of the global height oscillator, seconds.
  final double ghs;

  /// Seconds for one full 360° hue revolution.
  final double huePeriod;

  /// Computes the tuned parameters for a pulse [variant], [brightness], and
  /// cycle duration in [durationSeconds] (React default 2.3).
  factory PulseParams.resolve(
    BeamVariant variant,
    Brightness brightness,
    double durationSeconds,
  ) {
    final isDark = brightness == Brightness.dark;
    final durScale = durationSeconds / 2.3;
    if (variant == BeamVariant.pulseInside) {
      return PulseParams._(
        sp: 0.28,
        dr: isDark ? 33 : 40,
        op: isDark ? 0.48 : 0.45,
        gh: isDark ? 0.34 : 0.22,
        bs: (isDark ? 1.9 : 2.6) * durScale,
        ss: (isDark ? 2.6 : 4.6) * durScale,
        ghs: (isDark ? 2.4 : 5.5) * durScale,
        huePeriod: 16,
      );
    }
    return PulseParams._(
      sp: isDark ? 0.28 : 0.36,
      dr: isDark ? 14 : 19,
      op: isDark ? 0.46 : 0,
      gh: isDark ? 0.16 : 0.58,
      bs: (isDark ? 2.3 : 3.7) * durScale,
      ss: (isDark ? 6.4 : 4.6) * durScale,
      ghs: (isDark ? 2.4 : 3.8) * durScale,
      huePeriod: 14,
    );
  }
}
