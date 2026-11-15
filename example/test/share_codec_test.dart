import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam_example/src/playground/playground_state.dart';
import 'package:flutter_border_beam_example/src/playground/share_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodePlaygroundState', () {
    test('encodes the default configuration to the empty string', () {
      expect(encodePlaygroundState(PlaygroundState()), isEmpty);
    });

    test('writes only the fields that differ from the default', () {
      final state = PlaygroundState()
        ..effect = EffectKind.line
        ..strength = 0.6;
      expect(encodePlaygroundState(state), 'v=line&str=0.6');
    });

    test('trims trailing zeros from numbers', () {
      final state = PlaygroundState()..borderWidth = 2;
      expect(encodePlaygroundState(state), 'bw=2');
    });

    test('preserves custom swatches while another palette is selected', () {
      final state = PlaygroundState()
        ..preset = 'ocean'
        ..customColors = [2, 5, 7];
      final decoded = decodePlaygroundState(encodePlaygroundState(state));
      expect(decoded.paletteMode, PaletteMode.preset);
      expect(decoded.preset, 'ocean');
      expect(decoded.customColors, [2, 5, 7]);
    });

    test('preserves the chosen preset while a factory mode is selected', () {
      final state = PlaygroundState()
        ..preset = 'dusk'
        ..paletteMode = PaletteMode.seed;
      final decoded = decodePlaygroundState(encodePlaygroundState(state));
      expect(decoded.paletteMode, PaletteMode.seed);
      expect(decoded.preset, 'dusk');
    });

    test('preserves an explicit offscreen opt-out', () {
      final state = PlaygroundState()..pauseWhenOffscreen = false;
      final encoded = encodePlaygroundState(state);
      expect(encoded, 'pwo=0');
      expect(decodePlaygroundState(encoded).pauseWhenOffscreen, isFalse);
    });

    test('emits only ASCII that needs no percent-escaping', () {
      final state = PlaygroundState()
        ..paletteMode = PaletteMode.custom
        ..customColors = [2, 5, 7]
        ..hueBase = -120
        ..shimmerAngle = -45
        ..cycleSeconds = 2.5;
      final encoded = encodePlaygroundState(state);
      expect(encoded, matches(RegExp(r'^[A-Za-z0-9.,=&-]*$')));
      expect(encoded, contains('cc=2,5,7'));
      expect(encoded, contains('hb=-120'));
      expect(encoded, contains('sha=-45'));
      expect(encoded, contains('cy=2.5'));
    });
  });

  group('decodePlaygroundState', () {
    test('restores every field through a round trip', () {
      final state = PlaygroundState()
        ..effect = EffectKind.shimmer
        ..rotateLength = 1.75
        ..rotateCount = 3
        ..rotateComet = true
        ..lineEdge = BeamEdge.left
        ..shimmerAngle = 35
        ..paletteMode = PaletteMode.lerp
        ..preset = 'citrus'
        ..customColors = [1, 4, 6]
        ..seedColor = 3
        ..seedHarmony = BeamSeedHarmony.monochrome
        ..lerpFrom = 'ice'
        ..lerpTo = 'lavender'
        ..lerpT = 0.25
        ..alphaScale = 0.6
        ..beamTheme = BeamTheme.light
        ..strength = 0.4
        ..glow = 2.5
        ..hueShift = 50
        ..hueMode = BeamHueMode.none
        ..hueBase = 90
        ..stadium = true
        ..perCorner = true
        ..radius = 24
        ..radiusTopLeft = 4
        ..radiusTopRight = 8
        ..radiusBottomRight = 12
        ..radiusBottomLeft = 20
        ..superellipse = true
        ..borderWidth = 2.5
        ..ringOffset = -6
        ..segmentPreset = SegmentPreset.custom
        ..segmentStartEdge = BeamEdge.bottom
        ..segmentStartT = 0.2
        ..segmentEndEdge = BeamEdge.top
        ..segmentEndT = 0.8
        ..segmentFeather = 64
        ..dashes = 12
        ..cycleSeconds = 3.5
        ..cycleGapSeconds = 0
        ..speed = 2
        ..direction = BeamDirection.bounce
        ..phaseOffset = 0.5
        ..huePeriodSeconds = 9
        ..active = false
        ..repeatCycles = 3
        ..reducedMotion = BeamReducedMotion.hide
        ..simulateReducedMotion = true
        ..pauseWhenOffscreen = true
        ..cssFadeCurve = true
        ..controllerMode = true
        ..controllerSpeed = 1.5
        ..startAfterSeconds = 1
        ..durationSeconds = 5
        ..driveProgress = true
        ..progress = 0.8
        ..followPointer = true
        ..strengthSignal = true
        ..themeDemo = true
        ..syncDemo = true;

      final decoded = decodePlaygroundState(encodePlaygroundState(state));

      expect(decoded.effect, EffectKind.shimmer);
      expect(decoded.rotateLength, 1.75);
      expect(decoded.rotateCount, 3);
      expect(decoded.rotateComet, isTrue);
      expect(decoded.lineEdge, BeamEdge.left);
      expect(decoded.shimmerAngle, 35);
      expect(decoded.paletteMode, PaletteMode.lerp);
      expect(decoded.preset, 'citrus');
      expect(decoded.customColors, [1, 4, 6]);
      expect(decoded.seedColor, 3);
      expect(decoded.seedHarmony, BeamSeedHarmony.monochrome);
      expect(decoded.lerpFrom, 'ice');
      expect(decoded.lerpTo, 'lavender');
      expect(decoded.lerpT, 0.25);
      expect(decoded.alphaScale, 0.6);
      expect(decoded.beamTheme, BeamTheme.light);
      expect(decoded.strength, 0.4);
      expect(decoded.glow, 2.5);
      expect(decoded.hueShift, 50);
      expect(decoded.hueMode, BeamHueMode.none);
      expect(decoded.hueBase, 90);
      expect(decoded.stadium, isTrue);
      expect(decoded.perCorner, isTrue);
      expect(decoded.radius, 24);
      expect(decoded.radiusTopLeft, 4);
      expect(decoded.radiusTopRight, 8);
      expect(decoded.radiusBottomRight, 12);
      expect(decoded.radiusBottomLeft, 20);
      expect(decoded.superellipse, isTrue);
      expect(decoded.borderWidth, 2.5);
      expect(decoded.ringOffset, -6);
      expect(decoded.segmentPreset, SegmentPreset.custom);
      expect(decoded.segmentStartEdge, BeamEdge.bottom);
      expect(decoded.segmentStartT, 0.2);
      expect(decoded.segmentEndEdge, BeamEdge.top);
      expect(decoded.segmentEndT, 0.8);
      expect(decoded.segmentFeather, 64);
      expect(decoded.dashes, 12);
      expect(decoded.cycleSeconds, 3.5);
      // An explicit zero gap is a value, not "the effect's default".
      expect(decoded.cycleGapSeconds, 0);
      expect(decoded.speed, 2);
      expect(decoded.direction, BeamDirection.bounce);
      expect(decoded.phaseOffset, 0.5);
      expect(decoded.huePeriodSeconds, 9);
      expect(decoded.active, isFalse);
      expect(decoded.repeatCycles, 3);
      expect(decoded.reducedMotion, BeamReducedMotion.hide);
      expect(decoded.simulateReducedMotion, isTrue);
      expect(decoded.pauseWhenOffscreen, isTrue);
      expect(decoded.cssFadeCurve, isTrue);
      expect(decoded.controllerMode, isTrue);
      expect(decoded.controllerSpeed, 1.5);
      expect(decoded.startAfterSeconds, 1);
      expect(decoded.durationSeconds, 5);
      expect(decoded.driveProgress, isTrue);
      expect(decoded.progress, 0.8);
      expect(decoded.followPointer, isTrue);
      expect(decoded.strengthSignal, isTrue);
      expect(decoded.themeDemo, isTrue);
      expect(decoded.syncDemo, isTrue);
    });

    test('an empty string decodes to the defaults', () {
      expect(
        encodePlaygroundState(decodePlaygroundState('')),
        encodePlaygroundState(PlaygroundState()),
      );
    });

    test('ignores unknown keys, malformed pairs, and bad values', () {
      final decoded = decodePlaygroundState(
        'v=sparkle&nope=1&=x&bw&str=7&r=-3&sp=abc&hm=wobble&bt=dim&'
        'p=rainbow&lfa=custom&sha=400&tl=9&bc=8&gl=-1',
      );
      final defaults = PlaygroundState();
      expect(decoded.effect, defaults.effect);
      expect(decoded.borderWidth, defaults.borderWidth);
      expect(decoded.strength, defaults.strength);
      expect(decoded.radius, defaults.radius);
      expect(decoded.speed, defaults.speed);
      expect(decoded.hueMode, isNull);
      expect(decoded.beamTheme, isNull);
      expect(decoded.paletteMode, PaletteMode.preset);
      expect(decoded.preset, defaults.preset);
      // A factory mode is not a preset, so it cannot be a lerp endpoint.
      expect(decoded.lerpFrom, defaults.lerpFrom);
      expect(decoded.shimmerAngle, defaults.shimmerAngle);
      expect(decoded.rotateLength, defaults.rotateLength);
      expect(decoded.rotateCount, defaults.rotateCount);
      expect(decoded.glow, defaults.glow);
    });

    test('drops out-of-bounds swatch indices and short custom lists', () {
      expect(decodePlaygroundState('cc=0,99').customColors, [0, 1]);
      expect(
        decodePlaygroundState('cc=7,6,5,4,3,2,1,0').customColors,
        hasLength(maxCustomColors),
      );
      expect(decodePlaygroundState('cc=3,-1,5').customColors, [3, 5]);
    });

    test('bad segment ids, anchors, feather, and dash counts are ignored', () {
      final decoded = decodePlaygroundState(
        'sgp=diagonal&sga=middle,0.5&sgb=left,2&sgf=999&ds=5',
      );
      final defaults = PlaygroundState();
      expect(decoded.segmentPreset, SegmentPreset.off);
      expect(decoded.segmentStartEdge, defaults.segmentStartEdge);
      expect(decoded.segmentEndT, defaults.segmentEndT);
      expect(decoded.segmentFeather, defaults.segmentFeather);
      expect(decoded.dashes, isNull);
    });
  });

  group('0.1 links', () {
    test('variant ids map onto the effects that replaced them', () {
      expect(decodePlaygroundState('v=small').effect, EffectKind.rotate);
      expect(decodePlaygroundState('v=line').effect, EffectKind.line);
      expect(decodePlaygroundState('v=pulse-inside').effect, EffectKind.pulse);
      expect(decodePlaygroundState('v=pulse-outside').effect, EffectKind.halo);
    });

    test('moved fields are read from their old keys', () {
      final decoded = decodePlaygroundState(
        'v=line&ed=top&tl=1.5&bc=3&co=1&sg=8&sc=1&gs=2&pr=0.7&hr=20',
      );
      expect(decoded.lineEdge, BeamEdge.top);
      expect(decoded.rotateLength, 1.5);
      expect(decoded.rotateCount, 3);
      expect(decoded.rotateComet, isTrue);
      expect(decoded.dashes, 8);
      expect(decoded.hueMode, BeamHueMode.none);
      expect(decoded.glow, 2);
      expect(decoded.progress, 0.7);
      expect(decoded.hueShift, 20);
    });

    test('presets, modes, and removed fields decode without complaint', () {
      final decoded = decodePlaygroundState(
        'p=holographic&pb=aurora&br=2&sa=1.5&so=1.2&sk=0.5&rs=0.5&ct=1&wc=1&'
        'pos=1&cb=20&bf=2',
      );
      expect(decoded.preset, 'holographic');
      expect(encodePlaygroundState(decoded), 'p=holographic');
      expect(decodePlaygroundState('p=custom').paletteMode, PaletteMode.custom);
      expect(decodePlaygroundState('p=lerp').paletteMode, PaletteMode.lerp);
    });
  });

  group('playgroundStateStringFrom', () {
    test('reads a query string', () {
      expect(
        playgroundStateStringFrom(Uri.parse('https://x.dev/?v=line&str=0.5')),
        'v=line&str=0.5',
      );
    });

    test('reads a bare fragment — the form the share button hands out', () {
      expect(
        playgroundStateStringFrom(Uri.parse('https://x.dev/#v=line')),
        'v=line',
      );
    });

    test('reads a fragment carrying a route and query', () {
      expect(
        playgroundStateStringFrom(Uri.parse('https://x.dev/#/?v=line')),
        'v=line',
      );
    });

    test('returns null when there is no state to read', () {
      expect(playgroundStateStringFrom(Uri.parse('https://x.dev/')), isNull);
      expect(playgroundStateStringFrom(Uri.parse('https://x.dev/#/')), isNull);
    });
  });

  group('playgroundShareUrl', () {
    test('appends the state to the published site as a fragment', () {
      expect(playgroundShareUrl('v=flow'), '$playgroundSiteUrl#v=flow');
    });

    test('a default configuration shares the bare site URL', () {
      expect(playgroundShareUrl(''), playgroundSiteUrl);
    });

    test('round-trips through the URL it builds', () {
      final state = PlaygroundState()
        ..effect = EffectKind.charge
        ..preset = 'forest'
        ..driveProgress = true;
      final url = playgroundShareUrl(encodePlaygroundState(state));
      final decoded = decodePlaygroundState(
        playgroundStateStringFrom(Uri.parse(url))!,
      );
      expect(decoded.effect, EffectKind.charge);
      expect(decoded.preset, 'forest');
      expect(decoded.driveProgress, isTrue);
    });
  });

  test('every effect and every preset round-trips by name', () {
    for (final kind in EffectKind.values) {
      final state = PlaygroundState()..effect = kind;
      expect(
        decodePlaygroundState(encodePlaygroundState(state)).effect,
        kind,
        reason: kind.id,
      );
    }
    for (final name in presetNames) {
      final state = PlaygroundState()..preset = name;
      expect(
        decodePlaygroundState(encodePlaygroundState(state)).preset,
        name,
        reason: name,
      );
    }
  });
}
