import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../effects/beam_effect.dart';
import 'beam_options.dart';
import 'beam_palette.dart';
import 'beam_segment.dart';
import 'beam_shape.dart';
import 'beam_style.dart';
import 'beam_timing.dart';

/// Default corner radius when neither the widget nor a theme sets one.
const double defaultBeamRadius = 16;

/// Everything a beam needs to paint, with every inherited value settled.
///
/// Built by [BeamConfig.resolve] from the merged value objects. Value-equal,
/// so the painter repaints only when something that changes pixels changed.
/// Playback rate (`BeamTiming.speed`) is applied to the clock and is
/// deliberately not part of the config: a rate change never re-resolves it.
@immutable
class BeamConfig {
  /// Creates a resolved config. Prefer [BeamConfig.resolve].
  const BeamConfig({
    required this.effect,
    required this.palette,
    required this.brightness,
    required this.strength,
    required this.glow,
    required this.hueMode,
    required this.hueShift,
    required this.hueBase,
    required this.borderRadius,
    required this.superellipse,
    required this.borderWidth,
    required this.ringOffset,
    required this.segment,
    required this.dashes,
    required this.cycleSeconds,
    required this.gapSeconds,
    required this.direction,
    required this.phaseOffset,
    required this.huePeriodSeconds,
  });

  /// Resolves the value objects (already merged theme-under-widget) for
  /// [effect]. [palette] and [brightness] are settled by the caller, which
  /// owns the ambient theme; [textDirection] resolves `shape.radius`.
  factory BeamConfig.resolve({
    required BeamEffect effect,
    required BeamPalette palette,
    required Brightness brightness,
    BeamStyle style = const BeamStyle(),
    BeamShape shape = const BeamShape(),
    BeamTiming timing = const BeamTiming(),
    TextDirection textDirection = TextDirection.ltr,
  }) {
    double seconds(Duration? d, Duration fallback) =>
        (d ?? fallback).inMicroseconds / Duration.microsecondsPerSecond;
    final cycle = math.max(seconds(timing.cycle, effect.defaultCycle), 0.05);
    final hueMode = palette.fixedHue
        ? BeamHueMode.none
        : (style.hueMode ?? effect.defaultHueMode);
    return BeamConfig(
      effect: effect,
      palette: palette,
      brightness: brightness,
      strength: (style.strength ?? 1).clamp(0.0, 1.0),
      glow: math.max(style.glow ?? 1, 0),
      hueMode: hueMode,
      hueShift: style.hueShift ?? 30,
      hueBase: style.hueBase ?? 0,
      borderRadius:
          shape.radius?.resolve(textDirection) ??
          const BorderRadius.all(Radius.circular(defaultBeamRadius)),
      superellipse: shape.superellipse ?? false,
      borderWidth: math.max(shape.borderWidth ?? 1, 0),
      ringOffset: shape.ringOffset ?? 0,
      segment: shape.segment,
      dashes: math.max(shape.dashes ?? 0, 0),
      cycleSeconds: cycle,
      gapSeconds: math.max(seconds(timing.cycleGap, effect.defaultCycleGap), 0),
      direction: timing.direction ?? BeamDirection.forward,
      phaseOffset: timing.phaseOffset ?? 0,
      huePeriodSeconds: math.max(
        seconds(timing.huePeriod, effect.defaultHuePeriod),
        0.1,
      ),
    );
  }

  /// What the beam does.
  final BeamEffect effect;

  /// Resolved colour stops.
  final BeamPalette palette;

  /// Whether the beam is styled for a dark or a light surface.
  final Brightness brightness;

  /// Overall opacity, 0–1.
  final double strength;

  /// Glow size and intensity multiplier.
  final double glow;

  /// How the palette's hue drifts over time.
  final BeamHueMode hueMode;

  /// ± degrees of the ping-pong hue drift.
  final double hueShift;

  /// Static hue rotation in degrees.
  final double hueBase;

  /// Corner radii, resolved for the ambient text direction.
  final BorderRadius borderRadius;

  /// Whether corners are superellipse curves.
  final bool superellipse;

  /// Stroke width in logical px.
  final double borderWidth;

  /// How far the outline sits outside (positive) or inside the child.
  final double ringOffset;

  /// The visible part of the border, or null for all of it.
  final BeamSegment? segment;

  /// Number of dashes (below 2: a solid border).
  final int dashes;

  /// One cycle, in seconds.
  final double cycleSeconds;

  /// Rest between sweeps of a travelling effect, in seconds.
  final double gapSeconds;

  /// Travel direction.
  final BeamDirection direction;

  /// Phase offset as a fraction of a cycle.
  final double phaseOffset;

  /// Hue drift period, in seconds.
  final double huePeriodSeconds;

  /// Whether this is a dark-surface beam.
  bool get isDark => brightness == Brightness.dark;

  /// How many beams travel the border at once.
  int get beamCount => switch (effect) {
    RotateEffect(:final count) => count.clamp(1, 4),
    _ => 1,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamConfig &&
          other.effect == effect &&
          other.palette == palette &&
          other.brightness == brightness &&
          other.strength == strength &&
          other.glow == glow &&
          other.hueMode == hueMode &&
          other.hueShift == hueShift &&
          other.hueBase == hueBase &&
          other.borderRadius == borderRadius &&
          other.superellipse == superellipse &&
          other.borderWidth == borderWidth &&
          other.ringOffset == ringOffset &&
          other.segment == segment &&
          other.dashes == dashes &&
          other.cycleSeconds == cycleSeconds &&
          other.gapSeconds == gapSeconds &&
          other.direction == direction &&
          other.phaseOffset == phaseOffset &&
          other.huePeriodSeconds == huePeriodSeconds;

  @override
  int get hashCode => Object.hash(
    effect,
    palette,
    brightness,
    strength,
    glow,
    hueMode,
    hueShift,
    hueBase,
    borderRadius,
    superellipse,
    borderWidth,
    ringOffset,
    segment,
    dashes,
    cycleSeconds,
    gapSeconds,
    direction,
    phaseOffset,
    huePeriodSeconds,
  );

  @override
  String toString() =>
      'BeamConfig($effect, $brightness, radius: $borderRadius, '
      'cycle: ${cycleSeconds}s)';
}
