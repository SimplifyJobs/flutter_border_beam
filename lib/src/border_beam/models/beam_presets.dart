import 'dart:ui';

import '../look/extra_palettes.dart';
import '../look/palette_tables.dart';
import 'beam_palette.dart';

// The built-in palettes, each a ring of colour stops around the border:
// position 0 is top-centre and positions increase clockwise by arc length.
//
// The stops of the four originals and the seven that follow them were laid
// out from where their blob tables put each colour on a 350 × 140 card; the
// blob tables themselves (`lib/src/look/`) are what the effects draw with.
// The palettes new in 0.2 have stops only, and are drawn by sampling them
// into `colorful`'s blob geometry. Every preset reads as light on both dark
// and light surfaces.

// ─── Originals ──────────────────────────────────────────────────────────────

/// `BeamColors.colorful`: orange, magenta, violet, blue, green, and a hot
/// pink across the top — the full spectrum.
const BeamPalette colorfulPalette = BeamPalette(
  colors: [
    Color(0xFFFF7828), // orange
    Color(0xFFC82BDF), // magenta
    Color(0xFF6446FF), // violet
    Color(0xFF288CFF), // blue
    Color(0xFF2FC568), // green
    Color(0xFF288CFF), // blue
    Color(0xFFFF3264), // hot pink
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  tables: colorfulTables,
);

/// `BeamColors.mono`: whites and greys, with a fixed hue.
const BeamPalette monoPalette = BeamPalette(
  colors: [
    Color(0xFFF0F0F0), // near white
    Color(0xFF9E9E9E), // mid grey
    Color(0xFFD2D2D2), // light grey
    Color(0xFFB0B0B0), // grey
  ],
  stops: [0.161, 0.410, 0.723, 0.938],
  fixedHue: true,
  tables: monoTables,
  mono: true,
);

/// `BeamColors.ocean`: blues and violets.
const BeamPalette oceanPalette = BeamPalette(
  colors: [
    Color(0xFF8C64F0), // lavender
    Color(0xFF7754F8), // violet
    Color(0xFF7850FF), // violet
    Color(0xFF4682FF), // azure
    Color(0xFF4B6DCC), // slate blue
    Color(0xFF3C78FF), // blue
    Color(0xFF6450DC), // indigo
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  tables: oceanTables,
);

/// `BeamColors.sunset`: reds, oranges, and amber.
const BeamPalette sunsetPalette = BeamPalette(
  colors: [
    Color(0xFFFF3C3C), // red
    Color(0xFFFF6C41), // vermilion
    Color(0xFFFF6450), // coral
    Color(0xFFFFB43C), // amber
    Color(0xFFFF8C3A), // orange
    Color(0xFFFFA028), // tangerine
    Color(0xFFFF5032), // scarlet
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  tables: sunsetTables,
);

// ─── Extras ─────────────────────────────────────────────────────────────────

/// `BeamColors.aurora`: teal, violet, and green — the northern lights.
const BeamPalette auroraPalette = BeamPalette(
  colors: [
    Color(0xFF35E08A), // green
    Color(0xFF25CFCD), // glacier teal
    Color(0xFF1FD9C0), // teal
    Color(0xFF7A5CFF), // violet
    Color(0xFF34D8A1), // sea green
    Color(0xFF7A5CFF), // violet
    Color(0xFF1FD9C0), // teal
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  tableColors: auroraColors,
);

/// `BeamColors.neon`: fully saturated magenta, lime, and cyan.
const BeamPalette neonPalette = BeamPalette(
  colors: [
    Color(0xFFFF00C8), // magenta
    Color(0xFFB6FF00), // lime
    Color(0xFF00F0FF), // cyan
    Color(0xFFB6FF00), // lime
    Color(0xFF00F0FF), // cyan
    Color(0xFFFF00C8), // magenta
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.860, 0.938],
  tableColors: neonColors,
);

/// `BeamColors.candy`: pastel pink, lavender, and peach.
const BeamPalette candyPalette = BeamPalette(
  colors: [
    Color(0xFFFF9EC4), // pink
    Color(0xFFEFBFBF), // blush
    Color(0xFFC5B3FF), // lavender
    Color(0xFFFFC49B), // peach
    Color(0xFFFFBDA4), // apricot
    Color(0xFFC5B3FF), // lavender
    Color(0xFFFF9EC4), // pink
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  tableColors: candyColors,
);

/// `BeamColors.ember`: deep red, orange, and gold.
const BeamPalette emberPalette = BeamPalette(
  colors: [
    Color(0xFFC1121F), // deep red
    Color(0xFFFFAC2D), // amber
    Color(0xFFFF6B1A), // orange
    Color(0xFFFFC233), // gold
    Color(0xFFF4AE30), // amber
    Color(0xFFFF6B1A), // orange
    Color(0xFFC1121F), // deep red
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  tableColors: emberColors,
);

/// `BeamColors.ice`: pale blue, white, and cyan.
const BeamPalette icePalette = BeamPalette(
  colors: [
    Color(0xFFBFE9FF), // pale blue
    Color(0xFFA3EBFF), // frost
    Color(0xFFFFFFFF), // white
    Color(0xFF63E2FF), // cyan
    Color(0xFF7BE3FF), // light cyan
    Color(0xFFFFFFFF), // white
    Color(0xFFBFE9FF), // pale blue
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  tableColors: iceColors,
);

/// `BeamColors.gold`: amber, gold, and bronze, with a fixed hue.
const BeamPalette goldPalette = BeamPalette(
  colors: [
    Color(0xFFFFC24B), // amber
    Color(0xFFBE8529), // old gold
    Color(0xFFE8A317), // gold
    Color(0xFFA9762F), // bronze
    Color(0xFFBD8936), // old gold
    Color(0xFFE8A317), // gold
    Color(0xFFFFC24B), // amber
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  fixedHue: true,
  tableColors: goldColors,
);

/// `BeamColors.holographic`: desaturated pastels built for a hue sweep.
const BeamPalette holographicPalette = BeamPalette(
  colors: [
    Color(0xFFB8E6FF), // sky
    Color(0xFFDAF0E1), // mint
    Color(0xFFFFE9B8), // cream
    Color(0xFFC9B8FF), // lilac
    Color(0xFFF5D4E3), // blush
    Color(0xFFB8E6FF), // sky
    Color(0xFFC9B8FF), // lilac
  ],
  stops: [0.161, 0.216, 0.410, 0.482, 0.723, 0.860, 0.938],
  tableColors: holographicColors,
);

// ─── New in 0.2 ─────────────────────────────────────────────────────────────

/// `BeamColors.lagoon`: teal, aqua, and mint — shallow tropical water.
const BeamPalette lagoonPalette = BeamPalette(
  colors: [
    Color(0xFF00C2A8), // teal
    Color(0xFF2BD9F0), // aqua
    Color(0xFF7CF5C8), // mint
    Color(0xFF0FA3C2), // deep aqua
  ],
  stops: [0.08, 0.32, 0.58, 0.82],
);

/// `BeamColors.dusk`: indigo, violet, and rose — the sky after sundown.
const BeamPalette duskPalette = BeamPalette(
  colors: [
    Color(0xFF5B5BF0), // indigo
    Color(0xFF9B5CF6), // violet
    Color(0xFFF0628F), // rose
    Color(0xFFB45CE6), // orchid
  ],
  stops: [0.12, 0.36, 0.60, 0.84],
);

/// `BeamColors.forest`: emerald, lime, and teal.
const BeamPalette forestPalette = BeamPalette(
  colors: [
    Color(0xFF12C27E), // emerald
    Color(0xFF8BD61C), // lime
    Color(0xFF17B8A6), // teal
    Color(0xFF3DDC6B), // leaf green
  ],
  stops: [0.10, 0.34, 0.60, 0.82],
);

/// `BeamColors.rose`: pink, coral, and mauve.
const BeamPalette rosePalette = BeamPalette(
  colors: [
    Color(0xFFFF6FB0), // pink
    Color(0xFFFF7F66), // coral
    Color(0xFFC77DC4), // mauve
    Color(0xFFFF5C8D), // rose
  ],
  stops: [0.14, 0.40, 0.66, 0.88],
);

/// `BeamColors.cosmic`: deep violet, electric blue, and magenta.
const BeamPalette cosmicPalette = BeamPalette(
  colors: [
    Color(0xFF6B2BFF), // deep violet
    Color(0xFF2D6BFF), // electric blue
    Color(0xFF33A1FF), // bright blue
    Color(0xFFF02BD9), // magenta
    Color(0xFFA235F5), // purple
  ],
  stops: [0.06, 0.30, 0.52, 0.74, 0.92],
);

/// `BeamColors.citrus`: lime, yellow, and tangerine.
const BeamPalette citrusPalette = BeamPalette(
  colors: [
    Color(0xFF9EE021), // lime
    Color(0xFFFFD000), // lemon
    Color(0xFFFF8A1C), // tangerine
    Color(0xFFFFB81F), // amber
  ],
  stops: [0.10, 0.36, 0.62, 0.86],
);

/// `BeamColors.sky`: cerulean, periwinkle, and a white-blue.
const BeamPalette skyPalette = BeamPalette(
  colors: [
    Color(0xFF1E9BFF), // cerulean
    Color(0xFF8C9EFF), // periwinkle
    Color(0xFFC6E4FF), // white-blue
    Color(0xFF3FC3FF), // sky blue
  ],
  stops: [0.12, 0.38, 0.62, 0.84],
);

/// `BeamColors.lavender`: lilac, lavender, and a soft pink.
const BeamPalette lavenderPalette = BeamPalette(
  colors: [
    Color(0xFFC48DFF), // lilac
    Color(0xFFA594FF), // lavender
    Color(0xFFFFA6D5), // soft pink
    Color(0xFFD69CFF), // orchid
  ],
  stops: [0.14, 0.40, 0.64, 0.86],
);
