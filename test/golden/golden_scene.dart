import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared staging for the golden families.
///
/// Every scene is a beam over a mock surface, centred on the demo backdrop
/// with [goldenMargin] of clear room on every side — outward light (a comet,
/// a positive ring offset) paints past the box and must land in the
/// image, not off it. Only that keyed region is captured, so the PNGs stay
/// small and an unrelated change to the test surface size moves nothing.
///
/// Scenes freeze the fake test clock at [goldenFreeze] after activation —
/// past the 0.6s fade-in, mid-cycle — so each image is one representative
/// animated frame, deterministic run to run.
///
/// Regenerate (macOS, on the SDK `ci.yaml` pins):
///   flutter test --update-goldens --tags golden

/// The instant every scene is captured at, unless it says otherwise.
const Duration goldenFreeze = Duration(milliseconds: 1300);

/// Clear room around the beam's box.
const double goldenMargin = 100;

/// The card every scene lights unless it needs another size.
const Size goldenCard = Size(350, 140);

const Key _captureKey = ValueKey<String>('golden-capture');

/// The demo backdrop for [brightness].
Color backdropFor(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF070707)
    : const Color(0xFFFDFDFD);

/// The card surface a beam is painted around, matching the beam's corners.
///
/// [radii] gives per-corner radii; [superellipse] clips the card with
/// Flutter's own superellipse so the scene shows whether the beam's stroke
/// sits on the card's edge.
Widget mockSurface(
  Brightness brightness, {
  double radius = 16,
  BorderRadius? radii,
  bool superellipse = false,
}) {
  final dark = brightness == Brightness.dark;
  final fill = dark ? const Color(0xFF1D1D1D) : const Color(0xFFFFFFFF);
  final edge = BorderSide(
    color: dark ? const Color(0x14FFFFFF) : const Color(0x14000000),
  );
  final corners = radii ?? BorderRadius.circular(radius);
  return DecoratedBox(
    decoration: ShapeDecoration(
      color: fill,
      shape: superellipse
          ? RoundedSuperellipseBorder(borderRadius: corners, side: edge)
          : RoundedRectangleBorder(borderRadius: corners, side: edge),
    ),
  );
}

/// Stages [child] at [size] on the backdrop for [brightness].
Widget goldenScene(
  Widget child, {
  Brightness brightness = Brightness.dark,
  Size size = goldenCard,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: brightness),
  home: Center(
    child: RepaintBoundary(
      key: _captureKey,
      child: ColoredBox(
        color: backdropFor(brightness),
        child: Padding(
          padding: const EdgeInsets.all(goldenMargin),
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    ),
  ),
);

/// Pumps [scene], runs the clock to [freeze], and matches the staged region
/// against `goldens/[name].png`.
///
/// [beforeFreeze] runs after the first frame and before the clock advances —
/// the hook for a hover, a press, or a focus request.
///
/// The clock normally jumps straight to [freeze]: every animated value is a
/// pure function of elapsed time. [frameByFrame] advances it in 60Hz frames
/// instead, for the one thing that integrates per frame — the eased
/// `BorderBeam.follow`, which ignores a single step longer than a frame
/// burst.
Future<void> captureGolden(
  WidgetTester tester,
  String name,
  Widget scene, {
  Duration freeze = goldenFreeze,
  Future<void> Function()? beforeFreeze,
  bool frameByFrame = false,
}) async {
  await tester.pumpWidget(scene);
  await beforeFreeze?.call();
  // The first tick after a ticker starts reports zero elapsed time.
  await tester.pump();
  if (frameByFrame) {
    const frame = Duration(microseconds: 16667);
    var left = freeze;
    while (left > frame) {
      await tester.pump(frame);
      left -= frame;
    }
    await tester.pump(left);
  } else {
    await tester.pump(freeze);
  }
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile('goldens/$name.png'),
  );
}
