import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show BorderRadius;

import '../../animation/beam_phases.dart';
import '../../constants/line_geometry.dart';
import '../../constants/line_keyframes.dart';
import '../../models/beam_blob.dart';
import '../../models/beam_config.dart';
import '../../models/beam_options.dart';
import '../../models/beam_segment.dart';
import '../color_matrix.dart';
import '../gradient_builders.dart';
import '../layer_utils.dart';
import '../ring_geometry.dart';
import '../variant_strategy.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

// How far a traveller's band runs past the box, before and after the edge it
// rides: far enough that nothing a blob or a blur reaches is ever cut, while
// the bands still partition the edge between the travellers.
const double _bandOverhang = 10000;

// The sparkle scatter's radius around a traveller, and how finely its
// position is quantised into the twinkle seed.
const double _sparkleSpread = 16;
const int _sparkleSeedSteps = 24;

/// One traveller's frame: where it sits along the edge, its width factor, the
/// edge fade it carries, and the slice of the edge it owns.
///
/// [band] is null for a lone beam — the ordinary case paints exactly as it
/// always has, with no clip and no radius clamp.
typedef _Traveller = ({
  double x,
  double w,
  double fade,
  Rect? band,
  double? fraction,
  Path? pathBand,
});

/// The perimeter slice a path-mode frame is painted over: the geometry, the
/// clockwise range, and whether travel runs against that range.
///
/// [mirrored] is set for the edge-derived range `wrapCorners` builds, where
/// the beam must keep the planar variant's direction (see [_paintPathAbove]).
typedef _PathContext = ({
  BeamRingGeometry geometry,
  double from,
  double span,
  bool mirrored,
});

/// The edge-riding traveling beam (React `line`): all masks are radial
/// windows anchored at the traveling position on the edge, plus a bloom of
/// fixed spikes that shimmer via two counter-phased scale tracks.
///
/// The geometry is authored for the bottom edge; every other edge is that
/// painting turned about the box's centre, so the transcribed numbers are
/// never touched.
class LineStrategy extends BeamVariantStrategy {
  /// Const constructor.
  const LineStrategy();

  @override
  void paintAbove(
    Canvas canvas,
    Size size,
    BeamConfig config,
    BeamFramePhases phases,
  ) {
    if (phases.fadeOpacity <= 0) return;

    final pathMode = config.segment != null || config.wrapCorners;
    if (pathMode) {
      _paintPathAbove(canvas, size, config, phases);
      return;
    }

    // The rotations run counter-clockwise around the box, so a beam that
    // rides the bottom edge left-to-right rides the right edge
    // bottom-to-top.
    canvas.save();
    final authored = _applyEdgeTransform(canvas, size, config.edge);
    final rect = beamRect(authored, config);
    final geometry = BeamRingGeometry(
      rect: rect,
      radius: _rotateRadii(config.borderRadius, config.edge),
      borderWidth: config.borderWidth,
      useSuperellipse: config.useSuperellipse,
      contour: config.contour,
    );
    final isDark = config.brightness == Brightness.dark;
    final beams = _travellers(rect, phases);
    // A group's opacity carries the brightest traveller's edge fade; each
    // traveller then scales its own colours by the rest of it. The bands are
    // disjoint, so scaling per band is exact rather than an approximation.
    var fadeMax = 0.0;
    for (final beam in beams) {
      fadeMax = math.max(fadeMax, beam.fade);
    }
    if (fadeMax <= 0) {
      canvas.restore();
      return;
    }

    final layerMatrix = config.staticColors
        ? null
        : BeamColorMatrix.beamFilter(
            hueDegrees: phases.hueDegrees + config.hueBase,
            brightness: config.brightnessFactor,
            saturation: config.saturation,
          );
    Color fold(Color c) => layerMatrix?.transform(c) ?? c;

    _paintInner(canvas, rect, geometry, config, phases, fold, beams, fadeMax);
    _paintStroke(
      canvas,
      rect,
      geometry,
      config,
      phases,
      fold,
      isDark,
      beams,
      fadeMax,
    );
    _paintBloom(canvas, rect, geometry, config, phases, isDark, beams, fadeMax);
    canvas.restore();
  }

