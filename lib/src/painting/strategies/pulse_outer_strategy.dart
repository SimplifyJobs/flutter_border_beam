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

  // The demo-hero tuning recipe (`.beam-host--pulse-outside-tuned` in the
  // source's demo). The library's RAW defaults render a sparse, dim halo of
  // separate blobs; the pulse-outside look everyone knows from
  // beam.jakubantalik.com layers this recipe on top: unit-scaled insets and
  // blurs (the ~20px core blur is what melts the blobs into one continuous
  // edge-hugging glow), ×1.71 layer opacities, brightness 1.3×1.71 and
  // saturation 1.2×1.71, and a 1.05 prominence boost. Baked in as the
  // Flutter defaults; every value stays overridable through the widget's
  // coreBlur/bloomBlur/glowBrightness/glowSaturation/glowBoost/opacity
  // hooks.
  static const double _tunedBoost = 1.05;
  static const double _tunedGlowMul = 1.71;
  static const double _tunedCoreInset = 6;
  static const double _tunedBloomInset = 14;
  static const double _tunedCoreBlur = 10;
  static const double _tunedBloomBlur = 19;

  @override
  double? get preferredFps => 30;

  double _sx(Size size) =>
      (size.width / referenceWidth).clamp(minScale, maxScale);
  double _sy(Size size) =>
      (size.height / referenceHeight).clamp(minScale, maxScale);

  // Halo reach/blur scale with element size relative to the demo's Subscribe
  // button baseline (measured glow scale 0.35), damped ×0.7
  // (`--sub-glow-unit`).
  double _unit(Size size) => _sx(size) / minScale * 0.7;

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
    final params = PulseParams.resolve(
      BeamVariant.pulseOutside,
      config.brightness,
      config.cycleSeconds,
    );
    final sx = _sx(size);
    final sy = _sy(size);
    final unit = _unit(size);
    final boost = config.glowBoost * _tunedBoost;
    final border = config.palette.data.border;

    // Filter ordering: CSS runs `blur()` before the color terms, and Skia
    // runs a paint's colorFilter BEFORE its imageFilter, so the color matrix
    // is composed explicitly after the blur (ImageFilter.compose runs
    // `inner` first).
    final glowMatrix = _matrix(
      config,
      phases,
      brightness: config.glowBrightness ?? 1.3 * _tunedGlowMul,
      saturation: config.glowSaturation ?? 1.2 * _tunedGlowMul,
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
      extra: _tunedGlowMul,
    );
    final coreBlur = config.coreBlur ?? _tunedCoreBlur * unit;
    if (coreOpacity > 0) {
      final coreRect = rect.inflate(_tunedCoreInset * unit);
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
      extra: _tunedGlowMul,
    );
    final bloomBlur = config.bloomBlur ?? _tunedBloomBlur * unit;
    if (bloomOpacity > 0) {
      final bloomRect = rect.inflate(_tunedBloomInset * unit);
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
      extra: _tunedGlowMul,
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
