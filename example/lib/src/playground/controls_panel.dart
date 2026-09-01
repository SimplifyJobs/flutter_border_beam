import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

import '../demo_theme.dart';
import 'controls.dart';
import 'playground_state.dart';

/// Every playground control, grouped into collapsible sections.
///
/// The panel owns no state: it reads [state], hands each edit to [onEdit],
/// and routes the two playback concerns the section owns — swapping a
/// controller in ([onControllerMode]) and driving one ([onControllerAction])
/// — back up to it.
class ControlsPanel extends StatelessWidget {
  /// Creates the panel.
  const ControlsPanel({
    super.key,
    required this.state,
    required this.onEdit,
    required this.onControllerMode,
    required this.onControllerAction,
  });

  /// The configuration every control reads and writes.
  final PlaygroundState state;

  /// Applies a mutation to [state] and rebuilds.
  final void Function(VoidCallback mutate) onEdit;

  /// Turns controller mode on or off.
  final ValueChanged<bool> onControllerMode;

  /// Runs an action against every attached controller.
  final void Function(void Function(BorderBeamController)) onControllerAction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _sections(context),
  );

  List<Widget> _sections(BuildContext context) {
    final s = state;
    final isLine = s.variant == BeamVariant.line;
    final isPulse = s.variant.isPulse;
    final isOutside = s.variant == BeamVariant.pulseOutside;
    final brightness = DemoTheme.of(context).isDark
        ? Brightness.dark
        : Brightness.light;
    return [
      ControlSection(
        title: 'Variant & colors',
        initiallyExpanded: true,
        children: [
          ControlRow(
            label: 'Variant',
            child: ChipGroup(
              children: [
                for (final entry in _variantLabels.entries)
                  DemoChip(
                    label: entry.value,
                    selected: s.variant == entry.key,
                    onTap: () => onEdit(() => s.variant = entry.key),
                  ),
              ],
            ),
          ),
          ControlRow(
            label: 'Palette',
            child: ChipGroup(
              children: [
                for (final preset in PalettePreset.values)
                  DemoChip(
                    label: preset.label,
                    selected: s.palette == preset,
                    onTap: () => onEdit(() => s.palette = preset),
                  ),
              ],
            ),
          ),
          if (s.palette == PalettePreset.custom)
            ControlRow(
              label: 'Custom colors',
              child: ChipGroup(
                children: [
                  for (final (i, swatch) in customSwatches.indexed)
                    DemoChip(
                      label: swatch.name,
                      selected: s.customColors.contains(i),
                      leading: _Dot(color: swatch.color),
                      onTap: () => onEdit(() => _toggleSwatch(i)),
                    ),
                ],
              ),
            ),
        ],
      ),
      ControlSection(
        title: 'Shape',
        initiallyExpanded: true,
        children: [
          ControlRow(
            label: 'Corners',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Stadium',
                  selected: s.stadium,
                  onTap: () => onEdit(() => s.stadium = !s.stadium),
                ),
                DemoChip(
                  label: 'Per corner',
                  selected: s.perCorner,
                  onTap: () => onEdit(() => s.perCorner = !s.perCorner),
                ),
                DemoChip(
                  label: 'Squircle',
                  selected: s.superellipse,
                  onTap: () => onEdit(() => s.superellipse = !s.superellipse),
                ),
              ],
            ),
          ),
          if (!s.stadium && !s.perCorner)
            SliderRow(
              label: 'Radius',
              value: s.radius,
              min: 0,
              max: 48,
              suffix: 'px',
              onChanged: (v) => onEdit(() => s.radius = v),
            ),
          if (!s.stadium && s.perCorner) ...[
            SliderRow(
              label: 'Top left',
              value: s.radiusTopLeft,
              min: 0,
              max: 48,
              suffix: 'px',
              onChanged: (v) => onEdit(() => s.radiusTopLeft = v),
            ),
            SliderRow(
              label: 'Top right',
              value: s.radiusTopRight,
              min: 0,
              max: 48,
              suffix: 'px',
              onChanged: (v) => onEdit(() => s.radiusTopRight = v),
            ),
            SliderRow(
              label: 'Bottom right',
              value: s.radiusBottomRight,
              min: 0,
              max: 48,
              suffix: 'px',
              onChanged: (v) => onEdit(() => s.radiusBottomRight = v),
            ),
            SliderRow(
              label: 'Bottom left',
              value: s.radiusBottomLeft,
              min: 0,
              max: 48,
              suffix: 'px',
              onChanged: (v) => onEdit(() => s.radiusBottomLeft = v),
            ),
          ],
          SliderRow(
            label: 'Border width',
            value: s.borderWidth,
            min: 0.5,
            max: 4,
            suffix: 'px',
            onChanged: (v) => onEdit(() => s.borderWidth = v),
          ),
        ],
      ),
      ControlSection(
        title: 'Timing',
        children: [
          NullableSliderRow(
            label: 'Cycle',
            value: s.cycleSeconds,
            fallback: s.defaultCycleSeconds,
            min: 0.5,
            max: 8,
            suffix: 's',
            onChanged: (v) => onEdit(() => s.cycleSeconds = v),
          ),
          SliderRow(
            label: 'Cycle gap',
            value: s.cycleGapSeconds,
            min: 0,
            max: 4,
            suffix: 's',
            enabled: !isPulse,
            onChanged: (v) => onEdit(() => s.cycleGapSeconds = v),
          ),
          SliderRow(
            label: 'Speed',
            value: s.speed,
            min: 0.25,
            max: 4,
            suffix: '×',
            // A controller owns the rate; its own slider takes over.
            enabled: !s.controllerMode,
            onChanged: (v) => onEdit(() => s.speed = v),
          ),
          NullableSliderRow(
            label: 'Hue period',
            value: s.huePeriodSeconds,
            fallback: s.defaultHuePeriodSeconds,
            min: 2,
            max: 30,
            suffix: 's',
            onChanged: (v) => onEdit(() => s.huePeriodSeconds = v),
          ),
          if (isLine) ...[
            SliderRow(
              label: 'Breathe',
              value: s.breatheFactor,
              min: 0.5,
              max: 3,
              suffix: '×',
              onChanged: (v) => onEdit(() => s.breatheFactor = v),
            ),
            SliderRow(
              label: 'Spike',
              value: s.spikeFactor,
              min: 0.5,
              max: 3,
              suffix: '×',
              onChanged: (v) => onEdit(() => s.spikeFactor = v),
            ),
            SliderRow(
              label: 'Spike 2',
              value: s.spike2Factor,
              min: 0.5,
              max: 3,
              suffix: '×',
              onChanged: (v) => onEdit(() => s.spike2Factor = v),
            ),
          ],
          ControlRow(
            label: 'Hue',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Static colors',
                  selected: s.staticColors,
                  onTap: () => onEdit(() => s.staticColors = !s.staticColors),
                ),
              ],
            ),
          ),
        ],
      ),
      ControlSection(
        title: 'Style',
        children: [
          SliderRow(
            label: 'Strength',
            value: s.strength,
            min: 0,
            max: 1,
            onChanged: (v) => onEdit(() => s.strength = v),
          ),
          NullableSliderRow(
            label: 'Brightness',
            value: s.brightness,
            fallback: s.defaultBrightness(brightness),
            min: 0.5,
            max: 3,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.brightness = v),
          ),
          NullableSliderRow(
            label: 'Saturation',
            value: s.saturation,
            fallback: s.defaultSaturation(brightness),
            min: 0.5,
            max: 3,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.saturation = v),
          ),
          SliderRow(
            label: 'Hue range',
            value: s.hueRange,
            min: 0,
            max: 60,
            suffix: '°',
            // The line variant caps its own hue range at 13°.
            enabled: !isPulse,
            onChanged: (v) => onEdit(() => s.hueRange = v),
          ),
          SliderRow(
            label: 'Hue base',
            value: s.hueBase,
            min: -180,
            max: 180,
            suffix: '°',
            onChanged: (v) => onEdit(() => s.hueBase = v),
          ),
          SliderRow(
            label: 'Stroke opacity',
            value: s.strokeOpacityFactor,
            min: 0,
            max: 2,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.strokeOpacityFactor = v),
          ),
          SliderRow(
            label: 'Inner opacity',
            value: s.innerOpacityFactor,
            min: 0,
            max: 2,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.innerOpacityFactor = v),
          ),
          SliderRow(
            label: 'Bloom opacity',
            value: s.bloomOpacityFactor,
            min: 0,
            max: 2,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.bloomOpacityFactor = v),
          ),
          if (isPulse)
            SliderRow(
              label: 'Glow boost',
              value: s.glowBoost,
              min: 0,
              max: 3,
              suffix: '×',
              onChanged: (v) => onEdit(() => s.glowBoost = v),
            ),
          if (isOutside) ...[
            NullableSliderRow(
              label: 'Core blur',
              value: s.coreBlur,
              fallback: null,
              min: 0,
              max: 60,
              suffix: 'px',
              onChanged: (v) => onEdit(() => s.coreBlur = v),
            ),
            NullableSliderRow(
              label: 'Bloom blur',
              value: s.bloomBlur,
              fallback: null,
              min: 0,
              max: 120,
              suffix: 'px',
              onChanged: (v) => onEdit(() => s.bloomBlur = v),
            ),
            NullableSliderRow(
              label: 'Glow brightness',
              value: s.glowBrightness,
              fallback: null,
              min: 0.5,
              max: 3,
              suffix: '×',
              onChanged: (v) => onEdit(() => s.glowBrightness = v),
            ),
            NullableSliderRow(
              label: 'Glow saturation',
              value: s.glowSaturation,
              fallback: null,
              min: 0.5,
              max: 3,
              suffix: '×',
              onChanged: (v) => onEdit(() => s.glowSaturation = v),
            ),
          ],
        ],
      ),
      ControlSection(
        title: 'Playback',
        initiallyExpanded: true,
        children: [
          ControlRow(
            label: 'Mode',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: s.active ? 'Active' : 'Inactive',
                  selected: s.active,
                  onTap: s.controllerMode
                      ? () {}
                      : () => onEdit(() => s.active = !s.active),
                ),
                DemoChip(
                  label: 'Controller',
                  selected: s.controllerMode,
                  onTap: () => onControllerMode(!s.controllerMode),
                ),
              ],
            ),
          ),
          if (s.controllerMode) ...[
            ControlRow(
              label: 'Transport',
              child: ChipGroup(
                children: [
                  for (final entry
                      in <String, void Function(BorderBeamController)>{
                        'Start': (c) => c.start(),
                        'Pause': (c) => c.pause(),
                        'Resume': (c) => c.resume(),
                        'Stop': (c) => c.stop(),
                      }.entries)
                    DemoChip(
                      label: entry.key,
                      selected: false,
                      onTap: () => onControllerAction(entry.value),
                    ),
                ],
              ),
            ),
            SliderRow(
              label: 'Controller speed',
              value: s.controllerSpeed,
              min: 0.25,
              max: 4,
              suffix: '×',
              onChanged: (v) => onEdit(() {
                s.controllerSpeed = v;
                onControllerAction((c) => c.speed = v);
              }),
            ),
          ] else ...[
            SliderRow(
              label: 'Start after',
              value: s.startAfterSeconds,
              min: 0,
              max: 3,
              suffix: 's',
              onChanged: (v) => onEdit(() => s.startAfterSeconds = v),
            ),
            SliderRow(
              label: 'Duration',
              value: s.durationSeconds,
              min: 0,
              max: 15,
              suffix: 's',
              onChanged: (v) => onEdit(() => s.durationSeconds = v),
            ),
          ],
        ],
      ),
      ControlSection(
        title: 'Theme',
        children: [
          ControlRow(
            label: 'Inheritance',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'BorderBeamTheme',
                  selected: s.themeDemo,
                  onTap: () => onEdit(() => s.themeDemo = !s.themeDemo),
                ),
              ],
            ),
          ),
          _Hint(
            'Wraps the preview in a BorderBeamTheme carrying ocean colors '
            'and a squircle-20 shape. Controls left at their default '
            'inherit from it; anything you set wins.',
          ),
        ],
      ),
    ];
  }

  void _toggleSwatch(int index) {
    final selected = state.customColors.toList();
    if (selected.contains(index)) {
      if (selected.length <= minCustomColors) return;
      selected.remove(index);
    } else {
      if (selected.length >= maxCustomColors) return;
      selected.add(index);
    }
    state.customColors = selected;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: t.muted,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

const Map<BeamVariant, String> _variantLabels = {
  BeamVariant.rotate: 'Large',
  BeamVariant.small: 'Small',
  BeamVariant.line: 'Line',
  BeamVariant.pulseInside: 'Pulse Inner',
  BeamVariant.pulseOutside: 'Pulse Outside',
};
