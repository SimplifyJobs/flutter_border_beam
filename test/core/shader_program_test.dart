import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/core/shader_program.dart';

/// `ShaderProgram`: one load per program, shared by every caller that asks
/// while it is in flight. Each test makes its own instance, so it starts
/// unloaded.
void main() {
  test('calls while a load is in flight share it', () async {
    final shader = ShaderProgram('beam');
    expect(shader.program, isNull, reason: 'nothing has loaded it yet');
    final first = shader.load();
    expect(shader.load(), same(first));
    // A caller in another zone does not wait on this zone's load, which
    // under a widget test's fake clock might never complete.
    final elsewhere = runZoned(shader.load);
    expect(elsewhere, isNot(same(first)));
    await Future.wait([first, elsewhere]);

    final program = shader.program;
    expect(program, isNotNull);
    expect(shader.ready.value, isTrue);
    await shader.load();
    expect(shader.program, same(program), reason: 'loaded only once');
  });

  test('a missing shader reports once and stays unloaded', () async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final shader = ShaderProgram('no_such_shader');
    await shader.load();
    await shader.load();
    expect(shader.program, isNull);
    expect(shader.ready.value, isFalse);
    expect(errors, hasLength(1));
    expect(errors.single.library, 'prismatic');
  });
}
