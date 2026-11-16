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
/// * **Travelling** — [rotate], [line]. A position runs along the border
///   once per cycle; these respond to `BeamTiming.direction`,
///   `BeamTiming.cycleGap`, `BorderBeam.progress`, and `BorderBeam.follow`.
/// * **Ambient** — [pulse], [halo]. Light breathes around the whole border;
///   the travel inputs are ignored.
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

  /// Every effect with its default parameters, in gallery order.
  static const List<BeamEffect> values = [
    BeamEffect.rotate(),
    BeamEffect.line(),
    BeamEffect.pulse(),
    BeamEffect.halo(),
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
