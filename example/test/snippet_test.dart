import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam_example/src/playground/playground_state.dart';
import 'package:flutter_border_beam_example/src/playground/snippet.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a default configuration prints.
const String defaultSnippet =
    'BorderBeam(\n  effect: const BeamEffect.rotate(),\n  child: child,\n)';

void main() {
  test('a default configuration prints the effect and the child', () {
    expect(buildSnippet(PlaygroundState()), defaultSnippet);
  });

  group('effect', () {
    test('every effect prints its own const constructor', () {
      for (final kind in EffectKind.values) {
        final state = PlaygroundState()..effect = kind;
        expect(
          buildSnippet(state),
          contains('effect: const BeamEffect.${kind.id}()'),
          reason: kind.id,
        );
      }
    });

    test('rotate parameters are emitted only when they differ', () {
      final state = PlaygroundState()..rotateLength = 1.5;
      expect(
        buildSnippet(state),
        contains('effect: const BeamEffect.rotate(length: 1.5)'),
      );

      state
        ..rotateCount = 3
        ..rotateComet = true;
      expect(
        buildSnippet(state),
        contains(
          'effect: const BeamEffect.rotate(length: 1.5, count: 3, '
          'comet: true)',
        ),
      );
    });

    test('effect parameters stay with their own effect', () {
      final state = PlaygroundState()
        ..rotateCount = 3
        ..lineEdge = BeamEdge.top
        ..shimmerAngle = 45;
      expect(buildSnippet(state), isNot(contains('edge:')));
      expect(buildSnippet(state), isNot(contains('angle:')));

      state.effect = EffectKind.line;
      expect(
        buildSnippet(state),
        contains('effect: const BeamEffect.line(edge: BeamEdge.top)'),
      );
      expect(buildSnippet(state), isNot(contains('count:')));

      state.effect = EffectKind.shimmer;
      expect(
        buildSnippet(state),
        contains('effect: const BeamEffect.shimmer(angle: 45)'),
      );
    });
  });

  group('shape', () {
    test('a plain radius uses the borderRadius shorthand', () {
      final state = PlaygroundState()..radius = 24;
      expect(buildSnippet(state), contains('borderRadius: 24'));
      expect(buildSnippet(state), isNot(contains('BeamShape')));
    });

    test(
      'a radius with a squircle or a width uses the const BeamShape.all',
      () {
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
      },
    );

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

    test('a ring offset promotes the shorthand to a const BeamShape', () {
      final state = PlaygroundState()..ringOffset = 6;
      expect(
        buildSnippet(state),
        contains('shape: const BeamShape.all(16, ringOffset: 6)'),
      );
    });

    test('dashes ride the shape', () {
      final state = PlaygroundState()..dashes = 8;
      expect(
        buildSnippet(state),
        contains('shape: const BeamShape.all(16, dashes: 8)'),
      );
    });

    test('segment presets emit their const BeamSegment fields', () {
      final state = PlaygroundState()..segmentPreset = SegmentPreset.bottomHalf;
      expect(buildSnippet(state), contains('segment: BeamSegment.bottomHalf'));

      state.segmentPreset = SegmentPreset.rightEdge;
      expect(buildSnippet(state), contains('segment: BeamSegment.rightEdge'));
    });

    test('a custom segment emits const edge anchors and feathering', () {
      final state = PlaygroundState()
        ..segmentPreset = SegmentPreset.custom
        ..segmentFeather = 48;
      expect(
        buildSnippet(state),
        contains(
          'segment: BeamSegment(start: BeamAnchor.edge(BeamEdge.right), '
          'end: BeamAnchor.edge(BeamEdge.left), feather: 48)',
        ),
      );

      state.segmentStartT = 0.25;
      expect(
        buildSnippet(state),
        contains('BeamAnchor.edge(BeamEdge.right, 0.25)'),
      );
    });
  });

  group('palettes', () {
    test('a preset emits its constant, new presets included', () {
      for (final name in ['aurora', 'lagoon', 'lavender']) {
        final state = PlaygroundState()..preset = name;
        expect(buildSnippet(state), contains('colors: BeamColors.$name'));
      }
    });

    test('custom colors are emitted as a const BeamColors list', () {
      final state = PlaygroundState()
        ..paletteMode = PaletteMode.custom
        ..customColors = [0, 1];
      expect(
        buildSnippet(state),
        contains(
          'colors: const BeamColors([Color(0xFFFF0080), '
          'Color(0xFF00E5FF)])',
        ),
      );
    });

    test('seed mode emits BeamColors.fromSeed, harmony only when set', () {
      final state = PlaygroundState()
        ..paletteMode = PaletteMode.seed
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
        ..paletteMode = PaletteMode.lerp
        ..lerpFrom = 'ice'
        ..lerpTo = 'cosmic'
        ..lerpT = 0.25;
      expect(
        buildSnippet(state),
        contains(
          'colors: const BeamColors.lerp(BeamColors.ice, '
          'BeamColors.cosmic, 0.25)',
        ),
      );
    });

    test('scaleAlpha wraps the palette, default colors included', () {
      final state = PlaygroundState()..alphaScale = 0.6;
      expect(
        buildSnippet(state),
        contains('colors: BeamColors.colorful.scaleAlpha(0.6)'),
      );

      state.preset = 'gold';
      expect(
        buildSnippet(state),
        contains('colors: BeamColors.gold.scaleAlpha(0.6)'),
      );
    });
  });

  group('style', () {
    test('every style field rides a const BeamStyle', () {
      final state = PlaygroundState()
        ..beamTheme = BeamTheme.dark
        ..strength = 0.5
        ..glow = 2
        ..hueShift = 45
        ..hueBase = -30;
      final snippet = buildSnippet(state);
      expect(snippet, contains('style: const BeamStyle('));
      expect(snippet, contains('theme: BeamTheme.dark'));
      expect(snippet, contains('strength: 0.5'));
      expect(snippet, contains('glow: 2'));
      expect(snippet, contains('hueShift: 45'));
      expect(snippet, contains('hueBase: -30'));
    });

    test('hue mode is emitted only when it is set, none included', () {
      final state = PlaygroundState();
      expect(buildSnippet(state), isNot(contains('hueMode')));

      state.hueMode = BeamHueMode.none;
      expect(buildSnippet(state), contains('hueMode: BeamHueMode.none'));
    });

    test('hue shift is dropped where the hue does not ping-pong', () {
      // Pulse drifts continuously by default.
      final state = PlaygroundState()
        ..effect = EffectKind.pulse
        ..hueShift = 45;
      expect(buildSnippet(state), isNot(contains('hueShift')));

      state.hueMode = BeamHueMode.pingPong;
      expect(buildSnippet(state), contains('hueShift: 45'));
    });
  });

  group('timing', () {
    test('sub-second durations are emitted in milliseconds', () {
      final state = PlaygroundState()..cycleGapSeconds = 0.9;
      expect(
        buildSnippet(state),
        contains('cycleGap: Duration(milliseconds: 900)'),
      );
    });

    test('whole-second durations are emitted in seconds', () {
      final state = PlaygroundState()..cycleSeconds = 2;
      expect(buildSnippet(state), contains('cycle: Duration(seconds: 2)'));
    });

    test('an explicit zero gap is a value, not the default', () {
      final state = PlaygroundState()
        ..effect = EffectKind.shimmer
        ..cycleGapSeconds = 0;
      expect(buildSnippet(state), contains('cycleGap: Duration(seconds: 0)'));
    });

    test('the gap is dropped on the ambient effects', () {
      final state = PlaygroundState()
        ..effect = EffectKind.flow
        ..cycleGapSeconds = 1;
      expect(buildSnippet(state), isNot(contains('cycleGap')));
    });

    test('direction applies to the effects that move', () {
      final state = PlaygroundState()
        ..effect = EffectKind.pulse
        ..direction = BeamDirection.reverse
        ..phaseOffset = 0.25;
      final pulse = buildSnippet(state);
      expect(pulse, isNot(contains('direction')));
      // A phase offset staggers any effect's timeline.
      expect(pulse, contains('phaseOffset: 0.25'));

      for (final kind in [EffectKind.spin, EffectKind.charge]) {
        state.effect = kind;
        expect(
          buildSnippet(state),
          contains('direction: BeamDirection.reverse'),
          reason: kind.id,
        );
      }
    });

    test('the hue period is dropped when the hue never drifts', () {
      final state = PlaygroundState()..huePeriodSeconds = 6;
      expect(buildSnippet(state), contains('huePeriod: Duration(seconds: 6)'));

      state.hueMode = BeamHueMode.none;
      expect(buildSnippet(state), isNot(contains('huePeriod')));
    });
  });

  group('playback', () {
    test('controller mode declares the controller and drops scheduling', () {
      final state = PlaygroundState()
        ..controllerMode = true
        ..controllerSpeed = 2
        ..speed = 3
        ..startAfterSeconds = 1
        ..durationSeconds = 5;
      final snippet = buildSnippet(state);
      expect(snippet, startsWith('final controller = BorderBeamController();'));
      expect(snippet, contains('// controller.speed = 2;'));
      expect(snippet, contains('// controller.pulse() / .flash()'));
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

    test('offscreen pause and the CSS fade curve ride BeamPlayback', () {
      final state = PlaygroundState()
        ..pauseWhenOffscreen = false
        ..cssFadeCurve = true;
      final snippet = buildSnippet(state);
      expect(snippet, contains('pauseWhenOffscreen: false'));
      expect(snippet, contains('fadeCurve: BeamPlayback.cssEase'));
    });
  });

  group('drive', () {
    test('progress rides a flat parameter, and only where a beam travels', () {
      final state = PlaygroundState()
        ..effect = EffectKind.charge
        ..driveProgress = true
        ..progress = 0.4;
      expect(buildSnippet(state), contains('progress: 0.4'));

      state.effect = EffectKind.halo;
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

  group('groups', () {
    test('theme mode nests the beam under a const BorderBeamTheme', () {
      final state = PlaygroundState()..themeDemo = true;
      final snippet = buildSnippet(state);
      expect(snippet, startsWith('BorderBeamTheme('));
      expect(snippet, contains('data: const BorderBeamThemeData('));
      expect(snippet, contains('style: BeamStyle(colors: BeamColors.ocean)'));
      expect(snippet, contains('shape: BeamShape.all(20, superellipse: true)'));
      expect(snippet, contains('  child: BorderBeam('));
      expect(snippet, endsWith(')'));
    });

    test('the sync demo wraps three beams in a BeamSync', () {
      final state = PlaygroundState()..syncDemo = true;
      final snippet = buildSnippet(state);
      expect(snippet, startsWith('BeamSync('));
      expect(snippet, contains('child: Column('));
      expect('BorderBeam('.allMatches(snippet), hasLength(3));
      expect(snippet, contains('phaseOffset: 0.33'));
      expect(snippet, contains('phaseOffset: 0.67'));
      expect(snippet, endsWith(')'));
    });

    test('the sync demo owns playback and never emits a controller', () {
      final state = PlaygroundState()
        ..syncDemo = true
        ..controllerMode = true
        ..active = false
        ..speed = 2
        ..reducedMotion = BeamReducedMotion.slow
        ..repeatCycles = 3;
      final snippet = buildSnippet(state);
      expect(snippet, contains('active: false'));
      expect(snippet, contains('speed: 2'));
      expect(snippet, contains('reducedMotion: BeamReducedMotion.slow'));
      expect(snippet, isNot(contains('BorderBeamController')));
      expect(snippet, isNot(contains('controller: controller')));
      expect(snippet, isNot(contains('repeat:')));
    });

    test('the sync demo nests inside the theme demo', () {
      final state = PlaygroundState()
        ..syncDemo = true
        ..themeDemo = true;
      final snippet = buildSnippet(state);
      expect(snippet, startsWith('BorderBeamTheme('));
      expect(snippet, contains('child: BeamSync('));
    });
  });
}
