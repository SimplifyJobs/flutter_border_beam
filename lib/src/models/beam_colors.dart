import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../constants/palettes.dart';
import 'beam_blob.dart';
import 'beam_palette.dart';

/// The color scheme of a beam.
///
/// Use one of the four presets ported from the React library:
///
/// ```dart
/// BorderBeam.rotate(colors: BeamColors.ocean, child: card)
/// ```
///
/// or bring your own colors — [BeamColors.custom] distributes them over the
/// preset blob geometry so the effect keeps its organic look:
///
/// ```dart
/// BorderBeam.rotate(
///   colors: BeamColors.custom([Colors.pink, Colors.cyan, Colors.amber]),
///   child: card,
/// )
/// ```
///
/// For pixel-level control, [BeamColors.spec] accepts explicit blob tables.
///
/// Every variant is a value type: two instances built from equal inputs are
/// `==`, so rebuilding `BeamColors.custom([...])` inline in a `build` method
/// does not force the widget to re-resolve its gradient tables.
@immutable
sealed class BeamColors {
  const BeamColors._();

  /// Rainbow spectrum. The default.
  static const BeamColors colorful = _PresetBeamColors(colorfulPreset);

  /// Grayscale. Hue animation is disabled and layer opacity halved, matching
  /// the source library's mono treatment.
  static const BeamColors mono = _PresetBeamColors(monoPreset, isMono: true);

  /// Blue and purple tones.
  static const BeamColors ocean = _PresetBeamColors(oceanPreset);

  /// Warm orange, yellow, and red tones.
  static const BeamColors sunset = _PresetBeamColors(sunsetPreset);

  /// Distributes [colors] over the default preset's blob geometry (cycling
  /// when fewer colors than blob slots are given).
  ///
  /// The list must not be empty. Alpha channels of the preset tables (inner
  /// glows, bloom spikes) are preserved and applied to your colors, so the
  /// layered depth of the effect is kept.
  const factory BeamColors.custom(List<Color> colors) = _CustomBeamColors;

  /// Advanced: full per-blob control.
  ///
  /// [border] replaces the 9-blob border table (any length ≥ 1) used by the
  /// rotate stroke and as the pulse color source. Tables not provided
  /// ([smallBorder], [lineBlobs]) are derived by cycling the border colors
  /// over the default geometry.
  const factory BeamColors.spec({
    required List<BeamBlob> border,
    List<BeamBlob>? smallBorder,
    List<LineBlob>? lineBlobs,
  }) = _SpecBeamColors;

  /// Resolves this color choice to concrete gradient tables.
  ///
  /// The result is memoized per instance: repeated calls on the same
  /// instance return the identical [BeamPalette].
  BeamPalette resolve() => _paletteCache[this] ??= _buildPalette();

  /// Builds the palette. Called at most once per instance by [resolve].
  BeamPalette _buildPalette();
}

// Per-instance memo for [BeamColors.resolve]. An Expando (rather than a
// field) so that const instances — the presets, and any `const
// BeamColors.custom([...])` — can cache too.
final Expando<BeamPalette> _paletteCache = Expando<BeamPalette>(
  'BeamColors.resolve',
);

