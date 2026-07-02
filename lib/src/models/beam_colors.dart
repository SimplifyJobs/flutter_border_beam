import 'dart:ui';

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
  BeamPalette resolve();
}

class _PresetBeamColors extends BeamColors {
  const _PresetBeamColors(this.preset, {this.isMono = false}) : super._();

  final BeamPresetData preset;
  final bool isMono;

  @override
  BeamPalette resolve() => BeamPalette(
    data: preset,
    forcesStaticColors: isMono,
    opacityMultiplier: isMono ? 0.5 : 1.0,
    monoTreatment: isMono,
  );
}

class _CustomBeamColors extends BeamColors {
  const _CustomBeamColors(this.colors) : super._();

  final List<Color> colors;

  @override
  BeamPalette resolve() {
    assert(colors.isNotEmpty, 'BeamColors.custom requires at least one color');
    Color pick(int i, Color original) {
      final c = colors[i % colors.length];
      // Keep the preset's alpha so inner/bloom layering depth is preserved.
      return c.withValues(alpha: original.a);
    }

    final base = colorfulPreset;
    return BeamPalette(
      data: BeamPresetData(
        border: [
          for (final (i, b) in base.border.indexed)
            b.withColor(pick(i, b.color)),
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
          for (final (i, b) in base.lineDark.indexed)
            b.withColor(pick(i, b.color)),
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
      ),
    );
  }
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
  BeamPalette resolve() {
    assert(border.isNotEmpty, 'BeamColors.spec requires at least one blob');
    // Derive any missing tables by cycling the provided border colors over
    // the default geometry.
    final derived = _CustomBeamColors([
      for (final b in border) b.color,
    ]).resolve().data;
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
}
