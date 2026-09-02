import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_options.dart';
import 'package:flutter_border_beam/src/models/beam_segment.dart';
import 'package:flutter_border_beam/src/models/beam_shape.dart';
import 'package:flutter_border_beam/src/models/beam_style.dart';
import 'package:flutter_border_beam/src/models/beam_timing.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Enforces CLAUDE.md hard rule 2: the per-frame `saveLayer` budget.
///
/// Every `saveLayer` is an offscreen render target, so the count is the
/// single cheapest proxy for the cost of a beam frame. The budget below is
/// the measured count for a full frame (`paintBehind` + `paintAbove`) of each
/// variant; it must only ever go down.
void main() {
  // Measured maxima over every brightness × palette × time sample. Each entry
  // is one layer composite: the layers a variant stacks over the child, plus
  // the mask sub-layers that intersect two masks, plus (pulse-outside) the
  // two behind-child glow layers.
  //
  //   rotate       4 — inner + inner mask + stroke + blurred bloom
  //   small        3 — inner + stroke + blurred bloom (single-mask inner)
  //   line         4 — inner + inner mask + stroke + blurred bloom
  //   pulseInside  4 — inner + inner mask + stroke + blurred bloom
  //   pulseOutside 3 — behind: core glow + bloom halo; above: stroke
  const budget = <BeamVariant, int>{
    BeamVariant.rotate: 4,
    BeamVariant.small: 3,
    BeamVariant.line: 4,
    BeamVariant.pulseInside: 4,
    BeamVariant.pulseOutside: 3,
  };

  const size = ui.Size(350, 140);
  final palettes = {
    'colorful': BeamColors.colorful,
    'mono': BeamColors.mono,
    'custom': const BeamColors.custom([ui.Color(0xFFFF0080)]),
  };
  // Post fade-in samples spread over the cycle: mid-travel, the golden
  // freeze, and a late frame several cycles in.
  const samples = [0.5, 1.3, 7.9];

  for (final variant in BeamVariant.values) {
    test('$variant stays within its saveLayer budget', () {
      var worst = 0;
      var worstCase = '';
      for (final brightness in ui.Brightness.values) {
        for (final MapEntry(key: name, value: colors) in palettes.entries) {
          final config = BeamConfig.resolve(
            variant: variant,
            palette: colors.resolve(),
            brightness: brightness,
          );
          final resolver = BeamPhaseResolver(config);
          final strategy = strategyFor(variant);
          for (final t in samples) {
            final recorder = ui.PictureRecorder();
            final canvas = _CountingCanvas(ui.Canvas(recorder));
            final phases = resolver.sample(t, 1);
            strategy.paintBehind(canvas, size, config, phases);
            strategy.paintAbove(canvas, size, config, phases);
            recorder.endRecording().dispose();

            expect(
              canvas.unforwarded,
              isEmpty,
              reason:
                  'the counting canvas does not forward '
                  '${canvas.unforwarded.join(', ')} — add explicit '
                  'delegating overrides so painting is still exercised',
            );
            // Every layer and every clip scope must be closed, or the
            // painter would leak state into whatever draws next.
            expect(
              canvas.saves + canvas.saveLayers,
              canvas.restores,
              reason:
                  'unbalanced save/restore for $variant/$brightness/$name '
                  'at t=$t: ${canvas.saves} save + ${canvas.saveLayers} '
                  'saveLayer vs ${canvas.restores} restore',
            );
            if (canvas.saveLayers > worst) {
              worst = canvas.saveLayers;
              worstCase = '$brightness/$name at t=${t}s';
            }
          }
        }
      }
      // ignore: avoid_print
      print('$variant: max $worst saveLayer/frame ($worstCase)');
      expect(
        worst,
        budget[variant],
        reason:
            'the $variant frame now issues $worst saveLayer calls '
            '(worst case $worstCase). Fewer is a win — update the budget '
            'table. More is a regression: fold the new work into an '
            'existing layer.',
      );
    });
  }

  // Every Phase 3 surface option, measured against the SAME table. None of
  // them may buy its effect with a layer: the comet re-clips the bloom layer
  // it already had, the sparkles and the dash mask ride inside layers that
  // exist anyway, a wider glow only changes a blur sigma, extra beams and a
  // turned edge change geometry, and a contour changes which path the ring
  // is cut from.
  final scenarios =
      <String, ({BeamStyle style, BeamShape shape, BeamTiming timing})>{
        'comet': (
          style: const BeamStyle(comet: true),
          shape: const BeamShape(),
          timing: const BeamTiming(),
        ),
        'sparkle: 1': (
          style: const BeamStyle(sparkle: 1),
          shape: const BeamShape(),
          timing: const BeamTiming(),
        ),
        'segments: 8': (
          style: const BeamStyle(segments: 8),
          shape: const BeamShape(),
          timing: const BeamTiming(),
        ),
        'glowSpread: 2': (
          style: const BeamStyle(glowSpread: 2),
          shape: const BeamShape(),
          timing: const BeamTiming(),
        ),
        'tailLength: 2': (
          style: const BeamStyle(tailLength: 2),
          shape: const BeamShape(),
          timing: const BeamTiming(),
        ),
        'beamCount: 3': (
          style: const BeamStyle(),
          shape: const BeamShape(),
          timing: const BeamTiming(beamCount: 3),
        ),
        'direction: reverse': (
          style: const BeamStyle(),
          shape: const BeamShape(),
          timing: const BeamTiming(direction: BeamDirection.reverse),
        ),
        'edge: left': (
          style: const BeamStyle(),
          shape: const BeamShape(edge: BeamEdge.left),
          timing: const BeamTiming(),
        ),
        'ringOffset: 8': (
          style: const BeamStyle(),
          shape: const BeamShape(ringOffset: 8),
          timing: const BeamTiming(),
        ),
        'contour': (
          style: const BeamStyle(),
          shape: BeamShape(contour: _blobContour),
          timing: const BeamTiming(),
        ),
        'segment: bottomHalf': (
          style: const BeamStyle(),
          shape: const BeamShape(segment: BeamSegment.bottomHalf),
          timing: const BeamTiming(),
        ),
        'segment: bottomEdge': (
          style: const BeamStyle(),
          shape: const BeamShape(segment: BeamSegment.bottomEdge),
          timing: const BeamTiming(),
        ),
        'segment feather: 0': (
          style: const BeamStyle(),
          shape: const BeamShape(
            segment: BeamSegment(
              start: BeamAnchor.rightCenter,
              end: BeamAnchor.leftCenter,
              feather: 0,
            ),
          ),
          timing: const BeamTiming(),
        ),
        'line wrapCorners': (
          style: const BeamStyle(),
          shape: const BeamShape(wrapCorners: true),
          timing: const BeamTiming(),
        ),
        // renderScale is one canvas transform inside BeamPainter, so a
        // strategy frame is the same frame; innerSizeScale only resizes
        // blobs a layer already holds; and the stock pulse-outside table
        // only moves insets and blur sigmas.
        'renderScale: 0.5': (
          style: const BeamStyle(renderScale: 0.5),
          shape: const BeamShape(),
          timing: const BeamTiming(),
        ),
        'innerSizeScale: 0.6': (
          style: const BeamStyle(innerSizeScale: 0.6),
          shape: const BeamShape(),
          timing: const BeamTiming(),
        ),
        'pulseOutsideStock': (
          style: BeamStyle.pulseOutsideStock,
          shape: const BeamShape(),
          timing: const BeamTiming(),
        ),
      };

  for (final MapEntry(key: label, value: scenario) in scenarios.entries) {
    for (final variant in BeamVariant.values) {
      test('$variant with $label stays within its saveLayer budget', () {
        var worst = 0;
        var worstCase = '';
        for (final brightness in ui.Brightness.values) {
          final config = BeamConfig.resolve(
            variant: variant,
            palette: BeamColors.colorful.resolve(),
            brightness: brightness,
            style: scenario.style,
            shape: scenario.shape,
            timing: scenario.timing,
          );
          final resolver = BeamPhaseResolver(config);
          final strategy = strategyFor(variant);
          for (final t in samples) {
            final recorder = ui.PictureRecorder();
            final canvas = _CountingCanvas(ui.Canvas(recorder));
            final phases = resolver.sample(t, 1);
            strategy.paintBehind(canvas, size, config, phases);
            strategy.paintAbove(canvas, size, config, phases);
            recorder.endRecording().dispose();

            expect(canvas.unforwarded, isEmpty);
            expect(
              canvas.saves + canvas.saveLayers,
              canvas.restores,
              reason:
                  'unbalanced save/restore for $variant/$label/$brightness '
                  'at t=$t',
            );
            if (canvas.saveLayers > worst) {
              worst = canvas.saveLayers;
              worstCase = '$brightness at t=${t}s';
            }
          }
        }
        expect(
          worst,
          budget[variant],
          reason:
              '$label changed the $variant frame to $worst saveLayer calls '
              '(worst case $worstCase). A surface option must use exactly '
              'the layers the variant already composites.',
        );
      });
    }
  }
}

