/// Animated border beam effects for Flutter.
///
/// Travelling and breathing light around any widget's border — four
/// effects, a gallery of palettes plus your own, superellipse corners,
/// theming, and playback control — drawn by one fragment shader in a single
/// pass, with no offscreen layers or blurs.
library;

export 'src/beam_sync.dart' show BeamSync;
export 'src/border_beam.dart' show BorderBeam;
export 'src/border_beam_controller.dart' show BorderBeamController;
export 'src/border_beam_theme.dart' show BorderBeamTheme, BorderBeamThemeData;
export 'src/effects/beam_effect.dart'
    show BeamEffect, HaloEffect, LineEffect, PulseEffect, RotateEffect;
export 'src/models/beam_colors.dart' show BeamColors, BeamSeedHarmony;
export 'src/models/beam_options.dart'
    show BeamDirection, BeamEdge, BeamHueMode, BeamReducedMotion, BeamRepeat;
export 'src/models/beam_playback.dart' show BeamPlayback;
export 'src/models/beam_segment.dart' show BeamAnchor, BeamCorner, BeamSegment;
export 'src/models/beam_shape.dart' show BeamShape;
export 'src/models/beam_style.dart' show BeamStyle;
export 'src/models/beam_theme.dart' show BeamTheme;
export 'src/models/beam_timing.dart' show BeamTiming;
export 'src/widgets/beam_decoration.dart' show BeamDecoration;
export 'src/widgets/beam_focus_ring.dart' show BeamFocusRing;
export 'src/widgets/beam_hover.dart' show BeamHover;
export 'src/widgets/beam_press.dart' show BeamPress;
