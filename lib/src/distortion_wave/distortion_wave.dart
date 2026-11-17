import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'distortion_wave_controller.dart';
import 'distortion_wave_theme.dart';
import 'models/wave_palette.dart';
import 'models/wave_snapshots.dart';
import 'models/wave_spec.dart';
import 'models/wave_style.dart';
import 'models/wave_type.dart';
import 'render/render_wave_stage.dart';
import 'render/wave_programs.dart';
import 'render/wave_warm_up.dart';
import 'timeline/wave_clock.dart';
import 'wave_source.dart';

/// A colourful distortion wave that opens from the widget that started it —
/// a button, a screen edge, an avatar — and carries one view into another.
///
/// Everything falls toward the source for a moment, tiny white sparks with
/// it. Then the front leaves the source and travels out as one soft swell,
/// lifting and bending what it passes, with a progressive blur and colour
/// fringing peaking on it. Its colour stays on the view's edges, with a
/// hairline on the glass, after the middle has cleared.
///
/// Flip [revealed] to send the wave out; flip it back to collapse it into the
/// source:
///
/// ```dart
/// DistortionWave(
///   revealed: sent,
///   revealedChild: const ReceiptScreen(),
///   child: ReviewScreen(
///     confirm: DistortionWaveAnchor(
///       child: FilledButton(
///         onPressed: () => setState(() => sent = true),
///         child: const Text('Send'),
///       ),
///     ),
///   ),
/// )
/// ```
///
/// The wave opens from [source] — by default the [DistortionWaveAnchor]
/// inside it that was pressed or focused last, leaning toward the touch, or
/// else the usual spot for its [type]. Give both sides an opaque background: the wave
/// draws them from pictures of themselves, and what is transparent in a side
/// shows nothing behind it while the wave runs.
///
/// The wave is drawn by one fragment shader from GPU images of the two
/// sides, taken when it starts and again whenever a side repaints (see
/// [snapshots]). At rest the visible side is drawn as itself and costs
/// nothing extra. With reduced motion on, it crossfades instead.
class DistortionWave extends StatefulWidget {
  /// A wave between [child] and [revealedChild].
  const DistortionWave({
    super.key,
    this.revealed = false,
    required this.revealedChild,
    required this.child,
    this.source,
    this.type,
    this.palette,
    this.style,
    this.controller,
    this.progress,
    this.snapshots,
    this.maintainState = true,
    this.onFinish,
  }) : assert(
         progress == null || (progress >= 0 && progress <= 1),
         'progress must be between 0 and 1',
       );

  /// Whether [revealedChild] is shown. Flip it to run the wave: to true to
  /// send it out, back to false to collapse it. Ignored while a [controller]
  /// is attached, which owns playback then.
  final bool revealed;

  /// The view shown at rest, which the wave leaves behind.
  final Widget child;

  /// The view the wave reveals.
  final Widget revealedChild;

  /// Where the wave opens from. Null opens it from the
  /// [DistortionWaveAnchor] inside it pressed or focused last (or, when none
  /// was, the only anchor on the side on screen), or else from the usual
  /// spot for its [type]. Read when a run starts from rest.
  final WaveSource? source;

  /// Which way it travels; shorthand for `style.type`, and wins over it.
  final WaveType? type;

  /// Its colours; shorthand for `style.palette`, and wins over it.
  final WavePalette? palette;

  /// Everything else about its look, over the nearest
  /// [DistortionWaveTheme]'s style, over the tuned defaults of its type.
  final WaveStyle? style;

  /// Drives the wave from outside. Attached, it owns playback: [revealed] is
  /// ignored.
  final DistortionWaveController? controller;

  /// Holds the wave at this point of its life, 0–1, instead of animating it
  /// — for screenshots, tests, or driving it from a gesture.
  final double? progress;

  /// When the wave takes fresh pictures of the sides while it bends them.
  /// Defaults to the theme's, or [WaveSnapshots.onChange].
  final WaveSnapshots? snapshots;

