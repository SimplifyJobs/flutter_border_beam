import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../border_beam.dart';
import '../models/beam_colors.dart';
import '../models/beam_shape.dart';
import '../models/beam_style.dart';
import '../models/beam_timing.dart';
import '../models/beam_variant.dart';

/// Lights a beam around [child] while a finger is down on it.
///
/// The touch counterpart of `BeamHover`: pointer-down activates the beam,
/// pointer-up releases it. A tap is far shorter than a pulse, so a release is
/// held until [minimumDuration] has passed since the press began — otherwise
/// every tap would be a flicker.
///
/// ```dart
/// BeamPress(
///   borderRadius: 20,
///   onTap: () => submit(),
///   child: card,
/// )
/// ```
///
/// ## Gestures
///
/// The listener is a plain [Listener] with [HitTestBehavior.translucent]: it
/// observes raw pointer events without entering the gesture arena, so it can
/// never win a gesture away from [child]. A button or a `GestureDetector`
/// inside keeps receiving its own taps, and a scrollable above keeps its
/// drags.
///
/// [onTap] is a convenience for the common "the whole thing is tappable"
/// case, fired when the pointer lifts inside the widget's bounds. Because it
/// bypasses the arena it does not wait to see whether another recognizer
/// claims the gesture; a child that has its own tap handling should keep it
/// and leave [onTap] null.
class BeamPress extends StatefulWidget {
  /// Creates a press-driven beam around [child].
  const BeamPress({
    super.key,
    required this.child,
    this.variant = BeamVariant.pulseInside,
    this.colors,
    this.borderRadius,
    this.style,
    this.shape,
    this.timing,
    this.minimumDuration = const Duration(milliseconds: 600),
    this.onTap,
  });

  /// The pressed content. Laid out and hit-tested normally.
  final Widget child;

  /// Which effect the press paints. Defaults to [BeamVariant.pulseInside],
  /// whose breathing glow reads as "held".
  final BeamVariant variant;

  /// Shorthand for `style.colors`; a non-null value here wins over it.
  final BeamColors? colors;

  /// Shorthand for a uniform corner radius in logical px. Match [child]'s own
  /// radius.
  final double? borderRadius;

  /// Colors, theme adaptation, and filter hooks, passed straight through.
  final BeamStyle? style;

  /// Corner radii, ring width, and corner family, passed straight through.
  final BeamShape? shape;

  /// Cycle length, rest, rate, and hue periods, passed straight through.
  final BeamTiming? timing;

  /// How long the beam stays lit from pointer-down, however early the pointer
  /// lifts. A quick tap still gets a full pulse. [Duration.zero] releases on
  /// pointer-up.
  final Duration minimumDuration;

  /// Called when the pointer lifts inside the widget's bounds.
  final VoidCallback? onTap;

  @override
  State<BeamPress> createState() => _BeamPressState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<BeamVariant>('variant', variant))
      ..add(
        DiagnosticsProperty<BeamColors>('colors', colors, defaultValue: null),
      )
      ..add(DoubleProperty('borderRadius', borderRadius, defaultValue: null))
      ..add(DiagnosticsProperty<Duration>('minimumDuration', minimumDuration))
      ..add(FlagProperty('onTap', value: onTap != null, ifTrue: 'tappable'))
      ..add(DiagnosticsProperty<BeamStyle>('style', style, defaultValue: null))
      ..add(DiagnosticsProperty<BeamShape>('shape', shape, defaultValue: null))
      ..add(
        DiagnosticsProperty<BeamTiming>('timing', timing, defaultValue: null),
      );
  }
}

class _BeamPressState extends State<BeamPress> {
  bool _active = false;
  bool _down = false;
  bool _minimumMet = true;
  int? _pointer;
  Timer? _minimumTimer;

  @override
  void dispose() {
    _minimumTimer?.cancel();
    super.dispose();
  }

  void _handleDown(PointerDownEvent event) {
    // A second finger while one is already down changes nothing: the beam is
    // already lit and its minimum runs from the first press.
    if (_pointer != null) return;
    _pointer = event.pointer;
    _down = true;
    _minimumTimer?.cancel();
    _minimumMet = widget.minimumDuration <= Duration.zero;
    if (!_minimumMet) {
      _minimumTimer = Timer(widget.minimumDuration, _handleMinimumElapsed);
    }
    if (!_active) setState(() => _active = true);
  }

  void _handleMinimumElapsed() {
    _minimumTimer = null;
    _minimumMet = true;
    if (!_down) _release();
  }

  void _handleUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _down = false;
    if (_minimumMet) _release();
    if (widget.onTap != null && _containsLocal(event.localPosition)) {
      widget.onTap!();
    }
  }

  // A cancel means another recognizer took the gesture over (a scroll, most
  // often). Nothing was pressed, so the beam drops immediately rather than
  // holding out the minimum a real press earns.
  void _handleCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _down = false;
    _minimumTimer?.cancel();
    _minimumTimer = null;
    _minimumMet = true;
    _release();
  }

  bool _containsLocal(Offset position) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    return (Offset.zero & box.size).contains(position);
  }

  void _release() {
    if (!mounted || !_active) return;
    setState(() => _active = false);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _handleDown,
    onPointerUp: _handleUp,
    onPointerCancel: _handleCancel,
    child: BorderBeam(
      variant: widget.variant,
      colors: widget.colors,
      active: _active,
      borderRadius: widget.borderRadius,
      style: widget.style,
      shape: widget.shape,
      timing: widget.timing,
      child: widget.child,
    ),
  );
}
