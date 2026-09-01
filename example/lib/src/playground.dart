import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter/material.dart';

import 'demo_theme.dart';

/// The interactive playground of the gallery: variant / palette / strength /
/// superellipse controls, a live preview, and the generated Flutter snippet
/// (ports the React demo's playground).
class PlaygroundSection extends StatefulWidget {
  /// Const constructor.
  const PlaygroundSection({super.key});

  @override
  State<PlaygroundSection> createState() => _PlaygroundSectionState();
}

class _PlaygroundSectionState extends State<PlaygroundSection> {
  static const _variants = [
    (label: 'Large', variant: BeamVariant.rotate),
    (label: 'Small', variant: BeamVariant.small),
    (label: 'Line', variant: BeamVariant.line),
    (label: 'Pulse Inner', variant: BeamVariant.pulseInside),
    (label: 'Pulse Outside', variant: BeamVariant.pulseOutside),
  ];
  static const _palettes = [
    (label: 'Colorful', name: 'colorful', colors: BeamColors.colorful),
    (label: 'Mono', name: 'mono', colors: BeamColors.mono),
    (label: 'Ocean', name: 'ocean', colors: BeamColors.ocean),
    (label: 'Sunset', name: 'sunset', colors: BeamColors.sunset),
  ];

  BeamVariant _variant = BeamVariant.rotate;
  int _paletteIndex = 0;
  double _strength = 0.7;
  bool _superellipse = false;
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    final theme = DemoTheme.of(context);
    final t = theme.tokens;
    final beamTheme = theme.isDark ? BeamTheme.dark : BeamTheme.light;
    final palette = _palettes[_paletteIndex];

    final preview = Container(
      width: 350,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.mockBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.mockBorder),
      ),
      child: _variant == BeamVariant.small
          ? null
          : Text(
              'Build anything...',
              style: TextStyle(
                fontSize: 13,
                color: t.mockPlaceholder,
                decoration: TextDecoration.none,
              ),
            ),
    );

    final beam = switch (_variant) {
      BeamVariant.rotate => BorderBeam.rotate(
        colors: palette.colors,
        theme: beamTheme,
        strength: _strength,
        active: _active,
        useSuperellipse: _superellipse,
        child: preview,
      ),
      BeamVariant.small => BorderBeam.small(
        colors: palette.colors,
        theme: beamTheme,
        strength: _strength,
        active: _active,
        useSuperellipse: _superellipse,
        borderRadius: 16,
        child: preview,
      ),
      BeamVariant.line => BorderBeam.line(
        colors: palette.colors,
        theme: beamTheme,
        strength: _strength,
        active: _active,
        useSuperellipse: _superellipse,
        child: preview,
      ),
      BeamVariant.pulseInside => BorderBeam.pulseInside(
        colors: palette.colors,
        theme: beamTheme,
        strength: _strength,
        active: _active,
        useSuperellipse: _superellipse,
        child: preview,
      ),
      BeamVariant.pulseOutside => BorderBeam.pulseOutside(
        colors: palette.colors,
        theme: beamTheme,
        strength: _strength,
        active: _active,
        useSuperellipse: _superellipse,
        child: preview,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ControlRow(
          label: 'Type',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in _variants)
                _Chip(
                  label: v.label,
                  selected: _variant == v.variant,
                  onTap: () => setState(() => _variant = v.variant),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ControlRow(
          label: 'Colors',
          child: Wrap(
            spacing: 6,
            children: [
              for (final (i, p) in _palettes.indexed)
                _Chip(
                  label: p.label,
                  selected: _paletteIndex == i,
                  onTap: () => setState(() => _paletteIndex = i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ControlRow(
          label: 'Strength',
          child: Row(
            children: [
              Expanded(
                child: _MinimalSlider(
                  value: _strength,
                  onChanged: (v) => setState(() => _strength = v),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  '${(_strength * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.muted,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ControlRow(
          label: 'Options',
          child: Wrap(
            spacing: 6,
            children: [
              _Chip(
                label: 'Squircle',
                selected: _superellipse,
                onTap: () => setState(() => _superellipse = !_superellipse),
              ),
              _Chip(
                label: _active ? 'Pause' : 'Play',
                selected: !_active,
                onTap: () => setState(() => _active = !_active),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: theme.isDark ? t.surface : const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(child: beam),
        ),
        const SizedBox(height: 16),
        _CodeBlock(code: _snippet(palette.name)),
      ],
    );
  }

  String _snippet(String paletteName) {
    final constructor = switch (_variant) {
      BeamVariant.rotate => 'rotate',
      BeamVariant.small => 'small',
      BeamVariant.line => 'line',
      BeamVariant.pulseInside => 'pulseInside',
      BeamVariant.pulseOutside => 'pulseOutside',
    };
    final args = [
      if (paletteName != 'colorful') 'colors: BeamColors.$paletteName,',
      if (_strength < 1) 'strength: ${_strength.toStringAsFixed(2)},',
      if (_superellipse) 'useSuperellipse: true,',
      if (!_active) 'active: false,',
      'child: child,',
    ];
    return 'BorderBeam.$constructor(\n  ${args.join('\n  ')}\n)';
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: t.muted,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.btnBgActive : t.btnBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? t.btnTextActive : t.btnText,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _MinimalSlider extends StatelessWidget {
  const _MinimalSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset local) {
          onChanged((local.dx / constraints.maxWidth).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => update(d.localPosition),
          onHorizontalDragUpdate: (d) => update(d.localPosition),
          child: SizedBox(
            height: 28,
            child: Center(
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: t.trackBg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: t.trackFill,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 12,
          height: 1.6,
          fontFamily: 'Menlo',
          fontFamilyFallback: const ['Courier New', 'monospace'],
          color: t.codeText,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
