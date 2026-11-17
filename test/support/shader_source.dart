import 'dart:io';

/// A uniform the shader declares: its GLSL type, name, and array length (1
/// for a plain uniform).
typedef ShaderUniform = ({String type, String name, int count});

/// Floats per GLSL float type, as the Dart packers write them.
const Map<String, int> floatsPerType = {
  'float': 1,
  'vec2': 2,
  'vec3': 3,
  'vec4': 4,
  'mat2': 4,
  'mat3': 9,
  'mat4': 16,
};

/// The source of the shader at [path] (relative to the package root) with
/// every local `#include "…"` inlined, resolved against `shaders/` as the
/// shader compiler resolves it. Each file is inlined once, as its include
/// guard would allow.
String shaderSource(String path, {Set<String>? seen}) {
  final included = seen ?? <String>{};
  final source = File(path).readAsStringSync();
  return source.replaceAllMapped(
    RegExp(r'^\s*#include\s+"([^"]+)"', multiLine: true),
    (m) {
      final target = 'shaders/${m[1]}';
      if (!included.add(target)) return '';
      return shaderSource(target, seen: included);
    },
  );
}

/// The uniforms [source] declares, in order: float uniforms and samplers
/// alike.
///
/// Throws when a line declares a uniform in a form this cannot parse (a
/// precision qualifier, several names), rather than leave it out.
List<ShaderUniform> shaderUniforms(String source) {
  final declaration = RegExp(
    r'^\s*uniform\s+(\w+)\s+(\w+)\s*(?:\[\s*(\d+)\s*\])?\s*;',
    multiLine: true,
  );
  final uniforms = [
    for (final m in declaration.allMatches(source))
      (type: m[1]!, name: m[2]!, count: int.parse(m[3] ?? '1')),
  ];
  final declared = RegExp(
    r'^\s*uniform\b',
    multiLine: true,
  ).allMatches(source).length;
  if (declared != uniforms.length) {
    throw FormatException(
      'Parsed ${uniforms.length} of $declared uniform declarations; '
      'declare each as `uniform <type> <name>;` or '
      '`uniform <type> <name>[<n>];`.',
    );
  }
  return uniforms;
}

/// The float offset of each float uniform in [uniforms], in declaration
/// order; samplers take no floats and are left out.
Map<String, int> floatOffsets(List<ShaderUniform> uniforms) {
  final offsets = <String, int>{};
  var at = 0;
  for (final u in uniforms) {
    final size = floatsPerType[u.type];
    if (size == null) continue;
    offsets[u.name] = at;
    at += size * u.count;
  }
  return offsets;
}

/// The total floats of the float uniforms in [uniforms].
int floatCount(List<ShaderUniform> uniforms) =>
    uniforms.fold(0, (sum, u) => sum + (floatsPerType[u.type] ?? 0) * u.count);
