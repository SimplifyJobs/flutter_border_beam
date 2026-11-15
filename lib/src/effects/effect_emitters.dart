import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/animation.dart' show Curves;

import '../animation/beam_phases.dart';
import '../look/beam_look.dart';
import '../look/layer_presets.dart';
import '../look/line_look.dart';
import '../look/look_blobs.dart';
import '../look/palette_tables.dart';
import '../look/pulse_look.dart';
import '../look/pulse_tables.dart';
import '../look/rotate_look.dart';
import '../models/beam_config.dart';
import '../models/beam_options.dart';
import '../models/beam_segment.dart';
import '../render/beam_frame.dart';
import '../render/beam_outline.dart';
import 'beam_effect.dart';

/// Everything an effect reads to write one frame.
final class BeamFrame {
  /// Creates a frame context.
  BeamFrame({
    required this.config,
    required this.phases,
    required this.outline,
    required this.data,
    required this.alpha,
  });

  /// The resolved config.
  final BeamConfig config;

  /// This frame's phases.
  final BeamFramePhases phases;

  /// The outline being lit.
  final BeamOutline outline;

  /// The uniforms being written.
  final BeamFrameData data;

  /// The frame's overall opacity: fade × strength × any extra.
  final double alpha;

  /// The palette's blob tables.
  late final BeamLookTables tables = BeamLook.tablesFor(config.palette);

  /// Whether the beam is styled for a dark surface.
  bool get dark => config.isDark;

  /// Whether the palette is the greyscale one.
  bool get mono => config.palette.mono;

  /// The outline box.
  Rect get rect => outline.rect;

  /// Perimeter length, px.
  double get length => outline.length;

  /// How much of the glow layers' opacity survives `BeamStyle.glow` (below 1
  /// the glows fade, so 0 leaves the hairline alone).
  double get glowOpacity => math.min(config.glow, 1);

  /// How far `BeamStyle.glow` grows the glows.
  double get glowSize => math.max(config.glow, 0.05);

  /// How far in from the edge an inner glow fades out: the design's 28 px,
  /// grown by `BeamStyle.glow`, but never more than 0.4 of the box, so a
  /// chip keeps a clear band through its middle.
  double get edgeFade =>
      math.min(innerEdgeFade * glowSize, rect.shortestSide * 0.4);

  /// Whether the box is small enough for the compact chip treatment.
  bool get compact => rect.shortestSide <= compactMaxExtent;

  /// Whether the hue holds still.
  bool get staticHue => config.hueMode == BeamHueMode.none;

  /// The ambient clock, in seconds.
  double get seconds => phases.cycles * config.cycleSeconds;

  /// A point of the box given as fractions of it.
  Offset at(double fx, double fy) =>
      Offset(rect.left + fx * rect.width, rect.top + fy * rect.height);
}

/// Writes [frame]'s layers into its data. The data must be reset and carry
/// the outline and the user's segment already.
void emitEffect(BeamFrame frame) {
  final effect = frame.config.effect;
  switch (effect) {
    case RotateEffect():
      _rotate(frame, effect);
    case LineEffect():
      _line(frame, effect);
    case PulseEffect():
      _pulse(frame);
    case HaloEffect():
      _halo(frame);
    case FlowEffect():
      _flow(frame);
    case SpinEffect():
      _spin(frame);
    case ShimmerEffect():
      _shimmer(frame, effect);
    case ChargeEffect():
      _charge(frame);
  }
}

/// Applies [segment] (if any) to [data]'s visible track, with [dashes].
void applyTrack(
  BeamFrameData data,
  BeamSegment? segment,
  BeamOutline outline,
  int dashes,
) {
  if (segment == null || outline.length <= 0) {
    data.setTrack(0, 0, 0, dashes);
    return;
  }
  final range = segment.resolve(outline);
  var span = BeamOutline.wrapFraction(range.to - range.from);
  if (span <= 0) span = 1;
  data.setTrack(
    range.from,
    span,
    math.min(segment.feather / outline.length, span / 2),
    dashes,
  );
}

/// The visible track as `(start, span)`; the whole border when no segment
/// is set.
({double start, double span}) segmentTrack(BeamFrameData data) =>
    data.trackSpan <= 0
    ? (start: 0.0, span: 1.0)
    : (start: data.trackStart, span: data.trackSpan);

// ─── Shared pieces ──────────────────────────────────────────────────────────

/// The conic coordinate of [point] around [centre]: 0 at 12 o'clock,
/// increasing clockwise, in turns.
double conicFraction(Offset point, Offset centre) {
  final d = point - centre;
  final t = math.atan2(d.dx, -d.dy) / (2 * math.pi);
  return t - t.floorToDouble();
}

// Scratch lists for table transforms: no allocation per frame.
final Float64List _stops = Float64List(tableStops);
final Float64List _alphas = Float64List(tableStops);
final Float64List _blurStops = Float64List(tableStops);
final Float64List _blurAlphas = Float64List(tableStops);

double _lookup(List<double> stops, List<double> alphas, int n, double t) {
  if (t <= stops[0]) return alphas[0];
  for (var i = 1; i < n; i++) {
    if (t <= stops[i]) {
      final span = math.max(stops[i] - stops[i - 1], 1e-9);
      return alphas[i - 1] +
          (alphas[i] - alphas[i - 1]) * (t - stops[i - 1]) / span;
    }
  }
  return alphas[n - 1];
}

