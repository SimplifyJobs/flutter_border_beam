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

const int _geometryCacheCapacity = 16;
final List<({Rect rect, BeamConfig config, BeamRingGeometry geometry})>
_geometryCache = [];

/// The ring geometry [config] describes over [rect].
///
/// Strategies request geometry on every paint. A tiny LRU retains the recent
/// frame boundaries so path metrics and perimeter alignment are measured once
/// for equal layout and resolved-config values.
BeamRingGeometry beamGeometry(Rect rect, BeamConfig config) {
  for (var i = 0; i < _geometryCache.length; i++) {
    final entry = _geometryCache[i];
    if (entry.rect == rect && entry.config == config) {
      _geometryCache.removeAt(i);
      _geometryCache.add(entry);
      return entry.geometry;
    }
  }
  final geometry = BeamRingGeometry(
    rect: rect,
    radius: config.borderRadius,
    borderWidth: config.borderWidth,
    useSuperellipse: config.useSuperellipse,
    contour: config.contour,
    segment: config.segment,
  );
  _geometryCache.add((rect: rect, config: config, geometry: geometry));
  if (_geometryCache.length > _geometryCacheCapacity) {
    _geometryCache.removeAt(0);
  }
  return geometry;
}

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
