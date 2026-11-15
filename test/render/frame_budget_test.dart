import 'dart:ui' as ui;
import 'dart:ui' show Brightness;

import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/render/beam_frame.dart';
import 'package:flutter_border_beam/src/render/beam_program.dart';
import 'package:flutter_border_beam/src/render/beam_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render_utils.dart';

/// The renderer's cost contract: a beam frame is ONE draw call with the beam
/// shader — no `saveLayer` (no offscreen target), no clip, no image or mask
/// filter (no blur pass) — and it leaves the canvas state as it found it.
///
/// Every effect is measured across both themes, a palette subset, every shape
/// family, and several instants. A frame the fade or a cycle gap has blacked
/// out issues no draw at all; any other frame issues exactly one.
void main() {
  setUpAll(() async {
    await BorderBeam.precache();
    expect(
      BeamProgram.program,
      isNotNull,
      reason: 'the budget is only meaningful with the shader loaded',
    );
  });

  // Mid-sweep, the golden instant, late in a gap-carrying period, and several
  // cycles in.
  const instants = [0.3, 1.3, 2.05, 7.9];

  // Whether the frame had light to draw: the fade and strength let some
  // through, and the effect lit a layer (an empty charge lights none).
  bool litFrame(BeamRenderer renderer, BeamConfig config, double fade) {
    if (fade * config.strength <= 0) return false;
    final d = renderer.debugFrame;
    for (var k = 0; k < beamLayerCount; k++) {
      if (d.geometryOf(k) != BeamGeometry.none && d.opacityOf(k) > 0) {
        return true;
      }
    }
    return false;
  }

  void expectBudget(
    RecordingCanvas canvas,
    BeamConfig config,
    double fade,
    String label, {
    required bool lit,
  }) {
    expect(
      canvas.unforwarded,
      isEmpty,
      reason:
          '$label: the frame called ${canvas.unforwarded.join(', ')}, which '
          'the recording canvas does not count — a new kind of call needs an '
          'explicit override here',
    );
    expect(canvas.saveLayers, 0, reason: '$label: saveLayer');
    expect(canvas.clips, 0, reason: '$label: clip');
    expect(canvas.saves, canvas.restores, reason: '$label: save/restore');
    expect(
      canvas.draws,
      lit ? hasLength(1) : isEmpty,
      reason: '$label: ${canvas.draws}',
    );
    for (final draw in canvas.draws) {
      expect(draw, anyOf('drawRect', 'drawDRRect'), reason: label);
    }
    for (final paint in canvas.paints) {
      expect(paint.shader, isA<ui.FragmentShader>(), reason: label);
      expect(paint.imageFilter, isNull, reason: '$label: imageFilter');
      expect(paint.maskFilter, isNull, reason: '$label: maskFilter');
    }
  }

  for (final MapEntry(key: name, value: effect) in effectsByName.entries) {
    test('$name: one draw, no layers, clips, or filters', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final brightness in Brightness.values) {
        for (final MapEntry(key: palette, value: colors)
            in paletteSubset.entries) {
          final config = configFor(
            effect,
            brightness: brightness,
            colors: colors,
          );
          for (final t in instants) {
            final phases = phasesAt(config, t);
            final canvas = recordFrame(renderer, config, phases);
            expectBudget(
              canvas,
              config,
              phases.fadeOpacity,
              '$name/${brightness.name}/$palette at ${t}s',
              lit: litFrame(renderer, config, phases.fadeOpacity),
            );
          }
        }
      }
    });

    test('$name: every shape family keeps the budget', () {
      final renderer = BeamRenderer();
      addTearDown(renderer.dispose);
      for (final MapEntry(key: label, value: shape) in shapeVariety.entries) {
        final config = configFor(effect, shape: shape);
        for (final t in instants) {
          final phases = phasesAt(config, t);
          expectBudget(
            recordFrame(renderer, config, phases),
            config,
            phases.fadeOpacity,
            '$name/$label at ${t}s',
            lit: litFrame(renderer, config, phases.fadeOpacity),
          );
        }
      }
    });
  }

  test('effect options keep the budget', () {
    final options = <String, BeamEffect>{
      'rotate comet': const BeamEffect.rotate(comet: true),
      'rotate count 4': const BeamEffect.rotate(count: 4),
      'rotate long tail': const BeamEffect.rotate(length: 2),
      'line top': const BeamEffect.line(edge: BeamEdge.top),
      'line left': const BeamEffect.line(edge: BeamEdge.left),
      'shimmer 75°': const BeamEffect.shimmer(angle: 75),
    };
    final renderer = BeamRenderer();
    addTearDown(renderer.dispose);
    for (final MapEntry(key: label, value: effect) in options.entries) {
      for (final glow in [0.0, 1.0, 2.5]) {
        final config = configFor(effect, style: BeamStyle(glow: glow));
        for (final t in instants) {
          final phases = phasesAt(config, t);
          expectBudget(
            recordFrame(renderer, config, phases),
            config,
            phases.fadeOpacity,
            '$label, glow $glow at ${t}s',
            lit: litFrame(renderer, config, phases.fadeOpacity),
          );
        }
      }
    }
  });

  test('a driven sweep keeps the budget at every progress', () {
    final renderer = BeamRenderer();
    addTearDown(renderer.dispose);
    for (final effect in BeamEffect.values.where((e) => e.travels)) {
      final config = configFor(effect);
      for (final progress in [0.0, 0.001, 0.25, 0.5, 0.999, 1.0]) {
        final phases = phasesAt(config, 1.3, progress: progress);
        expectBudget(
          recordFrame(renderer, config, phases),
          config,
          phases.fadeOpacity,
          '${effect.name} at progress $progress',
          lit: litFrame(renderer, config, phases.fadeOpacity),
        );
      }
    }
  });

  test('a zero-strength or fully faded frame draws nothing', () {
    final renderer = BeamRenderer();
    addTearDown(renderer.dispose);
    for (final effect in BeamEffect.values) {
      final dim = configFor(effect, style: const BeamStyle(strength: 0));
      expect(recordFrame(renderer, dim, phasesAt(dim, 1.3)).draws, isEmpty);
      final config = configFor(effect);
      expect(
        recordFrame(renderer, config, phasesAt(config, 1.3, fade: 0)).draws,
        isEmpty,
      );
    }
  });

  test('frames reuse one Paint and one FragmentShader', () {
    // The renderer rewrites the shader's uniforms in place: steady-state
    // frames allocate neither a Paint nor a shader.
    final renderer = BeamRenderer();
    addTearDown(renderer.dispose);
    final config = configFor(const BeamEffect.rotate());
    final first = recordFrame(renderer, config, phasesAt(config, 1.0));
    final second = recordFrame(renderer, config, phasesAt(config, 1.5));
    expect(identical(first.paints.single, second.paints.single), isTrue);
    expect(
      identical(first.paints.single.shader, second.paints.single.shader),
      isTrue,
    );
  });

  test('the draw covers the box, and hugs it when no light reaches out', () {
    // The single draw is the region light can reach: it must contain the
    // whole outline, and a frame whose light all stays inside the border
    // must not shade the space around the box.
    final renderer = BeamRenderer();
    addTearDown(renderer.dispose);
    final box = const Offset(renderMargin, renderMargin) & cardSize;
    for (final effect in BeamEffect.values) {
      final config = configFor(effect);
      final canvas = recordFrame(renderer, config, phasesAt(config, 1.3));
      final bounds = canvas.drawBounds.single;
      expect(
        bounds.contains(box.topLeft) && bounds.contains(box.bottomRight),
        isTrue,
        reason: '${effect.name}: $bounds must contain $box',
      );
      final reachesOut = renderer.debugFrame.reachOutside > 0;
      if (!reachesOut) {
        expect(
          box.inflate(4).contains(bounds.topLeft) &&
              box.inflate(4).contains(bounds.bottomRight),
          isTrue,
          reason: '${effect.name}: inward-only light drew $bounds',
        );
      }
    }
  });
}
