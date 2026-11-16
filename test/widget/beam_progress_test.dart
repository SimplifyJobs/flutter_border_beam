import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_phases.dart';
import 'package:flutter_border_beam/src/look/rotate_look.dart';
import 'package:flutter_border_beam/src/render/beam_frame.dart';
import 'package:flutter_border_beam/src/render/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: app!,
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, height: 140, child: child)),
  ),
);

BeamPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .first;

// The phases the painter draws right now, driven sweep included.
BeamFramePhases _now(WidgetTester tester) {
  final painter = _painter(tester);
  return painter.resolver.sample(
    painter.clock.elapsedSeconds,
    painter.clock.fadeOpacity,
    progress: painter.progress?.value,
  );
}

BeamFrameData _frame(WidgetTester tester) =>
    _painter(tester).renderer.debugFrame;

// How far the painted rotate head sits from [progress] round the ring.
double _headOffset(WidgetTester tester, double progress) {
  final head = _frame(tester).conicStart + rotateHeadStop;
  return ((head - progress) + 0.5) % 1.0 - 0.5;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

// Derived, so a new effect joins the family it belongs to.
final _travelling = [
  for (final effect in BeamEffect.values)
    if (effect.travels) effect,
];

final _ambient = [
  for (final effect in BeamEffect.values)
    if (!effect.travels) effect,
];

/// `BorderBeam.progress`: a value, not the clock, places the sweep of a
/// travelling effect, while the fade and the hue keep running underneath.
void main() {
  setUpAll(() async {
    await BorderBeam.precache();
  });

  for (final effect in _travelling) {
    testWidgets('drives the ${effect.name} sweep and holds it there', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            effect: effect,
            progress: 0.3,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await _settle(tester);
      expect(_painter(tester).progress?.value, 0.3);
      var phases = _now(tester);
      expect(phases.travelProgress, 0.3);
      expect(phases.travellers.first, 0.3);
      expect(phases.driven, isTrue);

      await tester.pump(const Duration(milliseconds: 900));
      phases = _now(tester);
      expect(phases.travelProgress, 0.3, reason: 'time does not move it');
      expect(phases.driven, isTrue);
    });
  }

  testWidgets('clamps out-of-range values into 0–1', (tester) async {
    Widget build(double progress) =>
        _host(BorderBeam(progress: progress, child: const SizedBox.expand()));

    await tester.pumpWidget(build(1.7));
    expect(_painter(tester).progress?.value, 1);
    expect(_now(tester).travelProgress, 1);

    await tester.pumpWidget(build(-0.4));
    expect(_painter(tester).progress?.value, 0);
    expect(_now(tester).travelProgress, 0);
  });

  testWidgets('the clock, fade and hue keep running underneath', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BorderBeam(
          effect: BeamEffect.line(),
          progress: 0.5,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final painter = _painter(tester);
    expect(painter.clock.isRunning, isTrue);
    final fading = _now(tester);
    expect(fading.fadeOpacity, lessThan(1), reason: 'still fading in');

    await tester.pump(const Duration(milliseconds: 1500));
    final later = _now(tester);
    expect(later.fadeOpacity, closeTo(1, 1e-6));
    expect(later.travelProgress, fading.travelProgress);
    expect(later.hueDegrees, isNot(closeTo(fading.hueDegrees, 1e-6)));
  });

  testWidgets('the rest between sweeps does not dim a driven sweep', (
    tester,
  ) async {
    // A 1.4s sweep that rests 1.6s after each pass.
    await tester.pumpWidget(
      _host(
        const BorderBeam(
          timing: BeamTiming(
            cycle: Duration(milliseconds: 1400),
            cycleGap: Duration(milliseconds: 1600),
          ),
          progress: 0.5,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    final painter = _painter(tester);
    final t = painter.clock.elapsedSeconds;
    expect(
      painter.resolver.sample(t, 1).fadeOpacity,
      0,
      reason: 'the timed sweep would be resting now',
    );
    expect(painter.progress?.value, 0.5);
    final driven = painter.resolver.sample(
      t,
      1,
      progress: painter.progress?.value,
    );
    expect(driven.fadeOpacity, 1);
    expect(driven.travelProgress, 0.5);
  });

  testWidgets('a change repaints without re-resolving the config', (
    tester,
  ) async {
    // Frozen: the clock never ticks, so only the progress itself can repaint.
    Widget build(double progress) => _host(
      BorderBeam(
        effect: const BeamEffect.rotate(),
        progress: progress,
        playback: const BeamPlayback(
          debugFrozenAt: Duration(milliseconds: 1300),
        ),
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build(0.2));
    await tester.pump();
    final before = _painter(tester);
    expect(_headOffset(tester, 0.2), closeTo(0, 1e-6));

    await tester.pumpWidget(build(0.8));
    final after = _painter(tester);
    expect(identical(before.config, after.config), isTrue);
    expect(identical(before.resolver, after.resolver), isTrue);
    expect(after.shouldRepaint(before), isFalse);
    expect(after.progress?.value, 0.8);
    expect(
      _headOffset(tester, 0.8),
      closeTo(0, 1e-6),
      reason: 'the new value reached the painted frame',
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('null hands the travel back to the clock', (tester) async {
    Widget build(double? progress) => _host(
      BorderBeam(
        progress: progress,
        timing: const BeamTiming(cycle: Duration(seconds: 2)),
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build(0.9));
    await _settle(tester);
    expect(_now(tester).travelProgress, 0.9);

    await tester.pumpWidget(build(null));
    final painter = _painter(tester);
    expect(painter.progress?.value, isNull);
    final phases = _now(tester);
    expect(phases.driven, isFalse);
    expect(
      phases.travelProgress,
      closeTo((painter.clock.elapsedSeconds / 2) % 1.0, 1e-9),
      reason: 'the timed sweep, wherever its schedule has it',
    );

    await tester.pumpWidget(_host(const SizedBox.expand()));
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final effect in _ambient) {
    testWidgets('${effect.name} has no travel for it to drive', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            effect: effect,
            progress: 0.5,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await _settle(tester);
      final phases = _now(tester);
      expect(phases.travelProgress, 0);
      expect(phases.driven, isFalse);
    });
  }

  testWidgets('a reduced-motion static frame still reads the value', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        const BorderBeam(
          effect: BeamEffect.rotate(),
          progress: 0.6,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final painter = _painter(tester);
    expect(painter.staticMode, isTrue);
    expect(tester.binding.transientCallbackCount, 0);

    final phases = painter.resolver.staticFrame(
      progress: painter.progress?.value,
    );
    expect(phases.travelProgress, 0.6);
    expect(phases.driven, isTrue);
    expect(_headOffset(tester, 0.6), closeTo(0, 1e-6));
  });

  testWidgets('BorderBeam.overlay takes it too', (tester) async {
    await tester.pumpWidget(
      _host(
        const Stack(
          children: [
            Positioned.fill(
              child: BorderBeam.overlay(
                effect: BeamEffect.line(),
                progress: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
    await _settle(tester);
    expect(tester.getSize(find.byType(BorderBeam)), const Size(350, 140));
    expect(_painter(tester).progress?.value, 0.3);
    expect(_now(tester).travelProgress, 0.3);
  });
}
