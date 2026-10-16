import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tencent_kit/tencent_kit.dart';

/// ═══════════════════════════════════════════════════════════════
/// QQ 原生登录（1015 新增，替代 WebView 方式）
///
/// 为什么必须用原生 SDK：
///   WebView 里的 QQ 授权页检测不到 QQ App → 提示「请安装 QQ 手机版」
///   → 卡在「正在拉起QQ手机版…」→ 根本登录不了。
///   只有原生 SDK 才能直接调起 QQ App 一键授权。
///
/// 使用前需要在平台侧配置：
///   · Android：AndroidManifest 里注册 tencent{APPID} 的 scheme
///   · iOS：Info.plist 里注册 LSApplicationQueriesSchemes + URL Scheme
/// ═══════════════════════════════════════════════════════════════
class QQLogin {
  QQLogin._();

  /// AppID 由服务端下发后注入（避免硬编码）
  static String appId = '';

  /// 检查是否安装了 QQ
  static Future<bool> isQQInstalled() async {
    try {
      return await TencentKitPlatform.instance.isQQInstalled();
    } catch (_) {
      return false;
    }
  }

  /// 发起 QQ 登录，返回 access_token 与 openid
  /// 返回 null 表示用户取消或失败
  static Future<QQAuthResult?> login() async {
    if (appId.isEmpty) {
      throw Exception('QQ AppID 未配置');
    }
    try {
      final resp = await TencentKitPlatform.instance.login(
        scope: 'get_user_info',
        appId: appId,
      );
      if (resp == null) return null;
      final openid = resp.openid ?? '';
      final token = resp.accessToken ?? '';
      if (openid.isEmpty || token.isEmpty) return null;
      return QQAuthResult(openid: openid, accessToken: token);
    } on PlatformException catch (e) {
      // 用户取消 / 未安装 QQ
      throw Exception(e.message ?? 'QQ 登录失败');
    }
  }

  /// 退出登录（清除 QQ SDK 的本地登录态）
  static Future<void> logout() async {
    try {
      await TencentKitPlatform.instance.logout();
    } catch (_) {}
  }

  /// 是否 iOS
  static bool get isIOS => Platform.isIOS;
}

class QQAuthResult {
  final String openid;
  final String accessToken;
  const QQAuthResult({required this.openid, required this.accessToken});
}
