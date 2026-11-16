import 'package:flutter/foundation.dart';

import 'wave_dots.dart';
import 'wave_glow.dart';
import 'wave_lens.dart';
import 'wave_motion.dart';
import 'wave_palette.dart';
import 'wave_timing.dart';
import 'wave_type.dart';

/// Everything about how a distortion wave looks and moves, grouped the way
/// you tune it.
///
/// Every field is nullable and means *inherit*: a field set on the widget
/// wins over the nearest `DistortionWaveTheme`, which wins over the tuned
/// defaults of the wave's [type]. Start from nothing and set only what you
/// want to change:
///
/// ```dart
/// DistortionWave(
///   style: const WaveStyle(
///     type: WaveType.center,
///     palette: WavePalette.ocean,
///     glow: WaveGlow(cornerRadius: 32),
///   ),
///   ...
/// )
/// ```
@immutable
class WaveStyle {
  /// Creates a style. Every omitted field is inherited.
  const WaveStyle({
    this.type,
    this.palette,
    this.timing,
    this.motion,
    this.lens,
    this.glow,
    this.dots,
  });

  /// Which way the wave travels; also picks the tuned defaults every other
  /// field falls back to. Default [WaveType.vertical].
  final WaveType? type;

  /// The colours along the front and round the edges.
  final WavePalette? palette;

  /// The wave's life: anticipation, travel, and how long the edges linger.
  final WaveTiming? timing;

  /// The pull before the launch, and the lean with a touch.
  final WaveMotion? motion;

  /// The swell, colour fringing and progressive blur.
  final WaveLens? lens;

  /// The colour on the front and on the edges.
  final WaveGlow? glow;

  /// The dots.
  final WaveDots? dots;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value.
  WaveStyle copyWith({
    WaveType? type,
    WavePalette? palette,
    WaveTiming? timing,
    WaveMotion? motion,
    WaveLens? lens,
    WaveGlow? glow,
    WaveDots? dots,
  }) => WaveStyle(
    type: type ?? this.type,
    palette: palette ?? this.palette,
    timing: timing ?? this.timing,
    motion: motion ?? this.motion,
    lens: lens ?? this.lens,
    glow: glow ?? this.glow,
    dots: dots ?? this.dots,
  );

  /// Layers [other] over this style. Its type and palette win when set; the
  /// groups merge field by field, so `WaveStyle(lens: WaveLens(blur: 0))`
  /// over a theme's style changes only the blur.
  WaveStyle merge(WaveStyle? other) => other == null
      ? this
      : WaveStyle(
          type: other.type ?? type,
          palette: other.palette ?? palette,
          timing: _mergeGroup(timing, other.timing, (a, b) => a.merge(b)),
          motion: _mergeGroup(motion, other.motion, (a, b) => a.merge(b)),
          lens: _mergeGroup(lens, other.lens, (a, b) => a.merge(b)),
          glow: _mergeGroup(glow, other.glow, (a, b) => a.merge(b)),
          dots: _mergeGroup(dots, other.dots, (a, b) => a.merge(b)),
        );

  static T? _mergeGroup<T>(T? base, T? over, T Function(T, T) merge) {
    if (base == null) return over;
    if (over == null) return base;
    return merge(base, over);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveStyle &&
          other.type == type &&
          other.palette == palette &&
          other.timing == timing &&
          other.motion == motion &&
          other.lens == lens &&
          other.glow == glow &&
          other.dots == dots;

  @override
  int get hashCode =>
      Object.hash(type, palette, timing, motion, lens, glow, dots);

  @override
  String toString() {
    final fields = <String>[
      if (type != null) 'type: $type',
      if (palette != null) 'palette: $palette',
      if (timing != null) 'timing: $timing',
      if (motion != null) 'motion: $motion',
      if (lens != null) 'lens: $lens',
      if (glow != null) 'glow: $glow',
      if (dots != null) 'dots: $dots',
    ];
    return 'WaveStyle(${fields.join(', ')})';
  }
}
