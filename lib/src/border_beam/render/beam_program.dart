import '../../core/shader_program.dart';

/// The beam's fragment program, `shaders/beam.frag`, shared by every beam.
///
/// Until it has loaded, beams paint nothing; their fade-in hides the few
/// milliseconds this takes.
final ShaderProgram beamProgram = ShaderProgram('beam');
