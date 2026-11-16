@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';

/// The wave's look, pinned: each type at the moments of its life that show
/// its parts — the pull before the launch, the launch, the front crossing,
/// the colour left on the edges — and the palettes on the front.
///
/// The scenes are the ones the look was calibrated on against the reference
/// design (DistortionWavesKit, rendered at the same progress over the same
/// mock screens; mean difference about 1/255). macOS-generated on the
/// Flutter version `ci.yaml` pins.
void main() {
  setUpAll(DistortionWave.precache);

  /// A mock screen: a header bar, cards with an avatar and two lines each,
  /// and optionally a full-width button at the bottom.
  Widget screen(
    Color background,
    Color card,
    Color accent, {
    bool button = true,
    int cards = 5,
  }) => ColoredBox(
    color: background,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 24, color: accent),
          const SizedBox(height: 24),
          for (var i = 0; i < cards; i++) ...[
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 10,
                        width: 120.0 + i * 20,
                        color: const Color(0x99FFFFFF),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        width: 80,
                        color: const Color(0x55FFFFFF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Spacer(),
          if (button)
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
        ],
      ),
    ),
  );

  final review = screen(
    const Color(0xFF0E0E10),
    const Color(0xFF1C1C20),
    const Color(0xFF3D7BFF),
  );
  final receipt = screen(
    const Color(0xFFF4F1EA),
    const Color(0xFFFFFFFF),
    const Color(0xFF1B8A4B),
    button: false,
  );
  final sheet = screen(
    const Color(0xFF16161A),
    const Color(0xFF23232A),
    const Color(0xFFE0A030),
    button: false,
    cards: 4,
  );
  final done = screen(
    const Color(0xFF16161A),
    const Color(0xFF23232A),
    const Color(0xFF35BA00),
    button: false,
    cards: 4,
  );

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    Widget wave,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: RepaintBoundary(child: wave),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  const phone = Size(390, 844);
  const button = WaveSource.rect(
    Rect.fromLTWH(20, 764, 350, 56),
    focus: Offset(300, 790),
  );

  group('vertical', () {
    for (final (name, p) in [
      ('pull', 0.06),
      ('launch', 0.16),
      ('crossing', 0.22),
      ('top', 0.30),
      ('edges', 0.40),
    ]) {
      testWidgets(name, (tester) async {
        await capture(
          tester,
          'vertical_$name',
          phone,
          DistortionWave(
            progress: p,
            source: button,
            revealedChild: receipt,
            child: review,
          ),
        );
      });
    }
  });

  group('horizontal', () {
    for (final (name, p) in [
      ('launch', 0.16),
      ('crossing', 0.25),
      ('edges', 0.40),
    ]) {
      testWidgets(name, (tester) async {
        await capture(
          tester,
          'horizontal_$name',
          phone,
          DistortionWave(
            progress: p,
            type: WaveType.horizontal,
            source: const WaveSource.rect(
              Rect.fromLTWH(0, 200, 24, 440),
              focus: Offset(12, 300),
            ),
            revealedChild: receipt,
            child: review,
          ),
        );
      });
    }
  });

  group('center', () {
    for (final (name, p) in [('pull', 0.04), ('ring', 0.20), ('edges', 0.35)]) {
      testWidgets(name, (tester) async {
        await capture(
          tester,
          'center_$name',
          const Size(360, 520),
          DistortionWave(
            progress: p,
            type: WaveType.center,
            source: const WaveSource.rect(Rect.fromLTWH(148, 60, 64, 64)),
            revealedChild: done,
            child: sheet,
          ),
        );
      });
    }
  });

  group('palettes', () {
    for (final (name, palette) in [
      ('ocean', WavePalette.ocean),
      ('sunset', WavePalette.sunset),
      ('aurora', WavePalette.fromBeamColors(BeamColors.aurora)),
    ]) {
      testWidgets(name, (tester) async {
        await capture(
          tester,
          'palette_$name',
          phone,
          DistortionWave(
            progress: 0.22,
            source: button,
            palette: palette,
            revealedChild: receipt,
            child: review,
          ),
        );
      });
    }
  });
}
