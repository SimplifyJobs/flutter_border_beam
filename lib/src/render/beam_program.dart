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
    'packages/flutter_border_beam/shaders/beam.frag',
    'shaders/beam.frag',
  ];

  static ui.FragmentProgram? _program;
  static Future<void>? _loading;
  static bool _reported = false;
  static final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);

  /// The loaded program, or null until [load] completes.
  static ui.FragmentProgram? get program => _program;

  /// Becomes true once the program has loaded.
  static ValueListenable<bool> get ready => _ready;

  /// Starts loading the program if it has not been loaded yet, and completes
  /// when it is available (or when loading failed).
  ///
  /// Safe to call repeatedly. A load that never completed — one started in a
  /// zone that has since gone away, as in a widget test's fake clock — is
  /// replaced rather than awaited forever.
  static Future<void> load() {
    if (_program != null) return Future<void>.value();
    return _loading = _load();
  }

  static Future<void> _load() async {
    Object? lastError;
    StackTrace? lastStack;
    for (final key in _keys) {
      try {
        final program = await ui.FragmentProgram.fromAsset(key);
        _program = program;
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
          library: 'flutter_border_beam',
          context: ErrorDescription('while loading the beam shader'),
        ),
      );
    }
  }

  /// Whether a load is in flight.
  @visibleForTesting
  static bool get isLoading => _loading != null && _program == null;
}
