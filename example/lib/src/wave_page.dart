import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';

import 'controls.dart';
import 'tokens.dart';
import 'wave_scenes.dart';

/// The distortion wave screen: a stage you swipe between the three wave
/// demos, each a mock screen made for one type of wave, with a caption, a
/// type selector, the palettes, and a bar that scrubs the wave.
///
/// In the header, Route pushes a full page with a `DistortionWaveRoute`, and
/// the close button pops this one — which came in on a wave too.
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

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Material(
        color: t.bg,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 16, 0),
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
                        // An anchor, so the route's wave leans with the touch.
                        DistortionWaveAnchor(
                          child: Builder(
                            builder: (context) => PillButton(
                              key: const ValueKey('route-button'),
                              icon: Icons.north_east_rounded,
                              label: 'Route',
                              semanticLabel: 'Open a page on a wave',
                              onTap: () => _openRoute(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Where the home screen's wave button was, so the
                        // wave that brought this page in leaves it in place.
                        RoundToggle(
                          key: const ValueKey('wave-close'),
                          icon: Icons.close_rounded,
                          label: 'Back to Border Beam',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                        RoundToggle(
                          key: const ValueKey('theme-toggle'),
                          icon: dark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          label: dark ? 'Light theme' : 'Dark theme',
                          onTap: widget.onToggleTheme,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _stage(t)),
                  _caption(t),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: EffectSelector(
                      labels: [for (final demo in _demos) _label(demo.type)],
                      page: _page,
                      onSelect: _select,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwatchRow(
                    names: wavePalettes.keys.toList(),
                    gradientOf: waveSwatch,
                    selected: _palettes[_index],
                    onSelect: (name) =>
                        setState(() => _palettes[_index] = name),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ScrubBar(
                      value: _shown,
                      onStart: _scrubStart,
                      onChanged: _scrubTo,
                      onEnd: _scrubEnd,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The swipeable stage. Neighbouring pages dim and shrink a little as they
  // leave, as on the home screen.
  Widget _stage(Tokens t) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(colors: [t.spot, t.bg], radius: 0.5),
    ),
    child: LayoutBuilder(
      builder: (context, box) => PageView.builder(
        controller: _pages,
        itemCount: _demos.length,
        itemBuilder: (context, i) => ValueListenableBuilder<double>(
          valueListenable: _page,
          builder: (context, page, child) {
            final away = (page - i).abs().clamp(0.0, 1.0);
            return Opacity(
              opacity: 1 - away * 0.6,
              child: Transform.scale(scale: 1 - away * 0.08, child: child),
            );
          },
          // Scales down only when the stage is short.
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(fit: BoxFit.scaleDown, child: _exhibit(i, box)),
          ),
        ),
      ),
    ),
  );

  // One demo: a phone screen as tall as the stage allows, or the sheet at
  // the height the center wave is tuned for.
  Widget _exhibit(int i, BoxConstraints box) {
    final demo = _demos[i];
    final width = (box.maxWidth - 48).clamp(280.0, 360.0);
    final height = demo == WaveDemo.success
        ? sheetHeight
        : (box.maxHeight - 32).clamp(560.0, 720.0);
    return SizedBox(
      width: width,
      height: height,
      child: ValueListenableBuilder<({int demo, double at})?>(
        valueListenable: _scrub,
        builder: (context, scrub, _) => DemoWave(
          demo: demo,
          controller: _waves[i],
          palette: wavePalettes[_palettes[i]]!,
          progress: scrub != null && scrub.demo == i ? scrub.at : null,
        ),
      ),
    );
  }

  Widget _caption(Tokens t) {
    final demo = _demos[_index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: easeOut,
            switchOutCurve: easeOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(_index),
              children: [
                Text(
                  demo.title,
                  style: TextStyle(
                    color: t.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  demo.blurb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.muted, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // The longer palettes would overflow a phone; shrink rather than
          // wrap.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'WaveType.${demo.type.name}  ·  '
              '${wavePaletteCode(_palettes[_index])}',
              style: _codeStyle(t),
            ),
          ),
        ],
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

String _label(WaveType type) =>
    type.name[0].toUpperCase() + type.name.substring(1);
