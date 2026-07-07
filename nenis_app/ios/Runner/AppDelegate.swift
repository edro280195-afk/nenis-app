import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let googleMapsChannel = "nenis_app/google_maps"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let apiKey = Self.googleMapsApiKey {
      GMSServices.provideAPIKey(apiKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    FlutterMethodChannel(
      name: googleMapsChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "hasApiKey":
        result(Self.googleMapsApiKey != nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static var googleMapsApiKey: String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
      trimmed != "YOUR_API_KEY",
      !trimmed.contains("GOOGLE_MAPS_API_KEY")
    else {
      return nil
    }
    return trimmed
  }
}
