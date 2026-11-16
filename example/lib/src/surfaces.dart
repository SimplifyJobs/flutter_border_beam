import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The quiet, realistic surfaces the beams wrap — one per effect, each the
/// kind of widget that effect is for. Purely presentational; every one
/// takes its [width] from the stage.

BoxDecoration _box(Tokens t, double radius) => BoxDecoration(
  color: t.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: t.surfaceLine),
);

TextStyle _text(Color color, {double size = 13, FontWeight? weight}) =>
    TextStyle(
      fontSize: size,
      height: 1.25,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.1,
    );

/// The corner radius the card-shaped surfaces share.
const double surfaceRadius = 20;

/// An agent's task list — the card `rotate` laps.
class TaskCard extends StatelessWidget {
  /// Creates the card.
  const TaskCard({super.key, required this.width});

  /// Laid-out width.
  final double width;

  static const _tasks = [
    'Generate colour palettes',
    'Recommend font pairings',
    'Create layout templates',
    'Build the section engine',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Container(
      width: width,
      decoration: _box(t, surfaceRadius),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ShimmerText('Working…', base: t.placeholder, highlight: t.text),
          const SizedBox(height: 22),
          for (final (i, task) in _tasks.indexed) ...[
            if (i > 0) const SizedBox(height: 18),
            Row(
              children: [
                i < 2
                    ? Icon(Icons.check_circle, size: 16, color: t.icon)
                    : CustomPaint(
                        size: const Size.square(16),
                        painter: _DashedCircle(t.icon),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(i < 2 ? t.placeholder : t.surfaceText),
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

/// A chat composer — the input `line` rides the bottom edge of.
class Composer extends StatelessWidget {
  /// Creates the composer.
  const Composer({super.key, required this.width});

  /// Laid-out width.
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    Widget chip(String label) => Container(
      height: 26,
      padding: const EdgeInsets.only(left: 9, right: 5),
      decoration: BoxDecoration(
        color: t.chip,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: t.chipLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _text(t.surfaceText, size: 12)),
          Icon(Icons.keyboard_arrow_down, size: 16, color: t.icon),
        ],
      ),
    );
    return Container(
      width: width,
      height: 140,
      decoration: _box(t, surfaceRadius),
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Build anything…', style: _text(t.placeholder, size: 15)),
          const Spacer(),
          Row(
            children: [
              chip('Agent'),
              const SizedBox(width: 6),
              chip('Auto'),
              const Spacer(),
              // Empty input, so the send button rests.
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: t.chip,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.chipLine),
                ),
                child: Icon(Icons.arrow_upward, size: 18, color: t.icon),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An assistant mid-answer — the "thinking" state `pulse` breathes in.
class ThinkingCard extends StatelessWidget {
  /// Creates the card.
  const ThinkingCard({super.key, required this.width});

  /// Laid-out width.
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Container(
      width: width,
      decoration: _box(t, surfaceRadius),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.chip,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.chipLine),
                ),
                child: Icon(Icons.auto_awesome, size: 14, color: t.icon),
              ),
              const SizedBox(width: 10),
              ShimmerText('Thinking', base: t.placeholder, highlight: t.text),
            ],
          ),
          const SizedBox(height: 20),
          for (final fraction in const [1.0, 0.88, 0.56]) ...[
            FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: t.chip,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// A call-to-action pill — what `halo` breathes around.
class AskButton extends StatelessWidget {
  /// Creates the button.
  const AskButton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: _box(t, 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: t.text),
          const SizedBox(width: 10),
          Text(
            'Ask anything',
            style: _text(t.text, size: 16, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// A loading label with a highlight sweeping across it.
class ShimmerText extends StatefulWidget {
  /// Creates the label.
  const ShimmerText(
    this.text, {
    super.key,
    required this.base,
    required this.highlight,
  });

  /// The label.
  final String text;

  /// Resting colour.
  final Color base;

  /// The colour of the sweep.
  final Color highlight;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _sweep,
    builder: (context, child) {
      final x = 1 - _sweep.value * 2; // sweeps left to right
      return ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-x - 1, 0),
          end: Alignment(-x + 1, 0),
          colors: [widget.base, widget.highlight, widget.base],
        ).createShader(bounds),
        child: child,
      );
    },
    child: Text(
      widget.text,
      style: _text(widget.base, size: 14, weight: FontWeight.w500),
    ),
  );
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final rect = (Offset.zero & size).deflate(1);
    const dashes = 8;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle oldDelegate) => oldDelegate.color != color;
}
