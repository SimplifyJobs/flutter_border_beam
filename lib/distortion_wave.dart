/// Distortion waves for Flutter: a colourful refractive wave that opens from
/// the widget that started it and carries one view into another.
///
/// Drawn by one fragment shader from GPU images of the two views: a swell
/// that lifts and bends content, a progressive blur, colour fringing, a band
/// of colour on the front and colour that lingers on the view's edges.
library;

export 'src/distortion_wave/distortion_wave.dart' show DistortionWave;
export 'src/distortion_wave/distortion_wave_controller.dart'
    show DistortionWaveController;
export 'src/distortion_wave/distortion_wave_theme.dart'
    show DistortionWaveTheme, DistortionWaveThemeData;
export 'src/distortion_wave/models/wave_dots.dart' show WaveDots;
export 'src/distortion_wave/models/wave_glow.dart' show WaveGlow;
export 'src/distortion_wave/models/wave_lens.dart' show WaveLens;
export 'src/distortion_wave/models/wave_motion.dart' show WaveMotion;
export 'src/distortion_wave/models/wave_palette.dart'
    show WavePalette, maxWavePaletteColors;
export 'src/distortion_wave/models/wave_snapshots.dart' show WaveSnapshots;
export 'src/distortion_wave/models/wave_style.dart' show WaveStyle;
export 'src/distortion_wave/models/wave_timing.dart' show WaveTiming;
export 'src/distortion_wave/models/wave_type.dart' show WaveType;
export 'src/distortion_wave/wave_source.dart'
    show DistortionWaveAnchor, DistortionWaveAnchorState, WaveSource;
