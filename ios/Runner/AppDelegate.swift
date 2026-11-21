import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let timezoneChannel = FlutterMethodChannel(
        name: "com.example.reciept_logging/device_timezone",
        binaryMessenger: controller.binaryMessenger
      )
      timezoneChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "getDeviceTimezone" {
          result(TimeZone.current.identifier)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let timezoneChannel = FlutterMethodChannel(
      name: "com.example.reciept_logging/device_timezone",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "DeviceTimezone").messenger()
    )
    timezoneChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getDeviceTimezone" {
        result(TimeZone.current.identifier)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
