// Asserts every table in `lib/src/constants/` against the upstream React
// library's machine-readable spec, vendored at `test/fixtures/beam-spec.json`.
//
// Our constants are hand transcriptions of `src/styles.ts`; this test is the
// only thing that can prove the transcription is still faithful. A failure
// here means the SPEC and OUR CONSTANTS disagree — re-audit against
// `src/styles.ts` and report the divergence. Never "fix" a constant to make
// this test pass (CLAUDE.md hard rule 1).
//
// Spec conventions the parsers below handle:
//   colors     CSS `rgb(r, g, b)` / `rgba(r, g, b, a)` / `transparent`
//   positions  `"33% -7.4%"`  → fractional Offset(0.33, -0.074)
//   sizes      `"70px 40px"`  → Size(70, 40), and CSS ellipse sizes are RADII
//   stops      percent (0–100) where our tables carry fractions (0–1)

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/animation/oscillator.dart';
import 'package:flutter_border_beam/src/constants/line_geometry.dart';
import 'package:flutter_border_beam/src/constants/line_keyframes.dart';
import 'package:flutter_border_beam/src/constants/palettes.dart';
import 'package:flutter_border_beam/src/constants/pulse_constants.dart';
import 'package:flutter_border_beam/src/constants/pulse_params.dart';
import 'package:flutter_border_beam/src/constants/pulse_tables.dart';
import 'package:flutter_border_beam/src/constants/rotate_stops.dart';
import 'package:flutter_border_beam/src/constants/theme_presets.dart';
import 'package:flutter_border_beam/src/constants/upstream.dart';
import 'package:flutter_border_beam/src/models/beam_blob.dart';
import 'package:flutter_border_beam/src/models/beam_colors.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/models/beam_palette.dart';
import 'package:flutter_border_beam/src/models/beam_style.dart';
import 'package:flutter_border_beam/src/models/beam_variant.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixture ────────────────────────────────────────────────────────────────

const String _fixturePath = 'test/fixtures/beam-spec.json';
const String _upstreamPath = 'test/fixtures/UPSTREAM';

Map<String, dynamic> _loadSpec() =>
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

Map<String, String> _loadUpstream() {
  final out = <String, String>{};
  for (final line in File(_upstreamPath).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final i = line.indexOf('=');
    out[line.substring(0, i)] = line.substring(i + 1);
  }
  return out;
}

// ─── CSS value parsers ──────────────────────────────────────────────────────

/// Parses a spec color string: `rgb(r, g, b)`, `rgba(r, g, b, a)`, or the
/// keyword `transparent`.
Color cssColor(Object? raw) {
  final s = (raw! as String).trim();
  if (s == 'transparent') return const Color(0x00000000);
  final m = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(s);
  if (m == null) throw FormatException('not a CSS rgb/rgba color: "$s"');
  final parts = m.group(1)!.split(',').map((p) => p.trim()).toList();
  if (parts.length != 3 && parts.length != 4) {
    throw FormatException('CSS color needs 3 or 4 components: "$s"');
  }
  return Color.fromRGBO(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
    parts.length == 4 ? double.parse(parts[3]) : 1.0,
  );
}

/// Parses a spec position string — `"33% -7.4%"` → `Offset(0.33, -0.074)`.
Offset cssPosition(Object? raw) {
  final parts = (raw! as String).trim().split(RegExp(r'\s+'));
  if (parts.length != 2) {
    throw FormatException('CSS position needs two components: "$raw"');
  }
  double pct(String p) {
    if (!p.endsWith('%')) throw FormatException('not a percentage: "$p"');
    return double.parse(p.substring(0, p.length - 1)) / 100;
  }

  return Offset(pct(parts[0]), pct(parts[1]));
}

/// Parses a spec size string — `"70px 40px"` → `Size(70, 40)`. CSS
/// `radial-gradient(ellipse W H …)` sizes are radii, and so is [Size] here.
Size cssSize(Object? raw) {
  final parts = (raw! as String).trim().split(RegExp(r'\s+'));
  if (parts.length != 2) {
    throw FormatException('CSS size needs two components: "$raw"');
  }
  double px(String p) {
    if (!p.endsWith('px')) throw FormatException('not a px length: "$p"');
    return double.parse(p.substring(0, p.length - 2));
  }

  return Size(px(parts[0]), px(parts[1]));
}

/// Parses a single spec percentage — `"27%"` → `0.27`.
double cssPercent(Object? raw) {
  final s = (raw! as String).trim();
  if (!s.endsWith('%')) throw FormatException('not a percentage: "$s"');
  return double.parse(s.substring(0, s.length - 1)) / 100;
}

// ─── Matchers ───────────────────────────────────────────────────────────────

/// One 8-bit step: CSS integer channels round-trip through Flutter's doubles.
const double _channelTolerance = 1 / 255;

/// Half an ulp of the spec's 4-decimal rounding. Flutter stores alpha as an
/// exact double, so the only slack needed is the spec generator's rounding of
/// the mono-attenuated alphas (0.82 × 0.098 = 0.08036, recorded as 0.0804).
const double _alphaTolerance = 1e-4;

const double _epsilon = 1e-9;

void expectColor(Color actual, Object? specColor, String reason) {
  final want = cssColor(specColor);
  expect(actual.r, closeTo(want.r, _channelTolerance), reason: '$reason (r)');
  expect(actual.g, closeTo(want.g, _channelTolerance), reason: '$reason (g)');
  expect(actual.b, closeTo(want.b, _channelTolerance), reason: '$reason (b)');
  expect(actual.a, closeTo(want.a, _channelTolerance), reason: '$reason (a)');
}

/// Compares component-wise: `"-7.4%" / 100` and `-0.074` are the same
/// position but not the same double, so `Offset ==` is too strict here.
void expectOffset(Offset actual, Object? specPos, String reason) {
  final want = cssPosition(specPos);
  expect(actual.dx, closeTo(want.dx, _epsilon), reason: '$reason (dx)');
  expect(actual.dy, closeTo(want.dy, _epsilon), reason: '$reason (dy)');
}

void expectSize(Size actual, Object? specSize, String reason) {
  final want = cssSize(specSize);
  expect(actual.width, closeTo(want.width, _epsilon), reason: '$reason (w)');
  expect(actual.height, closeTo(want.height, _epsilon), reason: '$reason (h)');
}

