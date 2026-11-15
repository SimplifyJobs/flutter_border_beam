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
    children: [
      _effectSection(),
      _colorsSection(),
      _styleSection(),
      _shapeSection(),
      _timingSection(),
      _playbackSection(),
      _driveSection(),
      _themeSection(),
    ],
  );

  Widget _effectSection() {
    final s = state;
    return ControlSection(
      title: 'Effect',
      initiallyExpanded: true,
      children: [
        ControlRow(
          label: 'Effect',
          child: ChipGroup(
            children: [
              for (final kind in EffectKind.values)
                DemoChip(
                  label: kind.label,
                  selected: s.effect == kind,
                  onTap: () => onEdit(() => s.effect = kind),
                ),
            ],
          ),
        ),
        if (s.effect == EffectKind.rotate) ...[
          SliderRow(
            label: 'Length',
            value: s.rotateLength,
            min: 0.25,
            max: 2,
            suffix: '×',
            onChanged: (v) => onEdit(() => s.rotateLength = v),
          ),
          ControlRow(
            label: 'Count',
            child: ChipGroup(
              children: [
                for (var count = 1; count <= 4; count++)
                  DemoChip(
                    label: '$count',
                    selected: s.rotateCount == count,
                    onTap: () => onEdit(() => s.rotateCount = count),
                  ),
              ],
            ),
          ),
          ControlRow(
            label: 'Comet',
            child: ChipGroup(
              children: [
                DemoChip(
                  label: 'Comet tail',
                  selected: s.rotateComet,
                  onTap: () => onEdit(() => s.rotateComet = !s.rotateComet),
                ),
              ],
            ),
          ),
        ],
        if (s.effect == EffectKind.line)
          ControlRow(
            label: 'Edge',
            child: ChipGroup(
              children: [
                for (final entry in _edgeLabels.entries)
                  DemoChip(
                    label: entry.value,
                    selected: s.lineEdge == entry.key,
                    onTap: () => onEdit(() => s.lineEdge = entry.key),
                  ),
              ],
            ),
          ),
        if (s.effect == EffectKind.shimmer)
          SliderRow(
            label: 'Angle',
            value: s.shimmerAngle,
            min: -90,
            max: 90,
            suffix: '°',
            onChanged: (v) => onEdit(() => s.shimmerAngle = v),
          ),
        _Hint(_effectHints[s.effect]!),
      ],
    );
  }

  Widget _colorsSection() {
    final s = state;
    return ControlSection(
      title: 'Colors',
      initiallyExpanded: true,
      children: [
        ControlRow(
          label: 'Preset',
          child: ChipGroup(
            children: [
              for (final name in presetNames)
                DemoChip(
                  label: presetLabel(name),
                  selected:
                      s.paletteMode == PaletteMode.preset && s.preset == name,
                  leading: _PaletteDot(
                    colors: PlaygroundState.presetColors(name),
                  ),
                  onTap: () => onEdit(() {
                    s
                      ..paletteMode = PaletteMode.preset
                      ..preset = name;
                  }),
                ),
            ],
          ),
        ),
        ControlRow(
          label: 'Build',
          child: ChipGroup(
            children: [
              for (final entry in _paletteModeLabels.entries)
                DemoChip(
                  label: entry.value,
                  selected: s.paletteMode == entry.key,
                  onTap: () => onEdit(() => s.paletteMode = entry.key),
                ),
            ],
          ),
        ),
        if (s.paletteMode == PaletteMode.custom)
          ControlRow(
            label: 'Colors',
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
        if (s.paletteMode == PaletteMode.seed) ...[
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
        if (s.paletteMode == PaletteMode.lerp) ...[
          ControlRow(
            label: 'From',
            child: _PresetPicker(
              selected: s.lerpFrom,
              onSelected: (name) => onEdit(() => s.lerpFrom = name),
            ),
          ),
          ControlRow(
            label: 'To',
            child: _PresetPicker(
              selected: s.lerpTo,
              onSelected: (name) => onEdit(() => s.lerpTo = name),
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
        _Hint(
          s.paletteMode == PaletteMode.custom
              ? 'BeamColors([...]) spaces your colors evenly around the '
                    'border from top-centre; pass stops: to place them.'
              : 'Mono and gold pin the hue: they never drift, whatever the '
                    'hue mode says.',
        ),
      ],
    );
  }

  Widget _styleSection() {
    final s = state;
    return ControlSection(
      title: 'Style',
      children: [
        ControlRow(
          label: 'Theme',
          child: ChipGroup(
            children: [
              DemoChip(
                label: 'Auto',
                selected: s.beamTheme == null,
                onTap: () => onEdit(() => s.beamTheme = null),
              ),
              DemoChip(
                label: 'Dark',
                selected: s.beamTheme == BeamTheme.dark,
                onTap: () => onEdit(() => s.beamTheme = BeamTheme.dark),
              ),
              DemoChip(
                label: 'Light',
                selected: s.beamTheme == BeamTheme.light,
                onTap: () => onEdit(() => s.beamTheme = BeamTheme.light),
              ),
            ],
          ),
        ),
        SliderRow(
          label: 'Strength',
          value: s.strength,
          min: 0,
          max: 1,
          onChanged: (v) => onEdit(() => s.strength = v),
        ),
        SliderRow(
          label: 'Glow',
          value: s.glow,
          min: 0,
          max: 3,
          suffix: '×',
          onChanged: (v) => onEdit(() => s.glow = v),
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
          label: 'Hue shift',
          value: s.hueShift,
          min: 0,
          max: 90,
          suffix: '°',
          // Only a ping-pong drift swings across ±hueShift.
          enabled: s.hueShiftApplies,
          onChanged: (v) => onEdit(() => s.hueShift = v),
        ),
        SliderRow(
          label: 'Hue base',
          value: s.hueBase,
          min: -180,
          max: 180,
          suffix: '°',
          onChanged: (v) => onEdit(() => s.hueBase = v),
        ),
        _Hint(
          'Auto hue mode is ${_hueModeLabels[s.effect.defaults.defaultHueMode]!.toLowerCase()} '
          'for ${s.effect.id}. Glow scales every glow around the border; '
          'the crisp stroke stays put, so 0 leaves only the stroke.',
        ),
      ],
    );
  }

  Widget _shapeSection() {
    final s = state;
    return ControlSection(
      title: 'Shape',
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
        SliderRow(
          label: 'Ring offset',
          value: s.ringOffset,
          min: -12,
          max: 24,
          suffix: 'px',
          onChanged: (v) => onEdit(() => s.ringOffset = v),
        ),
        ControlRow(
          label: 'Dashes',
          child: ChipGroup(
            children: [
              DemoChip(
                label: 'Solid',
                selected: s.dashes == null,
                onTap: () => onEdit(() => s.dashes = null),
              ),
              for (final count in dashChoices)
                DemoChip(
                  label: '$count',
                  selected: s.dashes == count,
                  onTap: () => onEdit(() => s.dashes = count),
                ),
            ],
          ),
        ),
        ControlRow(
          label: 'Segment',
          child: ChipGroup(
            children: [
              for (final preset in SegmentPreset.values)
                DemoChip(
                  label: preset.label,
                  selected: s.segmentPreset == preset,
                  onTap: () => onEdit(() => s.segmentPreset = preset),
                ),
            ],
          ),
        ),
        if (s.segmentPreset == SegmentPreset.custom) ...[
          ControlRow(
            label: 'Start edge',
            child: ChipGroup(
              children: [
                for (final entry in _edgeLabels.entries)
                  DemoChip(
                    label: entry.value,
                    selected: s.segmentStartEdge == entry.key,
                    onTap: () => onEdit(() => s.segmentStartEdge = entry.key),
                  ),
              ],
            ),
          ),
          SliderRow(
            label: 'Start t',
            value: s.segmentStartT,
            min: 0,
            max: 1,
            onChanged: (v) => onEdit(() => s.segmentStartT = v),
          ),
          ControlRow(
            label: 'End edge',
            child: ChipGroup(
              children: [
                for (final entry in _edgeLabels.entries)
                  DemoChip(
                    label: entry.value,
                    selected: s.segmentEndEdge == entry.key,
                    onTap: () => onEdit(() => s.segmentEndEdge = entry.key),
                  ),
              ],
            ),
          ),
          SliderRow(
            label: 'End t',
            value: s.segmentEndT,
            min: 0,
            max: 1,
            onChanged: (v) => onEdit(() => s.segmentEndT = v),
          ),
          SliderRow(
            label: 'Feather',
            value: s.segmentFeather,
            min: 0,
            max: 120,
            suffix: 'px',
            onChanged: (v) => onEdit(() => s.segmentFeather = v),
          ),
        ],
        _Hint(
          'A segment masks the full-border animation rather than refitting '
          'it, so a travelling beam enters at the start and leaves at the '
          'end. The mock surface follows the corners — a beam never reads '
          'its child.',
        ),
      ],
    );
  }

  Widget _timingSection() {
    final s = state;
    return ControlSection(
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
        NullableSliderRow(
          label: 'Cycle gap',
          value: s.cycleGapSeconds,
          fallback: s.defaultCycleGapSeconds,
          min: 0,
          max: 4,
          suffix: 's',
          // Ambient effects have no cycle boundary to rest at.
          enabled: s.travels,
          onChanged: (v) => onEdit(() => s.cycleGapSeconds = v),
        ),
        SliderRow(
          label: 'Speed',
          value: s.speed,
          min: 0.25,
          max: 4,
          suffix: '×',
          // A controller owns a single beam's rate; BeamSync owns the
          // group's rate even when controller mode remains selected.
          enabled: !s.controllerMode || s.syncDemo,
          onChanged: (v) => onEdit(() => s.speed = v),
        ),
        ControlRow(
          label: 'Direction',
          enabled: s.directionApplies,
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
        NullableSliderRow(
          label: 'Hue period',
          value: s.huePeriodSeconds,
          fallback: s.defaultHuePeriodSeconds,
          min: 2,
          max: 30,
          suffix: 's',
          enabled: s.hueDrifts,
          onChanged: (v) => onEdit(() => s.huePeriodSeconds = v),
        ),
      ],
    );
  }

  Widget _playbackSection() {
    final s = state;
    return ControlSection(
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
                enabled: !s.controllerMode || s.syncDemo,
                onTap: () => onEdit(() => s.active = !s.active),
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
                // Labelled as the calls they make, which also keeps
                // `pulse()` apart from the Pulse effect chip.
                for (final entry
                    in <String, void Function(BorderBeamController)>{
                      'start()': (c) => c.start(),
                      'pause()': (c) => c.pause(),
                      'resume()': (c) => c.resume(),
                      'stop()': (c) => c.stop(),
                      'pulse()': (c) => c.pulse(),
                      'flash()': (c) => c.flash(),
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
            enabled: !s.syncDemo,
            onChanged: (v) => onEdit(() => s.startAfterSeconds = v),
          ),
          SliderRow(
            label: 'Duration',
            value: s.durationSeconds,
            min: 0,
            max: 15,
            suffix: 's',
            enabled: !s.syncDemo,
            onChanged: (v) => onEdit(() => s.durationSeconds = v),
          ),
        ],
        ControlRow(
          enabled: !s.syncDemo,
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
          enabled: !s.syncDemo,
          label: 'Offscreen',
          child: ChipGroup(
            children: [
              DemoChip(
                label: 'Default',
                selected: s.pauseWhenOffscreen == null,
                onTap: () => onEdit(() => s.pauseWhenOffscreen = null),
              ),
              DemoChip(
                label: 'Pause offscreen',
                selected: s.pauseWhenOffscreen == true,
                onTap: () => onEdit(() => s.pauseWhenOffscreen = true),
              ),
              DemoChip(
                label: 'Keep running',
                selected: s.pauseWhenOffscreen == false,
                onTap: () => onEdit(() => s.pauseWhenOffscreen = false),
              ),
            ],
          ),
        ),
        ControlRow(
          enabled: !s.syncDemo,
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
    );
  }

  Widget _driveSection() {
    final s = state;
    final travels = s.travels;
    return ControlSection(
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
                onTap: () => onEdit(() => s.strengthSignal = !s.strengthSignal),
              ),
            ],
          ),
        ),
        if (s.driveProgress)
          SliderRow(
            // Named for what it sets, so it does not read as a second copy
            // of the toggle above it.
            label: 'Position',
            value: s.progress,
            min: 0,
            max: 1,
            enabled: travels,
            onChanged: (v) => onEdit(() => s.progress = v),
          ),
        _Hint(
          travels
              ? 'Progress places the sweep where you put it — charge fills '
                    'to it, rotate becomes a progress ring — and follow eases '
                    'it to the pointer, so progress wins where both are on. '
                    'Strength rides a sine wave through a '
                    'strengthListenable, without a rebuild.'
              : 'Pulse, halo, flow, and spin have no travel, so progress and '
                    'follow do nothing here. Strength still rides a sine '
                    'wave through a strengthListenable.',
        ),
      ],
    );
  }

  Widget _themeSection() {
    final s = state;
    return ControlSection(
      title: 'Theme & sync',
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
    );
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

/// A row of preset chips picking one name — the lerp endpoints.
class _PresetPicker extends StatelessWidget {
  const _PresetPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => ChipGroup(
    children: [
      for (final name in presetNames)
        DemoChip(
          label: presetLabel(name),
          selected: selected == name,
          leading: _PaletteDot(colors: PlaygroundState.presetColors(name)),
          onTap: () => onSelected(name),
        ),
    ],
  );
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

/// A palette's ring of stops drawn as a tiny sweep, so nineteen preset chips
/// can be told apart at a glance.
class _PaletteDot extends StatelessWidget {
  const _PaletteDot({required this.colors});

  final BeamColors colors;

  @override
  Widget build(BuildContext context) {
    final palette = colors.resolve();
    final ring = palette.colors.length == 1
        ? [palette.colors.single, palette.colors.single]
        : [...palette.colors, palette.colors.first];
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // −90° so the ring starts at 12 o'clock, where stop 0 sits.
        gradient: SweepGradient(
          colors: ring,
          transform: const GradientRotation(-1.5708),
        ),
      ),
    );
  }
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

const Map<EffectKind, String> _effectHints = {
  EffectKind.rotate:
      'A beam travelling the whole border. Length scales its tail, count '
      'spaces several around the border, and comet trails a glow outside it.',
  EffectKind.line:
      'A streak riding one edge with light spiking up from it — inputs, '
      'search bars, composers.',
  EffectKind.pulse:
      'Colour breathing inward from the whole border, strongest at the '
      'corners — a contained "thinking" state.',
  EffectKind.halo:
      'A halo breathing outward. It paints past the widget\'s bounds, so '
      'leave it room and no tight clip above it.',
  EffectKind.flow:
      'Colours streaming round the border with an inner glow that swells and '
      'ebbs — an assistant-is-listening look.',
  EffectKind.spin:
      'A full gradient ring spinning round the border — the classic animated '
      'gradient border for buttons and badges.',
  EffectKind.shimmer:
      'A glint sweeping across the border at an angle, then resting for the '
      'cycle gap. Calls to action, new items.',
  EffectKind.charge:
      'The border fills clockwise from the top. Turn on Progress in the '
      'Drive section to fill it to a value instead of once per cycle.',
};

const Map<PaletteMode, String> _paletteModeLabels = {
  PaletteMode.custom: 'Custom',
  PaletteMode.seed: 'Seed',
  PaletteMode.lerp: 'Lerp',
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
  BeamHueMode.none: 'None',
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
