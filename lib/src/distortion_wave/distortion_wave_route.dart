import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'distortion_wave.dart';
import 'distortion_wave_theme.dart';
import 'models/wave_palette.dart';
import 'models/wave_snapshots.dart';
import 'models/wave_spec.dart';
import 'models/wave_style.dart';
import 'models/wave_type.dart';
import 'render/render_wave_stage.dart';
import 'render/wave_programs.dart';
import 'wave_source.dart';

/// A page route that plays a distortion wave from the widget that pushed it
/// into the new page, and collapses it back into that widget on pop.
///
/// ```dart
/// FilledButton(
///   onPressed: () => Navigator.of(context).push(
///     DistortionWaveRoute<void>(
///       source: WaveSource.of(context),
///       builder: (context) => const ReceiptScreen(),
///     ),
///   ),
///   child: const Text('Send'),
/// )
/// ```
///
/// Wrap the button in a `DistortionWaveAnchor` and `WaveSource.of` carries
/// the touch too, so the wave leans toward it.
///
/// The page underneath is pictured as the push starts, and again as a pop
/// starts; the wave bends that picture. It does not play its own exit
/// transition meanwhile. Give the new page an opaque background.
class DistortionWaveRoute<T> extends PageRoute<T> {
  /// A route to the page [builder] builds, opening from [source].
  DistortionWaveRoute({
    required this.builder,
    this.source,
    this.type,
    this.palette,
    this.style,
    this.snapshots,
    this.maintainState = true,
    super.settings,
    super.fullscreenDialog,
  });

  /// Builds the new page.
  final WidgetBuilder builder;

  /// Where the wave opens from; null for the usual spot of its type.
  final WaveSource? source;

  /// Which way it travels; shorthand for `style.type`.
  final WaveType? type;

  /// Its colours; shorthand for `style.palette`.
  final WavePalette? palette;

  /// Everything else about its look, over the nearest
  /// `DistortionWaveTheme`'s style.
  final WaveStyle? style;

  /// When the new page is pictured again while the wave bends it.
  final WaveSnapshots? snapshots;

  @override
  final bool maintainState;

  WaveSpec? _spec;

  /// The settled look, resolved against the navigator's theme once.
  WaveSpec get spec => _spec ??= WaveSpec.resolve(
    (style ?? const WaveStyle()).merge(WaveStyle(type: type, palette: palette)),
    fallback: _themeContext == null
        ? null
        : DistortionWaveTheme.of(_themeContext!).style,
  );

  BuildContext? get _themeContext => navigator?.context;

  bool get _reducedMotion {
    final context = navigator?.context;
    if (context == null) return false;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  Duration get transitionDuration => _reducedMotion
      ? const Duration(milliseconds: 300)
      : _seconds(spec.duration);

  @override
  Duration get reverseTransitionDuration => _reducedMotion
      ? const Duration(milliseconds: 300)
      : _seconds(spec.returnDuration);

  static Duration _seconds(double s) =>
      Duration(microseconds: (s * Duration.microsecondsPerSecond).round());

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  // The page underneath keeps still: the wave carries a picture of it.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  final ValueNotifier<ui.Image?> _below = ValueNotifier<ui.Image?>(null);
  ModalRoute<dynamic>? _previous;

  // The new page's anchors register here, never with an enclosing wave.
  // Made once: the transition is rebuilt on every frame of the animation.
  final WaveAnchorRegistry _anchors = WaveAnchorRegistry();

  /// The picture of the page underneath; for tests.
  @visibleForTesting
  ValueListenable<ui.Image?> get debugBelow => _below;

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    super.didChangePrevious(previousRoute);
    _previous = previousRoute is ModalRoute<dynamic> ? previousRoute : null;
  }

  @override
  TickerFuture didPush() {
    loadWavePrograms();
    _pictureBelowAfterFrame();
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    // The page underneath may have changed while covered; picture it again
    // once it has been painted.
    _pictureBelowAfterFrame();
    return super.didPop(result);
  }

  void _pictureBelowAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) => _pictureBelow());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _pictureBelow() {
    // A route removed before its first frame is disposed before this runs.
    if (_disposed) return;
    final boundary = _previous?.subtreeContext?.findRenderObject();
    // `debugNeedsPaint` keeps debug builds clear of `toImageSync`'s
    // assertion; it is always false in release, where a page still waiting
    // to repaint is pictured as it was last painted.
    if (boundary is! RenderRepaintBoundary ||
        !boundary.attached ||
        !boundary.hasSize ||
        boundary.debugNeedsPaint) {
      return;
    }
    final view = navigator?.context;
    final ratio = view == null
        ? 1.0
        : MediaQuery.maybeDevicePixelRatioOf(view) ??
              View.of(view).devicePixelRatio;
    final old = _below.value;
    _below.value = boundary.toImageSync(pixelRatio: ratio);
    old?.dispose();
  }

  // Made once: `buildTransitions` runs every frame of the transition, and a
  // curve made there would add a listener to the route's animation each time.
  CurvedAnimation? _curved;

  /// The route's animation on the wave's curves: linear out, and the
  /// collapse on the wave's easing, as `DistortionWave`'s does.
  Animation<double> _curve(Animation<double> parent) {
    final curved = _curved;
    if (curved != null && identical(curved.parent, parent)) return curved;
    curved?.dispose();
    return _curved = CurvedAnimation(
      parent: parent,
      curve: Curves.linear,
      reverseCurve: spec.easing.flipped,
    );
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _curved?.dispose();
    _below.value?.dispose();
    _below.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _WaveRouteTransition(
    route: this,
    animation: _curve(animation),
    child: child,
  );

  @override
  String get debugLabel => '${super.debugLabel}(DistortionWaveRoute)';
}

class _WaveRouteTransition extends StatelessWidget {
  const _WaveRouteTransition({
    required this.route,
    required this.animation,
    required this.child,
  });

  final DistortionWaveRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = DistortionWaveTheme.of(context);
    return WaveAnchorScope(
      registry: route._anchors,
      child: WaveStage(
        progress: animation,
        spec: route.spec,
        source: route.source,
        devicePixelRatio:
            MediaQuery.maybeDevicePixelRatioOf(context) ??
            View.of(context).devicePixelRatio,
        snapshots: route.snapshots ?? theme.snapshots ?? WaveSnapshots.onChange,
        plain: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
        revealing: animation.status != AnimationStatus.reverse,
        displayRadii:
            route.style?.glow?.cornerRadius == null &&
                theme.style?.glow?.cornerRadius == null
            ? MediaQuery.maybeDisplayCornerRadiiOf(context)
            : null,
        viewSize: MediaQuery.maybeSizeOf(context),
        outgoing: WaveSide(
          slot: WaveSlot.outgoing,
          child: ValueListenableBuilder<ui.Image?>(
            valueListenable: route._below,
            builder: (context, image, _) => RawImage(
              image: image,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
        incoming: WaveSide(slot: WaveSlot.incoming, child: child),
      ),
    );
  }
}
