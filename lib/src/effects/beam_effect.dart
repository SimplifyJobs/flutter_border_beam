import 'package:flutter/foundation.dart';

import '../models/beam_options.dart';

/// What a beam does: how its light is placed along the border and how it
/// moves.
///
/// Every effect is rendered by the same single-pass shader, so they all cost
/// the same order of GPU time — pick for the look, not for performance.
///
/// Effects fall into two families:
///
/// * **Travelling** — [rotate], [line], [shimmer], [charge]. A position runs
///   along the border once per cycle; these respond to
///   `BeamTiming.direction`, `BeamTiming.cycleGap`, `BorderBeam.progress`,
///   and `BorderBeam.follow`.
/// * **Ambient** — [pulse], [halo], [flow], [spin]. Light breathes or
///   streams around the whole border; the travel inputs are ignored.
@immutable
sealed class BeamEffect {
  const BeamEffect._();

  /// A beam of light that travels around the whole border, trailing a soft
  /// tail and lighting the inside edge as it passes. Cards, panels, surfaces.
  ///
  /// [length] scales the tail (0.25–2, default 1), [count] puts several beams
  /// on the border at once, evenly spaced (1–4), and [comet] adds an outer
  /// glow that trails the head outside the border.
  const factory BeamEffect.rotate({double length, int count, bool comet}) =
      RotateEffect;

  /// A streak that rides one edge, its colours spread across it, with light
  /// spiking up from the edge. Inputs, search bars, composers.
  const factory BeamEffect.line({BeamEdge edge}) = LineEffect;

  /// Colour breathing inward from the whole border, strongest at the
  /// corners. A contained "thinking" state.
  const factory BeamEffect.pulse() = PulseEffect;

  /// A halo breathing outward around the widget. Leave room around it — the
  /// light is painted outside the widget's bounds.
  const factory BeamEffect.halo() = HaloEffect;

  /// Colours streaming continuously around the whole border, with an inner
  /// glow that swells and ebbs — an assistant-is-listening look.
  const factory BeamEffect.flow() = FlowEffect;

  /// A full gradient ring that spins around the border. The classic animated
  /// gradient border, for buttons and badges.
  const factory BeamEffect.spin() = SpinEffect;

  /// A glint that sweeps across the border at [angle] degrees from vertical,
  /// then rests for `BeamTiming.cycleGap`. Calls to action, new items.
  const factory BeamEffect.shimmer({double angle}) = ShimmerEffect;

  /// The border fills clockwise from the top with a hot leading edge.
  /// Drive it with `BorderBeam.progress` for determinate progress; without
  /// one it fills once per cycle.
  const factory BeamEffect.charge() = ChargeEffect;

  /// Every effect with its default parameters, in gallery order.
  static const List<BeamEffect> values = [
    BeamEffect.rotate(),
    BeamEffect.line(),
    BeamEffect.pulse(),
    BeamEffect.halo(),
    BeamEffect.flow(),
    BeamEffect.spin(),
    BeamEffect.shimmer(),
    BeamEffect.charge(),
  ];

  /// A short identifier, e.g. `rotate`.
  String get name;

  /// Whether this is a travelling effect (see the class docs).
  bool get travels;

  /// The cycle used when `BeamTiming.cycle` is not set.
  Duration get defaultCycle;

  /// The hue drift used when `BeamStyle.hueMode` is not set.
  BeamHueMode get defaultHueMode => BeamHueMode.pingPong;

  /// The hue drift period used when `BeamTiming.huePeriod` is not set.
  Duration get defaultHuePeriod => const Duration(seconds: 12);

  /// The rest between sweeps used when `BeamTiming.cycleGap` is not set.
  Duration get defaultCycleGap => Duration.zero;

  @override
  String toString() => 'BeamEffect.$name()';
}

/// See [BeamEffect.rotate].
final class RotateEffect extends BeamEffect {
  /// Creates a rotating beam.
  const RotateEffect({this.length = 1, this.count = 1, this.comet = false})
    : assert(length > 0, 'length must be positive'),
      assert(count >= 1 && count <= 4, 'count must be 1–4'),
      super._();

  /// Tail length multiplier (clamped to 0.25–2).
  final double length;

  /// How many beams travel the border at once, evenly spaced.
  final int count;

  /// Whether a glow trails the head outside the border.
  final bool comet;

  @override
  String get name => 'rotate';

  @override
  bool get travels => true;

  @override
  Duration get defaultCycle => const Duration(milliseconds: 2400);

  @override
  bool operator ==(Object other) =>
      other is RotateEffect &&
      other.length == length &&
      other.count == count &&
      other.comet == comet;

