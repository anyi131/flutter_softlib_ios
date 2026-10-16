import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../api/user_service.dart';
import '../routes/app_pages.dart';
import 'notify_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// FCM 真推送（1016 新增）—— 安卓 + iOS
///
/// 为什么需要：
///   App 退到后台/被锁屏后系统会挂起进程，靠 App 自己轮询**收不到**通知。
///   真正的「后台/锁屏也能收到」只能走系统推送通道。
///
/// 分工：
///   · App 在后台/被杀 → 消息由**系统**直接弹出（payload 里带 notification）
///   · App 在前台 → 系统不弹，我们用自己的通知渠道弹（下面的 onMessage）
///   · 点通知进来 → 直接跳到「消息」页
///   · 登录后把设备 token 上报服务端（服务端用 FCM 官方接口发）
///
/// 没配好（缺 google-services.json / GoogleService-Info.plist）时全部安全跳过，
/// 不影响其它功能。
/// ═══════════════════════════════════════════════════════════════

/// 后台消息处理（必须是顶层函数 + vm:entry-point）
/// 注：带 notification 的推送系统会自己弹，这里只兜底「纯 data」推送。
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage m) async {
  try {
    if (m.notification != null) return;
    final t = '${m.data['title'] ?? '新消息'}';
    final b = '${m.data['body'] ?? ''}';
    await NotifyService.instance.showNow(t, b);
  } catch (_) {}
}

class FcmService {
  FcmService._();
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    _inited = true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[fcm] initializeApp 跳过（未配置）: $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

      final m = FirebaseMessaging.instance;
      // 申请通知权限（iOS 会弹系统框；安卓 13+ 由 permission_handler 那步已处理）
      await m.requestPermission(alert: true, badge: true, sound: true);

      // 前台收到 → 用自己的渠道弹出来（FCM 在前台默认不显示）
      FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n != null) {
          NotifyService.instance.showNow(n.title ?? '新消息', n.body ?? '');
        }
      });

      // 点通知进入 App → 直接打开消息页
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        try {
          Get.toNamed(Routes.message);
        } catch (_) {}
      });

      // 冷启动时如果是点通知进来的
      final initial = await m.getInitialMessage();
      if (initial != null) {
        try {
          Get.toNamed(Routes.message);
        } catch (_) {}
      }

      await _report();
      m.onTokenRefresh.listen((_) => _report());
    } catch (e) {
      debugPrint('[fcm] 初始化失败: $e');
    }
  }

  /// 把设备 token 上报服务端（服务端据此发推送）
  static Future<void> _report() async {
    try {
      final m = FirebaseMessaging.instance;
      final tok = await m.getToken();
      if (tok == null || tok.isEmpty) return;
      await UserService.instance.reportFcmToken(
        tok,
        Platform.isIOS ? 'ios' : 'android',
      );
      debugPrint('[fcm] token 已上报');
    } catch (_) {}
  }

  /// 登录后调用：补报一次（登录前上报会被服务端拒绝）
  static Future<void> reportNow() => _report();
}
