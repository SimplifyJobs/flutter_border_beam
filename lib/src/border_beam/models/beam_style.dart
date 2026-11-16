import 'package:flutter/foundation.dart';

import 'beam_colors.dart';
import 'beam_options.dart';
import 'beam_theme.dart';

/// How a beam looks: its colours, how it adapts to the background, how
/// strongly it glows, and how its colours drift.
///
/// Every field is nullable and means *inherit*. A field is resolved in this
/// order: the value set on the widget (a shorthand such as `colors:` wins
/// over the same field of the widget's own style), then the nearest
/// `BorderBeamTheme`, then the effect's default.
///
/// ```dart
/// BorderBeam(
///   style: const BeamStyle(colors: BeamColors.ocean, strength: 0.6),
///   child: card,
/// )
/// ```
@immutable
class BeamStyle {
  /// Creates a style. Every omitted field is inherited.
  const BeamStyle({
    this.colors,
    this.theme,
    this.strength,
    this.glow,
    this.hueShift,
    this.hueMode,
    this.hueBase,
  }) : assert(glow == null || glow >= 0, 'glow must not be negative');

  /// The palette painted around the border. Defaults to
  /// [BeamColors.colorful].
  final BeamColors? colors;

  /// Background adaptation: dark, light, or follow the ambient theme.
  /// Defaults to [BeamTheme.auto].
  final BeamTheme? theme;

  /// Overall opacity of the beam, 0–1 (clamped). Default 1.
  final double? strength;

  /// Multiplies the size and intensity of every glow around the border; the
  /// crisp stroke is unaffected. Must not be negative; 0 leaves only the
  /// stroke. Default 1.
  final double? glow;

  /// How far, in degrees either side, the hue swings under
  /// [BeamHueMode.pingPong]. Default 30.
  ///
  /// Ignored by [BeamHueMode.continuous] and [BeamHueMode.none].
  final double? hueShift;

  /// How the colours drift over time. Defaults to the effect's own choice
  /// (`BeamEffect.defaultHueMode`).
  ///
  /// Palettes with a fixed hue ([BeamColors.mono], [BeamColors.gold]) never
  /// drift, whatever this says.
  final BeamHueMode? hueMode;

  /// A static hue rotation, in degrees, applied to the whole palette on top
  /// of any drift. Default 0.
  final double? hueBase;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value; build a new [BeamStyle] to clear a field back to inherit.
  BeamStyle copyWith({
    BeamColors? colors,
    BeamTheme? theme,
    double? strength,
    double? glow,
    double? hueShift,
    BeamHueMode? hueMode,
    double? hueBase,
  }) => BeamStyle(
    colors: colors ?? this.colors,
    theme: theme ?? this.theme,
    strength: strength ?? this.strength,
    glow: glow ?? this.glow,
    hueShift: hueShift ?? this.hueShift,
    hueMode: hueMode ?? this.hueMode,
    hueBase: hueBase ?? this.hueBase,
  );

  /// Layers [other] over this style: every non-null field of [other] wins,
  /// every null one inherits from this style.
  BeamStyle merge(BeamStyle? other) => other == null
      ? this
      : copyWith(
          colors: other.colors,
          theme: other.theme,
          strength: other.strength,
          glow: other.glow,
          hueShift: other.hueShift,
          hueMode: other.hueMode,
          hueBase: other.hueBase,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamStyle &&
          other.colors == colors &&
          other.theme == theme &&
          other.strength == strength &&
          other.glow == glow &&
          other.hueShift == hueShift &&
          other.hueMode == hueMode &&
          other.hueBase == hueBase;

  @override
  int get hashCode =>
      Object.hash(colors, theme, strength, glow, hueShift, hueMode, hueBase);

  @override
  String toString() {
    final fields = <String>[
      if (colors != null) 'colors: $colors',
      if (theme != null) 'theme: $theme',
      if (strength != null) 'strength: $strength',
      if (glow != null) 'glow: $glow',
      if (hueShift != null) 'hueShift: $hueShift',
      if (hueMode != null) 'hueMode: $hueMode',
      if (hueBase != null) 'hueBase: $hueBase',
    ];
    return 'BeamStyle(${fields.join(', ')})';
  }
}
