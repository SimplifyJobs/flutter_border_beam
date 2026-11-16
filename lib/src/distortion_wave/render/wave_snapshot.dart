import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Pixels per logical pixel of the near-blurred copy of a side.
const double _nearScale = 1;

/// Pixels per logical pixel of the far-blurred copy of a side.
const double _farScale = 0.5;

/// One side of the wave as GPU images: [sharp] at the device pixel ratio,
/// and two blurred copies baked from it at lower resolution, [near] and
/// [far]. The wave shader mixes the three by the blur radius each pixel
/// should have.
///
/// Owned by the stage that took it; [dispose] releases every image.
final class WaveSideImages {
  /// Takes a picture of [side] at [pixelRatio]: paints it into a detached
  /// layer and rasterises that, as `SnapshotWidget` does. Returns null when
  /// the side cannot be rasterised (it holds a platform view).
  static WaveSideImages? take(RenderBox side, double pixelRatio) {
    final size = side.size;
    if (size.isEmpty) return null;
    final layer = OffsetLayer();
    final context = _SnapshotContext(layer, Offset.zero & size);
    context.paintChild(side, Offset.zero);
    context.finish();
    if (!layer.supportsRasterization()) {
      layer.dispose();
      return null;
    }
    final image = layer.toImageSync(Offset.zero & size, pixelRatio: pixelRatio);
    layer.dispose();
    return WaveSideImages._(image, size);
  }

  WaveSideImages._(this.sharp, this.size);

  /// The side as it is, at the device pixel ratio.
  final ui.Image sharp;

  /// The side's logical size.
  final Size size;

  ui.Image? _near;
  ui.Image? _far;
  double? _nearSigma;
  double? _farSigma;

  /// The near-blurred copy, if baked.
  ui.Image? get near => _near;

  /// The far-blurred copy, if baked.
  ui.Image? get far => _far;

  /// Whether both blurred copies are baked, at these blurs.
  bool hasBlurs(double nearSigma, double farSigma) =>
      _near != null && _nearSigma == nearSigma && _farSigma == farSigma;

  /// Bakes the two blurred copies from [sharp], blurred by [nearSigma] and
  /// [farSigma] logical pixels: two small offscreen renders, once per
  /// picture of the side.
  void bakeBlurs(double nearSigma, double farSigma) {
    if (hasBlurs(nearSigma, farSigma)) return;
    _disposeBlurs();
    _near = _blurred(nearSigma, _nearScale);
    _far = _blurred(farSigma, _farScale);
    _nearSigma = nearSigma;
    _farSigma = farSigma;
  }

  ui.Image _blurred(double sigma, double scale) {
    final width = math.max((size.width * scale).ceil(), 1);
    final height = math.max((size.height * scale).ceil(), 1);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final target = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.low;
    final sigmaPx = sigma * scale;
    if (sigmaPx > 0.1) {
      // Clamped at the edges, so the side's border colours run on rather
      // than fading to transparent.
      paint.imageFilter = ui.ImageFilter.blur(
        sigmaX: sigmaPx,
        sigmaY: sigmaPx,
        tileMode: TileMode.clamp,
      );
    }
    canvas.drawImageRect(
      sharp,
      Rect.fromLTWH(0, 0, sharp.width.toDouble(), sharp.height.toDouble()),
      target,
      paint,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  void _disposeBlurs() {
    _near?.dispose();
    _far?.dispose();
    _near = null;
    _far = null;
    _nearSigma = null;
    _farSigma = null;
  }

  /// Releases every image.
  void dispose() {
    _disposeBlurs();
    sharp.dispose();
  }
}

/// A painting context for a detached layer: `PaintingContext`'s constructor
/// and its finishing call are protected, so a subclass reaches them.
final class _SnapshotContext extends PaintingContext {
  _SnapshotContext(super.containerLayer, super.estimatedBounds);

  void finish() => stopRecordingIfNeeded();
}
