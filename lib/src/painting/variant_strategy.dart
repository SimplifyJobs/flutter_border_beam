import 'dart:ui';

import '../animation/beam_phases.dart';
import '../models/beam_config.dart';

/// Paints one beam variant.
///
/// The child sits between the two passes: [paintBehind] renders layers that
/// must show through from behind the (opaque) child — only the
/// pulse-outside halo uses it — while [paintAbove] renders the decorative
/// layers stacked over the child (every other layer in every variant).
abstract class BeamVariantStrategy {
  /// Const constructor for subclasses.
  const BeamVariantStrategy();

  /// Paint-notification cap in frames/second, mirroring the source's ~30fps
  /// pulse driver; null runs at display rate.
  double? get preferredFps => null;

  /// Layers painted behind the child (may exceed [size] bounds).
  void paintBehind(
    Canvas canvas,
    Size size,
    BeamConfig config,
    BeamFramePhases phases,
  ) {}

  /// Layers painted over the child.
  void paintAbove(
    Canvas canvas,
    Size size,
    BeamConfig config,
    BeamFramePhases phases,
  );
}
