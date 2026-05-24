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
    registerAppDirectoriesChannel(engineBridge.applicationRegistrar.messenger())
  }

  private func registerAppDirectoriesChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "unittrace/app_directories",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "documentsDirectory":
        guard let url = FileManager.default.urls(
          for: .documentDirectory,
          in: .userDomainMask
        ).first else {
          result(FlutterError(
            code: "documents_unavailable",
            message: "Documents directory is unavailable.",
            details: nil
          ))
          return
        }
        result(url.path)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
