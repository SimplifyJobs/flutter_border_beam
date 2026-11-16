import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The display's corner radius where the platform does not report it to
/// Flutter itself, so a distortion wave that fills the screen puts its edge
/// colour on the glass.
///
/// Android's engine fills in `MediaQueryData.displayCornerRadii`; iOS does
/// not, so on iOS the example asks its own app delegate
/// (`ios/Runner/AppDelegate.swift`), which reads the screen's private corner
/// radius. The prismatic package only reads the public `MediaQuery` value;
/// [DisplayCorners] puts the iOS one there.
abstract final class DisplayCorners {
  static const MethodChannel _channel = MethodChannel(
    'prismatic_example/display',
  );

  static double? _radius;

  /// The radius the app delegate reported, in logical pixels, or null.
  static double? get radius => _radius;

  /// Asks the platform once, on iOS; elsewhere, or if it does not answer,
  /// leaves [radius] null.
  static Future<void> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      _radius = await _channel.invokeMethod<double>('cornerRadius');
    } on Object {
      _radius = null;
    }
  }

  /// [child] with the display's corner radii in its `MediaQuery`, unless the
  /// platform already reports them.
  static Widget apply(BuildContext context, Widget? child) {
    final content = child ?? const SizedBox.shrink();
    final r = _radius;
    final data = MediaQuery.of(context);
    if (r == null || data.displayCornerRadii != null) return content;
    return MediaQuery(
      data: data.applyDisplayCornerRadii(BorderRadius.circular(r)),
      child: content,
    );
  }
}
