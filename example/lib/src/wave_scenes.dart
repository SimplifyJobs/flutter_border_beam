import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';

import 'controls.dart';
import 'surfaces.dart' show squircle;
import 'tokens.dart';

/// The distortion wave demos: three realistic mock screens, one per wave
/// type, each turning into the screen it leads to. Shared by the wave page
/// and the wave reel.

/// One demo per wave type, each on the kind of screen that type is for.
enum WaveDemo {
  /// A payment review whose Send button reveals the receipt.
  send(
    WaveType.vertical,
    'Send money',
    'A vertical wave from the Send button.',
    'colorful',
  ),

  /// A sign-up step whose edge tab goes on to the next step.
  step(
    WaveType.horizontal,
    'Next step',
    'A horizontal wave from the edge tab.',
    'colorful',
  ),

  /// A payment sheet whose icon turns it into its success state.
  success(
    WaveType.center,
    'Success sheet',
    'A ring from the icon into success.',
    'green',
  );

  const WaveDemo(this.type, this.title, this.blurb, this.palette);

  /// The type of wave the demo plays.
  final WaveType type;

  /// The caption's title.
  final String title;

  /// The caption's one line.
  final String blurb;

  /// The name, in [wavePalettes], of the palette it starts on — the type's
  /// own default.
  final String palette;

  /// The corner radius of the view the wave fills, which the wave's colour
  /// on the edges follows.
  double get radius => this == success ? sheetRadius : screenRadius;
}

/// The corner radius of the mock phone screens.
const double screenRadius = 44;

/// The corner radius of the success sheet — the center wave's default.
const double sheetRadius = 48;

/// The success sheet's height: the size the center wave is tuned for.
const double sheetHeight = 500;

/// The palettes on offer: the wave's five presets, then two border-beam
/// palettes carried over with `WavePalette.fromBeamColors`.
final Map<String, WavePalette> wavePalettes = {
  ...WavePalette.presets,
  'aurora': WavePalette.fromBeamColors(BeamColors.aurora),
  'lagoon': WavePalette.fromBeamColors(BeamColors.lagoon),
};

/// The palette called [name], written as code.
String wavePaletteCode(String name) => WavePalette.presets.containsKey(name)
    ? 'WavePalette.$name'
    : 'WavePalette.fromBeamColors(BeamColors.$name)';

/// A swatch for the palette called [name]: its colours swept round from
/// 12 o'clock, wrapping back to the first, the way they flow round the
/// view's edges.
Gradient waveSwatch(String name) {
  final colors = wavePalettes[name]!.colors;
  return SweepGradient(
    transform: const GradientRotation(-math.pi / 2),
    colors: [...colors, colors.first],
  );
}

/// The steps the [WaveDemo.step] screen runs through, after the last back
/// to the first.
const int stepCount = 4;

/// One demo's wave between its two screens, in a frame with the demo's
/// corners.
///
/// Tapping the screen's anchor — the Send button, the edge tab, the icon —
/// sends the wave out from it; the revealed screen's Done collapses it. The
/// step demo carries on: once a step has arrived it becomes the resting
/// side, with the step after it ready behind, so the tab keeps going.
class DemoWave extends StatefulWidget {
  /// Creates the demo.
  const DemoWave({
    super.key,
    required this.demo,
    required this.controller,
    required this.palette,
    this.progress,
    this.source,
    this.anchorKey,
    this.chain = true,
    this.fullScreen = false,
    this.onFinish,
  });

  /// Whether the demo fills the device's screen: no frame, the real status
  /// bar and home indicator, and the wave's edge colour on the display's own
  /// corners. Otherwise it is a framed mock phone (or sheet).
  final bool fullScreen;

  /// Which demo.
  final WaveDemo demo;

  /// Plays the wave; the demo's buttons drive it.
  final DistortionWaveController controller;

  /// The wave's colours.
  final WavePalette palette;

  /// Holds the wave here, 0–1, instead of playing it — the scrub bar.
  final double? progress;

  /// Where the wave opens from. Null opens it from the anchor pressed last,
  /// leaning toward the touch — and, while [progress] holds it, from the
  /// demo's anchor.
  final WaveSource? source;

  /// The key on the demo's anchor; the demo makes its own if null.
  final GlobalKey? anchorKey;

  /// Whether the step demo goes on to the following step once a step
  /// arrives, instead of resting on the revealed one.
  final bool chain;

