import 'dart:ui';

import '../animation/beam_phases.dart';
import '../models/beam_config.dart';
import 'ring_geometry.dart';

/// The rect the beam's geometry occupies: the child's bounds, pushed outward
/// or pulled inward by `BeamShape.ringOffset`.
///
/// A positive offset paints outside [size]; nothing in the beam's own render
/// tree clips that away (the `CustomPaint` clips neither painter), so the
/// ring can orbit at a distance as long as the surrounding layout leaves it
/// room.
Rect beamRect(Size size, BeamConfig config) =>
    (Offset.zero & size).inflate(config.ringOffset);

/// The ring geometry [config] describes over [rect].
BeamRingGeometry beamGeometry(Rect rect, BeamConfig config) => BeamRingGeometry(
  rect: rect,
  radius: config.borderRadius,
  borderWidth: config.borderWidth,
  useSuperellipse: config.useSuperellipse,
  contour: config.contour,
);

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
