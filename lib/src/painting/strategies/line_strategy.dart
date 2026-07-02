import 'dart:ui';

import '../../animation/beam_phases.dart';
import '../../models/beam_blob.dart';
import '../../models/beam_config.dart';
import '../color_matrix.dart';
import '../gradient_builders.dart';
import '../layer_utils.dart';
import '../ring_geometry.dart';
import '../variant_strategy.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

/// The bottom-edge traveling beam (React `line`): all masks are radial
/// windows anchored at the traveling x position on the bottom edge, plus a
/// bloom of fixed spikes that shimmer via two counter-phased scale tracks.
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
    if (phases.fadeOpacity <= 0 || phases.edge <= 0) return;
    final rect = Offset.zero & size;
    final geometry = BeamRingGeometry(
      rect: rect,
      radius: config.borderRadius,
      borderWidth: config.borderWidth,
      useSuperellipse: config.useSuperellipse,
    );
    final isDark = config.brightness == Brightness.dark;

    final layerMatrix = config.staticColors
        ? null
        : BeamColorMatrix.beamFilter(
            hueDegrees: phases.hueDegrees + config.hueBase,
            brightness: config.brightnessFactor,
            saturation: config.saturation,
          );
    Color fold(Color c) => layerMatrix?.transform(c) ?? c;

    _paintInner(canvas, rect, geometry, config, phases, fold);
    _paintStroke(canvas, rect, geometry, config, phases, fold, isDark);
    _paintBloom(canvas, rect, geometry, config, phases, isDark);
  }

  Offset _beamAnchor(Rect rect, BeamFramePhases phases, {double dy = 0}) =>
      Offset(rect.left + phases.lineX * rect.width, rect.bottom + dy);

  void _paintInner(
    Canvas canvas,
    Rect rect,
    BeamRingGeometry geometry,
    BeamConfig config,
    BeamFramePhases phases,
    Color Function(Color) fold,
  ) {
    // The line variant does not apply the mono ×0.5 multiplier — its mono
    // treatment lives in the bloom spike attenuation.
    final opacity =
        (phases.fadeOpacity *
                phases.edge *
                config.theme.innerOpacity *
                config.innerOpacityFactor *
                config.strength)
            .clamp(0.0, 1.0);
    if (opacity <= 0) return;

    canvas.save();
    canvas.clipPath(geometry.outer);
    canvas.saveLayer(rect, Paint()..color = _white.withValues(alpha: opacity));

    for (final blob in config.palette.data.lineInner) {
      BeamGradients.paintBlob(
        canvas,
        center: Offset(
          rect.left + phases.lineX * rect.width + blob.offsetX,
          rect.bottom - blob.offsetY.abs(),
        ),
        radiusX: blob.sizeW * phases.lineW,
        radiusY: blob.sizeH * phases.lineH,
        color: fold(blob.color),
      );
    }
    BeamLayerUtils.paintInnerShadow(
      canvas,
      contour: geometry.outer,
      color: fold(config.theme.innerShadow),
      blur: 9,
    );

    // Mask: (featherV ∪ featherH) ∩ radial window.
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
        ..shader = BeamGradients.radialWindow(
          center: _beamAnchor(rect, phases),
          radiusX: 78 * phases.lineW,
          radiusY: 60 * phases.lineH,
          midStop: 0.45,
          midAlpha: 0.5,
        ),
    );
    canvas.restore();

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
    final opacity =
        (phases.fadeOpacity *
                phases.edge *
                config.theme.strokeOpacity *
                config.strokeOpacityFactor *
                config.strength)
            .clamp(0.0, 1.0);
    if (opacity <= 0) return;

    canvas.save();
    canvas.clipPath(geometry.ring);
    canvas.saveLayer(rect, Paint()..color = _white.withValues(alpha: opacity));

    // White (dark) / black (light) traveling highlight.
    if (isDark) {
      BeamLayerUtils.paintRadial(
        canvas,
        center: _beamAnchor(rect, phases, dy: 2),
        radiusX: 24 * phases.lineW,
        radiusY: 28 * phases.lineH,
        colors: [
          fold(_white.withValues(alpha: 0.38)),
          fold(_white.withValues(alpha: 0.12)),
          fold(_white.withValues(alpha: 0)),
        ],
        stops: const [0, 0.30, 0.65],
      );
    } else {
      BeamLayerUtils.paintRadial(
        canvas,
        center: _beamAnchor(rect, phases, dy: 2),
        radiusX: 35 * phases.lineW,
        radiusY: 28 * phases.lineH,
        colors: [
          fold(_black.withValues(alpha: 0.6)),
          fold(_black.withValues(alpha: 0.25)),
          fold(_black.withValues(alpha: 0)),
        ],
        stops: const [0, 0.35, 0.70],
      );
    }
    final blobs = isDark
        ? config.palette.data.lineDark
        : config.palette.data.lineLight;
    for (final blob in blobs) {
      BeamGradients.paintBlob(
        canvas,
        center: Offset(
          rect.left + phases.lineX * rect.width + blob.offsetX,
          rect.bottom + blob.offsetY,
        ),
        radiusX: blob.sizeW * phases.lineW,
        radiusY: blob.sizeH * phases.lineH,
        color: fold(blob.color),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = BeamGradients.radialWindow(
          center: _beamAnchor(rect, phases),
          radiusX: 78 * phases.lineW,
          radiusY: 60 * phases.lineH,
          midStop: 0.45,
          midAlpha: 0.5,
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
    final opacity =
        (phases.fadeOpacity *
                phases.edge *
                config.theme.bloomOpacity *
                config.bloomOpacityFactor *
                config.strength)
            .clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final mono = config.palette.monoTreatment;
    // Bloom filter: blur(8) + hue(range+10) when animating; blur(6) for
    // mono; no filter when static non-mono (matching the generated CSS).
    final blurSigma = mono ? 6.0 : (config.staticColors ? 0.0 : 8.0);
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
    canvas.saveLayer(rect, layerPaint);

    _paintSpikes(canvas, rect, config, phases, isDark, mono, fold);

    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = BeamGradients.radialWindow(
          center: _beamAnchor(rect, phases),
          radiusX: 84 * phases.lineW,
          radiusY: 110 * phases.lineH,
          midStop: 0.35,
          midAlpha: 0.5,
        ),
    );

    canvas.restore();
    canvas.restore();
  }

  // The fixed bloom spikes at 8/22/36/50/64/78/92% of the bottom edge, plus
  // the traveling dot/ambient (dark) or shadow blob (light). Transcribed
  // from getLineBloomGradients.
  void _paintSpikes(
    Canvas canvas,
    Rect rect,
    BeamConfig config,
    BeamFramePhases phases,
    bool isDark,
    bool mono,
    Color Function(Color) fold,
  ) {
    final palette = config.palette.data;
    final spikeColors = isDark ? palette.spike : palette.spikeLt;
    final table = isDark ? palette.lineBloomDark : palette.lineBloomLight;

    Color att(Color c, double f) => BeamLayerUtils.attenuateSpike(c, f);
    final sc1 = mono ? att(spikeColors.primary, 0.14) : spikeColors.primary;
    final sc1MidDark = mono
        ? att(spikeColors.primary, 0.09)
        : spikeColors.primary;
    final sc1MidLight = mono
        ? att(spikeColors.primary, 0.11)
        : BeamLayerUtils.withAlpha(spikeColors.primary, 0.85);
    final sc2 = mono ? att(spikeColors.secondary, 0.12) : spikeColors.secondary;
    final sc2MidDark = mono
        ? BeamLayerUtils.withAlpha(spikeColors.secondary, 0.06)
        : BeamLayerUtils.withAlpha(spikeColors.secondary, 0.49);
    final sc2MidLight = mono
        ? att(spikeColors.secondary, 0.09)
        : BeamLayerUtils.withAlpha(spikeColors.secondary, 0.7);
    SpikePair spikeAt(int i) => mono
        ? SpikePair(
            att(table[i].color1, 0.14),
            att(table[i].color2, 0.14 * 0.7),
          )
        : table[i];

    // Mono widens and shortens the thin spikes into a soft glow.
    final thinW1 = mono ? 12.0 : 0.8;
    final thinW2 = mono ? 14.0 : 2.0;
    final thinW3 = mono ? 12.0 : 1.2;
    final thinW4 = mono ? 10.0 : 0.6;
    final thinLW = mono ? 12.0 : 1.0;
    final thinH1 = mono ? 42.0 : 92.0;
    final thinH2 = mono ? 38.0 : 72.0;
    final thinH3 = mono ? 40.0 : 85.0;
    final thinH4 = mono ? 32.0 : 60.0;

    void spike({
      required double fx,
      required double yInset,
      required double rx,
      required double ry,
      required Color c0,
      required Color cMid,
      required double midStop,
      required double endStop,
    }) {
      BeamLayerUtils.paintRadial(
        canvas,
        center: Offset(rect.left + fx * rect.width, rect.bottom - yInset),
        radiusX: rx,
        radiusY: ry,
        colors: [fold(c0), fold(cMid), fold(cMid.withValues(alpha: 0))],
        stops: [0, midStop, endStop],
      );
    }

    final s = phases.spike;
    final s2 = phases.spike2;
    final h = phases.lineH;

    spike(
      fx: 0.08,
      yInset: 2,
      rx: thinW1 * s,
      ry: thinH1 * h,
      c0: sc1,
      cMid: isDark ? sc1MidDark : sc1MidLight,
      midStop: 0.30,
      endStop: 0.88,
    );
    spike(
      fx: 0.22,
      yInset: 4,
      rx: 10 * s2,
      ry: 35 * h,
      c0: sc2,
      cMid: isDark ? sc2MidDark : sc2MidLight,
      midStop: 0.50,
      endStop: 0.95,
    );
    spike(
      fx: 0.36,
      yInset: 3,
      rx: thinW2 * (2 - s),
      ry: thinH2 * h,
      c0: spikeAt(0).color1,
      cMid: spikeAt(0).color2,
      midStop: 0.40,
      endStop: 0.90,
    );
    spike(
      fx: 0.50,
      yInset: 2,
      rx: 14 * s2,
      ry: 28 * h,
      c0: spikeAt(1).color1,
      cMid: spikeAt(1).color2,
      midStop: 0.55,
      endStop: 0.96,
    );
    spike(
      fx: 0.64,
      yInset: 4,
      rx: thinW3 * (2 - s2),
      ry: thinH3 * h,
      c0: spikeAt(2).color1,
      cMid: spikeAt(2).color2,
      midStop: 0.35,
      endStop: 0.89,
    );
    spike(
      fx: 0.78,
      yInset: 2,
      rx: 7 * s,
      ry: 45 * h,
      c0: spikeAt(3).color1,
      cMid: spikeAt(3).color2,
      midStop: 0.48,
      endStop: 0.94,
    );
    spike(
      fx: 0.92,
      yInset: 3,
      rx: (isDark ? thinW4 : thinLW) * (2 - s),
      ry: thinH4 * h,
      c0: spikeAt(4).color1,
      cMid: spikeAt(4).color2,
      midStop: 0.42,
      endStop: 0.91,
    );

    if (isDark) {
      // Traveling dot + ambient glow.
      final dotC = _white.withValues(alpha: mono ? 0.5 : 1.0);
      final dot20 = _white.withValues(alpha: mono ? 0.45 : 0.9);
      final dot50 = _white.withValues(alpha: mono ? 0.25 : 0.5);
      BeamLayerUtils.paintRadial(
        canvas,
        center: _beamAnchor(rect, phases, dy: 1),
        radiusX: 21 * s,
        radiusY: 15 * s2,
        colors: [
          fold(dotC),
          fold(dot20),
          fold(dot50),
          fold(dot50.withValues(alpha: 0)),
        ],
        stops: const [0, 0.20, 0.50, 1.0],
      );
      final ambC = _white.withValues(alpha: mono ? 0.15 : 0.3);
      final amb25 = _white.withValues(alpha: mono ? 0.06 : 0.12);
      final amb55 = _white.withValues(alpha: mono ? 0.015 : 0.03);
      BeamLayerUtils.paintRadial(
        canvas,
        center: _beamAnchor(rect, phases),
        radiusX: 42 * phases.lineW,
        radiusY: 40 * h,
        colors: [
          fold(ambC),
          fold(amb25),
          fold(amb55),
          fold(amb55.withValues(alpha: 0)),
        ],
        stops: const [0, 0.25, 0.55, 0.80],
      );
    } else {
      // Light theme: a traveling dark shadow blob instead of the bright dot.
      BeamLayerUtils.paintRadial(
        canvas,
        center: _beamAnchor(rect, phases),
        radiusX: 50 * phases.lineW,
        radiusY: 32 * h,
        colors: [
          fold(_black.withValues(alpha: 0.5)),
          fold(_black.withValues(alpha: 0.18)),
          fold(_black.withValues(alpha: 0.03)),
          fold(_black.withValues(alpha: 0)),
        ],
        stops: const [0, 0.30, 0.60, 0.85],
      );
    }
  }
}
