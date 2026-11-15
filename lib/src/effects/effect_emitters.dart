import 'dart:math' as math;
import 'dart:ui';

import '../animation/beam_phases.dart';
import '../models/beam_config.dart';
import '../models/beam_options.dart';
import '../models/beam_segment.dart';
import '../render/beam_emission.dart';
import '../render/beam_outline.dart';
import '../render/color_math.dart';
import 'beam_effect.dart';

/// Everything an effect reads to emit one frame.
final class BeamFrame {
  /// Creates a frame context.
  BeamFrame({
    required this.config,
    required this.phases,
    required this.outline,
    required this.colors,
    required this.stops,
  });

  /// The resolved config.
  final BeamConfig config;

  /// This frame's phases.
  final BeamFramePhases phases;

  /// The outline being lit.
  final BeamOutline outline;

  /// The palette colours with this frame's hue rotation applied.
  final List<Color> colors;

  /// The palette stops.
  final List<double> stops;

  /// Whether the beam is styled for a dark surface.
  bool get dark => config.isDark;

  /// The shorter side of the outline box.
  double get minExtent => outline.rect.shortestSide;

  /// Perimeter length.
  double get length => outline.length;

  /// Glow multiplier.
  double get glow => config.glow;
}

/// Writes [frame]'s light into [out]. [out] must be [BeamEmission.reset]
/// first; the caller has already set the user segment on it.
void emitEffect(BeamEmission out, BeamFrame frame) {
  final effect = frame.config.effect;
  switch (effect) {
    case RotateEffect():
      _rotate(out, frame, effect);
    case LineEffect():
      _line(out, frame, effect);
    case PulseEffect():
      _pulse(out, frame);
    case HaloEffect():
      _halo(out, frame);
    case FlowEffect():
      _flow(out, frame);
    case SpinEffect():
      _spin(out, frame);
    case ShimmerEffect():
      _shimmer(out, frame, effect);
    case ChargeEffect():
      _charge(out, frame);
  }
}

/// The visible track as `(start, span)`; the whole border when no segment is
/// set.
({double start, double span}) segmentTrack(BeamEmission out) =>
    out.segmentSpan <= 0
    ? (start: 0.0, span: 1.0)
    : (start: out.segmentStart, span: out.segmentSpan);

/// Applies [segment] (if any) to [out]'s visible track.
void applySegment(BeamEmission out, BeamSegment? segment, BeamOutline outline) {
  if (segment == null || outline.length <= 0) return;
  final range = segment.resolve(outline);
  var span = BeamOutline.wrapFraction(range.to - range.from);
  if (span <= 0) span = 1;
  out
    ..segmentStart = range.from
    ..segmentSpan = span
    ..segmentFeather = math.min(segment.feather / outline.length, span / 2);
}

/// The shader's `segmentMask`, on the CPU: how visible perimeter [u] is.
double segmentWeight(BeamEmission out, double u) {
  if (out.segmentSpan <= 0) return 1;
  final x = BeamOutline.wrapFraction(u - out.segmentStart);
  if (x > out.segmentSpan) return 0;
  final fe = math.max(out.segmentFeather, 1e-5);
  return _smoothstep(0, fe, x) * _smoothstep(0, fe, out.segmentSpan - x);
}

Color _colorAt(BeamEmission out, BeamFrame f, double u) {
  var cu = (u - out.colorOrigin) * out.colorScale;
  cu = out.colorWrap ? BeamOutline.wrapFraction(cu) : cu.clamp(0.0, 1.0);
  return samplePalette(f.colors, f.stops, cu, wrap: out.colorWrap);
}

void _lightAt(
  BeamEmission out,
  BeamFrame f,
  double u, {
  required double along,
  required double inward,
  required double amplitude,
  double outwardShift = 0,
  BeamSide side = BeamSide.inside,
}) {
  final weight = segmentWeight(out, u);
  if (weight <= 0 || amplitude <= 0) return;
  final normal = f.outline.normalAt(u);
  out.addLight(
    at: f.outline.pointAt(u) + normal * outwardShift,
    inward: -normal,
    alongSigma: along,
    inwardSigma: inward,
    amplitude: amplitude * weight,
    color: _colorAt(out, f, u),
    side: side,
    anchorOutside: math.max(outwardShift, 0),
  );
}

