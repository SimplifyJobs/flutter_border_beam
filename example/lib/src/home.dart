import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

import 'controls.dart';
import 'surfaces.dart';
import 'tokens.dart';

/// The one screen: a stage you swipe between the four effects, each on the
/// surface it is made for, with a caption, an effect selector, and the
/// palettes underneath. Tapping the stage fades the beam out and back in.
class Home extends StatefulWidget {
  /// Creates the screen.
  const Home({super.key, required this.dark, required this.onToggleTheme});

  /// Whether the dark theme is on; the beams are tuned to match.
  final bool dark;

  /// Flips the app theme.
  final VoidCallback onToggleTheme;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const _effects = BeamEffect.values;

  final PageController _pages = PageController();
  final ValueNotifier<double> _page = ValueNotifier<double>(0);
  int _index = 0;
  String _palette = 'colorful';
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() {
      final page = _pages.page ?? 0;
      _page.value = page;
      if (page.round() != _index) setState(() => _index = page.round());
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _page.dispose();
    super.dispose();
  }

  void _select(int index) => _pages.animateToPage(
    index,
    duration: const Duration(milliseconds: 420),
    curve: easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Material(
        color: t.bg,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          'Border Beam',
                          style: TextStyle(
                            color: t.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        RoundToggle(
                          key: const ValueKey('active-toggle'),
                          icon: _active
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          label: _active ? 'Fade the beam out' : 'Fade it in',
                          onTap: _toggleActive,
                        ),
                        const SizedBox(width: 8),
                        RoundToggle(
                          key: const ValueKey('theme-toggle'),
                          icon: widget.dark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          label: widget.dark ? 'Light theme' : 'Dark theme',
                          onTap: widget.onToggleTheme,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _stage(t)),
                  _caption(t),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: EffectSelector(
                      labels: [for (final e in _effects) _title(e)],
                      page: _page,
                      onSelect: _select,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PaletteRow(
                    selected: _palette,
                    onSelect: (name) => setState(() => _palette = name),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleActive() => setState(() => _active = !_active);

  // The swipeable stage; a tap fades the beam out and back in. Neighbouring
  // pages dim and shrink a little as they leave, so a swipe reads as moving
  // between exhibits.
  Widget _stage(Tokens t) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _toggleActive,
    child: DecoratedBox(
      // A faint spotlight, so the exhibit sits on a stage rather than a void.
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [t.spot, t.bg], radius: 0.5),
      ),
      child: LayoutBuilder(
        builder: (context, box) => PageView.builder(
          controller: _pages,
          itemCount: _effects.length,
          itemBuilder: (context, i) => ValueListenableBuilder<double>(
            valueListenable: _page,
            builder: (context, page, child) {
              final away = (page - i).abs().clamp(0.0, 1.0);
              return Opacity(
                opacity: 1 - away * 0.6,
                child: Transform.scale(scale: 1 - away * 0.08, child: child),
              );
            },
            // Scales down only when the stage is short (a phone on its side).
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _exhibit(_effects[i], box.maxWidth),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // One effect on the surface it is made for.
  Widget _exhibit(BeamEffect effect, double stageWidth) {
    final width = math.min(340.0, stageWidth - 48);
    final (Widget surface, BeamShape shape) = switch (effect) {
      RotateEffect() => (
        TaskCard(width: width),
        const BeamShape.all(surfaceRadius),
      ),
      LineEffect() => (
        Composer(width: width),
        const BeamShape.all(surfaceRadius),
      ),
      PulseEffect() => (
        ThinkingCard(width: width),
        const BeamShape.all(surfaceRadius),
      ),
      HaloEffect() => (const AskButton(), const BeamShape.stadium()),
    };
    return BorderBeam(
      effect: effect,
      colors: BeamColors.presets[_palette],
      active: _active,
      shape: shape,
      style: BeamStyle(theme: widget.dark ? BeamTheme.dark : BeamTheme.light),
      child: surface,
    );
  }

  Widget _caption(Tokens t) {
    final effect = _effects[_index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: easeOut,
            switchOutCurve: easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(_index),
              children: [
                Text(
                  _title(effect),
                  style: TextStyle(
                    color: t.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _blurb(effect),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.muted, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'BeamEffect.${effect.name}()  ·  BeamColors.$_palette',
            style: TextStyle(
              color: t.faint,
              fontSize: 12,
              fontFamily: 'Menlo',
              fontFamilyFallback: const ['monospace', 'Consolas'],
            ),
          ),
        ],
      ),
    );
  }
}

String _title(BeamEffect effect) =>
    effect.name[0].toUpperCase() + effect.name.substring(1);

String _blurb(BeamEffect effect) => switch (effect) {
  RotateEffect() => 'A beam laps the border of a card.',
  LineEffect() => 'A streak rides the edge of an input.',
  PulseEffect() => 'Colour breathes in while it thinks.',
  HaloEffect() => 'Light breathes out, past the edges.',
};
