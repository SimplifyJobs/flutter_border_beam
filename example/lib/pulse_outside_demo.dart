import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter/material.dart';

import 'demo_harness.dart';

/// Focused reel for the pulse-outside effect. Record with:
///
///   tool/record_demo.sh --target lib/pulse_outside_demo.dart \
///     --prefix PULSEOUT --contact
void main() {
  runDemoReel(
    prefix: 'PULSEOUT',
    hold: const Duration(seconds: 10),
    scenes: {
      'pulse-outside': () => const SizedBox(
        width: 350,
        height: 140,
        child: BorderBeam.pulseOutside(child: _Surface()),
      ),
    },
  );
}

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
