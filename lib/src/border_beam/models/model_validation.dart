import 'dart:ui';

import 'beam_options.dart';
import 'beam_palette.dart';
import 'beam_timing.dart';

/// Runtime counterpart to [BeamTiming]'s constructor assertions.
///
/// Assertions disappear in release builds, so resolution invokes this before
/// values reach animation arithmetic or scheduling code.
void validateBeamTiming(BeamTiming timing) {
  void require(bool condition, String name, Object? value, String constraint) {
    if (!condition) throw ArgumentError.value(value, name, constraint);
  }

  require(
    timing.cycle == null || timing.cycle! > Duration.zero,
    'cycle',
    timing.cycle,
    'must be positive',
  );
  require(
    timing.cycleGap == null || timing.cycleGap! >= Duration.zero,
    'cycleGap',
    timing.cycleGap,
    'must be non-negative',
  );
  require(
    timing.speed == null || (timing.speed!.isFinite && timing.speed! > 0),
    'speed',
    timing.speed,
    'must be finite and positive',
  );
  require(
    timing.phaseOffset == null ||
        (timing.phaseOffset!.isFinite &&
            timing.phaseOffset! >= 0 &&
            timing.phaseOffset! <= 1),
    'phaseOffset',
    timing.phaseOffset,
    'must be finite and between 0 and 1',
  );
  require(
    timing.huePeriod == null || timing.huePeriod! > Duration.zero,
    'huePeriod',
    timing.huePeriod,
    'must be positive',
  );
}

/// Returns [speed] when it is finite and positive, and throws otherwise,
/// including in release builds. [name] labels the argument in the error.
///
/// A playback rate multiplies the timeline every frame, so a NaN, an
/// infinity, or a non-positive rate would poison every phase it feeds.
double validateSpeed(double speed, String name) {
  if (!speed.isFinite || speed <= 0) {
    throw ArgumentError.value(speed, name, 'must be finite and positive');
  }
  return speed;
}

/// Returns a valid repeat budget, including in release builds.
int? validateRepeat(BeamRepeat? repeat) {
  final cycles = repeat?.cycles;
  if (cycles != null && cycles < 1) {
    throw ArgumentError.value(
      cycles,
      'repeat',
      'must contain at least 1 cycle',
    );
  }
  return cycles;
}

/// Rejects a malformed palette, including in release builds.
///
/// `BeamColors` is a const hierarchy, so its constructors cannot assert on a
/// list's length; resolution checks it instead. A palette needs 1 to
/// [maxPaletteStops] colors and one stop per color, each finite, in
/// `[0, 1)`, and ascending (equal neighbours make a hard edge).
void validatePalette(List<Color> colors, List<double> stops, String name) {
  if (colors.isEmpty || colors.length > maxPaletteStops) {
    throw ArgumentError.value(
      colors.length,
      '$name colors',
      'must contain 1 to $maxPaletteStops entries',
    );
  }
  if (stops.length != colors.length) {
    throw ArgumentError.value(
      stops.length,
      '$name stops',
      'must contain one stop per color (${colors.length})',
    );
  }
  for (var i = 0; i < stops.length; i++) {
    final s = stops[i];
    if (!s.isFinite || s < 0 || s >= 1) {
      throw ArgumentError.value(s, '$name stops[$i]', 'must be in [0, 1)');
    }
    if (i > 0 && s < stops[i - 1]) {
      throw ArgumentError.value(s, '$name stops[$i]', 'must not descend');
    }
  }
}
