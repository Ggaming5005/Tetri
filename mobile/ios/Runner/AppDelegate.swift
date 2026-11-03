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
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TetriPlatform") else { return }
    let channel = FlutterMethodChannel(name: "dev.tetri/platform", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "openRepository" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: "https://github.com/Ggaming5005/Tetri") else { return }
      UIApplication.shared.open(url) { opened in
        if opened {
          result(nil)
        } else {
          result(FlutterError(code: "browser_unavailable", message: "No browser is available.", details: nil))
        }
      }
    }
  }
}
