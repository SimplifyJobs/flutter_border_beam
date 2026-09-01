import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// The easing curve behind the beam's fade-in / fade-out envelope.
///
/// The envelope is driven by a real spring simulation rather than a cubic
/// bezier so the beam settles with a little momentum instead of decelerating
/// mechanically. The spring is displaced by 1 with no initial velocity and
/// simulated over `t ∈ [0, 1]`:
///
/// * mass `1.0`
/// * stiffness `180.0`
/// * damping `20.0`
///
/// Those give a damping ratio of `ζ = damping / (2·√(mass·stiffness)) ≈ 0.745`,
/// i.e. a lightly under-damped spring: the value rises past its target, peaks
/// at about `1.03` near `t ≈ 0.35`, and oscillates back down. Callers that
/// feed the result to an opacity must clamp it (see `BeamClock.fadeOpacity`).
///
/// The simulation has not fully settled at `t = 1`, so the residual is
/// distributed linearly across the curve; that keeps `transform(1) == 1`
/// exactly while leaving the shape untouched.
final class FadeSpringCurve extends Curve {
  /// Creates the fade envelope curve. The curve is stateless — prefer the
  /// shared [instance].
  const FadeSpringCurve();

  /// The shared instance of the curve.
  static const FadeSpringCurve instance = FadeSpringCurve();

  static final SpringSimulation _simulation = SpringSimulation(
    // mass, stiffness, damping — see the class doc.
    SpringDescription(mass: 1, stiffness: 180, damping: 20),
    0,
    1,
    0,
  );

  /// How far short of 1 the simulation is when `t` reaches 1.
  static final double _endCorrection = 1 - _simulation.x(1);

  @override
  double transformInternal(double t) => _simulation.x(t) + t * _endCorrection;
}
