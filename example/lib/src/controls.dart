import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:material_ui/material_ui.dart';

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

  static const double _size = 30;
  static const double _ring = 3;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final names = BeamColors.presets.keys.toList();
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
                    gradient: _ringGradient(BeamColors.presets[name]!),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

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