/// Writes a conic table, its tail scaled by [tail] about the bright core's
/// leading edge, mirrored when [reversed], and blurred around the turn by
/// [blur] turns.
void _conicTable(
  BeamFrameData data,
  BeamTable table,
  List<double> stops,
  List<double> alphas, {
  double tail = 1,
  bool reversed = false,
  double shift = 0,
  double blur = 0,
}) {
  final n = math.min(stops.length, tableStops);
  var peak = alphas[0];
  for (var i = 0; i < n; i++) {
    peak = math.max(peak, alphas[i]);
  }
  var head = stops[0];
  for (var i = 0; i < n; i++) {
    if (alphas[i] >= peak) head = stops[i];
  }
  // The lit band, ignoring the table's 0 and 1 anchors.
  var first = 0;
  while (first < n - 1 && alphas[first + 1] <= 0) {
    first++;
  }
  var last = n - 1;
  while (last > 0 && alphas[last - 1] <= 0) {
    last--;
  }
  var f = tail;
  if (f != 1) {
    final back = head - stops[first];
    final front = stops[last] - head;
    var limit = double.infinity;
    if (back > 0) limit = math.min(limit, head / back);
    if (front > 0) limit = math.min(limit, (1 - head) / front);
    f = f.clamp(0.05, math.max(0.05, limit));
  }
  for (var i = 0; i < n; i++) {
    final s = (head + (stops[i] - head) * f + shift).clamp(0.0, 1.0);
    final j = reversed ? n - 1 - i : i;
    _stops[j] = reversed ? 1 - s : s;
    _alphas[j] = alphas[i];
  }
  if (blur <= 1e-4) {
    data.setTable(table, _stops, _alphas, n);
    return;
  }
  // Resample the table convolved with a gaussian of [blur] turns over its
  // lit band, widened by three sigmas.
  final lo = math.max(0.0, _stops[reversed ? n - 1 - last : first] - 3 * blur);
  final hi = math.min(1.0, _stops[reversed ? n - 1 - first : last] + 3 * blur);
  const taps = 9;
  _blurStops[0] = 0;
  _blurAlphas[0] = 0;
  final inner = tableStops - 2;
  for (var i = 0; i < inner; i++) {
    final x = lo + (hi - lo) * i / (inner - 1);
    var sum = 0.0;
    var weight = 0.0;
    for (var k = 0; k < taps; k++) {
      final o = (k - (taps - 1) / 2) / ((taps - 1) / 2) * 2.5;
      final w = math.exp(-0.5 * o * o);
      sum += w * _lookup(_stops, _alphas, n, (x + o * blur).clamp(0.0, 1.0));
      weight += w;
    }
    _blurStops[i + 1] = x;
    _blurAlphas[i + 1] = sum / weight;
  }
  _blurStops[tableStops - 1] = 1;
  _blurAlphas[tableStops - 1] = 0;
  data.setTable(table, _blurStops, _blurAlphas, tableStops);
}

/// Sets a layer's colour filter: the hue drift with the preset's
/// brightness and saturation, or — with the hue held — no filter beyond the
/// static hue base, unless [keepTone] keeps the brightness and saturation.
void _filter(
  BeamFrame f,
  int k,
  BeamLayerPreset preset, {
  double? hue,
  bool keepTone = false,
  double? brightness,
  double? saturation,
  bool fold = true,
}) {
  final h = f.staticHue
      ? f.config.hueBase
      : (hue ?? f.phases.hueDegrees) + f.config.hueBase;
  if (f.staticHue && !keepTone) {
    f.data.setFilter(k, hue: h, fold: fold);
    return;
  }
  f.data.setFilter(
    k,
    hue: h,
    brightness: brightness ?? preset.brightness,
    saturation: saturation ?? preset.saturation,
    fold: fold,
  );
}

/// The inner glow's inset shadow for a layer.
void _shadow(BeamFrame f, int k, Color color, double blur) {
  if (color.a <= 0) return;
  f.data.setShadow(k, color, depth: blur + 1, sigma: blur / 2);
}

double _ping(double t, double period, double range) {
  final c = t / period;
  final cycle = c - c.floorToDouble();
  final local = cycle < 0.5 ? cycle / 0.5 : (1 - cycle) / 0.5;
  final eased = Curves.easeInOut.transform(local.clamp(0.0, 1.0));
  return -range + 2 * range * eased;
}

// ─── Rotate ─────────────────────────────────────────────────────────────────

void _rotate(BeamFrame f, RotateEffect e) {
  final d = f.data;
  final rect = f.rect;
  final dark = f.dark;
  final compact = rect.shortestSide <= compactMaxExtent;
  final preset = presetFor(
    compact ? compactPresets : rotatePresets,
    dark: dark,
  );
  final base = f.alpha * (f.mono ? 0.5 : 1);
  final reversed = f.phases.reversedNow;
  final n = f.config.beamCount;
  final tail = e.length.clamp(0.25, 2.0);
  final sigma = rotateBloomBlur * f.glowSize;

  _conicTable(
    d,
    BeamTable.windowA,
    rotateWindowStops,
    rotateWindowAlphas,
    tail: tail,
    reversed: reversed,
  );
  if (compact) {
    _conicTable(
      d,
      BeamTable.windowB,
      compactWindowStops,
      compactWindowAlphas,
      tail: tail,
      reversed: reversed,
    );
  }
  _conicTable(
    d,
    BeamTable.overlayA,
    rotateHighlightStops,
    dark ? rotateHighlightAlphasDark : rotateHighlightAlphasLight,
    tail: tail,
    reversed: reversed,
  );
  _conicTable(
    d,
    BeamTable.overlayB,
    rotateBloomStops,
    dark ? rotateBloomAlphasDark : rotateBloomAlphasLight,
    tail: tail * (e.comet ? 1.6 : 1),
    reversed: reversed,
    blur: sigma * n / math.max(f.length, 1),
  );
  final head = reversed ? 1 - rotateHeadStop : rotateHeadStop;
  d.setConic(rect.center, _headAngle(f) - head / n, n);

  // Inner glow.
  d
    ..setLayer(
      0,
      BeamGeometry.fill,
      opacity: base * preset.innerOpacity * f.glowOpacity,
    )
    ..setConicWindow(0, compact ? BeamTable.windowB : BeamTable.windowA);
  if (!compact) d.setEdgeFade(0, f.edgeFade);
  _shadow(
    f,
    0,
    preset.innerShadow,
    compact ? compactInnerShadowBlur : rotateInnerShadowBlur,
  );
  _filter(f, 0, preset);
  if (compact) {
    for (final b in f.tables.smallInner) {
      final c = f.at(b.position.dx, b.position.dy);
      d.addSimpleBlob(
        0,
        cx: c.dx,
        cy: c.dy,
        rx: b.size.width,
        ry: b.size.height,
        color: b.color,
      );
    }
  } else {
    final alpha = f.mono ? rotateInnerBlobAlphaMono : rotateInnerBlobAlpha;
    for (final b in f.tables.border) {
      final c = f.at(b.position.dx, b.position.dy);
      d.addSimpleBlob(
        0,
        cx: c.dx,
        cy: c.dy,
        rx: (b.size.width * rotateInnerBlobScale).roundToDouble(),
        ry: (b.size.height * rotateInnerBlobScale).roundToDouble(),
        color: b.color.withValues(alpha: alpha),
      );
    }
  }

  // Hairline stroke.
  d
    ..setLayer(1, BeamGeometry.ring, opacity: base * preset.strokeOpacity)
    ..setConicWindow(1, BeamTable.windowA)
    ..setOverlay(1, BeamTable.overlayA, white: dark)
    ..setDashed(1);
  _filter(f, 1, preset);
  for (final b in compact ? f.tables.smallBorder : f.tables.border) {
    final c = f.at(b.position.dx, b.position.dy);
    d.addSimpleBlob(
      1,
      cx: c.dx,
      cy: c.dy,
      rx: b.size.width,
      ry: b.size.height,
      color: b.color,
    );
  }

  // Bloom: the bright band at the head, blurred — or, as a comet, a glow
  // trailing the head outside the border.
  d
    ..setLayer(
      2,
      e.comet ? BeamGeometry.halo : BeamGeometry.blurredRing,
      opacity: base * preset.bloomOpacity * f.glowOpacity,
      sigma: sigma,
      inflate: e.comet ? cometReach * f.glowSize : 0,
    )
    ..setOverlay(2, BeamTable.overlayB, white: dark)
    ..setDashed(2)
    ..setFilter(
      2,
      brightness: preset.brightness,
      saturation: preset.saturation,
    );
}

