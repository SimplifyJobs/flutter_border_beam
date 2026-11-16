import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../border_beam/render/beam_outline.dart';
import '../../core/oklab.dart';
import '../models/wave_palette.dart';
import '../models/wave_spec.dart';
import '../timeline/wave_frame.dart';
import '../timeline/wave_rim.dart';

/// Floats in the wave shaders' uniform block (`shaders/common/wave_uniforms.glsl`).
const int waveUniformFloats = 120;

/// Palette slots in the uniform block (`uStops`).
const int wavePaletteSlots = maxWavePaletteColors;

/// The near blur level, pt: the first blurred copy of each side, which takes
/// over from the sharp side as the blur radius grows to it. The far copy has
/// the spec's full blur.
const double waveNearBlur = 7;

/// The uniform buffer of the wave shaders, in the order the shaders declare
/// it, with one writer per part. Both `wave.frag` and `wave_glow.frag` read
/// the same block, so one buffer feeds either.
///
/// Reused frame to frame: the stage and the spec are written only when they
/// change, the frame and the rim's lumps every frame.
final class WaveFrameData {
  /// The floats, in shader order.
  final Float32List data = Float32List(waveUniformFloats);

  // Offsets, in floats, of each uniform.
  static const int _rect = 0;
  static const int _view = 4;
  static const int _quads = 8;
  static const int _front0 = 12;
  static const int _front1 = 16;
  static const int _front2 = 20;
  static const int _front3 = 24;
  static const int _front4 = 28;
  static const int _lens = 32;
  static const int _blur = 36;
  static const int _band = 40;
  static const int _rim = 44;
  static const int _hair = 48;
  static const int _stops = 52;
  static const int _fringe = _stops + wavePaletteSlots * 4;
  static const int _lumps = _fringe + 8;

  final Float32List _lumpScratch = Float32List(WaveRim.count * 3);

  void _v4(int at, double x, double y, double z, double w) {
    data[at] = x;
    data[at + 1] = y;
    data[at + 2] = z;
    data[at + 3] = w;
  }

  /// The stage: where it sits in the canvas, the size of a device pixel in
  /// logical pixels, whether to dither, and the outline its edges follow.
  void setStage(
    ui.Rect rect,
    double px,
    BeamOutline outline, {
    bool dither = true,
  }) {
    _v4(_rect, rect.left, rect.top, rect.width, rect.height);
    _v4(_view, px, dither ? 1 : 0, outline.length, 0);
    _v4(
      _quads,
      outline.quadStarts[0],
      outline.quadStarts[1],
      outline.quadStarts[2],
      outline.quadStarts[3],
    );
  }

  /// The settled look: lens, blur levels, band, rim, hairline and palette.
  void setSpec(WaveSpec spec) {
    _v4(_lens, spec.amplitude, spec.lensWidth, spec.aberration, spec.blur);
    final near = math.min(waveNearBlur, spec.blur);
    _v4(_blur, spec.blurAhead, spec.blurBehind, near, spec.blur);
    _v4(_band, spec.lead, spec.tail, spec.strength, spec.cornerRadius);
    _v4(
      _rim,
      spec.rimWidth,
      spec.rimSoftness,
      spec.rimUnevenness,
      spec.rimPulse,
    );
    final palette = spec.palette;
    final colors = palette.colors.isEmpty
        ? [palette.ahead]
        : palette.colors.take(wavePaletteSlots).toList();
    _v4(
      _hair,
      spec.hairlineWidth,
      spec.hairlineOpacity,
      spec.hairlineWhite,
      colors.length.toDouble(),
    );
    for (var i = 0; i < wavePaletteSlots; i++) {
      final lab = Oklab.fromColor(colors[i % colors.length]);
      _v4(_stops + i * 4, lab.l, lab.a, lab.b, 0);
    }
    final ahead = Oklab.fromColor(palette.ahead);
    final behind = Oklab.fromColor(palette.behind);
    _v4(_fringe, ahead.l, ahead.a, ahead.b, 0);
    _v4(_fringe + 4, behind.l, behind.a, behind.b, 0);
  }

  /// Where the wave is: its front, strengths, wipes, and which sides show.
  void setFrame(WaveFrame frame) {
    _v4(_front0, frame.origin.dx, frame.origin.dy, frame.spine, frame.radius);
    _v4(_front1, frame.squash, frame.time, frame.swell, frame.tilt);
    _v4(_front2, frame.energy, frame.gravity, frame.glow, frame.rim);
    _v4(
      _front3,
      frame.clearRadius,
      frame.hairClearRadius,
      frame.ring ? 1 : 0,
      frame.hold,
    );
    _v4(
      _front4,
      frame.launched ? 1 : 0,
      frame.showsOutgoing ? 1 : 0,
      frame.showsIncoming ? 1 : 0,
      0,
    );
  }

  /// The rim's lumps at [time], round a perimeter of [perimeter].
  void setLumps({
    required double time,
    required double perimeter,
    required double pulse,
  }) {
    WaveRim.lumps(_lumpScratch, time: time, perimeter: perimeter, pulse: pulse);
    for (var i = 0; i < WaveRim.count; i++) {
      _v4(
        _lumps + i * 4,
        _lumpScratch[i * 3],
        math.max(_lumpScratch[i * 3 + 1], 1e-3),
        _lumpScratch[i * 3 + 2],
        0,
      );
    }
  }

  /// Writes every float into [shader].
  void upload(ui.FragmentShader shader) {
    for (var i = 0; i < waveUniformFloats; i++) {
      shader.setFloat(i, data[i]);
    }
  }
}
