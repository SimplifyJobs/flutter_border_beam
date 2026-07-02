import 'package:flutter/widgets.dart';

/// Design tokens transcribed from the original border-beam demo
/// (demo/src/styles.css of the React package) so the Flutter gallery looks
/// identical — no Material defaults anywhere.
class DemoTokens {
  const DemoTokens._({
    required this.bg,
    required this.text,
    required this.heading,
    required this.subtitle,
    required this.muted,
    required this.panel,
    required this.surface,
    required this.tabsBarBg,
    required this.tabsPillBg,
    required this.tabsTextMuted,
    required this.tabsTextActive,
    required this.btnBg,
    required this.btnBgActive,
    required this.btnText,
    required this.btnTextActive,
    required this.trackBg,
    required this.trackFill,
    required this.mockBg,
    required this.mockBorder,
    required this.mockChipBg,
    required this.mockChipLine,
    required this.mockText,
    required this.mockTextStrong,
    required this.mockPlaceholder,
    required this.mockTagText,
    required this.mockSearchText,
    required this.mockSquare,
    required this.mockIcon,
    required this.shimmerBase,
    required this.codeText,
  });

  /// Dark theme tokens (`:root` in the demo CSS).
  static const dark = DemoTokens._(
    bg: Color(0xFF070707),
    text: Color(0xFFFBFBFB),
    heading: Color(0xFFFFFFFF),
    subtitle: Color(0xFFCACACA),
    muted: Color(0x99FBFBFB),
    panel: Color(0xFF121212),
    surface: Color(0x0DD9D9D9),
    tabsBarBg: Color(0xFF1C1C1C),
    tabsPillBg: Color(0xFF494949),
    tabsTextMuted: Color(0x80EFEFEF),
    tabsTextActive: Color(0xFFEFEFEF),
    btnBg: Color(0x08FFFFFF),
    btnBgActive: Color(0x1AFFFFFF),
    btnText: Color(0x80FBFBFB),
    btnTextActive: Color(0xFFFBFBFB),
    trackBg: Color(0x12FFFFFF),
    trackFill: Color(0x1AFFFFFF),
    mockBg: Color(0xFF1D1D1D),
    mockBorder: Color(0x852C2F36),
    mockChipBg: Color(0x0AFFFFFF),
    mockChipLine: Color(0x05FFFFFF),
    mockText: Color(0xFFC0C0C0),
    mockTextStrong: Color(0xFFFFFFFF),
    mockPlaceholder: Color(0xFF4E4E4E),
    mockTagText: Color(0xFFCACCD2),
    mockSearchText: Color(0xFF565656),
    mockSquare: Color(0xCCD9D9D9),
    mockIcon: Color(0xFF808388),
    shimmerBase: Color(0xFF6F6C6C),
    codeText: Color(0xFFFFFFFF),
  );

  /// Light theme tokens (`html[data-theme='light']`).
  static const light = DemoTokens._(
    bg: Color(0xFFFDFDFD),
    text: Color(0xFF1A1A22),
    heading: Color(0xFF111111),
    subtitle: Color(0xFF5C5C6E),
    muted: Color(0xFF5C5C6E),
    panel: Color(0xFFF4F4F7),
    surface: Color(0xFFF6F6F8),
    tabsBarBg: Color(0xFFF5F5F5),
    tabsPillBg: Color(0xFFFFFFFF),
    tabsTextMuted: Color(0x99333333),
    tabsTextActive: Color(0xFF2B2B2B),
    btnBg: Color(0x08111111),
    btnBgActive: Color(0xFFFFFFFF),
    btnText: Color(0xFF5C5C6E),
    btnTextActive: Color(0xFF111111),
    trackBg: Color(0x0F111111),
    trackFill: Color(0x24111111),
    mockBg: Color(0xFFFFFFFF),
    mockBorder: Color(0xD9C8C8D4),
    mockChipBg: Color(0x0A111111),
    mockChipLine: Color(0x0D000000),
    mockText: Color(0xFF3A3A48),
    mockTextStrong: Color(0xFF111111),
    mockPlaceholder: Color(0xFF9A9AA4),
    mockTagText: Color(0xFF3A3A48),
    mockSearchText: Color(0xFF8A8A94),
    mockSquare: Color(0xBF282834),
    mockIcon: Color(0xFF6B6E76),
    shimmerBase: Color(0xFF9A9AA4),
    codeText: Color(0xFF1A1A22),
  );

  /// Page background (`--c-bg`).
  final Color bg;

  /// Body text (`--c-text`).
  final Color text;

  /// Headings (`--c-heading`).
  final Color heading;

  /// Subtitle text (`--c-subtitle`).
  final Color subtitle;

  /// Muted body text (`--c-muted`).
  final Color muted;

  /// Code/panel background (`--c-panel`).
  final Color panel;

  /// Example frame background (`--c-surface`).
  final Color surface;

  /// Tab bar background (`--tabs-bar-bg`).
  final Color tabsBarBg;

  /// Active tab pill background (`--tabs-pill-bg`).
  final Color tabsPillBg;

  /// Inactive tab text (`--tabs-text-muted`).
  final Color tabsTextMuted;

  /// Active tab text (`--tabs-text-active`).
  final Color tabsTextActive;

  /// Control button background (`--c-btn-bg`).
  final Color btnBg;

  /// Active control button background (`--c-btn-bg-active`).
  final Color btnBgActive;

  /// Control button text (`--c-btn-text`).
  final Color btnText;

  /// Active control button text (`--c-btn-text-active`).
  final Color btnTextActive;

  /// Slider track background (`--c-track-bg`).
  final Color trackBg;

  /// Slider track fill (`--c-track-fill`).
  final Color trackFill;

  /// Mock surface background (`--c-mock-bg`).
  final Color mockBg;

  /// Mock surface 1px ring (`--c-mock-border`).
  final Color mockBorder;

  /// Mock chip background (`--c-mock-chip-bg`).
  final Color mockChipBg;

  /// Mock chip hairline (`--c-mock-chip-line`).
  final Color mockChipLine;

  /// Mock body text (`--c-mock-text`).
  final Color mockText;

  /// Mock strong text (`--c-mock-text-strong`).
  final Color mockTextStrong;

  /// Mock placeholder text (`--c-mock-placeholder`).
  final Color mockPlaceholder;

  /// Mock tag text (`--c-mock-tag-text`).
  final Color mockTagText;

  /// Mock search text (`--c-mock-search-text`).
  final Color mockSearchText;

  /// Mock icon-button square (`--c-mock-square`).
  final Color mockSquare;

  /// Mock icon stroke color.
  final Color mockIcon;

  /// Shimmer base text color (`--shimmer-base`).
  final Color shimmerBase;

  /// Code block text (`--c-code-text`).
  final Color codeText;
}

/// Inherited access to the active token set + theme toggling.
class DemoTheme extends InheritedWidget {
  /// Creates the theme scope.
  const DemoTheme({
    super.key,
    required this.tokens,
    required this.isDark,
    required this.toggle,
    required super.child,
  });

  /// Active tokens.
  final DemoTokens tokens;

  /// Whether the dark set is active.
  final bool isDark;

  /// Switches dark/light.
  final VoidCallback toggle;

  /// Lookup.
  static DemoTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoTheme>()!;

  @override
  bool updateShouldNotify(DemoTheme oldWidget) =>
      oldWidget.tokens != tokens || oldWidget.isDark != isDark;
}
