import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/distortion_wave/models/wave_dots.dart';
import 'package:prismatic/src/distortion_wave/models/wave_motion.dart';
import 'package:prismatic/src/distortion_wave/models/wave_spec.dart';
import 'package:prismatic/src/distortion_wave/models/wave_style.dart';
import 'package:prismatic/src/distortion_wave/models/wave_type.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_frame.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_particles.dart';

/// The particle cases of DistortionWavesKit's `WaveFrontTests`, ported: the
/// dots hop toward the source in the anticipation, are thrown out with the
/// front, spread behind it and burn out one by one; round a ring they come
/// in and go out on every side, and the center wave gathers none.
void main() {
  double hypot(double x, double y) => math.sqrt(x * x + y * y);

  group('vertical wave', () {
    const screen = Size(402, 874);
    const button = Rect.fromLTWH(20, 782, 362, 58);
    final spec = WaveSpec.resolve(const WaveStyle(type: WaveType.vertical));
    final particles = [
      for (var i = 0; i < spec.dotCount; i++) WaveParticle(i, spec),
    ];

    WaveFrame front(double progress) => WaveFrame.at(
      progress: progress,
      source: button,
      size: screen,
      spec: spec,
    );

    WaveFrame at(double seconds) => front(seconds / spec.duration);

    double distanceToButton(Offset p) {
      final dx = math.max(
        math.max(button.left - p.dx, 0.0),
        p.dx - button.right,
      );
      final dy = math.max(
        math.max(button.top - p.dy, 0.0),
        p.dy - button.bottom,
      );
      return hypot(dx, dy);
    }

    test('all builds every dot once and memoizes per spec', () {
      final all = WaveParticle.all(spec);
      expect(all, hasLength(spec.dotCount));
      expect(WaveParticle.all(spec), same(all));
      // An equal spec, resolved again, hits the same memo.
      expect(
        WaveParticle.all(
          WaveSpec.resolve(const WaveStyle(type: WaveType.vertical)),
        ),
        same(all),
      );
      for (var i = 0; i < all.length; i++) {
        expect(all[i].column, particles[i].column, reason: 'dot $i');
        expect(all[i].pace, particles[i].pace, reason: 'dot $i');
      }
      expect(() => all.add(particles.first), throwsUnsupportedError);
    });

    test('all keeps the dots of a few specs at once', () {
      final specs = [
        for (final count in [10, 20, 30, 40])
          WaveSpec.resolve(WaveStyle(dots: WaveDots(count: count))),
      ];
      final first = [for (final s in specs) WaveParticle.all(s)];
      // Waves of different styles on screen at once, frame after frame.
      for (var i = 0; i < specs.length; i++) {
        expect(WaveParticle.all(specs[i]), same(first[i]));
      }
    });

    test('particles hop toward the button', () {
      // In the anticipation the dots make short hops toward the button:
      // never nearer than the gap, each closing in by no more than the hop.
      for (final (index, particle) in particles.indexed) {
        ({double count, double distance})? hopStart;
        for (var i = 0; i < 200; i++) {
          final f = at(spec.anticipation * i / 200);
          final distance = distanceToButton(particle.pointOn(f, button));
          final where = 'dot $index step $i';
          expect(
            distance,
            greaterThanOrEqualTo(spec.dotGap - 0.5),
            reason: where,
          );
          expect(
            distance,
            lessThanOrEqualTo(spec.dotReach + 30),
            reason: where,
          );
          final count = particle.hopAt(f.time).count;
          final start = hopStart;
          if (start != null && start.count == count) {
            expect(
              distance,
              lessThanOrEqualTo(start.distance + 0.001),
              reason: where,
            );
            expect(
              start.distance - distance,
              lessThanOrEqualTo(spec.dotFlight + 0.5),
              reason: where,
            );
          } else {
            hopStart = (count: count, distance: distance);
          }
        }
      }
    });

    test('particles differ in brightness', () {
      // Spread over their range: more than ten different steps of 0.05 of
      // brightness are taken, and none is dimmer than the floor.
      final levels = {for (final p in particles) (p.brightness * 20).round()};
      expect(levels.length, greaterThan(10));
      expect(
        particles.map((p) => p.brightness).reduce(math.min),
        greaterThanOrEqualTo(0.3),
      );
    });

    test('particles ride out with the front', () {
      // Once the wave has left, every dot only rises, and the quickest stay
      // with the front while it crosses the screen.
      for (final (index, particle) in particles.indexed) {
        var lastY = double.infinity;
        for (var i = 1; i <= 200; i++) {
          final f = at(spec.anticipation + spec.travel * i / 200);
          final y = particle.pointOn(f, button).dy;
          expect(
            y,
            lessThanOrEqualTo(lastY + 0.001),
            reason: 'dot $index step $i',
          );
          lastY = y;
        }
      }
      final quickest = particles
          .where((p) => p.pace > 0.95)
          .reduce((a, b) => a.column.abs() <= b.column.abs() ? a : b);
      for (final seconds in const [0.05, 0.1, 0.2]) {
        final f = at(spec.anticipation + seconds);
        final height = f.origin.dy - quickest.pointOn(f, button).dy;
        expect(height, closeTo(f.radius, spec.lead), reason: '${seconds}s');
      }
    });

    test('particles spread out behind the front', () {
      // They fly as a scatter, not as one sheet: by the time the wave has
      // settled they are spread over much of the screen's height.
      final f = at(spec.anticipation + 0.5);
      final heights = [for (final p in particles) p.pointOn(f, button).dy];
      expect(
        heights.reduce(math.max) - heights.reduce(math.min),
        greaterThan(400),
      );
    });

    test('particles burn out one by one', () {
      // Each burns out in its own time, and all before the colour on the
      // edges has been wiped away.
      expect(particles.every((p) => p.opacityOn(front(0)) == 0), isTrue);
      final launch = at(spec.anticipation + 0.05);
      expect(particles.every((p) => p.opacityOn(launch) > 0), isTrue);
      final halfway = at(spec.anticipation + 0.5 * spec.dotLife);
      final midway = [for (final p in particles) p.opacityOn(halfway)];
      expect(midway.any((o) => o == 0), isTrue);
      expect(midway.any((o) => o > 0), isTrue);
      final burnt = at(spec.anticipation + spec.dotLife);
      expect(particles.every((p) => p.opacityOn(burnt) == 0), isTrue);
      expect(spec.dotLife, lessThanOrEqualTo(spec.linger + spec.rimFade));
    });
  });

  group('center wave', () {
    const sheet = Size(386, 509);
    const avatar = Rect.fromLTWH(161, 54, 64, 64);
    final center = WaveSpec.resolve(const WaveStyle(type: WaveType.center));

    WaveFrame ring(double seconds) => WaveFrame.at(
      progress: seconds / center.duration,
      source: avatar,
      size: sheet,
      spec: center,
    );

    test('success gathers nothing before the launch', () {
      // The success ring only pulls before the launch: no colour, no dots.
      // Its colour comes in smoothly once the ring has left the avatar.
      for (var i = 0; i * 0.01 <= center.anticipation; i++) {
        final f = ring(i * 0.01);
        final at = 't=${i * 0.01}';
        expect(f.glow, closeTo(0, 0.0001), reason: at);
        for (var index = 0; index < center.dotCount; index++) {
          expect(
            WaveParticle(index, center).opacityOn(f),
            closeTo(0, 0.0001),
            reason: 'dot $index $at',
          );
        }
      }
      expect(ring(center.anticipation + 0.01).glow, closeTo(0, 0.05));
      expect(ring(center.anticipation + 0.3).glow, greaterThan(0.5));
      expect(ring(center.anticipation).gravity, greaterThan(0));
    });

    test('ring dots come in and go out all round', () {
      // Dots hop in toward the avatar from every side, and are thrown out
      // every way.
      final gathering = WaveSpec.resolve(
        const WaveStyle(
          type: WaveType.center,
          motion: WaveMotion(gatherDots: 1),
        ),
      );
      final centre = avatar.center;
      double fromCentre(Offset p) => hypot(p.dx - centre.dx, p.dy - centre.dy);
      final sides = <int>{};
      for (var index = 0; index < gathering.dotCount; index++) {
        final dot = WaveParticle(index, gathering);
        // Within one hop, it only ever closes in.
        final a = ring(0.1);
        final b = ring(0.1 + dot.hop * 0.2);
        if (dot.hopAt(a.time).count == dot.hopAt(b.time).count) {
          expect(
            fromCentre(dot.pointOn(b, avatar)),
            lessThan(fromCentre(dot.pointOn(a, avatar)) + 0.001),
            reason: 'dot $index',
          );
        }
        final out = dot.pointOn(ring(center.anticipation + 0.4), avatar);
        expect(fromCentre(out), greaterThan(32), reason: 'dot $index');
        final angle = math.atan2(out.dy - centre.dy, out.dx - centre.dx);
        sides.add(((angle + math.pi) / (math.pi / 2)).floor() % 4);
      }
      expect(sides, hasLength(4));
    });
  });

  group('horizontal wave', () {
    const screen = Size(402, 874);
    const edge = Rect.fromLTWH(0, 300, 24, 274);
    final horizontal = WaveSpec.resolve(
      const WaveStyle(type: WaveType.horizontal),
    );

    WaveFrame sideways(double seconds) => WaveFrame.at(
      progress: seconds / horizontal.duration,
      source: edge,
      size: screen,
      spec: horizontal,
    );

    test('horizontal dots come from the right', () {
      // In the anticipation the dots hop in from the right of the source,
      // toward its face; after the launch they fly off to the right with
      // the front.
      final before = sideways(horizontal.anticipation * 0.6);
      final after = sideways(horizontal.anticipation + 0.5);
      for (var index = 0; index < horizontal.dotCount; index++) {
        final dot = WaveParticle(index, horizontal);
        expect(
          dot.pointOn(before, edge).dx,
          greaterThan(edge.right),
          reason: 'dot $index before',
        );
        expect(
          dot.pointOn(after, edge).dx,
          greaterThan(edge.right),
          reason: 'dot $index after',
        );
      }
    });
  });
}
