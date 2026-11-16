import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/distortion_wave/models/wave_motion.dart';
import 'package:prismatic/src/distortion_wave/models/wave_spec.dart';
import 'package:prismatic/src/distortion_wave/models/wave_style.dart';
import 'package:prismatic/src/distortion_wave/models/wave_type.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_frame.dart';

/// Property tests over `WaveFrame.at`.
///
/// A wave is a pure function of progress, which is what lets it be
/// scrubbed, reversed and frozen for a golden. These tests assert that
/// purity, the range every field may occupy, and the monotonic parts of the
/// wave's life — over a seeded random sweep of views, sources, touches and
/// progress across all three wave types, rather than the reference's
/// hand-picked screen and button.
void main() {
  const scenesPerType = 40;
  const samplesPerScene = 60;

  /// One random wave: a view, a source inside it, maybe a touch near the
  /// source, and a spec of [type] with a random lean and launch gap.
  ({Size size, Rect source, Offset? focus, WaveSpec spec}) scene(
    math.Random random,
    WaveType type,
  ) {
    double between(double a, double b) => a + (b - a) * random.nextDouble();
    final size = Size(between(120, 1400), between(120, 1400));
    final width = between(8, size.width);
    final height = between(8, size.height);
    final source = Rect.fromLTWH(
      between(0, size.width - width),
      between(0, size.height - height),
      width,
      height,
    );
    final focus = random.nextInt(3) == 0
        ? null
        : Offset(
            between(source.left - 40, source.right + 40),
            between(source.top - 40, source.bottom + 40),
          );
    final spec = WaveSpec.resolve(
      WaveStyle(
        type: type,
        motion: WaveMotion(
          orientation: random.nextDouble(),
          launchGap: between(0, 40),
        ),
      ),
    );
    return (size: size, source: source, focus: focus, spec: spec);
  }

  String describe(({Size size, Rect source, Offset? focus, WaveSpec spec}) s) =>
      '${s.spec.type.name} size=${s.size} source=${s.source} '
      'focus=${s.focus} orientation=${s.spec.orientation} '
      'gap=${s.spec.launchGap}';

  WaveFrame frameOf(
    ({Size size, Rect source, Offset? focus, WaveSpec spec}) s,
    double progress, {
    WaveSpec? spec,
  }) => WaveFrame.at(
    progress: progress,
    source: s.source,
    size: s.size,
    spec: spec ?? s.spec,
    focus: s.focus,
  );

  void expectSameFrame(WaveFrame a, WaveFrame b, String at) {
    expect(a.origin, b.origin, reason: 'origin $at');
    expect(a.tilt, b.tilt, reason: 'tilt $at');
    expect(a.spine, b.spine, reason: 'spine $at');
    expect(a.radius, b.radius, reason: 'radius $at');
    expect(a.moved, b.moved, reason: 'moved $at');
    expect(a.squash, b.squash, reason: 'squash $at');
    expect(a.time, b.time, reason: 'time $at');
    expect(a.energy, b.energy, reason: 'energy $at');
    expect(a.swell, b.swell, reason: 'swell $at');
    expect(a.size, b.size, reason: 'size $at');
    expect(a.gravity, b.gravity, reason: 'gravity $at');
    expect(a.glow, b.glow, reason: 'glow $at');
    expect(a.clearRadius, b.clearRadius, reason: 'clearRadius $at');
    expect(a.hairClearRadius, b.hairClearRadius, reason: 'hairClear $at');
    expect(a.rim, b.rim, reason: 'rim $at');
    expect(a.fallen, b.fallen, reason: 'fallen $at');
    expect(a.sparkle, b.sparkle, reason: 'sparkle $at');
    expect(a.flying, b.flying, reason: 'flying $at');
    expect(a.launched, b.launched, reason: 'launched $at');
    expect(a.hasCleared, b.hasCleared, reason: 'hasCleared $at');
    expect(a.ring, b.ring, reason: 'ring $at');
    expect(a.sideways, b.sideways, reason: 'sideways $at');
    expect(a.hold, b.hold, reason: 'hold $at');
  }

  for (final type in WaveType.values) {
    group(type.name, () {
      test('purity: the same inputs give the same frame', () {
        final random = math.Random(0x5EED + type.index);
        for (var n = 0; n < scenesPerType; n++) {
          final s = scene(random, type);
          // An equal spec resolved again must agree too: nothing is carried
          // from one frame to the next, or keyed on the spec's identity.
          final twin = WaveSpec.resolve(s.spec.style);
          for (var i = 0; i < samplesPerScene; i++) {
            final p = random.nextDouble();
            final first = frameOf(s, p);
            final at = '${describe(s)} p=$p';
            expectSameFrame(first, frameOf(s, p), at);
            expectSameFrame(first, frameOf(s, p, spec: twin), at);
          }
          // Progress outside 0–1 is the wave at rest at either end.
          expectSameFrame(frameOf(s, -0.5), frameOf(s, 0), describe(s));
          expectSameFrame(frameOf(s, 1.5), frameOf(s, 1), describe(s));
        }
      });

      test('ranges: every field is finite and in bounds', () {
        final random = math.Random(0xA11CE + type.index);
        for (var n = 0; n < scenesPerType; n++) {
          final s = scene(random, type);
          final spec = s.spec;
          final progresses = [
            0.0,
            spec.anticipation / spec.duration,
            1.0,
            for (var i = 0; i < samplesPerScene; i++) random.nextDouble(),
          ];
          for (final p in progresses) {
            final f = frameOf(s, p);
            final at = '${describe(s)} p=$p';
            for (final (name, value) in [
              ('origin.dx', f.origin.dx),
              ('origin.dy', f.origin.dy),
              ('tilt', f.tilt),
              ('spine', f.spine),
              ('radius', f.radius),
              ('moved', f.moved),
              ('squash', f.squash),
              ('time', f.time),
              ('energy', f.energy),
              ('swell', f.swell),
              ('gravity', f.gravity),
              ('glow', f.glow),
              ('clearRadius', f.clearRadius),
              ('hairClearRadius', f.hairClearRadius),
              ('rim', f.rim),
              ('fallen', f.fallen),
              ('sparkle', f.sparkle),
              ('flying', f.flying),
              ('hold', f.hold),
            ]) {
              expect(value.isFinite, isTrue, reason: '$name $at');
            }

            expect(f.energy, inInclusiveRange(0, 1), reason: 'energy $at');
            expect(f.glow, inInclusiveRange(0, 1), reason: 'glow $at');
            expect(f.rim, inInclusiveRange(0, 1), reason: 'rim $at');
            expect(
              f.rim,
              lessThanOrEqualTo(spec.rimStrength),
              reason: 'rim $at',
            );
            expect(f.sparkle, inInclusiveRange(0, 1), reason: 'sparkle $at');
            expect(f.fallen, inInclusiveRange(0, 1), reason: 'fallen $at');
            expect(
              f.gravity,
              inInclusiveRange(0, spec.pull),
              reason: 'gravity $at',
            );
            expect(f.moved, inInclusiveRange(0, 1), reason: 'moved $at');
            expect(f.squash, inInclusiveRange(1, 1.4), reason: 'squash $at');
            expect(
              f.swell,
              inInclusiveRange(0, spec.swell),
              reason: 'swell $at',
            );
            expect(f.spine, greaterThanOrEqualTo(0), reason: 'spine $at');
            expect(f.radius, greaterThan(0), reason: 'radius $at');
            expect(
              f.time,
              inInclusiveRange(0, spec.duration),
              reason: 'time $at',
            );
            expect(
              f.flying,
              inInclusiveRange(0, spec.duration - spec.anticipation),
              reason: 'flying $at',
            );
            expect(f.launched, f.flying > 0, reason: 'launched $at');
            expect(f.size, s.size, reason: 'size $at');
            expect(f.ring, type == WaveType.center, reason: 'ring $at');
            expect(
              f.sideways,
              type == WaveType.horizontal,
              reason: 'sideways $at',
            );
            if (f.ring) {
              expect(f.spine, 0, reason: 'a ring has no spine $at');
              expect(f.squash, 1, reason: 'a ring never bows $at');
              expect(f.origin, s.source.center, reason: 'never leans $at');
              expect(
                f.hold,
                math.min(s.source.width, s.source.height) / 2,
                reason: 'hold $at',
              );
            } else {
              expect(f.hold, 0, reason: 'an arc holds nothing $at');
            }
          }
        }
      });

      test('after the launch the front only moves out, and stays cleared', () {
        final random = math.Random(0xC1EA2 + type.index);
        for (var n = 0; n < scenesPerType; n++) {
          final s = scene(random, type);
          final launch = s.spec.anticipation / s.spec.duration;
          final progresses = [
            launch,
            1.0,
            for (var i = 0; i < samplesPerScene; i++)
              launch + (1 - launch) * random.nextDouble(),
          ]..sort();
          WaveFrame? last;
          for (final p in progresses) {
            final f = frameOf(s, p);
            final at = '${describe(s)} p=$p';
            final before = last;
            if (before != null) {
              expect(
                f.radius,
                greaterThanOrEqualTo(before.radius),
                reason: 'radius $at',
              );
              if (before.hasCleared) {
                expect(f.hasCleared, isTrue, reason: 'hasCleared $at');
              }
              // The wipes of the edges never come back either.
              expect(
                f.clearRadius,
                greaterThanOrEqualTo(before.clearRadius),
                reason: 'clearRadius $at',
              );
              expect(
                f.hairClearRadius,
                greaterThanOrEqualTo(before.hairClearRadius),
                reason: 'hairClearRadius $at',
              );
            }
            last = f;
          }
        }
      });
    });
  }
}
