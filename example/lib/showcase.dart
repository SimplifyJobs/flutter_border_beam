import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';

import 'demo_harness.dart';

/// The README showcase reel. Record with:
///
///   tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
///
/// Each scene holds for ~2 full animation cycles on the dark demo backdrop:
/// the three effects, then palettes and a squircle.
Future<void> main() => runDemoReel(
  prefix: 'SHOWCASE',
  hold: const Duration(seconds: 7),
  scenes: {
    'rotate': () =>
        _card(const BorderBeam(effect: BeamEffect.rotate(), child: _Surface())),
    'line': () => BorderBeam(
      effect: const BeamEffect.line(),
      borderRadius: 21,
      child: Container(
        width: 366,
        height: 42,
        decoration: _surfaceDecoration(21),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: const Row(
          children: [
            Icon(Icons.search, size: 20, color: Color(0x66565656)),
            SizedBox(width: 10),
            Text(
              'Search',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF565656),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    ),
    'pulse': () =>
        _card(const BorderBeam(effect: BeamEffect.pulse(), child: _Surface())),
    'palettes': () => const _PaletteSweep(),
    'squircle': () => _card(
      const BorderBeam(
        effect: BeamEffect.rotate(),
        colors: BeamColors.ocean,
        shape: BeamShape.all(28, superellipse: true),
        child: _Surface(radius: 28),
      ),
    ),
  },
);

Widget _card(Widget beam) => SizedBox(width: 350, height: 140, child: beam);

BoxDecoration _surfaceDecoration(double radius) => BoxDecoration(
  color: const Color(0xFF1D1D1D),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0x852C2F36)),
);

const TextStyle _labelStyle = TextStyle(
  fontSize: 13,
  color: Color(0xFF4E4E4E),
  decoration: TextDecoration.none,
);

class _Surface extends StatelessWidget {
  const _Surface({this.radius = 16});

  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _surfaceDecoration(radius),
    alignment: Alignment.center,
    child: const Text('Build anything...', style: _labelStyle),
  );
}

/// Three stacked cards: two of the newer presets and a custom ring.
class _PaletteSweep extends StatelessWidget {
  const _PaletteSweep();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final colors in const [
        BeamColors.lagoon,
        BeamColors.cosmic,
        BeamColors([Color(0xFFFF0080), Color(0xFF00E5FF)]),
      ]) ...[
        SizedBox(
          width: 320,
          height: 88,
          child: BorderBeam(
            effect: const BeamEffect.rotate(),
            colors: colors,
            child: const _Surface(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    ],
  );
}
