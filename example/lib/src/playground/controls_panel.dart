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
    final travels = s.isTraveling;
    final ring = s.isRing;
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
          if (s.palette == PalettePreset.custom) ...[
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
            ControlRow(
              label: 'Base',
              child: ChipGroup(
                children: [
                  for (final preset in PalettePreset.presets)
                    DemoChip(
                      label: preset.label,
                      selected: s.customBase == preset,
                      onTap: () => onEdit(() => s.customBase = preset),
                    ),
                ],
              ),
            ),
            _Hint(
              'The base supplies the blob geometry and the alpha structure '
              'your colors are distributed over.',
            ),
          ],
          if (s.palette == PalettePreset.seed) ...[
            ControlRow(
              label: 'Seed',
              child: ChipGroup(
                children: [
                  for (final (i, swatch) in customSwatches.indexed)
                    DemoChip(
                      label: swatch.name,
                      selected: s.seedColor == i,
                      leading: _Dot(color: swatch.color),
                      onTap: () => onEdit(() => s.seedColor = i),
                    ),
                ],
              ),
            ),
            ControlRow(
              label: 'Harmony',
              child: ChipGroup(
                children: [
                  for (final entry in _harmonyLabels.entries)
                    DemoChip(
                      label: entry.value,
                      selected: s.seedHarmony == entry.key,
                      onTap: () => onEdit(() => s.seedHarmony = entry.key),
                    ),
                ],
              ),
            ),
          ],
          if (s.palette == PalettePreset.lerp) ...[
            ControlRow(
              label: 'From',
              child: ChipGroup(
                children: [
                  for (final preset in PalettePreset.presets)
                    DemoChip(
                      label: preset.label,
                      selected: s.lerpFrom == preset,
                      onTap: () => onEdit(() => s.lerpFrom = preset),
                    ),
                ],
              ),
            ),
            ControlRow(
              label: 'To',
              child: ChipGroup(
                children: [
                  for (final preset in PalettePreset.presets)
                    DemoChip(
                      label: preset.label,
                      selected: s.lerpTo == preset,
                      onTap: () => onEdit(() => s.lerpTo = preset),
                    ),
                ],
              ),
            ),
            SliderRow(
              label: 'Blend',
              value: s.lerpT,
              min: 0,
              max: 1,
              onChanged: (v) => onEdit(() => s.lerpT = v),
            ),
          ],
          SliderRow(
            label: 'Alpha scale',
            value: s.alphaScale,
            min: 0,
            max: 2,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.alphaScale = v),
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
                DemoChip(
                  label: 'Star contour',
                  selected: s.contour,
                  onTap: () => onEdit(() => s.contour = !s.contour),
                ),
              ],
            ),
          ),
          if (s.contour)
            _Hint(
              'A BeamPathContour replaces the rounded rectangle, so the '
              'radius and squircle toggles stop applying. The mock surface '
              'keeps its own corners — the beam never reads the child.',
            ),
          if (!s.stadium && !s.perCorner)
            SliderRow(
              label: 'Radius',
              value: s.radius,
              min: 0,
              max: 48,
              suffix: 'px',
              enabled: !s.contour,
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
          SliderRow(
            label: 'Ring offset',
            value: s.ringOffset,
            min: -12,
            max: 24,
            suffix: 'px',
            onChanged: (v) => onEdit(() => s.ringOffset = v),
          ),
          if (isLine)
            ControlRow(
              label: 'Edge',
              child: ChipGroup(
                children: [
                  for (final entry in _edgeLabels.entries)
                    DemoChip(
                      label: entry.value,
                      selected: s.edge == entry.key,
                      onTap: () => onEdit(() => s.edge = entry.key),
                    ),
                ],
              ),
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
          if (travels) ...[
            ControlRow(
              label: 'Direction',
              child: ChipGroup(
                children: [
                  for (final entry in _directionLabels.entries)
                    DemoChip(
                      label: entry.value,
                      selected: s.direction == entry.key,
                      onTap: () => onEdit(() => s.direction = entry.key),
                    ),
                ],
              ),
            ),
            SliderRow(
              label: 'Phase offset',
              value: s.phaseOffset,
              min: 0,
              max: 1,
              onChanged: (v) => onEdit(() => s.phaseOffset = v),
            ),
            ControlRow(
              label: 'Beams',
              child: ChipGroup(
                children: [
                  for (var count = 1; count <= 4; count++)
                    DemoChip(
                      label: '$count',
                      selected: s.beamCount == count,
                      onTap: () => onEdit(() => s.beamCount = count),
                    ),
                ],
              ),
            ),
          ],
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
          ControlRow(
            label: 'Hue mode',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Auto',
                  selected: s.hueMode == null,
                  onTap: () => onEdit(() => s.hueMode = null),
                ),
                for (final entry in _hueModeLabels.entries)
                  DemoChip(
                    label: entry.value,
                    selected: s.hueMode == entry.key,
                    onTap: () => onEdit(() => s.hueMode = entry.key),
                  ),
              ],
            ),
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
          if (ring)
            SliderRow(
              label: 'Tail length',
              value: s.tailLength,
              min: 0.5,
              max: 2,
              suffix: '×',
              onChanged: (v) => onEdit(() => s.tailLength = v),
            ),
          SliderRow(
            label: 'Glow spread',
            value: s.glowSpread,
            min: 0.5,
            max: 3,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.glowSpread = v),
          ),
          if (travels)
            SliderRow(
              label: 'Sparkle',
              value: s.sparkle,
              min: 0,
              max: 1,
              onChanged: (v) => onEdit(() => s.sparkle = v),
            ),
          if (ring)
            ControlRow(
              label: 'Comet',
              child: ChipGroup(
                children: [
                  DemoChip(
                    label: 'Comet tail',
                    selected: s.comet,
                    onTap: () => onEdit(() => s.comet = !s.comet),
                  ),
                ],
              ),
            ),
          if (!isLine)
            ControlRow(
              label: 'Segments',
              child: ChipGroup(
                children: [
                  DemoChip(
                    label: 'Off',
                    selected: s.segments == null,
                    onTap: () => onEdit(() => s.segments = null),
                  ),
                  for (final count in segmentChoices)
                    DemoChip(
                      label: '$count',
                      selected: s.segments == count,
                      onTap: () => onEdit(() => s.segments = count),
                    ),
                ],
              ),
            ),
          SliderRow(
            label: 'Render scale',
            value: s.renderScale,
            min: 0.25,
            max: 1,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.renderScale = v),
          ),
          if (s.variant == BeamVariant.pulseInside)
            SliderRow(
              label: 'Inner size',
              value: s.innerSizeScale,
              min: 0.5,
              max: 2,
              suffix: '×',
              onChanged: (v) => onEdit(() => s.innerSizeScale = v),
            ),
          if (isOutside)
            ControlRow(
              label: 'Recipe',
              child: ChipGroup(
                children: [
                  DemoChip(
                    label: 'Stock pulse-outside',
                    selected: s.stockPulseOutside,
                    onTap: () => onEdit(
                      () => s.stockPulseOutside = !s.stockPulseOutside,
                    ),
                  ),
                ],
              ),
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
          if (isOutside && s.stockPulseOutside)
            _Hint(
              'BeamStyle.pulseOutsideStock is the React library\'s own '
              'look, before the demo page\'s tuning: a tighter, dimmer halo. '
              'Anything set here layers over it.',
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
              // A BeamSync group owns its own clock, so the controller has
              // no beam to drive while the sync demo is on.
              enabled: !s.syncDemo,
              label: 'Transport',
              child: ChipGroup(
                children: [
                  for (final entry
                      in <String, void Function(BorderBeamController)>{
                        'Start': (c) => c.start(),
                        'Pause': (c) => c.pause(),
                        'Resume': (c) => c.resume(),
                        'Stop': (c) => c.stop(),
                        'Pulse': (c) => c.pulse(),
                        'Flash': (c) => c.flash(),
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
              enabled: !s.syncDemo,
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
          ControlRow(
            label: 'Repeat',
            child: ChipGroup(
              children: [
                for (final entry in _repeatLabels.entries)
                  DemoChip(
                    label: entry.value,
                    selected: s.repeatCycles == entry.key,
                    onTap: () => onEdit(() => s.repeatCycles = entry.key),
                  ),
              ],
            ),
          ),
          ControlRow(
            label: 'Reduced motion',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Static frame',
                  selected: s.reducedMotion == null,
                  onTap: () => onEdit(() => s.reducedMotion = null),
                ),
                for (final entry in _reducedMotionLabels.entries)
                  DemoChip(
                    label: entry.value,
                    selected: s.reducedMotion == entry.key,
                    onTap: () => onEdit(() => s.reducedMotion = entry.key),
                  ),
              ],
            ),
          ),
          ControlRow(
            label: 'Offscreen',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Pause offscreen',
                  selected: s.pauseWhenOffscreen,
                  onTap: () => onEdit(
                    () => s.pauseWhenOffscreen = !s.pauseWhenOffscreen,
                  ),
                ),
              ],
            ),
          ),
          ControlRow(
            label: 'Fade curve',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Spring',
                  selected: !s.cssFadeCurve,
                  onTap: () => onEdit(() => s.cssFadeCurve = false),
                ),
                DemoChip(
                  label: 'CSS ease',
                  selected: s.cssFadeCurve,
                  onTap: () => onEdit(() => s.cssFadeCurve = true),
                ),
              ],
            ),
          ),
          ControlRow(
            label: 'Simulate',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Simulate reduced motion',
                  selected: s.simulateReducedMotion,
                  onTap: () => onEdit(
                    () => s.simulateReducedMotion = !s.simulateReducedMotion,
                  ),
                ),
              ],
            ),
          ),
          _Hint(
            'Static frame is the package default, so it sets no field. '
            'Simulate wraps the preview in a MediaQuery asking for reduced '
            'motion — the same signal the platform sends.',
          ),
        ],
      ),
      ControlSection(
        title: 'Drive',
        children: [
          ControlRow(
            label: 'Sources',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Progress',
                  selected: s.driveProgress,
                  onTap: () => onEdit(() => s.driveProgress = !s.driveProgress),
                ),
                DemoChip(
                  label: 'Follow pointer',
                  selected: s.followPointer,
                  onTap: () => onEdit(() => s.followPointer = !s.followPointer),
                ),
                DemoChip(
                  label: 'Strength from signal',
                  selected: s.strengthSignal,
                  onTap: () =>
                      onEdit(() => s.strengthSignal = !s.strengthSignal),
                ),
              ],
            ),
          ),
          if (s.driveProgress)
            SliderRow(
              // Named for what it sets, so it does not read as a second
              // copy of the toggle above it.
              label: 'Position',
              value: s.progress,
              min: 0,
              max: 1,
              enabled: travels,
              onChanged: (v) => onEdit(() => s.progress = v),
            ),
          _Hint(
            travels
                ? 'Progress parks the sweep where you put it and follow eases '
                      'it to the pointer, so progress wins where both are on. '
                      'Strength rides a sine wave through a '
                      'strengthListenable, without a rebuild.'
                : 'The pulse variants have no travel, so progress and follow '
                      'do nothing here. Strength still rides a sine wave '
                      'through a strengthListenable.',
          ),
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
          ControlRow(
            label: 'Group',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'BeamSync',
                  selected: s.syncDemo,
                  onTap: () => onEdit(() => s.syncDemo = !s.syncDemo),
                ),
              ],
            ),
          ),
          _Hint(
            'BorderBeamTheme wraps the preview in ocean colors and a '
            'squircle-20 shape: controls left at their default inherit from '
            'it, anything you set wins. BeamSync swaps the preview for three '
            'beams on one clock, a third of a cycle apart.',
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

const Map<BeamSeedHarmony, String> _harmonyLabels = {
  BeamSeedHarmony.analogous: 'Analogous',
  BeamSeedHarmony.complementary: 'Complementary',
  BeamSeedHarmony.triadic: 'Triadic',
  BeamSeedHarmony.monochrome: 'Monochrome',
};

const Map<BeamEdge, String> _edgeLabels = {
  BeamEdge.top: 'Top',
  BeamEdge.right: 'Right',
  BeamEdge.bottom: 'Bottom',
  BeamEdge.left: 'Left',
};

const Map<BeamDirection, String> _directionLabels = {
  BeamDirection.forward: 'Forward',
  BeamDirection.reverse: 'Reverse',
  BeamDirection.bounce: 'Bounce',
};

const Map<BeamHueMode, String> _hueModeLabels = {
  BeamHueMode.pingPong: 'Ping-pong',
  BeamHueMode.continuous: 'Continuous',
};

// Null is the forever default; the two counts are the shapes BeamRepeat
// takes.
const Map<int?, String> _repeatLabels = {
  null: 'Forever',
  1: 'Once',
  3: '3 cycles',
};

// Static frame is the package default and lives on its own chip, which
// clears the field rather than setting it.
const Map<BeamReducedMotion, String> _reducedMotionLabels = {
  BeamReducedMotion.hide: 'Hide',
  BeamReducedMotion.slow: 'Slow',
  BeamReducedMotion.animate: 'Animate',
};