/// The conic angle the head of a travelling beam sits at: the travel itself
/// around the turn, or — on a segment — the point of the track it has
/// reached.
double _headAngle(BeamFrame f) {
  final p = f.phases.travelProgress;
  final track = segmentTrack(f.data);
  if (track.span >= 1) return p;
  return conicFraction(
    f.outline.pointAt(track.start + track.span * p),
    f.rect.center,
  );
}

// ─── Line ───────────────────────────────────────────────────────────────────

void _line(BeamFrame f, LineEffect e) {
  final d = f.data;
  final dark = f.dark;
  final preset = presetFor(linePresets, dark: dark);
  final p = f.phases.travelProgress.clamp(0.0, 1.0);
  final driven = f.phases.driven;
  final x = driven ? p : sampleKeyframes(lineTravelX, p);
  final w = driven ? 1.2 : sampleKeyframes(lineTravelW, p);
  final fade = driven ? 1.0 : sampleKeyframes(lineEdgeFade, p);
  final cyc = f.phases.cycles;
  double frac(double v) => v - v.floorToDouble();
  final h = sampleKeyframes(
    lineBreatheH,
    frac(cyc / lineBreathePeriod),
    eased: true,
  );
  final s1 = sampleKeyframes(
    lineSpike,
    frac(cyc / lineSpikePeriod),
    eased: true,
  );
  final s2 = sampleKeyframes(
    lineSpike2,
    frac(cyc / lineSpike2Period),
    eased: true,
  );
  final base = f.alpha * fade;
  if (base <= 0) return;

  // Two hue tracks: the stroke and glow swing gently, the bloom wider and
  // faster.
  final range = math.min(f.config.hueShift, lineHueCap);
  final ht = f.phases.hueTime;
  final period = f.config.huePeriodSeconds;
  final (strokeHue, bloomHue) = switch (f.config.hueMode) {
    BeamHueMode.none => (0.0, 0.0),
    BeamHueMode.continuous => (f.phases.hueDegrees, f.phases.hueDegrees),
    BeamHueMode.pingPong => (
      _ping(ht, period * 1.5, range),
      _ping(ht, period, range + lineBloomHueBonus),
    ),
  };

  final frame = _LineFrame(f, e.edge);
  final bx = x * frame.width;
  final tables = f.tables;

  // Inner glow.
  d
    ..setLayer(
      0,
      BeamGeometry.fill,
      opacity: base * preset.innerOpacity * f.glowOpacity,
    )
    ..setEdgeFade(0, f.edgeFade);
  frame.space(0);
  frame.window(
    0,
    bx,
    0,
    lineWindowRadiusX * w,
    lineWindowRadiusY * h,
    lineWindowMidStop,
    lineWindowMidAlpha,
  );
  _shadow(f, 0, preset.innerShadow, lineInnerShadowBlur);
  _filter(f, 0, preset, hue: strokeHue);
  for (final b in tables.lineInner) {
    frame.blob(
      0,
      bx + b.offsetX,
      b.offsetY.abs(),
      b.sizeW * w,
      b.sizeH * h,
      b.color,
    );
  }

  // Stroke: the travelling highlight over the streak's blobs.
  d
    ..setLayer(1, BeamGeometry.ring, opacity: base * preset.strokeOpacity)
    ..setDashed(1);
  frame.space(1);
  frame.window(
    1,
    bx,
    0,
    lineWindowRadiusX * w,
    lineWindowRadiusY * h,
    lineWindowMidStop,
    lineWindowMidAlpha,
  );
  _filter(f, 1, preset, hue: strokeHue);
  final hiAlphas = dark ? lineHighlightAlphasDark : lineHighlightAlphasLight;
  final hiStops = dark ? lineHighlightStopsDark : lineHighlightStopsLight;
  frame.stopBlob(
    1,
    bx,
    -lineHighlightOffsetY,
    (dark ? lineHighlightRadiusXDark : lineHighlightRadiusXLight) * w,
    (dark ? lineHighlightRadiusYDark : lineHighlightRadiusYLight) * h,
    dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    hiAlphas,
    hiStops,
  );
  for (final b in dark ? tables.lineDark : tables.lineLight) {
    frame.blob(
      1,
      bx + b.offsetX,
      -b.offsetY,
      b.sizeW * w,
      b.sizeH * h,
      b.color,
    );
  }

  // Bloom: seven spikes rising from the edge, the travelling dot and its
  // ambient glow (or, on a light surface, a soft shadow), seen through a
  // tall window that travels with the streak.
  final mono = f.mono;
  final blur =
      (mono ? lineBloomBlurMono : (f.staticHue ? 0.0 : lineBloomBlur)) *
      f.glowSize;
  d.setLayer(
    2,
    BeamGeometry.fill,
    opacity: base * preset.bloomOpacity * f.glowOpacity,
  );
  frame.space(2, blur: blur);
  frame.window(
    2,
    bx,
    0,
    lineBloomWindowRadiusX * w,
    lineBloomWindowRadiusY * h,
    lineBloomWindowMidStop,
    lineBloomWindowMidAlpha,
  );
  _filter(f, 2, preset, hue: bloomHue);
  _lineSpikes(
    frame,
    tables,
    dark: dark,
    mono: mono,
    s1: s1,
    s2: s2,
    h: h,
    w: w,
    bx: bx,
  );
}

