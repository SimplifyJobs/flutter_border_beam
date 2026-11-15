import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../animation/beam_phases.dart';
import '../effects/effect_emitters.dart';
import '../models/beam_config.dart';
import 'beam_emission.dart';
import 'beam_outline.dart';
import 'beam_program.dart';
import 'color_math.dart';

/// Number of floats the shader's uniforms occupy (see `shaders/beam.frag`).
const int beamUniformFloats = 248;

/// Paints beam frames with the shared shader.
///
/// One renderer per beam: it owns a `FragmentShader` (reused every frame, its
/// uniforms rewritten in place), a `Paint`, and a [BeamEmission], so a frame
/// allocates almost nothing. A frame is one `drawDRRect` — the ring of the
/// canvas where light can reach — with no layers, clips, or filters.
class BeamRenderer {
  ui.FragmentShader? _shader;
  final Paint _paint = Paint()..isAntiAlias = false;
  final BeamEmission _emission = BeamEmission();
  final List<Color> _colors = <Color>[];
  BeamOutline? _outline;

  /// The emission of the last painted frame, for tests.
  BeamEmission get debugEmission => _emission;

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

    final palette = config.palette;
    final hue = phases.hueDegrees + config.hueBase;
    _colors.clear();
    for (final c in palette.colors) {
      _colors.add(hueRotate(c, hue));
    }

    final e = _emission..reset();
    applySegment(e, config.segment, outline);
    emitEffect(
      e,
      BeamFrame(
        config: config,
        phases: phases,
        outline: outline,
        colors: _colors,
        stops: palette.stops,
      ),
    );

    final shader = _shader ??= program.fragmentShader();
    final px = 1 / math.max(devicePixelRatio * _canvasScale(canvas), 0.25);
    _pack(shader, outline, config, e, _colors, alpha, px);

    // Fragment work only where light can land: the box grown by the furthest
    // outward reach, minus the interior beyond the furthest inward reach.
    final w = config.borderWidth;
    var outside = 2.0;
    if (e.bloom > 0 && e.bloomSide != BeamSide.inside) {
      outside = math.max(outside, 3 * e.bloomSigma + 2);
    }
    if (e.outer > 0) {
      outside = math.max(outside, e.outerPlateau + e.outerReach + 2);
    }
    if (e.lights > 0) outside = math.max(outside, e.lightReachOutside + 2);
    var inside = w + 2;
    if (e.bloom > 0 && e.bloomSide != BeamSide.outside) {
      inside = math.max(inside, 3 * e.bloomSigma + w + 2);
    }
    if (e.lights > 0) inside = math.max(inside, e.lightReachInside + 2);
    if (e.sweepAmplitude > 0) inside = math.max(inside, w + 3 * e.bloomSigma);
    final maxCorner = outline.cornerSizes.reduce(math.max);
    final hole = math.max(inside, inside / math.sqrt2 + 0.3 * maxCorner);
    _paint.shader = shader;
    final outer = rect.inflate(outside);
    if (2 * hole >= rect.shortestSide) {
      canvas.drawRect(outer, _paint);
    } else {
      canvas.drawDRRect(
        RRect.fromRectAndRadius(outer, Radius.zero),
        RRect.fromRectAndRadius(rect.deflate(hole), Radius.zero),
        _paint,
      );
    }
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

  static void _pack(
    ui.FragmentShader s,
    BeamOutline o,
    BeamConfig config,
    BeamEmission e,
    List<Color> colors,
    double opacity,
    double px,
  ) {
    var i = 0;
    void f(double v) => s.setFloat(i++, v);
    void v4(double a, double b, double c, double d) {
      f(a);
      f(b);
      f(c);
      f(d);
    }

    final r = o.rect;
    v4(r.left, r.top, r.width, r.height);
    v4(o.radii[0], o.radii[1], o.radii[2], o.radii[3]);
    v4(o.inset, o.exponent, config.borderWidth, px);
    v4(o.length, o.arcFactor, switch (e.bloomSide) {
      BeamSide.inside => -1,
      BeamSide.both => 0,
      BeamSide.outside => 1,
    }, 1);
    v4(o.quadStarts[0], o.quadStarts[1], o.quadStarts[2], o.quadStarts[3]);
    v4(e.stroke, e.bloom, e.outer, e.lights);
    v4(e.bloomSigma, e.outerReach, e.outerPlateau, e.outerWiden);
    v4(1, 1, 1, e.highlight);
    v4(e.base, e.bumpCount.toDouble(), opacity, e.additive);
    v4(
      e.noiseAmplitude,
      e.noiseFrequency,
      e.noisePhase,
      e.lightCount.toDouble(),
    );
    v4(
      e.segmentStart,
      e.segmentSpan,
      e.segmentFeather,
      config.dashes.toDouble(),
    );
    final stops = config.palette.stops;
    v4(
      e.colorOrigin,
      e.colorScale,
      e.colorWrap ? 1 : 0,
      colors.length.toDouble(),
    );
    v4(
      e.sweepDirection.dx,
      e.sweepDirection.dy,
      e.sweepPosition,
      e.sweepHalfWidth,
    );
    v4(e.sweepAmplitude, e.bumpPlateau, config.isDark ? 0 : 1, 0);
    for (var k = 0; k < beamSlots * 4; k++) {
      f(e.bumps[k]);
    }
    for (var k = 0; k < beamSlots; k++) {
      final c = k < colors.length ? colors[k] : const Color(0x00000000);
      v4(c.r, c.g, c.b, c.a);
    }
    for (var k = 0; k < beamSlots; k++) {
      v4(k < stops.length ? stops[k] : 1, 0, 0, 0);
    }
    for (var k = 0; k < beamSlots * 4; k++) {
      f(e.lightPos[k]);
    }
    for (var k = 0; k < beamSlots * 4; k++) {
      f(e.lightShape[k]);
    }
    for (var k = 0; k < beamSlots * 4; k++) {
      f(e.lightColor[k]);
    }
    assert(i == beamUniformFloats, 'packed $i floats');
  }

  /// Releases the shader.
  void dispose() {
    _shader?.dispose();
    _shader = null;
  }
}
