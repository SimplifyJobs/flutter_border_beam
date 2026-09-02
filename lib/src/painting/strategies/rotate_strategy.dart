import 'dart:math' as math;
import 'dart:ui';

import '../../animation/beam_phases.dart';
import '../../constants/rotate_stops.dart';
import '../../models/beam_config.dart';
import '../color_matrix.dart';
import '../gradient_builders.dart';
import '../layer_utils.dart';
import '../ring_geometry.dart';
import '../variant_strategy.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

// How far past the ring the comet halo reaches at glowSpread 1, and how much
// wider its band runs than the plain bloom's — the halo is the same layer,
// re-clipped and stretched, so it has to read as a trail rather than as an
// edge highlight.
const double _cometReach = 12;
const double _cometBandFactor = 1.6;

// The stop the rotate window's bright core ends at: the beam's head, and so
// where the sparkles gather.
const double _windowHeadStop = 0.80;

// The sparkle scatter's radius around the head, and how finely travel
// progress is quantised into its seed (higher re-rolls the twinkles more
// often).
const double _sparkleSpread = 14;
const int _sparkleSeedSteps = 16;

/// The traveling-beam strategy shared by [BeamVariant.rotate] (React `md`)
/// and [BeamVariant.small] (React `sm`) — a conic highlight and color blobs
/// revealed through a rotating soft window.
class RotateStrategy extends BeamVariantStrategy {
  /// Creates the strategy. [compact] selects the small variant's gradient
  /// tables and masks.
  const RotateStrategy({required this.compact});

  /// Whether this paints the small (`sm`) variant.
  final bool compact;

  @override
  void paintAbove(
    Canvas canvas,
    Size size,
    BeamConfig config,
    BeamFramePhases phases,
  ) {
    if (phases.fadeOpacity <= 0) return;
    final rect = beamRect(size, config);
    final geometry = beamGeometry(rect, config);
    final isDark = config.brightness == Brightness.dark;

    // CPU color folding: when hue animation runs, the whole
    // hue/brightness/saturation chain is baked into gradient colors, so the
    // stroke/inner layers need no per-frame ColorFilter saveLayer. With
    // static colors the source omits the filter entirely.
    final strokeMatrix = config.staticColors
        ? null
        : BeamColorMatrix.beamFilter(
            hueDegrees: phases.hueDegrees + config.hueBase,
            brightness: config.brightnessFactor,
            saturation: config.saturation,
          );
    Color fold(Color c) => strokeMatrix?.transform(c) ?? c;

    _paintInner(canvas, rect, geometry, config, phases, fold, isDark);
    _paintStroke(canvas, rect, geometry, config, phases, fold, isDark);
    _paintBloom(canvas, rect, geometry, config, phases, isDark);
  }

  void _paintInner(
    Canvas canvas,
    Rect rect,
    BeamRingGeometry geometry,
    BeamConfig config,
    BeamFramePhases phases,
    Color Function(Color) fold,
    bool isDark,
  ) {
    final opacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.innerOpacity,
      hookFactor: config.innerOpacityFactor,
    );
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

    if (compact) {
      for (final blob in config.palette.data.smallInner) {
        BeamGradients.paintBlob(
          canvas,
          center: _blobCenter(rect, blob.position),
          radiusX: blob.size.width,
          radiusY: blob.size.height,
          color: fold(blob.color),
        );
      }
    } else {
      // md derives its inner blobs from the border table: 0.9× size and a
      // fixed alpha (0.45, or 0.225 for mono).
      final alpha = config.palette.monoTreatment
          ? rotateInnerBlobAlphaMono
          : rotateInnerBlobAlpha;
      for (final blob in config.palette.data.border) {
        BeamGradients.paintBlob(
          canvas,
          center: _blobCenter(rect, blob.position),
          radiusX: (blob.size.width * rotateInnerBlobScale).roundToDouble(),
          radiusY: (blob.size.height * rotateInnerBlobScale).roundToDouble(),
          color: fold(blob.color.withValues(alpha: alpha)),
        );
      }
    }
    BeamLayerUtils.paintInnerShadow(
      canvas,
      contour: geometry.outer,
      color: fold(config.theme.innerShadow),
      blur: compact ? smallInnerShadowBlur : rotateInnerShadowBlur,
    );

