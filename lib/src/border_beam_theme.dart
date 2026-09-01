import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'models/beam_playback.dart';
import 'models/beam_shape.dart';
import 'models/beam_style.dart';
import 'models/beam_timing.dart';

/// App-wide defaults for every [BorderBeamTheme] descendant's beams.
///
/// Each slot is one of the beam value objects, and each of their fields is
/// nullable: a field set here fills in for every beam below that leaves it
/// null, and a beam that sets it wins.
@immutable
class BorderBeamThemeData {
  /// Creates theme defaults. Every omitted slot inherits.
  const BorderBeamThemeData({
    this.style,
    this.shape,
    this.timing,
    this.playback,
  });

  /// Default colors, theme adaptation, and filter hooks.
  final BeamStyle? style;

  /// Default corner radii, ring width, and corner family.
  final BeamShape? shape;

  /// Default cycle length, rest, rate, and hue periods.
  final BeamTiming? timing;

  /// Default play state and scheduling.
  final BeamPlayback? playback;

  /// Returns a copy with the given slots replaced. A null argument keeps the
  /// current slot.
  BorderBeamThemeData copyWith({
    BeamStyle? style,
    BeamShape? shape,
    BeamTiming? timing,
    BeamPlayback? playback,
  }) => BorderBeamThemeData(
    style: style ?? this.style,
    shape: shape ?? this.shape,
    timing: timing ?? this.timing,
    playback: playback ?? this.playback,
  );

  /// Layers [other] over this data, field by field: a field set in [other]
  /// wins, every other field falls through to this data.
  BorderBeamThemeData merge(BorderBeamThemeData? other) => other == null
      ? this
      : BorderBeamThemeData(
          style: style?.merge(other.style) ?? other.style,
          shape: shape?.merge(other.shape) ?? other.shape,
          timing: timing?.merge(other.timing) ?? other.timing,
          playback: playback?.merge(other.playback) ?? other.playback,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BorderBeamThemeData &&
          other.style == style &&
          other.shape == shape &&
          other.timing == timing &&
          other.playback == playback;

  @override
  int get hashCode => Object.hash(style, shape, timing, playback);

  @override
  String toString() =>
      'BorderBeamThemeData(style: $style, shape: $shape, '
      'timing: $timing, playback: $playback)';
}

/// Supplies default [BorderBeamThemeData] to the beams below it.
///
/// ```dart
/// BorderBeamTheme(
///   data: const BorderBeamThemeData(
///     style: BeamStyle(colors: BeamColors.ocean),
///     shape: BeamShape.circular(20, superellipse: true),
///   ),
///   child: app,
/// )
/// ```
///
/// Themes nest: [of] walks every enclosing theme and merges them from the
/// outside in, so an inner theme overrides only the fields it sets.
class BorderBeamTheme extends InheritedWidget {
  /// Creates a theme scope carrying [data].
  const BorderBeamTheme({super.key, required this.data, required super.child});

  /// The defaults this scope contributes. Merged under any inner scope.
  final BorderBeamThemeData data;

  /// The merged defaults at [context], or empty data when there is no
  /// enclosing [BorderBeamTheme].
  static BorderBeamThemeData of(BuildContext context) =>
      maybeOf(context) ?? const BorderBeamThemeData();

  /// The merged defaults at [context], or null when there is no enclosing
  /// [BorderBeamTheme].
  ///
  /// [context] is registered as a dependent of every theme in the chain, so a
  /// change to an outer one rebuilds it just as an inner one does.
  static BorderBeamThemeData? maybeOf(BuildContext context) {
    BorderBeamThemeData? merged;
    BuildContext? scope = context;
    while (scope != null) {
      final element = scope
          .getElementForInheritedWidgetOfExactType<BorderBeamTheme>();
      if (element == null) break;
      context.dependOnInheritedElement(element);
      final data = (element.widget as BorderBeamTheme).data;
      // Walking inward-out: what is already merged sits inside `data`.
      merged = data.merge(merged);
      scope = _parentOf(element);
    }
    return merged;
  }

  // The element directly above [element], where the search for the next
  // enclosing scope resumes — an inherited element's own scope map includes
  // itself, so continuing from it would find the same widget forever.
  static BuildContext? _parentOf(Element element) {
    BuildContext? parent;
    element.visitAncestorElements((ancestor) {
      parent = ancestor;
      return false;
    });
    return parent;
  }

  @override
  bool updateShouldNotify(BorderBeamTheme oldWidget) => data != oldWidget.data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BorderBeamThemeData>('data', data));
  }
}
