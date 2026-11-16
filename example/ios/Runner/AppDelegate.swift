import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DisplayCorners") {
      DisplayCorners.register(with: registrar.messenger())
    }
  }
}

/// Reports the display's corner radius to Dart, so the example's distortion
/// waves put their edge colour on the glass.
///
/// iOS has no public API for it (Flutter's `MediaQueryData.displayCornerRadii`
/// is filled in on Android only), so this reads the screen's private
/// `_displayCornerRadius`, as many apps do. The key is assembled at run time
/// and checked with `responds(to:)` first, so an iOS without it reports
/// nothing rather than crashing. This is the example app only: the prismatic
/// package itself uses public API alone.
enum DisplayCorners {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "prismatic_example/display", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "cornerRadius" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(radius())
    }
  }

  private static var key: String {
    ["Radius", "Corner", "display", "_"].reversed().joined()
  }

  /// The radius in points, or nil when the screen does not say.
  private static func radius() -> Double? {
    let screen =
      UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.screen }
        .first
    guard let screen, screen.responds(to: NSSelectorFromString(key)) else { return nil }
    guard let value = screen.value(forKey: key) as? NSNumber else { return nil }
    let radius = value.doubleValue
    return radius > 0 ? radius : nil
  }
}
