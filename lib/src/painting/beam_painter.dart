import 'package:flutter/foundation.dart';
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
class BeamPainter extends CustomPainter with Diagnosticable {
  /// Creates a painter bound to [clock].
  BeamPainter({
    required this.clock,
    required this.config,
    required this.resolver,
    required this.strategy,
    required this.behind,
    required this.staticMode,
    this.progress,
    this.strength,
    this.frozenAt,
  }) : super(repaint: Listenable.merge([clock, ?progress, ?strength]));

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

  /// The externally driven sweep position (0–1), or null when nothing
  /// drives it.
  ///
  /// Held as a listenable rather than a value so `BorderBeam.progress` and
  /// `BorderBeam.follow` can move the beam without rebuilding the config.
  final ValueListenable<double?>? progress;

  /// A per-frame multiplier on every layer's opacity, or null for none.
  ///
  /// `BorderBeam.strengthListenable`, the live twin of `BeamStyle.strength`:
  /// it repaints without rebuilding, and the reduced-motion static frame
  /// ignores it along with the rest of the clock.
  final ValueListenable<double>? strength;

  /// The timeline position every frame is sampled at, or null to follow the
  /// clock.
  ///
  /// `BeamPlayback.debugFrozenAt`: the beam paints that one instant at full
  /// fade forever, which is what makes a screenshot of it reproducible. It
  /// lives on the painter rather than on the config because it changes no
  /// painted value — only which moment of the timeline is read — so a config
  /// cached across a freeze is still the right config.
  final Duration? frozenAt;

  // The config the strategies actually paint with: at renderScale 1 it is
  // the config itself, and below that the same beam re-authored for the
  // smaller box the canvas transform magnifies back up.
  late final BeamConfig _paintConfig = config.renderScale >= 1
      ? config
      : config.scaledBy(config.renderScale);

  @override
  void paint(Canvas canvas, Size size) {
    final driven = progress?.value;
    final BeamFramePhases phases;
    final frozen = frozenAt;
    if (frozen != null) {
      phases = resolver.sample(
        frozen.inMicroseconds / Duration.microsecondsPerSecond,
        strength?.value ?? 1,
        progress: driven,
      );
    } else if (staticMode) {
      phases = resolver.staticFrame(progress: driven);
    } else {
      if (!clock.isVisible) return;
      // The boost and the live strength both scale every layer, and layer
      // opacity is clamped at paint time — so they ride in on the fade
      // rather than needing a channel of their own.
      final amplitude = clock.boost * (strength?.value ?? 1);
      phases = resolver.sample(
        clock.elapsedSeconds,
        clock.fadeOpacity * amplitude,
        progress: driven,
      );
    }
    final scale = config.renderScale;
    if (scale >= 1) {
      _paintPass(canvas, size, config, phases);
      return;
    }
    // One transform, no layer: the beam is drawn into a box `scale` the size
    // of the real one and magnified back about the origin, so it lands
    // exactly on the box's bounds. Blur sigmas ride the canvas, so they grow
    // with everything else.
    canvas.save();
    canvas.scale(1 / scale);
    _paintPass(
      canvas,
      Size(size.width * scale, size.height * scale),
      _paintConfig,
      phases,
    );
    canvas.restore();
  }

  void _paintPass(
    Canvas canvas,
    Size size,
    BeamConfig painted,
    BeamFramePhases phases,
  ) {
    if (behind) {
      strategy.paintBehind(canvas, size, painted, phases);
    } else {
      strategy.paintAbove(canvas, size, painted, phases);
    }
  }

  @override
  bool shouldRepaint(BeamPainter oldDelegate) =>
      oldDelegate.config != config ||
      oldDelegate.strategy != strategy ||
      oldDelegate.behind != behind ||
      oldDelegate.staticMode != staticMode ||
      oldDelegate.clock != clock ||
      oldDelegate.progress != progress ||
      oldDelegate.strength != strength ||
      oldDelegate.frozenAt != frozenAt;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<BeamConfig>('config', config))
      ..add(FlagProperty('behind', value: behind, ifTrue: 'behind child'))
      ..add(
        FlagProperty('staticMode', value: staticMode, ifTrue: 'static frame'),
      )
      ..add(DoubleProperty('elapsedSeconds', clock.elapsedSeconds))
      ..add(DoubleProperty('fadeOpacity', clock.fadeOpacity))
      ..add(DoubleProperty('boost', clock.boost, defaultValue: 1.0))
      ..add(DoubleProperty('progress', progress?.value, defaultValue: null))
      ..add(DoubleProperty('strength', strength?.value, defaultValue: null))
      ..add(
        DiagnosticsProperty<Duration>('frozenAt', frozenAt, defaultValue: null),
      );
  }
}
