import 'dart:ui';

import '../../animation/beam_phases.dart';
import '../../constants/pulse_params.dart';
import '../../constants/pulse_tables.dart';
import '../../models/beam_config.dart';
import '../../models/beam_variant.dart';
import '../color_matrix.dart';
import '../gradient_builders.dart';
import '../layer_utils.dart';
import '../ring_geometry.dart';
import '../variant_strategy.dart';
import 'pulse_common.dart';

const Color _white = Color(0xFFFFFFFF);

/// The contained breathing glow (React `pulse-inner`): a breathing inner
/// perimeter with corner accents, a colorful perimeter ring, and a frozen
/// blurred bloom, all clipped inside the element.
class PulseInnerStrategy extends BeamVariantStrategy {
  /// Const constructor.
  const PulseInnerStrategy();

  @override
  double? get preferredFps => 30;

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
    final params = PulseParams.resolve(
      BeamVariant.pulseInside,
      config.brightness,
      config.cycleSeconds,
    );

    // Pulse layers keep brightness/saturation even with static colors; only
    // the hue term is dropped (ringAnim in the source).
    final ringMatrix = BeamColorMatrix.beamFilter(
      hueDegrees: config.staticColors ? 0 : phases.hueDegrees + config.hueBase,
      brightness: config.brightnessFactor,
      saturation: config.saturation,
    );
    Color fold(Color c) => ringMatrix.transform(c);

    final boost = config.glowBoost;
    final border = config.palette.data.border;

    // ── z1: inner perimeter + corner accents (::before) ──
    final innerOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.innerOpacity,
      hookFactor: config.innerOpacityFactor,
    );
    if (innerOpacity > 0) {
      canvas.save();
      canvas.clipPath(geometry.outer);
      canvas.saveLayer(
        rect,
        Paint()..color = _white.withValues(alpha: innerOpacity),
      );

      for (final (i, blob) in border.indexed) {
        final map = pulseRingMap[i];
        paintPulseBlob(
          canvas,
          rect: rect,
          color: blob.color,
          fractionalPos: blob.position,
          w: pulseInnerSizes[i].width,
          h: pulseInnerSizes[i].height,
          region: map.region,
          quad: map.quad,
          pulse: phases.pulse,
          sx: 1,
          sy: 1,
          boost: boost,
          fold: fold,
        );
      }
      // Corner accents: fixed 60×60 ellipses whose alpha breathes with the
      // corner's quadrant oscillator.
      final cornerBase = isDark ? _white : const Color(0xFF000000);
      final cornerAlpha = isDark ? 0.18 : 0.08;
      final corners = [
        (pos: rect.topLeft, quad: pulseRingMap[0].quad),
        (pos: rect.topRight, quad: pulseRingMap[6].quad),
        (pos: rect.bottomLeft, quad: pulseRingMap[2].quad),
        (pos: rect.bottomRight, quad: pulseRingMap[4].quad),
      ];
      for (final corner in corners) {
        final a = cornerAlpha * quadOpacity(phases.pulse, corner.quad);
        BeamLayerUtils.paintRadial(
          canvas,
          center: corner.pos,
          radiusX: 60,
          radiusY: 60,
          colors: [
            fold(cornerBase.withValues(alpha: a)),
            fold(cornerBase.withValues(alpha: 0)),
          ],
          stops: const [0, 0.70],
        );
      }

      // Mask: featherV ∪ featherH (edge-hugging inner border).
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
      canvas.restore();

      canvas.restore();
      canvas.restore();
    }

    // ── z2: perimeter ring (::after) ──
    final strokeOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.strokeOpacity,
      hookFactor: config.strokeOpacityFactor,
    );
    if (strokeOpacity > 0) {
      canvas.save();
      canvas.clipPath(geometry.ring);
      canvas.saveLayer(
        rect,
        Paint()..color = _white.withValues(alpha: strokeOpacity),
      );
      for (final (i, blob) in border.indexed) {
        final map = pulseRingMap[i];
        paintPulseBlob(
          canvas,
          rect: rect,
          color: blob.color,
          fractionalPos: blob.position,
          w: blob.size.width,
          h: blob.size.height,
          region: map.region,
          quad: map.quad,
          pulse: phases.pulse,
          sx: 1,
          sy: 1,
          boost: boost,
          fold: fold,
        );
      }
      canvas.restore();
      canvas.restore();
    }

    // ── z3: frozen bloom in the ring, blurred ──
    final bloomOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.bloomOpacity,
      hookFactor: config.bloomOpacityFactor,
    );
    if (bloomOpacity > 0) {
      final frozenAlpha = 1 - params.op * 0.5;
      canvas.save();
      canvas.clipPath(geometry.outer);
      canvas.saveLayer(
        rect,
        Paint()
          ..color = _white.withValues(alpha: bloomOpacity)
          ..imageFilter = ImageFilter.blur(
            sigmaX: 8,
            sigmaY: 8,
            tileMode: TileMode.decal,
          ),
      );
      canvas.save();
      canvas.clipPath(geometry.ring);
      for (final spec in pulseInnerBloom) {
        final source = border[spec.ci];
        paintFrozenPulseBlob(
          canvas,
          rect: rect,
          color: source.color,
          fractionalPos: source.position,
          w: spec.w,
          h: spec.h,
          frozenAlpha: frozenAlpha,
          sx: 1,
          sy: 1,
          boost: boost,
          fold: fold,
        );
      }
      canvas.restore();
      canvas.restore();
      canvas.restore();
    }
  }
}
