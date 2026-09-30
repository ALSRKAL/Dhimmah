import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications' iOS setup: the plugin hears about reminders
    // through the app delegate, which is how one that arrives while the app is
    // open is presented and how a tap on it reaches the app.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The user's backup folder, behind the same channel name Android uses.
    // Created here, not in application(_:didFinishLaunchingWithOptions:): with
    // the scene lifecycle the engine is created later than that, and Flutter's
    // UIScene migration guide moves method channels to this callback.
    BackupFolderChannel.register(with: engineBridge.applicationRegistrar.messenger())
  }
}
