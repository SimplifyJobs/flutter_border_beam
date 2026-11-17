import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';

import 'controls.dart';
import 'tokens.dart';
import 'wave_scenes.dart';

/// The distortion wave screen: the three wave demos, swiped between, each a
/// screen made for one type of wave.
///
/// On a phone the demo fills the whole screen, so the wave runs on the
/// device's own corners, and the options — the demo, its palette, a bar that
/// holds the wave, and a page opened on a `DistortionWaveRoute` — slide in
/// from a tab on the right edge. On a wide screen they sit in a side bar
/// beside a framed phone.
class WavePage extends StatefulWidget {
  /// Creates the screen.
  const WavePage({super.key, required this.onToggleTheme});

  /// Flips the app theme.
  final VoidCallback onToggleTheme;

  @override
  State<WavePage> createState() => _WavePageState();
}

class _WavePageState extends State<WavePage>
    with SingleTickerProviderStateMixin {
  static const _demos = WaveDemo.values;

  final PageController _pages = PageController();
  final ValueNotifier<double> _page = ValueNotifier<double>(0);
  int _index = 0;

  // One wave per demo, each with its own palette, starting on its type's.
  final List<DistortionWaveController> _waves = [
    for (final _ in _demos) DistortionWaveController(),
  ];
  final List<String> _palettes = [for (final demo in _demos) demo.palette];

  // The drag on the scrub bar: which demo it holds, and where. Null between
  // drags.
  final ValueNotifier<({int demo, double at})?> _scrub = ValueNotifier(null);

  // Where the scrub bar's thumb sits: the drag, or else the wave on screen
  // as it plays, followed by a ticker that runs only while the wave does.
  final ValueNotifier<double> _shown = ValueNotifier<double>(0);
  late final Ticker _follow = createTicker((_) => _sync());

  DistortionWaveController get _wave => _waves[_index];

  @override
  void initState() {
    super.initState();
    _pages.addListener(() {
      final page = _pages.page ?? 0;
      _page.value = page;
      if (page.round() != _index) {
        setState(() => _index = page.round());
        _sync();
      }
    });
    for (final wave in _waves) {
      wave.addListener(_sync);
    }
  }

  @override
  void dispose() {
    _follow.dispose();
    for (final wave in _waves) {
      wave.dispose();
    }
    _pages.dispose();
    _page.dispose();
    _scrub.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _sync() {
    _shown.value = _scrub.value?.at ?? _wave.progress;
    if (_wave.isRunning) {
      if (!_follow.isActive) _follow.start();
    } else if (_follow.isActive) {
      _follow.stop();
    }
  }

  void _scrubStart(double at) {
    _scrub.value = (demo: _index, at: at);
    _sync();
  }

  void _scrubTo(double at) {
    if (_scrub.value == null) return;
    _scrub.value = (demo: _index, at: at);
    _sync();
  }

  // Let go, the wave plays on from where it was held to the nearer side.
  void _scrubEnd() {
    final scrub = _scrub.value;
    if (scrub == null) return;
    final wave = _waves[scrub.demo]..seek(scrub.at);
    if (scrub.at >= 0.5) {
      wave.reveal();
    } else {
      wave.collapse();
    }
    _scrub.value = null;
    _sync();
  }

  void _select(int index) => _pages.animateToPage(
    index,
    duration: const Duration(milliseconds: 420),
    curve: easeOut,
  );

  // A full page from the Route button, on a ring — the center wave suits a
  // small round-ish source — in the palette on screen.
  void _openRoute(BuildContext context) {
    Navigator.of(context).push(
      DistortionWaveRoute<void>(
        source: WaveSource.of(context),
        type: WaveType.center,
        palette: wavePalettes[_palettes[_index]],
        builder: (_) => const WaveRoutePage(),
      ),
    );
  }

  // The options panel, on a phone: slid in from the right edge.
  bool _panelOpen = false;

  void _showPanel() => setState(() => _panelOpen = true);

  void _hidePanel() => setState(() => _panelOpen = false);

  /// Wider than this, the options sit in a side bar beside a framed phone;
  /// narrower, the demo fills the screen and the options slide in.
  static const double _wideBreakpoint = 840;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Material(
        color: t.bg,
        child: wide ? _wideLayout(t, dark) : _phoneLayout(t, dark),
      ),
    );
  }

  // A wide screen: the framed demo in the middle, the options docked on the
  // right.
  Widget _wideLayout(Tokens t, bool dark) => Row(
    children: [
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [t.spot, t.bg], radius: 0.5),
          ),
          child: SafeArea(right: false, child: _stage(framed: true)),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: t.bg,
          border: Border(left: BorderSide(color: t.surfaceLine)),
        ),
        child: SizedBox(
          width: 340,
          child: SafeArea(left: false, child: _panel(t, dark, docked: true)),
        ),
      ),
    ],
  );

  // A phone: the demo fills the whole screen, edge to edge, and the options
  // slide in from a tab on the right edge. While the scrub bar is held the
  // panel turns see-through, so the whole wave shows as it is scrubbed.
  Widget _phoneLayout(Tokens t, bool dark) {
    final width = MediaQuery.sizeOf(context).width;
    return Stack(
      children: [
        Positioned.fill(child: _stage(framed: false)),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(child: _PanelTab(onTap: _showPanel)),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_panelOpen,
            child: ValueListenableBuilder<({int demo, double at})?>(
              valueListenable: _scrub,
              builder: (context, scrub, panel) => AnimatedOpacity(
                opacity: !_panelOpen ? 0 : (scrub != null ? 0.12 : 1),
                duration: const Duration(milliseconds: 180),
                curve: easeOut,
                child: panel,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _hidePanel,
                      child: const ColoredBox(color: Color(0x40000000)),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: (width * 0.86).clamp(0.0, 340.0),
                    child: AnimatedSlide(
                      offset: _panelOpen ? Offset.zero : const Offset(1, 0),
                      duration: const Duration(milliseconds: 280),
                      curve: easeOut,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.bg,
                          border: Border(
                            left: BorderSide(color: t.surfaceLine),
                          ),
                        ),
                        child: SafeArea(
                          left: false,
                          child: _panel(t, dark, docked: false),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // The swipeable demos.
  Widget _stage({required bool framed}) => PageView.builder(
    controller: _pages,
    itemCount: _demos.length,
    itemBuilder: (context, i) => framed ? _framed(i) : _fullScreen(i),
  );

  // A demo held, while the scrub bar is dragged on it.
  double? _heldFor(int i, ({int demo, double at})? scrub) =>
      scrub != null && scrub.demo == i ? scrub.at : null;

  Widget _demo(int i, {required bool fullScreen}) =>
      ValueListenableBuilder<({int demo, double at})?>(
        valueListenable: _scrub,
        builder: (context, scrub, _) => DemoWave(
          demo: _demos[i],
          controller: _waves[i],
          palette: wavePalettes[_palettes[i]]!,
          progress: _heldFor(i, scrub),
          fullScreen: fullScreen,
        ),
      );

  // On a phone: the send and step demos fill the screen; the success sheet
  // sits at the bottom at the height the center wave is tuned for.
  Widget _fullScreen(int i) {
    if (_demos[i] != WaveDemo.success) return _demo(i, fullScreen: true);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 420,
            height: sheetHeight,
            child: _demo(i, fullScreen: false),
          ),
        ),
      ),
    );
  }

  // On a wide screen: a framed phone as tall as the stage allows, or the
  // sheet.
  Widget _framed(int i) => LayoutBuilder(
    builder: (context, box) {
      final demo = _demos[i];
      final height = demo == WaveDemo.success
          ? sheetHeight
          : (box.maxHeight - 48).clamp(560.0, 860.0);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: demo == WaveDemo.success ? 400 : height * 0.46,
              height: height,
              child: _demo(i, fullScreen: false),
            ),
          ),
        ),
      );
    },
  );

  // The options: which demo, its palette, the scrub bar, the route.
  Widget _panel(Tokens t, bool dark, {required bool docked}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Distortion Wave',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _headerStyle(t),
              ),
            ),
            RoundToggle(
              key: const ValueKey('theme-toggle'),
              icon: dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              label: dark ? 'Light theme' : 'Dark theme',
              onTap: widget.onToggleTheme,
            ),
            const SizedBox(width: 8),
            RoundToggle(
              key: const ValueKey('wave-close'),
              icon: Icons.arrow_back_rounded,
              label: 'Back to Border Beam',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            if (!docked) ...[
              const SizedBox(width: 8),
              RoundToggle(
                key: const ValueKey('panel-close'),
                icon: Icons.chevron_right_rounded,
                label: 'Hide options',
                onTap: _hidePanel,
              ),
            ],
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(t, 'Demo'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EffectSelector(
                  labels: [for (final demo in _demos) _typeName(demo.type)],
                  page: _page,
                  onSelect: _select,
                ),
              ),
              const SizedBox(height: 14),
              _caption(t),
              const SizedBox(height: 22),
              _label(t, 'Palette'),
              SwatchRow(
                names: wavePalettes.keys.toList(),
                gradientOf: waveSwatch,
                selected: _palettes[_index],
                onSelect: (name) => setState(() => _palettes[_index] = name),
              ),
              const SizedBox(height: 22),
              _label(t, 'Hold the wave'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ScrubBar(
                  value: _shown,
                  onStart: _scrubStart,
                  onChanged: _scrubTo,
                  onEnd: _scrubEnd,
                ),
              ),
              const SizedBox(height: 26),
              _label(t, 'Between routes'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  // An anchor, so the route's wave leans with the touch.
                  child: DistortionWaveAnchor(
                    child: Builder(
                      builder: (context) => PillButton(
                        key: const ValueKey('route-button'),
                        icon: Icons.north_east_rounded,
                        label: 'Open a page',
                        semanticLabel: 'Open a page on a wave',
                        onTap: () => _openRoute(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _label(Tokens t, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: t.faint,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _caption(Tokens t) {
    final demo = _demos[_index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            demo.title,
            style: TextStyle(
              color: t.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            demo.blurb,
            style: TextStyle(color: t.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'WaveType.${demo.type.name}  ·  '
            '${wavePaletteCode(_palettes[_index])}',
            style: _codeStyle(t),
          ),
          const SizedBox(height: 4),
          // What a full-screen wave follows: the display's corners, as the
          // platform (or, on iOS, the app delegate) reports them.
          Text(_cornersLabel(context), style: _codeStyle(t)),
        ],
      ),
    );
  }
}

/// The tab on the right edge of a phone that slides the options in. Slim
/// enough to sit in every demo's side margin.
class _PanelTab extends StatelessWidget {
  const _PanelTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Show options',
      child: Container(
        width: 20,
        height: 64,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(12),
          ),
          border: Border.all(color: t.surfaceLine),
        ),
        child: Icon(Icons.chevron_left_rounded, size: 18, color: t.icon),
      ),
    );
  }
}

/// The full page the Route button pushes. Its Close pill sits exactly where
/// Route was: the center wave leaves its source alone, so one turns into the
/// other in plain view.
class WaveRoutePage extends StatelessWidget {
  /// Creates the page.
  const WaveRoutePage({super.key});

  static const _code = '''
Navigator.of(context).push(
  DistortionWaveRoute(
    source: WaveSource.of(context),
    type: WaveType.center,
    builder: (_) => const RoutePage(),
  ),
);''';

  static const _points = [
    (
      Icons.touch_app_outlined,
      'Opens from WaveSource.of(context): the button that pushed it, '
          'leaning toward the touch.',
    ),
    (
      Icons.photo_outlined,
      'The page below holds still; the wave bends a picture of it.',
    ),
    (Icons.undo_rounded, 'Popping collapses the wave back into the button.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Material(
      color: t.bg,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Route',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _headerStyle(t),
                        ),
                      ),
                      PillButton(
                        key: const ValueKey('route-close'),
                        icon: Icons.close_rounded,
                        label: 'Close',
                        semanticLabel: 'Close the page',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      // Room for the two round buttons beside Route on the
                      // page below, so Close lands where Route was.
                      const SizedBox(width: 8 + 36 + 8 + 36),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A page from a button',
                          style: TextStyle(
                            color: t.text,
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.8,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'DistortionWaveRoute opens a page from the widget '
                          'that pushed it, and collapses back into it when '
                          'the page pops.',
                          style: TextStyle(
                            color: t.muted,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: ShapeDecoration(
                            color: t.surface,
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: t.surfaceLine),
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              _code,
                              style: _codeStyle(t)
                                  .copyWith(color: t.surfaceText, height: 1.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        for (final (icon, text) in _points) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 18, color: t.muted),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: t.muted,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _headerStyle(Tokens t) => TextStyle(
  color: t.text,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.3,
);

TextStyle _codeStyle(Tokens t) => TextStyle(
  color: t.faint,
  fontSize: 12,
  fontFamily: 'Menlo',
  fontFamilyFallback: const ['monospace', 'Consolas'],
);

/// The display's corner radii the waves follow, top-left clockwise, or a
/// note that none are reported.
String _cornersLabel(BuildContext context) {
  final r = MediaQuery.maybeDisplayCornerRadiiOf(context);
  if (r == null) return 'display corners: not reported';
  String pt(Radius c) => c.x.toStringAsFixed(c.x % 1 == 0 ? 0 : 1);
  return 'display corners: ${pt(r.topLeft)} · ${pt(r.topRight)} · '
      '${pt(r.bottomRight)} · ${pt(r.bottomLeft)} pt';
}

String _typeName(WaveType type) =>
    type.name[0].toUpperCase() + type.name.substring(1);
