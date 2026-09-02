/// Animated border beam effects for Flutter.
///
/// A faithful port of the border-beam React library: traveling and breathing
/// glow animations around any widget, with rotate, line, and pulse variants,
/// four color presets plus custom palettes, superellipse borders, and an
/// optional playback controller.
library;

export 'src/beam_sync.dart' show BeamSync;
export 'src/border_beam.dart' show BorderBeam;
export 'src/border_beam_controller.dart' show BorderBeamController;
export 'src/border_beam_theme.dart' show BorderBeamTheme, BorderBeamThemeData;
export 'src/models/beam_blob.dart' show BeamBlob, LineBlob;
export 'src/models/beam_colors.dart' show BeamColors, BeamSeedHarmony;
export 'src/models/beam_options.dart'
    show
        BeamContour,
        BeamDirection,
        BeamEdge,
        BeamHueMode,
        BeamPathContour,
        BeamPulseOutsideTuning,
        BeamReducedMotion,
        BeamRepeat;
export 'src/models/beam_playback.dart' show BeamPlayback;
export 'src/models/beam_segment.dart' show BeamAnchor, BeamCorner, BeamSegment;
export 'src/models/beam_shape.dart' show BeamShape;
export 'src/models/beam_style.dart' show BeamStyle;
export 'src/models/beam_theme.dart' show BeamTheme;
export 'src/models/beam_theme_config.dart' show BeamThemeConfig;
export 'src/models/beam_timing.dart' show BeamTiming;
export 'src/models/beam_variant.dart' show BeamVariant;
export 'src/widgets/beam_decoration.dart' show BeamDecoration;
export 'src/widgets/beam_focus_ring.dart' show BeamFocusRing;
export 'src/widgets/beam_hover.dart' show BeamHover;
export 'src/widgets/beam_press.dart' show BeamPress;
