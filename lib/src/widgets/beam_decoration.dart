import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import '../animation/beam_clock.dart';
import '../animation/beam_phases.dart';
import '../border_beam_theme.dart';
import '../models/beam_colors.dart';
import '../models/beam_config.dart';
import '../models/beam_playback.dart';
import '../models/beam_shape.dart';
import '../models/beam_style.dart';
import '../models/beam_theme.dart';
import '../models/beam_timing.dart';
import '../models/beam_variant.dart';
import '../painting/beam_painter.dart';
import '../painting/variant_strategy.dart';

/// A beam as a [Decoration], for dropping into an existing
/// `Container`/`DecoratedBox` instead of wrapping the subtree in a
/// `BorderBeam`.
///
/// ```dart
/// Container(
///   foregroundDecoration: BeamDecoration(
///     variant: BeamVariant.rotate,
///     brightness: Theme.of(context).brightness,
///     colors: BeamColors.ocean,
///     borderRadius: 16,
///   ),
///   decoration: BoxDecoration(
///     color: surface,
///     borderRadius: BorderRadius.circular(16),
///   ),
///   child: content,
/// )
/// ```
///
/// It takes the same value objects and shorthands as `BorderBeam` — [style],
/// [shape], [timing], [playback], plus the [colors]/[active]/[borderRadius]
/// shorthands — and paints the identical frames.
///
/// ## Which slot
///
/// A decoration paints in exactly one slot, so the variant decides which:
///
/// | Variant | Slot |
/// | --- | --- |
/// | [BeamVariant.rotate], [BeamVariant.small], [BeamVariant.line], [BeamVariant.pulseInside] | `foregroundDecoration:` |
/// | [BeamVariant.pulseOutside] | `decoration:` |
///
/// `BorderBeam` paints every layer of the first four *over* its child, which
/// is what `foregroundDecoration:` does — put them in `decoration:` only when
/// the beam is meant to sit under opaque content.
/// [BeamVariant.pulseOutside] is the opposite case: its halo blooms behind
/// and outside the child, so it belongs in `decoration:`, and the child needs
/// the same clip-free room around it that the widget form requires.
///
/// ## Limits of the decoration form
///
/// A [BoxPainter] gets a canvas and nothing else — no `BuildContext`, no
/// [TickerProvider]. Prefer `BorderBeam` when any of these matter; it is the
/// same engine with the context the decoration cannot reach:
///
/// - **Ambient theming is passed in, not read.** [brightness] is required and
///   [theme] takes the `BorderBeamThemeData` that `BorderBeamTheme.of` would
///   have returned; a decoration inherits from no enclosing theme by itself.
/// - **The ticker is unmanaged.** It is created directly rather than through
///   a [TickerProvider], so it is not muted by `TickerMode` — a beam inside a
///   scrollable's off-screen cache extent, or under an inactive route, keeps
///   ticking. It stops only when the decoration is replaced or its render
///   object is disposed.
/// - **Reduced motion is not observed.** `MediaQuery.disableAnimationsOf` is
///   unreachable, so [BeamPlayback.reducedMotion] has no effect here. Nor is
///   the enclosing scrollable: there is no `Scrollable.of` to ask, so
///   [BeamPlayback.pauseWhenOffscreen] is inert here too.
/// - **[active] is a starting state, not a toggle.** Changing any field
///   replaces the decoration, which discards the running painter and builds a
///   fresh one — so flipping [active] cuts rather than fading. Animated
///   activation is `BorderBeam`'s.
/// - **It does not interpolate.** `lerpFrom`/`lerpTo` return null (the
///   inherited behavior), so an `AnimatedContainer` snaps between two beam
///   decorations at the halfway point.
///
/// The decoration never absorbs pointer events: `hitTest` returns false, so
/// hits fall through to the child exactly as they do under `BorderBeam`.
@immutable
class BeamDecoration extends Decoration {
  /// Creates a beam decoration for [variant].
  ///
  /// [brightness] is the ambient brightness the beam adapts to — normally
  /// `Theme.of(context).brightness`; `style.theme` still overrides it.
  /// [theme] stands in for the enclosing `BorderBeamTheme`: pass
  /// `BorderBeamTheme.of(context)` to inherit app-wide defaults.
  const BeamDecoration({
    required this.variant,
    required this.brightness,
    this.theme,
    this.colors,
    this.active,
    this.borderRadius,
    this.style,
    this.shape,
    this.timing,
    this.playback,
  });

