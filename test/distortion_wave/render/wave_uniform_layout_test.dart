import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/border_beam/render/beam_outline.dart';
import 'package:prismatic/src/core/oklab.dart';
import 'package:prismatic/src/distortion_wave/models/wave_glow.dart';
import 'package:prismatic/src/distortion_wave/models/wave_lens.dart';
import 'package:prismatic/src/distortion_wave/models/wave_palette.dart';
import 'package:prismatic/src/distortion_wave/models/wave_spec.dart';
import 'package:prismatic/src/distortion_wave/models/wave_style.dart';
import 'package:prismatic/src/distortion_wave/models/wave_type.dart';
import 'package:prismatic/src/distortion_wave/render/wave_frame_data.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_frame.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_rim.dart';

import '../../support/shader_source.dart';

/// `WaveFrameData` writes the wave shaders' uniforms by float index, so the
/// block both shaders declare (`shaders/common/wave_uniforms.glsl`) and the
/// packer must agree float for float — a uniform added on one side only
/// shifts every value after it, and the frame is garbage rather than an
/// error.
void main() {
  final wave = shaderSource('shaders/wave.frag');
  final glow = shaderSource('shaders/wave_glow.frag');
  final uniforms = shaderUniforms(wave);
  final floats = [
    for (final u in uniforms)
      if (floatsPerType.containsKey(u.type)) u,
  ];

  test('both wave shaders declare the same float block', () {
    expect(floats, isNotEmpty);
    expect([
      for (final u in shaderUniforms(glow))
        if (floatsPerType.containsKey(u.type)) u,
    ], floats);
    expect(
      shaderUniforms(glow).where((u) => u.type == 'sampler2D'),
      isEmpty,
      reason: 'the colour-only shader reads no images',
    );
  });

  test('wave.frag reads six images, each side sharp, near and far', () {
    // The renderer binds them by index in this order.
    expect(
      [
        for (final u in uniforms)
          if (u.type == 'sampler2D') u.name,
      ],
      ['uOutSharp', 'uOutNear', 'uOutFar', 'uInSharp', 'uInNear', 'uInFar'],
    );
  });

  test('every float uniform is a vec4 or a vec4 array', () {
    for (final u in floats) {
      expect(u.type, 'vec4', reason: u.name);
    }
    expect(
      uniforms.map((u) => u.name).toSet(),
      hasLength(uniforms.length),
      reason: 'uniform names must be unique',
    );
  });

  test('the declared float count equals waveUniformFloats', () {
    expect(floatCount(uniforms), waveUniformFloats);
    // OpenGL ES 3.0 guarantees a fragment shader 224 vec4s of uniforms.
    expect(waveUniformFloats, lessThanOrEqualTo(224 * 4));
  });

  test('the arrays hold what the frame data packs into them', () {
    expect(
      {for (final u in floats.where((u) => u.count > 1)) u.name: u.count},
      {'uStops': wavePaletteSlots, 'uFringe': 2, 'uLumps': WaveRim.count},
    );
  });

  test("the shaders' loops visit every slot", () {
    // The palette lookup walks every stop, the rim every lump.
    expect(wave, contains('for (int k = 0; k < $wavePaletteSlots; k++)'));
    expect(wave, contains('for (int i = 0; i < ${WaveRim.count}; i++)'));
  });

  test('each writer lands in the uniform the shader declares for it', () {
    final offsets = floatOffsets(uniforms);
    String owner(int float) =>
        offsets.entries.lastWhere((e) => e.value <= float).key;
    final blank = WaveFrameData().data;
    final checked = <String>{};

    // [write] on a fresh buffer puts [expected] [from] floats into [name],
    // and touches no uniform outside [touches].
    void expectWrite(
      String name,
      void Function(WaveFrameData d) write,
      List<double> expected, {
      int from = 0,
      required Set<String> touches,
    }) {
      final d = WaveFrameData();
      write(d);
      final start = offsets[name]! + from;
      for (var i = 0; i < expected.length; i++) {
        expect(
          d.data[start + i],
          closeTo(expected[i], 1e-3),
          reason: '$name float ${from + i}',
        );
      }
      expect(
        {
          for (var i = 0; i < waveUniformFloats; i++)
            if (d.data[i] != blank[i]) owner(i),
        },
        touches,
        reason: 'what writing $name touched',
      );
      checked.add(name);
    }

    // Distinct values throughout, so a value read from a neighbour fails.
    final outline = BeamOutline(
      const Rect.fromLTWH(0, 0, 390, 844),
      const BorderRadius.only(
        topLeft: Radius.circular(40),
        topRight: Radius.circular(44),
        bottomRight: Radius.circular(52),
        bottomLeft: Radius.circular(56),
      ),
      superellipse: true,
    );
    void stage(WaveFrameData d) =>
        d.setStage(const Rect.fromLTWH(3, 5, 390, 844), 0.5, outline);
    const stageUniforms = {'uRect', 'uView', 'uQuads', 'uRadii'};
    expectWrite('uRect', stage, [3, 5, 390, 844], touches: stageUniforms);
    expectWrite('uView', stage, [
      0.5,
      1,
      outline.length,
      0,
    ], touches: stageUniforms);
    expectWrite('uQuads', stage, outline.quadStarts, touches: stageUniforms);
    expectWrite('uRadii', stage, outline.radii, touches: stageUniforms);

    const palette = WavePalette(
      colors: [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF)],
      ahead: Color(0xFFFFFF00),
      behind: Color(0xFF00FFFF),
    );
    final spec = WaveSpec.resolve(
      const WaveStyle(
        palette: palette,
        lens: WaveLens(
          amplitude: 11,
          width: 13,
          aberration: 0.5,
          blur: 17,
          blurAhead: 19,
          blurBehind: 23,
        ),
        glow: WaveGlow(
          lead: 29,
          tail: 31,
          strength: 0.25,
          cornerRadius: 37,
          rimWidth: 41,
          rimSoftness: 43,
          rimUnevenness: 0.75,
          rimPulse: 0.125,
          hairlineWidth: 2.5,
          hairlineOpacity: 0.375,
          hairlineWhite: 0.625,
        ),
      ),
    );
    void look(WaveFrameData d) => d.setSpec(spec);
    const specUniforms = {
      'uLens',
      'uBlur',
      'uBand',
      'uRim',
      'uHair',
      'uStops',
      'uFringe',
    };
    expectWrite('uLens', look, [11, 13, 0.5, 17], touches: specUniforms);
    expectWrite('uBlur', look, [
      19,
      23,
      waveNearBlur,
      17,
    ], touches: specUniforms);
    expectWrite('uBand', look, [29, 31, 0.25, 37], touches: specUniforms);
    expectWrite('uRim', look, [41, 43, 0.75, 0.125], touches: specUniforms);
    expectWrite('uHair', look, [2.5, 0.375, 0.625, 3], touches: specUniforms);
    List<double> lab(Color c) {
      final o = Oklab.fromColor(c);
      return [o.l, o.a, o.b, 0];
    }

    // The stops cycle through the palette to fill every slot.
    for (var i = 0; i < wavePaletteSlots; i++) {
      expectWrite(
        'uStops',
        look,
        lab(palette.colors[i % 3]),
        from: i * 4,
        touches: specUniforms,
      );
    }
    expectWrite('uFringe', look, [
      ...lab(palette.ahead),
      ...lab(palette.behind),
    ], touches: specUniforms);

    final frame = WaveFrame.at(
      progress: 0.3,
      source: const Rect.fromLTWH(20, 760, 350, 56),
      size: const Size(390, 844),
      spec: spec,
      focus: const Offset(300, 790),
    );
    void moment(WaveFrameData d) => d.setFrame(frame);
    const frameUniforms = {
      'uFront0',
      'uFront1',
      'uFront2',
      'uFront3',
      'uFront4',
    };
    expectWrite('uFront0', moment, [
      frame.origin.dx,
      frame.origin.dy,
      frame.spine,
      frame.radius,
    ], touches: frameUniforms);
    expectWrite('uFront1', moment, [
      frame.squash,
      frame.time,
      frame.swell,
      frame.tilt,
    ], touches: frameUniforms);
    expectWrite('uFront2', moment, [
      frame.energy,
      frame.gravity,
      frame.glow,
      frame.rim,
    ], touches: frameUniforms);
    expectWrite('uFront3', moment, [
      frame.clearRadius,
      frame.hairClearRadius,
      0,
      0,
    ], touches: frameUniforms);
    // The center wave is a ring that holds its source still: the two lanes
    // the vertical wave leaves at 0.
    final ring = WaveFrame.at(
      progress: 0.3,
      source: const Rect.fromLTWH(163, 300, 64, 64),
      size: const Size(390, 844),
      spec: WaveSpec.resolve(const WaveStyle(type: WaveType.center)),
    );
    expect(ring.ring, isTrue);
    expect(ring.hold, greaterThan(0));
    expectWrite('uFront3', (d) => d.setFrame(ring), [
      ring.clearRadius,
      ring.hairClearRadius,
      1,
      ring.hold,
    ], touches: frameUniforms);
    expectWrite('uFront4', moment, [
      frame.launched ? 1 : 0,
      frame.showsOutgoing ? 1 : 0,
      frame.showsIncoming ? 1 : 0,
    ], touches: frameUniforms);

    void lumps(WaveFrameData d) =>
        d.setLumps(time: 1.25, perimeter: outline.length, pulse: 0.5);
    final expectedLumps = Float32List(WaveRim.count * 3);
    WaveRim.lumps(
      expectedLumps,
      time: 1.25,
      perimeter: outline.length,
      pulse: 0.5,
    );
    for (var i = 0; i < WaveRim.count; i++) {
      expectWrite(
        'uLumps',
        lumps,
        [
          expectedLumps[i * 3],
          expectedLumps[i * 3 + 1],
          expectedLumps[i * 3 + 2],
          0,
        ],
        from: i * 4,
        touches: {'uLumps'},
      );
    }

    expect(checked, {
      for (final u in floats) u.name,
    }, reason: 'a new uniform needs its writer checked here');
  });
}