void _lineSpikes(
  _LineFrame frame,
  BeamLookTables tables, {
  required bool dark,
  required bool mono,
  required double s1,
  required double s2,
  required double h,
  required double w,
  required double bx,
}) {
  final spikeColors = dark ? tables.spike : tables.spikeLt;
  final table = dark ? tables.lineBloomDark : tables.lineBloomLight;
  Color att(Color c, double k) =>
      c.a < 1 ? c.withValues(alpha: c.a * k) : c.withValues(alpha: k);
  final sc1 = mono
      ? att(spikeColors.primary, lineMonoSpike1)
      : spikeColors.primary;
  final sc1Mid = dark
      ? (mono
            ? att(spikeColors.primary, lineMonoSpike1MidDark)
            : spikeColors.primary)
      : (mono
            ? att(spikeColors.primary, lineMonoSpike1MidLight)
            : spikeColors.primary.withValues(alpha: lineSpike1MidLightAlpha));
  final sc2 = mono
      ? att(spikeColors.secondary, lineMonoSpike2)
      : spikeColors.secondary;
  final sc2Mid = dark
      ? spikeColors.secondary.withValues(
          alpha: mono ? lineMonoSpike2MidDark : lineSpike2MidDarkAlpha,
        )
      : (mono
            ? att(spikeColors.secondary, lineMonoSpike2MidLight)
            : spikeColors.secondary.withValues(alpha: lineSpike2MidLightAlpha));
  SpikePair pair(int i) => mono
      ? SpikePair(
          att(table[i].color1, lineMonoTableSpike1),
          att(table[i].color2, lineMonoTableSpike2),
        )
      : table[i];
  final thinW = mono ? lineMonoThinSpikeWidths : lineThinSpikeWidths;
  final thinH = mono ? lineMonoThinSpikeHeights : lineThinSpikeHeights;
  final thinLW = mono
      ? lineMonoThinSpikeWidthLight92
      : lineThinSpikeWidthLight92;
  final wa = frame.width;

  void spike(int i, double rx, double ry, Color c0, Color mid) {
    final g = lineSpikes[i];
    frame.stopBlob(
      2,
      g.fx * wa,
      g.yInset,
      rx,
      ry,
      c0,
      [c0.a, mid.a, 0],
      [0, g.midStop, g.endStop],
    );
  }

  spike(0, thinW[0] * s1, thinH[0] * h, sc1, sc1Mid);
  spike(1, lineSpikeWideRadiusX22 * s2, lineSpikeRadiusY22 * h, sc2, sc2Mid);
  spike(2, thinW[1] * (2 - s1), thinH[1] * h, pair(0).color1, pair(0).color2);
  spike(
    3,
    lineSpikeWideRadiusX50 * s2,
    lineSpikeRadiusY50 * h,
    pair(1).color1,
    pair(1).color2,
  );
  spike(4, thinW[2] * (2 - s2), thinH[2] * h, pair(2).color1, pair(2).color2);
  spike(
    5,
    lineSpikeRadiusX78 * s1,
    lineSpikeRadiusY78 * h,
    pair(3).color1,
    pair(3).color2,
  );
  spike(
    6,
    (dark ? thinW[3] : thinLW) * (2 - s1),
    thinH[3] * h,
    pair(4).color1,
    pair(4).color2,
  );

  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);
  if (dark) {
    frame.stopBlob(
      2,
      bx,
      -lineDotOffsetY,
      lineDotRadiusX * s1,
      lineDotRadiusY * s2,
      white,
      [...(mono ? lineDotAlphasMono : lineDotAlphas), 0],
      lineDotStops,
    );
    frame.stopBlob(
      2,
      bx,
      0,
      lineAmbientRadiusX * w,
      lineAmbientRadiusY * h,
      white,
      [...(mono ? lineAmbientAlphasMono : lineAmbientAlphas), 0],
      lineAmbientStops,
    );
  } else {
    frame.stopBlob(
      2,
      bx,
      0,
      lineShadowRadiusX * w,
      lineShadowRadiusY * h,
      black,
      lineShadowAlphas,
      lineShadowStops,
    );
  }
}

/// The frame the line is authored in — the streak riding the bottom edge of
/// a [width] × [height] box, x along the edge and y the depth in from it —
/// mapped onto the real edge, or onto the user's segment in path space.
class _LineFrame {
  _LineFrame(this.f, this.edge) {
    final r = f.rect;
    final track = f.data.trackSpan > 0;
    path = track;
    if (track) {
      width = f.data.trackSpan * f.length;
      height = r.height;
      start = f.data.trackStart * f.length;
    } else {
      final vertical = edge == BeamEdge.left || edge == BeamEdge.right;
      width = vertical ? r.height : r.width;
      height = vertical ? r.width : r.height;
    }
  }

  final BeamFrame f;
  final BeamEdge edge;
  late final bool path;
  late final double width;
  late final double height;
  double start = 0;

  bool get _swap => !path && (edge == BeamEdge.left || edge == BeamEdge.right);

  /// The canvas point (or path-space point) of authored x along the edge
  /// and [depth] in from it.
  Offset map(double x, double depth) {
    if (path) return Offset(start + x, depth);
    final r = f.rect;
    return switch (edge) {
      BeamEdge.bottom => Offset(r.left + x, r.bottom - depth),
      BeamEdge.top => Offset(r.right - x, r.top + depth),
      BeamEdge.left => Offset(r.left + depth, r.top + x),
      BeamEdge.right => Offset(r.right - depth, r.bottom - x),
    };
  }

  void space(int k, {double blur = 0}) => f.data.setBlobSpace(
    k,
    blur > 0
        ? (path ? BeamBlobSpace.blurredPath : BeamBlobSpace.blurred)
        : (path ? BeamBlobSpace.path : BeamBlobSpace.planar),
    blur: blur,
  );

  void window(
    int k,
    double x,
    double depth,
    double rx,
    double ry,
    double mid,
    double midAlpha,
  ) {
    final c = map(x, depth);
    f.data.setRadialWindow(
      k,
      c,
      _swap ? ry : rx,
      _swap ? rx : ry,
      midStop: mid,
      midAlpha: midAlpha,
    );
  }

  void blob(int k, double x, double depth, double rx, double ry, Color color) {
    final c = map(x, depth);
    f.data.addSimpleBlob(
      k,
      cx: c.dx,
      cy: c.dy,
      rx: _swap ? ry : rx,
      ry: _swap ? rx : ry,
      color: color,
    );
  }

  /// A blob with explicit alpha stops (2–4; the last alpha is 0).
  void stopBlob(
    int k,
    double x,
    double depth,
    double rx,
    double ry,
    Color rgb,
    List<double> alphas,
    List<double> stops,
  ) {
    final c = map(x, depth);
    final n = alphas.length;
    double a1;
    double p1;
    double a2;
    double p2;
    final end = stops[n - 1];
    if (n >= 4) {
      p1 = stops[1];
      a1 = alphas[1];
      p2 = stops[2];
      a2 = alphas[2];
    } else if (n == 3) {
      p1 = stops[1];
      a1 = alphas[1];
      p2 = (stops[1] + end) / 2;
      a2 = alphas[1] / 2;
    } else {
      p1 = end / 3;
      a1 = alphas[0] * 2 / 3;
      p2 = end * 2 / 3;
      a2 = alphas[0] / 3;
    }
    f.data.addBlob(
      k,
      cx: c.dx,
      cy: c.dy,
      rx: _swap ? ry : rx,
      ry: _swap ? rx : ry,
      rgb: rgb,
      a0: alphas[0],
      p1: p1,
      a1: a1,
      p2: p2,
      a2: a2,
      p3: end,
      clip: f.data.blobSpaceOf(k).index >= BeamBlobSpace.blurred.index
          ? _edgeClip
          : null,
    );
  }

