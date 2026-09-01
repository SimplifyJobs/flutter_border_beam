import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter/material.dart';

import 'demo_harness.dart';

/// The README showcase reel. Record with:
///
///   tool/record_demo.sh --target lib/showcase.dart --prefix SHOWCASE --contact
///
/// Each scene holds for ~2 full animation cycles on the dark demo backdrop.
void main() {
  runDemoReel(
    prefix: 'SHOWCASE',
    hold: const Duration(seconds: 7),
    scenes: {
      'rotate': () => _card(const BorderBeam.rotate(child: _Surface())),
      'small': () => BorderBeam.small(
        borderRadius: 20,
        child: Container(
          width: 36,
          height: 36,
          decoration: _surfaceDecoration(20),
          alignment: Alignment.center,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xCCD9D9D9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
      'line': () => BorderBeam.line(
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
      'pulse-inside': () =>
          _card(const BorderBeam.pulseInside(child: _Surface())),
      'pulse-outside': () =>
          _card(const BorderBeam.pulseOutside(child: _Surface())),
      'palettes': () => const _PaletteSweep(),
      'squircle': () => _card(
        const BorderBeam.rotate(
          colors: BeamColors.ocean,
          useSuperellipse: true,
          borderRadius: 28,
          child: _Surface(radius: 28),
        ),
      ),
    },
  );
}

Widget _card(Widget beam) => SizedBox(width: 350, height: 140, child: beam);

BoxDecoration _surfaceDecoration(double radius) => BoxDecoration(
  color: const Color(0xFF1D1D1D),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0x852C2F36)),
);

class _Surface extends StatelessWidget {
  const _Surface({this.radius = 16});

  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _surfaceDecoration(radius),
    alignment: Alignment.center,
    child: const Text(
      'Build anything...',
      style: TextStyle(
        fontSize: 13,
        color: Color(0xFF4E4E4E),
        decoration: TextDecoration.none,
      ),
    ),
  );
}

/// Three stacked cards cycling ocean / sunset / custom palettes.
class _PaletteSweep extends StatelessWidget {
  const _PaletteSweep();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final colors in const [
        BeamColors.ocean,
        BeamColors.sunset,
        BeamColors.custom([Color(0xFFFF0080), Color(0xFF00E5FF)]),
      ]) ...[
        SizedBox(
          width: 320,
          height: 88,
          child: BorderBeam.rotate(colors: colors, child: const _Surface()),
        ),
        const SizedBox(height: 20),
      ],
    ],
  );
}
