import 'dart:ui';

// Flutter-only palette additions — NOT transcriptions of the React source.
// The React library ships four presets (colorful, mono, ocean, sunset), which
// live verbatim in `palettes.dart`. The seven below are original to this
// package: each is a short list of source colors that `BeamColors.custom`
// distributes over the `colorful` preset's blob geometry, so every table
// (border, small, line, bloom) keeps the source library's positions, sizes
// and per-entry alpha — only the hues change. Editing a list here changes
// how the matching `BeamColors` preset looks; it does not affect parity with
// the React source.

/// Source colors for `BeamColors.aurora` — a northern-lights sweep from
/// teal through violet to green.
const List<Color> auroraColors = [
  Color(0xFF1FD9C0), // teal
  Color(0xFF7A5CFF), // violet
  Color(0xFF35E08A), // green
  Color(0xFF2FB6E8), // glacier blue
];

/// Source colors for `BeamColors.neon` — fully saturated magenta, cyan and
/// lime, the loudest palette in the set.
const List<Color> neonColors = [
  Color(0xFFFF00C8), // magenta
  Color(0xFF00F0FF), // cyan
  Color(0xFFB6FF00), // lime
];

/// Source colors for `BeamColors.candy` — pastel pink, lavender and peach.
const List<Color> candyColors = [
  Color(0xFFFF9EC4), // pink
  Color(0xFFC5B3FF), // lavender
  Color(0xFFFFC49B), // peach
];

/// Source colors for `BeamColors.ember` — deep red through orange to gold,
/// the hot end of a fire.
const List<Color> emberColors = [
  Color(0xFFC1121F), // deep red
  Color(0xFFFF6B1A), // orange
  Color(0xFFFFC233), // gold
];

/// Source colors for `BeamColors.ice` — pale blue, white and cyan.
const List<Color> iceColors = [
  Color(0xFFBFE9FF), // pale blue
  Color(0xFFFFFFFF), // white
  Color(0xFF63E2FF), // cyan
];

/// Source colors for `BeamColors.gold` — a warm monochrome run from amber
/// through gold to bronze.
const List<Color> goldColors = [
  Color(0xFFFFC24B), // amber
  Color(0xFFE8A317), // gold
  Color(0xFFA9762F), // bronze
];

/// Source colors for `BeamColors.holographic` — desaturated pastels chosen
/// to stay pleasant under a continuous hue drift.
const List<Color> holographicColors = [
  Color(0xFFC9B8FF), // lilac
  Color(0xFFB8E6FF), // sky
  Color(0xFFFFC8E4), // blush
  Color(0xFFC8FFE0), // mint
  Color(0xFFFFE9B8), // cream
];
