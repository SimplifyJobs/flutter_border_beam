import '../../core/shader_program.dart';

/// The beam's fragment program, `shaders/beam.frag`, shared by every beam.
///
/// Until it has loaded, beams paint nothing, and they repaint once it has.
/// A failed load leaves them unpainted; the next load — a new beam, or
/// `BorderBeam.precache()` — tries again.
final ShaderProgram beamProgram = ShaderProgram('beam');
