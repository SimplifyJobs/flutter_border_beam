/// Animated border beam effects for Flutter.
///
/// Travelling and breathing light around any widget's border — three
/// effects, a gallery of palettes plus your own, superellipse corners,
/// theming, and playback control — drawn by one fragment shader in a single
/// pass, with no offscreen layers or blurs.
library;

export 'src/border_beam/beam_sync.dart' show BeamSync;
export 'src/border_beam/border_beam.dart' show BorderBeam;
export 'src/border_beam/border_beam_controller.dart' show BorderBeamController;
export 'src/border_beam/border_beam_theme.dart'
    show BorderBeamTheme, BorderBeamThemeData;
export 'src/border_beam/effects/beam_effect.dart'
    show BeamEffect, LineEffect, PulseEffect, RotateEffect;
export 'src/border_beam/models/beam_colors.dart'
    show BeamColors, BeamSeedHarmony;
export 'src/border_beam/models/beam_options.dart'
    show BeamDirection, BeamEdge, BeamHueMode, BeamReducedMotion, BeamRepeat;
export 'src/border_beam/models/beam_playback.dart' show BeamPlayback;
export 'src/border_beam/models/beam_segment.dart'
    show BeamAnchor, BeamCorner, BeamSegment;
export 'src/border_beam/models/beam_shape.dart' show BeamShape;
export 'src/border_beam/models/beam_style.dart' show BeamStyle;
export 'src/border_beam/models/beam_theme.dart' show BeamTheme;
export 'src/border_beam/models/beam_timing.dart' show BeamTiming;
export 'src/border_beam/widgets/beam_decoration.dart' show BeamDecoration;
export 'src/border_beam/widgets/beam_focus_ring.dart' show BeamFocusRing;
export 'src/border_beam/widgets/beam_hover.dart' show BeamHover;
export 'src/border_beam/widgets/beam_press.dart' show BeamPress;
