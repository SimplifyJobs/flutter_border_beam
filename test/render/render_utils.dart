import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/models/beam_config.dart';
import 'package:flutter_border_beam/src/render/beam_frame.dart';
import 'package:flutter_border_beam/src/render/beam_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The box most render tests light: the card proportions the goldens use.
const Size cardSize = Size(350, 140);

/// Room left around the box in rendered images, enough for the widest outward
/// light (a rotate comet's trail). [renderFrame] fails a frame that draws
/// past it rather than reading back a cropped one.
const double renderMargin = 80;

/// Every effect, by name, with its default parameters.
final Map<String, BeamEffect> effectsByName = {
  for (final effect in BeamEffect.values) effect.name: effect,
};

/// A palette subset that covers the stop-count extremes — the default, a
/// fixed-hue preset, one stop, and the full eight — and every way
/// `BeamLook.tablesFor` finds a palette's tables: its own (`colorful`,
/// `mono`), an extra preset's colours cycled over colorful's (`aurora`),
/// tables sampled from the stops (`solid`, `eight`), and a preset's own
/// tables scaled (`ocean ×0.5`).
final Map<String, BeamColors> paletteSubset = {
  'colorful': BeamColors.colorful,
  'mono': BeamColors.mono,
  'aurora': BeamColors.aurora,
  'ocean ×0.5': BeamColors.ocean.scaleAlpha(0.5),
  'solid': const BeamColors.solid(Color(0xFFFF0080)),
  'eight': const BeamColors([
    Color(0xFFFF0000),
    Color(0xFFFF8000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFF8000FF),
    Color(0xFFFF00FF),
  ]),
};

/// The shape families every renderer path must handle.
final Map<String, BeamShape> shapeVariety = {
  'rrect': const BeamShape(),
  'superellipse': const BeamShape.all(24, superellipse: true),
  'stadium': const BeamShape.stadium(),
  'per-corner': const BeamShape(
    radius: BorderRadius.only(
      topLeft: Radius.circular(40),
      bottomRight: Radius.circular(8),
    ),
  ),
  'segment': const BeamShape(segment: BeamSegment.bottomHalf),
  'dashes': const BeamShape(dashes: 12),
  'ringOffset +8': const BeamShape(ringOffset: 8),
  'ringOffset -6': const BeamShape(ringOffset: -6),
  'thick border': const BeamShape(borderWidth: 4),
};

/// Resolves a config the way a mounted beam does, from the merged value
/// objects.
BeamConfig configFor(
  BeamEffect effect, {
  ui.Brightness brightness = ui.Brightness.dark,
  BeamColors colors = BeamColors.colorful,
  BeamStyle style = const BeamStyle(),
  BeamShape shape = const BeamShape(),
  BeamTiming timing = const BeamTiming(),
}) => BeamConfig.resolve(
  effect: effect,
  palette: (style.colors ?? colors).resolve(),
  brightness: brightness,
  style: style,
  shape: shape,
  timing: timing,
);

/// An instant at which [effect] (with default timing) is fully faded in and
/// lit: halfway through its second sweep for a travelling effect, the golden
/// 1.3s for an ambient one. Measured from the effect's own cycle and gap, so
/// a travelling effect is never caught resting between sweeps.
double litSeconds(BeamEffect effect) {
  if (!effect.travels) return 1.3;
  double s(Duration d) => d.inMicroseconds / Duration.microsecondsPerSecond;
  final cycle = s(effect.defaultCycle);
  return cycle + s(effect.defaultCycleGap) + cycle / 2;
}

/// The phases a running beam paints at [seconds], at full fade.
BeamFramePhases phasesAt(
  BeamConfig config,
  double seconds, {
  double? progress,
  double fade = 1,
}) => BeamPhaseResolver(config).sample(seconds, fade, progress: progress);