/// Distributes [colors] over [base]'s blob geometry, cycling when there are
/// fewer colors than blob slots and preserving each table entry's alpha so
/// the layered depth of the effect survives the substitution.
BeamPresetData _distribute(List<Color> colors, BeamPresetData base) {
  Color pick(int i, Color original) {
    final c = colors[i % colors.length];
    // Keep the preset's alpha so inner/bloom layering depth is preserved.
    return c.withValues(alpha: original.a);
  }

  return BeamPresetData(
    border: [
      for (final (i, b) in base.border.indexed) b.withColor(pick(i, b.color)),
    ],
    spike: SpikeColors(
      primary: pick(0, base.spike.primary),
      secondary: pick(1, base.spike.secondary),
    ),
    spikeLt: SpikeColors(
      primary: pick(0, base.spikeLt.primary),
      secondary: pick(1, base.spikeLt.secondary),
    ),
    smallBorder: [
      for (final (i, b) in base.smallBorder.indexed)
        b.withColor(pick(i, b.color)),
    ],
    smallInner: [
      for (final (i, b) in base.smallInner.indexed)
        b.withColor(pick(i, b.color)),
    ],
    lineDark: [
      for (final (i, b) in base.lineDark.indexed) b.withColor(pick(i, b.color)),
    ],
    lineLight: [
      for (final (i, b) in base.lineLight.indexed)
        b.withColor(pick(i, b.color)),
    ],
    lineInner: [
      for (final (i, b) in base.lineInner.indexed)
        b.withColor(pick(i, b.color)),
    ],
    lineBloomDark: [
      for (final (i, s) in base.lineBloomDark.indexed)
        SpikePair(pick(i, s.color1), pick(i, s.color2)),
    ],
    lineBloomLight: [
      for (final (i, s) in base.lineBloomLight.indexed)
        SpikePair(pick(i, s.color1), pick(i, s.color2)),
    ],
  );
}

class _PresetBeamColors extends BeamColors {
  const _PresetBeamColors(this.preset, {this.isMono = false}) : super._();

  final BeamPresetData preset;
  final bool isMono;

  @override
  BeamPalette _buildPalette() => BeamPalette(
    data: preset,
    forcesStaticColors: isMono,
    opacityMultiplier: isMono ? 0.5 : 1.0,
    monoTreatment: isMono,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PresetBeamColors &&
          identical(other.preset, preset) &&
          other.isMono == isMono;

  @override
  int get hashCode => Object.hash(identityHashCode(preset), isMono);

  @override
  String toString() => 'BeamColors(preset, isMono: $isMono)';
}

class _CustomBeamColors extends BeamColors {
  const _CustomBeamColors(this.colors) : super._();

  final List<Color> colors;

  @override
  BeamPalette _buildPalette() {
    assert(colors.isNotEmpty, 'BeamColors.custom requires at least one color');
    return BeamPalette(data: _distribute(colors, colorfulPreset));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CustomBeamColors && listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hashAll(colors);

  @override
  String toString() => 'BeamColors.custom($colors)';
}

class _SpecBeamColors extends BeamColors {
  const _SpecBeamColors({
    required this.border,
    this.smallBorder,
    this.lineBlobs,
  }) : super._();

  final List<BeamBlob> border;
  final List<BeamBlob>? smallBorder;
  final List<LineBlob>? lineBlobs;

  @override
  BeamPalette _buildPalette() {
    assert(border.isNotEmpty, 'BeamColors.spec requires at least one blob');
    // Derive any missing tables by cycling the provided border colors over
    // the default geometry.
    final derived = _distribute([
      for (final b in border) b.color,
    ], colorfulPreset);
    return BeamPalette(
      data: BeamPresetData(
        border: border,
        spike: derived.spike,
        spikeLt: derived.spikeLt,
        smallBorder: smallBorder ?? derived.smallBorder,
        smallInner: smallBorder != null
            ? [
                for (final b in smallBorder!)
                  b.withColor(b.color.withValues(alpha: b.color.a * 0.45)),
              ]
            : derived.smallInner,
        lineDark: lineBlobs ?? derived.lineDark,
        lineLight: lineBlobs ?? derived.lineLight,
        lineInner: derived.lineInner,
        lineBloomDark: derived.lineBloomDark,
        lineBloomLight: derived.lineBloomLight,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SpecBeamColors &&
          listEquals(other.border, border) &&
          listEquals(other.smallBorder, smallBorder) &&
          listEquals(other.lineBlobs, lineBlobs);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(border),
    smallBorder == null ? null : Object.hashAll(smallBorder!),
    lineBlobs == null ? null : Object.hashAll(lineBlobs!),
  );

  @override
  String toString() =>
      'BeamColors.spec(border: ${border.length} blobs, '
      'smallBorder: ${smallBorder?.length}, lineBlobs: ${lineBlobs?.length})';
}
