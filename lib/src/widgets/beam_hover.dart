import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../border_beam.dart';
import '../models/beam_colors.dart';
import '../models/beam_shape.dart';
import '../models/beam_style.dart';
import '../models/beam_timing.dart';
import '../models/beam_variant.dart';

/// Lights a beam around [child] while the cursor is over it, and pulls the
/// sweep toward the cursor — the "spotlight border" effect.
///
/// ```dart
/// BeamHover(
///   borderRadius: 20,
///   child: pricingCard,
/// )
/// ```
///
/// Hover is a pointer-device idea, so this is a desktop and web wrapper: on a
/// touch device no mouse ever enters and the beam simply stays dark. `BeamPress`
/// is the touch counterpart.
///
/// The cursor position is fed to `BorderBeam.follow` as normalized box
/// coordinates, which eases the beam to the perimeter point nearest the
/// cursor. Leaving releases the follow immediately — the sweep resumes its
/// own schedule from where it is, without a snap — and the beam fades out
/// [holdAfterExit] later, so crossing a gap between two hoverable cards does
/// not strobe. Set [followPointer] to false to light the beam on hover
/// without steering it.
class BeamHover extends StatefulWidget {
  /// Creates a hover-driven beam around [child].
  const BeamHover({
    super.key,
    required this.child,
    this.variant = BeamVariant.rotate,
    this.colors,
    this.borderRadius,
    this.style,
    this.shape,
    this.timing,
    this.followPointer = true,
    this.holdAfterExit = const Duration(milliseconds: 300),
  });

  /// The hovered content. Laid out and hit-tested normally.
  final Widget child;

  /// Which effect the hover paints. Defaults to [BeamVariant.rotate]; only
  /// the traveling variants can follow a pointer.
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

  /// Whether the sweep gravitates to the cursor. False lights the beam on
  /// hover and leaves it on its own schedule.
  final bool followPointer;

  /// How long the beam stays lit after the cursor leaves.
  final Duration holdAfterExit;

  @override
  State<BeamHover> createState() => _BeamHoverState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<BeamVariant>('variant', variant))
      ..add(
        DiagnosticsProperty<BeamColors>('colors', colors, defaultValue: null),
      )
      ..add(DoubleProperty('borderRadius', borderRadius, defaultValue: null))
      ..add(
        FlagProperty(
          'followPointer',
          value: followPointer,
          ifFalse: 'does not follow the pointer',
        ),
      )
      ..add(DiagnosticsProperty<Duration>('holdAfterExit', holdAfterExit))
      ..add(DiagnosticsProperty<BeamStyle>('style', style, defaultValue: null))
      ..add(DiagnosticsProperty<BeamShape>('shape', shape, defaultValue: null))
      ..add(
        DiagnosticsProperty<BeamTiming>('timing', timing, defaultValue: null),
      );
  }
}

class _BeamHoverState extends State<BeamHover> {
  bool _active = false;
  Offset? _follow;
  Timer? _exitTimer;

  @override
  void didUpdateWidget(BeamHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.followPointer && _follow != null) _follow = null;
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  void _handleEnter(PointerEnterEvent event) {
    _exitTimer?.cancel();
    _exitTimer = null;
    _track(event.localPosition, active: true);
  }

  void _handleHover(PointerHoverEvent event) =>
      _track(event.localPosition, active: true);

  // The beam releases the pointer the moment it leaves, then holds its light
  // for [holdAfterExit]: a cursor crossing the gap between two cards should
  // not make either one strobe.
  void _handleExit(PointerExitEvent event) {
    _exitTimer?.cancel();
    _exitTimer = null;
    if (widget.holdAfterExit <= Duration.zero) {
      setState(() {
        _follow = null;
        _active = false;
      });
      return;
    }
    _exitTimer = Timer(widget.holdAfterExit, _fadeOut);
    if (_follow != null) setState(() => _follow = null);
  }

  void _fadeOut() {
    _exitTimer = null;
    if (!mounted) return;
    setState(() => _active = false);
  }

  void _track(Offset localPosition, {required bool active}) {
    final follow = widget.followPointer ? _normalize(localPosition) : null;
    if (active == _active && follow == _follow) return;
    setState(() {
      _active = active;
      _follow = follow;
    });
  }

  // Normalized box coordinates, which is what BorderBeam.follow takes. The
  // position is already local to the MouseRegion's box.
  Offset? _normalize(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return null;
    return Offset(
      (localPosition.dx / box.size.width).clamp(0.0, 1.0),
      (localPosition.dy / box.size.height).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: _handleEnter,
    onHover: _handleHover,
    onExit: _handleExit,
    child: BorderBeam(
      variant: widget.variant,
      colors: widget.colors,
      active: _active,
      follow: _follow,
      borderRadius: widget.borderRadius,
      style: widget.style,
      shape: widget.shape,
      timing: widget.timing,
      child: widget.child,
    ),
  );
}