/// Paints one frame into a [RecordingCanvas] and returns it.
RecordingCanvas recordFrame(
  BeamRenderer renderer,
  BeamConfig config,
  BeamFramePhases phases, {
  Size size = cardSize,
  double devicePixelRatio = 1,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = RecordingCanvas(ui.Canvas(recorder));
  renderer.paint(
    canvas,
    Offset(renderMargin, renderMargin) & size,
    config,
    phases,
    devicePixelRatio: devicePixelRatio,
  );
  recorder.endRecording().dispose();
  return canvas;
}

/// One rendered frame: the box sits [renderMargin] in from the image's
/// top-left corner.
class RenderedFrame {
  RenderedFrame._(this.width, this.height, this.rgba);

  /// Image width in px.
  final int width;

  /// Image height in px.
  final int height;

  /// Premultiplied RGBA bytes, row-major.
  final Uint8List rgba;

  /// The box's bounds within the image.
  Rect boxIn(Size size) => Offset(renderMargin, renderMargin) & size;

  /// The strongest channel at ([x], [y]), 0–255. Light composited with an
  /// additive share can carry colour above its alpha, so this reads both.
  int levelAt(int x, int y) {
    final i = (y * width + x) * 4;
    var level = rgba[i + 3];
    for (var c = 0; c < 3; c++) {
      if (rgba[i + c] > level) level = rgba[i + c];
    }
    return level;
  }

  /// How many pixels inside [region] (clamped to the image) are brighter
  /// than [threshold].
  int litIn(Rect region, {int threshold = 0}) {
    final r = region.intersect(Offset.zero & Size(width * 1.0, height * 1.0));
    if (r.isEmpty) return 0;
    var count = 0;
    for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
      for (var x = r.left.floor(); x < r.right.ceil(); x++) {
        if (levelAt(x, y) > threshold) count++;
      }
    }
    return count;
  }

  /// The summed level of every pixel inside [region].
  int energyIn(Rect region) {
    final r = region.intersect(Offset.zero & Size(width * 1.0, height * 1.0));
    if (r.isEmpty) return 0;
    var sum = 0;
    for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
      for (var x = r.left.floor(); x < r.right.ceil(); x++) {
        sum += levelAt(x, y);
      }
    }
    return sum;
  }

  /// Pixels brighter than [threshold] anywhere in the image.
  int lit({int threshold = 0}) => litIn(
    Offset.zero & Size(width * 1.0, height * 1.0),
    threshold: threshold,
  );
}

/// Renders one frame of [config] at [phases] through a fresh renderer and
/// reads it back. The shader must be loaded (`BorderBeam.precache`).
Future<RenderedFrame> renderFrame(
  BeamConfig config,
  BeamFramePhases phases, {
  Size size = cardSize,
  BeamRenderer? renderer,
}) async {
  final r = renderer ?? BeamRenderer();
  final recorder = ui.PictureRecorder();
  final canvas = RecordingCanvas(ui.Canvas(recorder));
  r.paint(
    canvas,
    Offset(renderMargin, renderMargin) & size,
    config,
    phases,
    devicePixelRatio: 1,
  );
  final picture = recorder.endRecording();
  final width = (size.width + 2 * renderMargin).ceil();
  final height = (size.height + 2 * renderMargin).ceil();
  // The draw covers everywhere light can land, so it must fit the image:
  // light past the margin would be cut off and every region read short.
  for (final bounds in canvas.drawBounds) {
    expect(
      bounds.left >= 0 &&
          bounds.top >= 0 &&
          bounds.right <= width &&
          bounds.bottom <= height,
      isTrue,
      reason: 'the draw $bounds outgrows the ${renderMargin}px margin',
    );
  }
  final image = await picture.toImage(width, height);
  picture.dispose();
  final bytes = await image.toByteData();
  image.dispose();
  if (renderer == null) r.dispose();
  return RenderedFrame._(width, height, bytes!.buffer.asUint8List());
}

/// A [ui.Canvas] that records every call the renderer makes while forwarding
/// it to a real canvas, so the frame is still painted exactly as on screen.
///
/// The calls a beam frame may make are forwarded explicitly; anything else
/// lands in [unforwarded] through `noSuchMethod`, so a new kind of call fails
/// the budget test loudly instead of slipping through uncounted.
class RecordingCanvas implements ui.Canvas {
  /// Wraps `inner`.
  RecordingCanvas(this._inner);

  final ui.Canvas _inner;

  /// Draw calls, by name, in order.
  final List<String> draws = <String>[];

  /// The paint of every draw call, in order.
  final List<ui.Paint> paints = <ui.Paint>[];

  /// The outer bounds of every draw call, in order.
  final List<Rect> drawBounds = <Rect>[];

  /// Plain `save` calls.
  int saves = 0;

  /// `saveLayer` calls — offscreen render targets.
  int saveLayers = 0;

  /// `restore` calls.
  int restores = 0;

  /// `clip*` calls.
  int clips = 0;

  /// Calls not forwarded explicitly.
  final Set<String> unforwarded = <String>{};

  @override
  Float64List getTransform() => _inner.getTransform();

  @override
  void save() {
    saves++;
    _inner.save();
  }

  @override
  void saveLayer(Rect? bounds, ui.Paint paint) {
    saveLayers++;
    _inner.saveLayer(bounds, paint);
  }

  @override
  void restore() {
    restores++;
    _inner.restore();
  }

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    clips++;
    _inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    clips++;
    _inner.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    clips++;
    _inner.clipPath(path, doAntiAlias: doAntiAlias);
  }

  @override
  void drawRect(Rect rect, ui.Paint paint) {
    _record('drawRect', rect, paint);
    _inner.drawRect(rect, paint);
  }

  @override
  void drawDRRect(RRect outer, RRect inner, ui.Paint paint) {
    _record('drawDRRect', outer.outerRect, paint);
    _inner.drawDRRect(outer, inner, paint);
  }

  @override
  void drawRRect(RRect rrect, ui.Paint paint) {
    _record('drawRRect', rrect.outerRect, paint);
    _inner.drawRRect(rrect, paint);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    _record('drawPath', path.getBounds(), paint);
    _inner.drawPath(path, paint);
  }

  @override
  void drawPaint(ui.Paint paint) {
    _record('drawPaint', Rect.largest, paint);
    _inner.drawPaint(paint);
  }

  @override
  void translate(double dx, double dy) => _inner.translate(dx, dy);

  @override
  void scale(double sx, [double? sy]) => _inner.scale(sx, sy);

  void _record(String name, Rect bounds, ui.Paint paint) {
    draws.add(name);
    drawBounds.add(bounds);
    paints.add(paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unforwarded.add(_symbolName(invocation.memberName));
    return null;
  }
}

