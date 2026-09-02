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

    test('preserves custom swatches while another palette is selected', () {
      final state = PlaygroundState()
        ..palette = PalettePreset.ocean
        ..customColors = [2, 5, 7];
      final decoded = decodePlaygroundState(encodePlaygroundState(state));
      expect(decoded.palette, PalettePreset.ocean);
      expect(decoded.customColors, [2, 5, 7]);
    });

    test('preserves an explicit offscreen opt-out', () {
      final state = PlaygroundState()..pauseWhenOffscreen = false;
      final encoded = encodePlaygroundState(state);
      expect(encoded, 'pwo=0');
      expect(decodePlaygroundState(encoded).pauseWhenOffscreen, isFalse);
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
        ..customBase = PalettePreset.aurora
        ..seedColor = 3
        ..seedHarmony = BeamSeedHarmony.triadic
        ..lerpFrom = PalettePreset.ice
        ..lerpTo = PalettePreset.gold
        ..lerpT = 0.25
        ..alphaScale = 0.6
        ..stadium = true
        ..perCorner = true
        ..radius = 24
        ..radiusTopLeft = 4
        ..radiusTopRight = 8
        ..radiusBottomRight = 12
        ..radiusBottomLeft = 20
        ..superellipse = true
        ..borderWidth = 2.5
        ..edge = BeamEdge.right
        ..ringOffset = -6
        ..contour = true
        ..segmentPreset = SegmentPreset.custom
        ..segmentStartEdge = BeamEdge.bottom
        ..segmentStartT = 0.2
        ..segmentEndEdge = BeamEdge.top
        ..segmentEndT = 0.8
        ..segmentFeather = 72
        ..wrapCorners = true
        ..cycleSeconds = 3.25
        ..cycleGapSeconds = 1.5
        ..speed = 2
        ..direction = BeamDirection.bounce
        ..phaseOffset = 0.5
        ..beamCount = 3
        ..huePeriodSeconds = 7
        ..breatheFactor = 2
        ..spikeFactor = 0.75
        ..spike2Factor = 2.5
        ..staticColors = true
        ..strength = 0.35
        ..brightness = 1.8
        ..saturation = 0.9
        ..hueRange = 12
        ..hueMode = BeamHueMode.continuous
        ..hueBase = 45
        ..strokeOpacityFactor = 0.5
        ..innerOpacityFactor = 1.5
        ..bloomOpacityFactor = 0.25
        ..tailLength = 1.75
        ..glowSpread = 2.5
        ..comet = true
        ..sparkle = 0.4
        ..segments = 12
        ..innerSizeScale = 1.4
        ..renderScale = 0.5
        ..stockPulseOutside = true
        ..glowBoost = 2.2
        ..coreBlur = 18
        ..bloomBlur = 64
        ..glowBrightness = 1.4
        ..glowSaturation = 2.1
        ..active = false
        ..repeatCycles = 3
        ..reducedMotion = BeamReducedMotion.slow
        ..simulateReducedMotion = true
        ..pauseWhenOffscreen = true
        ..cssFadeCurve = true
        ..driveProgress = true
        ..progress = 0.8
        ..followPointer = true
        ..strengthSignal = true
        ..syncDemo = true
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
      expect(decoded.customBase, PalettePreset.aurora);
      expect(decoded.seedColor, 3);
      expect(decoded.seedHarmony, BeamSeedHarmony.triadic);
      expect(decoded.lerpFrom, PalettePreset.ice);
      expect(decoded.lerpTo, PalettePreset.gold);
      expect(decoded.lerpT, 0.25);
      expect(decoded.alphaScale, 0.6);
      expect(decoded.edge, BeamEdge.right);
      expect(decoded.ringOffset, -6);
      expect(decoded.contour, isTrue);
      expect(decoded.segmentPreset, SegmentPreset.custom);
      expect(decoded.segmentStartEdge, BeamEdge.bottom);
      expect(decoded.segmentStartT, 0.2);
      expect(decoded.segmentEndEdge, BeamEdge.top);
      expect(decoded.segmentEndT, 0.8);
      expect(decoded.segmentFeather, 72);
      expect(decoded.wrapCorners, isTrue);
      expect(decoded.direction, BeamDirection.bounce);
      expect(decoded.phaseOffset, 0.5);
      expect(decoded.beamCount, 3);
      expect(decoded.hueMode, BeamHueMode.continuous);
      expect(decoded.tailLength, 1.75);
      expect(decoded.glowSpread, 2.5);
      expect(decoded.comet, isTrue);
      expect(decoded.sparkle, 0.4);
      expect(decoded.segments, 12);
      expect(decoded.innerSizeScale, 1.4);
      expect(decoded.renderScale, 0.5);
      expect(decoded.stockPulseOutside, isTrue);
      expect(decoded.pauseWhenOffscreen, isTrue);
      expect(decoded.cssFadeCurve, isTrue);
      expect(decoded.repeatCycles, 3);
      expect(decoded.reducedMotion, BeamReducedMotion.slow);
      expect(decoded.simulateReducedMotion, isTrue);
      expect(decoded.driveProgress, isTrue);
      expect(decoded.progress, 0.8);
      expect(decoded.followPointer, isTrue);
      expect(decoded.strengthSignal, isTrue);
      expect(decoded.syncDemo, isTrue);
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

  group('the new controls', () {
    test('each new palette mode round-trips its own fields', () {
      for (final palette in [
        PalettePreset.holographic,
        PalettePreset.seed,
        PalettePreset.lerp,
        PalettePreset.custom,
      ]) {
        final state = PlaygroundState()..palette = palette;
        final decoded = decodePlaygroundState(encodePlaygroundState(state));
        expect(decoded.palette, palette);
      }
    });

    test('a default configuration still encodes to the empty string', () {
      // Every new field must default to what the package resolves on its
      // own, or the share link stops being empty at rest.
      expect(encodePlaygroundState(PlaygroundState()), isEmpty);
    });

    test('enum values encode as their names, still escaping-free', () {
      final state = PlaygroundState()
        ..edge = BeamEdge.left
        ..direction = BeamDirection.reverse
        ..hueMode = BeamHueMode.pingPong
        ..reducedMotion = BeamReducedMotion.hide
        ..seedHarmony = BeamSeedHarmony.monochrome;
      final encoded = encodePlaygroundState(state);
      expect(encoded, matches(RegExp(r'^[A-Za-z0-9.,=&-]*$')));
      expect(encoded, contains('ed=left'));
      expect(encoded, contains('dir=reverse'));
      expect(encoded, contains('hm=pingPong'));
      expect(encoded, contains('rm=hide'));
      expect(encoded, contains('sdh=monochrome'));
    });

    test('segment presets and custom anchors use the compact shape keys', () {
      final preset = PlaygroundState()
        ..segmentPreset = SegmentPreset.bottomHalf;
      expect(encodePlaygroundState(preset), 'sgp=bottomHalf');

      final custom = PlaygroundState()
        ..segmentPreset = SegmentPreset.custom
        ..segmentStartEdge = BeamEdge.top
        ..segmentStartT = 0.25
        ..segmentEndEdge = BeamEdge.bottom
        ..segmentEndT = 0.75
        ..segmentFeather = 64
        ..wrapCorners = true;
      final encoded = encodePlaygroundState(custom);
      expect(encoded, contains('sgp=custom'));
      expect(encoded, contains('sga=top,0.25'));
      expect(encoded, contains('sgb=bottom,0.75'));
      expect(encoded, contains('sgf=64'));
      expect(encoded, contains('wc=1'));

      final decoded = decodePlaygroundState(encoded);
      expect(decoded.segmentPreset, SegmentPreset.custom);
      expect(decoded.segmentStartEdge, BeamEdge.top);
      expect(decoded.segmentStartT, 0.25);
      expect(decoded.segmentEndEdge, BeamEdge.bottom);
      expect(decoded.segmentEndT, 0.75);
      expect(decoded.segmentFeather, 64);
      expect(decoded.wrapCorners, isTrue);
    });

    test('unknown enum names and out-of-range numbers are ignored', () {
      final decoded = decodePlaygroundState(
        'ed=diagonal&dir=sideways&hm=strobe&rm=never&sdh=nope&'
        'ro=999&po=4&bc=9&sg=7&rp=0&pr=2&al=-1&lt=5&tl=9&gs=9&sk=3&'
        'iss=9&rs=4',
      );
      final d = PlaygroundState();
      expect(decoded.edge, d.edge);
      expect(decoded.direction, d.direction);
      expect(decoded.hueMode, isNull);
      expect(decoded.reducedMotion, isNull);
      expect(decoded.seedHarmony, d.seedHarmony);
      expect(decoded.ringOffset, d.ringOffset);
      expect(decoded.phaseOffset, d.phaseOffset);
      expect(decoded.beamCount, d.beamCount);
      expect(decoded.segments, isNull, reason: '7 is not an offered count');
      expect(decoded.repeatCycles, isNull);
      expect(decoded.progress, d.progress);
      expect(decoded.alphaScale, d.alphaScale);
      expect(decoded.lerpT, d.lerpT);
      expect(decoded.tailLength, d.tailLength);
      expect(decoded.glowSpread, d.glowSpread);
      expect(decoded.sparkle, d.sparkle);
      expect(decoded.innerSizeScale, d.innerSizeScale);
      expect(decoded.renderScale, d.renderScale);
    });

    test('bad segment ids, anchors, feather, and wrap values are ignored', () {
      final decoded = decodePlaygroundState(
        'sgp=diagonal&sga=right,4&sgb=nope,0.5&sgf=121&wc=maybe',
      );
      final d = PlaygroundState();
      expect(decoded.segmentPreset, d.segmentPreset);
      expect(decoded.segmentStartEdge, d.segmentStartEdge);
      expect(decoded.segmentStartT, d.segmentStartT);
      expect(decoded.segmentEndEdge, d.segmentEndEdge);
      expect(decoded.segmentEndT, d.segmentEndT);
      expect(decoded.segmentFeather, d.segmentFeather);
      expect(decoded.wrapCorners, d.wrapCorners);
    });

    test('an assembled palette cannot be a lerp endpoint or a custom '
        'base', () {
      final decoded = decodePlaygroundState('pb=seed&lfa=lerp&lto=custom');
      final d = PlaygroundState();
      expect(decoded.customBase, d.customBase);
      expect(decoded.lerpFrom, d.lerpFrom);
      expect(decoded.lerpTo, d.lerpTo);
    });

    test('the drive and group toggles round-trip', () {
      final state = PlaygroundState()
        ..driveProgress = true
        ..progress = 0.9
        ..followPointer = true
        ..strengthSignal = true
        ..simulateReducedMotion = true
        ..syncDemo = true;
      final decoded = decodePlaygroundState(encodePlaygroundState(state));
      expect(decoded.driveProgress, isTrue);
      expect(decoded.progress, 0.9);
      expect(decoded.followPointer, isTrue);
      expect(decoded.strengthSignal, isTrue);
      expect(decoded.simulateReducedMotion, isTrue);
      expect(decoded.syncDemo, isTrue);
    });
  });
}
