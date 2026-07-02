import 'package:border_beam/border_beam.dart';
import 'package:flutter/material.dart';

import 'src/demo_theme.dart';
import 'src/mocks.dart';
import 'src/playground.dart';

void main() => runApp(const BorderBeamDemoApp());

/// The border_beam gallery — a Flutter recreation of the original React
/// demo (https://beam.jakubantalik.com): hero, Rotate/Pulse example tabs,
/// and an interactive playground, styled with the demo's own tokens instead
/// of Material defaults.
class BorderBeamDemoApp extends StatefulWidget {
  /// Const constructor.
  const BorderBeamDemoApp({super.key});

  @override
  State<BorderBeamDemoApp> createState() => _BorderBeamDemoAppState();
}

class _BorderBeamDemoAppState extends State<BorderBeamDemoApp> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    final tokens = _dark ? DemoTokens.dark : DemoTokens.light;
    return DemoTheme(
      tokens: tokens,
      isDark: _dark,
      toggle: () => setState(() => _dark = !_dark),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: _dark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: tokens.bg,
        ),
        home: const _DemoPage(),
      ),
    );
  }
}

class _DemoPage extends StatefulWidget {
  const _DemoPage();

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  bool _pulseTab = false;

  @override
  Widget build(BuildContext context) {
    final theme = DemoTheme.of(context);
    final t = theme.tokens;
    return ColoredBox(
      color: t.bg,
      child: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false, overscroll: false),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(onToggleTheme: theme.toggle, isDark: theme.isDark),
                    const SizedBox(height: 36),
                    Center(
                      child: PillTabBar(
                        tabs: const ['Rotate', 'Pulse'],
                        index: _pulseTab ? 1 : 0,
                        onChanged: (i) => setState(() => _pulseTab = i == 1),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _pulseTab
                          ? const _PulseExamples(key: ValueKey('pulse'))
                          : const _RotateExamples(key: ValueKey('rotate')),
                    ),
                    const SizedBox(height: 56),
                    const _SectionTitle('Playground'),
                    const SizedBox(height: 16),
                    const PlaygroundSection(),
                    const SizedBox(height: 56),
                    const _Footer(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onToggleTheme, required this.isDark});

  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: DemoIconButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            onTap: onToggleTheme,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Border beam',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: t.heading,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Animated border beam widgets for Flutter',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: t.subtitle,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: t.heading,
        decoration: TextDecoration.none,
      ),
    );
  }
}

/// A frame around each example, matching the demo's `.example-cell`.
class ExampleFrame extends StatelessWidget {
  /// Creates a frame.
  const ExampleFrame({
    super.key,
    required this.child,
    this.height = 220,
    this.clip = true,
  });

  /// Framed content, centered.
  final Widget child;

  /// Frame height.
  final double height;

  /// Whether to clip (pulse-outside frames must NOT clip the halo).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final theme = DemoTheme.of(context);
    final t = theme.tokens;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.isDark ? t.surface : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: Center(child: child),
    );
  }
}

class _RotateExamples extends StatelessWidget {
  const _RotateExamples({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DemoTheme.of(context);
    final beamTheme = theme.isDark ? BeamTheme.dark : BeamTheme.light;
    return Column(
      children: [
        ExampleFrame(
          child: BorderBeam.rotate(
            theme: beamTheme,
            borderRadius: 20,
            child: const MockChatInput(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ExampleFrame(
                height: 140,
                child: BorderBeam.small(
                  theme: beamTheme,
                  borderRadius: 20,
                  child: const MockIconButton(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ExampleFrame(
                height: 140,
                child: BorderBeam.line(
                  theme: beamTheme,
                  borderRadius: 20,
                  child: const MockSearchBar(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PulseExamples extends StatelessWidget {
  const _PulseExamples({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DemoTheme.of(context);
    final beamTheme = theme.isDark ? BeamTheme.dark : BeamTheme.light;
    return Column(
      children: [
        ExampleFrame(
          height: 300,
          clip: false,
          child: BorderBeam.pulseInside(
            theme: beamTheme,
            borderRadius: 20,
            child: const MockWorkingCard(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ExampleFrame(
                height: 160,
                clip: false,
                child: BorderBeam.pulseInside(
                  theme: beamTheme,
                  borderRadius: 20,
                  child: const MockSubscribeButton(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ExampleFrame(
                height: 220,
                clip: false,
                child: BorderBeam.pulseOutside(
                  theme: beamTheme,
                  borderRadius: 20,
                  child: const MockChatInput(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    final muted = TextStyle(
      fontSize: 13,
      color: t.muted,
      decoration: TextDecoration.none,
    );
    return Column(
      children: [
        Text(
          'Original border-beam by Jakub Antalik',
          textAlign: TextAlign.center,
          style: muted,
        ),
        const SizedBox(height: 4),
        Text(
          'Flutter port · border_beam package',
          textAlign: TextAlign.center,
          style: muted.copyWith(color: t.muted.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

/// The animated pill tab bar of the demo (`.tab-nav`).
class PillTabBar extends StatelessWidget {
  /// Creates the tab bar.
  const PillTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  /// Tab labels.
  final List<String> tabs;

  /// Selected index.
  final int index;

  /// Selection callback.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.tabsBarBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, label) in tabs.indexed)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: const Cubic(0.22, 1, 0.36, 1),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == index ? t.tabsPillBg : null,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: i == index ? t.tabsTextActive : t.tabsTextMuted,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A minimal icon button matching the demo's `.icon-btn`.
class DemoIconButton extends StatelessWidget {
  /// Creates the button.
  const DemoIconButton({super.key, required this.icon, required this.onTap});

  /// Glyph.
  final IconData icon;

  /// Tap callback.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: t.btnBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 16, color: t.btnText),
      ),
    );
  }
}
