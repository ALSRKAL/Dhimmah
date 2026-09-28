import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The user's backup folder, behind the same channel name Android uses.
    // Registered through the app's own plugin registry, which is how a
    // non-plugin channel is wired on iOS.
    let registrar = self.registrar(forPlugin: "BackupFolderChannelPlugin")
    BackupFolderChannel.register(with: registrar)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