  // The edge the streak rides: a blurred layer is cut there before its
  // blur, so light below the edge never spills back in.
  ({int axis, double at, bool keepBelow}) get _edgeClip {
    if (path) return (axis: 1, at: 0, keepBelow: false);
    final r = f.rect;
    return switch (edge) {
      BeamEdge.bottom => (axis: 1, at: r.bottom, keepBelow: true),
      BeamEdge.top => (axis: 1, at: r.top, keepBelow: false),
      BeamEdge.left => (axis: 0, at: r.left, keepBelow: false),
      BeamEdge.right => (axis: 0, at: r.right, keepBelow: true),
    };
  }
}

// ─── Pulse ──────────────────────────────────────────────────────────────────

// One oscillator bank per tuning, rebuilt only when the tuning changes.
final Map<(bool, bool, double), PulseOscillatorBank> _banks = {};
final PulseFrame _pulseFrame = PulseFrame();

PulseFrame _breathe(BeamFrame f, {required bool halo}) {
  final key = (halo, f.dark, f.config.cycleSeconds);
  final bank = _banks[key] ??= () {
    if (_banks.length > 16) _banks.clear();
    return PulseOscillatorBank(
      halo
          ? PulseParams.halo(dark: f.dark, cycleSeconds: f.config.cycleSeconds)
          : PulseParams.pulse(
              dark: f.dark,
              cycleSeconds: f.config.cycleSeconds,
            ),
    );
  }();
  bank.sample(f.seconds, _pulseFrame);
  return _pulseFrame;
}

double _quad(PulseFrame p, PulseQuad q) => p.bop[q.index];

BeamBlob _borderAt(BeamLookTables t, int i) => t.border[i % t.border.length];

/// One breathing pulse blob: its group's size and drift, its corner's
/// opacity.
void _pulseBlob(
  BeamFrame f,
  int k, {
  required Rect box,
  required Offset position,
  required double w,
  required double h,
  required Color color,
  required PulseRegion region,
  required PulseQuad quad,
  required PulseFrame pulse,
  double sx = 1,
  double sy = 1,
  double boost = 1,
  Offset scale = const Offset(1, 1),
}) {
  final r = region.index;
  var c = Offset(
    box.left + position.dx * box.width + pulse.bx[r],
    box.top + position.dy * box.height + pulse.by[r],
  );
  final centre = f.rect.center;
  c =
      centre +
      Offset((c.dx - centre.dx) * scale.dx, (c.dy - centre.dy) * scale.dy);
  f.data.addSimpleBlob(
    k,
    cx: c.dx,
    cy: c.dy,
    rx: w * pulse.bw[r] * sx * boost * scale.dx,
    ry: h * pulse.bh[r] * pulse.bgh * sy * boost * scale.dy,
    color: color,
    alpha: _quad(pulse, quad),
  );
}

/// One static bloom blob at the breathing's average alpha.
void _frozenBlob(
  BeamFrame f,
  int k, {
  required Rect box,
  required Offset position,
  required double w,
  required double h,
  required Color color,
  required double alpha,
  double sx = 1,
  double sy = 1,
  double boost = 1,
  Offset scale = const Offset(1, 1),
}) {
  var c = Offset(
    box.left + position.dx * box.width,
    box.top + position.dy * box.height,
  );
  final centre = f.rect.center;
  c =
      centre +
      Offset((c.dx - centre.dx) * scale.dx, (c.dy - centre.dy) * scale.dy);
  f.data.addSimpleBlob(
    k,
    cx: c.dx,
    cy: c.dy,
    rx: w * sx * boost * scale.dx,
    ry: h * sy * boost * scale.dy,
    color: color.withValues(alpha: alpha),
  );
}

void _pulse(BeamFrame f) {
  final d = f.data;
  final dark = f.dark;
  final preset = presetFor(pulsePresets, dark: dark);
  final base = f.alpha * (f.mono ? 0.5 : 1);
  final pulse = _breathe(f, halo: false);
  final params = PulseParams.pulse(
    dark: dark,
    cycleSeconds: f.config.cycleSeconds,
  );
  final border = f.tables.border;
  final rect = f.rect;

  // Inner glow: the breathing blobs and the corner accents, faded in from
  // the edge.
  d
    ..setLayer(
      0,
      BeamGeometry.fill,
      opacity: base * preset.innerOpacity * f.glowOpacity,
    )
    ..setEdgeFade(0, f.edgeFade);
  _filter(f, 0, preset, keepTone: true);
  for (final (i, b) in border.indexed) {
    final map = pulseRingMap[i % pulseRingMap.length];
    final size = pulseInnerSizes[i % pulseInnerSizes.length];
    _pulseBlob(
      f,
      0,
      box: rect,
      position: b.position,
      w: size.width * f.glowSize,
      h: size.height * f.glowSize,
      color: b.color,
      region: map.region,
      quad: map.quad,
      pulse: pulse,
    );
  }
  final corner = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  final cornerAlpha = dark ? pulseCornerAlphaDark : pulseCornerAlphaLight;
  for (final (pos, quad) in const [
    (Offset(0, 0), PulseQuad.tl),
    (Offset(1, 0), PulseQuad.tr),
    (Offset(0, 1), PulseQuad.bl),
    (Offset(1, 1), PulseQuad.br),
  ]) {
    final c = f.at(pos.dx, pos.dy);
    d.addSimpleBlob(
      0,
      cx: c.dx,
      cy: c.dy,
      rx: pulseCornerRadius * f.glowSize,
      ry: pulseCornerRadius * f.glowSize,
      color: corner.withValues(alpha: cornerAlpha * _quad(pulse, quad)),
      end: pulseCornerEndStop,
    );
  }

  // Stroke: the border blobs breathing on the hairline.
  d
    ..setLayer(1, BeamGeometry.ring, opacity: base * preset.strokeOpacity)
    ..setDashed(1);
  _filter(f, 1, preset, keepTone: true);
  for (final (i, b) in border.indexed) {
    final map = pulseRingMap[i % pulseRingMap.length];
    _pulseBlob(
      f,
      1,
      box: rect,
      position: b.position,
      w: b.size.width,
      h: b.size.height,
      color: b.color,
      region: map.region,
      quad: map.quad,
      pulse: pulse,
    );
  }

  // Bloom: the static blobs on the ring, blurred.
  d.setLayer(
    2,
    BeamGeometry.blurredRing,
    opacity: base * preset.bloomOpacity * f.glowOpacity,
    sigma: pulseBloomBlur * f.glowSize,
  );
  _filter(f, 2, preset, keepTone: true);
  for (final spec in pulseInnerBloom) {
    final src = _borderAt(f.tables, spec.ci);
    _frozenBlob(
      f,
      2,
      box: rect,
      position: src.position,
      w: spec.w,
      h: spec.h,
      color: src.color,
      alpha: params.frozenBloomAlpha,
    );
  }
}

