import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';

import 'surfaces.dart' show squircle;
import 'tokens.dart';

/// Scales its child down a touch while pressed, and clicks on tap.
class Pressable extends StatefulWidget {
  /// Creates the wrapper.
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticLabel,
    this.selected = false,
  });

  /// Called on tap.
  final VoidCallback onTap;

  /// The pressable content.
  final Widget child;

  /// What a screen reader announces.
  final String? semanticLabel;

  /// Whether a screen reader should announce this as selected.
  final bool selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.selected,
    label: widget.semanticLabel,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 140),
        curve: easeOut,
        child: widget.child,
      ),
    ),
  );
}

/// A segmented control over the effects whose thumb tracks [page] — the
/// stage's live scroll position — so it slides with a swipe as well as a
/// tap.
class EffectSelector extends StatelessWidget {
  /// Creates the selector.
  const EffectSelector({
    super.key,
    required this.labels,
    required this.page,
    required this.onSelect,
  });

  /// One label per effect.
  final List<String> labels;

  /// The stage's page, fractional mid-swipe.
  final ValueListenable<double> page;

  /// Called with the tapped index.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(color: t.track, shape: squircle(20)),
      child: LayoutBuilder(
        builder: (context, box) {
          final segment = box.maxWidth / labels.length;
          return ValueListenableBuilder<double>(
            valueListenable: page,
            builder: (context, page, _) => Stack(
              children: [
                Positioned(
                  left: page * segment,
                  width: segment,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: t.thumb,
                      shape: squircle(17),
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (i, label) in labels.indexed)
                      Expanded(
                        child: Pressable(
                          onTap: () => onSelect(i),
                          selected: page.round() == i,
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.1,
                                // Brightens as the thumb arrives.
                                color: Color.lerp(
                                  t.text,
                                  t.muted,
                                  (page - i).abs().clamp(0, 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One round swatch per entry of [BeamColors.presets], drawn from the
/// palette's own stops, in a row that scrolls under faded edges.
class PaletteRow extends StatelessWidget {
  /// Creates the row.
  const PaletteRow({super.key, required this.selected, required this.onSelect});

  /// The selected preset's name.
  final String selected;

  /// Called with the tapped preset's name.
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SwatchRow(
    names: BeamColors.presets.keys.toList(),
    gradientOf: (name) => _ringGradient(BeamColors.presets[name]!),
    selected: selected,
    onSelect: onSelect,
  );

  // The palette's ring as a sweep from 12 o'clock, clockwise — where the
  // beam itself places the stops. The ring wraps: past the last stop it
  // blends back into the first across 12 o'clock, so both ends of the sweep
  // carry the palette's own colour there.
  static Gradient _ringGradient(BeamColors colors) {
    final palette = colors.resolve();
    final stops = palette.stops;
    final opaque = [for (final c in palette.colors) c.withValues(alpha: 1)];
    if (opaque.length == 1) {
      return SweepGradient(colors: [opaque.first, opaque.first]);
    }
    final wrap = palette.sample(0).withValues(alpha: 1);
    return SweepGradient(
      transform: const GradientRotation(-math.pi / 2),
      colors: [wrap, ...opaque, wrap],
      stops: [0, ...stops, 1],
    );
  }
}

/// A row of round swatches, one per name, each painted with
/// [gradientOf] its name, that scrolls under faded edges. The selected one
/// wears a ring.
class SwatchRow extends StatelessWidget {
  /// Creates the row.
  const SwatchRow({
    super.key,
    required this.names,
    required this.gradientOf,
    required this.selected,
    required this.onSelect,
  });

  /// The swatches' names, in order.
  final List<String> names;

  /// The fill of the swatch called this.
  final Gradient Function(String name) gradientOf;

  /// The selected swatch's name.
  final String selected;

  /// Called with the tapped swatch's name.
  final ValueChanged<String> onSelect;

  static const double _size = 30;
  static const double _ring = 3;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x00000000),
        ],
        stops: [0, 0.06, 0.94, 1],
      ).createShader(bounds),
      child: SizedBox(
        height: _size + 4 * _ring,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: names.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final name = names[i];
            final on = name == selected;
            return Pressable(
              key: ValueKey('swatch-$name'),
              onTap: () => onSelect(name),
              semanticLabel: '$name palette',
              selected: on,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: easeOut,
                padding: const EdgeInsets.all(_ring),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: on ? t.text : t.text.withValues(alpha: 0),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradientOf(name),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A small round icon button whose glyph turns as it changes — the
/// header's play/pause and theme toggles.
class RoundToggle extends StatelessWidget {
  /// Creates the button.
  const RoundToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// The current glyph; a new one rotates in.
  final IconData icon;

  /// What a screen reader announces.
  final String label;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: t.track, shape: BoxShape.circle),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: easeOut,
          switchOutCurve: easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: Icon(icon, key: ValueKey(icon), size: 18, color: t.muted),
        ),
      ),
    );
  }
}

/// A pill with a glyph and a word, in the round toggles' style — for a
/// header action that needs saying.
class PillButton extends StatelessWidget {
  /// Creates the button.
  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  /// The glyph before the word.
  final IconData icon;

  /// The word.
  final String label;

  /// Called on tap.
  final VoidCallback onTap;

  /// What a screen reader announces; [label] if null.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      child: Container(
        height: 36,
        // Wide enough for any one word, so two pills in the same spot match.
        constraints: const BoxConstraints(minWidth: 84),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: ShapeDecoration(color: t.track, shape: squircle(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: t.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: t.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A track you drag to hold a wave anywhere in its life, 0–1. Between drags
/// its thumb follows [value] — the wave as it plays — so it doubles as the
/// wave's progress bar.
///
/// A screen reader's increase and decrease hold the wave a step further on
/// or back, as a drag does, and let it go — to play on — once the screen
/// reader's focus leaves the bar, or a moment after the last step.
class ScrubBar extends StatefulWidget {
  /// Creates the bar.
  const ScrubBar({
    super.key,
    required this.value,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
  });

  /// Where the thumb sits, 0–1.
  final ValueListenable<double> value;

  /// Called with the point a drag starts at.
  final ValueChanged<double> onStart;

  /// Called with each point the drag moves to.
  final ValueChanged<double> onChanged;

  /// Called when the drag ends or is cancelled.
  final VoidCallback onEnd;

  @override
  State<ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<ScrubBar> {
  static const double _height = 36;
  static const double _inset = 3;
  static const double _thumb = _height - 2 * _inset;

  /// How far a screen reader's increase or decrease moves the wave.
  static const double _step = 0.1;

  /// How long after a screen reader's last step the wave is let go, if its
  /// focus has not left the bar by then.
  static const Duration _letGoAfter = Duration(seconds: 3);

  /// Whether a screen reader's steps hold the wave, and when they let go.
  bool _stepping = false;
  Timer? _letGo;

  void _stepTo(double at) {
    if (_stepping) {
      widget.onChanged(at);
    } else {
      _stepping = true;
      widget.onStart(at);
    }
    _letGo?.cancel();
    _letGo = Timer(_letGoAfter, _endSteps);
  }

  void _endSteps() {
    _letGo?.cancel();
    _letGo = null;
    if (!_stepping) return;
    _stepping = false;
    widget.onEnd();
  }

  // A drag takes the hold over from the screen reader's steps.
  void _dragStart(double at) {
    _letGo?.cancel();
    _letGo = null;
    _stepping = false;
    widget.onStart(at);
  }

  @override
  void dispose() {
    _letGo?.cancel();
    if (_stepping) {
      // Not while the tree is being torn down: let go after this frame.
      final end = widget.onEnd;
      WidgetsBinding.instance.addPostFrameCallback((_) => end());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: widget.value,
      builder: (context, v, bar) {
        String percent(double x) => '${(x * 100).round()}%';
        final up = math.min(v + _step, 1.0);
        final down = math.max(v - _step, 0.0);
        return Semantics(
          slider: true,
          label: 'Scrub the wave',
          value: percent(v),
          increasedValue: percent(up),
          decreasedValue: percent(down),
          onIncrease: v < 1 ? () => _stepTo(up) : null,
          onDecrease: v > 0 ? () => _stepTo(down) : null,
          onDidLoseAccessibilityFocus: _endSteps,
          child: bar,
        );
      },
      child: Row(
        children: [
          Text(
            'Scrub',
            style: TextStyle(
              color: t.muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final travel = math.max(
                  1.0,
                  box.maxWidth - 2 * _inset - _thumb,
                );
                // The point under the finger, with the thumb's middle on it.
                double at(Offset local) =>
                    ((local.dx - _inset - _thumb / 2) / travel).clamp(0.0, 1.0);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onHorizontalDragStart: (d) => _dragStart(at(d.localPosition)),
                  onHorizontalDragUpdate: (d) =>
                      widget.onChanged(at(d.localPosition)),
                  onHorizontalDragEnd: (_) => widget.onEnd(),
                  onHorizontalDragCancel: widget.onEnd,
                  child: Container(
                    height: _height,
                    padding: const EdgeInsets.all(_inset),
                    decoration: ShapeDecoration(
                      color: t.track,
                      shape: squircle(_height / 2),
                    ),
                    child: ValueListenableBuilder<double>(
                      valueListenable: widget.value,
                      builder: (context, v, _) => Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: _thumb + v * travel,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: t.thumb.withValues(alpha: 0.5),
                                shape: squircle(_thumb / 2),
                              ),
                            ),
                          ),
                          Positioned(
                            left: v * travel,
                            top: 0,
                            bottom: 0,
                            width: _thumb,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: t.thumb,
                                shape: squircle(_thumb / 2),
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<double>(
            valueListenable: widget.value,
            builder: (context, v, _) => SizedBox(
              width: 40,
              child: Text(
                v.toStringAsFixed(2),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: t.faint,
                  fontSize: 12,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: const ['monospace', 'Consolas'],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
