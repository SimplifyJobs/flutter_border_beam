import 'package:flutter/widgets.dart';

import 'models/wave_type.dart';

/// Where a distortion wave opens from: a rect — the button, edge or avatar
/// that started it — and optionally the point on it that was touched, which
/// the vertical and horizontal waves lean toward.
///
/// Most of the time you need none of this: wrap the button in a
/// [DistortionWaveAnchor] and the wave finds it, and the touch, by itself.
@immutable
sealed class WaveSource {
  const WaveSource._();

  /// [rect] in the wave's own coordinates, touched at [focus] (also in the
  /// wave's coordinates), if given.
  const factory WaveSource.rect(Rect rect, {Offset? focus}) = _RectSource;

  /// The widget with [key], measured when the wave starts, touched at
  /// [focus] (in global coordinates), if given.
  const factory WaveSource.key(GlobalKey key, {Offset? focus}) = _KeySource;

  /// The widget at [context], measured now — or, inside a
  /// [DistortionWaveAnchor], the anchor and where it was last touched.
  ///
  /// Call it where the wave is started, as in a button's `onPressed`:
  ///
  /// ```dart
  /// onPressed: () => Navigator.of(context).push(
  ///   DistortionWaveRoute(
  ///     source: WaveSource.of(context),
  ///     builder: (_) => const ReceiptScreen(),
  ///   ),
  /// ),
  /// ```
  factory WaveSource.of(BuildContext context) {
    final anchor = context.findAncestorStateOfType<DistortionWaveAnchorState>();
    final rect = _globalRect(
      anchor?.context.findRenderObject() ?? context.findRenderObject(),
    );
    if (rect == null) return const _NoSource();
    return _GlobalSource(rect, focus: anchor?.lastTouch);
  }

  /// This source in the coordinates of [stage], or null when it cannot be
  /// measured (its widget is gone).
  ({Rect rect, Offset? focus})? resolve(RenderBox stage);

  // Null for anything that is not a laid-out box (a sliver, say): it has no
  // rect to open from.
  static Rect? _globalRect(RenderObject? box) {
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  static Matrix4? _fromGlobal(RenderBox stage) {
    if (!stage.attached) return null;
    return Matrix4.tryInvert(stage.getTransformTo(null));
  }
}

final class _RectSource extends WaveSource {
  const _RectSource(this.rect, {this.focus}) : super._();

  final Rect rect;
  final Offset? focus;

  @override
  ({Rect rect, Offset? focus}) resolve(RenderBox stage) =>
      (rect: rect, focus: focus);

  @override
  bool operator ==(Object other) =>
      other is _RectSource && other.rect == rect && other.focus == focus;

  @override
  int get hashCode => Object.hash(rect, focus);

  @override
  String toString() => 'WaveSource.rect($rect, focus: $focus)';
}

final class _KeySource extends WaveSource {
  const _KeySource(this.key, {this.focus}) : super._();

  final GlobalKey key;
  final Offset? focus;

  @override
  ({Rect rect, Offset? focus})? resolve(RenderBox stage) {
    final rect = WaveSource._globalRect(key.currentContext?.findRenderObject());
    if (rect == null) return null;
    return _GlobalSource(rect, focus: focus).resolve(stage);
  }

  @override
  bool operator ==(Object other) =>
      other is _KeySource && other.key == key && other.focus == focus;

  @override
  int get hashCode => Object.hash(key, focus);

  @override
  String toString() => 'WaveSource.key($key, focus: $focus)';
}

final class _GlobalSource extends WaveSource {
  const _GlobalSource(this.rect, {this.focus}) : super._();

  /// The rect, in global coordinates.
  final Rect rect;

  /// The touch, in global coordinates.
  final Offset? focus;

  @override
  ({Rect rect, Offset? focus})? resolve(RenderBox stage) {
    final toStage = WaveSource._fromGlobal(stage);
    if (toStage == null) return null;
    final f = focus;
    return (
      rect: MatrixUtils.transformRect(toStage, rect),
      focus: f == null ? null : MatrixUtils.transformPoint(toStage, f),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _GlobalSource && other.rect == rect && other.focus == focus;

  @override
  int get hashCode => Object.hash(rect, focus);

  @override
  String toString() => 'WaveSource.of($rect, focus: $focus)';
}

final class _NoSource extends WaveSource {
  const _NoSource() : super._();

  @override
  ({Rect rect, Offset? focus})? resolve(RenderBox stage) => null;

  @override
  bool operator ==(Object other) => other is _NoSource;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'WaveSource.none';
}

/// The rect a wave of [type] opens from in a view of [size] when nothing
/// says otherwise: a button along the bottom for the vertical wave, the left
/// edge for the horizontal one, an avatar in the middle for the center one.
Rect defaultWaveSource(WaveType type, Size size) => switch (type) {
  WaveType.vertical => Rect.fromCenter(
    center: Offset(size.width / 2, size.height - 52),
    width: (size.width - 40).clamp(0.0, 350.0),
    height: 56,
  ),
  WaveType.horizontal => Rect.fromLTWH(
    0,
    size.height * 0.2,
    24,
    size.height * 0.6,
  ),
  WaveType.center => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: 64,
    height: 64,
  ),
};

/// Marks a widget — typically the button that starts a wave — as the wave's
/// source, and remembers where it was touched.
///
/// A `DistortionWave` with no `source` opens from the anchor inside it that
/// was pressed or focused last, leaning toward the touch. When nothing was —
/// a screen reader activates a button without touching or focusing it — it
/// opens from the only anchor on the side on screen, if there is one.
/// `WaveSource.of(context)` called inside an anchor measures the anchor and
/// carries its touch too, which is how a `DistortionWaveRoute` finds its
/// button.
///
/// ```dart
/// DistortionWaveAnchor(
///   child: FilledButton(
///     onPressed: () => setState(() => sent = true),
///     child: const Text('Send'),
///   ),
/// )
/// ```
class DistortionWaveAnchor extends StatefulWidget {
  /// Marks [child] as a wave's source.
  const DistortionWaveAnchor({super.key, required this.child});

