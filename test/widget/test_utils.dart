import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
