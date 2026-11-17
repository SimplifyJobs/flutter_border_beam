import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../timeline/wave_frame.dart';
import '../timeline/wave_particles.dart';

/// Draws a wave's dots in one `drawRawAtlas` call: every dot is the same
/// anti-aliased white disc, scaled to its size and faded to its opacity.
///
/// The disc is rendered once per size in device pixels and kept until the
/// size changes or the atlas is disposed — a few hundred bytes, owned by the
/// wave that draws it, so nothing outlives the wave.
final class DotAtlas {
  Float32List _transforms = Float32List(0);
  Float32List _rects = Float32List(0);
  Int32List _colors = Int32List(0);
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  ui.Image? _spriteImage;
  int _spriteDiameter = 0;

  /// The disc for dots up to [diameterPx] device pixels across: a white
  /// circle with a one-pixel soft edge, in a square with a pixel of margin.
  ui.Image _sprite(int diameterPx) {
    final cached = _spriteImage;
    if (cached != null && _spriteDiameter == diameterPx) return cached;
    cached?.dispose();
    final side = diameterPx + 2;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawCircle(
      Offset(side / 2, side / 2),
      diameterPx / 2,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..isAntiAlias = true,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(side, side);
    picture.dispose();
    _spriteDiameter = diameterPx;
    return _spriteImage = image;
  }

  /// Releases the disc. The atlas can still paint afterwards; it renders the
  /// disc again.
  void dispose() {
    _spriteImage?.dispose();
    _spriteImage = null;
  }

  /// Draws [dots] as they are on [frame], for a wave from [source], into
  /// [canvas] at [offset]. Draws nothing when no dot is visible.
  void paint(
    Canvas canvas,
    Offset offset,
    List<WaveParticle> dots,
    WaveFrame frame,
    Rect source, {
    required double devicePixelRatio,
    required double largest,
  }) {
    if (dots.isEmpty || largest <= 0) return;
    final diameterPx = math.max((largest * devicePixelRatio).ceil(), 2);
    final sprite = _sprite(diameterPx);
    final spriteSide = sprite.width.toDouble();
    final anchor = spriteSide / 2;

    if (_transforms.length < dots.length * 4) {
      _transforms = Float32List(dots.length * 4);
      _rects = Float32List(dots.length * 4);
      _colors = Int32List(dots.length);
    }
    var n = 0;
    for (final dot in dots) {
      final opacity = dot.opacityOn(frame).clamp(0.0, 1.0);
      if (opacity <= 0.004) continue;
      final centre = offset + dot.pointOn(frame, source);
      // Sprite pixels to logical pixels, so the disc is this dot's size.
      final scale = dot.size / diameterPx;
      _transforms[n * 4] = scale;
      _transforms[n * 4 + 1] = 0;
      _transforms[n * 4 + 2] = centre.dx - anchor * scale;
      _transforms[n * 4 + 3] = centre.dy - anchor * scale;
      // White at the dot's opacity, modulating the sprite.
      _colors[n] = ((opacity * 255).round() << 24) | 0x00FFFFFF;
      _rects[n * 4] = 0;
      _rects[n * 4 + 1] = 0;
      _rects[n * 4 + 2] = spriteSide;
      _rects[n * 4 + 3] = spriteSide;
      n++;
    }
    if (n == 0) return;
    canvas.drawRawAtlas(
      sprite,
      Float32List.sublistView(_transforms, 0, n * 4),
      Float32List.sublistView(_rects, 0, n * 4),
      Int32List.sublistView(_colors, 0, n),
      BlendMode.modulate,
      null,
      _paint,
    );
  }
}