String _symbolName(Symbol symbol) {
  final text = symbol.toString();
  final start = text.indexOf('"');
  final end = text.lastIndexOf('"');
  return start >= 0 && end > start ? text.substring(start + 1, end) : text;
}

/// Checks the invariants every written frame must hold, whatever the
/// effect: every uniform finite, blob counts within their slots, opacities
/// and table alphas in range, table stops ascending and in 0–1 for every
/// table in use (and every table a lit layer reads), blob radii positive,
/// and — when [drawBounds] is given — the outline inside the draw.
void expectSaneFrame(BeamFrameData d, String label, {Rect? drawBounds}) {
  for (var i = 0; i < beamUniformFloats; i++) {
    expect(d.data[i].isFinite, isTrue, reason: '$label: uniform $i');
  }
  const slots = [blobSlotsA, blobSlotsB, blobSlotsC];
  var lit = 0;
  for (var k = 0; k < beamLayerCount; k++) {
    expect(d.blobCount(k), inInclusiveRange(0, slots[k]), reason: label);
    expect(d.opacityOf(k), inInclusiveRange(0, 1), reason: '$label: $k');
    expect(d.sigmaOf(k), greaterThanOrEqualTo(0), reason: '$label: $k');
    expect(d.edgeFadeOf(k), greaterThanOrEqualTo(0), reason: '$label: $k');
    if (d.geometryOf(k) != BeamGeometry.none && d.opacityOf(k) > 0) lit++;
    if (d.geometryOf(k) == BeamGeometry.blurredRing) {
      expect(d.sigmaOf(k), greaterThan(0), reason: '$label: $k sigma');
    }
  }
  expect(lit, greaterThan(0), reason: '$label: some layer is lit');
  // The tables a lit layer reads through, as its window or its overlay.
  final read = <BeamTable>{
    for (var k = 0; k < beamLayerCount; k++)
      if (d.geometryOf(k) != BeamGeometry.none && d.opacityOf(k) > 0) ...[
        if (d.windowOf(k) == BeamWindow.conicA) BeamTable.windowA,
        if (d.windowOf(k) == BeamWindow.conicB) BeamTable.windowB,
        ?d.overlayOf(k),
      ],
  };
  for (final t in BeamTable.values) {
    for (var i = 0; i <= 64; i++) {
      final a = d.tableAt(t, i / 64);
      expect(a, inInclusiveRange(0, 1), reason: '$label: $t at ${i / 64}');
    }
    // A table in use holds conic coordinates, its padding included; an
    // unused one is all the 2 it is cleared to. A first stop past 1 reads
    // as unused, so a table a layer reads must be in use.
    final used = d.tableStop(t, 0) <= 1;
    if (read.contains(t)) {
      expect(used, isTrue, reason: '$label: $t is read but unused');
    }
    var previous = -1.0;
    for (var i = 0; i < tableStops; i++) {
      final stop = d.tableStop(t, i);
      expect(
        stop,
        used ? inInclusiveRange(0, 1) : 2,
        reason: '$label: $t stop $i',
      );
      expect(stop, greaterThanOrEqualTo(previous), reason: '$label: $t');
      previous = stop;
    }
  }
  for (var k = 0; k < beamLayerCount; k++) {
    for (var i = 0; i < d.blobCount(k); i++) {
      final b = d.blob(k, i);
      expect(b.rx, greaterThan(0), reason: '$label: layer $k blob $i');
      expect(b.ry, greaterThan(0), reason: '$label: layer $k blob $i');
      expect(b.alpha, inInclusiveRange(0, 1), reason: '$label: blob alpha');
      for (final c in [b.r, b.g, b.b]) {
        expect(c, inInclusiveRange(0, 1), reason: '$label: blob colour');
      }
    }
  }
  expect(d.trackSpan, inInclusiveRange(0, 1), reason: '$label: span');
  expect(d.trackFeather, greaterThanOrEqualTo(0), reason: '$label: feather');
  if (drawBounds != null) {
    final box = d.outlineRect;
    expect(
      drawBounds.inflate(0.5).contains(box.topLeft) &&
          drawBounds.inflate(0.5).contains(box.bottomRight),
      isTrue,
      reason: '$label: $drawBounds must contain the outline $box',
    );
  }
}