/// Compares a color against loose spec channels (the expanded
/// `line.bloomGradients` stops carry r/g/b as ints and a as a double).
void expectChannels(
  Color actual, {
  required Map<String, dynamic> stop,
  required String reason,
  double alphaScale = 1,
}) {
  expect(
    actual.r,
    closeTo((stop['r'] as num) / 255, _channelTolerance),
    reason: '$reason (r)',
  );
  expect(
    actual.g,
    closeTo((stop['g'] as num) / 255, _channelTolerance),
    reason: '$reason (g)',
  );
  expect(
    actual.b,
    closeTo((stop['b'] as num) / 255, _channelTolerance),
    reason: '$reason (b)',
  );
  expect(
    actual.a * alphaScale,
    closeTo((stop['a'] as num).toDouble(), _alphaTolerance),
    reason: '$reason (a)',
  );
}

void expectNum(num actual, Object? spec, String reason) => expect(
  actual.toDouble(),
  closeTo((spec! as num).toDouble(), _epsilon),
  reason: reason,
);

/// Asserts a `[[posPercent, value], …]` spec table against parallel
/// fraction/value lists.
/// [terminatedAt1] covers the tables whose CSS gradient stops short of 100%
/// and lets the last stop's (already transparent) color extend to the end.
/// Flutter's `SweepGradient` needs that extension written out, so our list
/// carries one extra `(1.0, 0.0)` entry the spec has no row for.
void expectStopTable(
  Object? spec,
  List<double> stops,
  List<double> values,
  String reason, {
  bool terminatedAt1 = false,
}) {
  final rows = (spec! as List).cast<List<dynamic>>();
  final extra = terminatedAt1 ? 1 : 0;
  expect(stops, hasLength(rows.length + extra), reason: '$reason (stop count)');
  expect(
    values,
    hasLength(rows.length + extra),
    reason: '$reason (value count)',
  );
  for (var i = 0; i < rows.length; i++) {
    expectNum(stops[i] * 100, rows[i][0], '$reason stop $i');
    expectNum(values[i], rows[i][1], '$reason value $i');
  }
  if (terminatedAt1) {
    expect(stops.last, 1.0, reason: '$reason terminal stop');
    expect(values.last, 0.0, reason: '$reason terminal value');
    expect(
      values[values.length - 2],
      0.0,
      reason: '$reason is already transparent before its terminator',
    );
  }
}

/// Asserts a `[[tPercent, value], …]` spec table against a keyframe list.
void expectKeyframes(Object? spec, List<BeamKeyframe> track, String reason) {
  final rows = (spec! as List).cast<List<dynamic>>();
  expect(rows, hasLength(track.length), reason: '$reason (length)');
  for (var i = 0; i < rows.length; i++) {
    expectNum(track[i].t * 100, rows[i][0], '$reason t$i');
    expectNum(track[i].value, rows[i][1], '$reason value$i');
  }
}

// ─── Spec key ↔ Dart enum mapping ───────────────────────────────────────────

const Map<String, BeamPresetData> _presets = {
  'colorful': colorfulPreset,
  'mono': monoPreset,
  'ocean': oceanPreset,
  'sunset': sunsetPreset,
};

const Map<String, BeamVariant> _sizes = {
  'sm': BeamVariant.small,
  'md': BeamVariant.rotate,
  'line': BeamVariant.line,
  'pulse-outside': BeamVariant.pulseOutside,
  'pulse-inner': BeamVariant.pulseInside,
};

const Map<int, PulseRegion> _regions = {
  1: PulseRegion.r1,
  2: PulseRegion.r2,
  3: PulseRegion.r3,
};

const Map<String, PulseQuad> _quads = {
  'tl': PulseQuad.tl,
  'tr': PulseQuad.tr,
  'bl': PulseQuad.bl,
  'br': PulseQuad.br,
};

