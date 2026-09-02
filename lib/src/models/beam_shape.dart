import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'beam_options.dart';
import 'beam_segment.dart';

/// The geometry of a beam: its corner radii, ring thickness, corner family
/// (circular arcs or superellipse), how far the ring sits from the child,
/// and which edge the line variant rides.
///
/// Every field is nullable and means *inherit*. A field is resolved in this
/// order: the value set on the widget (the `borderRadius` shorthand wins over
/// [radius]), then the nearest `BorderBeamTheme`, then the variant's preset
/// (radius 16, or 32 for `BeamVariant.small`; border width 1).
///
/// ```dart
/// BorderBeam.rotate(
///   shape: const BeamShape.all(24, superellipse: true),
///   child: card,
/// )
/// ```
@immutable
class BeamShape {
  /// Creates a shape with per-corner [radius]. Every omitted field is
  /// inherited.
  const BeamShape({
    BorderRadiusGeometry? radius,
    this.borderWidth,
    this.superellipse,
    this.edge,
    this.ringOffset,
    this.contour,
    this.segment,
    this.wrapCorners,
  }) : _radius = radius,
       _uniformRadius = null;

  /// A shape whose four corners share one radius — the const path.
  ///
  /// The number is stored as given and grown into a [BorderRadius] where
  /// [radius] is read, which is what keeps the constructor const: building a
  /// [BorderRadius] from a parameter is a runtime construction. `all` and
  /// [circular] compare equal for the same number.
  const BeamShape.all(
    double radius, {
    this.borderWidth,
    this.superellipse,
    this.edge,
    this.ringOffset,
    this.contour,
    this.segment,
    this.wrapCorners,
  }) : _uniformRadius = radius,
       _radius = null;

  /// A shape whose four corners share one [radius], built as a
  /// [BorderRadius].
  ///
  /// Not `const` — for a const beam use [BeamShape.all], which stores the
  /// number instead. Reach for this one when you already think in
  /// [BorderRadius] terms.
  BeamShape.circular(
    double radius, {
    this.borderWidth,
    this.superellipse,
    this.edge,
    this.ringOffset,
    this.contour,
    this.segment,
    this.wrapCorners,
  }) : _radius = BorderRadius.circular(radius),
       _uniformRadius = null;

  /// A pill: each corner rounds to half the shortest side of the box, so a
  /// square box comes out a circle.
  ///
  /// The radius is infinite and the ring geometry clamps it per corner, which
  /// is what makes it track the box as it resizes.
  const BeamShape.stadium({
    this.borderWidth,
    this.superellipse,
    this.edge,
    this.ringOffset,
    this.contour,
    this.segment,
    this.wrapCorners,
  }) : _radius = const BorderRadius.all(Radius.circular(double.infinity)),
       _uniformRadius = null;

  final BorderRadiusGeometry? _radius;
  final double? _uniformRadius;

  /// Corner radii of the beam contour, direction-aware.
  ///
  /// Resolved against the ambient [Directionality] (or LTR when there is
  /// none), then clamped per corner the way [RRect.scaleRadii] does: when two
  /// radii on one side exceed that side's length, all four scale down by the
  /// smallest offending ratio. Match your child's decoration radius — the
  /// beam does not read it.
  ///
  /// Ignored when [contour] is set.
  BorderRadiusGeometry? get radius {
    final uniform = _uniformRadius;
    return uniform == null ? _radius : BorderRadius.circular(uniform);
  }

  /// Stroke ring thickness in logical px. Default 1, as in the source.
  final double? borderWidth;

  /// Whether the contour is a rounded superellipse (an Apple-style squircle)
  /// instead of circular corner arcs.
  ///
  /// Defaults to false, matching the circular-arc corners of the source
  /// library's CSS `border-radius`. Ignored when [contour] is set.
  final bool? superellipse;

  /// Which edge the line variant's beam travels along. Default
  /// [BeamEdge.bottom], as in the source. The other variants ignore it.
  final BeamEdge? edge;

  /// Logical px the ring is pushed outward (positive) or pulled inward
  /// (negative) from the child's bounds, so the beam can orbit at a distance
  /// or tuck inside a padded surface. Default 0 — the ring sits on the
  /// bounds.
  final double? ringOffset;

  /// An arbitrary contour for the beam to travel instead of the rounded
  /// rectangle built from [radius].
  ///
  /// Default null. When set, [radius] and [superellipse] are ignored — the
  /// path the contour builds is the whole geometry.
  final BeamContour? contour;

  /// The clockwise portion of the contour on which the beam is visible.
  ///
  /// Null inherits, resolving to the full ring.
  final BeamSegment? segment;

  /// Whether line-variant blobs use border-path space and bend around
  /// corners instead of continuing straight past an edge.
  ///
  /// Null inherits, resolving to false.
  final bool? wrapCorners;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamShape] to clear a field back to inherit.
  BeamShape copyWith({
    BorderRadiusGeometry? radius,
    double? borderWidth,
    bool? superellipse,
    BeamEdge? edge,
    double? ringOffset,
    BeamContour? contour,
    BeamSegment? segment,
    bool? wrapCorners,
  }) => BeamShape(
    radius: radius ?? this.radius,
    borderWidth: borderWidth ?? this.borderWidth,
    superellipse: superellipse ?? this.superellipse,
    edge: edge ?? this.edge,
    ringOffset: ringOffset ?? this.ringOffset,
    contour: contour ?? this.contour,
    segment: segment ?? this.segment,
    wrapCorners: wrapCorners ?? this.wrapCorners,
  );

  /// Layers [other] over this shape: every non-null field of [other] wins,
  /// every null one inherits from this shape.
  BeamShape merge(BeamShape? other) => other == null
      ? this
      : copyWith(
          radius: other.radius,
          borderWidth: other.borderWidth,
          superellipse: other.superellipse,
          edge: other.edge,
          ringOffset: other.ringOffset,
          contour: other.contour,
          segment: other.segment,
          wrapCorners: other.wrapCorners,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamShape &&
          other.radius == radius &&
          other.borderWidth == borderWidth &&
          other.superellipse == superellipse &&
          other.edge == edge &&
          other.ringOffset == ringOffset &&
          other.contour == contour &&
          other.segment == segment &&
          other.wrapCorners == wrapCorners;

  @override
  int get hashCode => Object.hash(
    radius,
    borderWidth,
    superellipse,
    edge,
    ringOffset,
    contour,
    segment,
    wrapCorners,
  );

  @override
  String toString() {
    final fields = <String>[
      if (radius != null) 'radius: $radius',
      if (borderWidth != null) 'borderWidth: $borderWidth',
      if (superellipse != null) 'superellipse: $superellipse',
      if (edge != null) 'edge: $edge',
      if (ringOffset != null) 'ringOffset: $ringOffset',
      if (contour != null) 'contour: $contour',
      if (segment != null) 'segment: $segment',
      if (wrapCorners != null) 'wrapCorners: $wrapCorners',
    ];
    return 'BeamShape(${fields.join(', ')})';
  }
}
