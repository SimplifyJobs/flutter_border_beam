import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter/material.dart';

import 'src/demo_theme.dart';
import 'src/mocks.dart';
import 'src/playground.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the beam shader before the first frame, so no beam on the page
  // waits for it.
  await BorderBeam.precache();
  runApp(const BorderBeamDemoApp());
}

/// The flutter_border_beam gallery — a Flutter recreation of the original React
/// demo (https://beam.jakubantalik.com): hero, Rotate/Pulse example tabs,
/// the newer effects, and an interactive playground, styled with the demo's
/// own tokens instead of Material defaults.
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
        // Beams default to BeamTheme.auto, which reads this brightness — so
        // the gallery's beams follow the toggle without a `theme:` of their
        // own.
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
                    const _SectionTitle('Flow, spin, shimmer, charge'),
                    const _SectionCaption(
                      'Four effects beyond the original library: colours '
                      'streaming round an assistant, a spinning gradient '
                      'ring, a glint across a call to action, and a border '
                      'that fills.',
                    ),
                    const SizedBox(height: 16),
                    const _NewEffectExamples(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Every effect'),
                    const _SectionCaption(
                      'BeamEffect.values on the same card. One shader draws '
                      'all eight in a single pass, so pick for the look, not '
                      'the cost.',
                    ),
                    const SizedBox(height: 16),
                    const _EffectGrid(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Driven progress'),
                    const _SectionCaption(
                      'progress: places the sweep where a value says. Charge '
                      'fills the border to it; rotate parks a glowing ring on '
                      'it. The clock keeps running underneath, so the beam '
                      'stays lit rather than frozen.',
                    ),
                    const SizedBox(height: 16),
                    const _ProgressExamples(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Palettes'),
                    const _SectionCaption(
                      'All nineteen entries of BeamColors.presets, each on the '
                      'same card — eight of them new. Custom, seeded, and '
                      'blended palettes live in the playground.',
                    ),
                    const SizedBox(height: 16),
                    const _PaletteExamples(),
                    const SizedBox(height: 40),
                    const _SectionTitle('Themed'),
                    const _SectionCaption(
                      'One BorderBeamTheme above all three — each card sets '
                      'only its effect and inherits ocean + squircle 20.',
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
                      'A BeamSegment masks the border: the same lower half '
                      'across rotate, line, and pulse, and spin held to the '
                      'bottom edge and its two corners.',
                    ),
                    const SizedBox(height: 16),
                    const _PartialContourExamples(),
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
                      'Direction, beam count, dashes, the comet tail, and '
                      'glow — one card each.',
                    ),
                    const SizedBox(height: 16),
                    const _MotionExamples(),
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

  /// Whether to clip. Light that reaches outward — a halo, a comet, a
  /// positive ring offset — paints past the beam's bounds, so those frames
  /// must not clip it.
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

/// Lays [children] out in rows of equal-width cells: [wideColumns] a row
/// when the column is at least [breakpoint] wide, [narrowColumns] below it.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.children,
    this.wideColumns = 3,
    this.narrowColumns = 2,
    this.breakpoint = 420,
    this.spacing = 12,
    this.height = 64,
  });

  final List<Widget> children;
  final int wideColumns;
  final int narrowColumns;
  final double breakpoint;
  final double spacing;

  /// Cell height; null lets each cell size itself.
  final double? height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= breakpoint
          ? wideColumns
          : narrowColumns;
      final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: width, height: height, child: child),
        ],
      );
    },
  );
}

