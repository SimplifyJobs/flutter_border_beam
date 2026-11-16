import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../animation/beam_phases.dart';
import '../effects/effect_emitters.dart';
import '../models/beam_config.dart';
import 'beam_frame.dart';
import 'beam_outline.dart';
import 'beam_program.dart';

export 'beam_frame.dart' show beamUniformFloats;

/// Paints beam frames with the shared shader.
///
/// One renderer per beam: it owns a `FragmentShader` (reused every frame, its
/// uniforms rewritten in place), a `Paint`, and a [BeamFrameData], so a frame
/// allocates almost nothing. A frame is one `drawDRRect` — the ring of the
/// canvas where light can reach — with no layers, clips, or filters.
class BeamRenderer {
  ui.FragmentShader? _shader;
  final Paint _paint = Paint()..isAntiAlias = false;
  final BeamFrameData _frame = BeamFrameData();
  BeamOutline? _outline;

  /// The uniforms of the last painted frame, for tests.
  BeamFrameData get debugFrame => _frame;

  /// Whether the shader program is available yet.
  bool get isReady => BeamProgram.program != null;

  /// Paints one frame of [config] at [phases] over [box] (the child's
  /// bounds in canvas coordinates).
  ///
  /// [opacity] multiplies the whole frame (fade × boost × live strength
  /// travel in [phases]; this is anything on top). [devicePixelRatio] sets the
  /// anti-aliasing width; the canvas's own scale is folded in.
  void paint(
    Canvas canvas,
    Rect box,
    BeamConfig config,
    BeamFramePhases phases, {
    required double devicePixelRatio,
    double opacity = 1,
  }) {
    final program = BeamProgram.program;
    if (program == null) return;
    final alpha = phases.fadeOpacity * config.strength * opacity;
    if (alpha <= 0) return;
    final rect = box.inflate(config.ringOffset);
    if (rect.width < 1 || rect.height < 1) return;

    final outline = _outlineFor(rect, config);
    if (outline.length <= 0) return;

    final px = 1 / math.max(devicePixelRatio * _canvasScale(canvas), 0.25);
    final d = _frame..reset();
    d.setOutline(outline, config.borderWidth, px);
    applyTrack(d, config.segment, outline, config.dashes);
    emitEffect(
      BeamFrame(
        config: config,
        phases: phases,
        outline: outline,
        data: d,
        alpha: alpha,
      ),
    );
    d.finish();
    _measure(d, config.borderWidth);
    var lit = false;
    for (var k = 0; k < beamLayerCount; k++) {
      if (d.geometryOf(k) != BeamGeometry.none && d.opacityOf(k) > 0) {
        lit = true;
      }
    }
    if (!lit) return;

    final shader = _shader ??= program.fragmentShader();
    final data = d.data;
    for (var i = 0; i < beamUniformFloats; i++) {
      shader.setFloat(i, data[i]);
    }

    // Fragment work only where light can land: the box grown by the furthest
    // outward reach, minus the interior beyond the furthest inward reach.
    _paint.shader = shader;
    final outer = rect.inflate(d.reachOutside + 2);
    final inside = d.reachInside + 2;
    final maxCorner = outline.cornerSizes.reduce(math.max);
    final hole = math.max(inside, inside / math.sqrt2 + 0.3 * maxCorner);
    if (!hole.isFinite || 2 * hole >= rect.shortestSide) {
      canvas.drawRect(outer, _paint);
    } else {
      canvas.drawDRRect(
        RRect.fromRectAndRadius(outer, Radius.zero),
        RRect.fromRectAndRadius(rect.deflate(hole), Radius.zero),
        _paint,
      );
    }
  }

  // How far the frame's layers reach either side of the outline.
  static void _measure(BeamFrameData d, double borderWidth) {
    var outside = 0.0;
    var inside = borderWidth + 1;
    for (var k = 0; k < beamLayerCount; k++) {
      if (d.opacityOf(k) <= 0) continue;
      final sigma = d.sigmaOf(k);
      switch (d.geometryOf(k)) {
        case BeamGeometry.none:
          break;
        case BeamGeometry.ring:
          break;
        case BeamGeometry.fill:
          final edge = d.edgeFadeOf(k);
          inside = math.max(inside, edge > 0 ? edge + 1 : double.infinity);
        case BeamGeometry.blurredRing:
          inside = math.max(inside, 3 * sigma + borderWidth);
        case BeamGeometry.glow:
          outside = math.max(outside, d.inflateOf(k) + 3 * sigma);
      }
    }
    d
      ..reachOutside = outside
      ..reachInside = inside;
  }

  BeamOutline _outlineFor(Rect rect, BeamConfig config) {
    final cached = _outline;
    if (cached != null &&
        cached.rect == rect &&
        cached.superellipse == config.superellipse &&
        _outlineRadius == config.borderRadius) {
      return cached;
    }
    _outlineRadius = config.borderRadius;
    return _outline = BeamOutline(
      rect,
      config.borderRadius,
      superellipse: config.superellipse,
    );
  }

  // The radius the cached outline was built from.
  BorderRadius? _outlineRadius;

  // The canvas's own scale (a Transform painted into the same layer), so the
  // anti-aliasing width stays one device pixel under it.
  static double _canvasScale(Canvas canvas) {
    final m = canvas.getTransform();
    final sx = math.sqrt(m[0] * m[0] + m[1] * m[1]);
    final sy = math.sqrt(m[4] * m[4] + m[5] * m[5]);
    final s = math.sqrt(sx * sy);
    return s.isFinite && s > 0 ? s : 1;
  }

  /// Releases the shader.
  void dispose() {
    _shader?.dispose();
    _shader = null;
  }
}
