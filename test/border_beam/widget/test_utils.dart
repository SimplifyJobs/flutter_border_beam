import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/border_beam/animation/beam_clock.dart';
import 'package:prismatic/src/border_beam/render/beam_painter.dart';

/// Long enough for a fade-in to finish: [BeamClock.fadeInSeconds] plus a
/// margin. A test that waits out a fade waits this long instead of a number
/// of its own, so retuning the fade cannot leave it caught mid-fade.
final Duration pastFadeIn = _pastFade(BeamClock.fadeInSeconds);

/// Long enough for a fade-out to finish: [BeamClock.fadeOutSeconds] plus the
/// same margin as [pastFadeIn].
final Duration pastFadeOut = _pastFade(BeamClock.fadeOutSeconds);

Duration _pastFade(double seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).ceil()) +
    const Duration(milliseconds: 100);

/// Pumps [app] and expects the framework to report an [AssertionError] whose
/// message contains [message].
///
/// A widget-level `assert` is reported once per rebuild attempt, and how many
/// attempts a broken build gets varies by Flutter version — one on 3.44, three
/// on the 3.35 floor this package supports. `tester.takeException()` collapses
/// anything past the first into a "Multiple exceptions" [FlutterError], so it
/// cannot reach the assert itself. This installs its own [FlutterError.onError]
/// around the pump, collects every report, and matches the one carrying
/// [message]: the count of reports is the framework's business, the content is
/// what the test pins.
///
/// The tree is torn down inside that window too, so the follow-on framework
/// errors an unmount of a half-built tree can raise are captured rather than
/// surfacing later as an unexpected exception. Flutter 3.35 cannot always
/// finish that unmount — `InheritedElement.unmount` asserts on its dependents —
/// so a widget that starts a ticker on mount can outlive the pump and count
/// against the next test in the file; pump such a widget in a state that starts
/// no ticker.
Future<void> pumpExpectingAssertion(
  WidgetTester tester,
  Widget app, {
  required String message,
}) async {
  final reported = <Object>[];
  final previousOnError = FlutterError.onError;
  void capture(FlutterErrorDetails details) => reported.add(details.exception);
  // Restored below so the rest of the test sees the default reporter again;
  // the tear-down is the safety net for an exception thrown past the `finally`.
  addTearDown(() => FlutterError.onError = previousOnError);
  FlutterError.onError = capture;
  try {
    await tester.pumpWidget(app);
    await tester.pumpWidget(const SizedBox.shrink());
  } finally {
    FlutterError.onError = previousOnError;
  }

  expect(
    reported.whereType<AssertionError>().map((error) => '${error.message}'),
    contains(contains(message)),
    reason:
        'no reported assertion carried the expected message; '
        'reported: $reported',
  );
}

/// A [MaterialApp] hosting [child] centred in a [size] box.
///
/// [disableAnimations] sets `MediaQuery.disableAnimations` (the platform's
/// reduced-motion request); [textDirection], when given, wraps [child] in a
/// [Directionality].
Widget beamHost(
  Widget child, {
  bool disableAnimations = false,
  Brightness brightness = Brightness.dark,
  TextDirection? textDirection,
  Size size = const Size(350, 140),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: brightness),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: app!,
  ),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: textDirection == null
            ? child
            : Directionality(textDirection: textDirection, child: child),
      ),
    ),
  ),
);

/// The painter of the first [BorderBeam] under [within] (default: any beam
/// in the tree), or null when it paints nothing at all
/// (`BeamReducedMotion.hide`).
///
/// Offstage widgets are included: a row parked in a scrollable's cache extent
/// is laid out but never painted, and the default finders would skip it.
BeamPainter? maybeBeamPainterOf(WidgetTester tester, {Finder? within}) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: within ?? find.byType(BorderBeam, skipOffstage: false),
        matching: find.byType(CustomPaint, skipOffstage: false),
      ),
    )
    .map((paint) => paint.foregroundPainter)
    .whereType<BeamPainter>()
    .firstOrNull;

/// The painter of the first [BorderBeam] under [within]; see
/// [maybeBeamPainterOf].
BeamPainter beamPainterOf(WidgetTester tester, {Finder? within}) {
  final painter = maybeBeamPainterOf(tester, within: within);
  expect(painter, isNotNull, reason: 'no BeamPainter in the tree');
  return painter!;
}

/// Rasterizes the [RepaintBoundary] the first [BorderBeam] (or [of]) builds
/// around itself — the beam over its child — as raw RGBA.
///
/// Run on the real event loop: `toImage` never completes under a widget
/// test's fake async. The beam paints nothing until its shader has loaded, so
/// a test that reads pixels awaits `BorderBeam.precache()` in `setUpAll`.
Future<BeamPixels> beamPixels(WidgetTester tester, {Finder? of}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    of ?? find.byType(BorderBeam).first,
  );
  final pixels = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = BeamPixels(
      data!.buffer.asUint8List(),
      image.width,
      image.height,
    );
    image.dispose();
    return result;
  });
  return pixels!;
}

/// One rasterized frame, as raw RGBA bytes.
class BeamPixels {
  /// Wraps [bytes] of a [width]×[height] image.
  BeamPixels(this.bytes, this.width, this.height);

  /// Row-major RGBA, four bytes per pixel.
  final Uint8List bytes;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// The alpha (0–255) of the pixel at ([x], [y]).
  int alphaAt(int x, int y) => bytes[(y * width + x) * 4 + 3];

  /// Total alpha over the whole image, in whole-pixel units.
  double get totalAlpha {
    var sum = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      sum += bytes[i];
    }
    return sum / 255;
  }

  /// How many pixels differ from [color] by more than [tolerance] in any
  /// channel.
  int countDifferentFrom(Color color, {int tolerance = 2}) {
    final target = [
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
      (color.a * 255).round(),
    ];
    var count = 0;
    for (var i = 0; i < bytes.length; i += 4) {
      for (var c = 0; c < 4; c++) {
        if ((bytes[i + c] - target[c]).abs() > tolerance) {
          count++;
          break;
        }
      }
    }
    return count;
  }
}
