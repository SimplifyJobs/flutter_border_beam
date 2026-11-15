import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../animation/beam_clock.dart';
import '../animation/beam_phases.dart';
import '../models/beam_config.dart';
import 'beam_program.dart';
import 'beam_renderer.dart';

/// The beam's [CustomPainter]: samples the phases for this frame and hands
/// them to the [BeamRenderer]. Repaints are driven directly by the
/// [BeamClock] — no widget rebuilds per frame.
class BeamPainter extends CustomPainter with Diagnosticable {
  /// Creates a painter bound to [clock].
  BeamPainter({
    required this.renderer,
    required this.clock,
    required this.config,
    required this.resolver,
    required this.staticMode,
    required this.devicePixelRatio,
    this.progress,
    this.strength,
    this.frozenAt,
  }) : super(
         repaint: Listenable.merge([
           clock,
           BeamProgram.ready,
           ?progress,
           ?strength,
         ]),
       );

  /// Draws the frames; owned by the widget's state.
  final BeamRenderer renderer;

  /// The time source; also the repaint trigger.
  final BeamClock clock;

  /// Resolved beam configuration.
  final BeamConfig config;

  /// Phase computer.
  final BeamPhaseResolver resolver;

  /// Reduced-motion mode: paint one static frame, ignore the clock.
  final bool staticMode;

  /// Device pixels per logical pixel, for anti-aliasing.
  final double devicePixelRatio;

  /// The externally driven sweep position (0–1), or null when nothing
  /// drives it.
  final ValueListenable<double?>? progress;

  /// A per-frame multiplier on the beam's opacity, or null for none.
  final ValueListenable<double>? strength;

  /// The timeline position every frame is sampled at, or null to follow the
  /// clock (`BeamPlayback.debugFrozenAt`).
  final Duration? frozenAt;

  @override
  void paint(Canvas canvas, Size size) {
    final driven = progress?.value;
    final BeamFramePhases phases;
    final frozen = frozenAt;
    if (frozen != null) {
      phases = resolver.sample(
        frozen.inMicroseconds / Duration.microsecondsPerSecond,
        strength?.value ?? 1,
        progress: driven,
      );
    } else if (staticMode) {
      phases = resolver.staticFrame(progress: driven);
    } else {
      if (!clock.isVisible) return;
      final amplitude = clock.boost * (strength?.value ?? 1);
      phases = resolver.sample(
        clock.elapsedSeconds,
        clock.fadeOpacity * amplitude,
        progress: driven,
      );
    }
    renderer.paint(
      canvas,
      Offset.zero & size,
      config,
      phases,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  bool shouldRepaint(BeamPainter oldDelegate) =>
      oldDelegate.config != config ||
      oldDelegate.renderer != renderer ||
      oldDelegate.staticMode != staticMode ||
      oldDelegate.clock != clock ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.progress != progress ||
      oldDelegate.strength != strength ||
      oldDelegate.frozenAt != frozenAt;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<BeamConfig>('config', config))
      ..add(
        FlagProperty('staticMode', value: staticMode, ifTrue: 'static frame'),
      )
      ..add(DoubleProperty('elapsedSeconds', clock.elapsedSeconds))
      ..add(DoubleProperty('fadeOpacity', clock.fadeOpacity))
      ..add(DoubleProperty('boost', clock.boost, defaultValue: 1.0))
      ..add(DoubleProperty('progress', progress?.value, defaultValue: null))
      ..add(DoubleProperty('strength', strength?.value, defaultValue: null))
      ..add(
        DiagnosticsProperty<Duration>('frozenAt', frozenAt, defaultValue: null),
      );
  }
}
