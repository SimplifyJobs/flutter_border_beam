import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../border_beam/models/beam_colors.dart';

/// The most colours a [WavePalette] flows along its front.
const int maxWavePaletteColors = 8;

/// The colours of a distortion wave: several flowing along the front and
/// round the view's edges, a fringe riding just ahead of the front and one
/// trailing behind it.
///
/// The colours are mixed in OKLab, so neighbouring hues never pass through
/// grey.
///
/// ```dart
/// DistortionWave(palette: WavePalette.ocean, ...)
/// DistortionWave(palette: WavePalette.single(Color(0xFF35BA00)), ...)
/// DistortionWave(palette: WavePalette.fromBeamColors(BeamColors.aurora), ...)
/// ```
@immutable
class WavePalette {
  /// A palette of [colors] with a fringe [ahead] of the front and one
  /// [behind] it.
  ///
  /// The wave flows along the first [maxWavePaletteColors] colours; with
  /// none, it uses [ahead] alone. Colours are drawn opaque.
  const WavePalette({
    required this.colors,
    required this.ahead,
    required this.behind,
  });

  /// One colour, lighter ahead of the front and deeper behind it.
  factory WavePalette.single(Color color) {
    final opaque = color.withValues(alpha: 1);
    return WavePalette(
      colors: [
        opaque,
        _mix(opaque, const Color(0xFFFFFFFF), 0.25),
        opaque,
        _mix(opaque, const Color(0xFF000000), 0.15),
      ],
      ahead: _mix(opaque, const Color(0xFFFFFFFF), 0.45),
      behind: _mix(opaque, const Color(0xFF000000), 0.3),
    );
  }

  /// A wave in the colours of a border-beam palette: its stops flow along
  /// the front, the fringe ahead is a lightened first stop and the fringe
  /// behind a deepened middle one.
  factory WavePalette.fromBeamColors(BeamColors beamColors) {
    final stops = beamColors.resolve().colors;
    final opaque = [
      for (final color in stops.take(maxWavePaletteColors))
        color.withValues(alpha: 1),
    ];
    return WavePalette(
      colors: opaque,
      ahead: _mix(opaque.first, const Color(0xFFFFFFFF), 0.4),
      behind: _mix(opaque[opaque.length ~/ 2], const Color(0xFF000000), 0.25),
    );
  }

  /// Yellow, sky, violet, pink, peach, periwinkle and aqua, with a pink
  /// fringe ahead and a blue one behind. The default for the vertical and
  /// horizontal waves.
  static const WavePalette colorful = WavePalette(
    colors: [
      Color(0xFFFFC915),
      Color(0xFF7EC4FF),
      Color(0xFFB428E6),
      Color(0xFFEB64A0),
      Color(0xFFFFB07A),
      Color(0xFF9AA0FF),
      Color(0xFF7FD9EE),
    ],
    ahead: Color(0xFFFF7AB6),
    behind: Color(0xFF5ABEFF),
  );

  /// Greens only, from a success badge's green out to lime and mint. The
  /// default for the center wave.
  static const WavePalette green = WavePalette(
    colors: [
      Color(0xFF35BA00),
      Color(0xFF8CEB5A),
      Color(0xFF00C46E),
      Color(0xFFBEFA82),
      Color(0xFF28A03C),
      Color(0xFF6EE1A0),
      Color(0xFF5AD228),
    ],
    ahead: Color(0xFFC4FF78),
    behind: Color(0xFF009646),
  );

  /// Blues and teals.
  static const WavePalette ocean = WavePalette(
    colors: [
      Color(0xFF2878FF),
      Color(0xFF5AC8FF),
      Color(0xFF1450C8),
      Color(0xFF78E6F0),
      Color(0xFF3C96FF),
      Color(0xFF96B4FF),
      Color(0xFF00B4DC),
    ],
    ahead: Color(0xFF96E6FF),
    behind: Color(0xFF1E46DC),
  );

  /// Oranges, pinks and magentas.
  static const WavePalette sunset = WavePalette(
    colors: [
      Color(0xFFFF8C3C),
      Color(0xFFFF5A78),
      Color(0xFFFFC850),
      Color(0xFFF0465A),
      Color(0xFFFFAA78),
      Color(0xFFDC5AC8),
      Color(0xFFFF7850),
    ],
    ahead: Color(0xFFFFDC78),
    behind: Color(0xFFC83CA0),
  );

  /// Whites and silvers.
  static const WavePalette mono = WavePalette(
    colors: [
      Color(0xFFF0F0F5),
      Color(0xFFC8CDD7),
      Color(0xFFFFFFFF),
      Color(0xFFAAAFBE),
      Color(0xFFE1E4EB),
      Color(0xFFBEC3CD),
      Color(0xFFF5F5FA),
    ],
    ahead: Color(0xFFFFFFFF),
    behind: Color(0xFFA0A5B4),
  );

  /// The named palettes, in order — handy for a picker.
  static const Map<String, WavePalette> presets = {
    'colorful': colorful,
    'green': green,
    'ocean': ocean,
    'sunset': sunset,
    'mono': mono,
  };

  /// The colours flowing along the front and round the edges, in order; the
  /// flow wraps from the last back to the first.
  final List<Color> colors;

  /// The fringe riding just ahead of the front.
  final Color ahead;

  /// The fringe trailing behind the front.
  final Color behind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WavePalette &&
          listEquals(other.colors, colors) &&
          other.ahead == ahead &&
          other.behind == behind;

  @override
  int get hashCode => Object.hash(Object.hashAll(colors), ahead, behind);

  @override
  String toString() {
    for (final MapEntry(:key, :value) in presets.entries) {
      if (identical(value, this) || value == this) return 'WavePalette.$key';
    }
    return 'WavePalette(${colors.length} colours)';
  }

  static Color _mix(Color a, Color b, double t) => Color.from(
    alpha: 1,
    red: a.r + (b.r - a.r) * t,
    green: a.g + (b.g - a.g) * t,
    blue: a.b + (b.b - a.b) * t,
  );
}
