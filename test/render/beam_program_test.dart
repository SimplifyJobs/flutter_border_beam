import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/render/beam_program.dart';

/// `BeamProgram`: one shader load, shared by every caller that asks while it
/// is in flight. Nothing else in this file loads the program, so it starts
/// unloaded.
void main() {
  test('calls while a load is in flight share it', () async {
    expect(BeamProgram.program, isNull, reason: 'nothing has loaded it yet');
    final first = BeamProgram.load();
    expect(BeamProgram.load(), same(first));
    // A caller in another zone does not wait on this zone's load, which
    // under a widget test's fake clock might never complete.
    final elsewhere = runZoned(BeamProgram.load);
    expect(elsewhere, isNot(same(first)));
    await Future.wait([first, elsewhere]);

    final program = BeamProgram.program;
    expect(program, isNotNull);
    expect(BeamProgram.ready.value, isTrue);
    await BeamProgram.load();
    expect(BeamProgram.program, same(program), reason: 'loaded only once');
  });
}
