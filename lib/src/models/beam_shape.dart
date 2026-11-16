/// @docImport 'package:flutter/widgets.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'beam_segment.dart';

/// The geometry of a beam's outline: its corner radii and corner family
/// (circular arcs or superellipse), the stroke thickness, how far the outline
/// sits from the child, and which part of it is lit.
///
/// Every field is nullable and means *inherit*. A field is resolved in this
/// order: the value set on the widget (the `borderRadius` shorthand wins over
/// [radius]), then the nearest `BorderBeamTheme`, then the default (radius
/// 16, border width 1, ring offset 0, circular corners, the whole border,
/// solid).
///
/// ```dart
/// BorderBeam(
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
    this.superellipse,
    this.borderWidth,
    this.ringOffset,
    this.segment,
    this.dashes,
  }) : assert(dashes == null || dashes >= 0, 'dashes must not be negative'),
       _radius = radius,
       _uniformRadius = null;

  /// A shape whose four corners share one radius — the const path.
  ///
  /// The number is stored as given and grown into a [BorderRadius] where
  /// [radius] is read, which is what keeps the constructor const: building a
  /// [BorderRadius] from a parameter is a runtime construction. `all` and
  /// [BeamShape.circular] compare equal for the same number.
  const BeamShape.all(
    double radius, {
    this.superellipse,
    this.borderWidth,
    this.ringOffset,
    this.segment,
    this.dashes,
  }) : assert(dashes == null || dashes >= 0, 'dashes must not be negative'),
       _uniformRadius = radius,
       _radius = null;

  /// A shape whose four corners share one [radius], built as a
  /// [BorderRadius].
  ///
  /// Not `const` — for a const beam use [BeamShape.all], which stores the
  /// number instead. Reach for this one when you already think in
  /// [BorderRadius] terms.
  BeamShape.circular(
    double radius, {
    this.superellipse,
    this.borderWidth,
    this.ringOffset,
    this.segment,
    this.dashes,
  }) : assert(dashes == null || dashes >= 0, 'dashes must not be negative'),
       _radius = BorderRadius.circular(radius),
       _uniformRadius = null;

  /// A pill: each corner rounds to half the shortest side of the box, so a
  /// square box comes out a circle.
  ///
  /// The radius is infinite and the outline clamps it per corner, which is
  /// what makes it track the box as it resizes.
  const BeamShape.stadium({
    this.superellipse,
    this.borderWidth,
    this.ringOffset,
    this.segment,
    this.dashes,
  }) : assert(dashes == null || dashes >= 0, 'dashes must not be negative'),
       _radius = const BorderRadius.all(Radius.circular(double.infinity)),
       _uniformRadius = null;

  /// The corner radius used when no [radius] is set anywhere.
  static const double defaultRadius = 16;

  final BorderRadiusGeometry? _radius;
  final double? _uniformRadius;

  /// Corner radii of the outline, direction-aware. Default 16 on every
  /// corner.
  ///
  /// Resolved against the ambient [Directionality] (or LTR when there is
  /// none), then clamped per corner the way [RRect.scaleRadii] does: when two
  /// radii on one side exceed that side's length, all four scale down by the
  /// smallest offending ratio. Match your child's decoration radius — the
  /// beam does not read it.
  BorderRadiusGeometry? get radius {
    final uniform = _uniformRadius;
    return uniform == null ? _radius : BorderRadius.circular(uniform);
  }

  /// Whether the corners are superellipse curves (an Apple-style squircle,
  /// matching `RoundedSuperellipseBorder`) instead of circular arcs.
  /// Default false.
  final bool? superellipse;

  /// Stroke thickness in logical px. Default 1.
  final double? borderWidth;

  /// Logical px the outline is pushed outward (positive) or pulled inward
  /// (negative) from the child's bounds, so the beam can orbit at a distance
  /// or tuck inside a padded surface. Default 0 — the outline sits on the
  /// bounds.
  final double? ringOffset;

  /// The clockwise portion of the border on which the beam is visible.
  ///
  /// Null inherits, resolving to the whole border.
  final BeamSegment? segment;

  /// Breaks the border into this many evenly spaced dashes.
  ///
  /// Null, 0, and 1 keep the border solid (the default); 2 or more paints
  /// that many dashes. Must not be negative.
  final int? dashes;

  /// [radius] resolved against [textDirection], or [defaultRadius] on every
  /// corner when it is unset.
  ///
  /// The result is not yet clamped to a box — the outline does that.
  BorderRadius resolveRadius(TextDirection textDirection) =>
      radius?.resolve(textDirection) ??
      const BorderRadius.all(Radius.circular(defaultRadius));

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamShape] to clear a field back to inherit.
  BeamShape copyWith({
    BorderRadiusGeometry? radius,
    bool? superellipse,
    double? borderWidth,
    double? ringOffset,
    BeamSegment? segment,
    int? dashes,
  }) => BeamShape(
    radius: radius ?? this.radius,
    superellipse: superellipse ?? this.superellipse,
    borderWidth: borderWidth ?? this.borderWidth,
    ringOffset: ringOffset ?? this.ringOffset,
    segment: segment ?? this.segment,
    dashes: dashes ?? this.dashes,
  );

  /// Layers [other] over this shape: every non-null field of [other] wins,
  /// every null one inherits from this shape.
  BeamShape merge(BeamShape? other) => other == null
      ? this
      : copyWith(
          radius: other.radius,
          superellipse: other.superellipse,
          borderWidth: other.borderWidth,
          ringOffset: other.ringOffset,
          segment: other.segment,
          dashes: other.dashes,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamShape &&
          other.radius == radius &&
          other.superellipse == superellipse &&
          other.borderWidth == borderWidth &&
          other.ringOffset == ringOffset &&
          other.segment == segment &&
          other.dashes == dashes;

  @override
  int get hashCode => Object.hash(
    radius,
    superellipse,
    borderWidth,
    ringOffset,
    segment,
    dashes,
  );

  @override
  String toString() {
    final fields = <String>[
      if (radius != null) 'radius: $radius',
      if (superellipse != null) 'superellipse: $superellipse',
      if (borderWidth != null) 'borderWidth: $borderWidth',
      if (ringOffset != null) 'ringOffset: $ringOffset',
      if (segment != null) 'segment: $segment',
      if (dashes != null) 'dashes: $dashes',
    ];
    return 'BeamShape(${fields.join(', ')})';
  }
}