/// A lobed contour: enough of a departure from a rounded rect to exercise the
/// offset path, and value-equal so the config caches it.
final _blobContour = BeamPathContour((rect) {
  final path = Path();
  final centre = rect.center;
  for (var i = 0; i <= 48; i++) {
    final a = i / 48 * 2 * math.pi;
    final r = rect.shortestSide / 2 * (0.75 + 0.25 * (i % 8 < 4 ? 1 : 0));
    final p = Offset(
      centre.dx + r * 1.6 * math.cos(a),
      centre.dy + r * math.sin(a),
    );
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}, key: 'budget-blob');

/// A [ui.Canvas] that counts layer and clip scopes while forwarding the draw
/// calls to a real canvas, so the painters run exactly as they do on screen.
///
/// Everything the strategies call is delegated explicitly; anything else
/// lands in [unforwarded] via `noSuchMethod` so a new draw call fails the
/// test loudly instead of silently going unpainted.
class _CountingCanvas implements ui.Canvas {
  _CountingCanvas(this._inner);

  final ui.Canvas _inner;

  int saves = 0;
  int saveLayers = 0;
  int restores = 0;
  final Set<String> unforwarded = <String>{};

  @override
  void save() {
    saves++;
    _inner.save();
  }

  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    saveLayers++;
    _inner.saveLayer(bounds, paint);
  }

  @override
  void restore() {
    restores++;
    _inner.restore();
  }

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) =>
      _inner.clipPath(path, doAntiAlias: doAntiAlias);

  @override
  void clipRect(
    ui.Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => _inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => _inner.drawRect(rect, paint);

  @override
  void drawPath(ui.Path path, ui.Paint paint) => _inner.drawPath(path, paint);

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) =>
      _inner.drawCircle(c, radius, paint);

  @override
  void translate(double dx, double dy) => _inner.translate(dx, dy);

  @override
  void scale(double sx, [double? sy]) => _inner.scale(sx, sy);

  @override
  void rotate(double radians) => _inner.rotate(radians);

  @override
  void transform(Float64List matrix4) => _inner.transform(matrix4);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unforwarded.add(_symbolName(invocation.memberName));
    return null;
  }
}

String _symbolName(Symbol symbol) {
  final text = symbol.toString();
  final start = text.indexOf('"');
  final end = text.lastIndexOf('"');
  return start >= 0 && end > start ? text.substring(start + 1, end) : text;
}
