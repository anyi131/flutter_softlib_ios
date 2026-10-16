import 'dart:io';

import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════
/// QQ 原生登录（1015 自实现桥接）
///
/// 为什么不用第三方插件：
///   tencent_kit 等插件把 AGP 版本写死在 Gradle 里（7.3.0 + compileSdk 31），
///   与本项目 AGP 8.9 / compileSdk 36 不兼容 → 反复构建失败。
///   现在改为「自己写原生桥接 + 腾讯官方 SDK jar」，完全可控。
///
/// 原生侧：android/.../QQLoginBridge.java（MethodChannel）
///        channel = com.soft.anyi/qq
/// iOS 侧：暂未实现（iOS 走 WebView 兜底）
/// ═══════════════════════════════════════════════════════════════
class QQLogin {
  QQLogin._();

  static const _ch = MethodChannel('com.soft.anyi/qq');

  /// AppID（由服务端下发后注入）
  static String appId = '';

  /// ★ 1016：QQ 还没绑定账号时，先暂存凭据 ——
  ///   引导用户去注册，注册请求里带上它，注册成功即完成绑定。
  static String pendingOpenid = '';
  static String pendingAccessToken = '';

  static bool get hasPendingBind =>
      pendingOpenid.isNotEmpty && pendingAccessToken.isNotEmpty;

  static void clearPendingBind() {
    pendingOpenid = '';
    pendingAccessToken = '';
  }

  /// 检查是否安装了 QQ
  static Future<bool> isQQInstalled() async {
    if (!Platform.isAndroid) return false;
    try {
      final r = await _ch.invokeMethod<bool>('isQQInstalled');
      return r ?? false;
    } catch (_) {
      return false;
    }
  }

  /// ★ 1016：预热（进登录页时调用）—— 原生侧先建好 Tencent 实例，
  ///   点登录时省掉初始化耗时，体感更快。失败静默。
  static Future<void> preheat() async {
    if (!Platform.isAndroid || appId.isEmpty) return;
    try {
      await _ch.invokeMethod<bool>('preheat', {'appId': appId});
    } catch (_) {}
  }

  /// 发起 QQ 登录
  /// - 返回 QQAuthResult：成功
  /// - 返回 null：用户取消
  /// - 抛异常：失败（未安装 / 无 AppID / QQ 报错）
  static Future<QQAuthResult?> login() async {
    if (!Platform.isAndroid) {
      throw Exception('iOS 暂不支持原生 QQ 登录');
    }
    if (appId.isEmpty) {
      throw Exception('QQ AppID 未配置（后台缺少 AppID）');
    }
    try {
      final r = await _ch.invokeMethod<Map>('login', {'appId': appId});
      if (r == null) return null; // 用户取消
      final openid = '${r['openid'] ?? ''}';
      final token = '${r['access_token'] ?? ''}';
      if (openid.isEmpty || token.isEmpty) return null;
      return QQAuthResult(
        openid: openid,
        accessToken: token,
        uiMs: int.tryParse('${r['uiMs'] ?? -1}') ?? -1,
        initMs: int.tryParse('${r['initMs'] ?? -1}') ?? -1,
      );
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'QQ 登录失败（${e.code}）');
    } on MissingPluginException {
      throw Exception('当前安装包未集成 QQ 登录（请更新到最新版）');
    }
  }

  /// 退出（清 QQ SDK 本地态）
  static Future<void> logout() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('logout');
    } catch (_) {}
  }
}

class QQAuthResult {
  final String openid;
  final String accessToken;

  /// ★ 1016 真机计时：原生侧测得的耗时（毫秒，-1 表示未知）
  ///   uiMs   = 「拉起 QQ → 用户点同意 → 回调」全程（含 QQ 冷启动）
  ///   initMs = 原生初始化（建 Tencent 实例 + 权限声明）
  final int uiMs;
  final int initMs;

  const QQAuthResult({
    required this.openid,
    required this.accessToken,
    this.uiMs = -1,
    this.initMs = -1,
  });
}
