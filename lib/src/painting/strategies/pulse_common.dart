import 'dart:ui';

import '../../animation/oscillator.dart';
import '../../models/beam_blob.dart';
import '../gradient_builders.dart';

/// Resolves a [PulseQuad] to its animated opacity factor.
double quadOpacity(PulsePhaseSet pulse, PulseQuad quad) => switch (quad) {
  PulseQuad.tl => pulse.bopTl,
  PulseQuad.tr => pulse.bopTr,
  PulseQuad.bl => pulse.bopBl,
  PulseQuad.br => pulse.bopBr,
};

/// Paints one breathing pulse blob (the source's `pulseGrad`):
/// width = `w · bw[region] · sx · boost`, height = `h · bh[region] · bgh ·
/// sy · boost`, position = base + region drift, alpha = quadrant factor.
void paintPulseBlob(
  Canvas canvas, {
  required Rect rect,
  required Color color,
  required Offset fractionalPos,
  required double w,
  required double h,
  required PulseRegion region,
  required PulseQuad quad,
  required PulsePhaseSet pulse,
  required double sx,
  required double sy,
  required double boost,
  required Color Function(Color) fold,
  double alphaScale = 1,
}) {
  if (alphaScale <= 0) return;
  final r = region.index;
  BeamGradients.paintBlob(
    canvas,
    center: Offset(
      rect.left + fractionalPos.dx * rect.width + pulse.bx[r],
      rect.top + fractionalPos.dy * rect.height + pulse.by[r],
    ),
    radiusX: w * pulse.bw[r] * sx * boost,
    radiusY: h * pulse.bh[r] * pulse.bgh * sy * boost,
    color: fold(color),
    alpha: quadOpacity(pulse, quad) * alphaScale,
  );
}

/// Paints one frozen (non-breathing) pulse blob, as used by the pulse bloom
/// layers (the source's `pulseTableGradientsStatic`): geometry scaled only
/// by sx/sy/boost, alpha fixed at the breathing time-average.
void paintFrozenPulseBlob(
  Canvas canvas, {
  required Rect rect,
  required Color color,
  required Offset fractionalPos,
  required double w,
  required double h,
  required double frozenAlpha,
  required double sx,
  required double sy,
  required double boost,
  required Color Function(Color) fold,
  double alphaScale = 1,
}) {
  if (alphaScale <= 0) return;
  BeamGradients.paintBlob(
    canvas,
    center: Offset(
      rect.left + fractionalPos.dx * rect.width,
      rect.top + fractionalPos.dy * rect.height,
    ),
    radiusX: w * sx * boost,
    radiusY: h * sy * boost,
    color: fold(color.withValues(alpha: frozenAlpha * alphaScale)),
  );
}
