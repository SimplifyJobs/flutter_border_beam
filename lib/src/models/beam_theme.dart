import 'dart:ui';

/// How the beam adapts to the surrounding background.
enum BeamTheme {
  /// Tuned for dark backgrounds (the React default).
  dark,

  /// Tuned for light backgrounds.
  light,

  /// Follows the ambient [Brightness] from `Theme.of(context)`.
  auto;

  /// Resolves to a concrete [Brightness] given the ambient theme brightness.
  Brightness resolve(Brightness ambient) => switch (this) {
    dark => Brightness.dark,
    light => Brightness.light,
    auto => ambient,
  };
}