  /// Which effect this decoration paints.
  final BeamVariant variant;

  /// The ambient brightness the beam adapts to, since a painter cannot read
  /// one. `style.theme` (a [BeamTheme] other than [BeamTheme.auto]) wins.
  final Brightness brightness;

  /// The defaults an enclosing `BorderBeamTheme` would have supplied. Null
  /// inherits nothing.
  final BorderBeamThemeData? theme;

  /// Shorthand for `style.colors`; a non-null value here wins over it.
  final BeamColors? colors;

  /// Shorthand for `playback.active`; a non-null value here wins over it.
  /// A starting state rather than a toggle — see the class docs.
  final bool? active;

  /// Shorthand for a uniform `shape.radius` in logical px; a non-null value
  /// here wins over it. Match the decorated box's own radius.
  final double? borderRadius;

  /// Colors, theme adaptation, and every filter/opacity tuning hook.
  final BeamStyle? style;

  /// Corner radii, ring width, and corner family.
  final BeamShape? shape;

  /// Cycle length, rest between sweeps, playback rate, and hue periods.
  final BeamTiming? timing;

  /// Play state and scheduling. [BeamPlayback.reducedMotion] is inert here.
  final BeamPlayback? playback;

  // The decoration's own value objects, with the shorthands folded in and
  // [theme] merged underneath — the decoration's analogue of BorderBeam's
  // build-time resolution.
  BeamStyle get _style {
    final own = colors == null
        ? style
        : (style ?? const BeamStyle()).copyWith(colors: colors);
    return (theme?.style ?? const BeamStyle()).merge(own);
  }

  BeamShape get _shape {
    final own = borderRadius == null
        ? shape
        : (shape ?? const BeamShape()).copyWith(
            radius: BorderRadius.circular(borderRadius!),
          );
    return (theme?.shape ?? const BeamShape()).merge(own);
  }

  BeamTiming get _timing => (theme?.timing ?? const BeamTiming()).merge(timing);

  BeamPlayback get _playback {
    final own = active == null
        ? playback
        : (playback ?? const BeamPlayback()).copyWith(active: active);
    return (theme?.playback ?? const BeamPlayback()).merge(own);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _BeamBoxPainter(this, onChanged);

  /// Always false: the beam is decorative and never absorbs a pointer.
  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamDecoration &&
          other.variant == variant &&
          other.brightness == brightness &&
          other.theme == theme &&
          other.colors == colors &&
          other.active == active &&
          other.borderRadius == borderRadius &&
          other.style == style &&
          other.shape == shape &&
          other.timing == timing &&
          other.playback == playback;

  @override
  int get hashCode => Object.hash(
    variant,
    brightness,
    theme,
    colors,
    active,
    borderRadius,
    style,
    shape,
    timing,
    playback,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<BeamVariant>('variant', variant))
      ..add(EnumProperty<Brightness>('brightness', brightness))
      ..add(
        DiagnosticsProperty<BorderBeamThemeData>(
          'theme',
          theme,
          defaultValue: null,
        ),
      )
      ..add(DiagnosticsProperty<BeamStyle>('style', _style))
      ..add(DiagnosticsProperty<BeamShape>('shape', _shape))
      ..add(DiagnosticsProperty<BeamTiming>('timing', _timing))
      ..add(DiagnosticsProperty<BeamPlayback>('playback', _playback));
  }
}

