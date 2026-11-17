import '../../core/shader_program.dart';

/// The wave's main program, `shaders/wave.frag`: lens, blur, crossfade,
/// fringing and colour in one pass over both sides' images.
final ShaderProgram waveProgram = ShaderProgram('wave');

/// The wave's colour-only program, `shaders/wave_glow.frag`: the band, rim
/// and hairline drawn over the revealed side once it is no longer bent.
final ShaderProgram waveGlowProgram = ShaderProgram('wave_glow');

/// Loads both wave programs; completes when both are available (or failed).
Future<void> loadWavePrograms() =>
    Future.wait([waveProgram.load(), waveGlowProgram.load()]);
