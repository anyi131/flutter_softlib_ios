import Flutter
import UIKit
import flutter_downloader

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // ★ iOS 适配：flutter_downloader 在 App 被系统在后台唤醒时需要自行注册插件，
    //   否则后台下载任务无法恢复（安卓侧不需要这一步，行为不变）。
    FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private func registerPlugins(registry: FlutterPluginRegistry) {
  if !registry.hasPlugin("FlutterDownloaderPlugin") {
    FlutterDownloaderPlugin.register(
      with: registry.registrar(forPlugin: "FlutterDownloaderPlugin")!)
  }
}
