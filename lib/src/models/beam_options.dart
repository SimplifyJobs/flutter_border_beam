import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The shape of a beam's hue track: a swing back and forth, or one
/// continuous revolution.
enum BeamHueMode {
  /// The hue swings from `-hueRange` to `+hueRange` and back over one hue
  /// period — the traveling variants' default.
  pingPong,

  /// The hue advances through a full 360° revolution over one hue period,
  /// never reversing — the pulse variants' default.
  continuous,
}

/// Which set of glow geometry the pulse-outside variant paints.
///
/// The two differ only in how far the outward glow is grown past the child
/// and how heavily it is blurred; every other part of the variant is shared.
enum BeamPulseOutsideTuning {
  /// The demo-hero recipe the source's demo page layers over its own
  /// defaults: insets and blurs scaled by the element's size, melting the
  /// separate blobs into one continuous edge-hugging glow.
  ///
  /// The default, because it is the pulse-outside look the library is known
  /// for.
  demo,

  /// The React library's own defaults: fixed insets and a per-brightness
  /// blur, with no size-derived unit.
  ///
  /// Reach for it through `BeamStyle.pulseOutsideStock`, which also rolls
  /// back the demo recipe's prominence and opacity multipliers.
  stock,
}

/// Which way a beam travels around its contour.
enum BeamDirection {
  /// Clockwise for the rotate and small variants, left-to-right for the line
  /// variant.
  forward,

  /// The mirror of [forward]: counter-clockwise, or right-to-left.
  reverse,

  /// Alternates each cycle, running [forward] on one sweep and [reverse] on
  /// the next.
  bounce,
}

/// Which edge of the box the line variant's beam rides.
enum BeamEdge {
  /// The top edge, travelling horizontally.
  top,

  /// The right edge, travelling vertically.
  right,

  /// The bottom edge, travelling horizontally — the line variant's default.
  bottom,

  /// The left edge, travelling vertically.
  left,
}

/// What a beam does when the platform asks for reduced motion
/// (`MediaQuery.disableAnimationsOf`).
enum BeamReducedMotion {
  /// Ignores the request and keeps animating.
  animate,

  /// Paints a single static frame of the effect instead of animating — the
  /// default.
  staticFrame,

  /// Paints nothing at all, leaving the child bare.
  hide,

  /// Keeps animating at a quarter of the configured speed.
  slow,
}

/// How many cycles a beam runs before it stops.
///
/// A beam that reaches its last cycle fades out the way an inactive one
/// does, rather than cutting off mid-sweep.
///
/// ```dart
/// BorderBeam.rotate(
///   playback: const BeamPlayback(repeat: BeamRepeat.count(3)),
///   child: card,
/// )
/// ```
@immutable
class BeamRepeat {
  /// Loops forever — the default.
  const BeamRepeat.forever() : cycles = null;

  /// Runs exactly one cycle, then stops.
  const BeamRepeat.once() : cycles = 1;

  /// Runs [n] cycles, then stops. [n] must be at least 1.
  const BeamRepeat.count(int n)
    : assert(n >= 1, 'BeamRepeat.count needs at least one cycle'),
      cycles = n;

  /// How many cycles to run, or null to loop forever.
  final int? cycles;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BeamRepeat && other.cycles == cycles;

  @override
  int get hashCode => cycles.hashCode;

  @override
  String toString() =>
      cycles == null ? 'BeamRepeat.forever()' : 'BeamRepeat.count($cycles)';
}

/// An arbitrary outer contour for the beam to travel, replacing the rounded
/// rectangle built from `BeamShape.radius`.
///
/// The beam's ring, its masks, and the path the traveling head follows are
/// all built from [build], so any closed path works — a notched card, a
/// speech bubble, a hand-drawn blob.
///
/// A contour is a value: `BeamConfig` keys its cache on it, so **every
/// implementer must override `==` and `hashCode`**. A contour that compares
/// by identity re-resolves the config on every rebuild. [BeamPathContour]
/// shows the pattern — it compares on an explicit key, because two closures
/// that draw the same path are never equal to each other.
@immutable
abstract class BeamContour {
  /// Allows subclasses to be const.
  const BeamContour();

  /// Builds the contour path for a beam occupying [rect].
  ///
  /// Called with the beam's own bounds, already grown or shrunk by
  /// `BeamShape.ringOffset`. Return a closed path in the same coordinate
  /// space.
  Path build(Rect rect);
}

/// A [BeamContour] that delegates to a builder function, comparing on an
/// explicit [key].
///
/// ```dart
/// BeamShape(
///   contour: BeamPathContour(
///     (rect) => Path()..addOval(rect),
///     key: 'oval',
///   ),
/// )
/// ```
class BeamPathContour extends BeamContour {
  /// Creates a contour that calls [builder], and compares equal to another
  /// [BeamPathContour] carrying an equal [key].
  const BeamPathContour(this.builder, {required this.key});

  /// Draws the contour for the beam's bounds.
  final Path Function(Rect rect) builder;

  /// The value this contour compares and hashes on.
  ///
  /// Two contours built from the same drawing take the same key — Dart
  /// closures compare by identity, so an inline builder would otherwise make
  /// every rebuild a new value. Any value-equal object works: a string, an
  /// enum, or a `Record` of the parameters the builder closes over.
  final Object key;

  @override
  Path build(Rect rect) => builder(rect);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamPathContour &&
          other.runtimeType == runtimeType &&
          other.key == key;

  @override
  int get hashCode => Object.hash(runtimeType, key);

  @override
  String toString() => 'BeamPathContour($key)';
}