  /// Whether the side that is not shown stays mounted at rest, keeping its
  /// state; its tickers are muted. Default true. When false it is built only
  /// while a wave runs.
  final bool maintainState;

  /// Called when a run arrives: the wave has left and the view's edges have
  /// cleared, or it has collapsed back. Not called for a run that was
  /// interrupted by another.
  final VoidCallback? onFinish;

  /// Loads the wave's shaders ahead of the first wave, and draws each of
  /// them once out of sight so the GPU has built their pipelines before the
  /// first wave's first frames. A wave started before they load shows its
  /// sides plainly until they do.
  static Future<void> precache() async {
    await loadWavePrograms();
    warmUpWaveRendering();
  }

  @override
  State<DistortionWave> createState() => _DistortionWaveState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('revealed', value: revealed, ifTrue: 'revealed'))
      ..add(
        DiagnosticsProperty<WaveSource>('source', source, defaultValue: null),
      )
      ..add(EnumProperty<WaveType>('type', type, defaultValue: null))
      ..add(DiagnosticsProperty<WaveStyle>('style', style, defaultValue: null))
      ..add(DoubleProperty('progress', progress, defaultValue: null));
  }
}

class _DistortionWaveState extends State<DistortionWave>
    with SingleTickerProviderStateMixin
    implements WaveDriver {
  late final WaveClock _clock;
  final ValueNotifier<double> _held = ValueNotifier<double>(0);
  final WaveAnchorRegistry _anchors = WaveAnchorRegistry();
  late bool _revealing;
  WaveSource? _runSource;
  int _run = 0;
  WaveSpec? _spec;
  WaveSnapshots _snapshots = WaveSnapshots.onChange;
  bool _followsDisplay = true;

  @override
  void initState() {
    super.initState();
    _revealing = widget.controller?.isRevealed ?? widget.revealed;
    _clock = WaveClock(vsync: this, progress: _revealing ? 1 : 0)
      ..addListener(_onClock);
    _held.value = widget.progress ?? 0;
    widget.controller?.attach(this);
    loadWavePrograms();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveLook();
  }

  @override
  void didUpdateWidget(DistortionWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newOwner = !identical(widget.controller, oldWidget.controller);
    if (newOwner) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    _resolveLook();
    final held = widget.progress;
    final wasHeld = oldWidget.progress;
    if (held != null) {
      if (wasHeld == null) {
        // Picking the wave up: it opens from wherever a run would, and the
        // run in flight stops where it is, so nothing moves or arrives under
        // the hold.
        if (_atRest) _runSource = _sourceForRun(null);
        _run++;
        _clock.stop();
      }
      _held.value = held;
    } else if (wasHeld != null) {
      // Letting go: the wave plays on from where it was held, toward the
      // side it is meant to rest on.
      _clock.jumpTo(wasHeld);
      drive(reveal: widget.controller?.isRevealed ?? widget.revealed);
      return;
    }
    final target = widget.controller?.isRevealed ?? widget.revealed;
    if (newOwner) {
      // A new owner — another controller, or `revealed` once the controller
      // is gone — brings its own target: head for it, unless a run is on its
      // way there already. A wave stopped short of it (by a seek) runs on.
      final heading = _clock.target ?? _clock.progress;
      if (target != _revealing || heading != (target ? 1 : 0)) {
        drive(reveal: target);
      }
    } else if (widget.controller == null &&
        widget.revealed != oldWidget.revealed) {
      drive(reveal: widget.revealed);
    }
  }

  // Read at rest, so the side on screen is the one the clock rests on.
  WaveSource? _sourceForRun(WaveSource? source) =>
      source ??
      widget.source ??
      _anchors.sourceFor(revealedOnScreen: _clock.progress >= 1)?.source;

  void _resolveLook() {
    final theme = DistortionWaveTheme.of(context);
    final style = (widget.style ?? const WaveStyle()).merge(
      WaveStyle(type: widget.type, palette: widget.palette),
    );
    _spec = WaveSpec.resolve(style, fallback: theme.style);
    // Nothing sets the corners: a wave that fills the view follows the
    // display's.
    _followsDisplay =
        style.glow?.cornerRadius == null &&
        theme.style?.glow?.cornerRadius == null;
    _snapshots = widget.snapshots ?? theme.snapshots ?? WaveSnapshots.onChange;
  }

  bool get _atRest =>
      !_clock.isRunning && (_clock.progress <= 0 || _clock.progress >= 1);

  bool _reducedMotion() =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  // The clock crosses into or out of rest: the sides' tickers and mounting
  // change, so rebuild then — not on every tick, which the stage handles.
  bool _wasAtRest = true;

  void _onClock() {
    final atRest = _atRest;
    if (atRest != _wasAtRest) {
      _wasAtRest = atRest;
      if (mounted) setState(() {});
    }
  }

  // Held, the wave is where it is held, and nothing runs.
  @override
  double get progress => widget.progress ?? _clock.progress;

  @override
  bool get isRunning => widget.progress == null && _clock.isRunning;

  @override
  void drive({required bool reveal, WaveSource? source}) {
    if (!mounted) return;
    // The source, and the touch the wave leans with, are taken only when a
    // run starts from rest: changing them mid-wave would make everything on
    // screen jump.
    final held = widget.progress != null;
    if (_atRest && !held) _runSource = _sourceForRun(source);
    final spec = _spec!;
    final run = ++_run;
    void arrived() {
      if (run != _run || !mounted) return;
      setState(() {});
      widget.onFinish?.call();
      widget.controller?.arrived();
    }

    setState(() => _revealing = reveal);
    // Held, the wave stays put; it heads for this side once it is let go.
    if (held) return;
    if (_reducedMotion()) {
      _clock.runTo(reveal ? 1 : 0, fullSeconds: 0.3, onDone: arrived);
    } else if (reveal) {
      _clock.runTo(1, fullSeconds: spec.duration, onDone: arrived);
    } else {
      // On the wave's own easing, which is quick through the end of its
      // life, where little is on screen: the collapse answers at once.
      _clock.runTo(
        0,
        fullSeconds: spec.returnDuration,
        curve: spec.easing,
        onDone: arrived,
      );
    }
  }

  @override
  void seekTo(double progress) {
    if (!mounted) return;
    if (_atRest) _runSource = _sourceForRun(null);
    _run++;
    setState(() => _revealing = progress >= 0.5);
    _clock.jumpTo(progress);
  }

  // A wave leaving the tree lets go of its controller at once, not at
  // disposal at the end of the frame, so a replacement mounted in the same
  // frame (a new key, a GlobalKey moving) can take it over.
  @override
  void deactivate() {
    widget.controller?.detach(this);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.controller?.attach(this);
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _clock
      ..removeListener(_onClock)
      ..dispose();
    _held.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrubbing = widget.progress != null;
    final p = scrubbing ? widget.progress! : _clock.progress;
    final resting = scrubbing ? false : _atRest;
    final onOutgoing = p <= 0;
    final onIncoming = p >= 1;
    // At rest the hidden side is muted, or not built at all. Whenever a side
    // is off screen — at rest, or held at either end — it takes no focus, so
    // Tab, autofocus and the like never land on what cannot be seen.
    Widget? side(WaveSlot slot, Widget child, bool visible) {
      if (resting && !visible && !widget.maintainState) return null;
      final offScreen = slot == WaveSlot.outgoing ? onIncoming : onOutgoing;
      return WaveSide(
        slot: slot,
        child: WaveAnchorScope(
          registry: _anchors,
          onRevealedSide: slot == WaveSlot.incoming,
          child: ExcludeFocus(
            excluding: offScreen,
            child: TickerMode(enabled: !resting || visible, child: child),
          ),
        ),
      );
    }

    return WaveStage(
      progress: scrubbing ? _held : _clock,
      spec: _spec!,
      source: _runSource ?? widget.source,
      devicePixelRatio:
          MediaQuery.maybeDevicePixelRatioOf(context) ??
          View.of(context).devicePixelRatio,
      snapshots: _snapshots,
      plain: _reducedMotion(),
      revealing: _revealing,
      displayRadii: _followsDisplay
          ? MediaQuery.maybeDisplayCornerRadiiOf(context)
          : null,
      viewSize: MediaQuery.maybeSizeOf(context),
      outgoing: side(WaveSlot.outgoing, widget.child, onOutgoing || !resting),
      incoming: side(
        WaveSlot.incoming,
        widget.revealedChild,
        onIncoming || !resting,
      ),
    );
  }
}

