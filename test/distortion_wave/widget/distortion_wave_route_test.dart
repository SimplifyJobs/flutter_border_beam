import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:prismatic/prismatic.dart';
import 'package:prismatic/src/distortion_wave/render/render_wave_stage.dart';

import 'wave_test_utils.dart';

/// `DistortionWaveRoute`: the wave from the button that pushed it into the
/// new page, a picture of the page underneath for it to bend, and the
/// collapse on pop.
void main() {
  // Every test here also checks that the route disposes what it makes.
  LeakTesting.enable();
  setUpAll(DistortionWave.precache);

  final navigatorKey = GlobalKey<NavigatorState>();
  late Animation<double> homeSecondary;

  Widget app({bool disableAnimations = false}) => waveHost(
    Navigator(
      key: navigatorKey,
      onGenerateInitialRoutes: (navigator, name) => [
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondary) {
            homeSecondary = secondary;
            return Stack(
              children: [
                flatSide(outgoingColor, 'home'),
                Positioned(
                  left: 20,
                  top: 764,
                  width: 350,
                  height: 56,
                  child: DistortionWaveAnchor(
                    child: Builder(
                      builder: (context) => GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          DistortionWaveRoute<void>(
                            source: WaveSource.of(context),
                            builder: (_) => flatSide(incomingColor, 'next'),
                          ),
                        ),
                        child: const ColoredBox(
                          key: ValueKey('send'),
                          color: Color(0xFF3D7BFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
    disableAnimations: disableAnimations,
  );

  DistortionWaveRoute<void> topRoute() {
    late Route<dynamic> top;
    navigatorKey.currentState!.popUntil((route) {
      top = route;
      return true;
    });
    return top as DistortionWaveRoute<void>;
  }

  testWidgets('a push plays the wave from the button into the new page', (
    tester,
  ) async {
    useWaveView(tester);
    await tester.pumpWidget(app());
    await tester.tapAt(const Offset(300, 790));
    await tester.pump();
    final route = topRoute();
    expect(route.transitionDuration.inMilliseconds, greaterThan(3000));

    await tester.pump();
    expect(route.debugBelow.value, isNotNull, reason: 'the page underneath');
    await tester.pump(const Duration(milliseconds: 900));
    expect(waveStage(tester).debugLastPhase, WavePhase.distorting);
    final origin = waveStage(tester).source!.resolve(waveStage(tester))!;
    expect(origin.rect, const Rect.fromLTWH(20, 764, 350, 56));
    expect(origin.focus, const Offset(300, 790));
    expect(
      homeSecondary.value,
      0,
      reason: 'the page underneath plays no exit of its own',
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next')), findsOneWidget);
    expect(find.byKey(const ValueKey('home')), findsNothing);
    expect(waveStage(tester).debugLastPhase, WavePhase.rest);
  });

  testWidgets('a pop collapses it back onto the page underneath', (
    tester,
  ) async {
    useWaveView(tester);
    await tester.pumpWidget(app());
    await tester.tapAt(const Offset(195, 790));
    await tester.pumpAndSettle();
    final route = topRoute();

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump();
    await tester.pump(
      Duration(
        milliseconds: route.reverseTransitionDuration.inMilliseconds ~/ 3,
      ),
    );
    expect(waveStage(tester).progress.value, inExclusiveRange(0, 1));
    expect(route.reverseTransitionDuration < route.transitionDuration, isTrue);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next')), findsNothing);
    expect(find.byKey(const ValueKey('home')), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('with reduced motion the route crossfades in 0.3 s', (
    tester,
  ) async {
    useWaveView(tester);
    await tester.pumpWidget(app(disableAnimations: true));
    await tester.tapAt(const Offset(195, 790));
    await tester.pump();
    expect(topRoute().transitionDuration, const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 150));
    expect(waveStage(tester).debugLastPhase, WavePhase.crossfading);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next')), findsOneWidget);
  });

  testWidgets(
    'a push and a pop leave nothing undisposed',
    experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
    (tester) async {
      useWaveView(tester);
      await tester.pumpWidget(app());
      await tester.tapAt(const Offset(300, 790));
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('next')), findsNothing);
    },
  );
}