  /// Called when a run arrives.
  final VoidCallback? onFinish;

  @override
  State<DemoWave> createState() => _DemoWaveState();
}

class _DemoWaveState extends State<DemoWave>
    with AutomaticKeepAliveClientMixin {
  late final GlobalKey _ownKey = GlobalKey(debugLabel: 'wave anchor');
  int _step = 0;

  // Kept alive in the page view, so a swipe away and back keeps the step.
  @override
  bool get wantKeepAlive => true;

  GlobalKey get _anchor => widget.anchorKey ?? _ownKey;

  DistortionWaveController get _wave => widget.controller;

  void _reveal() => _wave.reveal();

  void _collapse() => _wave.collapse();

  void _arrived() {
    if (widget.demo == WaveDemo.step && widget.chain && _wave.isRevealed) {
      // The next step is on screen: make it the resting side, with the step
      // after it behind. Both sides change in the same frame, so nothing
      // moves.
      setState(() => _step = (_step + 1) % stepCount);
      _wave.seek(0);
    }
    widget.onFinish?.call();
  }

  void _back() {
    if (_step == 0 || _wave.isRunning) return;
    // The reverse: the step on screen moves to the revealed side, the one
    // before it underneath, and the wave collapses back into the edge.
    setState(() => _step--);
    _wave
      ..seek(1)
      ..collapse();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final demo = widget.demo;
    final (Widget rest, Widget revealed) = switch (demo) {
      WaveDemo.send => (
        SendReview(anchorKey: _anchor, onSend: _reveal),
        SendReceipt(onDone: _collapse),
      ),
      WaveDemo.step => (
        StepScreen(
          step: _step,
          anchorKey: _anchor,
          onNext: _reveal,
          onBack: _back,
        ),
        StepScreen(
          step: (_step + 1) % stepCount,
          onNext: _reveal,
          onBack: _collapse,
        ),
      ),
      WaveDemo.success => (
        PayConfirm(anchorKey: _anchor, onPay: _reveal),
        PaySuccess(onDone: _collapse),
      ),
    };
    final held = widget.progress;
    final fills = widget.fullScreen && demo != WaveDemo.success;
    final wave = DistortionWave(
      controller: _wave,
      type: demo.type,
      palette: widget.palette,
      // Filling the screen, the wave follows the display's corners by
      // itself; framed, it follows the frame's.
      style: fills
          ? null
          : WaveStyle(glow: WaveGlow(cornerRadius: demo.radius)),
      progress: held,
      // A held wave opens from the anchor pressed last; before anything has
      // been pressed there is none, so hold it on the button.
      source: widget.source ?? (held == null ? null : WaveSource.key(_anchor)),
      onFinish: _arrived,
      revealedChild: revealed,
      child: rest,
    );
    return MediaQuery.withNoTextScaling(
      child: fills
          ? _FullScreen(child: wave)
          // A framed mock draws its own status bar and spacing.
          : MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: _Frame(radius: demo.radius, child: wave),
            ),
    );
  }
}

