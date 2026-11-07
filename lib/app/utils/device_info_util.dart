import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_marketing_names/device_marketing_names.dart';
import 'package:flutter/foundation.dart';

/// 设备信息（用于后台操作日志的「手机型号 / 系统版本」）
///
/// ★ 需求 #10：管理后台要能看到用户的操作日志 + IP + 手机型号 + 系统版本。
///   App 端把型号/系统版本放进请求头，后端 oplog 直接读取，无需额外接口。
///
/// 用法：App 启动时调一次 `DeviceInfo.init()`，
///       各 Dio 客户端通过 `DeviceInfo.headers` 带上下面的请求头。
class DeviceInfo {
  DeviceInfo._();

  static String model = '';
  /// 原始机型代号（如 V1986A），排查问题用；展示优先用 model
  static String code = '';
  static String os = '';
  /// 应用版本号（如 3.10.28+132）。启动时由 main.dart 填，下载/崩溃上报都靠它，
  /// 否则后台只看到「应用版本 -」。
  static String appVersion = '';
  static bool _inited = false;

  /// 启动时调用一次（失败也不抛异常）
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final p = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await p.androidInfo;
        code = a.model;
        // ★ 1106h：部分机型（如 vivo V1986A）Build.BRAND 为空 → 用 manufacturer 兜底
        final brand = (a.brand.trim().isEmpty ? a.manufacturer : a.brand).trim();
        model = '$brand ${a.model}'.trim();
        os = 'Android ${a.version.release} (API ${a.version.sdkInt})';
      } else if (Platform.isIOS) {
        final i = await p.iosInfo;
        code = i.utsname.machine;
        model = i.utsname.machine;
        os = 'iOS ${i.systemVersion}';
      }
      // ★ 1101 开源批二：注入机型市场名（'Xiaomi M2012K11AC'→'Xiaomi Redmi K40'）。
      //   失败静默回退原 model，不阻塞启动。
      try {
        final names = DeviceMarketingNames();
        final pretty = await names.getSingleName().timeout(
          const Duration(seconds: 3),
          onTimeout: () => '',
        );
        if (pretty.isNotEmpty) {
          // 保留品牌前缀（Android 的 model 无品牌；iOS machine 亦无），
          // getSingleName() 返回「品牌 机型」，直接用。
          model = pretty;
        }
      } catch (e) {
        debugPrint('[Softlib] device marketing: $e');
      }
    } catch (e) {
      debugPrint('[Softlib] device info: $e');
    }
    if (model.isEmpty) model = '未知设备';
    if (os.isEmpty)
      os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : '未知系统');
  }

  /// 后台展示用：优先市场名，括号里带原始代号
  static String get display {
    if (model.isEmpty) return code.isEmpty ? '未知设备' : code;
    if (code.isEmpty || code == model) return model;
    return '$model ($code)';
  }

  /// 供 Dio 使用的请求头
  static Map<String, String> get headers => {
    if (model.isNotEmpty) 'X-Device-Model': model,
    if (os.isNotEmpty) 'X-Os-Version': os,
  };
}