  // A configured segment owns line travel, so [BeamConfig.edge] is ignored:
  // the beam runs the segment's own clockwise start → end.
  //
  // With wrapCorners alone the selected edge resolves to its straight run plus
  // both adjacent corner arcs, and feeds the same path-space code with one
  // rule attached: wrapCorners is a modifier on the ordinary line variant, so
  // turning it on must not reverse the animation. The planar painting is
  // authored on the bottom edge running left to right, and every other edge is
  // that painting turned rigidly about the box's centre — which leaves travel
  // running counter-clockwise around the box on all four edges (bottom left to
  // right, top right to left, left top to bottom, right bottom to top), the
  // opposite of the perimeter's clockwise parameterisation. An edge-derived
  // range therefore carries `mirrored`, and every progress, spike fraction and
  // blob offset goes through [_pathFraction] to flip. `BeamDirection` is
  // already folded into `phases.travellers` and composes on top of this.
  void _paintPathAbove(
    Canvas canvas,
    Size size,
    BeamConfig config,
    BeamFramePhases phases,
  ) {
    final rect = beamRect(size, config);
    final segment = config.segment ?? _edgeSegment(config.edge);
    final geometry = config.segment != null
        ? beamGeometry(rect, config)
        : BeamRingGeometry(
            rect: rect,
            radius: config.borderRadius,
            borderWidth: config.borderWidth,
            useSuperellipse: config.useSuperellipse,
            contour: config.contour,
            segment: segment,
          );
    final range = geometry.segmentRange!;
    final span = _clockwiseSpan(range.from, range.to);
    final path = (
      geometry: geometry,
      from: range.from,
      span: span,
      mirrored: config.segment == null,
    );
    final isDark = config.brightness == Brightness.dark;
    final beams = _pathTravellers(path, phases);
    var fadeMax = 0.0;
    for (final beam in beams) {
      fadeMax = math.max(fadeMax, beam.fade);
    }
    if (fadeMax <= 0) return;

    final layerMatrix = config.staticColors
        ? null
        : BeamColorMatrix.beamFilter(
            hueDegrees: phases.hueDegrees + config.hueBase,
            brightness: config.brightnessFactor,
            saturation: config.saturation,
          );
    Color fold(Color c) => layerMatrix?.transform(c) ?? c;

    _paintInner(
      canvas,
      rect,
      geometry,
      config,
      phases,
      fold,
      beams,
      fadeMax,
      path: path,
    );
    _paintStroke(
      canvas,
      rect,
      geometry,
      config,
      phases,
      fold,
      isDark,
      beams,
      fadeMax,
      path: path,
    );
    _paintBloom(
      canvas,
      rect,
      geometry,
      config,
      phases,
      isDark,
      beams,
      fadeMax,
      path: path,
    );
  }

  // ─── Travel ─────────────────────────────────────────────────────────────

  // Resolves every beam travelling the edge this frame. With one beam the
  // keyframe values already on the phases are used as they are; with several,
  // each traveller samples the same tracks at its own progress and takes the
  // slice of the edge reaching halfway to each neighbour — disjoint bands are
  // what let several radial masks union inside one layer, since a `dstIn`
  // draw multiplies and would otherwise erase its neighbours.
  List<_Traveller> _travellers(Rect rect, BeamFramePhases phases) {
    final progress = phases.travellers;
    if (progress.length <= 1) {
      return [
        (
          x: phases.lineX,
          w: phases.lineW,
          fade: phases.edge,
          band: null,
          fraction: null,
          pathBand: null,
        ),
      ];
    }
    final sorted = [...progress]
      ..sort(
        (a, b) => sampleKeyframes(
          lineTravelX,
          a,
        ).compareTo(sampleKeyframes(lineTravelX, b)),
      );
    final xs = [for (final p in sorted) sampleKeyframes(lineTravelX, p)];
    final result = <_Traveller>[];
    for (var i = 0; i < sorted.length; i++) {
      final centre = rect.left + xs[i] * rect.width;
      final left = i == 0
          ? rect.left - _bandOverhang
          : (centre + rect.left + xs[i - 1] * rect.width) / 2;
      final right = i == sorted.length - 1
          ? rect.right + _bandOverhang
          : (centre + rect.left + xs[i + 1] * rect.width) / 2;
      result.add((
        x: xs[i],
        w: sampleKeyframes(lineTravelW, sorted[i]),
        fade: sampleKeyframes(lineEdgeFade, sorted[i]),
        band: Rect.fromLTRB(
          left,
          rect.top - _bandOverhang,
          right,
          rect.bottom + _bandOverhang,
        ),
        fraction: null,
        pathBand: null,
      ));
    }
    return result;
  }

