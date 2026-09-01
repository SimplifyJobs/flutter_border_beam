import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../border_beam.dart';
import '../models/beam_colors.dart';
import '../models/beam_shape.dart';
import '../models/beam_style.dart';
import '../models/beam_timing.dart';
import '../models/beam_variant.dart';

/// Lights a beam around [child] while it holds keyboard focus.
///
/// ```dart
/// BeamFocusRing(
///   borderRadius: 12,
///   child: TextField(decoration: decoration),
/// )
/// ```
///
/// With no [focusNode] the ring inserts a non-focusable [Focus] around
/// [child] and follows *its subtree*: the beam lights while [child] or any
/// descendant of it holds focus, which is what a field, a button, or a whole
/// form wrapped in one ring should do. Pass [focusNode] to follow one
/// specific node instead — including a node that lives outside this subtree.
///
/// Focus comes and goes with the beam's own fades (0.6s in, 0.5s out) rather
/// than a cut, because the ring only flips `BorderBeam`'s `active`.
///
/// ## Highlight mode
///
/// The ring follows [FocusManager.highlightMode], the same rule
/// [FocusableActionDetector] uses: it shows under
/// [FocusHighlightMode.traditional] (focus moved by keyboard or mouse) and
/// stays dark under [FocusHighlightMode.touch], where a focus ring around a
/// tapped field is noise. Set [alwaysShow] to light it in either mode.
///
/// ## Accessibility
///
/// This is a *visual* focus indicator and complements the semantics a focused
/// widget already reports — it adds none of its own. Assistive technology
/// announces focus through the focused widget, not through this ring, so keep
/// whatever labels and semantics [child] carries.
class BeamFocusRing extends StatefulWidget {
  /// Creates a focus ring around [child].
  const BeamFocusRing({
    super.key,
    required this.child,
    this.focusNode,
    this.variant = BeamVariant.small,
    this.colors = BeamColors.ocean,
    this.borderRadius,
    this.style,
    this.shape,
    this.timing,
    this.alwaysShow = false,
  });

  /// The focused content. Laid out and hit-tested normally.
  final Widget child;

  /// The node whose focus the ring follows. Null follows [child]'s own
  /// subtree through an inserted non-focusable [Focus].
  final FocusNode? focusNode;

  /// Which effect the ring paints. Defaults to [BeamVariant.small], the
  /// compact traveling beam.
  final BeamVariant variant;

  /// The ring's palette. Defaults to [BeamColors.ocean].
  final BeamColors colors;

  /// Shorthand for a uniform corner radius in logical px. Match the focused
  /// widget's own radius.
  final double? borderRadius;

  /// Colors, theme adaptation, and filter hooks, passed straight through.
  final BeamStyle? style;

  /// Corner radii, ring width, and corner family, passed straight through.
  final BeamShape? shape;

  /// Cycle length, rest, rate, and hue periods, passed straight through.
  final BeamTiming? timing;

  /// Whether to light the ring even under [FocusHighlightMode.touch].
  final bool alwaysShow;

  @override
  State<BeamFocusRing> createState() => _BeamFocusRingState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<BeamVariant>('variant', variant))
      ..add(DiagnosticsProperty<BeamColors>('colors', colors))
      ..add(DoubleProperty('borderRadius', borderRadius, defaultValue: null))
      ..add(
        DiagnosticsProperty<FocusNode>(
          'focusNode',
          focusNode,
          defaultValue: null,
        ),
      )
      ..add(FlagProperty('alwaysShow', value: alwaysShow, ifTrue: 'alwaysShow'))
      ..add(DiagnosticsProperty<BeamStyle>('style', style, defaultValue: null))
      ..add(DiagnosticsProperty<BeamShape>('shape', shape, defaultValue: null))
      ..add(
        DiagnosticsProperty<BeamTiming>('timing', timing, defaultValue: null),
      );
  }
}

class _BeamFocusRingState extends State<BeamFocusRing> {
  // Created only when no node was supplied. Non-focusable and skipped by
  // traversal, so it changes nothing about where focus can land — it exists
  // to report whether focus is somewhere inside [child].
  FocusNode? _internalNode;
  bool _focused = false;
  late FocusHighlightMode _highlightMode;

  FocusNode get _node => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _highlightMode = FocusManager.instance.highlightMode;
    FocusManager.instance.addHighlightModeListener(_handleHighlightModeChange);
    _node.addListener(_handleFocusChange);
    _focused = _node.hasFocus;
  }

  @override
  void didUpdateWidget(BeamFocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    (oldWidget.focusNode ?? _internalNode)?.removeListener(_handleFocusChange);
    if (widget.focusNode != null) {
      _internalNode?.dispose();
      _internalNode = null;
    }
    _node.addListener(_handleFocusChange);
    _focused = _node.hasFocus;
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(
      _handleHighlightModeChange,
    );
    _node.removeListener(_handleFocusChange);
    _internalNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final focused = _node.hasFocus;
    if (focused == _focused) return;
    setState(() => _focused = focused);
  }

  void _handleHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted || mode == _highlightMode) return;
    setState(() => _highlightMode = mode);
  }

  // Mirrors FocusableActionDetector: a focus highlight belongs to keyboard
  // and mouse interaction, not to a tap that put focus in a field.
  bool get _showHighlight =>
      widget.alwaysShow || _highlightMode == FocusHighlightMode.traditional;

  @override
  Widget build(BuildContext context) {
    final beam = BorderBeam(
      variant: widget.variant,
      colors: widget.colors,
      active: _focused && _showHighlight,
      borderRadius: widget.borderRadius,
      style: widget.style,
      shape: widget.shape,
      timing: widget.timing,
      child: widget.child,
    );
    if (widget.focusNode != null) return beam;
    return Focus(
      focusNode: _node,
      canRequestFocus: false,
      skipTraversal: true,
      child: beam,
    );
  }
}
