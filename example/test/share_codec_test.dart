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
        ..variant = BeamVariant.line
        ..strength = 0.6;
      expect(encodePlaygroundState(state), 'v=line&str=0.6');
    });

    test('trims trailing zeros from numbers', () {
      final state = PlaygroundState()..borderWidth = 2;
      expect(encodePlaygroundState(state), 'bw=2');
    });

    test('emits only ASCII that needs no percent-escaping', () {
      final state = PlaygroundState()
        ..palette = PalettePreset.custom
        ..customColors = [2, 5, 7]
        ..hueBase = -120
        ..cycleSeconds = 2.5;
      final encoded = encodePlaygroundState(state);
      expect(encoded, matches(RegExp(r'^[A-Za-z0-9.,=&-]*$')));
      expect(encoded, contains('cc=2,5,7'));
      expect(encoded, contains('hb=-120'));
      expect(encoded, contains('cy=2.5'));
    });
  });

  group('decodePlaygroundState', () {
    test('restores every field through a round trip', () {
      final state = PlaygroundState()
        ..variant = BeamVariant.pulseOutside
        ..palette = PalettePreset.custom
        ..customColors = [1, 4, 6]
        ..stadium = true
        ..perCorner = true
        ..radius = 24
        ..radiusTopLeft = 4
        ..radiusTopRight = 8
        ..radiusBottomRight = 12
        ..radiusBottomLeft = 20
        ..superellipse = true
        ..borderWidth = 2.5
        ..cycleSeconds = 3.25
        ..cycleGapSeconds = 1.5
        ..speed = 2
        ..huePeriodSeconds = 7
        ..breatheFactor = 2
        ..spikeFactor = 0.75
        ..spike2Factor = 2.5
        ..staticColors = true
        ..strength = 0.35
        ..brightness = 1.8
        ..saturation = 0.9
        ..hueRange = 12
        ..hueBase = 45
        ..strokeOpacityFactor = 0.5
        ..innerOpacityFactor = 1.5
        ..bloomOpacityFactor = 0.25
        ..glowBoost = 2.2
        ..coreBlur = 18
        ..bloomBlur = 64
        ..glowBrightness = 1.4
        ..glowSaturation = 2.1
        ..active = false
        ..controllerMode = true
        ..controllerSpeed = 3
        ..startAfterSeconds = 1.5
        ..durationSeconds = 9
        ..themeDemo = true;

      final encoded = encodePlaygroundState(state);
      final decoded = decodePlaygroundState(encoded);

      expect(encodePlaygroundState(decoded), encoded);
      expect(decoded.variant, BeamVariant.pulseOutside);
      expect(decoded.palette, PalettePreset.custom);
      expect(decoded.customColors, [1, 4, 6]);
      expect(decoded.stadium, isTrue);
      expect(decoded.perCorner, isTrue);
      expect(decoded.superellipse, isTrue);
      expect(decoded.borderWidth, 2.5);
      expect(decoded.cycleSeconds, 3.25);
      expect(decoded.huePeriodSeconds, 7);
      expect(decoded.hueBase, 45);
      expect(decoded.active, isFalse);
      expect(decoded.controllerMode, isTrue);
      expect(decoded.controllerSpeed, 3);
      expect(decoded.themeDemo, isTrue);
    });

    test('an empty string decodes to the defaults', () {
      final decoded = decodePlaygroundState('');
      expect(encodePlaygroundState(decoded), isEmpty);
      expect(decoded.variant, BeamVariant.rotate);
      expect(decoded.cycleSeconds, isNull);
    });

    test('ignores unknown keys, malformed pairs, and bad values', () {
      final decoded = decodePlaygroundState(
        'nope=1&&=5&v=not-a-variant&p=nope&str=huge&bw=99&hb=-999&sc=maybe',
      );
      expect(decoded.variant, BeamVariant.rotate);
      expect(decoded.palette, PalettePreset.colorful);
      expect(decoded.strength, 1);
      expect(decoded.borderWidth, 1, reason: 'out of the 0.5–4 range');
      expect(decoded.hueBase, 0, reason: 'out of the -180–180 range');
      expect(decoded.staticColors, isFalse);
    });

    test('drops out-of-bounds swatch indices and short custom lists', () {
      expect(decodePlaygroundState('cc=0,99,x,3').customColors, [0, 3]);
      expect(
        decodePlaygroundState('cc=0').customColors,
        PlaygroundState().customColors,
        reason: 'fewer than two colors is not a usable custom palette',
      );
      expect(decodePlaygroundState('cc=0,1,2,3,4,5').customColors.length, 4);
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
      expect(playgroundStateStringFrom(Uri.parse('file:///tmp/app')), isNull);
    });
  });

  group('playgroundShareUrl', () {
    test('appends the state to the published site as a fragment', () {
      expect(playgroundShareUrl('v=line'), '$playgroundSiteUrl#v=line');
    });

    test('a default configuration shares the bare site URL', () {
      expect(playgroundShareUrl(''), playgroundSiteUrl);
    });

    test('round-trips through the URL it builds', () {
      final state = PlaygroundState()
        ..variant = BeamVariant.small
        ..stadium = true;
      final encoded = encodePlaygroundState(state);
      final uri = Uri.parse(playgroundShareUrl(encoded));
      final decoded = decodePlaygroundState(playgroundStateStringFrom(uri)!);
      expect(decoded.variant, BeamVariant.small);
      expect(decoded.stadium, isTrue);
    });
  });
}