// ─── Halo ───────────────────────────────────────────────────────────────────

void _halo(BeamFrame f) {
  final d = f.data;
  final dark = f.dark;
  final preset = presetFor(haloPresets, dark: dark);
  final base = f.alpha * (f.mono ? 0.5 : 1);
  final pulse = _breathe(f, halo: true);
  final params = PulseParams.halo(
    dark: dark,
    cycleSeconds: f.config.cycleSeconds,
  );
  final rect = f.rect;
  final sx = (rect.width / haloReferenceWidth).clamp(
    haloMinScale,
    haloMaxScale,
  );
  final sy = (rect.height / haloReferenceHeight).clamp(
    haloMinScale,
    haloMaxScale,
  );
  final unit = sx / haloMinScale * haloUnitDamping;
  final g = f.glowSize;
  final coreInset = haloCoreInset * unit * g;
  final bloomInset = haloBloomInset * unit * g;
  final coreBlur = haloCoreBlur * unit * g;
  final bloomBlur = haloBloomBlur * unit * g;
  const scale = Offset(haloScaleX, haloScaleY);
  const sigmaScale = (haloScaleX + haloScaleY) / 2;
  // The glows' shapes are the box grown by their inset and then shrunk about
  // the centre: what sticks out past the box on average.
  double reach(double inset) =>
      (((rect.width + 2 * inset) * haloScaleX - rect.width) / 2 +
          ((rect.height + 2 * inset) * haloScaleY - rect.height) / 2) /
      2;
  final glowBrightness = haloGlowBrightness * haloGlowMultiplier;
  final glowSaturation = haloGlowSaturation * haloGlowMultiplier;

  // Bloom: the wide static wash.
  final bloomBox = rect.inflate(bloomInset);
  d
    ..setLayer(
      0,
      BeamGeometry.halo,
      opacity: base * preset.bloomOpacity * haloGlowMultiplier * f.glowOpacity,
      sigma: bloomBlur * sigmaScale,
      inflate: reach(bloomInset),
    )
    ..setBlobSpace(0, BeamBlobSpace.blurred, blur: bloomBlur * sigmaScale);
  _filter(
    f,
    0,
    preset,
    keepTone: true,
    brightness: glowBrightness,
    saturation: glowSaturation,
    fold: false,
  );
  for (final spec in pulseOuterBloom) {
    final src = _borderAt(f.tables, spec.ci);
    _frozenBlob(
      f,
      0,
      box: bloomBox,
      position: Offset(spec.x ?? src.position.dx, spec.y ?? src.position.dy),
      w: spec.w,
      h: spec.h,
      color: src.color,
      alpha: params.frozenBloomAlpha,
      sx: sx,
      sy: sy,
      boost: haloBoost,
      scale: scale,
    );
  }

  // Stroke: the core blobs breathing on the hairline.
  d
    ..setLayer(
      1,
      BeamGeometry.ring,
      opacity: base * preset.strokeOpacity * haloGlowMultiplier,
    )
    ..setDashed(1);
  _filter(f, 1, preset, keepTone: true, fold: false);
  for (final spec in pulseOuterCore) {
    final src = _borderAt(f.tables, spec.ci);
    _pulseBlob(
      f,
      1,
      box: rect,
      position: Offset(spec.x ?? src.position.dx, spec.y ?? src.position.dy),
      w: spec.w,
      h: spec.h,
      color: src.color,
      region: spec.region,
      quad: spec.quad,
      pulse: pulse,
      sx: sx,
      sy: sy,
    );
  }

  // Core: the breathing glow hugging the edge.
  final coreBox = rect.inflate(coreInset);
  d
    ..setLayer(
      2,
      BeamGeometry.halo,
      opacity: base * preset.innerOpacity * haloGlowMultiplier * f.glowOpacity,
      sigma: coreBlur * sigmaScale,
      inflate: reach(coreInset),
    )
    ..setBlobSpace(2, BeamBlobSpace.blurred, blur: coreBlur * sigmaScale);
  _filter(
    f,
    2,
    preset,
    keepTone: true,
    brightness: glowBrightness,
    saturation: glowSaturation,
    fold: false,
  );
  for (final spec in pulseOuterCore) {
    final src = _borderAt(f.tables, spec.ci);
    _pulseBlob(
      f,
      2,
      box: coreBox,
      position: Offset(spec.x ?? src.position.dx, spec.y ?? src.position.dy),
      w: spec.w,
      h: spec.h,
      color: src.color,
      region: spec.region,
      quad: spec.quad,
      pulse: pulse,
      sx: sx,
      sy: sy,
      boost: haloBoost,
      scale: scale,
    );
  }
}

// ─── Blobs along the outline (flow, spin, shimmer, charge) ──────────────────

/// Adds a blob centred on the outline at perimeter [u], [depth] px in, with
/// radius [along] the outline and [inward] across it. The ellipse's axes
/// follow the outline's normal there, blending smoothly through a corner.
void _onOutline(
  BeamFrame f,
  int k,
  double u, {
  required double along,
  required double inward,
  required Color color,
  double depth = 0,
  double alpha = 1,
  Offset drift = Offset.zero,
  Offset stretch = const Offset(1, 1),
}) {
  final n = f.outline.normalAt(u);
  final c = f.outline.pointAt(u) - n * depth + drift;
  final nx = n.dx * n.dx;
  final ny = n.dy * n.dy;
  f.data.addSimpleBlob(
    k,
    cx: c.dx,
    cy: c.dy,
    rx: (along * ny + inward * nx) * stretch.dx,
    ry: (along * nx + inward * ny) * stretch.dy,
    color: color,
    alpha: alpha,
  );
}

