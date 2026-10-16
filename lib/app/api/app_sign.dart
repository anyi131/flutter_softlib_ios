import 'dart:io';

import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：App 自身签名指纹（防重打包）
///
/// 原理：APK 的签名证书 MD5 是唯一的。重打包必须换签名 → MD5 就变了。
///   这里把当前安装包的签名 MD5 随每个请求带给服务端（X-App-Sign），
///   服务端拿它跟「官方登记的签名」比对：
///     观察模式：只记审计日志（默认，先看有没有误判）
///     拦截模式：不一致直接拒绝
///
/// ⚠ 诚实说明：这能挡住「用现成打包工具重打包、没改网络层」的绝大多数情况；
///   有心的破解者仍可伪造请求头。要更硬需要代码加固 / 完整性校验。
/// ═══════════════════════════════════════════════════════════════
class AppSign {
  AppSign._();

  static const _ch = MethodChannel('softlib/installer');

  static String? _cache;

  /// 读本机签名 MD5（失败返回空串；iOS 不支持 → 空串）
  static Future<String> value() async {
    if (_cache != null) return _cache!;
    if (!Platform.isAndroid) return _cache = '';
    try {
      final v = await _ch.invokeMethod<String>('getSignature');
      return _cache = (v ?? '').toLowerCase();
    } catch (_) {
      return _cache = '';
    }
  }

  /// ★ 1016：**同步**读取已缓存的签名（没预热好就返回 null）。
  ///   请求拦截器只能用这个 —— 绝不能 await 通道调用，
  ///   否则一旦原生没响应，整个 App 的网络请求都会卡住。
  static String? get cached => _cache;

  /// 启动时预热一次，别让首个业务请求等它
  static Future<void> warmUp() async {
    await value();
  }

  /// 请求头（拿不到签名就不带，服务端会记为 no_sign）
  static Future<Map<String, String>> headers() async {
    final s = await value();
    if (s.isEmpty) return const {};
    return {
      'X-App-Sign': s,
      'X-App-Ts': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    };
  }
}
