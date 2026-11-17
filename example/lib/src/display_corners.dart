import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The display's corner radii — each corner its own — where the platform
/// does not report them to Flutter itself, so a distortion wave that fills
/// the screen puts its edge colour on the glass.
///
/// Android's engine fills in `MediaQueryData.displayCornerRadii`; iOS does
/// not, so on iOS the example asks its own app delegate
/// (`ios/Runner/AppDelegate.swift`), which measures them with UIKit's
/// concentric-corner API. The prismatic package only reads the public
/// `MediaQuery` value; [DisplayCornersScope] puts the iOS ones there, and
/// measures them again whenever the window's size or orientation changes —
/// a rotated phone whose corners differ has them in other places.
abstract final class DisplayCorners {
  static const MethodChannel _channel = MethodChannel(
    'prismatic_example/display',
  );

  static BorderRadius? _radii;

  /// The radii last measured, in logical pixels, or null.
  static BorderRadius? get radii => _radii;

  /// Measures the radii now, on iOS, and keeps them as [radii]; elsewhere,
  /// or if the platform does not answer, null, and [radii] is left as it
  /// was.
  static Future<BorderRadius?> measure() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      final r = await _channel.invokeListMethod<double>('cornerRadii');
      if (r == null || r.length != 4) return null;
      final radii = BorderRadius.only(
        topLeft: Radius.circular(r[0]),
        topRight: Radius.circular(r[1]),
        bottomRight: Radius.circular(r[2]),
        bottomLeft: Radius.circular(r[3]),
      );
      if (!kReleaseMode) debugPrint('DisplayCorners: measured $radii');
      return _radii = radii;
    } on Object catch (error) {
      if (!kReleaseMode) debugPrint('DisplayCorners: failed ($error)');
      return null;
    }
  }

  /// Measures the radii once, before the first frame.
  static Future<void> load() => measure();
}

/// Puts the display's corner radii in the `MediaQuery` below it (unless the
/// platform already reports them), and measures them again when the window
/// changes size or orientation.
class DisplayCornersScope extends StatefulWidget {
  /// Provides the radii to [child].
  const DisplayCornersScope({super.key, required this.child});

  /// The app.
  final Widget child;

  @override
  State<DisplayCornersScope> createState() => _DisplayCornersScopeState();
}

class _DisplayCornersScopeState extends State<DisplayCornersScope>
    with WidgetsBindingObserver {
  BorderRadius? _radii = DisplayCorners.radii;
  Size? _measuredFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The window changed: once the frame for its new size is laid out, the
  // platform's window has its new bounds, so measure then.
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _remeasure());
  }

  Future<void> _remeasure() async {
    if (!mounted) return;
    final size = MediaQuery.maybeSizeOf(context);
    if (size == _measuredFor) return;
    _measuredFor = size;
    final radii = await DisplayCorners.measure();
    if (!mounted || radii == null || radii == _radii) return;
    setState(() => _radii = radii);
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    _measuredFor ??= data.size;
    final r = _radii;
    if (r == null || data.displayCornerRadii != null) return widget.child;
    return MediaQuery(
      data: data.applyDisplayCornerRadii(r),
      child: widget.child,
    );
  }
}
