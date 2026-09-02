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

  test('a radius with a squircle or a width uses the const BeamShape.all', () {
    final state = PlaygroundState()
      ..radius = 24
      ..superellipse = true
      ..borderWidth = 2;
    expect(
      buildSnippet(state),
      contains(
        'shape: const BeamShape.all(24, borderWidth: 2, '
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

  group('palettes', () {
    test('a preset emits its constant', () {
      final state = PlaygroundState()..palette = PalettePreset.aurora;
      expect(buildSnippet(state), contains('colors: BeamColors.aurora'));
    });

    test('seed mode emits BeamColors.fromSeed, harmony only when set', () {
      final state = PlaygroundState()
        ..palette = PalettePreset.seed
        ..seedColor = 1;
      expect(
        buildSnippet(state),
        contains('colors: const BeamColors.fromSeed(Color(0xFF00E5FF))'),
      );

      state.seedHarmony = BeamSeedHarmony.triadic;
      expect(
        buildSnippet(state),
        contains(
          'const BeamColors.fromSeed(Color(0xFF00E5FF), '
          'harmony: BeamSeedHarmony.triadic)',
        ),
      );
    });

    test('lerp mode emits both endpoints and the blend', () {
      final state = PlaygroundState()
        ..palette = PalettePreset.lerp
        ..lerpFrom = PalettePreset.ice
        ..lerpTo = PalettePreset.ember
        ..lerpT = 0.25;
      expect(
        buildSnippet(state),
        contains(
          'colors: const BeamColors.lerp(BeamColors.ice, '
          'BeamColors.ember, 0.25)',
        ),
      );
    });

    test('a custom base is emitted only when it is not colorful', () {
      final state = PlaygroundState()..palette = PalettePreset.custom;
      expect(buildSnippet(state), isNot(contains('base:')));

      state.customBase = PalettePreset.ocean;
      expect(buildSnippet(state), contains('base: BeamColors.ocean'));
    });

    test('scaleAlpha wraps the palette, default colors included', () {
      final state = PlaygroundState()..alphaScale = 0.6;
      expect(
        buildSnippet(state),
        contains('colors: BeamColors.colorful.scaleAlpha(0.6)'),
      );

      state.palette = PalettePreset.gold;
      expect(
        buildSnippet(state),
        contains('colors: BeamColors.gold.scaleAlpha(0.6)'),
      );
    });
  });

  group('shape', () {
    test('the line edge is emitted only on the line variant', () {
      final state = PlaygroundState()..edge = BeamEdge.top;
      expect(buildSnippet(state), isNot(contains('edge:')));

      state.variant = BeamVariant.line;
      expect(buildSnippet(state), contains('edge: BeamEdge.top'));
    });

    test('a ring offset promotes the shorthand to a const BeamShape', () {
      final state = PlaygroundState()..ringOffset = 6;
      expect(
        buildSnippet(state),
        contains('shape: const BeamShape.all(16, ringOffset: 6)'),
      );
    });

    test('a contour emits a commented placeholder, since it takes a '
        'builder', () {
      final state = PlaygroundState()..contour = true;
      final snippet = buildSnippet(state);
      expect(snippet, contains('shape: const BeamShape.all('));
      expect(
        snippet,
        contains("// contour: BeamPathContour(builder: yourPath, key: 'star')"),
      );
    });
  });

  group('style', () {
    test('hue mode is emitted only when it is set', () {
      final state = PlaygroundState();
      expect(buildSnippet(state), isNot(contains('hueMode')));

      state.hueMode = BeamHueMode.continuous;
      expect(buildSnippet(state), contains('hueMode: BeamHueMode.continuous'));
    });

    test('tail length and comet are ring-only', () {
      final state = PlaygroundState()
        ..variant = BeamVariant.line
        ..tailLength = 1.5
        ..comet = true;
      expect(buildSnippet(state), isNot(contains('tailLength')));
      expect(buildSnippet(state), isNot(contains('comet')));

      state.variant = BeamVariant.small;
      expect(buildSnippet(state), contains('tailLength: 1.5'));
      expect(buildSnippet(state), contains('comet: true'));
    });

    test('sparkle is dropped on the pulse variants', () {
      final state = PlaygroundState()
        ..variant = BeamVariant.pulseInside
        ..sparkle = 0.5;
      expect(buildSnippet(state), isNot(contains('sparkle')));

      state.variant = BeamVariant.line;
      expect(buildSnippet(state), contains('sparkle: 0.5'));
    });

    test('segments are dropped on the line variant', () {
      final state = PlaygroundState()
        ..variant = BeamVariant.line
        ..segments = 8;
      expect(buildSnippet(state), isNot(contains('segments')));

      state.variant = BeamVariant.pulseOutside;
      expect(buildSnippet(state), contains('segments: 8'));
    });

    test('glow spread applies to every variant', () {
      final state = PlaygroundState()..glowSpread = 2;
      expect(buildSnippet(state), contains('glowSpread: 2'));
    });
  });

  group('timing', () {
    test('the travel fields are dropped on the pulse variants', () {
      final state = PlaygroundState()
        ..variant = BeamVariant.pulseInside
        ..direction = BeamDirection.bounce
        ..phaseOffset = 0.25
        ..beamCount = 3;
      final pulse = buildSnippet(state);
      expect(pulse, isNot(contains('direction')));
      expect(pulse, isNot(contains('phaseOffset')));
      expect(pulse, isNot(contains('beamCount')));

      state.variant = BeamVariant.rotate;
      final rotate = buildSnippet(state);
      expect(rotate, contains('direction: BeamDirection.bounce'));
      expect(rotate, contains('phaseOffset: 0.25'));
      expect(rotate, contains('beamCount: 3'));
    });
  });

  group('playback', () {
    test('repeat emits the constructor the chip selects', () {
      final state = PlaygroundState()..repeatCycles = 1;
      expect(buildSnippet(state), contains('repeat: BeamRepeat.once()'));

      state.repeatCycles = 3;
      expect(buildSnippet(state), contains('repeat: BeamRepeat.count(3)'));

      state.repeatCycles = null;
      expect(buildSnippet(state), isNot(contains('repeat')));
    });

    test('static-frame reduced motion sets no field', () {
      final state = PlaygroundState();
      expect(buildSnippet(state), isNot(contains('reducedMotion')));

      state.reducedMotion = BeamReducedMotion.slow;
      expect(
        buildSnippet(state),
        contains('reducedMotion: BeamReducedMotion.slow'),
      );
    });

    test('repeat survives controller mode, where scheduling does not', () {
      final state = PlaygroundState()
        ..controllerMode = true
        ..repeatCycles = 3
        ..startAfterSeconds = 1
        ..durationSeconds = 5;
      final snippet = buildSnippet(state);
      expect(snippet, contains('repeat: BeamRepeat.count(3)'));
      expect(snippet, isNot(contains('startAfter')));
      expect(snippet, isNot(contains('duration:')));
    });
  });

  group('drive', () {
    test('progress rides a flat parameter, and only where a beam travels', () {
      final state = PlaygroundState()
        ..driveProgress = true
        ..progress = 0.4;
      expect(buildSnippet(state), contains('progress: 0.4'));

      state.variant = BeamVariant.pulseOutside;
      expect(buildSnippet(state), isNot(contains('progress')));
    });

    test('follow names the pointer variable and explains it', () {
      final state = PlaygroundState()..followPointer = true;
      final snippet = buildSnippet(state);
      expect(snippet, contains('// pointer:'));
      expect(snippet, contains('follow: pointer'));
    });

    test('progress wins over follow', () {
      final state = PlaygroundState()
        ..followPointer = true
        ..driveProgress = true;
      final snippet = buildSnippet(state);
      expect(snippet, contains('progress:'));
      expect(snippet, isNot(contains('follow:')));
    });

    test('the strength signal declares its notifier', () {
      final state = PlaygroundState()..strengthSignal = true;
      final snippet = buildSnippet(state);
      expect(snippet, startsWith('final level = ValueNotifier<double>(1);'));
      expect(snippet, contains('strengthListenable: level'));
    });
  });

  test('the sync demo wraps the beam in a BeamSync', () {
    final state = PlaygroundState()..syncDemo = true;
    final snippet = buildSnippet(state);
    expect(snippet, startsWith('BeamSync('));
    expect(snippet, contains('  child: BorderBeam.rotate('));
    expect(snippet, endsWith(')'));
  });

  test('the sync demo nests inside the theme demo', () {
    final state = PlaygroundState()
      ..syncDemo = true
      ..themeDemo = true;
    final snippet = buildSnippet(state);
    expect(snippet, startsWith('BorderBeamTheme('));
    expect(snippet, contains('child: BeamSync('));
  });

  group('the newest style and playback fields', () {
    test('inner size is pulse-inside only, render scale is universal', () {
      final state = PlaygroundState()
        ..innerSizeScale = 1.4
        ..renderScale = 0.5;
      expect(buildSnippet(state), isNot(contains('innerSizeScale')));
      expect(buildSnippet(state), contains('renderScale: 0.5'));

      state.variant = BeamVariant.pulseInside;
      expect(buildSnippet(state), contains('innerSizeScale: 1.4'));
    });

    test('the stock recipe replaces the const style, and merges what is '
        'set over it', () {
      final state = PlaygroundState()
        ..variant = BeamVariant.pulseOutside
        ..stockPulseOutside = true;
      expect(
        buildSnippet(state),
        contains('style: BeamStyle.pulseOutsideStock'),
      );
      expect(buildSnippet(state), isNot(contains('merge(')));

      state.glowBoost = 1.4;
      final merged = buildSnippet(state);
      expect(merged, contains('BeamStyle.pulseOutsideStock.merge('));
      expect(merged, contains('glowBoost: 1.4'));
    });

    test('the stock recipe is dropped on every other variant', () {
      final state = PlaygroundState()..stockPulseOutside = true;
      expect(buildSnippet(state), isNot(contains('pulseOutsideStock')));
    });

    test('offscreen pause and the CSS fade curve ride BeamPlayback', () {
      final state = PlaygroundState()
        ..pauseWhenOffscreen = true
        ..cssFadeCurve = true;
      final snippet = buildSnippet(state);
      expect(snippet, contains('pauseWhenOffscreen: true'));
      expect(snippet, contains('fadeCurve: BeamPlayback.cssEase'));
    });
  });
}
