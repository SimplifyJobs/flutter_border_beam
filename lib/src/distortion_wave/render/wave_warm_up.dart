import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../border_beam/render/beam_outline.dart';
import '../models/wave_spec.dart';
import '../timeline/wave_frame.dart';
import 'wave_frame_data.dart';
import 'wave_programs.dart';

/// Draws everything a wave draws — both shaders, a blurred bake and an atlas
/// of dots — once, into a tiny offscreen image, so the GPU builds their
/// pipelines before the first wave rather than on its first frames.
///
/// Does nothing until both wave programs have loaded. Cheap: a few draws into
/// a 4 × 4 image, released at once.
void warmUpWaveRendering() {
  final wave = waveProgram.program;
  final glow = waveGlowProgram.program;
  if (wave == null || glow == null) return;

  const side = 4;
  const area = Rect.fromLTWH(0, 0, 4, 4);
  final seed = ui.PictureRecorder();
  Canvas(seed).drawRect(area, Paint()..color = const Color(0xFF808080));
  final seedPicture = seed.endRecording();
  final image = seedPicture.toImageSync(side, side);
  seedPicture.dispose();

  final spec = WaveSpec.resolve(null);
  final frame = WaveFrame.at(
    progress: 0.2,
    source: const Rect.fromLTWH(0, 3, 4, 1),
    size: area.size,
    spec: spec,
  );
  final outline = BeamOutline(
    area,
    BorderRadius.circular(spec.cornerRadius),
    superellipse: true,
  );
  final data = WaveFrameData()
    ..setSpec(spec)
    ..setStage(area, 1, outline)
    ..setFrame(frame)
    ..setLumps(time: 0, perimeter: outline.length, pulse: spec.rimPulse);

  final waveShader = wave.fragmentShader();
  data.upload(waveShader);
  for (var i = 0; i < 6; i++) {
    waveShader.setImageSampler(i, image, filterQuality: FilterQuality.low);
  }
  final glowShader = glow.fragmentShader();
  data.upload(glowShader);

  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawImageRect(
      image,
      area,
      area,
      Paint()
        ..filterQuality = FilterQuality.low
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: 1,
          sigmaY: 1,
          tileMode: TileMode.clamp,
        ),
    )
    ..drawRect(area, Paint()..shader = waveShader)
    ..drawRect(area, Paint()..shader = glowShader)
    ..drawRawAtlas(
      image,
      Float32List.fromList([1, 0, 0, 0]),
      Float32List.fromList([0, 0, 4, 4]),
      Int32List.fromList([0x80FFFFFF]),
      BlendMode.modulate,
      null,
      Paint()..filterQuality = FilterQuality.low,
    );
  final picture = recorder.endRecording();
  picture.toImageSync(side, side).dispose();
  picture.dispose();
  waveShader.dispose();
  glowShader.dispose();
  image.dispose();
}
