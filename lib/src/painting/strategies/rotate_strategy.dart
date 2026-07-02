import 'dart:math' as math;
import 'dart:ui';

import '../../animation/beam_phases.dart';
import '../../models/beam_config.dart';
import '../color_matrix.dart';
import '../gradient_builders.dart';
import '../layer_utils.dart';
import '../ring_geometry.dart';
import '../variant_strategy.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

// Conic stop tables transcribed from the source's generated CSS
// (generateBorderVariantCSS / generateSmallVariantCSS — identical for both).

// The rotating soft window revealing the stroke/inner layers.
const _windowStops = [0.0, 0.30, 0.36, 0.44, 0.52, 0.80, 0.86, 0.92, 0.95, 1.0];
const _windowAlphas = [0.0, 0.0, 0.1, 0.35, 1.0, 1.0, 0.35, 0.1, 0.0, 0.0];

// The wider window used by the small variant's inner layer (`smallMask`).
const _smallWindowStops = [
  0.0, 0.22, 0.28, 0.36, 0.46, 0.82, 0.88, 0.94, 0.97, 1.0, //
];
const _smallWindowAlphas = [0.0, 0.0, 0.12, 0.4, 1.0, 1.0, 0.4, 0.12, 0.0, 0.0];

// The white (dark theme) / black (light theme) highlight sweep of the stroke.
const _highlightStops = [
  0.0, 0.54, 0.57, 0.60, 0.63, 0.66, 0.69, 0.72, 0.75, 0.78, 1.0, //
];
const _highlightAlphasDark = [
  0.0, 0.0, 0.1, 0.3, 0.6, 0.75, 0.6, 0.3, 0.1, 0.0, 0.0, //
];
const _highlightAlphasLight = [
  0.0, 0.0, 0.08, 0.2, 0.4, 0.55, 0.4, 0.2, 0.08, 0.0, 0.0, //
];

// The sharp bloom band, blurred 8px.
const _bloomStops = [
  0.0, 0.58, 0.62, 0.65, 0.67, 0.69, 0.70, 0.705, 0.715, 0.73, 0.75, 0.78,
  0.82, 1.0, //
];
const _bloomAlphasDark = [
  0.0, 0.0, 0.03, 0.08, 0.2, 0.45, 0.85, 0.85, 0.45, 0.2, 0.08, 0.03, 0.0,
  0.0, //
];
const _bloomAlphasLight = [
  0.0, 0.0, 0.02, 0.08, 0.2, 0.4, 0.6, 0.6, 0.4, 0.2, 0.08, 0.02, 0.0, 0.0, //
];

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
    final rect = Offset.zero & size;
    final geometry = BeamRingGeometry(
      rect: rect,
      radius: config.borderRadius,
      borderWidth: config.borderWidth,
      useSuperellipse: config.useSuperellipse,
    );
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
      final alpha = config.palette.monoTreatment ? 0.225 : 0.45;
      for (final blob in config.palette.data.border) {
        BeamGradients.paintBlob(
          canvas,
          center: _blobCenter(rect, blob.position),
          radiusX: (blob.size.width * 0.9).roundToDouble(),
          radiusY: (blob.size.height * 0.9).roundToDouble(),
          color: fold(blob.color.withValues(alpha: alpha)),
        );
      }
    }
    BeamLayerUtils.paintInnerShadow(
      canvas,
      contour: geometry.outer,
      color: fold(config.theme.innerShadow),
      blur: compact ? 5 : 9,
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
            phases.angleRadians,
            stops: _smallWindowStops,
            alphas: _smallWindowAlphas,
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
            phases.angleRadians,
            stops: _windowStops,
            alphas: _windowAlphas,
          ),
      );
      canvas.restore();
    }

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

    canvas.save();
    canvas.clipPath(geometry.ring);
    canvas.saveLayer(rect, Paint()..color = _white.withValues(alpha: opacity));

    // Highlight sweep (white on dark, black on light).
    final highlightBase = isDark ? _white : _black;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = BeamGradients.conic(
          rect: rect,
          cssFromRadians: phases.angleRadians,
          colors: [
            for (final a
                in isDark ? _highlightAlphasDark : _highlightAlphasLight)
              fold(highlightBase.withValues(alpha: a)),
          ],
          stops: _highlightStops,
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
          phases.angleRadians,
          stops: _windowStops,
          alphas: _windowAlphas,
        ),
    );

    canvas.restore();
    canvas.restore();
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

    // Bloom filter chain: blur(8px) brightness saturate (no hue).
    final matrix = BeamColorMatrix.beamFilter(
      hueDegrees: 0,
      brightness: config.brightnessFactor,
      saturation: config.saturation,
    );
    final base = isDark ? _white : _black;

    canvas.save();
    canvas.clipPath(geometry.outer);
    canvas.saveLayer(
      rect,
      Paint()
        ..color = _white.withValues(alpha: opacity)
        ..imageFilter = ImageFilter.blur(
          sigmaX: 8,
          sigmaY: 8,
          tileMode: TileMode.decal,
        ),
    );
    canvas.save();
    canvas.clipPath(geometry.ring);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = BeamGradients.conic(
          rect: rect,
          cssFromRadians: phases.angleRadians,
          colors: [
            for (final a in isDark ? _bloomAlphasDark : _bloomAlphasLight)
              matrix.transform(base.withValues(alpha: a)),
          ],
          stops: _bloomStops,
        ),
    );
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }

  Shader _window(
    Rect rect,
    double angle, {
    required List<double> stops,
    required List<double> alphas,
  }) => BeamGradients.conic(
    rect: rect,
    cssFromRadians: angle,
    colors: [for (final a in alphas) _white.withValues(alpha: a)],
    stops: stops,
  );

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