    // Mask pass.
    if (compact) {
      // Single wide conic window, additive.
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _window(
            rect,
            config,
            phases,
            stops: smallWindowStops,
            alphas: smallWindowAlphas,
          ),
      );
    } else {
      // (featherV ∪ featherH) ∩ conic window, built in a mask sub-layer.
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
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = _window(
            rect,
            config,
            phases,
            stops: rotateWindowStops,
            alphas: rotateWindowAlphas,
          ),
      );
      canvas.restore();
    }

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
  ) {
    final opacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.strokeOpacity,
      hookFactor: config.strokeOpacityFactor,
    );
    if (opacity <= 0) return;
    final highlightBase = isDark ? _white : _black;

    canvas.save();
    canvas.clipPath(geometry.ring);
    BeamLayerUtils.clipSegment(canvas, geometry, inward: 0, outward: 0);
    canvas.saveLayer(rect, Paint()..color = _white.withValues(alpha: opacity));

    // Highlight sweep (white on dark, black on light).
    final highlight = BeamConicWindow.resolve(
      rotateHighlightStops,
      isDark ? rotateHighlightAlphasDark : rotateHighlightAlphasLight,
      reversed: phases.reversedNow,
      tailLength: config.tailLength,
      beamCount: config.beamCount,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = BeamGradients.conic(
          rect: rect,
          cssFromRadians: phases.angleRadians,
          colors: [
            for (final a in highlight.alphas)
              fold(highlightBase.withValues(alpha: a)),
          ],
          stops: highlight.stops,
        ),
    );
    final blobs = compact
        ? config.palette.data.smallBorder
        : config.palette.data.border;
    for (final blob in blobs) {
      BeamGradients.paintBlob(
        canvas,
        center: _blobCenter(rect, blob.position),
        radiusX: blob.size.width,
        radiusY: blob.size.height,
        color: fold(blob.color),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _window(
          rect,
          config,
          phases,
          stops: rotateWindowStops,
          alphas: rotateWindowAlphas,
        ),
    );
    _applySegments(canvas, rect, config);
    BeamLayerUtils.applySegmentFeather(canvas, rect, geometry);

    canvas.restore();
    canvas.restore();

    _paintSparkles(
      canvas,
      rect,
      geometry,
      config,
      phases,
      opacity,
      highlightBase,
    );
  }

  void _paintBloom(
    Canvas canvas,
    Rect rect,
    BeamRingGeometry geometry,
    BeamConfig config,
    BeamFramePhases phases,
    bool isDark,
  ) {
    final opacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.bloomOpacity,
      hookFactor: config.bloomOpacityFactor,
    );
    if (opacity <= 0) return;

    // Bloom filter chain: blur(8px · glowSpread) brightness saturate (no
    // hue).
    final matrix = BeamColorMatrix.beamFilter(
      hueDegrees: 0,
      brightness: config.brightnessFactor,
      saturation: config.saturation,
    );
    final base = isDark ? _white : _black;

    // The comet is this same layer, re-aimed: instead of the thin ring it
    // fills a halo reaching past the border, and its band runs wider so the
    // glow trails the head. One clip swapped and one band stretched — no
    // second layer.
    final reach = _cometReach * config.glowSpread;
    final region = config.comet ? geometry.halo(reach) : geometry.outer;
    final band = config.comet ? region : geometry.ring;
    final bounds = config.comet ? rect.inflate(reach) : rect;
    final table = BeamConicWindow.resolve(
      rotateBloomStops,
      isDark ? rotateBloomAlphasDark : rotateBloomAlphasLight,
      reversed: phases.reversedNow,
      tailLength: config.tailLength * (config.comet ? _cometBandFactor : 1.0),
      beamCount: config.beamCount,
    );

    canvas.save();
    canvas.clipPath(region);
    BeamLayerUtils.clipSegment(
      canvas,
      geometry,
      inward: 0,
      outward: config.comet ? reach : 0,
    );
    canvas.saveLayer(
      bounds,
      Paint()
        ..color = _white.withValues(alpha: opacity)
        ..imageFilter = ImageFilter.blur(
          sigmaX: rotateBloomBlurSigma * config.glowSpread,
          sigmaY: rotateBloomBlurSigma * config.glowSpread,
          tileMode: TileMode.decal,
        ),
    );
    canvas.save();
    canvas.clipPath(band);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = BeamGradients.conic(
          rect: rect,
          cssFromRadians: phases.angleRadians,
          colors: [
            for (final a in table.alphas)
              matrix.transform(base.withValues(alpha: a)),
          ],
          stops: table.stops,
        ),
    );
    canvas.restore();
    _applySegments(canvas, bounds, config);
    BeamLayerUtils.applySegmentFeather(canvas, bounds, geometry);
    canvas.restore();
    canvas.restore();
  }

  // The dashed-ring mask: one repeating conic multiplied into a layer that
  // exists anyway, so a dashed ring costs no more than a solid one.
  void _applySegments(Canvas canvas, Rect rect, BeamConfig config) {
    final segments = config.segments;
    if (segments == null || segments < 2) return;
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = BeamGradients.segmentMask(rect, segments),
    );
  }

  // Twinkles at each beam head, drawn over the stroke without a layer of
  // their own. They live in the foreground pass, so nothing about them
  // touches the child.
  void _paintSparkles(
    Canvas canvas,
    Rect rect,
    BeamRingGeometry geometry,
    BeamConfig config,
    BeamFramePhases phases,
    double opacity,
    Color color,
  ) {
    if (config.sparkle <= 0 || rect.isEmpty) return;
    final turn = phases.angleRadians / (2 * math.pi);
    final seed = (turn * _sparkleSeedSteps).floor();
    final head = phases.reversedNow ? 1 - _windowHeadStop : _windowHeadStop;
    canvas.save();
    canvas.clipPath(_sparkleBand(rect, config));
    for (var k = 0; k < config.beamCount; k++) {
      final stop = (head + k) / config.beamCount;
      final edgePoint = BeamLayerUtils.edgePointAt(
        rect,
        phases.angleRadians + stop * 2 * math.pi,
      );
      final headFraction = geometry.perimeter.nearestFraction(edgePoint);
      if (geometry.segmentWeightAt(headFraction) == 0) continue;
      BeamLayerUtils.paintSparkles(
        canvas,
        center: edgePoint,
        density: config.sparkle,
        color: color,
        opacity: opacity,
        spread: _sparkleSpread,
        seed: seed * 7 + k,
      );
    }
    canvas.restore();
  }

  // Sparkles scatter around the border, so they are held to a band straddling
  // it rather than allowed to drift into the middle of the child.
  Path _sparkleBand(Rect rect, BeamConfig config) {
    final outside = beamGeometry(rect.inflate(_sparkleSpread), config).outer;
    final inside = rect.deflate(_sparkleSpread).isEmpty
        ? Path()
        : beamGeometry(rect.deflate(_sparkleSpread), config).outer;
    return Path.combine(PathOperation.difference, outside, inside);
  }

  Shader _window(
    Rect rect,
    BeamConfig config,
    BeamFramePhases phases, {
    required List<double> stops,
    required List<double> alphas,
  }) {
    final table = BeamConicWindow.resolve(
      stops,
      alphas,
      reversed: phases.reversedNow,
      tailLength: config.tailLength,
      beamCount: config.beamCount,
    );
    return BeamGradients.conic(
      rect: rect,
      cssFromRadians: phases.angleRadians,
      colors: [for (final a in table.alphas) _white.withValues(alpha: a)],
      stops: table.stops,
    );
  }

  static Offset _blobCenter(Rect rect, Offset fractional) => Offset(
    rect.left + fractional.dx * rect.width,
    rect.top + fractional.dy * rect.height,
  );
}

/// Reusable blob-center math for other strategies.
Offset blobCenter(Rect rect, Offset fractional) => Offset(
  rect.left + fractional.dx * rect.width,
  rect.top + fractional.dy * rect.height,
);

/// Clamp helper mirroring CSS `max(0, ...)` for derived radii.
double nonNegative(double v) => math.max(0, v);
