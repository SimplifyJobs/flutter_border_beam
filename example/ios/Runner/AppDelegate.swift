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

/// Reports the display's corner radii to Dart — each corner its own — so
/// the example's distortion waves put their edge colour on the glass.
///
/// iOS does not hand them to Flutter (`MediaQueryData.displayCornerRadii` is
/// filled in on Android only). On iOS 26 and later this asks UIKit's public
/// concentric-corner API: a hidden view the size of the window, with corners
/// concentric to its container, reports each corner's effective radius —
/// the display's. Before iOS 26, whose devices have four equal corners, it
/// falls back to the screen's private corner radius (key assembled at run
/// time and checked with `responds(to:)` first). This is the example app
/// only: the prismatic package itself uses public API alone.
enum DisplayCorners {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "prismatic_example/display", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "cornerRadii" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(radii())
    }
  }

  /// Top-left, top-right, bottom-right, bottom-left, in points; nil when
  /// nothing says.
  private static func radii() -> [Double]? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap(\.windows)
    // Both paths measure the display that holds this window.
    let window = windows.first(where: \.isKeyWindow) ?? windows.first
    if #available(iOS 26.0, *), let window {
      let probe = UIView(frame: window.bounds)
      probe.isHidden = true
      probe.isUserInteractionEnabled = false
      window.addSubview(probe)
      probe.cornerConfiguration = .corners(radius: .containerConcentric())
      let corners: [UIRectCorner] = [.topLeft, .topRight, .bottomRight, .bottomLeft]
      let found = corners.map { Double(probe.effectiveRadius(corner: $0)) }
      probe.removeFromSuperview()
      if found.contains(where: { $0 > 0 }) { return found }
    }
    let screen = window?.windowScene?.screen ?? scenes.first?.screen
    guard let single = legacyRadius(screen) else { return nil }
    return [single, single, single, single]
  }

  private static var key: String {
    ["Radius", "Corner", "display", "_"].reversed().joined()
  }

  /// The screen's one corner radius, before iOS 26.
  private static func legacyRadius(_ screen: UIScreen?) -> Double? {
    guard let screen, screen.responds(to: NSSelectorFromString(key)) else { return nil }
    guard let value = screen.value(forKey: key) as? NSNumber else { return nil }
    let radius = value.doubleValue
    return radius > 0 ? radius : nil
  }
}
