import 'dart:ui';

import '../../animation/beam_phases.dart';
import '../../constants/pulse_constants.dart';
import '../../constants/pulse_params.dart';
import '../../constants/pulse_tables.dart';
import '../../models/beam_blob.dart';
import '../../models/beam_config.dart';
import '../../models/beam_variant.dart';
import '../color_matrix.dart';
import '../gradient_builders.dart';
import '../layer_utils.dart';
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

  @override
  double? get preferredFps => 30;

  double _sx(Size size) => (size.width / pulseOuterReferenceWidth).clamp(
    pulseOuterMinScale,
    pulseOuterMaxScale,
  );
  double _sy(Size size) => (size.height / pulseOuterReferenceHeight).clamp(
    pulseOuterMinScale,
    pulseOuterMaxScale,
  );

  // Halo reach/blur scale with element size relative to the demo's Subscribe
  // button baseline (measured glow scale 0.35), damped ×0.7
  // (`--sub-glow-unit`).
  double _unit(Size size) =>
      _sx(size) / pulseOuterMinScale * pulseOuterGlowUnitDamping;

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
    final rect = beamRect(size, config);
    final params = PulseParams.resolve(
      BeamVariant.pulseOutside,
      config.brightness,
      config.cycleSeconds,
    );
    final sx = _sx(size);
    final sy = _sy(size);
    final unit = _unit(size);
    final boost = config.glowBoost * pulseOuterTunedBoost;
    final border = config.palette.data.border;

    // Filter ordering: CSS runs `blur()` before the color terms, and Skia
    // runs a paint's colorFilter BEFORE its imageFilter, so the color matrix
    // is composed explicitly after the blur (ImageFilter.compose runs
    // `inner` first).
    final glowMatrix = _matrix(
      config,
      phases,
      brightness:
          config.glowBrightness ??
          pulseOuterGlowBrightness * pulseOuterTunedGlowMultiplier,
      saturation:
          config.glowSaturation ??
          pulseOuterGlowSaturation * pulseOuterTunedGlowMultiplier,
    );
    ImageFilter glowBlur(double sigma) => ImageFilter.compose(
      outer: glowMatrix.toColorFilter(),
      inner: ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      ),
    );
    Color fold(Color c) => c;

    // ── Core glow: blurred, breathing, hugging the edge ──
    final coreOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.innerOpacity,
      hookFactor: config.innerOpacityFactor,
      extra: pulseOuterTunedGlowMultiplier,
    );
    // glowSpread multiplies how far the halo reaches and how soft it is —
    // its insets and both blurs.
    final spread = config.glowSpread;
    final coreBlur =
        (config.coreBlur ?? pulseOuterTunedCoreBlur * unit) * spread;
    if (coreOpacity > 0) {
      final coreRect = rect.inflate(pulseOuterTunedCoreInset * unit * spread);
      canvas.saveLayer(
        coreRect.inflate(coreBlur * 3),
        Paint()
          ..color = _white.withValues(alpha: coreOpacity)
          ..imageFilter = glowBlur(coreBlur),
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

    // ── Bloom halo: frozen, heavily blurred ambient wash ──
    final bloomOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.bloomOpacity,
      hookFactor: config.bloomOpacityFactor,
      extra: pulseOuterTunedGlowMultiplier,
    );
    final bloomBlur =
        (config.bloomBlur ?? pulseOuterTunedBloomBlur * unit) * spread;
    if (bloomOpacity > 0) {
      final bloomRect = rect.inflate(pulseOuterTunedBloomInset * unit * spread);
      final frozenAlpha = 1 - params.op * 0.5;
      canvas.saveLayer(
        bloomRect.inflate(bloomBlur * 3),
        Paint()
          ..color = _white.withValues(alpha: bloomOpacity)
          ..imageFilter = glowBlur(bloomBlur),
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
    final rect = beamRect(size, config);
    final isDark = config.brightness == Brightness.dark;
    // The stroke ring is always 1px in the source (padding: 1px).
    final geometry = beamGeometry(rect, config);
    final sx = _sx(size);
    final sy = _sy(size);
    // Filter applied at layer composite time (post-gradient), matching CSS —
    // see paintBehind for why this must not be folded into the colors.
    final matrix = _matrix(config, phases);
    Color fold(Color c) => c;
    final border = config.palette.data.border;

    final strokeOpacity = BeamLayerUtils.layerOpacity(
      config,
      fade: phases.fadeOpacity,
      preset: config.theme.strokeOpacity,
      hookFactor: config.strokeOpacityFactor,
      extra: pulseOuterTunedGlowMultiplier,
    );
    if (strokeOpacity <= 0) return;

    canvas.save();
    canvas.clipPath(geometry.ring);
    canvas.saveLayer(
      rect,
      Paint()
        ..color = _white.withValues(alpha: strokeOpacity)
        ..colorFilter = matrix.toColorFilter(),
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
    // The dashed-ring mask rides inside the ring layer; the outward glows are
    // left continuous, since dashing a soft halo reads as banding.
    final segments = config.segments;
    if (segments != null && segments >= 2) {
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = BeamGradients.segmentMask(rect, segments),
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
    canvas.scale(pulseOuterScaleX, pulseOuterScaleY);
    canvas.translate(-center.dx, -center.dy);
    paint();
    canvas.restore();
  }
}
