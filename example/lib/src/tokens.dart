import 'package:material_ui/material_ui.dart';

/// The example's colours, after the original border-beam demo's design
/// tokens. A [ThemeExtension], so `MaterialApp` cross-fades between the dark
/// and light sets when the theme flips.
@immutable
class Tokens extends ThemeExtension<Tokens> {
  /// Creates a token set.
  const Tokens({
    required this.bg,
    required this.spot,
    required this.text,
    required this.muted,
    required this.faint,
    required this.track,
    required this.thumb,
    required this.surface,
    required this.surfaceLine,
    required this.chip,
    required this.chipLine,
    required this.surfaceText,
    required this.placeholder,
    required this.icon,
  });

  /// Dark tokens — the default.
  static const dark = Tokens(
    bg: Color(0xFF070707),
    spot: Color(0xFF111111),
    text: Color(0xFFFBFBFB),
    muted: Color(0x99FBFBFB),
    faint: Color(0x4DFBFBFB),
    track: Color(0xFF141414),
    thumb: Color(0xFF2C2C2C),
    surface: Color(0xFF161616),
    surfaceLine: Color(0xFF242629),
    chip: Color(0x0DFFFFFF),
    chipLine: Color(0x0AFFFFFF),
    surfaceText: Color(0xFFC0C0C0),
    placeholder: Color(0xFF5A5A5A),
    icon: Color(0xFF808388),
  );

  /// Light tokens.
  static const light = Tokens(
    bg: Color(0xFFF7F7F8),
    spot: Color(0xFFFFFFFF),
    text: Color(0xFF111114),
    muted: Color(0xFF6B6B78),
    faint: Color(0xFFA5A5AE),
    track: Color(0xFFECECEF),
    thumb: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceLine: Color(0xFFE2E2E8),
    chip: Color(0x0A111111),
    chipLine: Color(0x0D000000),
    surfaceText: Color(0xFF3A3A48),
    placeholder: Color(0xFF9A9AA4),
    icon: Color(0xFF6B6E76),
  );

  /// Page background.
  final Color bg;

  /// The centre of the stage's spotlight.
  final Color spot;

  /// Primary text.
  final Color text;

  /// Secondary text.
  final Color muted;

  /// Hints and code.
  final Color faint;

  /// Control tracks.
  final Color track;

  /// The selected segment of a control.
  final Color thumb;

  /// The mock surfaces the beams wrap.
  final Color surface;

  /// The surfaces' 1px ring.
  final Color surfaceLine;

  /// Chips and skeleton bars inside a surface.
  final Color chip;

  /// Chip hairlines.
  final Color chipLine;

  /// Body text inside a surface.
  final Color surfaceText;

  /// Placeholder text inside a surface.
  final Color placeholder;

  /// Glyphs inside a surface.
  final Color icon;

  /// The tokens of the ambient theme.
  static Tokens of(BuildContext context) =>
      Theme.of(context).extension<Tokens>()!;

  @override
  Tokens copyWith() => this;

  @override
  Tokens lerp(Tokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return Tokens(
      bg: mix(bg, other.bg),
      spot: mix(spot, other.spot),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      faint: mix(faint, other.faint),
      track: mix(track, other.track),
      thumb: mix(thumb, other.thumb),
      surface: mix(surface, other.surface),
      surfaceLine: mix(surfaceLine, other.surfaceLine),
      chip: mix(chip, other.chip),
      chipLine: mix(chipLine, other.chipLine),
      surfaceText: mix(surfaceText, other.surfaceText),
      placeholder: mix(placeholder, other.placeholder),
      icon: mix(icon, other.icon),
    );
  }
}

/// The app theme for [brightness]: Material only as a carrier for [Tokens]
/// and the platform's type, with ripples off.
ThemeData buildTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark ? Tokens.dark : Tokens.light;
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: tokens.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [tokens],
  );
}

/// A strong ease-out for things that respond to a tap.
const Curve easeOut = Cubic(0.23, 1, 0.32, 1);
