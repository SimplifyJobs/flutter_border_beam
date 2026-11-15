import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter/material.dart';

import 'demo_harness.dart';

/// Focused reel for the halo effect — the 0.1 pulse-outside. Record with:
///
///   tool/record_demo.sh --target lib/halo_demo.dart --prefix HALO --contact
///
/// The halo paints outside the card's bounds, so the card sits on the open
/// stage with nothing clipping it.
Future<void> main() => runDemoReel(
  prefix: 'HALO',
  hold: const Duration(seconds: 10),
  scenes: {
    'halo': () => const SizedBox(
      width: 350,
      height: 140,
      child: BorderBeam(effect: BeamEffect.halo(), child: _Surface()),
    ),
    'halo-ocean': () => const SizedBox(
      width: 350,
      height: 140,
      child: BorderBeam(
        effect: BeamEffect.halo(),
        colors: BeamColors.ocean,
        child: _Surface(),
      ),
    ),
  },
);

class _Surface extends StatelessWidget {
  const _Surface();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1D1D1D),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x852C2F36)),
    ),
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