class _RotateExamples extends StatelessWidget {
  const _RotateExamples({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      ExampleFrame(
        child: BorderBeam(
          effect: BeamEffect.rotate(),
          borderRadius: 20,
          child: MockChatInput(),
        ),
      ),
      SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: ExampleFrame(
              height: 140,
              // The 0.1 `small` variant is rotate on a small box: the
              // beam scales its tail and glow to the surface.
              child: BorderBeam(
                effect: BeamEffect.rotate(),
                borderRadius: 18,
                child: MockIconButton(),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ExampleFrame(
              height: 140,
              child: BorderBeam(
                effect: BeamEffect.line(),
                borderRadius: 21,
                child: MockSearchBar(),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _PulseExamples extends StatelessWidget {
  const _PulseExamples({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      ExampleFrame(
        height: 300,
        child: BorderBeam(
          effect: BeamEffect.pulse(),
          borderRadius: 20,
          child: MockWorkingCard(),
        ),
      ),
      SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: ExampleFrame(
              height: 160,
              child: BorderBeam(
                effect: BeamEffect.pulse(),
                shape: BeamShape.stadium(),
                child: MockSubscribeButton(),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ExampleFrame(
              height: 220,
              // The halo breathes outside the card's bounds.
              clip: false,
              child: BorderBeam(
                effect: BeamEffect.halo(),
                borderRadius: 20,
                child: MockChatInput(),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Flow, spin, shimmer, and charge, each on the surface it suits.
class _NewEffectExamples extends StatelessWidget {
  const _NewEffectExamples();

  @override
  Widget build(BuildContext context) => const _Grid(
    wideColumns: 2,
    narrowColumns: 1,
    breakpoint: 480,
    spacing: 16,
    height: 150,
    children: [
      _LabelledFrame(
        label: 'flow · cosmic',
        child: BorderBeam(
          effect: BeamEffect.flow(),
          colors: BeamColors.cosmic,
          shape: BeamShape.stadium(),
          child: MockListeningCard(),
        ),
      ),
      _LabelledFrame(
        label: 'spin',
        child: BorderBeam(
          effect: BeamEffect.spin(),
          shape: BeamShape.stadium(),
          child: MockPillButton(
            label: 'Get started',
            icon: Icons.arrow_forward,
          ),
        ),
      ),
      _LabelledFrame(
        label: 'shimmer · gold',
        child: BorderBeam(
          effect: BeamEffect.shimmer(),
          colors: BeamColors.gold,
          shape: BeamShape.stadium(),
          child: MockPillButton(
            label: 'Upgrade to Pro',
            icon: Icons.auto_awesome,
          ),
        ),
      ),
      _LabelledFrame(
        label: 'charge · lagoon',
        child: BorderBeam(
          effect: BeamEffect.charge(),
          colors: BeamColors.lagoon,
          shape: BeamShape.stadium(),
          child: MockPillButton(
            label: 'Saving draft',
            icon: Icons.cloud_upload_outlined,
          ),
        ),
      ),
    ],
  );
}

/// An unclipped frame with a caption under its centered example.
class _LabelledFrame extends StatelessWidget {
  const _LabelledFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExampleFrame(
    height: 150,
    clip: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [child, const SizedBox(height: 14), _CardLabel(label)],
    ),
  );
}

/// Every effect with its defaults, on one card shape.
class _EffectGrid extends StatelessWidget {
  const _EffectGrid();

  @override
  Widget build(BuildContext context) => _Grid(
    wideColumns: 4,
    // The halo paints outside its card, so the cells keep their distance.
    spacing: 20,
    breakpoint: 480,
    children: [
      for (final effect in BeamEffect.values)
        BorderBeam(
          effect: effect,
          shape: const BeamShape.all(14, superellipse: true),
          child: _ThemedCard(label: effect.name, radius: 14),
        ),
    ],
  );
}

/// Charge filling an upload row to a looping value, and a rotate ring
/// parked on the same value.
class _ProgressExamples extends StatefulWidget {
  const _ProgressExamples();

  @override
  State<_ProgressExamples> createState() => _ProgressExamplesState();
}

class _ProgressExamplesState extends State<_ProgressExamples>
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

  // Fills over the first 80% of the loop and holds full for the rest, so
  // the finished state is on screen long enough to read.
  double get _upload =>
      Curves.easeInOut.transform((_controller.value / 0.8).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Column(
      children: [
        ExampleFrame(
          height: 150,
          child: BorderBeam(
            effect: const BeamEffect.charge(),
            colors: BeamColors.sky,
            borderRadius: 18,
            progress: _upload,
            child: MockUploadCard(progress: _upload),
          ),
        ),
        const SizedBox(height: 16),
        ExampleFrame(
          height: 150,
          child: SizedBox(
            width: 250,
            height: 84,
            child: BorderBeam(
              effect: const BeamEffect.rotate(),
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
      ],
    ),
  );
}

/// Every palette preset, one small card each; the eight added in 0.2 carry
/// a tag.
class _PaletteExamples extends StatelessWidget {
  const _PaletteExamples();

  static const Set<String> _added = {
    'lagoon',
    'dusk',
    'forest',
    'rose',
    'cosmic',
    'citrus',
    'sky',
    'lavender',
  };

  @override
  Widget build(BuildContext context) => _Grid(
    children: [
      for (final MapEntry(key: name, value: colors)
          in BeamColors.presets.entries)
        BorderBeam(
          effect: const BeamEffect.rotate(),
          colors: colors,
          shape: const BeamShape.all(14, superellipse: true),
          child: _ThemedCard(
            label: name,
            radius: 14,
            tag: _added.contains(name) ? 'new' : null,
          ),
        ),
    ],
  );
}

// Defaults handed to the Themed section's three cards — all const, since
// BeamShape.all stores its radius as a number.
const BorderBeamThemeData _galleryThemeData = BorderBeamThemeData(
  style: BeamStyle(colors: BeamColors.ocean),
  shape: BeamShape.all(20, superellipse: true),
  timing: BeamTiming(cycle: Duration(milliseconds: 2600)),
);

/// Three effects under one [BorderBeamTheme]: each beam sets nothing but
/// its own effect, so colors, shape, and cycle all come from the theme.
class _ThemedExamples extends StatelessWidget {
  const _ThemedExamples();

  @override
  Widget build(BuildContext context) {
    return BorderBeamTheme(
      data: _galleryThemeData,
      child: Row(
        children: [
          for (final (i, effect) in const [
            BeamEffect.rotate(),
            BeamEffect.flow(),
            BeamEffect.pulse(),
          ].indexed) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              child: ExampleFrame(
                height: 150,
                clip: false,
                child: SizedBox(
                  height: 84,
                  child: BorderBeam(
                    effect: effect,
                    child: _ThemedCard(label: 'themed ${effect.name}'),
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

/// The surface the themed cards wrap — squircle corners matching the beam's
/// shape, since a beam never reads its child's decoration.
class _ThemedCard extends StatelessWidget {
  const _ThemedCard({required this.label, this.radius = 20, this.tag});

  final String label;
  final double radius;

  /// An optional small caption under [label].
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    final style = TextStyle(
      fontSize: 12,
      color: t.mockText,
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Courier New', 'monospace'],
      decoration: TextDecoration.none,
    );
    return Container(
      decoration: ShapeDecoration(
        color: t.mockBg,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: t.mockBorder),
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          if (tag case final String text)
            Text(
              text,
              style: style.copyWith(fontSize: 10, color: t.mockPlaceholder),
            ),
        ],
      ),
    );
  }
}

/// A beam that rests between sweeps instead of running one straight into the
/// next.
class _CycleGapExample extends StatelessWidget {
  const _CycleGapExample();

  @override
  Widget build(BuildContext context) => const ExampleFrame(
    child: BorderBeam(
      effect: BeamEffect.rotate(),
      borderRadius: 20,
      timing: BeamTiming(cycleGap: Duration(milliseconds: 900)),
      child: MockChatInput(),
    ),
  );
}

/// One lower-half segment across three effects, beside spin held to the
/// bottom edge.
class _PartialContourExamples extends StatelessWidget {
  const _PartialContourExamples();

  static const BeamShape _halfShape = BeamShape.all(
    36,
    segment: BeamSegment.bottomHalf,
  );

  @override
  Widget build(BuildContext context) => const ExampleFrame(
    height: 370,
    clip: false,
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            height: 320,
            child: BorderBeam(
              effect: BeamEffect.rotate(),
              colors: BeamColors.aurora,
              shape: _halfShape,
              child: _ThemedCard(label: 'Half phone', radius: 36),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: BorderBeam(
                    effect: BeamEffect.line(),
                    colors: BeamColors.ocean,
                    shape: _halfShape,
                    child: _ThemedCard(label: 'Half phone · line', radius: 36),
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: BorderBeam(
                    effect: BeamEffect.pulse(),
                    colors: BeamColors.sunset,
                    shape: _halfShape,
                    child: _ThemedCard(label: 'Half phone · pulse', radius: 36),
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: BorderBeam(
                    effect: BeamEffect.spin(),
                    colors: BeamColors.neon,
                    shape: BeamShape.all(28, segment: BeamSegment.bottomEdge),
                    child: _ThemedCard(label: 'Bottom edge · spin', radius: 28),
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

/// The beam reached through something other than the `BorderBeam` wrapper:
/// a decoration, and the three interaction wrappers.
class _SurfaceExamples extends StatelessWidget {
  const _SurfaceExamples();

  @override
  Widget build(BuildContext context) {
    final theme = DemoTheme.of(context);
    final t = theme.tokens;
    // A decoration has no context, so it is told the brightness.
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
                    effect: const BeamEffect.rotate(),
                    brightness: brightness,
                    colors: BeamColors.ocean,
                    borderRadius: 16,
                  ),
                  decoration: ShapeDecoration(
                    color: t.mockBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: t.mockBorder),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const _CardLabel('BeamDecoration'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: ExampleFrame(
                height: 150,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Spin in ocean is the focus ring's own default.
                    BeamFocusRing(
                      borderRadius: 12,
                      alwaysShow: true,
                      child: MockFocusField(),
                    ),
                    SizedBox(height: 10),
                    _CardLabel('BeamFocusRing'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Row(
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
            SizedBox(width: 16),
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

/// Direction, beam count, dashes, comet, and glow, one card each.
class _MotionExamples extends StatelessWidget {
  const _MotionExamples();

  static const BeamShape _shape = BeamShape.all(16, superellipse: true);

  @override
  Widget build(BuildContext context) => const _Grid(
    height: 72,
    spacing: 16,
    children: [
      BorderBeam(
        effect: BeamEffect.rotate(),
        colors: BeamColors.ocean,
        shape: _shape,
        timing: BeamTiming(direction: BeamDirection.reverse),
        child: _ThemedCard(label: 'reverse', radius: 16),
      ),
      BorderBeam(
        effect: BeamEffect.rotate(),
        colors: BeamColors.sunset,
        shape: _shape,
        timing: BeamTiming(direction: BeamDirection.bounce),
        child: _ThemedCard(label: 'bounce', radius: 16),
      ),
      BorderBeam(
        effect: BeamEffect.rotate(count: 3),
        colors: BeamColors.neon,
        shape: _shape,
        child: _ThemedCard(label: 'count 3', radius: 16),
      ),
      BorderBeam(
        effect: BeamEffect.spin(),
        colors: BeamColors.ice,
        shape: BeamShape.all(16, superellipse: true, dashes: 8),
        child: _ThemedCard(label: 'dashes 8', radius: 16),
      ),
      BorderBeam(
        effect: BeamEffect.rotate(comet: true, length: 1.5),
        colors: BeamColors.dusk,
        shape: _shape,
        child: _ThemedCard(label: 'comet', radius: 16),
      ),
      BorderBeam(
        effect: BeamEffect.flow(),
        colors: BeamColors.rose,
        shape: _shape,
        style: BeamStyle(glow: 2),
        child: _ThemedCard(label: 'glow 2', radius: 16),
      ),
    ],
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
                  child: BorderBeam(
                    effect: const BeamEffect.rotate(),
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
