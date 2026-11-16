import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/src/render/beam_frame.dart';
import 'package:flutter_border_beam/src/render/beam_outline.dart';
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

  test('the arrays hold what the frame data packs into them', () {
    // Layers, tables, and blob stacks are sized on the Dart side by these
    // constants; an array of another length would desynchronise the packer.
    final arrays = {
      for (final u in uniforms.where((u) => u.count > 1)) u.name: u.count,
    };
    expect(arrays, {
      'uLayer': beamLayerCount * 9,
      'uWinA': tableStops ~/ 2,
      'uWinB': tableStops ~/ 2,
      'uOverA': tableStops ~/ 2,
      'uOverB': tableStops ~/ 2,
      'uBlobA': blobSlotsA * 3,
      'uBlobB': blobSlotsB * 3,
      'uBlobC': blobSlotsC * 3,
    });
  });

  test('each writer lands in the uniform the shader declares for it', () {
    // Where the shader reads each uniform, in floats: its declaration order
    // and sizes. The packer writes by fixed offsets, so a declaration moved
    // on either side alone puts values in the wrong uniform.
    final offsets = <String, int>{};
    var at = 0;
    for (final u in uniforms) {
      offsets[u.name] = at;
      at += floatsPerType[u.type]! * u.count;
    }
    String owner(int float) =>
        offsets.entries.lastWhere((e) => e.value <= float).key;
    final layerFloats =
        4 *
        uniforms.singleWhere((u) => u.name == 'uLayer').count ~/
        beamLayerCount;

    BeamFrameData frame() => BeamFrameData()..reset();
    final blank = frame().data;
    final checked = <String>{};

    // [write] on a reset frame puts [expected] [from] floats into [name],
    // and touches no uniform outside [touches].
    void expectWrite(
      String name,
      void Function(BeamFrameData d) write,
      List<double> expected, {
      int from = 0,
      Set<String>? touches,
    }) {
      final d = frame();
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
          for (var i = 0; i < beamUniformFloats; i++)
            if (d.data[i] != blank[i]) owner(i),
        },
        touches ?? {name},
        reason: 'what writing $name touched',
      );
      checked.add(name);
    }

    // Distinct values throughout, so a value read from a neighbour fails.
    final outline = BeamOutline(
      const Rect.fromLTWH(3, 5, 200, 100),
      const BorderRadius.only(
        topLeft: Radius.circular(7),
        topRight: Radius.circular(9),
        bottomRight: Radius.circular(11),
        bottomLeft: Radius.circular(13),
      ),
      superellipse: true,
    );
    void setOutline(BeamFrameData d) => d.setOutline(outline, 3, 0.5);
    const header = {'uRect', 'uRadii', 'uShape', 'uPerim', 'uQuads'};
    expectWrite('uRect', setOutline, [3, 5, 200, 100], touches: header);
    expectWrite('uRadii', setOutline, [7, 9, 11, 13], touches: header);
    expectWrite('uShape', setOutline, [1, 0, 3, 0.5], touches: header);
    expectWrite('uPerim', setOutline, [outline.length], touches: header);
    expectWrite('uQuads', setOutline, outline.quadStarts, touches: header);
    expectWrite('uMask', (d) => d.setTrack(0.25, 0.5, 0.125, 7), [
      0.25,
      0.5,
      0.125,
      7,
    ]);
    expectWrite('uConic', (d) => d.setConic(const Offset(11, 13), 0.375, 3), [
      11,
      13,
      0.375,
      3,
    ]);
    for (var k = 0; k < beamLayerCount; k++) {
      expectWrite(
        'uLayer',
        (d) => d.setLayer(
          k,
          BeamGeometry.glow,
          opacity: 0.5,
          sigma: 4.0 + k,
          inflate: 6,
        ),
        [BeamGeometry.glow.index.toDouble(), 4.0 + k, 6, 0.5],
        from: k * layerFloats,
      );
    }
    for (final (table, name) in [
      (BeamTable.windowA, 'uWinA'),
      (BeamTable.windowB, 'uWinB'),
      (BeamTable.overlayA, 'uOverA'),
      (BeamTable.overlayB, 'uOverB'),
    ]) {
      expectWrite(
        name,
        (d) => d.setTable(table, const [0.1, 0.6], const [0.3, 0.9], 2),
        [0.1, 0.3, 0.6, 0.9],
      );
    }
    for (final (k, name) in [(0, 'uBlobA'), (1, 'uBlobB'), (2, 'uBlobC')]) {
      expectWrite(
        name,
        (d) => d.addBlob(
          k,
          cx: 17,
          cy: 19,
          rx: 5,
          ry: 7,
          rgb: const Color(0xFF336699),
          a0: 0.8,
          p1: 0.25,
          a1: 0.5,
          p2: 0.75,
          a2: 0.25,
        ),
        [17, 19, 5, 7, 0.2, 0.4, 0.6, 0.8, 0.25, 0.5, 0.75, 0.25],
        // The blob count goes in the blob's layer header.
        touches: {name, 'uLayer'},
      );
    }

    expect(checked, {
      for (final u in uniforms) u.name,
    }, reason: 'a new uniform needs its writer checked here');
  });

  test('the uniforms stay inside the GLES budget', () {
    // OpenGL ES 3.0 guarantees a fragment shader 224 vec4s of uniforms
    // (MAX_FRAGMENT_UNIFORM_VECTORS), all a GLES device is bound to offer.
    expect(beamUniformFloats, lessThanOrEqualTo(224 * 4));
  });

  test("the shader's loop bounds match the slot counts", () {
    // A macro's parameters, and the bounds of the loops in its body (its
    // continuation lines).
    ({List<String> params, List<String> bounds}) macro(String name) {
      final m = RegExp(
        r'#define\s+' + name + r'\(([^)]*)\)((?:[^\n]*\\\n)*[^\n]*)',
      ).firstMatch(source);
      expect(m, isNotNull, reason: 'no $name macro');
      return (
        params: [for (final p in m![1]!.split(',')) p.trim()],
        bounds: [
          for (final loop in RegExp(
            r'for\s*\(\s*int\s+i\s*=\s*0\s*;\s*i\s*<\s*(\w+)\s*;',
          ).allMatches(m[2]!))
            loop[1]!,
        ],
      );
    }

    // A blob stack visits every slot it is handed...
    final blobStack = macro('BLOB_STACK');
    expect(blobStack.params[1], 'SLOTS');
    expect(blobStack.bounds, ['SLOTS']);
    // ...and each layer hands it its slot count.
    expect(source, contains('BLOB_STACK(uBlobA, $blobSlotsA,'));
    expect(source, contains('BLOB_STACK(uBlobB, $blobSlotsB,'));
    expect(source, contains('BLOB_STACK(uBlobC, $blobSlotsC,'));

    // A table lookup visits every stop, two to a vec4, and reads the last
    // one past the end.
    final lookup = macro('TABLE_LOOKUP');
    expect(lookup.bounds, ['${tableStops ~/ 2}']);
    expect(
      source,
      contains('TABLE[${tableStops ~/ 2 - 1}].w'),
      reason: 'the padding stop',
    );
  });
}
