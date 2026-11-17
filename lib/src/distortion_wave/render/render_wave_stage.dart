import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../border_beam/render/beam_outline.dart';
import '../models/wave_snapshots.dart';
import '../models/wave_spec.dart';
import '../timeline/wave_frame.dart';
import '../timeline/wave_particles.dart';
import '../wave_source.dart';
import 'dot_atlas.dart';
import 'wave_frame_data.dart';
import 'wave_programs.dart';
import 'wave_snapshot.dart';

/// The two sides of a wave stage.
enum WaveSlot {
  /// The side shown at progress 0, which the wave leaves behind.
  outgoing,

  /// The side shown at progress 1, which the wave reveals.
  incoming,
}

/// What a frame of the stage draws.
enum WavePhase {
  /// At rest on one side: that side, as itself.
  rest,

  /// The wave bends content: both sides through `wave.frag`, one draw.
  distorting,

  /// The front has crossed and bends nothing: the revealed side as itself,
  /// with the colour left on the edges drawn over it by `wave_glow.frag`.
  glowing,

  /// Reduced motion, or a side that cannot be rasterised: a plain
  /// crossfade.
  crossfading,
}

/// The render object of a distortion wave: two children, one per
/// [WaveSlot], laid out to the stage's size, and everything the wave draws
/// over and instead of them.
///
/// A repaint boundary that repaints on every tick of [progress]. Per frame
/// it resolves the [WaveFrame] and picks a [WavePhase]. While the wave bends
/// content it draws both sides from GPU images of them (`WaveSideImages`),
/// taken when first needed and again when that side's content repaints,
/// in one shader draw plus one atlas draw for the dots; no layers, clips or
/// filters per frame.
class RenderWaveStage extends RenderBox
    with SlottedContainerRenderObjectMixin<WaveSlot, RenderBox> {
  /// A stage at `progress`, with the look `spec`, opening from `source` (by
  /// default, the spot of the spec's type: see `defaultWaveSource`).
  RenderWaveStage({
    required this._progress,
    required this._spec,
    this._source,
    required this._devicePixelRatio,
    this._snapshots = WaveSnapshots.onChange,
    this._plain = false,
    this._revealing = false,
    this._displayRadii,
    this._viewSize,
  });

  ValueListenable<double> _progress;

  /// Where the wave is, 0–1. The stage repaints whenever it changes.
  ValueListenable<double> get progress => _progress;
  set progress(ValueListenable<double> value) {
    if (identical(value, _progress)) return;
    if (attached) _progress.removeListener(_onProgress);
    _progress = value;
    if (attached) _progress.addListener(_onProgress);
    _onProgress();
  }

  WaveSpec _spec;

  /// The settled look.
  WaveSpec get spec => _spec;
  set spec(WaveSpec value) {
    if (value == _spec) return;
    if (value.type != _spec.type) _resolved = null;
    _spec = value;
    _specWritten = false;
    markNeedsPaint();
  }

  WaveSource? _source;

  /// Where the wave opens from; null for the default spot of the wave's
  /// type. Measured the first time a frame needs it after it is set.
  WaveSource? get source => _source;
  set source(WaveSource? value) {
    if (value == _source) return;
    _source = value;
    _resolved = null;
    markNeedsPaint();
  }

  ({Rect rect, Offset? focus})? _resolved;

  /// The source in the stage's coordinates, measured once per source (and
  /// per size, for the default spot).
  ({Rect rect, Offset? focus}) get _origin => _resolved ??=
      _source?.resolve(this) ??
      (rect: defaultWaveSource(_spec.type, size), focus: null);

  double _devicePixelRatio;

  /// The device pixel ratio the sides are rasterised at.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _release();
    markNeedsPaint();
  }

  WaveSnapshots _snapshots;

  /// When the sides are rasterised again while the wave bends them.
  WaveSnapshots get snapshots => _snapshots;
  set snapshots(WaveSnapshots value) {
    if (value == _snapshots) return;
    _snapshots = value;
    markNeedsPaint();
  }

  bool _plain;

  /// Whether to crossfade plainly instead of drawing the wave (reduced
  /// motion).
  bool get plain => _plain;
  set plain(bool value) {
    if (value == _plain) return;
    _plain = value;
    markNeedsPaint();
  }

  BorderRadius? _displayRadii;

  /// The display's corner radii, when the edges should follow them: set when
  /// nothing sets `WaveGlow.cornerRadius`. Used only while the stage fills
  /// the whole view ([viewSize]); otherwise the spec's radius applies.
  BorderRadius? get displayRadii => _displayRadii;
  set displayRadii(BorderRadius? value) {
    if (value == _displayRadii) return;
    _displayRadii = value;
    markNeedsPaint();
  }

  Size? _viewSize;

  /// The size of the view the stage is in, logical pixels.
  Size? get viewSize => _viewSize;
  set viewSize(Size? value) {
    if (value == _viewSize) return;
    _viewSize = value;
    markNeedsPaint();
  }

  /// The corners the edges follow this frame: the display's — each corner
  /// its own — while the stage fills the view and the display reports them;
  /// else the spec's radius on all four.
  BorderRadius get _corners {
    final radii = _displayRadii;
    final view = _viewSize;
    if (radii != null && view != null && attached && hasSize) {
      final origin = localToGlobal(Offset.zero);
      final fills =
          origin.distance < 0.5 &&
          (size.width - view.width).abs() < 0.5 &&
          (size.height - view.height).abs() < 0.5;
      if (fills) return radii;
    }
    return BorderRadius.circular(_spec.cornerRadius);
  }

  /// The corners the edges follow; for tests.
  @visibleForTesting
  BorderRadius get debugCorners => _corners;

  bool _revealing;

  /// Whether the wave is heading for the incoming side; the side it is
  /// heading for is the one in the semantics tree while it runs.
  bool get revealing => _revealing;
  set revealing(bool value) {
    if (value == _revealing) return;
    _revealing = value;
    _checkSemanticSide();
  }

  /// The child shown at progress 0.
  RenderBox? get outgoing => childForSlot(WaveSlot.outgoing);

  /// The child shown at progress 1.
  RenderBox? get incoming => childForSlot(WaveSlot.incoming);

  // Per-frame state, reused.
  final WaveFrameData _data = WaveFrameData();
  final DotAtlas _dots = DotAtlas();
  ui.FragmentShader? _waveShader;
  ui.FragmentShader? _glowShader;
  final Paint _wavePaint = Paint()..isAntiAlias = false;
  final Paint _glowPaint = Paint()..isAntiAlias = false;
  bool _specWritten = false;
  BeamOutline? _outline;
  WaveSideImages? _outImages;
  WaveSideImages? _inImages;
  bool _unrasterizable = false;
  WavePhase _lastPhase = WavePhase.rest;

  /// What the last frame drew; for tests and diagnostics.
  @visibleForTesting
  WavePhase get debugLastPhase => _lastPhase;

  /// Whether the stage holds any picture of a side; for tests.
  @visibleForTesting
  bool get debugHoldsImages => _outImages != null || _inImages != null;

  /// How many pictures of each side have been taken; for tests.
  @visibleForTesting
  final Map<WaveSlot, int> debugSnapshotCount = {
    WaveSlot.outgoing: 0,
    WaveSlot.incoming: 0,
  };

  /// The side the semantics tree visits: the one at rest, or while the wave
  /// runs, the one it is heading for.
  WaveSlot get _semanticSlot {
    final p = _progress.value;
    if (p <= 0) return WaveSlot.outgoing;
    if (p >= 1) return WaveSlot.incoming;
    return _revealing ? WaveSlot.incoming : WaveSlot.outgoing;
  }

  WaveSlot? _visitedSlot;

  void _checkSemanticSide() {
    final slot = _semanticSlot;
    if (slot == _visitedSlot) return;
    _visitedSlot = slot;
    markNeedsSemanticsUpdate();
  }

  void _onProgress() {
    markNeedsPaint();
    _checkSemanticSide();
    final p = _progress.value;
    if (p <= 0 || p >= 1) _unrasterizable = false;
  }

  void _onProgramReady() => markNeedsPaint();

  /// Marks [slot]'s content as changed, so the next frame that draws it from
  /// an image takes a new one.
  void sideChanged(WaveSlot slot) {
    if (slot == WaveSlot.outgoing) {
      _outDirty = true;
    } else {
      _inDirty = true;
    }
  }

  bool _outDirty = true;
  bool _inDirty = true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(_onProgress);
    waveProgram.ready.addListener(_onProgramReady);
    waveGlowProgram.ready.addListener(_onProgramReady);
  }

  @override
  void detach() {
    _progress.removeListener(_onProgress);
    waveProgram.ready.removeListener(_onProgramReady);
    waveGlowProgram.ready.removeListener(_onProgramReady);
    _release();
    super.detach();
  }

  @override
  void dispose() {
    _release();
    _dots.dispose();
    _waveShader?.dispose();
    _glowShader?.dispose();
    _waveShader = null;
    _glowShader = null;
    super.dispose();
  }

  void _release() {
    _outImages?.dispose();
    _inImages?.dispose();
    _outImages = null;
    _inImages = null;
  }

  // ─── Layout ───────────────────────────────────────────────────────────────

  @override
  bool get isRepaintBoundary => true;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  Size _layoutSize(
    BoxConstraints constraints,
    Size Function(RenderBox) measure,
  ) {
    if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
      return constraints.biggest;
    }
    var size = Size.zero;
    for (final child in children) {
      final s = measure(child);
      size = Size(
        math.max(size.width, s.width),
        math.max(size.height, s.height),
      );
    }
    return constraints.constrain(size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _layoutSize(
    constraints,
    (child) => child.getDryLayout(constraints.loosen()),
  );

  @override
  void performLayout() {
    size = _layoutSize(constraints, (child) {
      child.layout(constraints.loosen(), parentUsesSize: true);
      return child.size;
    });
    for (final child in children) {
      child.layout(BoxConstraints.tight(size));
    }
    _outline = null;
    if (_source == null) _resolved = null;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      children.fold(0, (m, c) => math.max(m, c.getMinIntrinsicWidth(height)));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      children.fold(0, (m, c) => math.max(m, c.getMaxIntrinsicWidth(height)));

  @override
  double computeMinIntrinsicHeight(double width) =>
      children.fold(0, (m, c) => math.max(m, c.getMinIntrinsicHeight(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      children.fold(0, (m, c) => math.max(m, c.getMaxIntrinsicHeight(width)));

  // ─── Hit testing and semantics ────────────────────────────────────────────

  /// The side that takes touches: the one at rest; while the wave runs,
  /// none — except the revealed side once a reveal no longer bends it, so
  /// it answers while the colour lingers on the edges.
  RenderBox? get _touchable {
    final p = _progress.value;
    if (p <= 0) return outgoing;
    if (p >= 1) return incoming;
    if (!_revealing || _plain || !hasSize) return null;
    final origin = _origin;
    final frame = WaveFrame.at(
      progress: p,
      source: origin.rect,
      size: size,
      spec: _spec,
      focus: origin.focus,
    );
    return frame.contentAtRest ? incoming : null;
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final side = _touchable;
    if (side == null) return false;
    return side.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final slot = _semanticSlot;
    _visitedSlot = slot;
    final side = childForSlot(slot);
    if (side != null) visitor(side);
  }

  // ─── Painting ─────────────────────────────────────────────────────────────

  BorderRadius? _outlineCorners;

  BeamOutline _stageOutline(BorderRadius corners) {
    if (_outline == null || _outlineCorners != corners) {
      _outlineCorners = corners;
      _outline = BeamOutline(Offset.zero & size, corners, superellipse: true);
      _specWritten = false;
    }
    return _outline!;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final p = _progress.value;
    if (p <= 0 || p >= 1) {
      _lastPhase = WavePhase.rest;
      _release();
      final side = p <= 0 ? outgoing : incoming;
      if (side != null) context.paintChild(side, offset);
      return;
    }
    if (_plain || _unrasterizable) {
      _lastPhase = WavePhase.crossfading;
      _release();
      _paintCrossfade(context, offset, p);
      return;
    }

    final origin = _origin;
    final frame = WaveFrame.at(
      progress: p,
      source: origin.rect,
      size: size,
      spec: _spec,
      focus: origin.focus,
    );
    if (frame.contentAtRest) {
      _lastPhase = WavePhase.glowing;
      _release();
      if (incoming != null) context.paintChild(incoming!, offset);
      _paintGlow(context.canvas, offset, frame);
      _paintDots(context.canvas, offset, frame);
      return;
    }

    final program = waveProgram.program;
    if (program == null) {
      // The shader is still loading: show the side the wave is on.
      _lastPhase = WavePhase.rest;
      final side = frame.launched ? incoming : outgoing;
      if (side != null) context.paintChild(side, offset);
      return;
    }
    if (!_ensureImages(frame)) {
      _lastPhase = WavePhase.crossfading;
      _unrasterizable = true;
      _release();
      _paintCrossfade(context, offset, p);
      return;
    }
    _lastPhase = WavePhase.distorting;

    final shader = _waveShader ??= program.fragmentShader();
    _writeUniforms(offset, frame);
    _data.upload(shader);
    // A side not drawn this frame is never read; its slots get the other
    // side's images so every sampler is bound.
    _bindSide(shader, 0, _outImages ?? _inImages!);
    _bindSide(shader, 3, _inImages ?? _outImages!);
    _wavePaint.shader = shader;
    context.canvas.drawRect(offset & size, _wavePaint);
    _paintDots(context.canvas, offset, frame);
  }

  static void _bindSide(ui.FragmentShader shader, int at, WaveSideImages side) {
    shader
      ..setImageSampler(at, side.sharp, filterQuality: FilterQuality.low)
      ..setImageSampler(
        at + 1,
        side.near ?? side.sharp,
        filterQuality: FilterQuality.low,
      )
      ..setImageSampler(
        at + 2,
        side.far ?? side.sharp,
        filterQuality: FilterQuality.low,
      );
  }

  /// Makes sure the images [frame] needs are there and current. Returns
  /// false when a side cannot be rasterised.
  bool _ensureImages(WaveFrame frame) {
    final everyFrame = _snapshots == WaveSnapshots.everyFrame;
    final blurs = frame.energy > 0 && _spec.blur > 0;
    final near = math.min(waveNearBlur, _spec.blur);
    WaveSideImages? refresh(
      WaveSideImages? images,
      RenderBox? side,
      WaveSlot slot,
      bool dirty,
    ) {
      if (side == null) return images;
      if (images == null || dirty || everyFrame) {
        images?.dispose();
        images = WaveSideImages.take(side, _devicePixelRatio);
        if (images == null) return null;
        debugSnapshotCount[slot] = debugSnapshotCount[slot]! + 1;
      }
      if (blurs) images.bakeBlurs(near, _spec.blur);
      return images;
    }

    if (frame.showsOutgoing) {
      _outImages = refresh(_outImages, outgoing, WaveSlot.outgoing, _outDirty);
      _outDirty = false;
      if (_outImages == null && outgoing != null) return false;
    } else {
      _outImages?.dispose();
      _outImages = null;
    }
    if (frame.showsIncoming) {
      _inImages = refresh(_inImages, incoming, WaveSlot.incoming, _inDirty);
      _inDirty = false;
      if (_inImages == null && incoming != null) return false;
    } else {
      _inImages?.dispose();
      _inImages = null;
    }
    return _outImages != null || _inImages != null;
  }

  void _writeUniforms(Offset offset, WaveFrame frame) {
    final outline = _stageOutline(_corners);
    if (!_specWritten) {
      // The largest corner bounds where the edges' colour can reach.
      final largest = outline.radii.reduce(math.max);
      _data.setSpec(_spec, cornerRadius: largest);
      _specWritten = true;
    }
    _data
      ..setStage(offset & size, 1 / _devicePixelRatio, outline)
      ..setFrame(frame)
      ..setLumps(
        time: frame.time,
        perimeter: outline.length,
        pulse: _spec.rimPulse,
      );
  }

  void _paintGlow(Canvas canvas, Offset offset, WaveFrame frame) {
    if (frame.rim <= 0 && frame.glow <= 0) return;
    final program = waveGlowProgram.program;
    if (program == null) return;
    final shader = _glowShader ??= program.fragmentShader();
    _writeUniforms(offset, frame);
    _data.upload(shader);
    _glowPaint.shader = shader;
    canvas.drawRect(offset & size, _glowPaint);
  }

  void _paintDots(Canvas canvas, Offset offset, WaveFrame frame) {
    _dots.paint(
      canvas,
      offset,
      WaveParticle.all(_spec),
      frame,
      _origin.rect,
      devicePixelRatio: _devicePixelRatio,
      largest: _spec.dotSize,
    );
  }

  /// The incoming side, with the outgoing one over it fading out.
  void _paintCrossfade(PaintingContext context, Offset offset, double p) {
    final under = incoming;
    final over = outgoing;
    if (under != null) context.paintChild(under, offset);
    if (over == null) return;
    final alpha = ((1 - p) * 255).round();
    if (alpha <= 0) return;
    context.pushOpacity(
      offset,
      alpha,
      (context, offset) => context.paintChild(over, offset),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('progress', _progress.value))
      ..add(DiagnosticsProperty<WaveSpec>('spec', _spec))
      ..add(DiagnosticsProperty<WaveSource>('source', _source))
      ..add(EnumProperty<WavePhase>('phase', _lastPhase));
  }
}