  @override
  int get hashCode => Object.hash(RotateEffect, length, count, comet);

  @override
  String toString() =>
      'BeamEffect.rotate(length: $length, count: $count, comet: $comet)';
}

/// See [BeamEffect.line].
final class LineEffect extends BeamEffect {
  /// Creates a line beam on [edge].
  const LineEffect({this.edge = BeamEdge.bottom}) : super._();

  /// The edge the streak rides.
  final BeamEdge edge;

  @override
  String get name => 'line';

  @override
  bool get travels => true;

  @override
  Duration get defaultCycle => const Duration(milliseconds: 3100);

  @override
  Duration get defaultHuePeriod => const Duration(seconds: 8);

  @override
  bool operator ==(Object other) => other is LineEffect && other.edge == edge;

  @override
  int get hashCode => Object.hash(LineEffect, edge);

  @override
  String toString() => 'BeamEffect.line(edge: ${edge.name})';
}

/// See [BeamEffect.pulse].
final class PulseEffect extends BeamEffect {
  /// Creates a pulse.
  const PulseEffect() : super._();

  @override
  String get name => 'pulse';

  @override
  bool get travels => false;

  @override
  Duration get defaultCycle => const Duration(milliseconds: 2300);

  @override
  BeamHueMode get defaultHueMode => BeamHueMode.continuous;

  @override
  Duration get defaultHuePeriod => const Duration(seconds: 16);

  @override
  bool operator ==(Object other) => other is PulseEffect;

  @override
  int get hashCode => (PulseEffect).hashCode;
}

/// See [BeamEffect.halo].
final class HaloEffect extends BeamEffect {
  /// Creates a halo.
  const HaloEffect() : super._();

  @override
  String get name => 'halo';

  @override
  bool get travels => false;

  @override
  Duration get defaultCycle => const Duration(milliseconds: 2300);

  @override
  BeamHueMode get defaultHueMode => BeamHueMode.continuous;

  @override
  Duration get defaultHuePeriod => const Duration(seconds: 14);

  @override
  bool operator ==(Object other) => other is HaloEffect;

  @override
  int get hashCode => (HaloEffect).hashCode;
}

/// See [BeamEffect.flow].
final class FlowEffect extends BeamEffect {
  /// Creates a flow.
  const FlowEffect() : super._();

  @override
  String get name => 'flow';

  @override
  bool get travels => false;

  @override
  Duration get defaultCycle => const Duration(seconds: 6);

  @override
  BeamHueMode get defaultHueMode => BeamHueMode.none;

  @override
  bool operator ==(Object other) => other is FlowEffect;

  @override
  int get hashCode => (FlowEffect).hashCode;
}

/// See [BeamEffect.spin].
final class SpinEffect extends BeamEffect {
  /// Creates a spinning gradient ring.
  const SpinEffect() : super._();

  @override
  String get name => 'spin';

  @override
  bool get travels => false;

  @override
  Duration get defaultCycle => const Duration(seconds: 3);

  @override
  BeamHueMode get defaultHueMode => BeamHueMode.none;

  @override
  bool operator ==(Object other) => other is SpinEffect;

  @override
  int get hashCode => (SpinEffect).hashCode;
}

/// See [BeamEffect.shimmer].
final class ShimmerEffect extends BeamEffect {
  /// Creates a shimmer sweeping at [angle] degrees from vertical.
  const ShimmerEffect({this.angle = 20}) : super._();

  /// The sweep's tilt, in degrees from vertical (0 sweeps left to right).
  final double angle;

  @override
  String get name => 'shimmer';

  @override
  bool get travels => true;

  @override
  Duration get defaultCycle => const Duration(milliseconds: 1400);

  @override
  Duration get defaultCycleGap => const Duration(milliseconds: 1600);

  @override
  BeamHueMode get defaultHueMode => BeamHueMode.none;

  @override
  bool operator ==(Object other) =>
      other is ShimmerEffect && other.angle == angle;

  @override
  int get hashCode => Object.hash(ShimmerEffect, angle);

  @override
  String toString() => 'BeamEffect.shimmer(angle: $angle)';
}

/// See [BeamEffect.charge].
final class ChargeEffect extends BeamEffect {
  /// Creates a charge.
  const ChargeEffect() : super._();

  @override
  String get name => 'charge';

  @override
  bool get travels => true;

  @override
  Duration get defaultCycle => const Duration(milliseconds: 2600);

  @override
  Duration get defaultCycleGap => const Duration(milliseconds: 600);

  @override
  BeamHueMode get defaultHueMode => BeamHueMode.none;

  @override
  bool operator ==(Object other) => other is ChargeEffect;

  @override
  int get hashCode => (ChargeEffect).hashCode;
}
