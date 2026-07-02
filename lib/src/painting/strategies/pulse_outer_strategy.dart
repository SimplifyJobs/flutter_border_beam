import 'dart:ui';

import '../../animation/beam_phases.dart';
import '../../constants/pulse_params.dart';
import '../../constants/pulse_tables.dart';
import '../../models/beam_blob.dart';
import '../../models/beam_config.dart';
import '../../models/beam_variant.dart';
import '../color_matrix.dart';
import '../layer_utils.dart';
import '../ring_geometry.dart';
import '../variant_strategy.dart';
import 'pulse_common.dart';

const Color _white = Color(0xFFFFFFFF);

/// The outward-blooming breathing halo (React `pulse-outside`): a crisp
/// stroke ring above the child, and a colorful core plus soft halo painted
/// BEHIND and OUTSIDE the child (which must be opaque so only the outward
/// spill shows).
class PulseOuterStrategy extends BeamVariantStrategy {
  /// Const constructor.
  const PulseOuterStrategy();

  /// Reference child dimensions the glow geometry was authored for.
  static const double referenceWidth = 350;

  /// Reference child height.
  static const double referenceHeight = 140;

  /// Glow scale clamp bounds.
  static const double minScale = 0.35;

  /// Upper clamp bound.
  static const double maxScale = 4;

  // The source's constant outward-glow transform (scale(0.95, 0.9)).
  static const double _sw = 0.95;
  static const double _sh = 0.9;

  @override
  double? get preferredFps => 30;

  double _sx(Size size) =>
      (size.width / referenceWidth).clamp(minScale, maxScale);
  double _sy(Size size) =>
      (size.height / referenceHeight).clamp(minScale, maxScale);

  BeamColorMatrix _matrix(
    BeamConfig config,
    BeamFramePhases phases, {
    double? brightness,
    double? saturation,
  }) => BeamColorMatrix.beamFilter(
    hueDegrees: config.staticColors ? 0 : phases.hueDegrees + config.hueBase,
    brightness: brightness ?? config.brightnessFactor,
    saturation: saturation ?? config.saturation,
  );

  @override
  void paintBehind(
    Canvas canvas,
    Size size,
    BeamConfig config,
    BeamFramePhases phases,
  ) {
    if (phases.fadeOpacity <= 0) return;
    final rect = Offset.zero & size;
    final isDark = config.brightness == Brightness.dark;
    final params = PulseParams.resolve(
      BeamVariant.pulseOutside,
      config.brightness,
      config.cycleSeconds,
    );
    final sx = _sx(size);
    final sy = _sy(size);
    final boost = config.glowBoost;
    final border = config.palette.data.border;

    final glowMatrix = _matrix(
      config,
      phases,
      brightness: config.glowBrightness,
      saturation: config.glowSaturation,
    );
    Color fold(Color c) => glowMatrix.transform(c);

    // ── Core glow: inset −10px, blurred, breathing ──
    final coreOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.innerOpacity,
      hookFactor: config.innerOpacityFactor,
    );
    final coreBlur = config.coreBlur ?? (isDark ? 3.0 : 6.0);
    if (coreOpacity > 0) {
      final coreRect = rect.inflate(10);
      canvas.saveLayer(
        coreRect.inflate(coreBlur * 3),
        Paint()
          ..color = _white.withValues(alpha: coreOpacity)
          ..imageFilter = ImageFilter.blur(
            sigmaX: coreBlur,
            sigmaY: coreBlur,
            tileMode: TileMode.decal,
          ),
      );
      _scaled(canvas, rect.center, () {
        for (final spec in pulseOuterCore) {
          paintPulseBlob(
            canvas,
            rect: coreRect,
            color: border[spec.ci].color,
            fractionalPos: _specPos(spec, border),
            w: spec.w,
            h: spec.h,
            region: spec.region,
            quad: spec.quad,
            pulse: phases.pulse,
            sx: sx,
            sy: sy,
            boost: boost,
            fold: fold,
          );
        }
      });
      canvas.restore();
    }

    // ── Bloom halo: inset −30px, frozen, heavily blurred ──
    final bloomOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.bloomOpacity,
      hookFactor: config.bloomOpacityFactor,
    );
    final bloomBlur = config.bloomBlur ?? (isDark ? 22.5 : 15.0);
    if (bloomOpacity > 0) {
      final bloomRect = rect.inflate(30);
      final frozenAlpha = 1 - params.op * 0.5;
      canvas.saveLayer(
        bloomRect.inflate(bloomBlur * 3),
        Paint()
          ..color = _white.withValues(alpha: bloomOpacity)
          ..imageFilter = ImageFilter.blur(
            sigmaX: bloomBlur,
            sigmaY: bloomBlur,
            tileMode: TileMode.decal,
          ),
      );
      _scaled(canvas, rect.center, () {
        for (final spec in pulseOuterBloom) {
          paintFrozenPulseBlob(
            canvas,
            rect: bloomRect,
            color: border[spec.ci].color,
            fractionalPos: _specPos(spec, border),
            w: spec.w,
            h: spec.h,
            frozenAlpha: frozenAlpha,
            sx: sx,
            sy: sy,
            boost: boost,
            fold: fold,
          );
        }
      });
      canvas.restore();
    }
  }

  @override
  void paintAbove(
    Canvas canvas,
    Size size,
    BeamConfig config,
    BeamFramePhases phases,
  ) {
    if (phases.fadeOpacity <= 0) return;
    final rect = Offset.zero & size;
    final isDark = config.brightness == Brightness.dark;
    final geometry = BeamRingGeometry(
      rect: rect,
      radius: config.borderRadius,
      // The stroke ring is always 1px in the source (padding: 1px).
      borderWidth: config.borderWidth,
      useSuperellipse: config.useSuperellipse,
    );
    final sx = _sx(size);
    final sy = _sy(size);
    final matrix = _matrix(config, phases);
    Color fold(Color c) => matrix.transform(c);
    final border = config.palette.data.border;

    final strokeOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.strokeOpacity,
      hookFactor: config.strokeOpacityFactor,
    );
    if (strokeOpacity <= 0) return;

    canvas.save();
    canvas.clipPath(geometry.ring);
    canvas.saveLayer(
      rect,
      Paint()..color = _white.withValues(alpha: strokeOpacity),
    );
    // Optional static hairline under the colored stroke (preset 0 — the
    // wrapped child's own border provides the idle edge).
    final hairline = config.theme.hairlineOpacity ?? 0;
    if (hairline > 0) {
      final hairRGB = isDark
          ? const Color(0xFF464646)
          : const Color(0xFF000000);
      canvas.drawRect(
        rect,
        Paint()..color = hairRGB.withValues(alpha: hairline),
      );
    }
    for (final spec in pulseOuterCore) {
      paintPulseBlob(
        canvas,
        rect: rect,
        color: border[spec.ci].color,
        fractionalPos: _specPos(spec, border),
        w: spec.w,
        h: spec.h,
        region: spec.region,
        quad: spec.quad,
        pulse: phases.pulse,
        sx: sx,
        sy: sy,
        boost: config.glowBoost,
        fold: fold,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  Offset _specPos(PulseBlobSpec spec, List<BeamBlob> border) =>
      spec.x != null && spec.y != null
      ? Offset(spec.x!, spec.y!)
      : border[spec.ci].position;

  void _scaled(Canvas canvas, Offset center, void Function() paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(_sw, _sh);
    canvas.translate(-center.dx, -center.dy);
    paint();
    canvas.restore();
  }
}
