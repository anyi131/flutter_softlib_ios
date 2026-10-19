import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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
  static String os = '';
  static bool _inited = false;

  /// 启动时调用一次（失败也不抛异常）
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final p = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await p.androidInfo;
        model = '${a.brand} ${a.model}'.trim();
        os = 'Android ${a.version.release} (API ${a.version.sdkInt})';
      } else if (Platform.isIOS) {
        final i = await p.iosInfo;
        model = i.utsname.machine;
        os = 'iOS ${i.systemVersion}';
      }
    } catch (e) {
      debugPrint('[Softlib] device info: $e');
    }
    if (model.isEmpty) model = '未知设备';
    if (os.isEmpty)
      os = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : '未知系统');
  }

  /// 供 Dio 使用的请求头
  static Map<String, String> get headers => {
    if (model.isNotEmpty) 'X-Device-Model': model,
    if (os.isNotEmpty) 'X-Os-Version': os,
  };
}