  List<_Traveller> _pathTravellers(_PathContext path, BeamFramePhases phases) {
    final sorted = [...phases.travellers]..sort();
    return [
      for (var i = 0; i < sorted.length; i++)
        (
          x: sampleKeyframes(lineTravelX, sorted[i]),
          w: sampleKeyframes(lineTravelW, sorted[i]),
          fade: sampleKeyframes(lineEdgeFade, sorted[i]),
          band: null,
          fraction: _pathFraction(path, sorted[i]),
          pathBand: sorted.length == 1
              ? null
              : _pathBand(
                  path,
                  // The halfway points to each neighbour in travel order. A
                  // mirrored range reverses them on the perimeter, so the
                  // clockwise band runs from the later progress to the
                  // earlier one.
                  lower: i == 0 ? 0 : (sorted[i - 1] + sorted[i]) / 2,
                  upper: i == sorted.length - 1
                      ? 1
                      : (sorted[i] + sorted[i + 1]) / 2,
                ),
        ),
    ];
  }

  Path _pathBand(
    _PathContext path, {
    required double lower,
    required double upper,
  }) => path.geometry.perimeter.band(
    from: _pathFraction(path, path.mirrored ? upper : lower),
    to: _pathFraction(path, path.mirrored ? lower : upper),
    inward: _bandOverhang,
    outward: _bandOverhang,
  );

  Offset _anchor(
    Rect rect,
    _Traveller beam, {
    double dy = 0,
    _PathContext? path,
  }) => path == null
      ? Offset(rect.left + beam.x * rect.width, rect.bottom + dy)
      : path.geometry.perimeter.offsetPointAt(beam.fraction!, -dy);

  Offset _blobAnchor(
    Rect rect,
    _Traveller beam, {
    required double offsetX,
    required double inward,
    _PathContext? path,
  }) => path == null
      ? Offset(rect.left + beam.x * rect.width + offsetX, rect.bottom - inward)
      : path.geometry.perimeter.offsetPointAt(
          // A blob's offsetX runs along the direction of travel, which is
          // against the clockwise parameterisation on a mirrored range.
          beam.fraction! +
              (path.geometry.perimeter.length <= 0
                  ? 0
                  : (path.mirrored ? -offsetX : offsetX) /
                        path.geometry.perimeter.length),
          inward,
        );

  double _rotation(_Traveller beam, _PathContext? path) {
    if (path == null) return 0;
    final tangent = path.geometry.perimeter.tangentAt(beam.fraction!);
    return math.atan2(tangent.dy, tangent.dx);
  }

  // The widest a traveller's mask may reach without spilling into a
  // neighbour's band, where the clip would cut it while it is still opaque.
  double _maskRadiusX(Rect rect, _Traveller beam, double wanted) {
    final band = beam.band;
    if (band == null) return wanted;
    final centre = rect.left + beam.x * rect.width;
    return math.min(wanted, math.min(centre - band.left, band.right - centre));
  }

