import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/distortion_wave/models/wave_spec.dart';
import 'package:prismatic/src/distortion_wave/render/render_wave_stage.dart';
import 'package:prismatic/src/distortion_wave/wave_source.dart';

import 'wave_test_utils.dart';

/// `DistortionWave` itself: running, reversing, finishing, touches, the
/// hidden side, reduced motion, scrubbing, controller, theme and anchors.
void main() {
  setUpAll(DistortionWave.precache);

  final vertical = WaveSpec.resolve(null);

  Widget wave({
    bool revealed = false,
    VoidCallback? onFinish,
    DistortionWaveController? controller,
    double? progress,
    bool maintainState = true,
    WaveStyle? style,
    WavePalette? palette,
    WaveSource? source,
    Widget? child,
    Widget? revealedChild,
  }) => DistortionWave(
    revealed: revealed,
    onFinish: onFinish,
    controller: controller,
    progress: progress,
    maintainState: maintainState,
    style: style,
    palette: palette,
    source: source,
    revealedChild: revealedChild ?? flatSide(incomingColor, 'in'),
    child: child ?? flatSide(outgoingColor, 'out'),
  );

  Duration seconds(double s) => Duration(microseconds: (s * 1e6).round());

  testWidgets('rests on the child, runs through the wave to the revealed '
      'child, and calls onFinish once', (tester) async {
    useWaveView(tester);
    var finished = 0;
    await tester.pumpWidget(waveHost(wave(onFinish: () => finished++)));
    expect(waveStage(tester).progress.value, 0);
    expect(waveStage(tester).debugLastPhase, WavePhase.rest);

    await tester.pumpWidget(
      waveHost(wave(revealed: true, onFinish: () => finished++)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(waveStage(tester).debugLastPhase, WavePhase.distorting);
    expect(finished, 0);

    await tester.pump(seconds(vertical.duration));
    expect(waveStage(tester).progress.value, 1);
    expect(waveStage(tester).debugLastPhase, WavePhase.rest);
    expect(finished, 1);
  });

  testWidgets('after the front has crossed, the revealed side is drawn as '
      'itself under the lingering colour', (tester) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave()));
    await tester.pumpWidget(waveHost(wave(revealed: true)));
    await tester.pump();
    await tester.pump(seconds(vertical.anticipation + vertical.travel * 0.7));
    expect(waveStage(tester).debugLastPhase, WavePhase.glowing);
  });

  testWidgets('flipping back mid-run collapses from where it is, and only '
      'the collapse finishes', (tester) async {
    useWaveView(tester);
    final finishes = <bool>[];
    await tester.pumpWidget(waveHost(wave()));
    await tester.pumpWidget(
      waveHost(wave(revealed: true, onFinish: () => finishes.add(true))),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final at = waveStage(tester).progress.value;
    expect(at, inExclusiveRange(0, 1));

    await tester.pumpWidget(
      waveHost(wave(onFinish: () => finishes.add(false))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      waveStage(tester).progress.value,
      lessThanOrEqualTo(at),
      reason: 'it turns back without a jump',
    );
    // It leaves on the wave's easing, which starts fast — as the reference
    // does — but from where it was.
    expect(
      waveStage(tester).progress.value,
      closeTo(at, 0.05),
      reason: 'it turns back without a jump',
    );
    await tester.pump(seconds(vertical.returnDuration));
    expect(waveStage(tester).progress.value, 0);
    expect(finishes, [false]);
  });

  testWidgets('a full collapse is quicker than the reveal', (tester) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave(revealed: true)));
    expect(waveStage(tester).progress.value, 1);
    await tester.pumpWidget(waveHost(wave()));
    await tester.pump();
    await tester.pump(seconds(vertical.returnDuration * 0.98));
    expect(waveStage(tester).progress.value, greaterThan(0));
    await tester.pump(seconds(vertical.returnDuration * 0.04));
    expect(waveStage(tester).progress.value, 0);
  });

  testWidgets('neither side takes a touch while the wave runs; the side at '
      'rest does', (tester) async {
    useWaveView(tester);
    final taps = <String>[];
    Widget tappable(String name, Color color) => GestureDetector(
      onTap: () => taps.add(name),
      child: flatSide(color, name),
    );
    Widget build({bool revealed = false}) => waveHost(
      wave(
        revealed: revealed,
        revealedChild: tappable('in', incomingColor),
        child: tappable('out', outgoingColor),
      ),
    );

    await tester.pumpWidget(build());
    await tester.tapAt(const Offset(195, 300));
    expect(taps, ['out']);

    await tester.pumpWidget(build(revealed: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(195, 300), kind: PointerDeviceKind.touch);
    expect(taps, ['out'], reason: 'nothing takes a touch mid-run');

    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 300));
    expect(taps, ['out', 'in']);
  });

  testWidgets('the hidden side stays mounted with its tickers muted', (
    tester,
  ) async {
    useWaveView(tester);
    final enabled = <String, bool>{};
    Widget probe(String name) => Builder(
      builder: (context) {
        enabled[name] = TickerMode.valuesOf(context).enabled;
        return flatSide(outgoingColor, name);
      },
    );
    await tester.pumpWidget(
      waveHost(wave(child: probe('out'), revealedChild: probe('in'))),
    );
    expect(enabled, {'out': true, 'in': false});
    expect(find.byKey(const ValueKey('in')), findsOneWidget);
  });

  testWidgets('without maintainState the hidden side is built only while '
      'the wave runs', (tester) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave(maintainState: false)));
    expect(find.byKey(const ValueKey('in')), findsNothing);

    await tester.pumpWidget(
      waveHost(wave(revealed: true, maintainState: false)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('in')), findsOneWidget);
    expect(find.byKey(const ValueKey('out')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('out')), findsNothing);
    expect(find.byKey(const ValueKey('in')), findsOneWidget);
  });

  testWidgets('with reduced motion it crossfades in 0.3 s', (tester) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave(), disableAnimations: true));
    await tester.pumpWidget(
      waveHost(wave(revealed: true), disableAnimations: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(waveStage(tester).debugLastPhase, WavePhase.crossfading);
    await tester.pump(const Duration(milliseconds: 160));
    expect(waveStage(tester).progress.value, 1);
  });

  testWidgets('progress holds the wave at a point of its life', (tester) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave(progress: 0.2)));
    expect(waveStage(tester).progress.value, 0.2);
    expect(waveStage(tester).debugLastPhase, WavePhase.distorting);
    expect(tester.binding.transientCallbackCount, 0, reason: 'nothing ticks');

    await tester.pumpWidget(waveHost(wave(progress: 0.9)));
    expect(waveStage(tester).progress.value, 0.9);
  });

  group('a controller', () {
    testWidgets('owns playback: reveal, collapse, seek', (tester) async {
      useWaveView(tester);
      final controller = DistortionWaveController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(waveHost(wave(controller: controller)));

      controller.reveal();
      expect(controller.isRevealed, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(controller.isRunning, isTrue);
      expect(controller.progress, inExclusiveRange(0, 1));

      // `revealed` is ignored while the controller is attached.
      await tester.pumpWidget(
        waveHost(wave(controller: controller, revealed: true)),
      );
      await tester.pumpAndSettle();
      expect(controller.progress, 1);

      controller.seek(0.4);
      await tester.pump();
      expect(waveStage(tester).progress.value, 0.4);
      expect(controller.isRunning, isFalse);

      controller.collapse();
      await tester.pumpAndSettle();
      expect(controller.progress, 0);
      expect(controller.isRevealed, isFalse);
    });

    testWidgets('notifies when a run starts and when it arrives', (
      tester,
    ) async {
      useWaveView(tester);
      final controller = DistortionWaveController();
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);
      await tester.pumpWidget(waveHost(wave(controller: controller)));
      controller.reveal();
      expect(notified, 1);
      await tester.pumpAndSettle();
      expect(notified, 2);
    });

    testWidgets('drives one wave at a time', (tester) async {
      useWaveView(tester);
      final controller = DistortionWaveController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        waveHost(
          Column(
            children: [
              Expanded(child: wave(controller: controller)),
              Expanded(child: wave(controller: controller)),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  testWidgets("the theme's style applies under the widget's", (tester) async {
    useWaveView(tester);
    await tester.pumpWidget(
      waveHost(
        DistortionWaveTheme(
          data: const DistortionWaveThemeData(
            style: WaveStyle(
              palette: WavePalette.ocean,
              lens: WaveLens(blur: 9),
            ),
          ),
          child: wave(),
        ),
      ),
    );
    expect(waveStage(tester).spec.palette, WavePalette.ocean);
    expect(waveStage(tester).spec.blur, 9);

    await tester.pumpWidget(
      waveHost(
        DistortionWaveTheme(
          data: const DistortionWaveThemeData(
            style: WaveStyle(palette: WavePalette.ocean),
          ),
          child: wave(palette: WavePalette.sunset),
        ),
      ),
    );
    expect(waveStage(tester).spec.palette, WavePalette.sunset);
  });

  testWidgets('opens from the anchor pressed last, leaning with the touch', (
    tester,
  ) async {
    useWaveView(tester);
    Widget screen() => Stack(
      children: [
        flatSide(outgoingColor, 'out'),
        Positioned(
          left: 40,
          top: 700,
          width: 300,
          height: 60,
          child: DistortionWaveAnchor(
            child: GestureDetector(
              onTap: () {},
              child: const ColoredBox(color: Color(0xFF00FF00)),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(waveHost(wave(child: screen())));
    await tester.tapAt(const Offset(300, 720));
    await tester.pumpWidget(waveHost(wave(revealed: true, child: screen())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final stage = waveStage(tester);
    final origin = stage.source!.resolve(stage)!;
    expect(origin.rect, const Rect.fromLTWH(40, 700, 300, 60));
    expect(origin.focus, const Offset(300, 720));
  });

  testWidgets('WaveSource.of measures the anchor and carries its touch', (
    tester,
  ) async {
    useWaveView(tester);
    WaveSource? source;
    await tester.pumpWidget(
      waveHost(
        Stack(
          children: [
            Positioned(
              left: 10,
              top: 20,
              width: 100,
              height: 50,
              child: DistortionWaveAnchor(
                child: Builder(
                  builder: (context) => GestureDetector(
                    onTap: () => source = WaveSource.of(context),
                    child: const ColoredBox(color: Color(0xFF00FF00)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(30, 40));
    final root = tester.renderObject<RenderBox>(find.byType(Stack));
    final resolved = source!.resolve(root)!;
    expect(resolved.rect, const Rect.fromLTWH(10, 20, 100, 50));
    expect(resolved.focus, const Offset(30, 40));
  });

  testWidgets('a wave with no source and no anchor opens from its type\'s '
      'usual spot', (tester) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave(progress: 0.2)));
    final stage = waveStage(tester);
    expect(stage.source, isNull);
    expect(
      defaultWaveSource(WaveType.vertical, waveTestSize).bottom,
      lessThanOrEqualTo(waveTestSize.height),
    );
  });

  testWidgets('starts no ticker until it runs, and stops when it arrives', (
    tester,
  ) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave()));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(waveHost(wave(revealed: true)));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
  });
}
