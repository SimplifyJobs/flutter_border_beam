import 'package:flutter/material.dart';
import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_border_beam/src/animation/beam_clock.dart';
import 'package:flutter_border_beam/src/painting/beam_painter.dart';
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

Widget _beam({double? phaseOffset, Key? key}) => SizedBox(
  width: 120,
  height: 60,
  child: BorderBeam.rotate(
    key: key,
    timing: BeamTiming(phaseOffset: phaseOffset),
    child: const SizedBox.expand(),
  ),
);

/// A group of beams on one clock: one ticker, one timeline, and playback
/// owned by the scope rather than by each member.
void main() {
  testWidgets('three beams share a single ticker', (tester) async {
    await tester.pumpWidget(
      _host(
        BeamSync(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [_beam(), _beam(), _beam()],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BorderBeam), findsNWidgets(3));
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('the same three beams unsynced run three tickers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [_beam(), _beam(), _beam()],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, 3);
  });

  testWidgets('every beam paints from the one clock', (tester) async {
    await tester.pumpWidget(
      _host(
        BeamSync(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [_beam(), _beam(), _beam()],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final clocks = _painters(tester).map((p) => p.clock).toSet();
    expect(clocks, hasLength(1));
    expect(clocks.single.elapsedSeconds, closeTo(0.3, 1e-9));
  });

  testWidgets('lockstep beams sit at the same sweep position', (tester) async {
    await tester.pumpWidget(
      _host(
        BeamSync(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [_beam(), _beam()],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final painters = _painters(tester);
    final progress = painters
        .map((p) => p.resolver.sample(p.clock.elapsedSeconds, 1).travelProgress)
        .toSet();
    expect(progress, hasLength(1));
  });

  testWidgets('each beam still applies its own phase offset', (tester) async {
    await tester.pumpWidget(
      _host(
        BeamSync(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _beam(),
              _beam(phaseOffset: 0.25),
              _beam(phaseOffset: 0.5),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final painters = _painters(tester);
    final progress = painters
        .map((p) => p.resolver.sample(p.clock.elapsedSeconds, 1).travelProgress)
        .toList();
    expect(progress, hasLength(3));
    expect(progress[1] - progress[0], closeTo(0.25, 1e-9));
    expect(progress[2] - progress[0], closeTo(0.5, 1e-9));
  });

  testWidgets('the group speed drives the shared clock', (tester) async {
    await tester.pumpWidget(_host(BeamSync(speed: 3, child: _beam())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_painters(tester).first.clock.elapsedSeconds, closeTo(0.6, 1e-9));
  });

  testWidgets('the group stops and starts every beam together', (tester) async {
    Widget build({required bool active}) => _host(
      BeamSync(
        active: active,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_beam(), _beam()],
        ),
      ),
    );

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

  testWidgets('a group that starts stopped never runs a ticker', (
    tester,
  ) async {
    await tester.pumpWidget(_host(BeamSync(active: false, child: _beam())));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(_painters(tester).first.clock.isVisible, isFalse);
  });

  testWidgets('reduced motion freezes the group on a static frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        BeamSync(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [_beam(), _beam()],
          ),
        ),
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

  testWidgets('the group resumes when the request lifts', (tester) async {
    Widget build({required bool reduced}) =>
        _host(disableAnimations: reduced, BeamSync(child: _beam()));

    await tester.pumpWidget(build(reduced: true));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(build(reduced: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, 1);
    expect(_painters(tester).first.staticMode, isFalse);
  });

  testWidgets('returning to active under reduced motion stops a fade ticker', (
    tester,
  ) async {
    Widget build(bool active) => _host(
      disableAnimations: true,
      BeamSync(active: active, child: _beam()),
    );

    await tester.pumpWidget(build(true));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(build(false));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(build(true));
    expect(tester.binding.transientCallbackCount, 0);
    expect(_painters(tester).first.clock.isRunning, isFalse);
  });

  testWidgets('the group can opt into full motion under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        BeamSync(reducedMotion: BeamReducedMotion.animate, child: _beam()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final painter = _painters(tester).first;
    expect(painter.staticMode, isFalse);
    expect(painter.clock.isRunning, isTrue);
    expect(painter.clock.elapsedSeconds, closeTo(0.2, 1e-9));
  });

  testWidgets('the group slow policy scales its shared clock', (tester) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        BeamSync(reducedMotion: BeamReducedMotion.slow, child: _beam()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final painter = _painters(tester).first;
    expect(painter.staticMode, isFalse);
    expect(painter.clock.speed, 0.25);
    expect(painter.clock.elapsedSeconds, closeTo(0.25, 1e-9));
  });

  testWidgets('disposing the group leaves no ticker behind', (tester) async {
    await tester.pumpWidget(
      _host(
        BeamSync(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [_beam(), _beam(), _beam()],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pumpWidget(_host(const SizedBox()));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing one beam leaves the rest running', (tester) async {
    Widget build(int count) => _host(
      BeamSync(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < count; i++) _beam()],
        ),
      ),
    );

    await tester.pumpWidget(build(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(build(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, 1);
    expect(_painters(tester), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a controller inside a group asserts', (tester) async {
    final controller = BorderBeamController();
    addTearDown(controller.dispose);
    // The group is stopped so it never starts a ticker: a build that throws
    // leaves a tree Flutter 3.35 cannot unmount (`InheritedElement.unmount`
    // asserts on its dependents), so a ticker started here would outlive the
    // test and count against the next one.
    await pumpExpectingAssertion(
      tester,
      _host(
        BeamSync(
          active: false,
          child: SizedBox(
            width: 120,
            height: 60,
            child: BorderBeam.rotate(
              controller: controller,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
      message: 'A BorderBeam under a BeamSync runs on the group clock',
    );
  });

  testWidgets('leaving the group hands the beam its own clock', (tester) async {
    final key = GlobalKey();
    Widget build({required bool synced}) {
      final beam = _beam(key: key);
      return _host(synced ? BeamSync(child: beam) : beam);
    }

    await tester.pumpWidget(build(synced: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final shared = _painters(tester).first.clock;
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pumpWidget(build(synced: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final own = _painters(tester).first.clock;
    expect(identical(own, shared), isFalse);
    expect(own.isVisible, isTrue);
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pumpWidget(_host(const SizedBox()));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
