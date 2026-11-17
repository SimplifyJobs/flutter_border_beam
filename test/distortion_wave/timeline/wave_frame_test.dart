import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/distortion_wave/models/wave_motion.dart';
import 'package:prismatic/src/distortion_wave/models/wave_spec.dart';
import 'package:prismatic/src/distortion_wave/models/wave_style.dart';
import 'package:prismatic/src/distortion_wave/models/wave_timing.dart';
import 'package:prismatic/src/distortion_wave/models/wave_type.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_frame.dart';

/// A port of DistortionWavesKit's `WaveFrontTests` — the front, its timing,
/// gravity, glow, the edges and their hairline, clearing, the ring, the
/// horizontal wave and the lean with a touch. The Swift tests are the spec:
/// each keeps its name as the description and its numbers as the bounds.
///
/// The particle cases live in `wave_particles_test.dart`, the rim's lumps in
/// `wave_rim_test.dart`.
void main() {
  // Flutter's `Cubic` stops bisecting once its x is within 1e-3 of the
  // input, where the reference's easing bisects 24 times; so a value read
  // off the curve is good to about the curve's slope × 1e-3, not the
  // reference's 1e-4.
  const cubicTolerance = 1e-3;

  /// A [Duration] of [seconds], for the reference's mutated styles.
  Duration s(double seconds) => Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );

  double hypot(double x, double y) => math.sqrt(x * x + y * y);

  group('vertical wave', () {
    const screen = Size(402, 874);
    const button = Rect.fromLTWH(20, 782, 362, 58);
    final spec = WaveSpec.resolve(const WaveStyle(type: WaveType.vertical));

    WaveFrame front(double progress, {WaveSpec? using, Offset? focus}) =>
        WaveFrame.at(
          progress: progress,
          source: button,
          size: screen,
          spec: using ?? spec,
          focus: focus,
        );

    WaveFrame at(double seconds, {WaveSpec? using, Offset? focus}) =>
        front(seconds / (using ?? spec).duration, using: using, focus: focus);

    /// The farthest point of the screen in the field's own metric.
    double farthest(WaveFrame f) =>
        hypot(button.center.dx * f.squash, button.center.dy);

    test('launches clear of the source outline', () {
      // The front starts the spec's gap out from the button's outline: an
      // offset of the pill, with the button's own spine.
      final f = at(spec.anticipation);
      expect(f.radius, closeTo(29 + spec.launchGap, 0.01));
      expect(f.spine, closeTo(181 - 29, 0.01));
      expect(f.squash, closeTo(1, 0.001));
      expect(f.energy, closeTo(0, 0.001));
    });

    test('gravity pulls only around the launch', () {
      // A quick pull that peaks on the launch and lets go right after.
      expect(front(0).gravity, closeTo(0, 0.001));
      expect(at(spec.anticipation).gravity, closeTo(spec.pull, 0.01));
      expect(at(spec.anticipation + 0.25).gravity, closeTo(0, 0.001));
    });

    test('ring falls in before the launch', () {
      // Before the launch the ring of colour falls in onto where the front
      // starts.
      var last = double.infinity;
      for (var i = 0; i <= 40; i++) {
        final f = at(spec.anticipation * i / 40);
        expect(f.radius, lessThanOrEqualTo(last), reason: 'step $i');
        last = f.radius;
      }
      expect(front(0).radius, closeTo(29 + spec.launchGap + spec.inhale, 0.01));
    });

    test('front only ever moves outward after the launch', () {
      // As the pill opens into an arc the front must never retreat, or the
      // wave would be seen to pull back in from the screen's edges.
      var lastTop = double.negativeInfinity;
      var lastSide = double.negativeInfinity;
      for (var i = 0; i <= 400; i++) {
        final f = at(
          spec.anticipation + (spec.duration - spec.anticipation) * i / 400,
        );
        final top = f.radius;
        final side = (f.spine + f.radius) / f.squash;
        expect(top, greaterThanOrEqualTo(lastTop), reason: 'step $i');
        expect(side, greaterThanOrEqualTo(lastSide - 0.001), reason: 'step $i');
        lastTop = top;
        lastSide = side;
      }
    });

    test('leans with the touch', () {
      // Touched near its right end, the wave still leaves the button's own
      // outline, then opens from under the finger and leans right, so the
      // right side leads.
      final finger = Offset(button.right - 30, button.center.dy);
      final launch = at(spec.anticipation, focus: finger);
      expect(launch.origin.dx, closeTo(button.center.dx, 0.001));
      expect(launch.tilt, closeTo(0, 0.0001));
      final open = at(spec.anticipation + 0.3 * spec.travel, focus: finger);
      expect(open.origin.dx, greaterThan(button.center.dx + 40));
      expect(open.tilt, greaterThan(0.1));

      // The front is further up the screen on the touched side.
      double frontHeight(double x, WaveFrame f) {
        var y = f.origin.dy;
        while (y > 0) {
          final dx = x - f.origin.dx;
          final dy = y - f.origin.dy;
          final qx = math.cos(f.tilt) * dx + math.sin(f.tilt) * dy;
          final qy = -math.sin(f.tilt) * dx + math.cos(f.tilt) * dy;
          if (hypot(math.max((qx * f.squash).abs() - f.spine, 0), qy) >=
              f.radius) {
            break;
          }
          y -= 1;
        }
        return f.origin.dy - y;
      }

      final crossing = at(
        spec.anticipation + 0.08 * spec.travel,
        focus: finger,
      );
      expect(frontHeight(40, crossing), lessThan(700));
      expect(
        frontHeight(360, crossing),
        greaterThan(frontHeight(40, crossing) + 30),
      );

      final even = WaveSpec.resolve(
        const WaveStyle(motion: WaveMotion(orientation: 0)),
      );
      final level = front(
        (spec.anticipation + 0.3 * spec.travel) / spec.duration,
        using: even,
        focus: finger,
      );
      expect(level.origin.dx, closeTo(button.center.dx, 0.001));
      expect(level.tilt, closeTo(0, 0.0001));
    });

    test('edges wipe on ease-in-out', () {
      // Slow to start, half way at half time, slow to settle, and gone by
      // the end. With a wipe that starts after the tap; the defaults may
      // start it a moment before.
      final wiped = WaveSpec.resolve(
        WaveStyle(timing: WaveTiming(linger: s(0.3))),
      );
      double clear(double seconds) => at(seconds, using: wiped).clearRadius;
      final begin = wiped.anticipation + wiped.linger;
      final start = clear(begin);
      final end = clear(begin + wiped.rimFade);
      double share(double part) =>
          (clear(begin + part * wiped.rimFade) - start) / (end - start);
      expect(share(0.5), closeTo(0.5, 0.001));
      expect(share(0.1), lessThan(0.05));
      expect(share(0.9), greaterThan(0.95));
      expect(begin + wiped.rimFade, lessThanOrEqualTo(wiped.duration + 0.001));
      expect(
        spec.anticipation + spec.linger + spec.rimFade,
        lessThanOrEqualTo(spec.duration + 0.001),
      );
    });

    test('easing matches CSS', () {
      // The curve's parameter at 1/2 gives x = 0.3425, y = 0.875 by hand.
      const easing = Cubic(0.22, 1, 0.36, 1);
      expect(easing.transform(0), 0);
      expect(easing.transform(1), 1);
      expect(easing.transform(0.3425), closeTo(0.875, cubicTolerance));
      // The spec's default travel easing is that curve.
      expect(spec.easing.transform(0.3425), closeTo(0.875, cubicTolerance));
    });

    test('front moves on the easing', () {
      // With edges held long enough that the wave runs its whole travel;
      // with the defaults it ends once the front has settled, short of the
      // curve's end.
      final long = WaveSpec.resolve(
        WaveStyle(
          timing: WaveTiming(linger: s(2), rimFade: s(2)),
        ),
      );
      double radius(double seconds) => at(seconds, using: long).radius;
      final start = radius(long.anticipation);
      final end = radius(long.anticipation + long.travel);
      final mid = radius(long.anticipation + 0.3425 * long.travel);
      expect((mid - start) / (end - start), closeTo(0.875, cubicTolerance));
    });

    test('swell, blur and colour die as the front settles', () {
      // The front has crossed the screen long before the easing lets it
      // stop, and what it carries must not hang there, parked, while it
      // slows down.
      final f = at(spec.anticipation + 0.55 * spec.travel);
      expect(f.hasCleared, isTrue);
      expect(f.energy, closeTo(0, 0.001));
      expect(f.glow, closeTo(0, 0.001));
    });

    test('colour stays on the edges after the front has left', () {
      // With a hold longer than the front takes to settle; the defaults
      // start wiping the edges sooner.
      final held = WaveSpec.resolve(
        WaveStyle(
          timing: WaveTiming(linger: s(0.9), rimFade: s(2.05)),
        ),
      );
      final f = at(held.anticipation + 0.6 * held.travel, using: held);
      expect(f.glow, closeTo(0, 0.001));
      expect(f.energy, closeTo(0, 0.001));
      expect(f.rim, closeTo(held.rimStrength, 0.001));
      expect(f.clearRadius, lessThan(farthest(f)));
    });

    test('with any easing, the front has crossed the view by the end', () {
      // A long travel, so the front, not the colour's fade, sets how long the
      // reveal runs. A slower easing gets the time its front needs; the tuned
      // one keeps exactly its own share of the travel, and none gets less.
      // An overshooting easing counts from where it stays past the tuned
      // one's reach.
      WaveSpec slow([Curve? easing]) => WaveSpec.resolve(
        WaveStyle(
          type: WaveType.vertical,
          timing: WaveTiming(
            easing: easing,
            travel: const Duration(seconds: 6),
          ),
        ),
      );
      final tuned = slow();
      expect(
        tuned.duration,
        closeTo(tuned.anticipation + tuned.travel * 0.6, 1e-9),
      );
      for (final easing in [
        Curves.linear,
        Curves.easeInOut,
        Curves.easeIn,
        Curves.easeOutBack,
        Curves.elasticOut,
      ]) {
        final eased = slow(easing);
        final f = front(1, using: eased);
        expect(f.hasCleared, isTrue, reason: '$easing');
        expect(
          eased.duration,
          greaterThanOrEqualTo(tuned.duration),
          reason: '$easing',
        );
      }
      for (final slower in [Curves.linear, Curves.easeInOut, Curves.easeIn]) {
        expect(
          slow(slower).duration,
          greaterThan(tuned.duration),
          reason: '$slower',
        );
      }
    });

    test('everything has left the screen by the end', () {
      // So hiding the outgoing side and switching the shaders off cannot be
      // seen.
      final f = front(1);
      expect(f.hasCleared, isTrue);
      expect(
        f.clearRadius - spec.rimSoftness - spec.swell,
        greaterThan(farthest(f)),
      );
      expect(
        f.hairClearRadius - spec.rimSoftness - spec.swell + 0.001,
        greaterThanOrEqualTo(farthest(f)),
      );
      expect(f.energy, closeTo(0, 0.001));
      expect(f.glow, closeTo(0, 0.001));
      expect(f.rim, closeTo(0, 0.001));
      expect(f.gravity, closeTo(0, 0.001));
    });

    test('hairline outlasts the colour', () {
      // Wiped later and slower than the colour under it: never ahead of it,
      // and still on the edges once the colour has gone. The defaults may
      // bring the two close; this checks the mechanism with a line that
      // clearly holds on.
      final lasting = WaveSpec.resolve(
        WaveStyle(
          timing: WaveTiming(
            rimFade: s(2.51),
            hairlineLinger: s(0.25),
            hairlineFade: s(3),
          ),
        ),
      );
      for (var i = 0; i <= 200; i++) {
        final f = front(i / 200, using: lasting);
        expect(
          f.hairClearRadius,
          lessThanOrEqualTo(f.clearRadius + 0.001),
          reason: 'step $i',
        );
      }
      final f = at(
        lasting.anticipation + lasting.linger + lasting.rimFade,
        using: lasting,
      );
      expect(f.clearRadius - f.hairClearRadius, greaterThan(100));
      // Some of it is still kept on the farthest corner.
      expect(f.hairClearRadius - lasting.rimSoftness, lessThan(farthest(f)));
      expect(
        lasting.duration,
        greaterThanOrEqualTo(
          lasting.anticipation +
              lasting.linger +
              lasting.hairlineLinger +
              lasting.hairlineFade,
        ),
      );
    });

    test('clears only once the front has crossed the screen', () {
      // The outgoing side stops being drawn partway through, but never
      // while the front is still on screen.
      expect(at(spec.anticipation + 0.2).hasCleared, isFalse);
      expect(at(spec.anticipation + spec.travel).hasCleared, isTrue);
      for (var i = 0; i <= 400; i++) {
        final f = front(i / 400);
        if (f.hasCleared) {
          expect(
            f.radius,
            greaterThan(farthest(f) + waveCoverZone),
            reason: 'step $i',
          );
        }
      }
    });
  });

  group('center wave', () {
    const sheet = Size(386, 509);
    const avatar = Rect.fromLTWH(161, 54, 64, 64);
    final center = WaveSpec.resolve(const WaveStyle(type: WaveType.center));

    WaveFrame ring(double seconds, {Offset? focus}) => WaveFrame.at(
      progress: seconds / center.duration,
      source: avatar,
      size: sheet,
      spec: center,
      focus: focus,
    );

    test('ring spreads evenly from the centre', () {
      // A circle round the avatar's centre all the way: no spine, no
      // squash, and no lean, wherever it was touched.
      for (var i = 0; i * 0.1 <= center.duration; i++) {
        final t = i * 0.1;
        final f = ring(t, focus: Offset(avatar.right, avatar.center.dy));
        final at = 't=$t';
        expect(f.spine, closeTo(0, 0.001), reason: at);
        expect(f.squash, closeTo(1, 0.001), reason: at);
        expect(f.tilt, closeTo(0, 0.001), reason: at);
        expect(f.origin.dx, closeTo(avatar.center.dx, 0.001), reason: at);
        expect(f.origin.dy, closeTo(avatar.center.dy, 0.001), reason: at);
        expect(f.ring, isTrue, reason: at);
        // The token itself is held out of the wave.
        expect(f.hold, closeTo(32, 0.001), reason: at);
      }
      expect(ring(center.anticipation).radius, closeTo(32, 0.01));
    });

    test('ring crosses the whole sheet', () {
      // It has left every corner of the sheet, and cleared its edges, by
      // the end.
      final end = ring(center.duration);
      final corner = hypot(
        sheet.width - avatar.center.dx,
        sheet.height - avatar.center.dy,
      );
      expect(end.radius, greaterThan(corner + waveCoverZone));
      expect(
        end.clearRadius - center.rimSoftness - center.swell + 0.001,
        greaterThanOrEqualTo(corner),
      );
      expect(ring(center.anticipation + center.travel).hasCleared, isTrue);
    });
  });

  group('horizontal wave', () {
    const screen = Size(402, 874);
    // A tall source at the screen's left edge, as an edge swipe or a side
    // tab.
    const edge = Rect.fromLTWH(0, 300, 24, 274);
    final horizontal = WaveSpec.resolve(
      const WaveStyle(type: WaveType.horizontal),
    );

    WaveFrame sideways(double seconds, {Offset? focus}) => WaveFrame.at(
      progress: seconds / horizontal.duration,
      source: edge,
      size: screen,
      spec: horizontal,
      focus: focus,
    );

    /// How far inside the front [p] is, pt: above 0 the front has passed it.
    double passed(Offset p, WaveFrame f) {
      final dx = p.dx - f.origin.dx;
      final dy = p.dy - f.origin.dy;
      final qx = math.cos(f.tilt) * dx + math.sin(f.tilt) * dy;
      final qy = -math.sin(f.tilt) * dx + math.cos(f.tilt) * dy;
      return f.radius - hypot(math.max((qx * f.squash).abs() - f.spine, 0), qy);
    }

    test('horizontal travels left to right', () {
      // It leaves the source's own outline and crosses the screen to the
      // right, well ahead of how far it reaches up or down.
      final launch = sideways(horizontal.anticipation);
      expect(launch.tilt, closeTo(math.pi / 2, 0.0001));
      expect(launch.spine + launch.radius, closeTo(137, 0.01));
      expect(launch.radius, closeTo(12, 0.01));
      final f = sideways(horizontal.anticipation + 0.1 * horizontal.travel);
      final right = Offset(edge.right + 250, edge.center.dy);
      final up = Offset(edge.center.dx, edge.top - 250);
      expect(passed(right, f), greaterThan(0));
      expect(passed(right, f), greaterThan(passed(up, f) + 60));
      expect(
        sideways(horizontal.anticipation + horizontal.travel).hasCleared,
        isTrue,
      );
    });

    test('horizontal leans with the touch', () {
      // Touched low on the source, it opens from under the finger and
      // leans down.
      final finger = Offset(edge.center.dx, edge.bottom - 20);
      final open = sideways(
        horizontal.anticipation + 0.3 * horizontal.travel,
        focus: finger,
      );
      expect(open.origin.dy, greaterThan(edge.center.dy + 40));
      expect(open.origin.dx, closeTo(edge.center.dx, 0.001));
      expect(open.tilt, greaterThan(math.pi / 2 + 0.1));
    });
  });
}