void main() {
  final spec = _loadSpec();
  final upstream = _loadUpstream();

  Map<String, dynamic> obj(Map<String, dynamic> from, String key) =>
      from[key] as Map<String, dynamic>;
  List<dynamic> arr(Map<String, dynamic> from, String key) =>
      from[key] as List<dynamic>;

  final palettes = obj(spec, 'palettes');
  final rotate = obj(spec, 'rotate');
  final line = obj(spec, 'line');
  final pulse = obj(spec, 'pulse');
  final defaults = obj(spec, 'defaults');

  // ─── Provenance ───────────────────────────────────────────────────────────

  group('provenance', () {
    test(
      'the fixture is the spec version our constants were audited against',
      () {
        expect(spec['specVersion'], upstreamSpecVersion);
        expect(obj(spec, 'sourceLibrary')['version'], upstreamLibraryVersion);
        expect(obj(spec, 'sourceLibrary')['name'], 'border-beam');
      },
    );

    test('UPSTREAM records the fetched commit and versions', () {
      expect(upstream['commit'], matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(upstream['styles_sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(upstream['version'], upstreamLibraryVersion);
      expect(upstream['spec_version'], upstreamSpecVersion);
      expect(upstreamRepository, contains('Jakubantalik/Libraries'));
    });
  });

  // ─── palettes.border ──────────────────────────────────────────────────────

  group('palettes.border', () {
    final border = obj(palettes, 'border');
    for (final MapEntry(key: name, value: preset) in _presets.entries) {
      final specPreset = obj(border, name);

      test('$name border blobs', () {
        final blobs = specPreset['border'] as List<dynamic>;
        expect(
          preset.border,
          hasLength(blobs.length),
          reason: '$name border length',
        );
        for (var i = 0; i < blobs.length; i++) {
          final b = blobs[i] as Map<String, dynamic>;
          final ours = preset.border[i];
          expectColor(ours.color, b['color'], '$name border[$i].color');
          expectOffset(ours.position, b['pos'], '$name border[$i].pos');
          expectSize(ours.size, b['size'], '$name border[$i].size');
        }
      });

      test('$name spike colors', () {
        final s = obj(specPreset, 'spike');
        expectColor(preset.spike.primary, s['primary'], '$name spike.primary');
        expectColor(
          preset.spike.secondary,
          s['secondary'],
          '$name spike.secondary',
        );
        final lt = obj(specPreset, 'spikeLt');
        expectColor(
          preset.spikeLt.primary,
          lt['primary'],
          '$name spikeLt.primary',
        );
        expectColor(
          preset.spikeLt.secondary,
          lt['secondary'],
          '$name spikeLt.secondary',
        );
      });
    }
  });

  // ─── palettes.small ───────────────────────────────────────────────────────

  group('palettes.small', () {
    final small = obj(palettes, 'small');
    for (final MapEntry(key: name, value: preset) in _presets.entries) {
      final specPreset = obj(small, name);

      void checkTable(String key, List<BeamBlob> ours) {
        final blobs = specPreset[key] as List<dynamic>;
        expect(
          ours,
          hasLength(blobs.length),
          reason: '$name small.$key length',
        );
        for (var i = 0; i < blobs.length; i++) {
          final b = blobs[i] as Map<String, dynamic>;
          expectColor(ours[i].color, b['color'], '$name small.$key[$i].color');
          expectOffset(ours[i].position, b['pos'], '$name small.$key[$i].pos');
          expectSize(ours[i].size, b['size'], '$name small.$key[$i].size');
        }
      }

      test('$name smallBorder', () => checkTable('border', preset.smallBorder));
      test('$name smallInner', () => checkTable('inner', preset.smallInner));
    }
  });

  // ─── palettes.line / palettes.lineInner ───────────────────────────────────

  group('palettes.line', () {
    final specLine = obj(palettes, 'line');
    final specInner = obj(palettes, 'lineInner');

    void checkLineBlobs(
      String reason,
      List<dynamic> blobs,
      List<LineBlob> ours,
    ) {
      expect(ours, hasLength(blobs.length), reason: '$reason length');
      for (var i = 0; i < blobs.length; i++) {
        final b = blobs[i] as Map<String, dynamic>;
        expectColor(ours[i].color, b['color'], '$reason[$i].color');
        expectNum(ours[i].sizeW, b['sizeW'], '$reason[$i].sizeW');
        expectNum(ours[i].sizeH, b['sizeH'], '$reason[$i].sizeH');
        expectNum(ours[i].offsetX, b['offsetX'], '$reason[$i].offsetX');
        expectNum(ours[i].offsetY, b['offsetY'], '$reason[$i].offsetY');
      }
    }

    for (final MapEntry(key: name, value: preset) in _presets.entries) {
      test('$name lineDark', () {
        checkLineBlobs(
          '$name line.dark',
          arr(obj(specLine, name), 'dark'),
          preset.lineDark,
        );
      });
      test('$name lineLight', () {
        checkLineBlobs(
          '$name line.light',
          arr(obj(specLine, name), 'light'),
          preset.lineLight,
        );
      });
      test('$name lineInner', () {
        checkLineBlobs(
          '$name lineInner',
          specInner[name] as List<dynamic>,
          preset.lineInner,
        );
      });
    }
  });

  // ─── palettes.lineBloom ───────────────────────────────────────────────────

  group('palettes.lineBloom', () {
    final bloom = obj(palettes, 'lineBloom');
    for (final MapEntry(key: name, value: preset) in _presets.entries) {
      for (final theme in const ['dark', 'light']) {
        test('$name lineBloom.$theme', () {
          final spikes = arr(obj(obj(bloom, name), theme), 'spikes');
          final ours = theme == 'dark'
              ? preset.lineBloomDark
              : preset.lineBloomLight;
          expect(
            ours,
            hasLength(spikes.length),
            reason: '$name lineBloom.$theme length',
          );
          for (var i = 0; i < spikes.length; i++) {
            final s = spikes[i] as Map<String, dynamic>;
            expectColor(
              ours[i].color1,
              s['color1'],
              '$name lineBloom.$theme[$i].c1',
            );
            expectColor(
              ours[i].color2,
              s['color2'],
              '$name lineBloom.$theme[$i].c2',
            );
          }
        });
      }
    }
  });

  // ─── sizeThemePresets ─────────────────────────────────────────────────────

  group('sizeThemePresets', () {
    final presets = obj(spec, 'sizeThemePresets');
    for (final MapEntry(key: size, value: variant) in _sizes.entries) {
      for (final theme in const ['dark', 'light']) {
        test('$size/$theme', () {
          final s = obj(obj(presets, size), theme);
          final ours = themePresetFor(
            variant,
            theme == 'dark' ? Brightness.dark : Brightness.light,
          );
          expectNum(
            ours.strokeOpacity,
            s['strokeOpacity'],
            '$size/$theme strokeOpacity',
          );
          expectNum(
            ours.innerOpacity,
            s['innerOpacity'],
            '$size/$theme innerOpacity',
          );
          expectNum(
            ours.bloomOpacity,
            s['bloomOpacity'],
            '$size/$theme bloomOpacity',
          );
          expectColor(
            ours.innerShadow,
            s['innerShadow'],
            '$size/$theme innerShadow',
          );
          expectNum(
            ours.saturation,
            s['saturation'],
            '$size/$theme saturation',
          );

          // `brightness` and `hairlineOpacity` are optional in the spec; a
          // missing key must mean a null field on our side, not a default.
          if (s.containsKey('brightness')) {
            expect(
              ours.brightness,
              isNotNull,
              reason: '$size/$theme brightness present in spec',
            );
            expectNum(
              ours.brightness!,
              s['brightness'],
              '$size/$theme brightness',
            );
          } else {
            expect(
              ours.brightness,
              isNull,
              reason: '$size/$theme brightness absent from spec',
            );
          }
          if (s.containsKey('hairlineOpacity')) {
            expect(
              ours.hairlineOpacity,
              isNotNull,
              reason: '$size/$theme hairlineOpacity present in spec',
            );
            expectNum(
              ours.hairlineOpacity!,
              s['hairlineOpacity'],
              '$size/$theme hairlineOpacity',
            );
          } else {
            expect(
              ours.hairlineOpacity,
              isNull,
              reason: '$size/$theme hairlineOpacity absent from spec',
            );
          }
        });
      }
    }
  });

  // ─── sizePresets ──────────────────────────────────────────────────────────

  group('sizePresets', () {
    final presets = obj(spec, 'sizePresets');
    for (final MapEntry(key: size, value: variant) in _sizes.entries) {
      test('$size radius and border width', () {
        final s = obj(presets, size);
        expectNum(
          variant.defaultBorderRadius,
          s['borderRadius'],
          '$size borderRadius',
        );
        expectNum(
          variant.defaultBorderWidth,
          s['borderWidth'],
          '$size borderWidth',
        );
      });
    }
    // GAP: sizePresets.sm.width/height (70×36) has no counterpart — the
    // Flutter widget wraps and measures its child instead of forcing a size.
  });

  // ─── rotate.* ─────────────────────────────────────────────────────────────

  group('rotate stops', () {
    test('beamMaskStops ↔ rotateWindow*', () {
      expectStopTable(
        rotate['beamMaskStops'],
        rotateWindowStops,
        rotateWindowAlphas,
        'beamMaskStops',
      );
    });

    test('smallMaskStops ↔ smallWindow*', () {
      expectStopTable(
        rotate['smallMaskStops'],
        smallWindowStops,
        smallWindowAlphas,
        'smallMaskStops',
      );
    });

    test('whiteGradientStops.dark ↔ rotateHighlight*Dark', () {
      expectStopTable(
        obj(rotate, 'whiteGradientStops')['dark'],
        rotateHighlightStops,
        rotateHighlightAlphasDark,
        'whiteGradient.dark',
      );
    });

    test('whiteGradientStops.light ↔ rotateHighlight*Light', () {
      expectStopTable(
        obj(rotate, 'whiteGradientStops')['light'],
        rotateHighlightStops,
        rotateHighlightAlphasLight,
        'whiteGradient.light',
      );
    });

    test('bloomGradientStops.dark ↔ rotateBloom*Dark', () {
      expectStopTable(
        obj(rotate, 'bloomGradientStops')['dark'],
        rotateBloomStops,
        rotateBloomAlphasDark,
        'bloomGradient.dark',
        terminatedAt1: true,
      );
    });

    test('bloomGradientStops.light ↔ rotateBloom*Light', () {
      expectStopTable(
        obj(rotate, 'bloomGradientStops')['light'],
        rotateBloomStops,
        rotateBloomAlphasLight,
        'bloomGradient.light',
        terminatedAt1: true,
      );
    });
  });

  group('rotate constants', () {
    test('innerGradientDerivation ↔ rotateInnerBlob*', () {
      final d = obj(rotate, 'innerGradientDerivation');
      expectNum(rotateInnerBlobScale, d['sizeScale'], 'inner sizeScale');
      expectNum(rotateInnerBlobAlpha, d['alpha'], 'inner alpha');
      expectNum(rotateInnerBlobAlphaMono, d['monoAlpha'], 'inner monoAlpha');
    });

    test('innerShadowBlur ↔ rotate/small inner shadow blur', () {
      final b = obj(rotate, 'innerShadowBlur');
      expectNum(rotateInnerShadowBlur, b['md'], 'innerShadowBlur.md');
      expectNum(smallInnerShadowBlur, b['sm'], 'innerShadowBlur.sm');
    });

    test('bloomBlurPx ↔ rotateBloomBlurSigma', () {
      // CSS `filter: blur(Npx)` maps to sigma = N.
      expectNum(rotateBloomBlurSigma, rotate['bloomBlurPx'], 'bloomBlurPx');
    });

    // GAP: rotate.innerEdgeMaskPx (28) and rotate.spin (0→360, linear) have no
    // constant of their own — the feather is a default argument on
    // `BeamGradients.vertical/horizontalEdgeFeather` and the spin is the
    // rotate variant's angle = travelProgress × 2π.
  });

  // ─── line geometry ────────────────────────────────────────────────────────

  group('line geometry', () {
    test('beamMaskEllipse ↔ lineWindow*', () {
      final e = obj(line, 'beamMaskEllipse');
      expectNum(lineWindowRadiusX, e['w'], 'beamMask w');
      expectNum(lineWindowRadiusY, e['h'], 'beamMask h');
      final soft = (e['softStop']! as List).cast<num>();
      expectNum(lineWindowMidStop * 100, soft[0], 'beamMask soft stop');
      expectNum(lineWindowMidAlpha, soft[1], 'beamMask soft alpha');
    });

    test('bloomMaskEllipse ↔ lineBloomWindow*', () {
      final e = obj(line, 'bloomMaskEllipse');
      expectNum(lineBloomWindowRadiusX, e['w'], 'bloomMask w');
      expectNum(lineBloomWindowRadiusY, e['h'], 'bloomMask h');
      final soft = (e['softStop']! as List).cast<num>();
      expectNum(lineBloomWindowMidStop * 100, soft[0], 'bloomMask soft stop');
      expectNum(lineBloomWindowMidAlpha, soft[1], 'bloomMask soft alpha');
    });

    test('whiteHighlight.dark ↔ lineHighlight*Dark', () {
      final h = obj(obj(line, 'whiteHighlight'), 'dark');
      expectNum(lineHighlightRadiusXDark, h['w'], 'highlight.dark w');
      expectNum(lineHighlightRadiusYDark, h['h'], 'highlight.dark h');
      expectNum(lineHighlightOffsetY, h['yOffset'], 'highlight.dark yOffset');
      expectStopTable(
        h['stops'],
        lineHighlightStopsDark,
        lineHighlightAlphasDark,
        'highlight.dark stops',
      );
    });

    test('whiteHighlight.light ↔ lineHighlight*Light', () {
      final h = obj(obj(line, 'whiteHighlight'), 'light');
      expectNum(lineHighlightRadiusXLight, h['w'], 'highlight.light w');
      expectNum(lineHighlightRadiusYLight, h['h'], 'highlight.light h');
      expectNum(lineHighlightOffsetY, h['yOffset'], 'highlight.light yOffset');
      expectStopTable(
        h['stops'],
        lineHighlightStopsLight,
        lineHighlightAlphasLight,
        'highlight.light stops',
      );
      // The light-theme highlight paints black, not white.
      expect(h['onBlack'], isTrue);
    });

    test('bloom blur sigmas', () {
      expectNum(lineBloomBlurSigma, line['bloomBlurPx'], 'line bloomBlurPx');
      // The spec calls this key `monoBloomExtraBlurPx`, but in `styles.ts` the
      // mono branch REPLACES the animated bloom filter (`blur(8px) hue-rotate…`)
      // with a bare `filter: blur(6px)` — it does not add to it. The value is
      // the mono sigma, which is what we store.
      expectNum(
        lineBloomBlurSigmaMono,
        line['monoBloomExtraBlurPx'],
        'line monoBloomExtraBlurPx',
      );
    });

    // GAP: no `line.innerShadowBlur` in the spec; `lineInnerShadowBlur` (9)
    // is transcribed from `box-shadow: inset 0 0 9px 1px` in styles.ts.
  });

  // ─── line keyframes ───────────────────────────────────────────────────────

  group('line keyframes', () {
    final kf = obj(line, 'keyframes');

    test('travel.x ↔ lineTravelX', () {
      expectKeyframes(obj(kf, 'travel')['x'], lineTravelX, 'travel.x');
    });
    test('travel.w ↔ lineTravelW', () {
      expectKeyframes(obj(kf, 'travel')['w'], lineTravelW, 'travel.w');
    });
    test('edgeFade ↔ lineEdgeFade', () {
      expectKeyframes(kf['edgeFade'], lineEdgeFade, 'edgeFade');
    });
    test('breathe ↔ lineBreatheH', () {
      expectKeyframes(kf['breathe'], lineBreatheH, 'breathe');
    });
    test('spike ↔ lineSpike', () {
      expectKeyframes(kf['spike'], lineSpike, 'spike');
    });
    test('spike2 ↔ lineSpike2', () {
      expectKeyframes(kf['spike2'], lineSpike2, 'spike2');
    });

    test('durationScale ↔ BeamConfig breathe/spike factors', () {
      final s = obj(kf, 'durationScale');
      final config = _configFor(BeamVariant.line);
      expectNum(1, s['travel'], 'durationScale.travel');
      expectNum(1, s['edgeFade'], 'durationScale.edgeFade');
      expectNum(config.breatheFactor, s['breathe'], 'durationScale.breathe');
      expectNum(config.spikeFactor, s['spike'], 'durationScale.spike');
      expectNum(config.spike2Factor, s['spike2'], 'durationScale.spike2');
    });

    test('easing per track', () {
      final e = obj(kf, 'easing');
      // The travel/edge tracks sample linearly; breathe/spike ease per
      // segment (`sampleKeyframes(..., easedSegments: true)`).
      expect(e['travel'], 'linear');
      expect(e['edgeFade'], 'linear');
      expect(e['breathe'], 'easeInOut');
      expect(e['spike'], 'easeInOut');
      expect(e['spike2'], 'easeInOut');
    });
  });

  // ─── line.bloomGradients — the expanded spike table ───────────────────────
  //
  // The spec expands each palette × theme into 7 fixed spikes plus (dark) the
  // traveling dot and ambient glow, or (light) the traveling shadow. Our port
  // keeps the geometry in `line_geometry.dart` and the colors in the palette
  // tables, with the mono attenuation applied at paint time — so the mono rows
  // are compared against `ourAlpha × attenuation`.

  group('line.bloomGradients', () {
    final grads = obj(line, 'bloomGradients');

    /// Indices of the four thin (color-palette) spikes within the 7.
    const thin = [0, 2, 4, 6];

    for (final MapEntry(key: name, value: preset) in _presets.entries) {
      final isMono = name == 'mono';
      for (final theme in const ['dark', 'light']) {
        final isDark = theme == 'dark';

        test('$name/$theme spike geometry', () {
          final rows = arr(
            obj(grads, name),
            theme,
          ).cast<Map<String, dynamic>>();
          expect(lineSpikes, hasLength(7));
          for (var i = 0; i < 7; i++) {
            final r = rows[i];
            final s = lineSpikes[i];
            expectNum(s.fx * 100, r['xPct'], '$name/$theme spike$i xPct');
            expectNum(-s.yInset, r['yOffPx'], '$name/$theme spike$i yOffPx');
            final stops = (r['stops']! as List).cast<Map<String, dynamic>>();
            expect(
              stops,
              hasLength(3),
              reason: '$name/$theme spike$i stop count',
            );
            expectNum(0, stops[0]['pos'], '$name/$theme spike$i pos0');
            expectNum(s.midStop, stops[1]['pos'], '$name/$theme spike$i mid');
            expectNum(s.endStop, stops[2]['pos'], '$name/$theme spike$i end');
            expectNum(0, stops[2]['a'], '$name/$theme spike$i end alpha');

            // Radii.
            final w = obj(r, 'w')['base']! as num;
            final h = obj(r, 'h')['base']! as num;
            final t = thin.indexOf(i);
            if (t >= 0) {
              final wantW = isMono
                  ? (i == 6 && !isDark
                        ? lineMonoThinSpikeWidthLight92
                        : lineMonoThinSpikeWidths[t])
                  : (i == 6 && !isDark
                        ? lineThinSpikeWidthLight92
                        : lineThinSpikeWidths[t]);
              final wantH = isMono
                  ? lineMonoThinSpikeHeights[t]
                  : lineThinSpikeHeights[t];
              expectNum(wantW, w, '$name/$theme spike$i width');
              expectNum(wantH, h, '$name/$theme spike$i height');
            } else {
              final wantW = switch (i) {
                1 => lineSpikeWideRadiusX22,
                3 => lineSpikeWideRadiusX50,
                _ => lineSpikeRadiusX78,
              };
              final wantH = switch (i) {
                1 => lineSpikeRadiusY22,
                3 => lineSpikeRadiusY50,
                _ => lineSpikeRadiusY78,
              };
              expectNum(wantW, w, '$name/$theme spike$i width');
              expectNum(wantH, h, '$name/$theme spike$i height');
            }
          }
        });

        test('$name/$theme spike colors', () {
          final rows = arr(
            obj(grads, name),
            theme,
          ).cast<Map<String, dynamic>>();
          final spikes = isDark ? preset.spike : preset.spikeLt;
          final table = isDark ? preset.lineBloomDark : preset.lineBloomLight;

          List<Map<String, dynamic>> stopsOf(int i) =>
              (rows[i]['stops']! as List).cast<Map<String, dynamic>>();

          // Spike 0 — the primary accent.
          final s0 = stopsOf(0);
          expectChannels(
            spikes.primary,
            stop: s0[0],
            reason: '$name/$theme spike0 core',
            alphaScale: isMono ? lineMonoSpike1 : 1,
          );
          expectChannels(
            spikes.primary,
            stop: s0[1],
            reason: '$name/$theme spike0 mid',
            alphaScale: isMono
                ? (isDark ? lineMonoSpike1MidDark : lineMonoSpike1MidLight)
                : (isDark ? 1 : lineSpike1MidLightAlpha),
          );

          // Spike 1 — the secondary accent.
          final s1 = stopsOf(1);
          expectChannels(
            spikes.secondary,
            stop: s1[0],
            reason: '$name/$theme spike1 core',
            alphaScale: isMono ? lineMonoSpike2 : 1,
          );
          expectChannels(
            spikes.secondary,
            stop: s1[1],
            reason: '$name/$theme spike1 mid',
            alphaScale: isMono
                ? (isDark ? lineMonoSpike2MidDark : lineMonoSpike2MidLight)
                : (isDark ? lineSpike2MidDarkAlpha : lineSpike2MidLightAlpha) /
                      spikes.secondary.a,
          );

          // Spikes 2–6 — the five palette bloom pairs.
          for (var i = 2; i < 7; i++) {
            final st = stopsOf(i);
            final pair = table[i - 2];
            expectChannels(
              pair.color1,
              stop: st[0],
              reason: '$name/$theme spike$i core',
              alphaScale: isMono ? lineMonoTableSpike1 : 1,
            );
            expectChannels(
              pair.color2,
              stop: st[1],
              reason: '$name/$theme spike$i mid',
              alphaScale: isMono ? lineMonoTableSpike2 : 1,
            );
          }
        });

        test('$name/$theme traveling dot, ambient glow and shadow', () {
          final rows = arr(
            obj(grads, name),
            theme,
          ).cast<Map<String, dynamic>>();
          if (isDark) {
            expect(
              rows,
              hasLength(9),
              reason: 'dark carries dot + ambient after the 7 spikes',
            );
            final dot = rows[7];
            expectNum(lineDotOffsetY, dot['yOffPx'], '$name dot yOffPx');
            expectNum(lineDotRadiusX, obj(dot, 'w')['base'], '$name dot w');
            expectNum(lineDotRadiusY, obj(dot, 'h')['base'], '$name dot h');
            final dotStops = (dot['stops']! as List)
                .cast<Map<String, dynamic>>();
            final dotAlphas = isMono ? lineDotAlphasMono : lineDotAlphas;
            for (var i = 0; i < lineDotStops.length; i++) {
              expectNum(lineDotStops[i], dotStops[i]['pos'], '$name dot pos$i');
              expectNum(
                i < dotAlphas.length ? dotAlphas[i] : 0,
                dotStops[i]['a'],
                '$name dot alpha$i',
              );
              expectNum(255, dotStops[i]['r'], '$name dot is white');
            }

            final amb = rows[8];
            expectNum(0, amb['yOffPx'], '$name ambient yOffPx');
            expectNum(lineAmbientRadiusX, obj(amb, 'w')['base'], '$name amb w');
            expectNum(lineAmbientRadiusY, obj(amb, 'h')['base'], '$name amb h');
            final ambStops = (amb['stops']! as List)
                .cast<Map<String, dynamic>>();
            final ambAlphas = isMono
                ? lineAmbientAlphasMono
                : lineAmbientAlphas;
            for (var i = 0; i < lineAmbientStops.length; i++) {
              expectNum(
                lineAmbientStops[i],
                ambStops[i]['pos'],
                '$name amb pos$i',
              );
              expectNum(
                i < ambAlphas.length ? ambAlphas[i] : 0,
                ambStops[i]['a'],
                '$name amb alpha$i',
              );
            }
          } else {
            expect(
              rows,
              hasLength(8),
              reason: 'light carries one shadow blob after the 7 spikes',
            );
            final sh = rows[7];
            expectNum(0, sh['yOffPx'], '$name shadow yOffPx');
            expectNum(
              lineShadowRadiusX,
              obj(sh, 'w')['base'],
              '$name shadow w',
            );
            expectNum(
              lineShadowRadiusY,
              obj(sh, 'h')['base'],
              '$name shadow h',
            );
            final shStops = (sh['stops']! as List).cast<Map<String, dynamic>>();
            for (var i = 0; i < lineShadowStops.length; i++) {
              expectNum(
                lineShadowStops[i],
                shStops[i]['pos'],
                '$name shadow pos$i',
              );
              expectNum(
                lineShadowAlphas[i],
                shStops[i]['a'],
                '$name shadow alpha$i',
              );
              expectNum(0, shStops[i]['r'], '$name shadow is black');
            }
          }
        });
      }
    }
  });

  // ─── pulse tables ─────────────────────────────────────────────────────────

  group('pulse tables', () {
    test('ringMap ↔ pulseRingMap', () {
      final rows = arr(pulse, 'ringMap').cast<Map<String, dynamic>>();
      expect(pulseRingMap, hasLength(rows.length));
      for (var i = 0; i < rows.length; i++) {
        expect(
          pulseRingMap[i].region,
          _regions[rows[i]['region']],
          reason: 'ringMap[$i].region',
        );
        expect(
          pulseRingMap[i].quad,
          _quads[rows[i]['quad']],
          reason: 'ringMap[$i].quad',
        );
      }
    });

    test('innerSizes ↔ pulseInnerSizes', () {
      final rows = arr(pulse, 'innerSizes').cast<List<dynamic>>();
      expect(pulseInnerSizes, hasLength(rows.length));
      for (var i = 0; i < rows.length; i++) {
        expectNum(pulseInnerSizes[i].width, rows[i][0], 'innerSizes[$i].w');
        expectNum(pulseInnerSizes[i].height, rows[i][1], 'innerSizes[$i].h');
      }
    });

    void checkSpecs(
      String key,
      List<PulseBlobSpec> ours, {
      required bool positioned,
    }) {
      final rows = arr(pulse, key).cast<Map<String, dynamic>>();
      expect(ours, hasLength(rows.length), reason: '$key length');
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        expect(ours[i].ci, r['ci'], reason: '$key[$i].ci');
        expect(
          ours[i].region,
          _regions[r['region']],
          reason: '$key[$i].region',
        );
        expect(ours[i].quad, _quads[r['quad']], reason: '$key[$i].quad');
        expectNum(ours[i].w, r['w'], '$key[$i].w');
        expectNum(ours[i].h, r['h'], '$key[$i].h');
        if (positioned) {
          expect(ours[i].x, isNotNull, reason: '$key[$i].x');
          expect(ours[i].y, isNotNull, reason: '$key[$i].y');
          expect(
            ours[i].x!,
            closeTo(cssPercent(r['x']), _epsilon),
            reason: '$key[$i].x',
          );
          expect(
            ours[i].y!,
            closeTo(cssPercent(r['y']), _epsilon),
            reason: '$key[$i].y',
          );
        } else {
          expect(r.containsKey('x'), isFalse, reason: '$key[$i] has no x');
          expect(ours[i].x, isNull, reason: '$key[$i].x inherits');
          expect(ours[i].y, isNull, reason: '$key[$i].y inherits');
        }
      }
    }

    test('innerBloom ↔ pulseInnerBloom', () {
      checkSpecs('innerBloom', pulseInnerBloom, positioned: false);
    });
    test('outerCore ↔ pulseOuterCore', () {
      checkSpecs('outerCore', pulseOuterCore, positioned: true);
    });
    test('outerBloom ↔ pulseOuterBloom', () {
      checkSpecs('outerBloom', pulseOuterBloom, positioned: true);
    });

    test('innerCornerAccent ↔ pulseInnerCorner*', () {
      final a = obj(pulse, 'innerCornerAccent');
      expectNum(pulseInnerCornerRadius, a['sizePx'], 'cornerAccent sizePx');
      expectNum(
        pulseInnerCornerAlphaDark,
        obj(a, 'alpha')['dark'],
        'cornerAccent alpha.dark',
      );
      expectNum(
        pulseInnerCornerAlphaLight,
        obj(a, 'alpha')['light'],
        'cornerAccent alpha.light',
      );
      expectNum(
        pulseInnerCornerEndStop * 100,
        a['fadeStop'],
        'cornerAccent fadeStop',
      );
    });

    test('innerBloomBlurPx ↔ pulseInnerBloomBlurSigma', () {
      expectNum(
        pulseInnerBloomBlurSigma,
        pulse['innerBloomBlurPx'],
        'innerBloomBlurPx',
      );
    });

    test('oscillatorCurve is the cosine ping-pong we implement', () {
      expect(pulse['oscillatorCurve'], 'cosinePingPong');
      expect(pingPong(0), closeTo(0, _epsilon));
      expect(pingPong(0.5), closeTo(1, _epsilon));
      expect(pingPong(1), closeTo(0, _epsilon));
      // Cosine is even, so negative phases (positive delays) are valid.
      expect(pingPong(-0.25), closeTo(pingPong(0.25), _epsilon));
    });
  });

  // ─── pulse params, oscillators and hue periods ────────────────────────────

  group('pulse params', () {
    const variants = {
      'inner': BeamVariant.pulseInside,
      'outside': BeamVariant.pulseOutside,
    };

    for (final MapEntry(key: key, value: variant) in variants.entries) {
      for (final theme in const ['dark', 'light']) {
        final brightness = theme == 'dark' ? Brightness.dark : Brightness.light;

        test('$key/$theme params ↔ PulseParams.resolve', () {
          final s = obj(obj(obj(pulse, key), theme), 'params');
          // 2.3 is the source's pulse cycle duration, at which durScale == 1.
          final p = PulseParams.resolve(variant, brightness, 2.3);
          expectNum(p.sp, s['sp'], '$key/$theme sp');
          expectNum(p.dr, s['dr'], '$key/$theme dr');
          expectNum(p.op, s['op'], '$key/$theme op');
          expectNum(p.gh, s['gh'], '$key/$theme gh');
          expectNum(p.bs, s['bs'], '$key/$theme bs');
          expectNum(p.ss, s['ss'], '$key/$theme ss');
          expectNum(p.ghs, s['ghs'], '$key/$theme ghs');
          expectNum(p.huePeriod, s['huePeriod'], '$key/$theme huePeriod');
        });

        test('$key/$theme oscillators ↔ PulseOscillatorBank', () {
          final rows = arr(
            obj(obj(pulse, key), theme),
            'oscillators',
          ).cast<Map<String, dynamic>>();
          final bank = PulseOscillatorBank(
            PulseParams.resolve(variant, brightness, 2.3),
          );
          expect(
            bank.oscillators,
            hasLength(rows.length),
            reason: '$key/$theme oscillator count',
          );
          expect(
            bank.oscillators.keys.toList(),
            rows.map((r) => r['prop']).toList(),
            reason: '$key/$theme oscillator order',
          );
          for (final r in rows) {
            final prop = r['prop']! as String;
            final o = bank.oscillators[prop]!;
            expectNum(o.a, r['a'], '$key/$theme $prop.a');
            expectNum(o.b, r['b'], '$key/$theme $prop.b');
            expectNum(o.period, r['period'], '$key/$theme $prop.period');
            expectNum(o.delay, r['delay'], '$key/$theme $prop.delay');
            expect(
              r['unit'],
              prop.startsWith('bx') || prop.startsWith('by') ? 'px' : '',
              reason: '$key/$theme $prop.unit',
            );
          }
        });

        test('$key/$theme frozenBloomAlpha ↔ 1 − op/2', () {
          final s = obj(obj(pulse, key), theme);
          final p = PulseParams.resolve(variant, brightness, 2.3);
          expectNum(
            1 - p.op * 0.5,
            s['frozenBloomAlpha'],
            '$key/$theme frozenBloomAlpha',
          );
        });
      }
    }

    test('huePeriod ↔ BeamVariant.defaultHuePeriod', () {
      final h = obj(pulse, 'huePeriod');
      expectNum(
        BeamVariant.pulseInside.defaultHuePeriod.inMilliseconds / 1000,
        h['pulse-inner'],
        'pulse-inner huePeriod',
      );
      expectNum(
        BeamVariant.pulseOutside.defaultHuePeriod.inMilliseconds / 1000,
        h['pulse-outside'],
        'pulse-outside huePeriod',
      );
    });
  });

  // ─── pulse.outsideConstants ───────────────────────────────────────────────

  group('pulse.outsideConstants', () {
    // Only the VERBATIM half of `pulse_constants.dart` maps here. The blur and
    // inset values below them in that file are the source demo page's tuned
    // `.beam-host--pulse-outside-tuned` recipe, which this port bakes in — the
    // spec records the library's untuned defaults instead, so they are
    // deliberately not compared. See the file header.
    final c = obj(pulse, 'outsideConstants');

    test('glowScale ↔ pulseOuterScaleX/Y', () {
      expectNum(pulseOuterScaleX, obj(c, 'glowScale')['x'], 'glowScale.x');
      expectNum(pulseOuterScaleY, obj(c, 'glowScale')['y'], 'glowScale.y');
    });

    test('referenceSize ↔ pulseOuterReference*', () {
      expectNum(
        pulseOuterReferenceWidth,
        obj(c, 'referenceSize')['w'],
        'referenceSize.w',
      );
      expectNum(
        pulseOuterReferenceHeight,
        obj(c, 'referenceSize')['h'],
        'referenceSize.h',
      );
    });

    test('scaleClamp ↔ pulseOuterMin/MaxScale', () {
      expectNum(pulseOuterMinScale, obj(c, 'scaleClamp')['min'], 'clamp.min');
      expectNum(pulseOuterMaxScale, obj(c, 'scaleClamp')['max'], 'clamp.max');
    });

    // GAPS in pulse_constants.dart, all deliberate:
    //  * glowBlurPx (3/6), bloomBlurPx (22.5/15), coreInsetPx (10),
    //    bloomInsetPx (30) — the library's untuned defaults; the port ships
    //    the demo recipe (6/14 insets, 10/19 unit-scaled blurs) instead, all
    //    overridable through coreBlur/bloomBlur.
    //  * hairline.rgb (dark 70,70,70 / light 0,0,0) — lives inline in
    //    `PulseOuterStrategy.paintAbove`, not in a constant.
    //  * pulseOuterGlowUnitDamping (0.7) has no spec counterpart.
  });

  // ─── defaults ─────────────────────────────────────────────────────────────

  group('defaults', () {
    test('cycle durations ↔ BeamVariant.defaultCycleDuration', () {
      final d = obj(defaults, 'duration');
      double secs(BeamVariant v) =>
          v.defaultCycleDuration.inMicroseconds / 1000000;
      expectNum(secs(BeamVariant.rotate), d['rotate'], 'rotate duration');
      expectNum(secs(BeamVariant.small), d['rotate'], 'small duration');
      expectNum(secs(BeamVariant.line), d['line'], 'line duration');
      expectNum(secs(BeamVariant.pulseInside), d['pulse'], 'pulseInside');
      expectNum(secs(BeamVariant.pulseOutside), d['pulse'], 'pulseOutside');
    });

    test('hueRange and the line cap ↔ BeamConfig.resolve', () {
      expectNum(
        _configFor(BeamVariant.rotate).hueRange,
        defaults['hueRange'],
        'default hueRange',
      );
      // The line variant caps the range; a range under the cap passes through.
      expectNum(
        _configFor(BeamVariant.line).hueRange,
        defaults['lineHueRangeCap'],
        'line hueRange cap',
      );
      expect(_configFor(BeamVariant.line, hueRange: 5).hueRange, 5.0);
    });

    test('fade seconds ↔ BeamClock', () {
      expectNum(BeamClock.fadeInSeconds, defaults['fadeInSeconds'], 'fadeIn');
      expectNum(
        BeamClock.fadeOutSeconds,
        defaults['fadeOutSeconds'],
        'fadeOut',
      );
    });

    test('strength and brightness fallback ↔ BeamConfig.resolve', () {
      expectNum(
        _configFor(BeamVariant.rotate).strength,
        defaults['strength'],
        'default strength',
      );
      // `md` has no `brightness` in its theme preset, so the fallback shows.
      expect(
        themePresetFor(BeamVariant.rotate, Brightness.dark).brightness,
        isNull,
      );
      expectNum(
        _configFor(BeamVariant.rotate).brightnessFactor,
        defaults['brightnessFallback'],
        'brightness fallback',
      );
    });

    test('mono treatment ↔ BeamColors.mono', () {
      final mono = BeamColors.mono.resolve();
      expectNum(
        mono.opacityMultiplier,
        defaults['monoOpacityMultiplier'],
        'monoOpacityMultiplier',
      );
      expect(mono.forcesStaticColors, defaults['monoForcesStaticColors']);
      expect(mono.monoTreatment, isTrue);
    });

    test('hue-shift periods ↔ BeamVariant defaults', () {
      double secs(Duration d) => d.inMicroseconds / 1000000;
      for (final v in [
        BeamVariant.rotate,
        BeamVariant.small,
        BeamVariant.line,
      ]) {
        expectNum(
          secs(v.defaultHuePeriod),
          defaults['rotateHueShiftPeriod'],
          '$v huePeriod',
        );
      }
      expectNum(
        secs(BeamVariant.line.defaultBloomHuePeriod),
        defaults['lineBloomHueShiftPeriod'],
        'line bloom huePeriod',
      );
    });

    test('line bloom hue range carries the +10° bonus', () {
      final config = _configFor(BeamVariant.line);
      final resolver = BeamPhaseResolver(config);
      // `_pingPongHue` reaches −range at t=0 and +range at half a period.
      final low = resolver.sample(0, 1).bloomHueDegrees;
      final high = resolver
          .sample(config.bloomHuePeriodSeconds / 2, 1)
          .bloomHueDegrees;
      expectNum(
        (high - low) / 2 - config.hueRange,
        defaults['lineBloomHueRangeBonus'],
        'lineBloomHueRangeBonus',
      );
    });

    test('the spec\'s declared defaults name our built-ins', () {
      expect(defaults['size'], 'md');
      expect(defaults['colorVariant'], 'colorful');
      expect(defaults['theme'], 'dark');
      expect(defaults['fadeEasing'], 'ease');
    });

    // GAP: `defaults.pulseDriverFps` (30) is the source's pulse-driver tick
    // rate; ours is BeamClock's optional fps cap, not a constant.
    // GAP: `filters.order` / `filters.hueRotateModel` describe the CSS filter
    // pipeline our `BeamColorMatrix` implements; no constant mirrors them.
  });

  // ─── enums ────────────────────────────────────────────────────────────────

  group('enums', () {
    test('sizes ↔ BeamVariant', () {
      expect(
        arr(obj(spec, 'enums'), 'sizes').cast<String>().toSet(),
        _sizes.keys.toSet(),
      );
      expect(_sizes.values.toSet(), BeamVariant.values.toSet());
    });

    test('colorVariants ↔ the four transcribed presets', () {
      expect(
        arr(obj(spec, 'enums'), 'colorVariants').cast<String>().toSet(),
        _presets.keys.toSet(),
      );
    });

    test('themes ↔ Brightness', () {
      expect(arr(obj(spec, 'enums'), 'themes').cast<String>(), [
        'dark',
        'light',
      ]);
    });
  });
}

/// A resolved config for [variant] at the source's defaults.
BeamConfig _configFor(BeamVariant variant, {double? hueRange}) =>
    BeamConfig.resolve(
      variant: variant,
      palette: const BeamPalette(data: colorfulPreset),
      brightness: Brightness.dark,
      style: hueRange == null
          ? const BeamStyle()
          : BeamStyle(hueRange: hueRange),
    );
