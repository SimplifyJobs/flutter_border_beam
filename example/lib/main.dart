import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter/material.dart';

import 'src/demo_theme.dart';
import 'src/mocks.dart';
import 'src/playground.dart';

void main() => runApp(const BorderBeamDemoApp());

/// The flutter_border_beam gallery — a Flutter recreation of the original React
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CenteredColumn(
                  maxWidth: 560,
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
                    const _SectionTitle('Themed'),
                    const _SectionCaption(
                      'One BorderBeamTheme above all three — each card sets '
                      'only its variant and inherits ocean + squircle 20.',
                    ),
                    const SizedBox(height: 16),
                    const _ThemedExamples(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Rest between sweeps'),
                    const _SectionCaption(
                      'cycleGap parks the beam at the end of its travel and '
                      'fades it away before the next sweep starts.',
                    ),
                    const SizedBox(height: 16),
                    const _CycleGapExample(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Partial contours'),
                    const _SectionCaption(
                      'One segment across rotate, line, and pulse, plus a '
                      'full line that bends around its adjacent corners.',
                    ),
                    const SizedBox(height: 16),
                    const _PartialContourExamples(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Palettes'),
                    const _SectionCaption(
                      'The eleven presets, each on the same card. Custom, '
                      'seeded, and blended palettes live in the playground.',
                    ),
                    const SizedBox(height: 16),
                    const _PaletteExamples(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Surfaces'),
                    const _SectionCaption(
                      'The beam without the wrapper: a decoration in a '
                      'Container, and the focus, hover, and press wrappers '
                      'that light one on an interaction.',
                    ),
                    const SizedBox(height: 16),
                    const _SurfaceExamples(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Motion'),
                    const _SectionCaption(
                      'Direction, beam count, ring segments, and the comet '
                      'tail — one card each.',
                    ),
                    const SizedBox(height: 16),
                    const _MotionExamples(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Driven progress'),
                    const _SectionCaption(
                      'progress: parks the sweep where a value says, turning '
                      'the ring into a readout. The clock keeps running, so '
                      'the beam stays lit rather than frozen.',
                    ),
                    const SizedBox(height: 16),
                    const _ProgressExample(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Sync'),
                    const _SectionCaption(
                      'One clock for four beams: BeamSync spaces them with '
                      'phaseOffset instead of letting four tickers drift.',
                    ),
                    const SizedBox(height: 16),
                    const _SyncExamples(),
                  ],
                ),
                const SizedBox(height: 56),
                const _CenteredColumn(
                  maxWidth: 1040,
                  children: [
                    _SectionTitle('Playground'),
                    SizedBox(height: 16),
                    PlaygroundSection(),
                  ],
                ),
                const SizedBox(height: 56),
                const _CenteredColumn(
                  maxWidth: 560,
                  children: [_Footer(), SizedBox(height: 24)],
                ),
              ],
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

/// A page section held to [maxWidth] and centered — the gallery reads at
/// 560, the playground needs room for two previews beside its controls.
class _CenteredColumn extends StatelessWidget {
  const _CenteredColumn({required this.maxWidth, required this.children});

  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
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

class _SectionCaption extends StatelessWidget {
  const _SectionCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: t.muted,
          decoration: TextDecoration.none,
        ),
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
            style: BeamStyle(theme: beamTheme),
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
                  style: BeamStyle(theme: beamTheme),
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
                  style: BeamStyle(theme: beamTheme),
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
            style: BeamStyle(theme: beamTheme),
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
                  style: BeamStyle(theme: beamTheme),
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
                  style: BeamStyle(theme: beamTheme),
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

// Defaults handed to the Themed section's three cards. Not const: building a
// BorderRadius from a number is a runtime construction, so BeamShape.circular
// cannot be const either.
final BorderBeamThemeData _galleryThemeData = BorderBeamThemeData(
  style: const BeamStyle(colors: BeamColors.ocean),
  shape: BeamShape.circular(20, superellipse: true),
  timing: const BeamTiming(cycle: Duration(milliseconds: 2600)),
);

/// Three variants under one [BorderBeamTheme]: each beam sets nothing but
/// its own variant, so colors, shape, and cycle all come from the theme.
class _ThemedExamples extends StatelessWidget {
  const _ThemedExamples();

  @override
  Widget build(BuildContext context) {
    return BorderBeamTheme(
      data: _galleryThemeData,
      child: Row(
        children: [
          for (final entry in const [
            (label: 'rotate', variant: BeamVariant.rotate),
            (label: 'small', variant: BeamVariant.small),
            (label: 'pulseInside', variant: BeamVariant.pulseInside),
          ]) ...[
            if (entry.label != 'rotate') const SizedBox(width: 16),
            Expanded(
              child: ExampleFrame(
                height: 150,
                clip: false,
                child: SizedBox(
                  height: 84,
                  child: BorderBeam(
                    variant: entry.variant,
                    child: _ThemedCard(label: entry.label),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The surface the themed cards wrap — squircle 20, matching the theme's
/// shape, since a beam never reads its child's decoration.
class _ThemedCard extends StatelessWidget {
  const _ThemedCard({required this.label, this.radius = 20});

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      decoration: ShapeDecoration(
        color: t.mockBg,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: t.mockBorder),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: t.mockText,
          fontFamily: 'Menlo',
          fontFamilyFallback: const ['Courier New', 'monospace'],
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// A beam that rests between sweeps instead of running one straight into the
/// next.
class _CycleGapExample extends StatelessWidget {
  const _CycleGapExample();

  @override
  Widget build(BuildContext context) {
    final theme = DemoTheme.of(context);
    return ExampleFrame(
      child: BorderBeam.rotate(
        style: BeamStyle(
          theme: theme.isDark ? BeamTheme.dark : BeamTheme.light,
        ),
        borderRadius: 20,
        timing: const BeamTiming(cycleGap: Duration(milliseconds: 900)),
        child: const MockChatInput(),
      ),
    );
  }
}

/// A half-phone segment across the three painting families, beside a
/// segment-free line using border-path corner wrapping.
class _PartialContourExamples extends StatelessWidget {
  const _PartialContourExamples();

  static const BeamShape _halfShape = BeamShape.all(
    36,
    segment: BeamSegment.bottomHalf,
  );

  @override
  Widget build(BuildContext context) => ExampleFrame(
    height: 370,
    clip: false,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(
            width: 180,
            height: 320,
            child: BorderBeam.rotate(
              colors: BeamColors.aurora,
              shape: _halfShape,
              child: _ThemedCard(label: 'Half phone', radius: 36),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: BorderBeam.line(
                    colors: BeamColors.ocean,
                    shape: _halfShape,
                    child: const _ThemedCard(
                      label: 'Half phone · line',
                      radius: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: BorderBeam.pulseInside(
                    colors: BeamColors.sunset,
                    shape: _halfShape,
                    child: const _ThemedCard(
                      label: 'Half phone · pulse',
                      radius: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Expanded(
                  child: BorderBeam.line(
                    colors: BeamColors.neon,
                    shape: BeamShape.all(
                      28,
                      edge: BeamEdge.bottom,
                      wrapCorners: true,
                    ),
                    child: _ThemedCard(label: 'Corner wrap', radius: 28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The eleven palette presets, one small card each.
class _PaletteExamples extends StatelessWidget {
  const _PaletteExamples();

  static const List<(String, BeamColors)> _presets = [
    ('colorful', BeamColors.colorful),
    ('mono', BeamColors.mono),
    ('ocean', BeamColors.ocean),
    ('sunset', BeamColors.sunset),
    ('aurora', BeamColors.aurora),
    ('neon', BeamColors.neon),
    ('candy', BeamColors.candy),
    ('ember', BeamColors.ember),
    ('ice', BeamColors.ice),
    ('gold', BeamColors.gold),
    ('holographic', BeamColors.holographic),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Three cards a row on the gallery column, two on a phone.
      final columns = constraints.maxWidth >= 420 ? 3 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (label, colors) in _presets)
            SizedBox(
              width: width,
              height: 64,
              child: BorderBeam.rotate(
                colors: colors,
                shape: const BeamShape.all(14, superellipse: true),
                child: _ThemedCard(label: label, radius: 14),
              ),
            ),
        ],
      );
    },
  );
}

/// The beam reached through something other than the `BorderBeam` wrapper:
/// a decoration, and the three interaction wrappers.
class _SurfaceExamples extends StatelessWidget {
  const _SurfaceExamples();

  @override
  Widget build(BuildContext context) {
    final theme = DemoTheme.of(context);
    final t = theme.tokens;
    final brightness = theme.isDark ? Brightness.dark : Brightness.light;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ExampleFrame(
                height: 150,
                child: Container(
                  width: 190,
                  height: 72,
                  foregroundDecoration: BeamDecoration(
                    variant: BeamVariant.rotate,
                    brightness: brightness,
                    colors: BeamColors.ocean,
                    borderRadius: 16,
                  ),
                  decoration: ShapeDecoration(
                    color: t.mockBg,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: t.mockBorder),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _CardLabel('BeamDecoration'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ExampleFrame(
                height: 150,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BeamFocusRing(
                      borderRadius: 12,
                      alwaysShow: true,
                      child: MockFocusField(),
                    ),
                    const SizedBox(height: 10),
                    _CardLabel('BeamFocusRing'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ExampleFrame(
                height: 150,
                child: BeamHover(
                  borderRadius: 16,
                  colors: BeamColors.aurora,
                  child: SizedBox(
                    width: 190,
                    height: 72,
                    child: _ThemedCard(label: 'BeamHover', radius: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ExampleFrame(
                height: 150,
                child: BeamPress(
                  borderRadius: 16,
                  colors: BeamColors.ember,
                  child: SizedBox(
                    width: 190,
                    height: 72,
                    child: _ThemedCard(label: 'BeamPress', radius: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Direction, multi-beam, segments, and comet, one card each.
class _MotionExamples extends StatelessWidget {
  const _MotionExamples();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 420 ? 3 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      Widget cell(String label, Widget beam) =>
          SizedBox(width: width, height: 72, child: beam);
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          cell(
            'reverse',
            const BorderBeam.rotate(
              colors: BeamColors.ocean,
              shape: BeamShape.all(16, superellipse: true),
              timing: BeamTiming(direction: BeamDirection.reverse),
              child: _ThemedCard(label: 'reverse', radius: 16),
            ),
          ),
          cell(
            'bounce',
            const BorderBeam.rotate(
              colors: BeamColors.sunset,
              shape: BeamShape.all(16, superellipse: true),
              timing: BeamTiming(direction: BeamDirection.bounce),
              child: _ThemedCard(label: 'bounce', radius: 16),
            ),
          ),
          cell(
            'beams 3',
            const BorderBeam.rotate(
              colors: BeamColors.neon,
              shape: BeamShape.all(16, superellipse: true),
              timing: BeamTiming(beamCount: 3),
              child: _ThemedCard(label: 'beamCount 3', radius: 16),
            ),
          ),
          cell(
            'segments 8',
            const BorderBeam.rotate(
              colors: BeamColors.ice,
              shape: BeamShape.all(16, superellipse: true),
              style: BeamStyle(segments: 8),
              child: _ThemedCard(label: 'segments 8', radius: 16),
            ),
          ),
          cell(
            'comet',
            const BorderBeam.rotate(
              colors: BeamColors.aurora,
              shape: BeamShape.all(16, superellipse: true),
              style: BeamStyle(comet: true, sparkle: 0.4),
              child: _ThemedCard(label: 'comet', radius: 16),
            ),
          ),
        ],
      );
    },
  );
}

/// A rotate ring parked by a value instead of the clock: the controller
/// loops 0→1, and the beam sits wherever it says.
class _ProgressExample extends StatefulWidget {
  const _ProgressExample();

  @override
  State<_ProgressExample> createState() => _ProgressExampleState();
}

class _ProgressExampleState extends State<_ProgressExample>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExampleFrame(
    height: 170,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => SizedBox(
        width: 250,
        height: 84,
        child: BorderBeam.rotate(
          colors: BeamColors.aurora,
          shape: const BeamShape.all(16, superellipse: true),
          progress: _controller.value,
          child: _ThemedCard(
            label: 'progress ${_controller.value.toStringAsFixed(2)}',
            radius: 16,
          ),
        ),
      ),
    ),
  );
}

/// Four cards on one shared clock, a quarter of a cycle apart.
class _SyncExamples extends StatelessWidget {
  const _SyncExamples();

  static const int _count = 4;

  @override
  Widget build(BuildContext context) => ExampleFrame(
    height: 150,
    child: BeamSync(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < _count; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 76,
                  child: BorderBeam.rotate(
                    colors: BeamColors.ocean,
                    shape: const BeamShape.all(14, superellipse: true),
                    timing: BeamTiming(phaseOffset: i / _count),
                    child: _ThemedCard(label: '${i + 1}', radius: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// A caption under a surface example.
class _CardLabel extends StatelessWidget {
  const _CardLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: t.mockText,
        fontFamily: 'Menlo',
        fontFamilyFallback: const ['Courier New', 'monospace'],
        decoration: TextDecoration.none,
      ),
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
          'Flutter port · flutter_border_beam package',
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