  // Runs [paint] for one traveller, inside its own slice of the edge.
  void _forEachTraveller(
    Canvas canvas,
    List<_Traveller> beams,
    void Function(_Traveller beam) paint,
  ) {
    for (final beam in beams) {
      final band = beam.band;
      final pathBand = beam.pathBand;
      if (band == null && pathBand == null) {
        paint(beam);
        continue;
      }
      canvas.save();
      if (band != null) canvas.clipRect(band);
      if (pathBand != null) canvas.clipPath(pathBand);
      paint(beam);
      canvas.restore();
    }
  }

  // ─── Layers ─────────────────────────────────────────────────────────────

  void _paintInner(
    Canvas canvas,
    Rect rect,
    BeamRingGeometry geometry,
    BeamConfig config,
    BeamFramePhases phases,
    Color Function(Color) fold,
    List<_Traveller> beams,
    double fadeMax, {
    _PathContext? path,
  }) {
    // The line variant does not apply the mono ×0.5 multiplier — its mono
    // treatment lives in the bloom spike attenuation.
    final opacity =
        (phases.fadeOpacity *
                fadeMax *
                config.theme.innerOpacity *
                config.innerOpacityFactor *
                config.strength)
            .clamp(0.0, 1.0);
    if (opacity <= 0) return;

    canvas.save();
    canvas.clipPath(geometry.outer);
    BeamLayerUtils.clipSegment(
      canvas,
      geometry,
      inward: rect.shortestSide / 2,
      outward: 0,
    );
    canvas.saveLayer(rect, Paint()..color = _white.withValues(alpha: opacity));

    _forEachTraveller(canvas, beams, (beam) {
      final tint = _tint(fold, beam, fadeMax);
      for (final blob in config.palette.data.lineInner) {
        BeamGradients.paintBlob(
          canvas,
          center: _blobAnchor(
            rect,
            beam,
            offsetX: blob.offsetX,
            inward: blob.offsetY.abs(),
            path: path,
          ),
          radiusX: blob.sizeW * beam.w,
          radiusY: blob.sizeH * phases.lineH,
          color: tint(blob.color),
          rotation: _rotation(beam, path),
        );
      }
    });
    BeamLayerUtils.paintInnerShadow(
      canvas,
      contour: geometry.outer,
      color: fold(config.theme.innerShadow),
      blur: lineInnerShadowBlur,
    );

    // Mask: (featherV ∪ featherH) ∩ the union of the travellers' windows.
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);
    canvas.drawRect(
      rect,
      Paint()..shader = BeamGradients.verticalEdgeFeather(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = BeamGradients.horizontalEdgeFeather(rect),
    );
    _forEachTraveller(canvas, beams, (beam) {
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _window(rect, beam, phases, path: path),
      );
    });
    canvas.restore();

    BeamLayerUtils.applySegmentFeather(canvas, rect, geometry);

