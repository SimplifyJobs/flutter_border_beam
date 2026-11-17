import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// A spring described the way Apple's animation APIs describe one — a
/// damping ratio and a response — as a [Curve] over the time it takes to
/// settle.
///
/// * [dampingRatio] (ζ): `1` settles without overshoot (SwiftUI's `.smooth`);
///   below 1 the value overshoots and rings back, lower being bouncier.
/// * [response] (seconds): the period of the spring's undamped oscillation —
///   its perceptual duration.
///
/// The curve's `[0, 1]` spans [settlingSeconds], the time until what is left
/// of the motion is imperceptible, so running it over exactly that long plays
/// the spring in real time. It starts from rest — easing in as well as out —
/// and reaches exactly 1 at `t = 1`.
final class BeamSpringCurve extends Curve {
  /// A spring with damping ratio [dampingRatio] (critically damped at 1, or
  /// at most 0.9 for a bounce) and [response] seconds.
  const BeamSpringCurve({required this.dampingRatio, required this.response})
    : assert(
        dampingRatio == 1 || (dampingRatio > 0 && dampingRatio <= 0.9),
        'dampingRatio must be 1 or in (0, 0.9]',
      ),
      assert(response > 0, 'response must be positive');

  /// The fade-in envelope: critically damped, so an opacity glides up to 1
  /// and never overshoots it.
  static const BeamSpringCurve fadeIn = BeamSpringCurve(
    dampingRatio: 1,
    response: 0.45,
  );

  /// The fade-out envelope: critically damped with a longer response than
  /// [fadeIn], so the light leaves a little more gently than it arrives and
  /// settles into nothing instead of stopping.
  static const BeamSpringCurve fadeOut = BeamSpringCurve(
    dampingRatio: 1,
    response: 0.55,
  );

  /// The rise of a pulse accent: a light bounce, so the boost pops past its
  /// peak and settles back. A flash has no rise: it starts at its peak.
  static const BeamSpringCurve pop = BeamSpringCurve(
    dampingRatio: 0.75,
    response: 0.3,
  );

  /// Damping ratio ζ — 1 is critical damping (no overshoot).
  final double dampingRatio;

  /// Response in seconds — the undamped period `2π / ω₀`.
  final double response;

  /// How long the spring takes to settle: the duration to run the curve over
  /// so it plays in real time.
  double get settlingSeconds =>
      _settlePhase(dampingRatio) * response / (2 * math.pi);

  @override
  double transformInternal(double t) {
    final settle = _settlePhase(dampingRatio);
    return _position(dampingRatio, t * settle) /
        _position(dampingRatio, settle);
  }

  @override
  bool operator ==(Object other) =>
      other is BeamSpringCurve &&
      other.dampingRatio == dampingRatio &&
      other.response == response;

  @override
  int get hashCode => Object.hash(dampingRatio, response);

  @override
  String toString() =>
      'BeamSpringCurve(dampingRatio: $dampingRatio, response: ${response}s)';
}

/// `ω₀·t` at which a critically damped spring's remaining distance
/// `(1 + u)·e^(−u)` falls to 1% of its travel. A critically damped approach is
/// monotone, so nothing worth waiting for is left after it.
const double _criticalSettlePhase = 6.6383521;

/// The remaining distance an underdamped spring settles to: tighter than the
/// critical 1%, since the curve is normalised by its value at the settle
/// phase and the overshoot has to survive that division.
const double _overshootSettleTolerance = 0.001;

/// The phase `u = ω₀·t` at which a spring with damping ratio [zeta] has
/// settled.
double _settlePhase(double zeta) {
  if (zeta >= 1) return _criticalSettlePhase;
  return math.log(
        1 / (_overshootSettleTolerance * math.sqrt(1 - zeta * zeta)),
      ) /
      zeta;
}

/// The position of a unit spring released from rest at 0 toward 1, at phase
/// `u = ω₀·t`: the closed-form damped oscillator.
double _position(double zeta, double u) {
  if (zeta >= 1) return 1 - (1 + u) * math.exp(-u);
  final damped = math.sqrt(1 - zeta * zeta);
  return 1 -
      math.exp(-zeta * u) *
          (math.cos(damped * u) + (zeta / damped) * math.sin(damped * u));
}
