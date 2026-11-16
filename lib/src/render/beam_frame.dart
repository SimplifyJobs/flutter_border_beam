import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'beam_outline.dart';

/// Floats in the shader's uniform block (`shaders/beam.frag`).
const int beamUniformFloats = _blobsC + blobSlotsC * 12;

/// Layers a frame composites, bottom to top.
const int beamLayerCount = 3;

/// Blob slots of layer 0.
const int blobSlotsA = 14;

/// Blob slots of layer 1.
const int blobSlotsB = 10;

/// Blob slots of layer 2.
const int blobSlotsC = 10;

/// Stops a conic table holds.
const int tableStops = 16;

// Float offsets of each uniform, in declaration order.
const int _rect = 0;
const int _radii = 4;
const int _shape = 8;
const int _perim = 12;
const int _quads = 16;
const int _mask = 20;
const int _conic = 24;
const int _layers = 28;
const int _layerFloats = 36;
const int _tables = _layers + beamLayerCount * _layerFloats;
const int _tableFloats = tableStops * 2;
const int _blobsA = _tables + 4 * _tableFloats;
const int _blobsB = _blobsA + blobSlotsA * 12;
const int _blobsC = _blobsB + blobSlotsB * 12;

const List<int> _blobBase = [_blobsA, _blobsB, _blobsC];
const List<int> _blobSlots = [blobSlotsA, blobSlotsB, blobSlotsC];

/// What part of the box a layer covers.
enum BeamGeometry {
  /// Nothing: the layer is off.
  none,

  /// The hairline ring just inside the outline.
  ring,

  /// The filled shape.
  fill,

  /// The ring blurred by the layer's sigma, clipped to the shape.
  blurredRing,

  /// Outside the outline, fading out: the shape grown by the layer's
  /// inflate and blurred by its sigma.
  glow,
}

/// How a layer's blobs are placed and shaded.
enum BeamBlobSpace {
  /// Planar ellipses with a piecewise-linear falloff.
  planar,

  /// Ellipses in path space: arc length along the outline × depth inward.
  path,

  /// Planar gaussians — blobs blurred by the layer's blob blur.
  blurred,

  /// Path-space gaussians.
  blurredPath,
}

/// Which window a layer is seen through.
enum BeamWindow {
  /// No window.
  none,

  /// Conic table A.
  conicA,

  /// Conic table B.
  conicB,

  /// A radial ellipse.
  radial,
}

/// The four conic tables.
enum BeamTable {
  /// Window table A.
  windowA,

  /// Window table B.
  windowB,

  /// Overlay table A.
  overlayA,

  /// Overlay table B.
  overlayB,
}

/// One frame's uniforms, written in place.
///
/// Reused frame after frame by its renderer, so writing a frame allocates
/// nothing. [reset] turns every layer off; effects then switch on and fill
/// the layers they draw.
final class BeamFrameData {
  /// The uniform floats, in the shader's order.
  final Float32List data = Float32List(beamUniformFloats);

  final List<int> _counts = [0, 0, 0];
  final List<Float64List> _fold = [
    Float64List(9),
    Float64List(9),
    Float64List(9),
  ];
  final List<bool> _folded = [false, false, false];
  final List<double> _brightness = [1, 1, 1];
  final List<double> _blobBlur = [0, 0, 0];
  final List<BeamBlobSpace> _space = [
    BeamBlobSpace.planar,
    BeamBlobSpace.planar,
    BeamBlobSpace.planar,
  ];

  /// How far light reaches outside the outline, in logical px.
  double reachOutside = 0;

  /// How far light reaches inside the outline, in logical px (infinity:
  /// across the whole box).
  double reachInside = 0;

