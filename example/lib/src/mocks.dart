import 'package:flutter/material.dart';

import 'demo_theme.dart';

/// Mock UI surfaces mirroring the original border-beam demo (`mocks.tsx` +
/// `styles.css`): a chat input, an agent working card, a subscribe pill, an
/// icon button, and a search bar. Purely presentational.

BoxDecoration _mockBox(DemoTokens t, double radius) => BoxDecoration(
  color: t.mockBg,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: t.mockBorder),
);

TextStyle _mockStyle(
  Color color, {
  double size = 13,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontSize: size,
  height: 16 / 13,
  fontWeight: weight,
  color: color,
  decoration: TextDecoration.none,
  fontFamily: '.SF Pro Text',
  fontFamilyFallback: const ['Inter', 'Roboto'],
);

/// The 348×137 chat input ("Build anything...") — the hero example.
class MockChatInput extends StatelessWidget {
  /// Const constructor.
  const MockChatInput({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    Widget chip({required Widget child, EdgeInsets? padding}) => Container(
      height: 24,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: t.mockChipBg,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: t.mockChipLine),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
    );

    return Container(
      width: 348,
      height: 137,
      decoration: _mockBox(t, 20),
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chip(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.alternate_email, size: 16, color: t.mockIcon),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
            child: Text(
              'Build anything...',
              style: _mockStyle(t.mockPlaceholder),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              for (final label in ['Agent', 'Auto']) ...[
                chip(
                  padding: const EdgeInsets.only(left: 8, right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: _mockStyle(t.mockTagText, size: 12)),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: t.mockIcon.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.mockChipBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.mockChipLine),
                ),
                child: Icon(
                  Icons.arrow_upward,
                  size: 16,
                  color: t.mockIcon.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The agent task list card with the shimmering "Working..." header.
class MockWorkingCard extends StatelessWidget {
  /// Const constructor.
  const MockWorkingCard({super.key});

  static const _tasks = [
    'Generate color palettes',
    'Recommend font pairings',
    'Create layout templates',
    'Build section engine',
    'Generate hero variants',
  ];

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      width: 295,
      decoration: _mockBox(t, 20),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShimmerText('Working...', base: t.shimmerBase),
          const SizedBox(height: 24),
          for (final (i, task) in _tasks.indexed) ...[
            if (i > 0) const SizedBox(height: 20),
            Row(
              children: [
                _DashedCircle(color: t.mockIcon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task,
                    style: _mockStyle(t.mockText),
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The "Subscribe" pill button.
class MockSubscribeButton extends StatelessWidget {
  /// Const constructor.
  const MockSubscribeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: _mockBox(t, 48),
      alignment: Alignment.center,
      child: Text(
        'Subscribe',
        style: _mockStyle(t.mockTextStrong, weight: FontWeight.w500),
      ),
    );
  }
}

/// The 36×36 icon button with a small square glyph.
class MockIconButton extends StatelessWidget {
  /// Const constructor.
  const MockIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      width: 36,
      height: 36,
      decoration: _mockBox(t, 20),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: t.mockSquare,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The 366×42 pill search bar.
class MockSearchBar extends StatelessWidget {
  /// Const constructor.
  const MockSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return Container(
      width: 366,
      height: 42,
      decoration: _mockBox(t, 21),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 20,
            color: t.mockSearchText.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Text('Search', style: _mockStyle(t.mockSearchText, size: 15)),
        ],
      ),
    );
  }
}

class _DashedCircle extends StatelessWidget {
  const _DashedCircle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(16, 16),
    painter: _DashedCirclePainter(color),
  );
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final rect = (Offset.zero & size).deflate(1);
    // 8 dashes around the circle, matching the SVG's `stroke-dasharray 3 3`.
    const dashes = 8;
    const sweep = 3.14159 * 2 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A shimmering loading label (port of the demo's `t-shimmer`).
class _ShimmerText extends StatefulWidget {
  const _ShimmerText(this.text, {required this.base});

  final String text;
  final Color base;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = DemoTheme.of(context).tokens;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = 1 - _controller.value * 2; // 1 → −1 sweep
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x - 1, 0),
            end: Alignment(x + 1, 0),
            colors: [widget.base, t.text, widget.base],
          ).createShader(bounds),
          child: Text(widget.text, style: _mockStyle(widget.base)),
        );
      },
    );
  }
}