// Owns one BeamClock for the lifetime of the decoration it was created for.
//
// The clock's ticker is built with `Ticker.new` rather than a TickerProvider:
// a BoxPainter has no provider to ask, and none of the tree-driven muting
// that comes with one (see the class docs on BeamDecoration).
class _BeamBoxPainter extends BoxPainter {
  _BeamBoxPainter(this._decoration, super.onChanged)
    : _strategy = strategyFor(_decoration.variant) {
    _clock = BeamClock(
      createTicker: Ticker.new,
      maxFps: _strategy.preferredFps,
      fadeCurve: _decoration._playback.fadeCurve,
    )..speed = _decoration._timing.speed ?? 1;
    _schedule();
    // Subscribed last, on purpose: createBoxPainter runs *inside* the render
    // object's paint, where onChanged (markNeedsPaint) is illegal, and
    // _schedule may activate the clock synchronously.
    _clock.addListener(_handleTick);
  }

  final BeamDecoration _decoration;
  final BeamVariantStrategy _strategy;
  late final BeamClock _clock;

  Timer? _startTimer;
  Timer? _durationTimer;

  BeamConfig? _config;
  // _config re-authored for renderScale, or _config itself at scale 1 —
  // built with the config so a frame never allocates one.
  BeamConfig? _painted;
  BeamPhaseResolver? _resolver;
  TextDirection? _configDirection;
  bool _disposed = false;

  // Mirrors BorderBeam's autoplay: `active`/`autoPlay` gate the start,
  // `startAfter` delays it, `duration` ends it. There is no controller here —
  // a controller attaches to a widget's clock, not a painter's.
  void _schedule() {
    final playback = _decoration._playback;
    // A frozen beam paints one instant forever; its clock never starts.
    if (playback.debugFrozenAt != null) return;
    if (!(playback.autoPlay ?? true) || !(playback.active ?? true)) return;
    final startAfter = playback.startAfter;
    if (startAfter == null) {
      _start();
    } else {
      _startTimer = Timer(startAfter, _start);
    }
  }

  void _start() {
    if (_disposed) return;
    _clock.activate();
    final duration = _decoration._playback.duration;
    if (duration != null) _durationTimer = Timer(duration, _clock.deactivate);
  }

  void _handleTick() => onChanged?.call();

  BeamConfig _configFor(TextDirection textDirection) {
    if (_config != null && _configDirection == textDirection) return _config!;
    final style = _decoration._style;
    _configDirection = textDirection;
    _config = BeamConfig.resolve(
      variant: _decoration.variant,
      palette: (style.colors ?? BeamColors.colorful).resolve(),
      brightness: (style.theme ?? BeamTheme.auto).resolve(
        _decoration.brightness,
      ),
      style: style,
      shape: _decoration._shape,
      timing: _decoration._timing,
      textDirection: textDirection,
    );
    _resolver = BeamPhaseResolver(_config!);
    final scale = _config!.renderScale;
    _painted = scale >= 1 ? _config : _config!.scaledBy(scale);
    return _config!;
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final frozen = _decoration._playback.debugFrozenAt;
    if (frozen == null && !_clock.isVisible) return;
    final config = _configFor(configuration.textDirection ?? TextDirection.ltr);
    final phases = frozen != null
        ? _resolver!.sample(
            frozen.inMicroseconds / Duration.microsecondsPerSecond,
            1,
          )
        : _resolver!.sample(_clock.elapsedSeconds, _clock.fadeOpacity);
    // renderScale paints the beam into a smaller box and magnifies it back,
    // so a palette authored for a card reads on a screen-sized one.
    final scale = config.renderScale;
    final painted = _painted!;
    final paintedSize = scale >= 1
        ? size
        : Size(size.width * scale, size.height * scale);
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (scale < 1) canvas.scale(1 / scale);
    // Both passes land in this one slot; BeamDecoration's docs say which slot
    // to hand the variant so they land on the right side of the child.
    _strategy
      ..paintBehind(canvas, paintedSize, painted, phases)
      ..paintAbove(canvas, paintedSize, painted, phases);
    canvas.restore();
  }

  @override
  void dispose() {
    _disposed = true;
    _startTimer?.cancel();
    _durationTimer?.cancel();
    _clock
      ..removeListener(_handleTick)
      ..dispose();
    super.dispose();
  }
}
