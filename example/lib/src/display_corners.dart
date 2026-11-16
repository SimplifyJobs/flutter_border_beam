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
/// `MediaQuery` value; [DisplayCorners] puts the iOS ones there.
abstract final class DisplayCorners {
  static const MethodChannel _channel = MethodChannel(
    'prismatic_example/display',
  );

  static BorderRadius? _radii;

  /// The radii the app delegate reported, in logical pixels, or null.
  static BorderRadius? get radii => _radii;

  /// Asks the platform once, on iOS; elsewhere, or if it does not answer,
  /// leaves [radii] null.
  static Future<void> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final r = await _channel.invokeListMethod<double>('cornerRadii');
      if (r == null || r.length != 4) return;
      _radii = BorderRadius.only(
        topLeft: Radius.circular(r[0]),
        topRight: Radius.circular(r[1]),
        bottomRight: Radius.circular(r[2]),
        bottomLeft: Radius.circular(r[3]),
      );
    } on Object {
      _radii = null;
    }
  }

  /// [child] with the display's corner radii in its `MediaQuery`, unless the
  /// platform already reports them.
  static Widget apply(BuildContext context, Widget? child) {
    final content = child ?? const SizedBox.shrink();
    final r = _radii;
    final data = MediaQuery.of(context);
    if (r == null || data.displayCornerRadii != null) return content;
    return MediaQuery(data: data.applyDisplayCornerRadii(r), child: content);
  }
}
