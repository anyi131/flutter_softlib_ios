import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ★ 1101 开源批二：系统通知栏
/// 下载完成等关键节点现在只进 App 内消息中心，后台看不到；本类补系统级通知。
/// 纯新增：不碰 App 内消息链路，所有调用点均可选调用。
class SysNotify {
  SysNotify._();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _id = 1000;

  /// main() 首帧后调用一次；任何失败静默（通知不是关键路径）。
  static Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false, // iOS 权限在首次发通知时请求
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e) {
      debugPrint('[Softlib] sysnotify init: $e');
    }
  }

  /// 发一条普通通知（标题+正文）。
  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      const android = AndroidNotificationDetails(
        'softlib_general', // channel id
        '软件库通知', // channel name
        channelDescription: '下载完成、签到提醒等通知',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const ios = DarwinNotificationDetails();
      await _plugin.show(
        id: _id++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: android, iOS: ios),
      );
    } catch (e) {
      debugPrint('[Softlib] sysnotify show: $e');
    }
  }
}
