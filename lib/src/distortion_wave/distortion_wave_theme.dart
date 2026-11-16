import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'models/wave_snapshots.dart';
import 'models/wave_style.dart';

/// Defaults for every `DistortionWave` (and `DistortionWaveRoute`) below a
/// [DistortionWaveTheme].
///
/// Every field is nullable and means *inherit*.
@immutable
class DistortionWaveThemeData {
  /// Creates theme data. Every omitted field is inherited.
  const DistortionWaveThemeData({this.style, this.snapshots});

  /// The default style, under each wave's own.
  final WaveStyle? style;

  /// The default snapshot policy. Defaults to [WaveSnapshots.onChange].
  final WaveSnapshots? snapshots;

  /// Returns a copy with the given fields replaced.
  DistortionWaveThemeData copyWith({
    WaveStyle? style,
    WaveSnapshots? snapshots,
  }) => DistortionWaveThemeData(
    style: style ?? this.style,
    snapshots: snapshots ?? this.snapshots,
  );

  /// Layers [other] over this data: its style merges over this one field by
  /// field, its other fields win when set.
  DistortionWaveThemeData merge(DistortionWaveThemeData? other) => other == null
      ? this
      : DistortionWaveThemeData(
          style: (style ?? const WaveStyle()).merge(other.style),
          snapshots: other.snapshots ?? snapshots,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistortionWaveThemeData &&
          other.style == style &&
          other.snapshots == snapshots;

  @override
  int get hashCode => Object.hash(style, snapshots);

  @override
  String toString() =>
      'DistortionWaveThemeData(style: $style, snapshots: $snapshots)';
}

/// Sets defaults for every distortion wave below it.
///
/// Themes nest: an inner theme's fields win, and its style merges over the
/// outer one's field by field.
///
/// ```dart
/// DistortionWaveTheme(
///   data: const DistortionWaveThemeData(
///     style: WaveStyle(palette: WavePalette.ocean),
///   ),
///   child: app,
/// )
/// ```
class DistortionWaveTheme extends InheritedWidget {
  /// Applies [data] to the waves below.
  const DistortionWaveTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The defaults.
  final DistortionWaveThemeData data;

  /// The merged defaults at [context]: every enclosing theme, outer to
  /// inner, or empty data when there is none.
  static DistortionWaveThemeData of(BuildContext context) =>
      maybeOf(context) ?? const DistortionWaveThemeData();

  /// The merged defaults at [context], or null when there is no enclosing
  /// theme. [context] depends on every theme in the chain.
  static DistortionWaveThemeData? maybeOf(BuildContext context) {
    DistortionWaveThemeData? merged;
    BuildContext? scope = context;
    while (scope != null) {
      final element = scope
          .getElementForInheritedWidgetOfExactType<DistortionWaveTheme>();
      if (element == null) break;
      context.dependOnInheritedElement(element);
      final data = (element.widget as DistortionWaveTheme).data;
      // Walking inward-out: what is already merged sits inside `data`.
      merged = data.merge(merged);
      BuildContext? parent;
      element.visitAncestorElements((ancestor) {
        parent = ancestor;
        return false;
      });
      scope = parent;
    }
    return merged;
  }

  @override
  bool updateShouldNotify(DistortionWaveTheme oldWidget) =>
      data != oldWidget.data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DistortionWaveThemeData>('data', data));
  }
}
