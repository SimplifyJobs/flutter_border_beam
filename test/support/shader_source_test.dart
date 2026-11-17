import 'package:flutter_test/flutter_test.dart';

import 'shader_source.dart';

/// The shader-source helpers the uniform layout tests read shaders with.
void main() {
  test('shaderUniforms reads plain and array declarations in order', () {
    expect(
      shaderUniforms(
        'uniform vec4 uA;\nuniform vec4 uB[3];\n'
        'uniform sampler2D uImage;\n',
      ),
      [
        (type: 'vec4', name: 'uA', count: 1),
        (type: 'vec4', name: 'uB', count: 3),
        (type: 'sampler2D', name: 'uImage', count: 1),
      ],
    );
  });

  test('shaderUniforms throws on a declaration it cannot parse', () {
    expect(
      () => shaderUniforms('uniform vec4 uA;\nuniform highp vec4 uB;\n'),
      throwsFormatException,
    );
    expect(
      () => shaderUniforms('uniform vec4 uA, uB;\n'),
      throwsFormatException,
    );
  });
}
