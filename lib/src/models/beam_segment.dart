import 'package:flutter/foundation.dart';

import '../painting/ring_geometry.dart';
import 'beam_options.dart';

/// A corner of a beam contour, in clockwise order.
enum BeamCorner {
  /// The top-left corner.
  topLeft,

  /// The top-right corner.
  topRight,

  /// The bottom-right corner.
  bottomRight,

  /// The bottom-left corner.
  bottomLeft,
}

/// A position on a beam's perimeter, resolved against its painted box.
@immutable
sealed class BeamAnchor {
  /// Creates an anchor at arc-length fraction [t], clockwise from top-center.
  ///
  /// [t] is taken modulo one when the anchor is resolved.
  const factory BeamAnchor.fraction(double t) = _FractionAnchor;

  /// Creates an anchor [t] of the way along an edge's straight run.
  ///
  /// Travel is clockwise: left-to-right on top, top-to-bottom on right,
  /// right-to-left on bottom, and bottom-to-top on left.
  const factory BeamAnchor.edge(BeamEdge edge, [double t]) = _EdgeAnchor;

  /// Creates an anchor [t] of the way through [corner], clockwise.
  const factory BeamAnchor.corner(BeamCorner corner, [double t]) =
      _CornerAnchor;

  const BeamAnchor._();

  /// The top-center point of the perimeter.
  static const BeamAnchor topCenter = BeamAnchor.fraction(0);

  /// The center of the right edge's straight run.
  static const BeamAnchor rightCenter = BeamAnchor.edge(BeamEdge.right);

  /// The bottom-center point of the perimeter.
  static const BeamAnchor bottomCenter = BeamAnchor.edge(BeamEdge.bottom);

  /// The center of the left edge's straight run.
  static const BeamAnchor leftCenter = BeamAnchor.edge(BeamEdge.left);

  /// Resolves this anchor to an arc-length fraction on [perimeter].
  double resolve(BeamPerimeter perimeter);
}

final class _FractionAnchor extends BeamAnchor {
  const _FractionAnchor(this.t) : super._();

  final double t;

  @override
  double resolve(BeamPerimeter perimeter) => t % 1 < 0 ? t % 1 + 1 : t % 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _FractionAnchor && other.t == t;

  @override
  int get hashCode => Object.hash(_FractionAnchor, t);

  @override
  String toString() => 'BeamAnchor.fraction($t)';
}

final class _EdgeAnchor extends BeamAnchor {
  const _EdgeAnchor(this.edge, [this.t = 0.5]) : super._();

  final BeamEdge edge;
  final double t;

  @override
  double resolve(BeamPerimeter perimeter) => perimeter.fractionOfEdge(edge, t);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EdgeAnchor && other.edge == edge && other.t == t;

  @override
  int get hashCode => Object.hash(_EdgeAnchor, edge, t);

  @override
  String toString() => 'BeamAnchor.edge($edge, $t)';
}

final class _CornerAnchor extends BeamAnchor {
  const _CornerAnchor(this.corner, [this.t = 0.5]) : super._();

  final BeamCorner corner;
  final double t;

  @override
  double resolve(BeamPerimeter perimeter) =>
      perimeter.fractionOfCorner(corner, t);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CornerAnchor && other.corner == corner && other.t == t;

  @override
  int get hashCode => Object.hash(_CornerAnchor, corner, t);

  @override
  String toString() => 'BeamAnchor.corner($corner, $t)';
}

/// A clockwise portion of the perimeter over which a beam is visible.
///
/// A segment masks an unchanged full-ring animation: constants and blob
/// positions never move. The traveling beam enters at [start] and leaves at
/// [end], the line variant travels the segment, and pulse blobs outside it
/// are hidden. Ends fade over [feather] logical pixels along the perimeter.
///
/// A beam covering the lower half of a square runs from right-center, around
/// the bottom, to left-center:
///
/// ```dart
/// BorderBeam.rotate(
///   shape: const BeamShape(segment: BeamSegment.bottomHalf),
///   child: card,
/// )
/// ```
@immutable
class BeamSegment {
  /// Creates the clockwise segment from [start] to [end].
  const BeamSegment({
    required this.start,
    required this.end,
    this.feather = 32,
  });

  /// Where the clockwise visible portion begins.
  final BeamAnchor start;

  /// Where the clockwise visible portion ends, wrapping through top-center
  /// when its resolved fraction is smaller than [start].
  final BeamAnchor end;

  /// Logical pixels over which each end fades; zero makes a hard cut.
  final double feather;

  /// The lower half, from right-center through bottom-center to left-center.
  static const BeamSegment bottomHalf = BeamSegment(
    start: BeamAnchor.rightCenter,
    end: BeamAnchor.leftCenter,
  );

  /// The upper half, from left-center through top-center to right-center.
  static const BeamSegment topHalf = BeamSegment(
    start: BeamAnchor.leftCenter,
    end: BeamAnchor.rightCenter,
  );

  /// The left half, from bottom-center through left-center to top-center.
  static const BeamSegment leftHalf = BeamSegment(
    start: BeamAnchor.bottomCenter,
    end: BeamAnchor.topCenter,
  );

  /// The right half, from top-center through right-center to bottom-center.
  static const BeamSegment rightHalf = BeamSegment(
    start: BeamAnchor.topCenter,
    end: BeamAnchor.bottomCenter,
  );

  /// The bottom straight run plus the complete bottom-right and bottom-left
  /// corner arcs.
  static const BeamSegment bottomEdge = BeamSegment(
    start: BeamAnchor.corner(BeamCorner.bottomRight, 0),
    end: BeamAnchor.corner(BeamCorner.bottomLeft, 1),
  );

  /// The top straight run plus the complete top-left and top-right corner
  /// arcs.
  static const BeamSegment topEdge = BeamSegment(
    start: BeamAnchor.corner(BeamCorner.topLeft, 0),
    end: BeamAnchor.corner(BeamCorner.topRight, 1),
  );

  /// The left straight run plus the complete bottom-left and top-left corner
  /// arcs.
  static const BeamSegment leftEdge = BeamSegment(
    start: BeamAnchor.corner(BeamCorner.bottomLeft, 0),
    end: BeamAnchor.corner(BeamCorner.topLeft, 1),
  );

  /// The right straight run plus the complete top-right and bottom-right
  /// corner arcs.
  static const BeamSegment rightEdge = BeamSegment(
    start: BeamAnchor.corner(BeamCorner.topRight, 0),
    end: BeamAnchor.corner(BeamCorner.bottomRight, 1),
  );

  /// Returns this segment with all logical lengths scaled by [factor].
  BeamSegment scaledBy(double factor) =>
      BeamSegment(start: start, end: end, feather: feather * factor);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamSegment &&
          other.start == start &&
          other.end == end &&
          other.feather == feather;

  @override
  int get hashCode => Object.hash(start, end, feather);

  @override
  String toString() =>
      'BeamSegment(start: $start, end: $end, feather: $feather)';
}