double _wave(double x) => 0.5 + 0.5 * math.sin(2 * math.pi * x);

double _smoothstep(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _easeInOut(double x) {
  final t = x.clamp(0.0, 1.0);
  return t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
}

// The corner midpoints and the top/bottom centres: where the ambient effects
// gather their light, clockwise from the top-left corner.
List<double> _anchors(BeamOutline o) => [
  o.fractionOfCorner(BeamCorner.topLeft, 0.5),
  o.fractionOfEdge(BeamEdge.top, 0.5),
  o.fractionOfCorner(BeamCorner.topRight, 0.5),
  o.fractionOfCorner(BeamCorner.bottomRight, 0.5),
  o.fractionOfEdge(BeamEdge.bottom, 0.5),
  o.fractionOfCorner(BeamCorner.bottomLeft, 0.5),
];

void _rotate(BeamEmission o, BeamFrame f, RotateEffect e) {
  final dark = f.dark;
  final track = segmentTrack(o);
  final n = f.config.beamCount;
  final tail = math.min(0.2 * e.length.clamp(0.25, 2.0), 0.8 / n) * track.span;
  final lead = 0.018 * track.span;
  final reversed = f.phases.reversedNow;
  final dir = reversed ? -1.0 : 1.0;
  o
    ..stroke = dark ? 1.0 : 0.95
    ..bloom = dark ? 0.5 : 0.3
    ..bloomSigma = 3 + 1.5 * f.glow
    ..highlight = dark ? 0.75 : 0.25
    ..additive = dark ? 0.35 : 0
    ..lights = dark ? 0.5 : 0.32;
  if (e.comet) {
    o
      ..outer = dark ? 0.45 : 0.3
      ..outerReach = (8 + 0.1 * f.minExtent) * f.glow
      ..outerWiden = 2;
  }
  final beads = math.max(1, math.min(4, 8 ~/ n));
  final along = math.max(tail * f.length / beads * 0.75, 10.0);
  final inward = math.min(
    (0.13 * f.minExtent + 5) * f.glow,
    0.42 * f.minExtent,
  );
  for (final p in f.phases.travellers) {
    final head = track.start + track.span * p;
    o.addBump(head, reversed ? tail : lead, reversed ? lead : tail, 1);
    for (var j = 0; j < beads; j++) {
      final frac = (j + 0.35) / beads;
      _lightAt(
        o,
        f,
        head - dir * tail * frac * 0.9,
        along: along,
        inward: inward,
        amplitude: 0.95 * math.pow(1 - frac, 1.4).toDouble(),
      );
    }
  }
}

void _line(BeamEmission o, BeamFrame f, LineEffect e) {
  final dark = f.dark;
  final userTrack = o.segmentSpan > 0;
  final double from;
  final double span;
  if (userTrack) {
    from = o.segmentStart;
    span = o.segmentSpan;
  } else {
    final range = f.outline.edgeRange(e.edge);
    from = range.from;
    span = BeamOutline.wrapFraction(range.to - range.from);
    o
      ..segmentStart = from - 0.01
      ..segmentSpan = span + 0.02
      ..segmentFeather = 0.04 * span;
  }
  // A timed streak eases across the edge and fades at both ends; a driven one
  // is a readout, so it maps linearly and stays lit.
  final p = f.phases.travelProgress.clamp(0.0, 1.0);
  final timed = !f.phases.driven;
  var x = timed ? 0.06 + 0.88 * _easeInOut(p) : p;
  final envelope = timed
      ? math.pow(math.sin(math.pi * p), 0.5).toDouble()
      : 1.0;
  // Streaks run in reading order — left to right, top to bottom — whichever
  // way the perimeter coordinate runs along the edge.
  if (!userTrack && (e.edge == BeamEdge.bottom || e.edge == BeamEdge.left)) {
    x = 1 - x;
  }
  final centre = from + span * x;
  final half = span * 0.2;
  o
    ..addBump(centre, half, half, 1.15 * envelope)
    ..colorOrigin = centre - half
    ..colorScale = 1 / math.max(2 * half, 1e-4)
    ..colorWrap = false
    ..stroke = 1
    ..bloom = dark ? 0.6 : 0.35
    ..bloomSigma = 2.5 + f.glow
    ..highlight = dark ? 0.55 : 0.2
    ..additive = dark ? 0.45 : 0
    ..lights = dark ? 0.55 : 0.35;
  final depth = e.edge == BeamEdge.top || e.edge == BeamEdge.bottom
      ? f.outline.rect.height
      : f.outline.rect.width;
  final along = math.max(half * f.length * 0.09, 5.0);
  const spikes = 7;
  for (var i = 0; i < spikes; i++) {
    final offset = -0.9 + 1.8 * i / (spikes - 1);
    final breathe = _wave(f.phases.cycles * (1 + 0.23 * i) + 0.53 * i);
    _lightAt(
      o,
      f,
      centre + half * offset * 0.95,
      along: along,
      inward: math.min(depth * (0.12 + 0.3 * breathe) * f.glow, 0.7 * depth),
      amplitude:
          envelope * (0.35 + 0.65 * breathe) * (1 - 0.55 * offset * offset),
    );
  }
}

void _pulse(BeamEmission o, BeamFrame f) {
  final dark = f.dark;
  final m = f.minExtent;
  o
    ..base = 0.2
    ..stroke = 0.9
    ..bloom = dark ? 0.45 : 0.3
    ..bloomSigma = 3 + f.glow
    ..highlight = dark ? 0.3 : 0.1
    ..additive = dark ? 0.35 : 0
    ..lights = dark ? 0.5 : 0.32;
  final anchors = _anchors(f.outline);
  final along = (0.22 * m + 8) * f.glow;
  final inward = math.min((0.16 * m + 6) * f.glow, 0.45 * m);
  for (var i = 0; i < anchors.length; i++) {
    final b = _wave(f.phases.cycles * (0.85 + 0.11 * i) + 0.29 * i);
    o.addBump(anchors[i], 0.1, 0.1, 0.25 + 0.75 * b);
    _lightAt(
      o,
      f,
      anchors[i],
      along: along,
      inward: inward,
      amplitude: 0.3 + 0.7 * b,
    );
  }
}

void _halo(BeamEmission o, BeamFrame f) {
  final dark = f.dark;
  final m = f.minExtent;
  o
    ..base = 0.3
    ..stroke = 0.9
    ..bloom = dark ? 0.5 : 0.3
    ..bloomSigma = 3 + f.glow
    ..bloomSide = BeamSide.outside
    ..outer = dark ? 0.5 : 0.35
    ..outerReach = (0.32 * m + 18) * f.glow
    ..outerPlateau = 1
    ..outerWiden = 2.5
    ..highlight = dark ? 0.25 : 0.05
    ..additive = dark ? 0.55 : 0
    ..lights = dark ? 0.55 : 0.35;
  final anchors = _anchors(f.outline);
  for (var i = 0; i < anchors.length; i++) {
    final b = _wave(f.phases.cycles * (0.8 + 0.13 * i) + 0.31 * i);
    o.addBump(anchors[i], 0.12, 0.12, 0.3 + 0.7 * b);
    _lightAt(
      o,
      f,
      anchors[i],
      along: (0.3 * m + 14) * f.glow,
      inward: (0.22 * m + 10) * f.glow,
      amplitude: 0.8 * (0.25 + 0.75 * b),
      outwardShift: 0.1 * m * f.glow,
      side: BeamSide.outside,
    );
  }
}

void _flow(BeamEmission o, BeamFrame f) {
  final dark = f.dark;
  final m = f.minExtent;
  final dir = f.phases.reversedNow ? -1.0 : 1.0;
  final origin = dir * f.phases.cycles * 0.5;
  o
    ..base = 0.8
    ..colorOrigin = origin
    ..noiseAmplitude = 0.3
    ..noiseFrequency = 2
    ..noisePhase = f.phases.cycles * 0.6
    ..stroke = 1
    ..bloom = dark ? 0.55 : 0.35
    ..bloomSigma = 3.5 + f.glow
    ..highlight = dark ? 0.2 : 0.05
    ..additive = dark ? 0.45 : 0
    ..lights = dark ? 0.5 : 0.32;
  const count = 8;
  final along = f.length / count * 0.6;
  for (var i = 0; i < count; i++) {
    final swell = _wave(f.phases.cycles * 0.7 + i * 0.37);
    _lightAt(
      o,
      f,
      i / count + origin * 0.6,
      along: along,
      inward: math.min((0.1 * m + 5) * (0.7 + 0.6 * swell) * f.glow, 0.4 * m),
      amplitude: 0.45 + 0.55 * swell,
    );
  }
}

void _spin(BeamEmission o, BeamFrame f) {
  final dark = f.dark;
  final dir = f.phases.reversedNow ? -1.0 : 1.0;
  o
    ..base = 1
    ..colorOrigin = dir * f.phases.cycles
    ..stroke = 1
    ..bloom = dark ? 0.45 : 0.3
    ..bloomSigma = 3 + f.glow
    ..bloomSide = BeamSide.both
    ..outer = dark ? 0.22 : 0.15
    ..outerReach = (6 + 0.05 * f.minExtent) * f.glow
    ..highlight = dark ? 0.1 : 0
    ..additive = dark ? 0.35 : 0;
}

void _shimmer(BeamEmission o, BeamFrame f, ShimmerEffect e) {
  final dark = f.dark;
  final a = e.angle * math.pi / 180;
  final dx = math.cos(a);
  final dy = math.sin(a);
  const half = 0.16;
  final extent = (dx.abs() + dy.abs()) / 2 + half;
  o
    ..sweepAmplitude = 1
    ..sweepDirection = Offset(dx, dy)
    ..sweepHalfWidth = half
    ..sweepPosition = 0.5 - extent + 2 * extent * f.phases.travelProgress
    ..stroke = 1
    ..bloom = dark ? 0.6 : 0.35
    ..bloomSigma = 3 + f.glow
    ..highlight = dark ? 0.85 : 0.3
    ..additive = dark ? 0.5 : 0;
}

void _charge(BeamEmission o, BeamFrame f) {
  final dark = f.dark;
  final track = segmentTrack(o);
  final reversed = f.phases.reversedNow;
  final head = f.phases.travelProgress;
  final fill = reversed ? 1 - head : head;
  if (fill <= 0.001) {
    o.stroke = 0;
    return;
  }
  final span = track.span * fill;
  final start = reversed ? track.start + track.span - span : track.start;
  final tip = reversed ? start : start + span;
  // The tip light is placed against the user's track, before the fill
  // narrows it: the fill's own feather would otherwise fade the light out
  // exactly where it sits.
  o.lights = dark ? 0.5 : 0.3;
  _lightAt(
    o,
    f,
    tip,
    along: 0.08 * f.length,
    inward: math.min((0.13 * f.minExtent + 5) * f.glow, 0.42 * f.minExtent),
    amplitude: 0.8,
  );
  final userFeather = o.segmentSpan > 0 ? o.segmentFeather : 0.0;
  o
    ..segmentStart = start
    ..segmentSpan = span
    ..segmentFeather = math.max(math.min(0.006, span / 2), userFeather)
    ..base = 0.85
    ..stroke = 1
    ..bloom = dark ? 0.5 : 0.3
    ..bloomSigma = 3 + f.glow
    ..highlight = dark ? 0.6 : 0.2
    ..additive = dark ? 0.4 : 0;
  o.addBump(tip, reversed ? 0.07 : 0.012, reversed ? 0.012 : 0.07, 0.6);
}