  /// Turns every layer off and clears the tables and blobs.
  void reset() {
    data.fillRange(0, beamUniformFloats, 0);
    for (var k = 0; k < beamLayerCount; k++) {
      _counts[k] = 0;
      _blobBlur[k] = 0;
      _space[k] = BeamBlobSpace.planar;
      _folded[k] = false;
      _identity(k);
    }
    for (final t in BeamTable.values) {
      clearTable(t);
    }
    data[_conic + 3] = 1;
    reachOutside = 0;
    reachInside = 0;
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  /// Writes the outline, stroke width, and anti-aliasing width.
  void setOutline(BeamOutline o, double borderWidth, double px) {
    final r = o.rect;
    _v4(_rect, r.left, r.top, r.width, r.height);
    _v4(_radii, o.radii[0], o.radii[1], o.radii[2], o.radii[3]);
    _v4(_shape, o.superellipse ? 1 : 0, 0, borderWidth, px);
    _v4(_perim, o.length, 0, 1, 0);
    _v4(
      _quads,
      o.quadStarts[0],
      o.quadStarts[1],
      o.quadStarts[2],
      o.quadStarts[3],
    );
  }

  /// The visible track: start and span in `u` (span 0 = all of it), the
  /// feather at its ends, and the dash count.
  void setTrack(double start, double span, double feather, int dashes) =>
      _v4(_mask, start, span, feather, dashes.toDouble());

  /// The visible track's start (`u`).
  double get trackStart => data[_mask];

  /// The visible track's span (`u`; 0 = the whole border).
  double get trackSpan => data[_mask + 1];

  /// The visible track's end feather (`u`).
  double get trackFeather => data[_mask + 2];

  /// The conic coordinate: its [centre], the angle its tables start at (in
  /// turns, clockwise from 12 o'clock), and how many times they repeat
  /// around the turn.
  void setConic(Offset centre, double start, int repeats) => _v4(
    _conic,
    centre.dx,
    centre.dy,
    start - start.floorToDouble(),
    math.max(repeats, 1).toDouble(),
  );

  /// Switches off the dither on the soft tails.
  void disableDither() => data[_perim + 2] = 0;

  /// The outline box.
  Rect get outlineRect => Rect.fromLTWH(
    data[_rect],
    data[_rect + 1],
    data[_rect + 2],
    data[_rect + 3],
  );

  /// The conic coordinate's centre.
  Offset get conicCentre => Offset(data[_conic], data[_conic + 1]);

  /// The angle the conic tables start at, in turns.
  double get conicStart => data[_conic + 2];

  /// How many times the conic tables repeat around the turn.
  int get conicRepeats => data[_conic + 3].round();

  // ─── Tables ──────────────────────────────────────────────────────────────

  /// Marks [table] unused (it costs the shader one comparison).
  void clearTable(BeamTable table) {
    final base = _tables + table.index * _tableFloats;
    for (var i = 0; i < tableStops; i++) {
      data[base + 2 * i] = 2;
      data[base + 2 * i + 1] = 0;
    }
  }

  /// Writes [table] from the first [count] of parallel [stops] (ascending,
  /// 0–1) and [alphas]. At most [tableStops] stops; the rest pad with the
  /// last one.
  void setTable(
    BeamTable table,
    List<double> stops,
    List<double> alphas,
    int count,
  ) {
    final base = _tables + table.index * _tableFloats;
    final n = math.min(count, tableStops);
    for (var i = 0; i < tableStops; i++) {
      final j = i < n ? i : n - 1;
      data[base + 2 * i] = i < n ? stops[j] : math.max(stops[j], 1);
      data[base + 2 * i + 1] = alphas[j].clamp(0.0, 1.0);
    }
  }

  /// The [i]th stop position of [table] (unused tables report 2).
  double tableStop(BeamTable table, int i) =>
      data[_tables + table.index * _tableFloats + 2 * i];

  /// Whether [table] is in use.
  bool tableUsed(BeamTable table) =>
      data[_tables + table.index * _tableFloats] <= 1;

  /// The alpha of [table] at [t], as the shader reads it.
  double tableAt(BeamTable table, double t) {
    final base = _tables + table.index * _tableFloats;
    var pp = data[base];
    var pa = data[base + 1];
    if (t <= pp || pp > 1) return pa;
    for (var i = 0; i < tableStops; i++) {
      final s = data[base + 2 * i];
      final a = data[base + 2 * i + 1];
      if (t <= s) {
        final span = math.max(s - pp, 1e-5);
        return pa + (a - pa) * ((t - pp) / span).clamp(0.0, 1.0);
      }
      pp = s;
      pa = a;
    }
    return data[base + 2 * tableStops - 1];
  }

  // ─── Layers ──────────────────────────────────────────────────────────────

  int _h(int k, int row) => _layers + k * _layerFloats + row * 4;

  /// Switches layer [k] on with [geometry] and [opacity] (clamped to 0–1
  /// when painted). [sigma] blurs the blurred geometries; [inflate] grows a
  /// glow's shape.
  void setLayer(
    int k,
    BeamGeometry geometry, {
    required double opacity,
    double sigma = 0,
    double inflate = 0,
  }) {
    _v4(
      _h(k, 0),
      geometry.index.toDouble(),
      sigma,
      inflate,
      opacity.clamp(0.0, 1.0),
    );
  }

  /// Layer [k]'s geometry.
  BeamGeometry geometryOf(int k) => BeamGeometry.values[data[_h(k, 0)].round()];

  /// Layer [k]'s opacity.
  double opacityOf(int k) => data[_h(k, 0) + 3];

  /// Layer [k]'s blur sigma.
  double sigmaOf(int k) => data[_h(k, 0) + 1];

  /// Layer [k]'s inflate.
  double inflateOf(int k) => data[_h(k, 0) + 2];

  /// Multiplies layer [k]'s opacity by [factor].
  void scaleOpacity(int k, double factor) {
    final i = _h(k, 0) + 3;
    data[i] = (data[i] * factor).clamp(0.0, 1.0);
  }

  /// Fades layer [k] out [px] in from the edge.
  void setEdgeFade(int k, double px) => data[_h(k, 1)] = px;

  /// Layer [k]'s edge fade, px (0 = none).
  double edgeFadeOf(int k) => data[_h(k, 1)];

  /// Shows layer [k] through a conic window table.
  void setConicWindow(int k, BeamTable table) {
    assert(table == BeamTable.windowA || table == BeamTable.windowB);
    data[_h(k, 1) + 1] = table == BeamTable.windowA
        ? BeamWindow.conicA.index.toDouble()
        : BeamWindow.conicB.index.toDouble();
  }

  /// Shows layer [k] through a radial ellipse at [centre] with radii [rx] ×
  /// [ry]: 1 at the centre, [midAlpha] at [midStop], 0 at the rim. In path
  /// space the centre is (arc length, depth) and the radii (along, inward).
  void setRadialWindow(
    int k,
    Offset centre,
    double rx,
    double ry, {
    required double midStop,
    required double midAlpha,
  }) {
    data[_h(k, 1) + 1] = BeamWindow.radial.index.toDouble();
    _v4(_h(k, 2), centre.dx, centre.dy, rx, ry);
    data[_h(k, 3)] = midStop;
    data[_h(k, 3) + 1] = midAlpha;
  }

  /// Layer [k]'s window.
  BeamWindow windowOf(int k) => BeamWindow.values[data[_h(k, 1) + 1].round()];

  /// Layer [k]'s window parameters (see [setRadialWindow]).
  List<double> windowParamsOf(int k) => [
    for (var i = 0; i < 4; i++) data[_h(k, 2) + i],
  ];

  /// Lays an overlay table under layer [k]'s blobs, in white or black.
  void setOverlay(int k, BeamTable table, {required bool white}) {
    assert(table == BeamTable.overlayA || table == BeamTable.overlayB);
    data[_h(k, 1) + 2] = table == BeamTable.overlayA ? 1 : 2;
    data[_h(k, 1) + 3] = white ? 1 : 0;
  }

  /// How layer [k]'s blobs are placed; [blur] (px) blurs them in the
  /// blurred spaces. Set before adding blobs.
  void setBlobSpace(int k, BeamBlobSpace space, {double blur = 0}) {
    _space[k] = space;
    _blobBlur[k] = blur;
    data[_h(k, 3) + 2] = space.index.toDouble();
  }

  /// Layer [k]'s blob space.
  BeamBlobSpace blobSpaceOf(int k) => _space[k];

  /// Layer [k]'s blob blur, px (see [setBlobSpace]).
  double blobBlurOf(int k) => _blobBlur[k];

  /// An inset shadow on layer [k]: [color], solid to [depth] px in, blurred
  /// by [sigma].
  void setShadow(
    int k,
    Color color, {
    required double depth,
    required double sigma,
  }) {
    _v4(_h(k, 4), color.r, color.g, color.b, color.a);
    data[_h(k, 5)] = depth;
    data[_h(k, 5) + 1] = sigma;
  }

  /// Cuts layer [k] into the configured dashes.
  void setDashed(int k) => data[_h(k, 5) + 2] = 1;

  /// Layer [k]'s colour filter: CSS `hue-rotate(hue) brightness(b)
  /// saturate(s)`, applied left to right.
  ///
  /// By default the filter is folded into each colour of the layer — every
  /// blob, the overlay ink, and the shadow — before they are composited,
  /// which keeps overlapping colours saturated (call [finish] once the layer
  /// is written). With [fold] false the shader filters the composited layer
  /// instead.
  void setFilter(
    int k, {
    double hue = 0,
    double brightness = 1,
    double saturation = 1,
    bool fold = true,
  }) {
    final rad = hue * math.pi / 180;
    final c = math.cos(rad);
    final s = math.sin(rad);
    // Hue rotation (Filter Effects feColorMatrix), scaled by brightness.
    final h00 = (0.213 + c * 0.787 - s * 0.213) * brightness;
    final h01 = (0.715 - c * 0.715 - s * 0.715) * brightness;
    final h02 = (0.072 - c * 0.072 + s * 0.928) * brightness;
    final h10 = (0.213 - c * 0.213 + s * 0.143) * brightness;
    final h11 = (0.715 + c * 0.285 + s * 0.140) * brightness;
    final h12 = (0.072 - c * 0.072 - s * 0.283) * brightness;
    final h20 = (0.213 - c * 0.213 - s * 0.787) * brightness;
    final h21 = (0.715 - c * 0.715 + s * 0.715) * brightness;
    final h22 = (0.072 + c * 0.928 + s * 0.072) * brightness;
    final t = saturation;
    final s00 = 0.213 + 0.787 * t;
    final s01 = 0.715 - 0.715 * t;
    final s02 = 0.072 - 0.072 * t;
    final s10 = 0.213 - 0.213 * t;
    final s11 = 0.715 + 0.285 * t;
    final s12 = 0.072 - 0.072 * t;
    final s20 = 0.213 - 0.213 * t;
    final s21 = 0.715 - 0.715 * t;
    final s22 = 0.072 + 0.928 * t;
    final m = _fold[k];
    m[0] = s00 * h00 + s01 * h10 + s02 * h20;
    m[1] = s00 * h01 + s01 * h11 + s02 * h21;
    m[2] = s00 * h02 + s01 * h12 + s02 * h22;
    m[3] = s10 * h00 + s11 * h10 + s12 * h20;
    m[4] = s10 * h01 + s11 * h11 + s12 * h21;
    m[5] = s10 * h02 + s11 * h12 + s12 * h22;
    m[6] = s20 * h00 + s21 * h10 + s22 * h20;
    m[7] = s20 * h01 + s21 * h11 + s22 * h21;
    m[8] = s20 * h02 + s21 * h12 + s22 * h22;
    _brightness[k] = brightness;
    if (fold) {
      _folded[k] = true;
      _identity(k);
    } else {
      _folded[k] = false;
      _v4(_h(k, 6), m[0], m[1], m[2], 0);
      _v4(_h(k, 7), m[3], m[4], m[5], 0);
      _v4(_h(k, 8), m[6], m[7], m[8], 0);
    }
  }

  /// Folds each layer's filter into its colours (see [setFilter]).
  void finish() {
    for (var k = 0; k < beamLayerCount; k++) {
      if (!_folded[k]) continue;
      _folded[k] = false;
      final base = _blobBase[k];
      for (var i = 0; i < _counts[k]; i++) {
        _foldAt(k, base + i * 12 + 4);
      }
      _foldAt(k, _h(k, 4));
      final ink = _h(k, 1) + 3;
      data[ink] = (data[ink] * _brightness[k]).clamp(0.0, 1.0);
    }
  }

  void _foldAt(int k, int i) {
    final m = _fold[k];
    final r = data[i];
    final g = data[i + 1];
    final b = data[i + 2];
    data[i] = (m[0] * r + m[1] * g + m[2] * b).clamp(0.0, 1.0);
    data[i + 1] = (m[3] * r + m[4] * g + m[5] * b).clamp(0.0, 1.0);
    data[i + 2] = (m[6] * r + m[7] * g + m[8] * b).clamp(0.0, 1.0);
  }

  void _identity(int k) {
    _v4(_h(k, 6), 1, 0, 0, 0);
    _v4(_h(k, 7), 0, 1, 0, 0);
    _v4(_h(k, 8), 0, 0, 1, 0);
  }

  // ─── Blobs ───────────────────────────────────────────────────────────────

  /// Blobs in layer [k].
  int blobCount(int k) => _counts[k];

  /// Layer [k]'s [i]th blob as the shader reads it: centre, radii (sigmas
  /// for a blurred blob), straight colour, and peak alpha.
  ({
    double cx,
    double cy,
    double rx,
    double ry,
    double r,
    double g,
    double b,
    double alpha,
  })
  blob(int k, int i) {
    final o = _blobBase[k] + i * 12;
    return (
      cx: data[o],
      cy: data[o + 1],
      rx: data[o + 2],
      ry: data[o + 3],
      r: data[o + 4],
      g: data[o + 5],
      b: data[o + 6],
      alpha: data[o + 7],
    );
  }

  /// Layer [k]'s overlay table, or null for none.
  BeamTable? overlayOf(int k) => switch (data[_h(k, 1) + 2].round()) {
    1 => BeamTable.overlayA,
    2 => BeamTable.overlayB,
    _ => null,
  };

  /// Whether layer [k]'s shadow is set.
  bool hasShadow(int k) => data[_h(k, 4) + 3] > 0;

  /// Whether layer [k] is cut into dashes.
  bool isDashed(int k) => data[_h(k, 5) + 2] > 0;

  /// Adds a blob to layer [k], in painting order: each blob is drawn over
  /// the ones added before it.
  ///
  /// The blob is an ellipse of radii [rx] × [ry] centred at [cx], [cy] (in
  /// path space: arc length and depth), coloured [rgb], with alpha [a0] at
  /// the centre falling through [a1] at [p1] and [a2] at [p2] to 0 at [p3]
  /// (fractions of the radii). Ignored once the layer's slots are used.
  ///
  /// In the blurred spaces, [clip] cuts the blob along a line before
  /// it is blurred, keeping the side where the coordinate on `axis` (0 = x,
  /// 1 = y) is below `at` (`keepBelow`) or above it.
  void addBlob(
    int k, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required Color rgb,
    required double a0,
    required double p1,
    required double a1,
    required double p2,
    required double a2,
    double p3 = 1,
    ({int axis, double at, bool keepBelow})? clip,
  }) {
    if (_counts[k] >= _blobSlots[k] || a0 <= 0 && a1 <= 0 && a2 <= 0) return;
    final end = p3 <= 0 ? 1e-3 : p3;
    var x = cx;
    var y = cy;
    var sx = math.max(rx * end, 1e-3);
    var sy = math.max(ry * end, 1e-3);
    var q1 = (p1 / end).clamp(0.0, 1.0);
    var q2 = (p2 / end).clamp(q1, 1.0);
    var peak = a0;
    if (_space[k] == BeamBlobSpace.blurred ||
        _space[k] == BeamBlobSpace.blurredPath) {
      // The energy-preserving gaussian of the blob blurred by the layer's
      // blob blur: the profile's mass and variance, plus the blur's.
      final m0 = _moment(1, a0, q1, a1, q2, a2);
      final m2 = _moment(3, a0, q1, a1, q2, a2);
      if (m0 <= 0) return;
      final spread = math.sqrt(m2 / (2 * m0));
      var gx = sx * spread;
      var gy = sy * spread;
      var mass = m0 * sx * sy;
      if (clip != null) {
        // Cut along the line: the kept part's mass, mean, and variance
        // across it (a truncated normal).
        final s = clip.axis == 0 ? gx : gy;
        final c = clip.axis == 0 ? x : y;
        final inside = clip.keepBelow ? clip.at - c : c - clip.at;
        final a = -inside / s;
        final kept = _cdf(inside / s);
        if (kept <= 1e-4) return;
        final lambda = _pdf(a) / kept;
        final shift = s * lambda;
        final spreadAcross =
            s * math.sqrt(math.max(1 + a * lambda - lambda * lambda, 1e-4));
        mass *= kept;
        if (clip.axis == 0) {
          x += clip.keepBelow ? -shift : shift;
          gx = spreadAcross;
        } else {
          y += clip.keepBelow ? -shift : shift;
          gy = spreadAcross;
        }
      }
      final blur = _blobBlur[k];
      final bx = math.sqrt(gx * gx + blur * blur);
      final by = math.sqrt(gy * gy + blur * blur);
      peak = math.min(mass / (bx * by), math.max(a0, math.max(a1, a2)));
      sx = bx;
      sy = by;
      q1 = 0;
      q2 = 0;
    }
    final base = _blobBase[k] + _counts[k] * 12;
    _v4(base, x, y, sx, sy);
    _v4(base + 4, rgb.r, rgb.g, rgb.b, peak);
    _v4(base + 8, q1, a1, q2, a2);
    _counts[k]++;
    data[_h(k, 3) + 3] = _counts[k].toDouble();
  }