/// The stage of a wave: a [RenderWaveStage] with its two sides.
class WaveStage
    extends SlottedMultiChildRenderObjectWidget<WaveSlot, RenderBox> {
  /// A stage at [progress] between [outgoing] and [incoming].
  const WaveStage({
    super.key,
    required this.progress,
    required this.spec,
    this.source,
    required this.devicePixelRatio,
    this.snapshots = WaveSnapshots.onChange,
    this.plain = false,
    this.revealing = false,
    this.displayRadii,
    this.viewSize,
    this.outgoing,
    this.incoming,
  });

  /// Where the wave is, 0–1; the stage repaints when it changes.
  final ValueListenable<double> progress;

  /// The settled look.
  final WaveSpec spec;

  /// Where the wave opens from; null for its type's usual spot.
  final WaveSource? source;

  /// The pixel ratio the sides are pictured at.
  final double devicePixelRatio;

  /// When the sides are pictured again.
  final WaveSnapshots snapshots;

  /// Whether to crossfade instead (reduced motion).
  final bool plain;

  /// Whether the wave is heading for [incoming].
  final bool revealing;

  /// The display's corner radii, for edges that follow them while the stage
  /// fills the view; null when the style sets its own radius.
  final BorderRadius? displayRadii;

  /// The size of the view the stage is in.
  final Size? viewSize;

  /// The side shown at progress 0.
  final Widget? outgoing;

  /// The side shown at progress 1.
  final Widget? incoming;

  @override
  Iterable<WaveSlot> get slots => WaveSlot.values;

  @override
  Widget? childForSlot(WaveSlot slot) => switch (slot) {
    WaveSlot.outgoing => outgoing,
    WaveSlot.incoming => incoming,
  };

  @override
  RenderWaveStage createRenderObject(BuildContext context) => RenderWaveStage(
    progress: progress,
    spec: spec,
    source: source,
    devicePixelRatio: devicePixelRatio,
    snapshots: snapshots,
    plain: plain,
    revealing: revealing,
    displayRadii: displayRadii,
    viewSize: viewSize,
  );

  @override
  void updateRenderObject(BuildContext context, RenderWaveStage renderObject) {
    renderObject
      ..progress = progress
      ..spec = spec
      ..source = source
      ..devicePixelRatio = devicePixelRatio
      ..snapshots = snapshots
      ..plain = plain
      ..revealing = revealing
      ..displayRadii = displayRadii
      ..viewSize = viewSize;
  }
}

/// One side of a wave stage. Tells the stage when the side's content
/// repaints, so the wave takes a fresh picture of it.
class WaveSide extends SingleChildRenderObjectWidget {
  /// The [slot] side, showing [child].
  const WaveSide({super.key, required this.slot, required super.child});

  /// Which side this is.
  final WaveSlot slot;

  @override
  RenderWaveSide createRenderObject(BuildContext context) =>
      RenderWaveSide(slot);

  @override
  void updateRenderObject(BuildContext context, RenderWaveSide renderObject) {
    renderObject.slot = slot;
  }
}

/// The render object of a [WaveSide].
class RenderWaveSide extends RenderProxyBox {
  /// The [slot] side.
  RenderWaveSide(this.slot);

  /// Which side this is.
  WaveSlot slot;

  @override
  void markNeedsPaint() {
    // Anything below that repaints reaches here on its way up to the stage
    // (unless it sits in a repaint boundary of its own).
    final stage = parent;
    if (stage is RenderWaveStage) stage.sideChanged(slot);
    super.markNeedsPaint();
  }
}
