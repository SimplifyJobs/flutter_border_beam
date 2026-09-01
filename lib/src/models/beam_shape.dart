import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The geometry of a beam: its corner radii, ring thickness, and corner
/// family (circular arcs or superellipse).
///
/// Every field is nullable and means *inherit*. A field is resolved in this
/// order: the value set on the widget (the `borderRadius` shorthand wins over
/// [radius]), then the nearest `BorderBeamTheme`, then the variant's preset
/// (radius 16, or 32 for `BeamVariant.small`; border width 1).
///
/// ```dart
/// BorderBeam.rotate(
///   shape: const BeamShape.circular(24, superellipse: true),
///   child: card,
/// )
/// ```
@immutable
class BeamShape {
  /// Creates a shape with per-corner [radius]. Every omitted field is
  /// inherited.
  const BeamShape({this.radius, this.borderWidth, this.superellipse});

  /// A shape whose four corners share one [radius].
  ///
  /// Not `const` — building a [BorderRadius] from a plain number is a
  /// runtime construction, the same reason [BorderRadius.circular] is not
  /// const either. For a const beam, pass the `borderRadius` shorthand on the
  /// widget (a number, so it stays const) and keep this object for the rest.
  BeamShape.circular(double radius, {this.borderWidth, this.superellipse})
    : radius = BorderRadius.circular(radius);

  /// A pill: each corner rounds to half the shortest side of the box, so a
  /// square box comes out a circle.
  ///
  /// The radius is infinite and the ring geometry clamps it per corner, which
  /// is what makes it track the box as it resizes.
  const BeamShape.stadium({this.borderWidth, this.superellipse})
    : radius = const BorderRadius.all(Radius.circular(double.infinity));

  /// Corner radii of the beam contour, direction-aware.
  ///
  /// Resolved against the ambient [Directionality] (or LTR when there is
  /// none), then clamped per corner the way [RRect.scaleRadii] does: when two
  /// radii on one side exceed that side's length, all four scale down by the
  /// smallest offending ratio. Match your child's decoration radius — the
  /// beam does not read it.
  final BorderRadiusGeometry? radius;

  /// Stroke ring thickness in logical px. Default 1, as in the source.
  final double? borderWidth;

  /// Whether the contour is a rounded superellipse (an Apple-style squircle)
  /// instead of circular corner arcs.
  ///
  /// Defaults to false, matching the circular-arc corners of the source
  /// library's CSS `border-radius`.
  final bool? superellipse;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamShape] to clear a field back to inherit.
  BeamShape copyWith({
    BorderRadiusGeometry? radius,
    double? borderWidth,
    bool? superellipse,
  }) => BeamShape(
    radius: radius ?? this.radius,
    borderWidth: borderWidth ?? this.borderWidth,
    superellipse: superellipse ?? this.superellipse,
  );

  /// Layers [other] over this shape: every non-null field of [other] wins,
  /// every null one inherits from this shape.
  BeamShape merge(BeamShape? other) => other == null
      ? this
      : copyWith(
          radius: other.radius,
          borderWidth: other.borderWidth,
          superellipse: other.superellipse,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamShape &&
          other.radius == radius &&
          other.borderWidth == borderWidth &&
          other.superellipse == superellipse;

  @override
  int get hashCode => Object.hash(radius, borderWidth, superellipse);

  @override
  String toString() {
    final fields = <String>[
      if (radius != null) 'radius: $radius',
      if (borderWidth != null) 'borderWidth: $borderWidth',
      if (superellipse != null) 'superellipse: $superellipse',
    ];
    return 'BeamShape(${fields.join(', ')})';
  }
}
