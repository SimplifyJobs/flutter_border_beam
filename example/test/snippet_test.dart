import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam_example/src/playground/playground_state.dart';
import 'package:flutter_border_beam_example/src/playground/snippet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a default configuration prints the one-liner', () {
    expect(
      buildSnippet(PlaygroundState()),
      'BorderBeam.rotate(\n  child: child,\n)',
    );
  });

  test('picks the named constructor for the variant', () {
    for (final entry in {
      BeamVariant.rotate: 'BorderBeam.rotate(',
      BeamVariant.small: 'BorderBeam.small(',
      BeamVariant.line: 'BorderBeam.line(',
      BeamVariant.pulseInside: 'BorderBeam.pulseInside(',
      BeamVariant.pulseOutside: 'BorderBeam.pulseOutside(',
    }.entries) {
      final state = PlaygroundState()..variant = entry.key;
      expect(buildSnippet(state), startsWith(entry.value));
    }
  });

  test('the small variant emits its radius, whose preset is 32', () {
    final state = PlaygroundState()..variant = BeamVariant.small;
    expect(buildSnippet(state), contains('borderRadius: 16'));
  });

  test('a plain radius uses the borderRadius shorthand', () {
    final state = PlaygroundState()..radius = 24;
    expect(buildSnippet(state), contains('borderRadius: 24'));
    expect(buildSnippet(state), isNot(contains('BeamShape')));
  });

  test('a radius with a squircle or a width needs a non-const BeamShape', () {
    final state = PlaygroundState()
      ..radius = 24
      ..superellipse = true
      ..borderWidth = 2;
    expect(
      buildSnippet(state),
      contains(
        'shape: BeamShape.circular(24, borderWidth: 2, '
        'superellipse: true)',
      ),
    );
  });

  test('stadium corners emit the const named constructor', () {
    final state = PlaygroundState()..stadium = true;
    expect(buildSnippet(state), contains('shape: const BeamShape.stadium()'));
  });

  test('per-corner mode emits a const BorderRadius.only', () {
    final state = PlaygroundState()
      ..perCorner = true
      ..radiusTopLeft = 4
      ..radiusBottomRight = 28;
    final snippet = buildSnippet(state);
    expect(snippet, contains('shape: const BeamShape('));
    expect(snippet, contains('radius: BorderRadius.only('));
    expect(snippet, contains('topLeft: Radius.circular(4)'));
    expect(snippet, contains('bottomRight: Radius.circular(28)'));
  });

  test('sub-second durations are emitted in milliseconds', () {
    final state = PlaygroundState()..cycleGapSeconds = 0.9;
    expect(
      buildSnippet(state),
      contains('cycleGap: Duration(milliseconds: 900)'),
    );
  });

  test('whole-second durations are emitted in seconds', () {
    final state = PlaygroundState()..cycleGapSeconds = 2;
    expect(buildSnippet(state), contains('cycleGap: Duration(seconds: 2)'));
  });

  test('custom colors are emitted as a const list of Color literals', () {
    final state = PlaygroundState()
      ..palette = PalettePreset.custom
      ..customColors = [0, 1];
    expect(
      buildSnippet(state),
      contains(
        'colors: const BeamColors.custom([Color(0xFFFF0080), '
        'Color(0xFF00E5FF)])',
      ),
    );
  });

  test('controller mode declares the controller and drops playback', () {
    final state = PlaygroundState()
      ..controllerMode = true
      ..controllerSpeed = 2
      ..speed = 3
      ..startAfterSeconds = 1
      ..durationSeconds = 5;
    final snippet = buildSnippet(state);
    expect(snippet, startsWith('final controller = BorderBeamController();'));
    expect(snippet, contains('// controller.speed = 2;'));
    expect(snippet, contains('controller: controller'));
    // A controller owns scheduling and the rate exclusively.
    expect(snippet, isNot(contains('playback:')));
    expect(snippet, isNot(contains('speed:')));
  });

  test('scheduling fields ride BeamPlayback outside controller mode', () {
    final state = PlaygroundState()
      ..startAfterSeconds = 0.5
      ..durationSeconds = 6;
    final snippet = buildSnippet(state);
    expect(snippet, contains('playback: const BeamPlayback('));
    expect(snippet, contains('startAfter: Duration(milliseconds: 500)'));
    expect(snippet, contains('duration: Duration(seconds: 6)'));
  });

  test('an inactive beam uses the active shorthand', () {
    final state = PlaygroundState()..active = false;
    expect(buildSnippet(state), contains('active: false'));
  });

  test('theme mode nests the beam under a BorderBeamTheme', () {
    final state = PlaygroundState()..themeDemo = true;
    final snippet = buildSnippet(state);
    expect(snippet, startsWith('BorderBeamTheme('));
    expect(
      snippet,
      contains('style: const BeamStyle(colors: BeamColors.ocean)'),
    );
    expect(
      snippet,
      contains('shape: BeamShape.circular(20, superellipse: true)'),
    );
    expect(snippet, contains('  child: BorderBeam.rotate('));
    expect(snippet, endsWith(')'));
  });

  test('line-only timing fields are dropped on other variants', () {
    final state = PlaygroundState()
      ..variant = BeamVariant.rotate
      ..breatheFactor = 2
      ..spikeFactor = 2;
    expect(buildSnippet(state), isNot(contains('breatheFactor')));

    state.variant = BeamVariant.line;
    expect(buildSnippet(state), contains('breatheFactor: 2'));
    expect(buildSnippet(state), contains('spikeFactor: 2'));
  });

  test('pulse-only style fields are dropped on other variants', () {
    final state = PlaygroundState()
      ..glowBoost = 2
      ..coreBlur = 20;
    expect(buildSnippet(state), isNot(contains('glowBoost')));
    expect(buildSnippet(state), isNot(contains('coreBlur')));

    state.variant = BeamVariant.pulseInside;
    expect(buildSnippet(state), contains('glowBoost: 2'));
    expect(buildSnippet(state), isNot(contains('coreBlur')));

    state.variant = BeamVariant.pulseOutside;
    expect(buildSnippet(state), contains('coreBlur: 20'));
  });

  test('numbers read as hand-written arguments', () {
    final state = PlaygroundState()
      ..strength = 0.5
      ..hueBase = -30
      ..strokeOpacityFactor = 1.25;
    final snippet = buildSnippet(state);
    expect(snippet, contains('strength: 0.5'));
    expect(snippet, contains('hueBase: -30'));
    expect(snippet, contains('strokeOpacityFactor: 1.25'));
  });
}
