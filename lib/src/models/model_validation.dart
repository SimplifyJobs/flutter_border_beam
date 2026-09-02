import 'beam_options.dart';
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
    timing.beamCount == null || timing.beamCount! >= 1,
    'beamCount',
    timing.beamCount,
    'must be at least 1',
  );
  require(
    timing.huePeriod == null || timing.huePeriod! > Duration.zero,
    'huePeriod',
    timing.huePeriod,
    'must be positive',
  );
  require(
    timing.bloomHuePeriod == null || timing.bloomHuePeriod! > Duration.zero,
    'bloomHuePeriod',
    timing.bloomHuePeriod,
    'must be positive',
  );
  for (final (name, value) in [
    ('breatheFactor', timing.breatheFactor),
    ('spikeFactor', timing.spikeFactor),
    ('spike2Factor', timing.spike2Factor),
  ]) {
    require(
      value == null || (value.isFinite && value > 0),
      name,
      value,
      'must be finite and positive',
    );
  }
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