/// Clips a wave to [radius]'s continuous corners and rings it with the
/// surfaces' hairline. The wave's sides are opaque rectangles; the clip
/// rounds them.
class _Frame extends StatelessWidget {
  const _Frame({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(shape: squircle(radius, side: t.surfaceLine)),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

// ─── Send money ─────────────────────────────────────────────────────────────

/// A payment about to be sent: recipient, amount, details, and a Send
/// button along the bottom — where the vertical wave opens from.
class SendReview extends StatelessWidget {
  /// Creates the screen.
  const SendReview({super.key, this.anchorKey, required this.onSend});

  /// The key on the Send button's anchor.
  final GlobalKey? anchorKey;

  /// Called when Send is tapped.
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return ColoredBox(
      color: t.surface,
      child: Column(
        children: [
          const _StatusBar(),
          const _TopBar(
            title: 'Review',
            leading: Icons.arrow_back_ios_new_rounded,
          ),
          const SizedBox(height: 22),
          const _Monogram('MR'),
          const SizedBox(height: 10),
          Text(
            'Maya Rodriguez',
            style: _style(t.text, 16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text('@maya.r', style: _style(t.muted, 13)),
          const SizedBox(height: 20),
          Text(r'$248.00', style: _amount(t)),
          const SizedBox(height: 6),
          Text('from Checking •• 4821', style: _style(t.muted, 13)),
          const SizedBox(height: 22),
          const _Details([
            ('Arrives', 'Instantly'),
            ('Fee', 'Free'),
            ('Note', 'Dinner and tickets'),
          ]),
          const Spacer(),
          // Where the vertical wave opens from by default, too: 56 tall, 24
          // up from the bottom, 20 in from the sides.
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + _bottomInset(context)),
            child: DistortionWaveAnchor(
              key: anchorKey,
              child: _WideButton(label: r'Send $248.00', onTap: onSend),
            ),
          ),
        ],
      ),
    );
  }
}

/// The receipt the Send button leads to, with Done where Send was.
class SendReceipt extends StatelessWidget {
  /// Creates the screen.
  const SendReceipt({super.key, required this.onDone});

  /// Called when Done is tapped.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return ColoredBox(
      color: t.surface,
      child: Column(
        children: [
          const _StatusBar(),
          const _TopBar(title: 'Receipt', trailing: Icons.ios_share_rounded),
          const SizedBox(height: 30),
          const _CheckBadge(),
          const SizedBox(height: 16),
          Text(
            'Sent',
            style: _style(t.text, 28, weight: FontWeight.w600, spacing: -0.6),
          ),
          const SizedBox(height: 6),
          Text(r'$248.00 to Maya Rodriguez', style: _style(t.muted, 14)),
          const SizedBox(height: 26),
          const _Details([
            ('Status', 'Completed'),
            ('Date', 'Today, 9:41 AM'),
            ('Reference', 'PX-48K2-7QD'),
            ('From', 'Checking •• 4821'),
          ]),
          const Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + _bottomInset(context)),
            child: _WideButton(label: 'Done', onTap: onDone, primary: false),
          ),
        ],
      ),
    );
  }
}

// ─── Next step ──────────────────────────────────────────────────────────────

/// One step of a sign-up flow, with a tall tab on the left edge that goes
/// on to the next — where the horizontal wave opens from.
class StepScreen extends StatelessWidget {
  /// Creates step [step] (from 0) of [stepCount].
  const StepScreen({
    super.key,
    required this.step,
    this.anchorKey,
    required this.onNext,
    required this.onBack,
  });

  /// Which step, from 0.
  final int step;

  /// The key on the edge tab's anchor.
  final GlobalKey? anchorKey;

  /// Called when the edge tab is tapped.
  final VoidCallback onNext;

  /// Called when Back is tapped.
  final VoidCallback onBack;

