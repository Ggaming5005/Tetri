import CommonCrypto
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let pinQueue = DispatchQueue(label: "dev.tetri.pin", qos: .userInitiated)
  private let pinPermit = DispatchSemaphore(value: 1)

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

    let pinChannel = FlutterMethodChannel(name: "dev.tetri/pin", binaryMessenger: registrar.messenger())
    pinChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "defaultAlgorithm":
        result("pbkdf2-sha256")
      case "derive":
        guard let self = self else {
          result(FlutterError(code: "pin_unavailable", message: "PIN verification is unavailable.", details: nil))
          return
        }
        self.derivePin(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func derivePin(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let values = arguments as? [String: Any], values.count == 3,
      let pin = values["pin"] as? String,
      pin.utf8.count == 4, pin.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
      let suppliedSalt = values["salt"] as? FlutterStandardTypedData,
      suppliedSalt.data.count == 16,
      let algorithm = values["algorithm"] as? String,
      algorithm == "pbkdf2-sha256" || algorithm == "pbkdf2-sha1"
    else {
      result(FlutterError(code: "pin_invalid_input", message: "PIN verification is unavailable.", details: nil))
      return
    }
    // Keep the stored algorithm explicit; old records never silently downgrade.
    let prf = CCPseudoRandomAlgorithm(
      algorithm == "pbkdf2-sha256" ? kCCPRFHmacAlgSHA256 : kCCPRFHmacAlgSHA1
    )
    let iterations: UInt32 = algorithm == "pbkdf2-sha256" ? 600_000 : 1_400_000
    guard pinPermit.wait(timeout: .now()) == .success else {
      result(FlutterError(code: "pin_busy", message: "PIN verification is already running.", details: nil))
      return
    }
    let salt = suppliedSalt.data
    pinQueue.async {
      var password = Array(pin.utf8)
      var derived = [UInt8](repeating: 0, count: 32)
      let status = password.withUnsafeBytes { passwordBytes in
        salt.withUnsafeBytes { saltBytes in
          derived.withUnsafeMutableBytes { outputBytes in
            CCKeyDerivationPBKDF(
              CCPBKDFAlgorithm(kCCPBKDF2),
              passwordBytes.baseAddress!.assumingMemoryBound(to: CChar.self), 4,
              saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), 16,
              prf, iterations,
              outputBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), 32
            )
          }
        }
      }
      for index in password.indices { password[index] = 0 }
      self.pinPermit.signal()
      let response = status == kCCSuccess ? Data(derived) : nil
      for index in derived.indices { derived[index] = 0 }
      DispatchQueue.main.async {
        if let response = response {
          result(FlutterStandardTypedData(bytes: response))
        } else {
          result(FlutterError(code: "pin_unavailable", message: "PIN verification is unavailable.", details: nil))
        }
      }
    }
  }
}
