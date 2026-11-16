import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/src/distortion_wave/distortion_wave.dart';
import 'package:prismatic/src/distortion_wave/render/render_wave_stage.dart';

/// The logical size of the view the wave tests run in: a phone.
const Size waveTestSize = Size(390, 844);

/// Sizes the test view to [size] at a pixel ratio of 2 for the test.
void useWaveView(WidgetTester tester, {Size size = waveTestSize}) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// [child] with the ambient widgets a wave needs and nothing else.
Widget waveHost(
  Widget child, {
  bool disableAnimations = false,
  BorderRadius? displayCornerRadii,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(
      size: waveTestSize,
      devicePixelRatio: 2,
      disableAnimations: disableAnimations,
      displayCornerRadii: displayCornerRadii,
    ),
    child: child,
  ),
);

/// The wave's render object.
RenderWaveStage waveStage(WidgetTester tester) =>
    tester.renderObject<RenderWaveStage>(find.byType(WaveStage));

/// The outgoing side's solid colour in the wave tests.
const Color outgoingColor = Color(0xFF1030A0);

/// The incoming side's solid colour in the wave tests.
const Color incomingColor = Color(0xFFF0E8D8);

/// A side that is one flat colour, keyed so a test can find it.
Widget flatSide(Color color, String key) => ColoredBox(
  key: ValueKey(key),
  color: color,
  child: const SizedBox.expand(),
);
