import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';

import '../demo_theme.dart';
import 'playground_state.dart';

// The theme the "Theme demo" toggle installs above the preview.
final BorderBeamThemeData _demoThemeData = BorderBeamThemeData(
  style: const BeamStyle(colors: BeamColors.ocean),
  shape: BeamShape.circular(20, superellipse: true),
);

// The preview surface, and the frame that gives pulse-outside room to bloom.
const double _surfaceHeight = 128;
const double _maxSurfaceWidth = 320;
const double _frameHeight = 240;

// The sync demo's three stacked cards.
const int _syncBeams = 3;
const double _syncSurfaceHeight = 52;
const double _syncGap = 14;

// One full swing of the strength signal.
const Duration _signalPeriod = Duration(milliseconds: 2400);

class PlaygroundPreviews extends StatelessWidget {
  /// Creates the preview area.
  const PlaygroundPreviews({
    super.key,
    required this.state,
    required this.controllers,
    required this.bothThemes,
  });

  /// The configuration to render.
  final PlaygroundState state;

  /// One controller per preview — a BorderBeamController drives a single
  /// beam at a time, and the wide layout shows two.
  final List<BorderBeamController> controllers;

  /// Whether to render the dark and light backdrops side by side.
  final bool bothThemes;

  @override
  Widget build(BuildContext context) {
    final isDark = DemoTheme.of(context).isDark;
    if (!bothThemes) {
      return _Preview(
        key: GlobalObjectKey(controllers.first),
        state: state,
        brightness: isDark ? Brightness.dark : Brightness.light,
        controller: controllers.first,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Preview(
            key: GlobalObjectKey(controllers[0]),
            state: state,
            brightness: Brightness.dark,
            controller: controllers[0],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Preview(
            key: GlobalObjectKey(controllers[1]),
            state: state,
            brightness: Brightness.light,
            controller: controllers[1],
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatefulWidget {
  const _Preview({
    super.key,
    required this.state,
    required this.brightness,
    required this.controller,
  });

  final PlaygroundState state;
  final Brightness brightness;
  final BorderBeamController controller;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview>
    with SingleTickerProviderStateMixin {
  // Where the pointer is, in normalized box coordinates, while the Drive
  // section's follow toggle is on.
  Offset? _follow;

  // The signal behind `strengthListenable`: a sine wave, so the beam breathes
  // with something that is neither the clock nor a rebuild.
  final ValueNotifier<double> _level = ValueNotifier<double>(1);
  late final Ticker _ticker = createTicker(_tick);
  late bool _controllerMode = widget.state.controllerMode;
  late bool _syncDemo = widget.state.syncDemo;

  @override
  void initState() {
    super.initState();
    _syncSignal();
    _startAttachedController();
  }

  @override
  void didUpdateWidget(_Preview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSignal();
    if (!widget.state.followsPointer) _follow = null;
    if (_controllerMode && !widget.state.controllerMode) {
      // Restore a visible clock before BorderBeam detaches the controller;
      // otherwise disabling controller mode after Stop leaves a blank beam.
      widget.controller.start();
    }
    final needsController =
        widget.state.controllerMode &&
        !widget.state.syncDemo &&
        (!_controllerMode || _syncDemo);
    _controllerMode = widget.state.controllerMode;
    _syncDemo = widget.state.syncDemo;
    if (needsController) _startAttachedController();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _level.dispose();
    super.dispose();
  }

  void _syncSignal() {
    final wanted = widget.state.strengthSignal;
    if (wanted == _ticker.isActive) return;
    if (wanted) {
      _ticker.start();
    } else {
      _ticker.stop();
      _level.value = 1;
    }
  }

  void _tick(Duration elapsed) {
    final turns = elapsed.inMicroseconds / _signalPeriod.inMicroseconds;
    // 0.15–1, so the bottom of the swing dims the beam rather than killing it.
    _level.value = 0.575 + 0.425 * math.sin(turns * 2 * math.pi);
  }

  void _startAttachedController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.state.controllerMode ||
          widget.state.syncDemo ||
          !widget.controller.isAttached) {
        return;
      }
      widget.controller
        ..speed = widget.state.controllerSpeed
        ..start();
    });
  }

  void _track(Offset local, Size size) {
    if (!widget.state.followsPointer) return;
    setState(() {
      _follow = Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );
    });
  }

  void _release() {
    if (_follow == null) return;
    setState(() => _follow = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final dark = widget.brightness == Brightness.dark;
    final tokens = dark ? DemoTokens.dark : DemoTokens.light;

    Widget frame(Widget child) => Container(
      height: _frameHeight,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101010) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          _maxSurfaceWidth,
          math.max(120.0, constraints.maxWidth - 56),
        );
        Widget content = state.syncDemo
            ? _syncGroup(state, tokens, width)
            : _single(state, tokens, width);
        if (state.themeDemo) {
          content = BorderBeamTheme(data: _demoThemeData, child: content);
        }
        if (state.simulateReducedMotion) {
          // The same signal the platform sends, so the reducedMotion chips
          // can be watched without touching OS settings.
          content = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: content,
          );
        }
        // BeamTheme.auto reads the ambient brightness, so each preview only
        // needs the right Theme above it — no explicit `theme:` field, which
        // keeps the generated snippet faithful to what is on screen.
        return Theme(
          data: ThemeData(brightness: widget.brightness),
          child: frame(content),
        );
      },
    );
  }

  // The single configured beam, wrapped in a pointer listener while the
  // follow toggle is on.
  Widget _single(PlaygroundState state, DemoTokens tokens, double width) {
    final segmentSide = math.min(width, 200.0);
    final size = state.segmentPreset == SegmentPreset.off
        ? Size(width, _surfaceHeight)
        : Size.square(segmentSide);
    final Widget beam = SizedBox(
      width: size.width,
      height: size.height,
      child: BorderBeam(
        variant: state.variant,
        active: state.buildActive(),
        style: state.buildStyle(),
        shape: state.buildShape(),
        timing: state.buildTiming(),
        playback: state.buildPlayback(),
        progress: state.buildProgress(),
        follow: state.followsPointer ? _follow : null,
        strengthListenable: state.strengthSignal ? _level : null,
        controller: state.controllerMode ? widget.controller : null,
        child: _MockSurface(state: state, tokens: tokens, size: size),
      ),
    );
    if (!state.followsPointer) return beam;
    // The Listener carries touch drags; the MouseRegion adds plain hover,
    // which sends no pointer events of its own.
    return MouseRegion(
      onHover: (event) => _track(event.localPosition, size),
      onExit: (_) => _release(),
      child: Listener(
        onPointerDown: (event) => _track(event.localPosition, size),
        onPointerMove: (event) => _track(event.localPosition, size),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: beam,
      ),
    );
  }

  // Three beams on one BeamSync clock, evenly spaced around the cycle.
  //
  // The group owns playback, and a BorderBeamController owns a clock of its
  // own, so no controller is attached here.
  Widget _syncGroup(PlaygroundState state, DemoTokens tokens, double width) {
    final size = Size(width, _syncSurfaceHeight);
    final base = state.buildTiming() ?? const BeamTiming();
    return BeamSync(
      active: state.active,
      speed: state.speed,
      reducedMotion: state.reducedMotion ?? BeamReducedMotion.staticFrame,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _syncBeams; i++) ...[
            if (i > 0) const SizedBox(height: _syncGap),
            SizedBox(
              width: width,
              height: _syncSurfaceHeight,
              child: BorderBeam(
                variant: state.variant,
                style: state.buildStyle(),
                shape: state.buildShape(),
                timing: base.copyWith(phaseOffset: i / _syncBeams),
                progress: state.buildProgress(),
                strengthListenable: state.strengthSignal ? _level : null,
                child: _MockSurface(
                  state: state,
                  tokens: tokens,
                  size: size,
                  label: 'phaseOffset ${(i / _syncBeams).toStringAsFixed(2)}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The surface the beam hugs. Its own corners must match the beam contour,
/// theme inheritance included — the beam does not read the child's shape.
class _MockSurface extends StatelessWidget {
  const _MockSurface({
    required this.state,
    required this.tokens,
    required this.size,
    this.label = 'Build anything...',
  });

  final PlaygroundState state;
  final DemoTokens tokens;
  final Size size;
  final String label;

  @override
  Widget build(BuildContext context) {
    // With no shape of its own, the beam inherits the demo theme's squircle
    // 20 — so the surface follows it there too.
    final inherits = state.themeDemo && !state.hasShape;
    final radius = inherits
        ? BorderRadius.circular(20)
        : state.resolvedBorderRadius(size);
    final superellipse = inherits || state.superellipse;
    final side = BorderSide(color: tokens.mockBorder);
    return Container(
      decoration: ShapeDecoration(
        color: tokens.mockBg,
        shape: superellipse
            ? RoundedSuperellipseBorder(borderRadius: radius, side: side)
            : RoundedRectangleBorder(borderRadius: radius, side: side),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: tokens.mockPlaceholder,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
