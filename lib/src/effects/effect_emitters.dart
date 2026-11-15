import 'dart:math' as math;
import 'dart:typed_data';
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
  final dim = _paletteDim(frame);
  if (dim < 1) {
    out
      ..stroke *= dim
      ..bloom *= dim
      ..outer *= dim
      ..lights *= dim;
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
  final color = _colorAt(out, f, u);
  out.addLight(
    at: f.outline.pointAt(u) + normal * outwardShift,
    inward: -normal,
    alongSigma: along,
    inwardSigma: inward,
    amplitude: amplitude * weight,
    color: f.dark ? color : _lifted(color),
    side: side,
    anchorOutside: math.max(outwardShift, 0),
  );
}

// On a light surface a glow is a tint, and a dark tint reads as a smudge:
// lift the colour toward full value, keeping its hue and saturation.
Color _lifted(Color c) {
  final hi = math.max(c.r, math.max(c.g, c.b));
  if (hi <= 0) return c;
  final k = math.min(1 / hi, 1.4);
  return Color.from(
    alpha: c.a,
    red: math.min(c.r * k, 1),
    green: math.min(c.g * k, 1),
    blue: math.min(c.b * k, 1),
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
// gather their light, clockwise from the top-left corner. Cached per outline
// (the renderer keeps its outline across frames), so a frame allocates
// nothing here.
final Expando<Float64List> _anchorCache = Expando<Float64List>('anchors');

Float64List _anchors(BeamOutline o) =>
    _anchorCache[o] ??= Float64List.fromList([
      o.fractionOfCorner(BeamCorner.topLeft, 0.5),
      o.fractionOfEdge(BeamEdge.top, 0.5),
      o.fractionOfCorner(BeamCorner.topRight, 0.5),
      o.fractionOfCorner(BeamCorner.bottomRight, 0.5),
      o.fractionOfEdge(BeamEdge.bottom, 0.5),
      o.fractionOfCorner(BeamCorner.bottomLeft, 0.5),
    ]);

// How strongly this frame's palette is tinted, 0 (greys) to 1 (saturated).
// White light reads far brighter than coloured light at the same alpha, so
// achromatic palettes are dimmed (the 0.1 renderer halved mono's layers).
double _tint(BeamFrame f) {
  var sum = 0.0;
  for (final c in f.colors) {
    final hi = math.max(c.r, math.max(c.g, c.b));
    final lo = math.min(c.r, math.min(c.g, c.b));
    sum += hi - lo;
  }
  return f.colors.isEmpty ? 1 : (sum / f.colors.length / 0.45).clamp(0.0, 1.0);
}

// The layer multiplier for [f]'s palette: 1 for colour, 0.5 for greys.
double _paletteDim(BeamFrame f) => 0.5 + 0.5 * _tint(f);

void _rotate(BeamEmission o, BeamFrame f, RotateEffect e) {
  final dark = f.dark;
  final track = segmentTrack(o);
  final n = f.config.beamCount;
  final len = e.length.clamp(0.25, 2.0);
  // A long lit window — a soft lead, a plateau, a tail that fades slowly —
  // with a hot core just behind the head that whitens toward its peak.
  final tail = math.min(math.min(0.46 * len, 0.8 / n), 0.48) * track.span;
  final lead = math.min(0.09, 0.2 / n) * track.span;
  final hotTail = math.min(0.18 * len, 0.45 / n) * track.span;
  final hotLead = 0.05 * track.span;
  final reversed = f.phases.reversedNow;
  final dir = reversed ? -1.0 : 1.0;
  o
    ..bumpPlateau = 1.5
    ..stroke = dark ? 0.62 : 0.6
    ..bloom = dark ? 0.32 : 0.22
    ..bloomSigma = 3 + 2.5 * f.glow
    ..highlight = dark ? 0.6 : 0.5
    ..additive = dark ? 0.4 : 0
    ..lights = dark ? 0.3 : 0.26;
  if (e.comet) {
    o
      ..outer = dark ? 0.45 : 0.3
      ..outerReach = (8 + 0.1 * f.minExtent) * f.glow
      ..outerWiden = 2;
  }
  final beads = math.max(1, math.min(4, 8 ~/ n));
  final along = math.max(0.9 * tail * f.length / beads * 0.6, 8.0);
  final inward = math.min((0.07 * f.minExtent + 6) * f.glow, 0.4 * f.minExtent);
  for (final p in f.phases.travellers) {
    final head = track.start + track.span * p;
    o
      ..addBump(head, reversed ? tail : lead, reversed ? lead : tail, 0.5)
      ..addBump(
        head - dir * 0.015 * track.span,
        reversed ? hotTail : hotLead,
        reversed ? hotLead : hotTail,
        0.62,
      );
    for (var j = 0; j < beads; j++) {
      final frac = (j + 0.2) / beads;
      _lightAt(
        o,
        f,
        head - dir * tail * frac * 0.9,
        along: along,
        inward: inward,
        amplitude: 0.9 * math.pow(1 - 0.85 * frac, 1.2).toDouble(),
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
  // A timed streak glides across the edge, widening through the middle of
  // its run and fading in and out near the ends; a driven one is a readout,
  // so it maps linearly and stays lit at full width.
  final p = f.phases.travelProgress.clamp(0.0, 1.0);
  final timed = !f.phases.driven;
  var x = timed ? 0.06 + 0.88 * (0.15 * _easeInOut(p) + 0.85 * p) : p;
  final swell = timed ? math.sin(math.pi * p) : 1.0;
  final envelope = timed
      ? _smoothstep(0.08, 0.3, p) * (1 - _smoothstep(0.7, 0.92, p))
      : 1.0;
  // Streaks run in reading order — left to right, top to bottom — whichever
  // way the perimeter coordinate runs along the edge.
  if (!userTrack && (e.edge == BeamEdge.bottom || e.edge == BeamEdge.left)) {
    x = 1 - x;
  }
  final centre = from + span * x;
  final edgePx = span * f.length;
  // Half the streak, in u: about a quarter of the edge at full swell, held
  // to a sensible pixel range on very short and very long edges.
  final halfPx = (edgePx * (0.15 + 0.17 * swell)).clamp(
    math.min(24.0, 0.45 * edgePx),
    150.0,
  );
  final half = halfPx / f.length;
  o
    ..bumpPlateau = 1.4
    ..addBump(centre, half, half, 0.62 * envelope)
    ..addBump(centre, 0.3 * half, 0.3 * half, 0.5 * envelope)
    ..colorOrigin = centre - half
    ..colorScale = 1 / math.max(2 * half, 1e-4)
    ..colorWrap = false
    ..stroke = dark ? 1.0 : 0.85
    ..bloom = dark ? 0.5 : 0.3
    ..bloomSigma = 2 + 1.5 * f.glow
    ..highlight = 0.45
    ..additive = dark ? 0.45 : 0
    ..lights = dark ? 0.36 : 0.28;
  // How far the spikes may rise: the box behind the edge, but no taller than
  // a card's on a tall surface.
  final depth = math.min(
    e.edge == BeamEdge.top || e.edge == BeamEdge.bottom
        ? f.outline.rect.height
        : f.outline.rect.width,
    160.0,
  );
  // Seven soft spikes rising from the streak, each with its own height and
  // breathing rate, tallest near the middle; the centre one is the hot core.
  final along = (0.09 * halfPx + 3).clamp(3.0, 14.0);
  for (var i = 0; i < _lineSpikes.length; i += 2) {
    final offset = _lineSpikes[i];
    final height = _lineSpikes[i + 1];
    final k = i ~/ 2;
    final breathe = _wave(f.phases.cycles * (0.9 + 0.17 * k) + 0.61 * k);
    final taper = 1 - 0.6 * offset * offset;
    _lightAt(
      o,
      f,
      centre + 0.8 * half * offset,
      along: along * (1 + 0.25 * (k % 3)),
      inward: math.min(
        depth * height * (0.7 + 0.6 * breathe) * f.glow,
        0.4 * depth,
      ),
      amplitude: envelope * taper * (0.45 + 0.4 * breathe),
    );
  }
  // The hot core where the streak meets the edge.
  _lightAt(
    o,
    f,
    centre,
    along: 1.6 * along,
    inward: math.min(0.07 * depth + 3, 0.3 * depth) * f.glow,
    amplitude: 0.7 * envelope,
  );
}

// The line's spikes: position across the streak (-1..1) and height as a
// fraction of the depth behind the edge, in pairs.
const List<double> _lineSpikes = [
  -0.84, 0.07, //
  -0.56, 0.12, //
  -0.28, 0.09, //
  0.0, 0.15, //
  0.28, 0.1, //
  0.56, 0.13, //
  0.84, 0.065, //
];

void _pulse(BeamEmission o, BeamFrame f) {
  final dark = f.dark;
  final m = f.minExtent;
  // A dim ring all the way round, with patches of colour swelling and
  // ebbing at the corners and edge centres, washing a little way inward.
  o
    ..base = 0.28
    ..bumpPlateau = 1.3
    ..stroke = dark ? 0.45 : 0.4
    ..bloom = dark ? 0.3 : 0.2
    ..bloomSigma = 2.5 + 1.5 * f.glow
    ..highlight = dark ? 0.15 : 0.2
    ..additive = dark ? 0.4 : 0
    ..lights = dark ? 0.36 : 0.32;
  final anchors = _anchors(f.outline);
  final along = (0.2 * m + 10) * f.glow;
  final inward = math.min((0.12 * m + 6) * f.glow, 0.38 * m);
  final width = math.min(0.11, 90 / f.length);
  for (var i = 0; i < anchors.length; i++) {
    final b = _wave(f.phases.cycles * (0.85 + 0.11 * i) + 0.29 * i);
    o.addBump(anchors[i], width, width, 0.08 + 0.42 * b * b);
    _lightAt(
      o,
      f,
      anchors[i],
      along: along,
      inward: inward * (0.8 + 0.35 * b),
      amplitude: 0.12 + 0.6 * b * b,
    );
  }
}

// Where the halo's clouds sit: spread evenly round the box rather than at
// the corners, so the glow reads as a ring of soft light. Clockwise from the
// top edge's first third.
final Expando<Float64List> _haloAnchorCache = Expando<Float64List>('halo');

Float64List _haloAnchors(BeamOutline o) =>
    _haloAnchorCache[o] ??= Float64List.fromList([
      o.fractionOfEdge(BeamEdge.top, 0.28),
      o.fractionOfEdge(BeamEdge.top, 0.74),
      o.fractionOfEdge(BeamEdge.right, 0.5),
      o.fractionOfEdge(BeamEdge.bottom, 0.3),
      o.fractionOfEdge(BeamEdge.bottom, 0.76),
      o.fractionOfEdge(BeamEdge.left, 0.5),
    ]);

void _halo(BeamEmission o, BeamFrame f) {
  final dark = f.dark;
  final m = f.minExtent;
  // A thin coloured rim, a faint glow hugging it, and large soft clouds of
  // colour standing off the border that breathe in turn.
  o
    ..base = 0.4
    ..bumpPlateau = 1.2
    ..stroke = dark ? 0.6 : 0.55
    ..bloom = dark ? 0.12 : 0.1
    ..bloomSigma = 2 + f.glow
    ..bloomSide = BeamSide.outside
    ..outer = dark ? 0.05 : 0.08
    ..outerReach = (0.14 * m + 14) * f.glow
    ..outerWiden = 2
    ..highlight = dark ? 0.15 : 0.1
    ..additive = dark ? 0.6 : 0
    ..lights = dark ? 0.34 : 0.75;
  final anchors = _haloAnchors(f.outline);
  final width = math.min(0.12, 110 / f.length);
  // Cloud size follows the widget (a chip gets small clouds), capped so a
  // full-screen surface doesn't throw light across the whole screen.
  final along = math.min(0.29 * m + 10, 80.0) * f.glow;
  final across = math.min(0.17 * m + 6, 44.0) * f.glow;
  for (var i = 0; i < anchors.length; i++) {
    final b = _wave(f.phases.cycles * (0.8 + 0.13 * i) + 0.31 * i);
    o.addBump(anchors[i], width, width, 0.15 + 0.6 * b);
    _lightAt(
      o,
      f,
      anchors[i],
      along: along * (0.9 + 0.2 * b),
      inward: across * (0.9 + 0.2 * b),
      amplitude: 0.3 + 0.7 * b,
      outwardShift: 1.1 * across,
      side: BeamSide.outside,
    );
  }
}

void _flow(BeamEmission o, BeamFrame f) {
  final dark = f.dark;
  final m = f.minExtent;
  final dir = f.phases.reversedNow ? -1.0 : 1.0;
  // The palette streams round the border half a turn per cycle; the glow
  // inside drifts more slowly, so colour flows through it, and each patch
  // of it swells and ebbs on its own beat.
  final origin = dir * f.phases.cycles * 0.5;
  o
    ..base = 0.72
    ..colorOrigin = origin
    ..noiseAmplitude = 0.35
    ..noiseFrequency = 2
    ..noisePhase = f.phases.cycles * 0.6
    ..stroke = dark ? 0.85 : 0.8
    ..bloom = dark ? 0.42 : 0.28
    ..bloomSigma = 3 + 1.5 * f.glow
    ..highlight = dark ? 0.22 : 0.2
    ..additive = dark ? 0.45 : 0
    ..lights = dark ? 0.36 : 0.3;
  const count = 8;
  final along = f.length / count * 0.55;
  final reach = math.min((0.075 * m + 5) * f.glow, 0.32 * m);
  for (var i = 0; i < count; i++) {
    final swell = _wave(f.phases.cycles * (0.55 + 0.09 * (i % 3)) + i * 0.37);
    _lightAt(
      o,
      f,
      i / count + origin * 0.6,
      along: along,
      inward: reach * (0.65 + 0.7 * swell),
      amplitude: 0.25 + 0.75 * swell * swell,
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
    ..bloom = dark ? 0.38 : 0.26
    ..bloomSigma = 2.5 + 1.5 * f.glow
    ..bloomSide = BeamSide.both
    ..outer = dark ? 0.18 : 0.12
    ..outerReach = (6 + 0.05 * f.minExtent) * f.glow
    ..highlight = dark ? 0.1 : 0.1
    ..additive = dark ? 0.35 : 0;
}

void _shimmer(BeamEmission o, BeamFrame f, ShimmerEffect e) {
  final dark = f.dark;
  final r = f.outline.rect;
  final a = e.angle * math.pi / 180;
  // The sweep's direction in pixels, carried into box-normalised space and
  // scaled so the band coordinate spans exactly 0–1 across the box: the
  // glint keeps its true angle on any aspect ratio.
  final px = math.cos(a) * r.width;
  final py = math.sin(a) * r.height;
  final scale = math.max(px.abs() + py.abs(), 1e-6);
  final dx = px / scale;
  final dy = py / scale;
  const half = 0.2;
  final pos = -half + (1 + 2 * half) * f.phases.travelProgress;
  o
    ..sweepAmplitude = 1.15
    ..sweepDirection = Offset(dx, dy)
    ..sweepHalfWidth = half
    ..sweepPosition = pos
    ..stroke = 1
    ..bloom = dark ? 0.5 : 0.3
    ..bloomSigma = 2.5 + 1.5 * f.glow
    ..highlight = dark ? 0.8 : 0.5
    ..additive = dark ? 0.5 : 0
    ..lights = dark ? 0.3 : 0.24;
  // Where the glint's centre line crosses the border, it catches the edge:
  // a soft light just inside each crossing. The line is `c + s·(-dy, dx)`
  // in box-normalised space; [lo, hi] is the stretch of it inside the box.
  final norm = dx * dx + dy * dy;
  final cx = dx * (pos - 0.5) / norm;
  final cy = dy * (pos - 0.5) / norm;
  var lo = -1e9;
  var hi = 1e9;
  if (dy.abs() > 1e-6) {
    final s0 = (cx + 0.5) / dy;
    final s1 = (cx - 0.5) / dy;
    lo = math.max(lo, math.min(s0, s1));
    hi = math.min(hi, math.max(s0, s1));
  } else if (cx.abs() > 0.5) {
    return;
  }
  if (dx.abs() > 1e-6) {
    final s0 = (-0.5 - cy) / dx;
    final s1 = (0.5 - cy) / dx;
    lo = math.max(lo, math.min(s0, s1));
    hi = math.min(hi, math.max(s0, s1));
  } else if (cy.abs() > 0.5) {
    return;
  }
  if (hi <= lo) return;
  // Fade the catch lights in as the line enters the box and out as it
  // leaves, so they never pop at a corner.
  final presence = _smoothstep(0, 0.25, (hi - lo) * math.sqrt(norm));
  _shimmerCatch(o, f, cx - lo * dy, cy + lo * dx, presence);
  _shimmerCatch(o, f, cx - hi * dy, cy + hi * dx, presence);
}

void _shimmerCatch(BeamEmission o, BeamFrame f, double x, double y, double a) {
  if (a <= 0) return;
  final r = f.outline.rect;
  final m = f.minExtent;
  final point = Offset(r.center.dx + x * r.width, r.center.dy + y * r.height);
  _lightAt(
    o,
    f,
    f.outline.nearestFraction(point),
    along: (0.12 * m + 10) * f.glow,
    inward: math.min((0.08 * m + 5) * f.glow, 0.35 * m),
    amplitude: 0.9 * a,
  );
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
  final dir = reversed ? -1.0 : 1.0;
  final m = f.minExtent;
  // The tip light is placed against the user's track, before the fill
  // narrows it: the fill's own feather would otherwise fade the light out
  // exactly where it sits. It sits a little behind the tip, so it lights
  // the filled border rather than the empty one ahead.
  final along = (0.1 * m + 12) * f.glow;
  o.lights = dark ? 0.42 : 0.3;
  _lightAt(
    o,
    f,
    tip - dir * 0.8 * along / f.length,
    along: along,
    inward: math.min((0.1 * m + 5) * f.glow, 0.38 * m),
    amplitude: 0.85,
  );
  final userFeather = o.segmentSpan > 0 ? o.segmentFeather : 0.0;
  // The filled border brightens toward a white-hot tip.
  final glowTail = math.min(0.3, span);
  o
    ..segmentStart = start
    ..segmentSpan = span
    ..segmentFeather = math.max(math.min(5 / f.length, span / 2), userFeather)
    ..base = 0.72
    ..stroke = dark ? 0.9 : 0.85
    ..bloom = dark ? 0.4 : 0.26
    ..bloomSigma = 2.5 + 1.5 * f.glow
    ..highlight = dark ? 0.55 : 0.5
    ..additive = dark ? 0.4 : 0
    ..addBump(tip, reversed ? glowTail : 0.01, reversed ? 0.01 : glowTail, 0.3)
    ..addBump(tip, reversed ? 0.05 : 0.008, reversed ? 0.008 : 0.05, 0.5);
}