  static const _titles = [
    ('Create your account', 'It takes a minute. You can change it later.'),
    ('Choose a plan', 'Switch or cancel any time.'),
    ('Connect your bank', 'To move money in and out.'),
    ("You're all set", 'Your account is ready to use.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    final (title, subtitle) = _titles[step];
    final last = step == stepCount - 1;
    return ColoredBox(
      color: t.surface,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _StatusBar(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(44, 0, 24, 0),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          if (step > 0)
                            Pressable(
                              onTap: onBack,
                              semanticLabel: 'Back',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    size: 20,
                                    color: t.icon,
                                  ),
                                  Text('Back', style: _style(t.muted, 14)),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Text(
                            'Step ${step + 1} of $stepCount',
                            style: _style(t.muted, 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        44,
                        4,
                        24,
                        24 + _bottomInset(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Progress(step: step),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            style: _style(
                              t.text,
                              26,
                              weight: FontWeight.w600,
                              spacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(subtitle, style: _style(t.muted, 14)),
                          const SizedBox(height: 22),
                          _StepBody(step: step),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 14,
                                color: t.placeholder,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  last
                                      ? 'Tap the tab to start again'
                                      : 'Tap the tab to continue',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _style(t.placeholder, 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Where the horizontal wave opens from by default, too: the left
            // edge, over the middle 60% of its height.
            Positioned(
              left: 0,
              top: box.maxHeight * 0.2,
              width: 24,
              height: box.maxHeight * 0.6,
              child: DistortionWaveAnchor(
                key: anchorKey,
                child: Pressable(
                  onTap: onNext,
                  semanticLabel: last ? 'Start again' : 'Next step',
                  child: _EdgeTab(label: last ? 'AGAIN' : 'NEXT'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeTab extends StatelessWidget {
  const _EdgeTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.text,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chevron_right_rounded, size: 18, color: t.surface),
          const SizedBox(height: 6),
          RotatedBox(
            quarterTurns: 1,
            child: Text(
              label,
              style: _style(
                t.surface,
                10,
                weight: FontWeight.w700,
                spacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Row(
      children: [
        for (var i = 0; i < stepCount; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              decoration: ShapeDecoration(
                color: i <= step ? t.text : t.surfaceLine,
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    Widget bank(String name, String detail, {bool on = false}) => _Choice(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: t.chip,
          shape: BoxShape.circle,
          border: Border.all(color: t.chipLine),
        ),
        child: Icon(Icons.account_balance_outlined, size: 16, color: t.icon),
      ),
      title: name,
      detail: detail,
      selected: on,
    );
    Widget plan(String name, String price, {bool on = false}) => _Choice(
      leading: Icon(
        on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 20,
        color: on ? t.text : t.icon,
      ),
      title: name,
      trailing: price,
      selected: on,
    );
    final rows = switch (step) {
      0 => const [
        _Field('Name', 'Maya Rodriguez'),
        _Field('Email', 'maya@studio.design'),
        _Field('Password', '••••••••••'),
      ],
      1 => [
        plan('Basic', 'Free'),
        plan('Plus', r'$8 / mo', on: true),
        plan('Pro', r'$16 / mo'),
      ],
      2 => [
        bank('First National', 'Checking •• 4821', on: true),
        bank('Harbor Credit Union', 'Savings •• 1093'),
        bank('Summit Bank', 'Add an account'),
      ],
      _ => const [
        Padding(padding: EdgeInsets.only(bottom: 18), child: _CheckBadge()),
        _Details([
          ('Plan', 'Plus'),
          ('Bank', 'First National'),
          ('Email', 'maya@studio.design'),
        ], inset: 0),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0 && step < stepCount - 1) const SizedBox(height: 10),
          row,
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: ShapeDecoration(
        color: t.chip,
        shape: squircle(14, side: t.chipLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _style(t.placeholder, 11)),
          const SizedBox(height: 3),
          Text(value, style: _style(t.surfaceText, 14)),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.leading,
    required this.title,
    this.detail,
    this.trailing,
    this.selected = false,
  });

  final Widget leading;
  final String title;
  final String? detail;
  final String? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ShapeDecoration(
        color: selected ? t.chip : null,
        shape: squircle(14, side: selected ? t.muted : t.chipLine),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style(t.surfaceText, 14, weight: FontWeight.w500),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: _style(t.muted, 12)),
                ],
              ],
            ),
          ),
          if (trailing != null) Text(trailing!, style: _style(t.muted, 13)),
          if (selected && trailing == null)
            Icon(Icons.check_rounded, size: 18, color: t.text),
        ],
      ),
    );
  }
}

// ─── Success sheet ──────────────────────────────────────────────────────────

/// A payment sheet waiting for a touch on its fingerprint icon — where the
/// center wave opens from.
class PayConfirm extends StatelessWidget {
  /// Creates the sheet.
  const PayConfirm({super.key, this.anchorKey, required this.onPay});

  /// The key on the icon's anchor.
  final GlobalKey? anchorKey;

  /// Called when the icon is tapped.
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return _Sheet(
      badge: DistortionWaveAnchor(
        key: anchorKey,
        child: Pressable(
          onTap: onPay,
          semanticLabel: 'Pay with your fingerprint',
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: t.chip,
              shape: BoxShape.circle,
              border: Border.all(color: t.surfaceLine, width: 1.5),
            ),
            child: Icon(Icons.fingerprint, size: 36, color: t.text),
          ),
        ),
      ),
      caption: 'Touch to pay',
      rows: const [('Card', 'Visa •• 4821'), ('Rewards', '+12 points')],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 13, color: t.placeholder),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Paid with your device',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _style(t.placeholder, 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// The same sheet once paid: a check where the fingerprint was, and Done.
class PaySuccess extends StatelessWidget {
  /// Creates the sheet.
  const PaySuccess({super.key, required this.onDone});

  /// Called when Done is tapped.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => _Sheet(
    badge: const _CheckBadge(),
    caption: 'Payment complete',
    rows: const [('Card', 'Visa •• 4821'), ('Rewards', '+12 points earned')],
    footer: _WideButton(
      label: 'Done',
      onTap: onDone,
      primary: false,
      height: 48,
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.badge,
    required this.caption,
    required this.rows,
    required this.footer,
  });

  final Widget badge;
  final String caption;
  final List<(String, String)> rows;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return ColoredBox(
      color: t.surface,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 5,
            decoration: ShapeDecoration(
              color: t.surfaceLine,
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(height: 30),
          badge,
          const SizedBox(height: 14),
          Text(caption, style: _style(t.muted, 13)),
          const SizedBox(height: 20),
          Text(
            'Bloom Coffee',
            style: _style(t.surfaceText, 15, weight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(r'$6.40', style: _amount(t)),
          const SizedBox(height: 22),
          _Details(rows),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: SizedBox(height: 48, child: Center(child: footer)),
          ),
        ],
      ),
    );
  }
}

// ─── Shared pieces ──────────────────────────────────────────────────────────

/// The success green of a check badge, whatever the wave's palette.
const Color _success = Color(0xFF35BA00);

TextStyle _style(
  Color color,
  double size, {
  FontWeight? weight,
  double spacing = -0.1,
}) => TextStyle(
  color: color,
  fontSize: size,
  fontWeight: weight,
  height: 1.25,
  letterSpacing: spacing,
);

TextStyle _amount(Tokens t) => TextStyle(
  color: t.text,
  fontSize: 44,
  fontWeight: FontWeight.w600,
  height: 1.1,
  letterSpacing: -1.6,
);

/// Marks a demo that fills the device's screen, so its screens use the real
/// status bar rather than a mock one.
class _FullScreen extends InheritedWidget {
  const _FullScreen({required super.child});

  static bool on(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_FullScreen>() != null;

  @override
  bool updateShouldNotify(_FullScreen oldWidget) => false;
}

/// The device's bottom safe-area inset: the home indicator's room, when a
/// demo fills the screen; 0 in a framed mock.
double _bottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

/// A mock phone's status bar.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    // Full screen, the device's own status bar shows — at the top, or on a
    // device whose status bar sits elsewhere, not at all: leave room for its
    // inset, and draw no mock.
    final top = MediaQuery.paddingOf(context).top;
    if (_FullScreen.on(context) || top > 0) return SizedBox(height: top);
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 14, 26, 2),
      child: Row(
        children: [
          Text('9:41', style: _style(t.text, 14, weight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.signal_cellular_alt_rounded, size: 15, color: t.text),
          const SizedBox(width: 4),
          Icon(Icons.wifi_rounded, size: 15, color: t.text),
          const SizedBox(width: 4),
          RotatedBox(
            quarterTurns: 1,
            child: Icon(Icons.battery_full_rounded, size: 17, color: t.text),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.leading, this.trailing});

  final String title;
  final IconData? leading;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(title, style: _style(t.text, 15, weight: FontWeight.w600)),
            if (leading != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(leading, size: 18, color: t.icon),
              ),
            if (trailing != null)
              Align(
                alignment: Alignment.centerRight,
                child: Icon(trailing, size: 20, color: t.icon),
              ),
          ],
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram(this.initials);

  final String initials;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.chip,
        shape: BoxShape.circle,
        border: Border.all(color: t.surfaceLine, width: 1.5),
      ),
      child: Text(initials, style: _style(t.text, 18, weight: FontWeight.w600)),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: const BoxDecoration(color: _success, shape: BoxShape.circle),
    child: const Icon(Icons.check_rounded, size: 36, color: Colors.white),
  );
}

/// Label–value rows in an inset card.
class _Details extends StatelessWidget {
  const _Details(this.rows, {this.inset = 20});

  final List<(String, String)> rows;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: ShapeDecoration(
          color: t.chip,
          shape: squircle(18, side: t.chipLine),
        ),
        child: Column(
          children: [
            for (final (i, (label, value)) in rows.indexed) ...[
              if (i > 0) Container(height: 1, color: t.chipLine),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(label, style: _style(t.muted, 13)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _style(
                          t.surfaceText,
                          13,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A full-width button: solid for the primary action, quiet otherwise.
class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.onTap,
    this.primary = true,
    this.height = 56,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: primary ? t.text : t.chip,
          shape: squircle(height / 2, side: primary ? null : t.chipLine),
        ),
        child: Text(
          label,
          style: _style(
            primary ? t.surface : t.text,
            16,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