  /// The widget the wave opens from.
  final Widget child;

  @override
  State<DistortionWaveAnchor> createState() => DistortionWaveAnchorState();
}

/// The state of a [DistortionWaveAnchor]: where it was last touched.
class DistortionWaveAnchorState extends State<DistortionWaveAnchor> {
  Offset? _lastTouch;

  /// Where the anchor was last touched, in global coordinates, or null if it
  /// has not been.
  Offset? get lastTouch => _lastTouch;

  /// The anchor as a source: its rect now, and its last touch.
  WaveSource get source {
    final rect = WaveSource._globalRect(context.findRenderObject());
    if (rect == null) return const _NoSource();
    return _GlobalSource(rect, focus: _lastTouch);
  }

  WaveAnchorRegistry? _registry;

  // Depends on the scope, so a new registry or side reaches the anchor.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.dependOnInheritedWidgetOfExactType<WaveAnchorScope>();
    final registry = scope?.registry;
    if (!identical(registry, _registry)) {
      _registry?.forget(this);
      _registry = registry;
    }
    _registry?.add(this, onRevealedSide: scope?.onRevealedSide);
  }

  void _onPointerDown(PointerDownEvent event) {
    _lastTouch = event.position;
    _registry?.pressed(this);
  }

  // Focus landing inside the anchor — Tab, then Enter or Space — counts as
  // a press. Reached by keyboard, the anchor forgets its last touch, so the
  // wave does not lean toward a point touched long ago.
  void _onFocusChange(bool focused) {
    if (!focused) return;
    if (FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
      _lastTouch = null;
    }
    _registry?.pressed(this);
  }

  @override
  void dispose() {
    _registry?.forget(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onFocusChange: _onFocusChange,
    child: Listener(onPointerDown: _onPointerDown, child: widget.child),
  );
}

/// Knows the [DistortionWaveAnchor]s inside a wave, which side each is on,
/// and which was pressed or focused last. Provided by every
/// `DistortionWave` to both its sides.
final class WaveAnchorRegistry {
  final Map<DistortionWaveAnchorState, bool?> _sides = {};
  DistortionWaveAnchorState? _last;

  /// The anchor pressed or focused last, if it is still mounted.
  DistortionWaveAnchorState? get last =>
      (_last?.mounted ?? false) ? _last : null;

  /// The anchor a run starting with the revealed side on screen
  /// ([revealedOnScreen]) or the child on screen opens from: the one
  /// pressed or focused last if it is on that side, else the only anchor on
  /// that side, else the one pressed or focused last wherever it is (a wave
  /// started by something other than an anchor collapses into the anchor it
  /// opened from), else none.
  DistortionWaveAnchorState? sourceFor({required bool revealedOnScreen}) {
    final last = this.last;
    if (last != null && _sides[last] == revealedOnScreen) return last;
    DistortionWaveAnchorState? only;
    for (final MapEntry(key: anchor, value: side) in _sides.entries) {
      if (side != revealedOnScreen || !anchor.mounted) continue;
      if (only != null) return last;
      only = anchor;
    }
    return only ?? last;
  }

  /// Records [anchor], on the revealed side ([onRevealedSide] true), the
  /// child's (false) or neither (null).
  void add(DistortionWaveAnchorState anchor, {bool? onRevealedSide}) =>
      _sides[anchor] = onRevealedSide;

  /// Records [anchor] as pressed or focused.
  void pressed(DistortionWaveAnchorState anchor) => _last = anchor;

  /// Forgets [anchor], which is going away.
  void forget(DistortionWaveAnchorState anchor) {
    _sides.remove(anchor);
    if (identical(_last, anchor)) _last = null;
  }

  /// The registry of the nearest enclosing wave, without depending on it.
  static WaveAnchorRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WaveAnchorScope>()?.registry;
}

/// Provides a [WaveAnchorRegistry] to one side of a wave.
class WaveAnchorScope extends InheritedWidget {
  /// Provides [registry] to [child], the side [onRevealedSide] says.
  const WaveAnchorScope({
    super.key,
    required this.registry,
    this.onRevealedSide,
    required super.child,
  });

  /// The registry.
  final WaveAnchorRegistry registry;

  /// Whether [child] is the wave's revealed side (true), its child (false),
  /// or neither (null).
  final bool? onRevealedSide;

  @override
  bool updateShouldNotify(WaveAnchorScope oldWidget) =>
      !identical(registry, oldWidget.registry) ||
      onRevealedSide != oldWidget.onRevealedSide;
}
