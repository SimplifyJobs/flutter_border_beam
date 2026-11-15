import 'dart:io';

import 'package:flutter_border_beam/src/render/beam_emission.dart';
import 'package:flutter_border_beam/src/render/beam_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart packer writes uniforms by float index, so the shader's declared
/// layout and `beamUniformFloats` must agree float for float — a uniform
/// added on one side only shifts every value after it, and the frame is
/// garbage rather than an error.
void main() {
  final source = File('shaders/beam.frag').readAsStringSync();
  final declaration = RegExp(
    r'^\s*uniform\s+(\w+)\s+(\w+)\s*(?:\[\s*(\d+)\s*\])?\s*;',
    multiLine: true,
  );
  final uniforms = [
    for (final m in declaration.allMatches(source))
      (type: m[1]!, name: m[2]!, count: int.parse(m[3] ?? '1')),
  ];

  const floatsPerType = {
    'float': 1,
    'vec2': 2,
    'vec3': 3,
    'vec4': 4,
    'mat2': 4,
    'mat3': 9,
    'mat4': 16,
  };

  test('the shader declares its uniforms', () {
    expect(uniforms, isNotEmpty);
    expect(
      uniforms.map((u) => u.name).toSet(),
      hasLength(uniforms.length),
      reason: 'uniform names must be unique',
    );
  });

  test('every uniform is a float type the packer can write', () {
    // A sampler would need `setImageSampler`, which the renderer never calls.
    for (final u in uniforms) {
      expect(
        floatsPerType,
        contains(u.type),
        reason: '${u.name} has type ${u.type}',
      );
    }
  });

  test('every uniform is a vec4 or a vec4 array', () {
    // The shader header promises this: a vec4-only layout packs identically
    // on every backend, with no std140 padding surprises.
    for (final u in uniforms) {
      expect(u.type, 'vec4', reason: u.name);
    }
  });

  test('the declared float count equals beamUniformFloats', () {
    final floats = uniforms.fold<int>(
      0,
      (sum, u) => sum + floatsPerType[u.type]! * u.count,
    );
    expect(floats, beamUniformFloats);
  });

  test('every uniform array holds exactly one slot per beamSlots', () {
    // Bumps, stops, colours, and lights are all bounded by beamSlots on the
    // Dart side; an array of another length would desynchronise the packer.
    final arrays = uniforms.where((u) => u.count > 1);
    expect(arrays, isNotEmpty);
    for (final u in arrays) {
      expect(u.count, beamSlots, reason: u.name);
    }
  });
}
