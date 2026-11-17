import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/distortion_wave/render/render_wave_stage.dart';

import 'wave_test_utils.dart';

/// No ticker or image outlives what it belongs to: the wave disposed
/// mid-run, muted by TickerMode, a controller outliving its wave, and the
/// pictures of the sides once a run is over.
void main() {
  // Every test here also checks that the wave disposes what it makes.
  LeakTesting.enable();
  setUpAll(DistortionWave.precache);

  Widget wave({bool revealed = false, DistortionWaveController? controller}) =>
      DistortionWave(
        revealed: revealed,
        controller: controller,
        revealedChild: flatSide(incomingColor, 'in'),
        child: flatSide(outgoingColor, 'out'),
      );

  testWidgets('disposing the wave mid-run leaves no ticker', (tester) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave()));
    await tester.pumpWidget(waveHost(wave(revealed: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(waveHost(const SizedBox()));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('TickerMode mutes a running wave and resumes it', (tester) async {
    useWaveView(tester);
    Widget host({required bool enabled, bool revealed = true}) => waveHost(
      TickerMode(
        enabled: enabled,
        child: wave(revealed: revealed),
      ),
    );
    await tester.pumpWidget(host(enabled: true, revealed: false));
    await tester.pumpWidget(host(enabled: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(host(enabled: false));
    expect(tester.binding.transientCallbackCount, 0);
    final held = waveStage(tester).progress.value;
    await tester.pump(const Duration(seconds: 1));
    expect(waveStage(tester).progress.value, held);

    await tester.pumpWidget(host(enabled: true));
    await tester.pumpAndSettle();
    expect(waveStage(tester).progress.value, 1);
  });

  testWidgets('a controller outlives its wave', (tester) async {
    useWaveView(tester);
    final controller = DistortionWaveController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(waveHost(wave(controller: controller)));
    controller.reveal();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(waveHost(const SizedBox()));
    expect(tester.binding.transientCallbackCount, 0);

    controller
      ..collapse()
      ..seek(0.5);
    expect(controller.isRunning, isFalse);
    expect(controller.progress, 1, reason: 'detached, it reports its side');
  });

  testWidgets('a controller can move to another wave', (tester) async {
    useWaveView(tester);
    final a = DistortionWaveController();
    final b = DistortionWaveController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(waveHost(wave(controller: a)));
    await tester.pumpWidget(waveHost(wave(controller: b)));
    b.reveal();
    await tester.pumpAndSettle();
    expect(waveStage(tester).progress.value, 1);
    a.collapse();
    await tester.pump();
    expect(waveStage(tester).progress.value, 1, reason: 'a is detached');
  });

  testWidgets('pictures of the sides are released once they are not needed', (
    tester,
  ) async {
    useWaveView(tester);
    await tester.pumpWidget(waveHost(wave()));
    await tester.pumpWidget(waveHost(wave(revealed: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    final stage = waveStage(tester);
    expect(stage.debugLastPhase, WavePhase.distorting);
    expect(stage.debugHoldsImages, isTrue);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(stage.debugLastPhase, WavePhase.glowing);
    expect(stage.debugHoldsImages, isFalse);

    await tester.pumpAndSettle();
    expect(stage.debugLastPhase, WavePhase.rest);
    expect(stage.debugHoldsImages, isFalse);
  });

  testWidgets('a controller passes to a wave that replaces its own in the '
      'same frame, by a new key or a GlobalKey moving', (tester) async {
    useWaveView(tester);
    final controller = DistortionWaveController();
    addTearDown(controller.dispose);
    final moving = GlobalKey();
    Widget build(Key key, {bool wrapped = false}) {
      final wave = DistortionWave(
        key: key,
        controller: controller,
        revealedChild: flatSide(incomingColor, 'in'),
        child: flatSide(outgoingColor, 'out'),
      );
      return waveHost(wrapped ? SizedBox.expand(child: wave) : wave);
    }

    await tester.pumpWidget(build(const ValueKey('compact')));
    await tester.pumpWidget(build(const ValueKey('wide')));
    expect(tester.takeException(), isNull);
    controller.reveal();
    await tester.pumpAndSettle();
    expect(waveStage(tester).progress.value, 1);

    await tester.pumpWidget(build(moving));
    await tester.pumpWidget(build(moving, wrapped: true));
    expect(tester.takeException(), isNull);
    controller.collapse();
    await tester.pumpAndSettle();
    expect(waveStage(tester).progress.value, 0);
  });
}
