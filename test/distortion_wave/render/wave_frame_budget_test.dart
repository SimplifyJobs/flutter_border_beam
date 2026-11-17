import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/distortion_wave/models/wave_spec.dart';
import 'package:prismatic/src/distortion_wave/render/render_wave_stage.dart';
import 'package:prismatic/src/distortion_wave/timeline/wave_frame.dart';

import '../widget/wave_test_utils.dart';

/// The wave's frame budget, phase by phase: while it bends content a frame
/// is one shader rect and at most one atlas of dots — no layers, clips,
/// filters or image draws — and a side is pictured only when its content
/// changes (or every frame, when asked).
void main() {
  setUpAll(DistortionWave.precache);

  /// A progress in each phase of [type]'s wave.
  Map<String, double> phases(WaveType type) {
    final spec = WaveSpec.resolve(WaveStyle(type: type));
    WaveFrame at(double p) => WaveFrame.at(
      progress: p,
      source: const Rect.fromLTWH(20, 764, 350, 56),
      size: waveTestSize,
      spec: spec,
    );
    final settled = [
      for (var p = 0.05; p < 1; p += 0.01)
        if (at(p).contentAtRest && at(p).rim > 0) p,
    ];
    return {
      'anticipation': spec.anticipation * 0.6 / spec.duration,
      'launch': (spec.anticipation + 0.1) / spec.duration,
      'mid-travel': (spec.anticipation + spec.travel * 0.12) / spec.duration,
      if (settled.isNotEmpty) 'edges linger': settled.first,
    };
  }

  Widget held(double progress, WaveType type) => waveHost(
    DistortionWave(
      progress: progress,
      type: type,
      source: const WaveSource.rect(Rect.fromLTWH(20, 764, 350, 56)),
      revealedChild: flatSide(incomingColor, 'in'),
      child: flatSide(outgoingColor, 'out'),
    ),
  );

  for (final type in WaveType.values) {
    // The glowing case below is found by a scan; a type without one fails
    // here rather than dropping the case.
    test('${type.name} has a frame where the edges linger', () {
      expect(phases(type), contains('edges linger'));
    });

    for (final MapEntry(key: name, value: p) in phases(type).entries) {
      testWidgets('${type.name}, $name: one shader rect, no layers', (
        tester,
      ) async {
        useWaveView(tester);
        await tester.pumpWidget(held(p, type));
        final stage = waveStage(tester);
        final lingering = name == 'edges linger';
        expect(
          stage.debugLastPhase,
          lingering ? WavePhase.glowing : WavePhase.distorting,
        );
        // The revealed side paints one rect of its own when drawn as itself.
        expect(stage, paintsExactlyCountTimes(#drawRect, lingering ? 2 : 1));
        expect(stage, paintsExactlyCountTimes(#saveLayer, 0));
        expect(stage, paintsExactlyCountTimes(#clipRect, 0));
        expect(stage, paintsExactlyCountTimes(#clipRRect, 0));
        expect(stage, paintsExactlyCountTimes(#clipPath, 0));
        expect(stage, paintsExactlyCountTimes(#drawImage, 0));
        expect(stage, paintsExactlyCountTimes(#drawImageRect, 0));
        expect(
          stage,
          paints..something((method, arguments) {
            if (method != #drawRect) return false;
            return (arguments[1]! as Paint).shader != null;
          }),
        );
      });
    }
  }

  testWidgets('at rest it paints the visible side and nothing else', (
    tester,
  ) async {
    useWaveView(tester);
    await tester.pumpWidget(held(0, WaveType.vertical));
    final stage = waveStage(tester);
    expect(stage.debugLastPhase, WavePhase.rest);
    expect(stage, paintsExactlyCountTimes(#drawRect, 1));
    expect(stage, paintsExactlyCountTimes(#drawRawAtlas, 0));
    expect(stage.debugSnapshotCount, {
      WaveSlot.outgoing: 0,
      WaveSlot.incoming: 0,
    });
  });

  group('pictures of the sides', () {
    Widget running({
      required ValueNotifier<Color> outgoing,
      WaveSnapshots? snapshots,
    }) => waveHost(
      DistortionWave(
        revealed: true,
        snapshots: snapshots,
        revealedChild: flatSide(incomingColor, 'in'),
        child: ValueListenableBuilder<Color>(
          valueListenable: outgoing,
          builder: (context, color, _) => flatSide(color, 'out'),
        ),
      ),
    );

    Future<RenderWaveStage> startWave(
      WidgetTester tester,
      ValueNotifier<Color> outgoing, {
      WaveSnapshots? snapshots,
    }) async {
      useWaveView(tester);
      await tester.pumpWidget(
        waveHost(
          DistortionWave(
            snapshots: snapshots,
            revealedChild: flatSide(incomingColor, 'in'),
            child: flatSide(outgoingColor, 'out'),
          ),
        ),
      );
      await tester.pumpWidget(
        running(outgoing: outgoing, snapshots: snapshots),
      );
      await tester.pump();
      return waveStage(tester);
    }

    testWidgets('a still side is pictured once per run', (tester) async {
      final outgoing = ValueNotifier(outgoingColor);
      addTearDown(outgoing.dispose);
      final stage = await startWave(tester, outgoing);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(stage.debugLastPhase, WavePhase.distorting);
      expect(stage.debugSnapshotCount[WaveSlot.outgoing], 1);
    });

    testWidgets('a side whose content repaints is pictured again', (
      tester,
    ) async {
      final outgoing = ValueNotifier(outgoingColor);
      addTearDown(outgoing.dispose);
      final stage = await startWave(tester, outgoing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(stage.debugSnapshotCount[WaveSlot.outgoing], 1);
      outgoing.value = const Color(0xFFAA2244);
      await tester.pump(const Duration(milliseconds: 16));
      expect(stage.debugSnapshotCount[WaveSlot.outgoing], 2);
      await tester.pump(const Duration(milliseconds: 16));
      expect(stage.debugSnapshotCount[WaveSlot.outgoing], 2);
    });

    testWidgets('everyFrame pictures the side on every frame', (tester) async {
      final outgoing = ValueNotifier(outgoingColor);
      addTearDown(outgoing.dispose);
      final stage = await startWave(
        tester,
        outgoing,
        snapshots: WaveSnapshots.everyFrame,
      );
      await tester.pump(const Duration(milliseconds: 16));
      final before = stage.debugSnapshotCount[WaveSlot.outgoing]!;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(stage.debugSnapshotCount[WaveSlot.outgoing], before + 5);
    });

    testWidgets('the incoming side is pictured only once the front leaves', (
      tester,
    ) async {
      final outgoing = ValueNotifier(outgoingColor);
      addTearDown(outgoing.dispose);
      final stage = await startWave(tester, outgoing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(stage.debugSnapshotCount[WaveSlot.incoming], 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(stage.debugSnapshotCount[WaveSlot.incoming], 1);
    });
  });
}
