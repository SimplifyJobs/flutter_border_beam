import 'dart:ui';

import '../constants/pulse_params.dart';

/// The five beam effect variants, matching the React library's `size` prop.
///
/// Rotate family (a traveling beam sweeps around the border):
/// - [rotate] — full border glow for cards and large surfaces (React `md`).
/// - [small] — compact glow tuned for buttons and icons (React `sm`).
/// - [line] — a beam that travels along the bottom edge (React `line`).
///
/// Pulse family (a breathing glow, no rotation):
/// - [pulseInside] — contained breathing border glow (React `pulse-inner`).
/// - [pulseOutside] — outward-blooming halo behind the child
///   (React `pulse-outside`).
enum BeamVariant {
  /// Full border traveling beam (React `md`). The default look.
  rotate,

  /// Compact traveling beam for small elements (React `sm`).
  small,

  /// Bottom-edge traveling beam (React `line`).
  line,

  /// Contained breathing glow (React `pulse-inner`).
  pulseInside,

  /// Outward-blooming breathing halo (React `pulse-outside`).
  pulseOutside;

  /// Whether this variant uses the breathing (oscillator-driven) engine
  /// instead of the traveling-beam engine.
  bool get isPulse => this == pulseInside || this == pulseOutside;

  /// Default duration of one animation cycle, matching the React defaults
  /// (1.96s for rotate/small, 3.1s for line, 2.3s for pulse).
  Duration get defaultCycleDuration => switch (this) {
    rotate || small => const Duration(milliseconds: 1960),
    line => const Duration(milliseconds: 3100),
    pulseInside || pulseOutside => const Duration(milliseconds: 2300),
  };

  /// Default border radius preset (React `sizePresets`).
  double get defaultBorderRadius => this == small ? 32 : 16;

  /// Default border (stroke ring) width preset. All variants use 1px.
  double get defaultBorderWidth => 1;

  /// Default period of one full hue track pass: 12s for the traveling
  /// variants, 16s for [pulseInside], 14s for [pulseOutside].
  ///
  /// The pulse periods come from [PulseParams], which tunes them by neither
  /// brightness nor cycle length — the arguments below only satisfy that
  /// signature.
  Duration get defaultHuePeriod => isPulse
      ? _seconds(PulseParams.resolve(this, Brightness.dark, 2.3).huePeriod)
      : const Duration(seconds: 12);

  /// Default period of the [line] variant's separate bloom hue track: 8s.
  /// No other variant paints a bloom hue track of its own.
  Duration get defaultBloomHuePeriod => const Duration(seconds: 8);
}

Duration _seconds(double value) =>
    Duration(microseconds: (value * Duration.microsecondsPerSecond).round());
