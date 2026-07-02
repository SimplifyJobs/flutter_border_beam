import 'package:flutter/rendering.dart';

import '../animation/beam_clock.dart';
import '../animation/beam_phases.dart';
import '../models/beam_config.dart';
import '../models/beam_variant.dart';
import 'strategies/line_strategy.dart';
import 'strategies/pulse_inner_strategy.dart';
import 'strategies/pulse_outer_strategy.dart';
import 'strategies/rotate_strategy.dart';
import 'variant_strategy.dart';

/// Resolves the strategy singleton for a variant.
BeamVariantStrategy strategyFor(BeamVariant variant) => switch (variant) {
  BeamVariant.rotate => const RotateStrategy(compact: false),
  BeamVariant.small => const RotateStrategy(compact: true),
  BeamVariant.line => const LineStrategy(),
  BeamVariant.pulseInside => const PulseInnerStrategy(),
  BeamVariant.pulseOutside => const PulseOuterStrategy(),
};

/// The beam's [CustomPainter]. One instance paints either the behind-child
/// pass or the above-child pass of its strategy; repaints are driven
/// directly by the [BeamClock] (no widget rebuilds per frame).
class BeamPainter extends CustomPainter {
  /// Creates a painter bound to [clock].
  BeamPainter({
    required this.clock,
    required this.config,
    required this.resolver,
    required this.strategy,
    required this.behind,
    required this.staticMode,
  }) : super(repaint: clock);

  /// The time source; also the repaint trigger.
  final BeamClock clock;

  /// Resolved beam configuration.
  final BeamConfig config;

  /// Phase computer (owns the oscillator bank).
  final BeamPhaseResolver resolver;

  /// The variant strategy.
  final BeamVariantStrategy strategy;

  /// Whether this instance paints the behind-child pass.
  final bool behind;

  /// Reduced-motion mode: paint one static frame, ignore the clock.
  final bool staticMode;

  @override
  void paint(Canvas canvas, Size size) {
    final BeamFramePhases phases;
    if (staticMode) {
      phases = resolver.staticFrame();
    } else {
      if (!clock.isVisible) return;
      phases = resolver.sample(clock.elapsedSeconds, clock.fadeOpacity);
    }
    if (behind) {
      strategy.paintBehind(canvas, size, config, phases);
    } else {
      strategy.paintAbove(canvas, size, config, phases);
    }
  }

  @override
  bool shouldRepaint(BeamPainter oldDelegate) =>
      oldDelegate.config != config ||
      oldDelegate.strategy != strategy ||
      oldDelegate.behind != behind ||
      oldDelegate.staticMode != staticMode ||
      oldDelegate.clock != clock;
}