  // The standard normal density and distribution.
  static double _pdf(double z) => 0.3989422804 * math.exp(-0.5 * z * z);

  static double _cdf(double z) {
    // Abramowitz & Stegun 7.1.26 (|error| < 1.5e-7).
    final x = z.abs() / math.sqrt2;
    final t = 1 / (1 + 0.3275911 * x);
    final y =
        1 -
        ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t -
                        0.284496736) *
                    t +
                0.254829592) *
            t *
            math.exp(-x * x);
    return z >= 0 ? 0.5 * (1 + y) : 0.5 * (1 - y);
  }

  /// Adds a CSS `color → transparent` blob: alpha falls linearly from the
  /// colour's own alpha times [alpha] at the centre to 0 at the rim.
  void addSimpleBlob(
    int k, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required Color color,
    double alpha = 1,
    double end = 1,
    ({int axis, double at, bool keepBelow})? clip,
  }) {
    final a = color.a * alpha;
    addBlob(
      k,
      cx: cx,
      cy: cy,
      rx: rx,
      ry: ry,
      rgb: color,
      a0: a,
      p1: end / 3,
      a1: a * 2 / 3,
      p2: end * 2 / 3,
      a2: a / 3,
      p3: end,
      clip: clip,
    );
  }

  // ∫ f(t) t^n dt over the piecewise-linear profile 0:a0 → q1:a1 → q2:a2 →
  // 1:0.
  static double _moment(
    int n,
    double a0,
    double q1,
    double a1,
    double q2,
    double a2,
  ) {
    double seg(double t0, double f0, double t1, double f1) {
      if (t1 <= t0) return 0;
      final beta = (f1 - f0) / (t1 - t0);
      final alpha = f0 - beta * t0;
      double pw(double t, int e) => math.pow(t, e).toDouble();
      return alpha * (pw(t1, n + 1) - pw(t0, n + 1)) / (n + 1) +
          beta * (pw(t1, n + 2) - pw(t0, n + 2)) / (n + 2);
    }

    return seg(0, a0, q1, a1) + seg(q1, a1, q2, a2) + seg(q2, a2, 1, 0);
  }

  void _v4(int i, double a, double b, double c, double d) {
    data[i] = a;
    data[i + 1] = b;
    data[i + 2] = c;
    data[i + 3] = d;
  }
}
