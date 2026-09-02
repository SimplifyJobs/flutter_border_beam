import 'package:flutter/material.dart';

import '../demo_theme.dart';

/// A collapsible group of playground controls, headed by a tappable title
/// row in the demo's own typography.
class ControlSection extends StatefulWidget {
  /// Creates a section, open when [initiallyExpanded].
  const ControlSection({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  /// Header label.
  final String title;

  /// Rows revealed while the section is open.
  final List<Widget> children;

  /// Whether the section starts open.
  final bool initiallyExpanded;

  @override
  State<ControlSection> createState() => _ControlSectionState();
}

class _ControlSectionState extends State<ControlSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.heading,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: const Cubic(0.22, 1, 0.36, 1),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: const Cubic(0.22, 1, 0.36, 1),
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// A labelled control row: a fixed-width label and the control beside it,
/// stacking the two on narrow layouts.
class ControlRow extends StatelessWidget {
  /// Creates a row.
  const ControlRow({
    super.key,
    required this.label,
    required this.child,
    this.enabled = true,
  });

  /// Left-hand label.
  final String label;

  /// The control.
  final Widget child;

  /// Whether the control accepts input; a disabled row dims and ignores
  /// pointers.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: IgnorePointer(
          ignoring: !enabled,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labelWidget = Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: t.muted,
                  decoration: TextDecoration.none,
                ),
              );
              if (constraints.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: labelWidget),
                    const SizedBox(height: 2),
                    child,
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(width: 104, child: labelWidget),
                  Expanded(child: child),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The demo's pill control button, used for every toggle and choice.
class DemoChip extends StatelessWidget {
  /// Creates a chip.
  const DemoChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  /// Chip text.
  final String label;

  /// Whether the chip reads as on.
  final bool selected;

  /// Tap callback.
  final VoidCallback onTap;

  /// Optional widget ahead of the label (a color dot, for instance).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: const Cubic(0.22, 1, 0.36, 1),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.btnBgActive : t.btnBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading case final Widget widget) ...[
              widget,
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? t.btnTextActive : t.btnText,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of chips laid out as a wrap, one of which is selected.
class ChipGroup extends StatelessWidget {
  /// Creates a chip group.
  const ChipGroup({super.key, required this.children});

  /// The chips.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 6, children: children);
}

/// The demo's minimal drag track, mapped over an arbitrary range.
class MinimalSlider extends StatelessWidget {
  /// Creates a slider.
  const MinimalSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  /// Current value, clamped into [min]–[max] for display.
  final double value;

  /// Range start.
  final double min;

  /// Range end.
  final double max;

  /// Called with the new value on tap or drag.
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset local) {
          final f = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
          // Two decimals is the resolution the share codec round-trips.
          onChanged(double.parse((min + f * (max - min)).toStringAsFixed(2)));
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
                    widthFactor: fraction,
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

/// A slider row that always carries a value, with the number shown beside
/// the track.
class SliderRow extends StatelessWidget {
  /// Creates the row.
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
    this.enabled = true,
  });

  /// Row label.
  final String label;

  /// Current value.
  final double value;

  /// Range start.
  final double min;

  /// Range end.
  final double max;

  /// Change callback.
  final ValueChanged<double> onChanged;

  /// Unit appended to the readout (`s`, `px`, `°`, `×`).
  final String suffix;

  /// Whether the row accepts input.
  final bool enabled;

  @override
  Widget build(BuildContext context) => ControlRow(
    label: label,
    enabled: enabled,
    child: Row(
      children: [
        Expanded(
          child: MinimalSlider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 10),
        ValueReadout(text: '${formatControlValue(value)}$suffix'),
      ],
    ),
  );
}

/// A slider row whose value may be null, meaning the package resolves it.
///
/// The track sits at [fallback] while the value is null, and an `auto` chip
/// clears it back.
class NullableSliderRow extends StatelessWidget {
  /// Creates the row.
  const NullableSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.fallback,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
    this.enabled = true,
  });

  /// Row label.
  final String label;

  /// Current override, or null for the package default.
  final double? value;

  /// Where the track sits, and what the readout reports, while [value] is
  /// null. Null parks the track at [min] — the package default of that field
  /// is internal to the variant preset.
  final double? fallback;

  /// Range start.
  final double min;

  /// Range end.
  final double max;

  /// Change callback; null clears the override.
  final ValueChanged<double?> onChanged;

  /// Unit appended to the readout.
  final String suffix;

  /// Whether the row accepts input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shown = value ?? fallback ?? min;
    return ControlRow(
      label: label,
      enabled: enabled,
      child: Row(
        children: [
          Expanded(
            child: MinimalSlider(
              value: shown,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
          ValueReadout(
            text: value == null
                ? 'auto'
                : '${formatControlValue(shown)}$suffix',
          ),
          const SizedBox(width: 8),
          DemoChip(
            label: 'auto',
            selected: value == null,
            onTap: () => onChanged(null),
          ),
        ],
      ),
    );
  }
}

/// The fixed-width numeric readout beside a slider.
class ValueReadout extends StatelessWidget {
  /// Creates a readout.
  const ValueReadout({super.key, required this.text});

  /// Formatted value.
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return SizedBox(
      width: 52,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          color: t.muted,
          fontFeatures: const [FontFeature.tabularFigures()],
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// Formats a control value for its readout: `2` rather than `2.00`.
String formatControlValue(double value) {
  final fixed = value.toStringAsFixed(2);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// The install line above the playground: the pub command with the same copy
/// affordance the code panel uses, and a chip carrying the repository link.
class InstallBlock extends StatelessWidget {
  /// Creates the install line.
  const InstallBlock({
    super.key,
    required this.command,
    required this.repoLabel,
    required this.onCopyCommand,
    required this.onCopyRepo,
    required this.copied,
  });

  /// The shell command shown, and copied by the Copy chip.
  final String command;

  /// Label of the repository chip.
  final String repoLabel;

  /// Copies [command].
  final VoidCallback onCopyCommand;

  /// Copies the repository link.
  final VoidCallback onCopyRepo;

  /// Whether either confirmation is showing.
  final bool copied;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            command,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              fontFamily: 'Menlo',
              fontFamilyFallback: const ['Courier New', 'monospace'],
              color: t.codeText,
              decoration: TextDecoration.none,
            ),
          ),
          // A Wrap rather than a Row: the actions break onto their own line
          // on a narrow layout instead of overflowing.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              AnimatedOpacity(
                opacity: copied ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  'Copied',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.muted,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              DemoChip(label: 'Copy', selected: false, onTap: onCopyCommand),
              DemoChip(
                label: repoLabel,
                selected: false,
                onTap: onCopyRepo,
                leading: Icon(Icons.link, size: 14, color: t.btnText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The playground's code panel: the generated snippet plus a
/// copy-to-clipboard action that confirms in place.
class CodeBlock extends StatelessWidget {
  /// Creates the panel.
  const CodeBlock({
    super.key,
    required this.code,
    required this.onCopy,
    required this.copied,
  });

  /// Snippet text.
  final String code;

  /// Copy action.
  final VoidCallback onCopy;

  /// Whether the confirmation is showing.
  final bool copied;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedOpacity(
                opacity: copied ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  'Copied',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.muted,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DemoChip(label: 'Copy', selected: false, onTap: onCopy),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code,
              key: const ValueKey('playground-snippet'),
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                fontFamily: 'Menlo',
                fontFamilyFallback: const ['Courier New', 'monospace'],
                color: t.codeText,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