/// Lays [count] blobs evenly around the outline, each coloured from the
/// palette where it starts and carried [shift] turns along it.
void _paletteRing(
  BeamFrame f,
  int k, {
  required int count,
  required double inward,
  double alpha = 1,
  double shift = 0,
  double overlap = 1.25,
}) {
  final along = f.length / count * overlap;
  final palette = f.config.palette;
  for (var i = 0; i < count; i++) {
    final u = (i + 0.5) / count;
    _onOutline(
      f,
      k,
      u + shift,
      along: along,
      inward: inward,
      color: palette.sample(u),
      alpha: alpha,
    );
  }
}

// The strength of a full colour ring's hairline, which — unlike the rotate
// beam's — carries the whole look.
const double _ringStrokeDark = 0.85;
const double _ringStrokeLight = 0.55;

/// The inner glow under a colour ring: its blobs at the rotate beam's inner
/// alpha, edge-faded, with the inset shadow — on a compact chip with the
/// chip's tuning. With [head] set it is seen through the rotate window
/// (the chip's wider one on a chip) led by that stop of the turn.
void _ringInnerGlow(
  BeamFrame f, {
  double? head,
  bool reversed = false,
  double tail = 1,
  double shift = 0,
}) {
  final d = f.data;
  final compact = f.compact;
  final preset = presetFor(
    compact ? compactPresets : rotatePresets,
    dark: f.dark,
  );
  d
    ..setLayer(
      0,
      BeamGeometry.fill,
      opacity:
          f.alpha * (f.mono ? 0.5 : 1) * preset.innerOpacity * f.glowOpacity,
    )
    ..setEdgeFade(0, f.edgeFade);
  if (head != null) {
    _conicTable(
      d,
      BeamTable.windowB,
      compact ? compactWindowStops : rotateWindowStops,
      compact ? compactWindowAlphas : rotateWindowAlphas,
      reversed: reversed,
      tail: tail,
      shift: head - (compact ? 0.82 : 0.80),
    );
    d.setConicWindow(0, BeamTable.windowB);
  }
  _shadow(
    f,
    0,
    preset.innerShadow,
    compact ? compactInnerShadowBlur : rotateInnerShadowBlur,
  );
  _filter(f, 0, preset);
  _paletteRing(
    f,
    0,
    count: 12,
    inward: math.min(36, f.rect.shortestSide / 2),
    alpha: rotateInnerBlobAlpha,
    shift: shift,
  );
}

// ─── Spin ───────────────────────────────────────────────────────────────────

// The whole ring stays lit, brightening into the head.
const List<double> _spinWindowStops = [0.0, 0.40, 0.75, 0.88, 0.93, 1.0];
const List<double> _spinWindowAlphas = [0.6, 0.66, 0.85, 1.0, 0.8, 0.6];
const double _spinHead = 0.9;

void _spin(BeamFrame f) {
  final d = f.data;
  final dark = f.dark;
  final preset = presetFor(rotatePresets, dark: dark);
  final base = f.alpha * (f.mono ? 0.5 : 1);
  final reversed = f.phases.reversedNow;
  final turn = (reversed ? -1.0 : 1.0) * f.phases.cycles;
  final sigma = rotateBloomBlur * f.glowSize;
  final head = reversed ? 1 - _spinHead : _spinHead;

  _conicTable(
    d,
    BeamTable.windowA,
    _spinWindowStops,
    _spinWindowAlphas,
    reversed: reversed,
  );
  _conicTable(
    d,
    BeamTable.overlayA,
    rotateHighlightStops,
    dark ? rotateHighlightAlphasDark : rotateHighlightAlphasLight,
    reversed: reversed,
    shift: _spinHead - 0.66,
  );
  _conicTable(
    d,
    BeamTable.overlayB,
    rotateBloomStops,
    dark ? rotateBloomAlphasDark : rotateBloomAlphasLight,
    reversed: reversed,
    shift: _spinHead - rotateHeadStop,
    blur: sigma / math.max(f.length, 1),
  );
  // The colours turn with the head.
  d.setConic(f.rect.center, turn - head, 1);

  _ringInnerGlow(f, head: _spinHead, reversed: reversed, shift: turn);

  d
    ..setLayer(
      1,
      BeamGeometry.ring,
      opacity: base * (dark ? _ringStrokeDark : _ringStrokeLight),
    )
    ..setConicWindow(1, BeamTable.windowA)
    ..setOverlay(1, BeamTable.overlayA, white: dark, above: dark)
    ..setDashed(1);
  _filter(f, 1, preset);
  _paletteRing(f, 1, count: 10, inward: 30, shift: turn);

  d
    ..setLayer(
      2,
      BeamGeometry.blurredRing,
      opacity: base * preset.bloomOpacity * f.glowOpacity,
      sigma: sigma,
    )
    ..setOverlay(2, BeamTable.overlayB, white: dark)
    ..setDashed(2)
    ..setFilter(
      2,
      brightness: preset.brightness,
      saturation: preset.saturation,
    );
}

// ─── Flow ───────────────────────────────────────────────────────────────────

void _flow(BeamFrame f) {
  final d = f.data;
  final dark = f.dark;
  final preset = presetFor(pulsePresets, dark: dark);
  final base = f.alpha * (f.mono ? 0.5 : 1);
  final pulse = _breathe(f, halo: false);
  final params = PulseParams.pulse(
    dark: dark,
    cycleSeconds: f.config.cycleSeconds,
  );
  // The pulse's colour field streams half a turn per cycle while it
  // breathes.
  final shift = (f.phases.reversedNow ? -1.0 : 1.0) * f.phases.cycles * 0.5;
  final rect = f.rect;
  final border = f.tables.border;

  void streamed(
    int k,
    BeamBlob b,
    double w,
    double h, {
    double alpha = 1,
    PulseRegion? region,
    PulseQuad? quad,
  }) {
    final at = f.at(b.position.dx, b.position.dy);
    final loc = f.outline.locate(at);
    // Which way the blob lies: along its edge, and across it.
    final vertical =
        math.min(b.position.dx, 1 - b.position.dx) * rect.width <
        math.min(b.position.dy, 1 - b.position.dy) * rect.height;
    var drift = Offset.zero;
    var stretch = const Offset(1, 1);
    var a = alpha;
    if (region != null && quad != null) {
      final r = region.index;
      drift = Offset(pulse.bx[r], pulse.by[r]);
      stretch = Offset(pulse.bw[r], pulse.bh[r] * pulse.bgh);
      a *= _quad(pulse, quad);
    }
    _onOutline(
      f,
      k,
      loc.u + shift,
      along: vertical ? h : w,
      inward: vertical ? w : h,
      depth: -loc.distance,
      color: b.color,
      alpha: a,
      drift: drift,
      stretch: stretch,
    );
  }

  d
    ..setLayer(
      0,
      BeamGeometry.fill,
      opacity: base * preset.innerOpacity * f.glowOpacity,
    )
    ..setEdgeFade(0, f.edgeFade);
  _filter(f, 0, preset, keepTone: true);
  for (final (i, b) in border.indexed) {
    final map = pulseRingMap[i % pulseRingMap.length];
    final size = pulseInnerSizes[i % pulseInnerSizes.length];
    streamed(
      0,
      b,
      size.width * f.glowSize,
      size.height * f.glowSize,
      region: map.region,
      quad: map.quad,
    );
  }

  d
    ..setLayer(1, BeamGeometry.ring, opacity: base * preset.strokeOpacity)
    ..setDashed(1);
  _filter(f, 1, preset, keepTone: true);
  for (final (i, b) in border.indexed) {
    final map = pulseRingMap[i % pulseRingMap.length];
    streamed(
      1,
      b,
      b.size.width,
      b.size.height,
      region: map.region,
      quad: map.quad,
    );
  }

  d.setLayer(
    2,
    BeamGeometry.blurredRing,
    opacity: base * preset.bloomOpacity * f.glowOpacity,
    sigma: pulseBloomBlur * f.glowSize,
  );
  _filter(f, 2, preset, keepTone: true);
  for (final spec in pulseInnerBloom) {
    final src = _borderAt(f.tables, spec.ci);
    streamed(2, src, spec.w, spec.h, alpha: params.frozenBloomAlpha);
  }
}

