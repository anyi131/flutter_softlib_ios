import Flutter
import UIKit
import flutter_downloader
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// ★ 1016：与安卓侧同名的通道（softlib/installer），Dart 侧无需区分平台
  private let channelName = "softlib/installer"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // ★ iOS 适配：flutter_downloader 在 App 被系统在后台唤醒时需要自行注册插件，
    //   否则后台下载任务无法恢复（安卓侧不需要这一步，行为不变）。
    FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)

    // ★ 1016：通知栏（动态/回复/点赞/订单）
    //   服务端写消息 → Dart 侧轮询发现新消息 → 调这里弹系统通知
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "initNotify":
          // 申请通知权限（首次会弹系统授权框）
          UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
          ) { _, _ in }
          result(true)
        case "showNotify":
          let args = call.arguments as? [String: Any] ?? [:]
          let id = (args["id"] as? Int) ?? 0
          let title = (args["title"] as? String) ?? ""
          let body = (args["body"] as? String) ?? ""
          self?.post(id: id, title: title, body: body)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 发一条本地通知（trigger = nil 表示立即送达）
  private func post(id: Int, title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "softlib-\(id)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }

  /// App 在前台时也把通知横幅显示出来（否则前台收消息时看不到任何提示）
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }
}

private func registerPlugins(registry: FlutterPluginRegistry) {
  if !registry.hasPlugin("FlutterDownloaderPlugin") {
    FlutterDownloaderPlugin.register(
      with: registry.registrar(forPlugin: "FlutterDownloaderPlugin")!)
  }
}
