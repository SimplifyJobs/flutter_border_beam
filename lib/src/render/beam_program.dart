import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads the beam shader once per process and shares it.
///
/// `FragmentProgram.fromAsset` is asynchronous. Until it resolves, beams
/// paint nothing — their fade-in hides the few milliseconds this takes — and
/// [ready] flips once it has, so a painter that is not ticking (a static
/// reduced-motion frame) still repaints when the program arrives.
abstract final class BeamProgram {
  // A consuming app resolves package assets under `packages/<name>/`; the
  // package's own tests resolve them at the bare path.
  static const List<String> _keys = [
    'packages/prismatic/shaders/beam.frag',
    'shaders/beam.frag',
  ];

  static ui.FragmentProgram? _program;
  static Future<void>? _loading;
  static Zone? _loadingZone;
  static bool _reported = false;
  static final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);

  /// The loaded program, or null until [load] completes.
  static ui.FragmentProgram? get program => _program;

  /// Becomes true once the program has loaded.
  static ValueListenable<bool> get ready => _ready;

  /// Starts loading the program if it has not been loaded yet, and completes
  /// when it is available (or when loading failed).
  ///
  /// Safe to call repeatedly: a call while a load is in flight shares that
  /// load. Only a load started in the same zone is shared. One started in a
  /// zone that has since gone away, as in a widget test's fake clock, may
  /// never complete, so a caller in another zone starts its own rather than
  /// awaiting it forever.
  static Future<void> load() {
    if (_program != null) return Future<void>.value();
    final pending = _loading;
    if (pending != null && identical(_loadingZone, Zone.current)) {
      return pending;
    }
    late final Future<void> loading;
    loading = _load().whenComplete(() {
      // A failed load is forgotten, so a later call retries.
      if (identical(_loading, loading)) _loading = null;
    });
    _loadingZone = Zone.current;
    return _loading = loading;
  }

  static Future<void> _load() async {
    Object? lastError;
    StackTrace? lastStack;
    for (final key in _keys) {
      try {
        final program = await ui.FragmentProgram.fromAsset(key);
        // A load from another zone may have finished first; keep its program.
        _program ??= program;
        _ready.value = true;
        return;
      } on Object catch (error, stack) {
        lastError = error;
        lastStack = stack;
      }
    }
    if (!_reported && lastError != null) {
      _reported = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: lastError,
          stack: lastStack,
          library: 'prismatic',
          context: ErrorDescription('while loading the beam shader'),
        ),
      );
    }
  }
}