    canvas.restore();
    canvas.restore();
  }

  void _paintStroke(
    Canvas canvas,
    Rect rect,
    BeamRingGeometry geometry,
    BeamConfig config,
    BeamFramePhases phases,
    Color Function(Color) fold,
    bool isDark,
    List<_Traveller> beams,
    double fadeMax, {
    _PathContext? path,
  }) {
    final opacity =
        (phases.fadeOpacity *
                fadeMax *
                config.theme.strokeOpacity *
                config.strokeOpacityFactor *
                config.strength)
            .clamp(0.0, 1.0);
    if (opacity <= 0) return;

    canvas.save();
    canvas.clipPath(geometry.ring);
    BeamLayerUtils.clipSegment(canvas, geometry, inward: 0, outward: 0);
    canvas.saveLayer(rect, Paint()..color = _white.withValues(alpha: opacity));

    _forEachTraveller(canvas, beams, (beam) {
      final tint = _tint(fold, beam, fadeMax);
      // White (dark) / black (light) traveling highlight.
      final base = isDark ? _white : _black;
      final alphas = isDark
          ? lineHighlightAlphasDark
          : lineHighlightAlphasLight;
      BeamLayerUtils.paintRadial(
        canvas,
        center: _anchor(rect, beam, dy: lineHighlightOffsetY, path: path),
        radiusX:
            (isDark ? lineHighlightRadiusXDark : lineHighlightRadiusXLight) *
            beam.w,
        radiusY:
            (isDark ? lineHighlightRadiusYDark : lineHighlightRadiusYLight) *
            phases.lineH,
        colors: [for (final a in alphas) tint(base.withValues(alpha: a))],
        stops: isDark ? lineHighlightStopsDark : lineHighlightStopsLight,
        rotation: _rotation(beam, path),
      );
      final blobs = isDark
          ? config.palette.data.lineDark
          : config.palette.data.lineLight;
      for (final blob in blobs) {
        BeamGradients.paintBlob(
          canvas,
          center: _blobAnchor(
            rect,
            beam,
            offsetX: blob.offsetX,
            inward: -blob.offsetY,
            path: path,
          ),
          radiusX: blob.sizeW * beam.w,
          radiusY: blob.sizeH * phases.lineH,
          color: tint(blob.color),
          rotation: _rotation(beam, path),
        );
      }
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _window(rect, beam, phases, path: path),
      );
    });

    BeamLayerUtils.applySegmentFeather(canvas, rect, geometry);

    canvas.restore();
    canvas.restore();

    _paintSparkles(canvas, rect, config, beams, opacity, isDark, path: path);
  }

  void _paintBloom(
    Canvas canvas,
    Rect rect,
    BeamRingGeometry geometry,
    BeamConfig config,
    BeamFramePhases phases,
    bool isDark,
    List<_Traveller> beams,
    double fadeMax, {
    _PathContext? path,
  }) {
    final opacity =
        (phases.fadeOpacity *
                fadeMax *
                config.theme.bloomOpacity *
                config.bloomOpacityFactor *
                config.strength)
            .clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final mono = config.palette.monoTreatment;
    // Bloom filter: blur(8) + hue(range+10) when animating; blur(6) for
    // mono; no filter when static non-mono (matching the generated CSS).
    // glowSpread scales whichever blur applies.
    final blurSigma =
        (mono
            ? lineBloomBlurSigmaMono
            : (config.staticColors ? 0.0 : lineBloomBlurSigma)) *
        config.glowSpread;
    final matrix = config.staticColors
        ? null
        : BeamColorMatrix.beamFilter(
            hueDegrees: phases.bloomHueDegrees + config.hueBase,
            brightness: config.brightnessFactor,
            saturation: config.saturation,
          );
    Color fold(Color c) => matrix?.transform(c) ?? c;

    final layerPaint = Paint()..color = _white.withValues(alpha: opacity);
    if (blurSigma > 0) {
      layerPaint.imageFilter = ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
        tileMode: TileMode.decal,
      );
    }

    canvas.save();
    canvas.clipPath(geometry.outer);
    BeamLayerUtils.clipSegment(
      canvas,
      geometry,
      inward: rect.shortestSide / 2,
      outward: 0,
    );
    canvas.saveLayer(rect, layerPaint);

    _forEachTraveller(canvas, beams, (beam) {
      _paintSpikes(
        canvas,
        rect,
        config,
        phases,
        isDark,
        mono,
        _tint(fold, beam, fadeMax),
        beam,
        path: path,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = BeamGradients.radialWindow(
            center: _anchor(rect, beam, path: path),
            radiusX: _maskRadiusX(rect, beam, lineBloomWindowRadiusX * beam.w),
            radiusY: lineBloomWindowRadiusY * phases.lineH,
            midStop: lineBloomWindowMidStop,
            midAlpha: lineBloomWindowMidAlpha,
            rotation: _rotation(beam, path),
          ),
      );
    });

    BeamLayerUtils.applySegmentFeather(canvas, rect, geometry);

    canvas.restore();
    canvas.restore();
  }

  Shader _window(
    Rect rect,
    _Traveller beam,
    BeamFramePhases phases, {
    _PathContext? path,
  }) => BeamGradients.radialWindow(
    center: _anchor(rect, beam, path: path),
    radiusX: _maskRadiusX(rect, beam, lineWindowRadiusX * beam.w),
    radiusY: lineWindowRadiusY * phases.lineH,
    midStop: lineWindowMidStop,
    midAlpha: lineWindowMidAlpha,
    rotation: _rotation(beam, path),
  );

  // A traveller's colour treatment: the shared fold, then the share of the
  // edge fade the group opacity did not already carry.
  Color Function(Color) _tint(
    Color Function(Color) fold,
    _Traveller beam,
    double fadeMax,
  ) {
    final k = fadeMax <= 0 ? 0.0 : (beam.fade / fadeMax).clamp(0.0, 1.0);
    if (k >= 1) return fold;
    return (c) {
      final folded = fold(c);
      return folded.withValues(alpha: folded.a * k);
    };
  }

  // Twinkles at each traveller, drawn over the stroke without a layer of
  // their own.
  void _paintSparkles(
    Canvas canvas,
    Rect rect,
    BeamConfig config,
    List<_Traveller> beams,
    double opacity,
    bool isDark, {
    _PathContext? path,
  }) {
    if (config.sparkle <= 0 || rect.isEmpty) return;
    if (path != null) {
      canvas.save();
      canvas.clipPath(
        BeamLayerUtils.segmentBandPath(
          path.geometry,
          inward: _sparkleSpread,
          outward: _sparkleSpread,
        ),
      );
    }
    for (var i = 0; i < beams.length; i++) {
      final beam = beams[i];
      final weight = path == null
          ? 1.0
          : path.geometry.segmentWeightAt(beam.fraction!);
      if (weight <= 0) continue;
      BeamLayerUtils.paintSparkles(
        canvas,
        center: _anchor(rect, beam, path: path),
        density: config.sparkle,
        color: isDark ? _white : _black,
        opacity: opacity * beam.fade * weight,
        spread: _sparkleSpread,
        seed: (beam.x * _sparkleSeedSteps).floor() * 7 + i,
      );
    }
    if (path != null) canvas.restore();
  }

  // The fixed bloom spikes at 8/22/36/50/64/78/92% of the edge, plus the
  // traveling dot/ambient (dark) or shadow blob (light). Transcribed from
  // getLineBloomGradients.
  void _paintSpikes(
    Canvas canvas,
    Rect rect,
    BeamConfig config,
    BeamFramePhases phases,
    bool isDark,
    bool mono,
    Color Function(Color) fold,
    _Traveller beam, {
    _PathContext? path,
  }) {
    final palette = config.palette.data;
    final spikeColors = isDark ? palette.spike : palette.spikeLt;
    final table = isDark ? palette.lineBloomDark : palette.lineBloomLight;

    Color att(Color c, double f) => BeamLayerUtils.attenuateSpike(c, f);
    final sc1 = mono
        ? att(spikeColors.primary, lineMonoSpike1)
        : spikeColors.primary;
    final sc1MidDark = mono
        ? att(spikeColors.primary, lineMonoSpike1MidDark)
        : spikeColors.primary;
    final sc1MidLight = mono
        ? att(spikeColors.primary, lineMonoSpike1MidLight)
        : BeamLayerUtils.withAlpha(
            spikeColors.primary,
            lineSpike1MidLightAlpha,
          );
    final sc2 = mono
        ? att(spikeColors.secondary, lineMonoSpike2)
        : spikeColors.secondary;
    final sc2MidDark = mono
        ? BeamLayerUtils.withAlpha(spikeColors.secondary, lineMonoSpike2MidDark)
        : BeamLayerUtils.withAlpha(
            spikeColors.secondary,
            lineSpike2MidDarkAlpha,
          );
    final sc2MidLight = mono
        ? att(spikeColors.secondary, lineMonoSpike2MidLight)
        : BeamLayerUtils.withAlpha(
            spikeColors.secondary,
            lineSpike2MidLightAlpha,
          );
    SpikePair spikeAt(int i) => mono
        ? SpikePair(
            att(table[i].color1, lineMonoTableSpike1),
            att(table[i].color2, lineMonoTableSpike2),
          )
        : table[i];

    // Mono widens and shortens the thin spikes into a soft glow.
    final thinW = mono ? lineMonoThinSpikeWidths : lineThinSpikeWidths;
    final thinH = mono ? lineMonoThinSpikeHeights : lineThinSpikeHeights;
    final thinLW = mono
        ? lineMonoThinSpikeWidthLight92
        : lineThinSpikeWidthLight92;

    void spike({
      required int index,
      required double rx,
      required double ry,
      required Color c0,
      required Color cMid,
    }) {
      final geometry = lineSpikes[index];
      // The spike table is authored from the start of the planar edge, so on
      // a mirrored range its fractions flip with the travel direction and the
      // seven spikes keep the screen positions the planar variant gives them.
      final fraction = path == null ? 0.0 : _pathFraction(path, geometry.fx);
      final center = path == null
          ? Offset(
              rect.left + geometry.fx * rect.width,
              rect.bottom - geometry.yInset,
            )
          : path.geometry.perimeter.offsetPointAt(fraction, geometry.yInset);
      final rotation = path == null
          ? 0.0
          : () {
              final tangent = path.geometry.perimeter.tangentAt(fraction);
              return math.atan2(tangent.dy, tangent.dx);
            }();
      BeamLayerUtils.paintRadial(
        canvas,
        center: center,
        radiusX: rx,
        radiusY: ry,
        colors: [fold(c0), fold(cMid), fold(cMid.withValues(alpha: 0))],
        stops: [0, geometry.midStop, geometry.endStop],
        rotation: rotation,
      );
    }

    final s = phases.spike;
    final s2 = phases.spike2;
    final h = phases.lineH;

    spike(
      index: 0,
      rx: thinW[0] * s,
      ry: thinH[0] * h,
      c0: sc1,
      cMid: isDark ? sc1MidDark : sc1MidLight,
    );
    spike(
      index: 1,
      rx: lineSpikeWideRadiusX22 * s2,
      ry: lineSpikeRadiusY22 * h,
      c0: sc2,
      cMid: isDark ? sc2MidDark : sc2MidLight,
    );
    spike(
      index: 2,
      rx: thinW[1] * (2 - s),
      ry: thinH[1] * h,
      c0: spikeAt(0).color1,
      cMid: spikeAt(0).color2,
    );
    spike(
      index: 3,
      rx: lineSpikeWideRadiusX50 * s2,
      ry: lineSpikeRadiusY50 * h,
      c0: spikeAt(1).color1,
      cMid: spikeAt(1).color2,
    );
    spike(
      index: 4,
      rx: thinW[2] * (2 - s2),
      ry: thinH[2] * h,
      c0: spikeAt(2).color1,
      cMid: spikeAt(2).color2,
    );
    spike(
      index: 5,
      rx: lineSpikeRadiusX78 * s,
      ry: lineSpikeRadiusY78 * h,
      c0: spikeAt(3).color1,
      cMid: spikeAt(3).color2,
    );
    spike(
      index: 6,
      rx: (isDark ? thinW[3] : thinLW) * (2 - s),
      ry: thinH[3] * h,
      c0: spikeAt(4).color1,
      cMid: spikeAt(4).color2,
    );

    if (isDark) {
      // Traveling dot + ambient glow.
      final dot = mono ? lineDotAlphasMono : lineDotAlphas;
      final dotC = _white.withValues(alpha: dot[0]);
      final dot20 = _white.withValues(alpha: dot[1]);
      final dot50 = _white.withValues(alpha: dot[2]);
      BeamLayerUtils.paintRadial(
        canvas,
        center: _anchor(rect, beam, dy: lineDotOffsetY, path: path),
        radiusX: lineDotRadiusX * s,
        radiusY: lineDotRadiusY * s2,
        colors: [
          fold(dotC),
          fold(dot20),
          fold(dot50),
          fold(dot50.withValues(alpha: 0)),
        ],
        stops: lineDotStops,
        rotation: _rotation(beam, path),
      );
      final ambient = mono ? lineAmbientAlphasMono : lineAmbientAlphas;
      final ambC = _white.withValues(alpha: ambient[0]);
      final amb25 = _white.withValues(alpha: ambient[1]);
      final amb55 = _white.withValues(alpha: ambient[2]);
      BeamLayerUtils.paintRadial(
        canvas,
        center: _anchor(rect, beam, path: path),
        radiusX: lineAmbientRadiusX * beam.w,
        radiusY: lineAmbientRadiusY * h,
        colors: [
          fold(ambC),
          fold(amb25),
          fold(amb55),
          fold(amb55.withValues(alpha: 0)),
        ],
        stops: lineAmbientStops,
        rotation: _rotation(beam, path),
      );
    } else {
      // Light theme: a traveling dark shadow blob instead of the bright dot.
      BeamLayerUtils.paintRadial(
        canvas,
        center: _anchor(rect, beam, path: path),
        radiusX: lineShadowRadiusX * beam.w,
        radiusY: lineShadowRadiusY * h,
        colors: [
          for (final a in lineShadowAlphas) fold(_black.withValues(alpha: a)),
        ],
        stops: lineShadowStops,
        rotation: _rotation(beam, path),
      );
    }
  }
}