// ─── Shimmer ────────────────────────────────────────────────────────────────

const List<double> _flatStops = [0.0, 1.0];
const List<double> _glintAlphas = [0.5, 0.5];
const List<double> _fullAlphas = [1.0, 1.0];

void _shimmer(BeamFrame f, ShimmerEffect e) {
  final d = f.data;
  final dark = f.dark;
  final preset = presetFor(rotatePresets, dark: dark);
  final base = f.alpha * (f.mono ? 0.5 : 1);
  final r = f.rect;
  final a = e.angle * math.pi / 180;
  // The sweep's direction in pixels, carried into box-normalised space and
  // scaled so the band coordinate spans exactly 0–1 across the box: the
  // glint keeps its true angle on any aspect ratio.
  final px = math.cos(a) * r.width;
  final py = math.sin(a) * r.height;
  final norm = math.max(px.abs() + py.abs(), 1e-6);
  final dir = Offset(px / norm, py / norm);
  const half = 0.2;
  final pos = -half + (1 + 2 * half) * f.phases.travelProgress;

  d
    ..setTable(BeamTable.overlayA, _flatStops, _glintAlphas, 2)
    ..setTable(BeamTable.overlayB, _flatStops, _fullAlphas, 2);

  _ringInnerGlow(f);
  d.setLinearWindow(0, dir, pos, half * 1.2);

  d
    ..setLayer(
      1,
      BeamGeometry.ring,
      opacity: base * (dark ? _ringStrokeDark : _ringStrokeLight),
    )
    ..setLinearWindow(1, dir, pos, half)
    ..setDashed(1);
  if (dark) d.setOverlay(1, BeamTable.overlayA, white: true, above: true);
  _filter(f, 1, preset);
  _paletteRing(f, 1, count: 10, inward: 30);

  d
    ..setLayer(
      2,
      BeamGeometry.blurredRing,
      opacity: base * preset.bloomOpacity * 2 * f.glowOpacity,
      sigma: 6 * f.glowSize,
    )
    ..setLinearWindow(2, dir, pos, half * 0.45)
    ..setOverlay(2, BeamTable.overlayB, white: dark)
    ..setDashed(2);
}

// ─── Charge ─────────────────────────────────────────────────────────────────

// Behind the head, the filled border dims gently away from it.
const List<double> _chargeWindowStops = [0.0, 0.30, 0.58, 0.66, 0.70, 1.0];
const List<double> _chargeWindowAlphas = [0.5, 0.55, 0.85, 1.0, 0.5, 0.5];
const double _chargeHead = 0.66;

void _charge(BeamFrame f) {
  final d = f.data;
  final dark = f.dark;
  final preset = presetFor(rotatePresets, dark: dark);
  final base = f.alpha * (f.mono ? 0.5 : 1);
  final track = segmentTrack(d);
  final reversed = f.phases.reversedNow;
  final head = f.phases.travelProgress;
  final fill = reversed ? 1 - head : head;
  if (fill <= 0.001) return;
  final span = track.span * fill;
  final start = reversed ? track.start + track.span - span : track.start;
  final tip = reversed ? start : start + span;
  final userFeather = d.trackSpan > 0 ? d.trackFeather : 0.0;
  d.setTrack(
    start,
    span,
    math.max(math.min(4 / math.max(f.length, 1), span / 2), userFeather),
    f.config.dashes,
  );
  final sigma = rotateBloomBlur * f.glowSize;
  final tipAngle = conicFraction(f.outline.pointAt(tip), f.rect.center);
  final h = reversed ? 1 - _chargeHead : _chargeHead;

  _conicTable(
    d,
    BeamTable.windowA,
    _chargeWindowStops,
    _chargeWindowAlphas,
    reversed: reversed,
  );
  _conicTable(
    d,
    BeamTable.overlayA,
    rotateHighlightStops,
    dark ? rotateHighlightAlphasDark : rotateHighlightAlphasLight,
    reversed: reversed,
    tail: 0.7,
    shift: _chargeHead - 0.66,
  );
  _conicTable(
    d,
    BeamTable.overlayB,
    rotateBloomStops,
    dark ? rotateBloomAlphasDark : rotateBloomAlphasLight,
    reversed: reversed,
    shift: _chargeHead - rotateHeadStop,
    blur: sigma / math.max(f.length, 1),
  );
  d.setConic(f.rect.center, tipAngle - h, 1);

  _ringInnerGlow(f, head: _chargeHead, reversed: reversed, tail: 0.8);

  d
    ..setLayer(
      1,
      BeamGeometry.ring,
      opacity: base * (dark ? _ringStrokeDark : _ringStrokeLight),
    )
    ..setConicWindow(1, BeamTable.windowA)
    ..setOverlay(1, BeamTable.overlayA, white: dark, above: dark)
    ..setDashed(1);
  _filter(f, 1, preset);
  _paletteRing(f, 1, count: 10, inward: 30);

  d
    ..setLayer(
      2,
      BeamGeometry.blurredRing,
      opacity: base * preset.bloomOpacity * 1.6 * f.glowOpacity,
      sigma: sigma,
    )
    ..setOverlay(2, BeamTable.overlayB, white: dark)
    ..setDashed(2)
    ..setFilter(
      2,
      brightness: preset.brightness,
      saturation: preset.saturation,
    );
}
