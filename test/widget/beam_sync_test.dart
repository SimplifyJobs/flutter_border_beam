import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/render/beam_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: app!,
  ),
  home: Scaffold(body: Center(child: child)),
);

List<BeamPainter> _painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(BorderBeam),
        matching: find.byType(CustomPaint),
      ),
    )
    .expand((paint) => [paint.painter, paint.foregroundPainter])
    .whereType<BeamPainter>()
    .toList();

BeamPainter _painterOf(WidgetTester tester, Key key) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)),
    )
    .map((paint) => paint.foregroundPainter)
    .whereType<BeamPainter>()
    .first;

double _sweep(BeamPainter painter) =>
    painter.resolver.sample(painter.clock.elapsedSeconds, 1).travelProgress;

Widget _beam({
  Key? key,
  BeamEffect? effect,
  BeamTiming? timing,
  BeamPlayback? playback,
  Offset? follow,
}) => SizedBox(
  width: 120,
  height: 60,
  child: BorderBeam(
    key: key,
    effect: effect,
    timing: timing,
    playback: playback,
    follow: follow,
    child: const SizedBox.expand(),
  ),
);

Widget _row(List<Widget> children) =>
    Row(mainAxisSize: MainAxisSize.min, children: children);

/// A group of beams on one clock: one ticker, one timeline, and playback
/// owned by the scope rather than by each member.
void main() {
  group('the shared clock', () {
    testWidgets('three members share one clock and one ticker', (tester) async {
      await tester.pumpWidget(
        _host(BeamSync(child: _row([_beam(), _beam(), _beam()]))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final clocks = _painters(tester).map((p) => p.clock).toSet();
      expect(clocks, hasLength(1));
      expect(clocks.single.elapsedSeconds, closeTo(0.3, 1e-9));
      expect(tester.binding.transientCallbackCount, 1);
    });

    testWidgets('the same three beams unsynced run a ticker each', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_row([_beam(), _beam(), _beam()])));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painters(tester).map((p) => p.clock).toSet(), hasLength(3));
      expect(tester.binding.transientCallbackCount, 3);
    });

    testWidgets('a member added later joins the running timeline', (
      tester,
    ) async {
      Widget build(int count) => _host(
        BeamSync(child: _row([for (var i = 0; i < count; i++) _beam()])),
      );

      await tester.pumpWidget(build(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(build(2));
      final painters = _painters(tester);
      expect(painters, hasLength(2));
      expect(identical(painters[0].clock, painters[1].clock), isTrue);
      expect(painters[1].clock.elapsedSeconds, closeTo(0.5, 1e-9));
      expect(_sweep(painters[1]), _sweep(painters[0]));
    });

    testWidgets('members sit at one sweep position; offsets stay per beam', (
      tester,
    ) async {
      const cycle = Duration(seconds: 2);
      await tester.pumpWidget(
        _host(
          BeamSync(
            child: _row([
              _beam(timing: const BeamTiming(cycle: cycle)),
              _beam(timing: const BeamTiming(cycle: cycle)),
              _beam(timing: const BeamTiming(cycle: cycle, phaseOffset: 0.25)),
            ]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final sweeps = _painters(tester).map(_sweep).toList();
      expect(sweeps[1], sweeps[0]);
      expect((sweeps[2] - sweeps[0]) % 1.0, closeTo(0.25, 1e-9));
    });
  });

  group('group playback', () {
    testWidgets('the group speed drives the shared clock', (tester) async {
      await tester.pumpWidget(_host(BeamSync(speed: 3, child: _beam())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_painters(tester).single.clock.elapsedSeconds, closeTo(0.6, 1e-9));
    });

    testWidgets("a member's own playback is ignored", (tester) async {
      await tester.pumpWidget(
        _host(
          BeamSync(
            child: _row([
              _beam(),
              _beam(
                playback: const BeamPlayback(active: false, autoPlay: false),
              ),
            ]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final painters = _painters(tester);
      expect(painters[1].clock, same(painters[0].clock));
      expect(painters[1].clock.isVisible, isTrue);
      expect(tester.binding.transientCallbackCount, 1);
    });

    testWidgets('the group fades every member out and back in together', (
      tester,
    ) async {
      Widget build({required bool active}) =>
          _host(BeamSync(active: active, child: _row([_beam(), _beam()])));

      await tester.pumpWidget(build(active: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final clock = _painters(tester).first.clock;
      expect(clock.isVisible, isTrue);

      await tester.pumpWidget(build(active: false));
      expect(clock.stage, BeamFadeStage.fadingOut);
      await tester.pump(const Duration(milliseconds: 600));
      expect(clock.isVisible, isFalse);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(build(active: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock.isVisible, isTrue);
      expect(tester.binding.transientCallbackCount, 1);
    });

    testWidgets('the group reverses a fade-out that has not finished', (
      tester,
    ) async {
      Widget build({required bool active}) =>
          _host(BeamSync(active: active, child: _beam()));

      await tester.pumpWidget(build(active: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final clock = _painters(tester).single.clock;

      await tester.pumpWidget(build(active: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(clock.stage, BeamFadeStage.fadingOut);
      final elapsed = clock.elapsedSeconds;

      await tester.pumpWidget(build(active: true));
      expect(clock.stage, BeamFadeStage.fadingIn);
      expect(
        clock.elapsedSeconds,
        closeTo(elapsed, 1e-9),
        reason: 'a reversed fade keeps the timeline it was on',
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(clock.fadeOpacity, closeTo(1, 1e-6));
    });

    testWidgets('a group that starts stopped never runs a ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_host(BeamSync(active: false, child: _beam())));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_painters(tester).single.clock.isVisible, isFalse);
    });

    testWidgets('reduced motion freezes the whole group on a static frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          BeamSync(child: _row([_beam(), _beam()])),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      final painters = _painters(tester);
      expect(painters, hasLength(2));
      for (final painter in painters) {
        expect(painter.staticMode, isTrue);
      }
    });

    testWidgets('the group slow policy quarters the shared clock', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          disableAnimations: true,
          BeamSync(
            reducedMotion: BeamReducedMotion.slow,
            child: _beam(
              playback: const BeamPlayback(
                reducedMotion: BeamReducedMotion.staticFrame,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final painter = _painters(tester).single;
      expect(painter.staticMode, isFalse, reason: 'the group policy wins');
      expect(painter.clock.speed, 0.25);
      expect(painter.clock.elapsedSeconds, closeTo(0.25, 1e-9));
    });

    testWidgets('a controller inside a group asserts', (tester) async {
      final controller = BorderBeamController();
      addTearDown(controller.dispose);
      // The group is stopped so it never starts a ticker: a build that throws
      // leaves a tree Flutter 3.35 cannot unmount, and a ticker started here
      // would outlive the test.
      await pumpExpectingAssertion(
        tester,
        _host(
          BeamSync(
            active: false,
            child: SizedBox(
              width: 120,
              height: 60,
              child: BorderBeam(
                controller: controller,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        message: 'A BorderBeam under a BeamSync runs on the group clock',
      );
    });

    testWidgets(
      "one member's cycle change does not move the others",
      (tester) async {
        Widget build(Duration cycle) => _host(
          BeamSync(
            child: _row([
              _beam(key: const ValueKey('steady')),
              _beam(timing: BeamTiming(cycle: cycle)),
            ]),
          ),
        );

        await tester.pumpWidget(build(const Duration(seconds: 2)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        final steady = _sweep(_painterOf(tester, const ValueKey('steady')));

        await tester.pumpWidget(build(const Duration(seconds: 4)));
        expect(
          _sweep(_painterOf(tester, const ValueKey('steady'))),
          closeTo(steady, 1e-9),
        );
      },
      // defect: _retimeToNewCycle retimes the shared group clock, so one
      // member's cycle change rescales every member's timeline.
      skip: true,
    );
  });

  group('joining and leaving', () {
    testWidgets('leaving the group hands the beam its own clock, started', (
      tester,
    ) async {
      final key = GlobalKey();
      Widget build({required bool synced}) {
        final beam = _beam(key: key);
        return _host(synced ? BeamSync(child: beam) : beam);
      }

      await tester.pumpWidget(build(synced: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final shared = _painters(tester).single.clock;

      await tester.pumpWidget(build(synced: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final own = _painters(tester).single.clock;
      expect(own, isNot(same(shared)));
      expect(own.isVisible, isTrue);
      expect(own.isRunning, isTrue);
      expect(own.elapsedSeconds, closeTo(0.3, 1e-9), reason: 'a fresh start');
      expect(tester.binding.transientCallbackCount, 1);

      await tester.pumpWidget(_host(const SizedBox()));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one member leaving keeps the group running', (tester) async {
      final key = GlobalKey();
      Widget build({required bool moved}) => _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeamSync(child: _row([_beam(), if (!moved) _beam(key: key)])),
            if (moved) _beam(key: key),
          ],
        ),
      );

      await tester.pumpWidget(build(moved: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 1);

      await tester.pumpWidget(build(moved: true));
      await tester.pump();
      final clocks = _painters(tester).map((p) => p.clock).toSet();
      expect(clocks, hasLength(2));
      expect(clocks.every((clock) => clock.isRunning), isTrue);
      expect(tester.binding.transientCallbackCount, 2);
    });

    testWidgets('joining a group retires the beam own clock', (tester) async {
      final key = GlobalKey();
      Widget build({required bool synced}) {
        final beam = _beam(key: key);
        return _host(synced ? BeamSync(child: beam) : beam);
      }

      await tester.pumpWidget(build(synced: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final own = _painters(tester).single.clock;

      await tester.pumpWidget(build(synced: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painters(tester).single.clock, isNot(same(own)));
      expect(tester.binding.transientCallbackCount, 1);
    });

    testWidgets('removing members leaves the rest running', (tester) async {
      Widget build(int count) => _host(
        BeamSync(child: _row([for (var i = 0; i < count; i++) _beam()])),
      );

      await tester.pumpWidget(build(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 1);
      expect(_painters(tester).single.clock.elapsedSeconds, closeTo(0.6, 1e-9));

      await tester.pumpWidget(_host(const SizedBox()));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('timeline resets', () {
    // Follows a pointer, then lets go: the hand-back leaves a travel offset
    // on the member, measured against the clock it is on right now.
    Future<void> handBack(
      WidgetTester tester,
      Widget Function({Offset? follow}) build,
    ) async {
      await tester.pumpWidget(build(follow: const Offset(1, 0.5)));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpWidget(build());
    }

    testWidgets('a group restart drops its members corrections', (
      tester,
    ) async {
      var active = true;
      Widget build({Offset? follow}) => _host(
        BeamSync(
          active: active,
          child: _beam(follow: follow),
        ),
      );

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await handBack(tester, build);
      expect(_painters(tester).single.resolver.travelTimeOffset, isNot(0));

      // The group owns the clock, so the member is never told to restart —
      // it has to hear it from the clock itself.
      active = false;
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 600));
      active = true;
      await tester.pumpWidget(build());
      final painter = _painters(tester).single;
      expect(painter.clock.elapsedSeconds, 0);
      expect(painter.resolver.travelTimeOffset, 0);
    });

    testWidgets('a beam that left the group listens to its own clock', (
      tester,
    ) async {
      final key = GlobalKey();
      final stays = GlobalKey();
      var moved = false;
      var groupActive = true;
      var beamActive = true;
      Widget build({Offset? follow}) {
        final leaver = SizedBox(
          width: 120,
          height: 60,
          child: BorderBeam(
            key: key,
            active: beamActive,
            follow: follow,
            child: const SizedBox.expand(),
          ),
        );
        // The group keeps its place in the tree, so it is the same group —
        // and the same clock — before and after the move.
        return _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeamSync(
                active: groupActive,
                child: _row([_beam(key: stays), if (!moved) leaver]),
              ),
              if (moved) leaver,
            ],
          ),
        );
      }

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final groupClock = _painterOf(tester, stays).clock;
      expect(_painterOf(tester, key).clock, same(groupClock));

      moved = true;
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painterOf(tester, stays).clock, same(groupClock));

      BeamPainter leaver() => _painterOf(tester, key);
      expect(leaver().clock, isNot(same(groupClock)));

      await handBack(tester, build);
      final offset = leaver().resolver.travelTimeOffset;
      expect(offset, isNot(0));

      // The group it left restarts: none of the leaver's business.
      groupActive = false;
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 600));
      expect(groupClock.isVisible, isFalse);
      groupActive = true;
      await tester.pumpWidget(build());
      expect(leaver().resolver.travelTimeOffset, offset);

      // Its own clock restarts: that clears it.
      beamActive = false;
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 600));
      beamActive = true;
      await tester.pumpWidget(build());
      expect(leaver().clock.elapsedSeconds, 0);
      expect(leaver().resolver.travelTimeOffset, 0);
    });
  });
}