double _fraction(double value) {
  final result = value % 1;
  return result < 0 ? result + 1 : result;
}

// Where progress [t] along a path-mode run lands on the perimeter. A mirrored
// range walks its clockwise span backwards, which is what keeps wrapCorners
// travelling the way the planar variant does.
double _pathFraction(_PathContext path, double t) =>
    _fraction(path.from + path.span * (path.mirrored ? 1 - t : t));

double _clockwiseSpan(double from, double to) {
  final span = _fraction(to - from);
  return span == 0 ? 1 : span;
}

BeamSegment _edgeSegment(BeamEdge edge) => switch (edge) {
  BeamEdge.top => BeamSegment.topEdge,
  BeamEdge.right => BeamSegment.rightEdge,
  BeamEdge.bottom => BeamSegment.bottomEdge,
  BeamEdge.left => BeamSegment.leftEdge,
};

// Turns the canvas so the authored bottom-edge painting lands on [edge], and
// returns the size it should be authored against — swapped for the two
// vertical edges, where the box's height becomes the authored width.
Size _applyEdgeTransform(Canvas canvas, Size size, BeamEdge edge) {
  switch (edge) {
    case BeamEdge.bottom:
      return size;
    case BeamEdge.top:
      canvas.translate(size.width, size.height);
      canvas.rotate(math.pi);
      return size;
    case BeamEdge.left:
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
      return Size(size.height, size.width);
    case BeamEdge.right:
      canvas.translate(0, size.height);
      canvas.rotate(-math.pi / 2);
      return Size(size.height, size.width);
  }
}

// The corner radii to author the ring with so that, once the canvas turn is
// applied, every corner lands back on the corner of the child it belongs to.
BorderRadius _rotateRadii(BorderRadius radii, BeamEdge edge) {
  switch (edge) {
    case BeamEdge.bottom:
      return radii;
    case BeamEdge.top:
      return BorderRadius.only(
        topLeft: radii.bottomRight,
        topRight: radii.bottomLeft,
        bottomLeft: radii.topRight,
        bottomRight: radii.topLeft,
      );
    case BeamEdge.left:
      return BorderRadius.only(
        topLeft: _swapAxes(radii.topRight),
        topRight: _swapAxes(radii.bottomRight),
        bottomRight: _swapAxes(radii.bottomLeft),
        bottomLeft: _swapAxes(radii.topLeft),
      );
    case BeamEdge.right:
      return BorderRadius.only(
        topLeft: _swapAxes(radii.bottomLeft),
        topRight: _swapAxes(radii.topLeft),
        bottomRight: _swapAxes(radii.topRight),
        bottomLeft: _swapAxes(radii.bottomRight),
      );
  }
}

// A quarter turn swaps an elliptical radius' two axes.
Radius _swapAxes(Radius r) => Radius.elliptical(r.y, r.x);
