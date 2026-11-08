import 'package:dio/dio.dart';

import 'api_host.dart';
import '../utils/device_info_util.dart';

/// ★ 1108 极薄全局错误上报通道：POST /api/softlib/log/report
///
/// 设计：
///  · 与 SoftService/UserService 解耦（防循环依赖），失败完全静默
///  · 节流：每小时最多 20 条（超限静默丢弃），防止异常风暴刷库
///  · 普通网络错误（超时/断网）降级为一行；同步异常（如 HTTP 头非法）带原始信息
class GlobalErrorReporter {
  GlobalErrorReporter._();

  static Dio? _dio;
  static int _count = 0;
  static int _hour = DateTime.now().hour;

  static bool get _quota {
    final h = DateTime.now().hour;
    if (h != _hour) {
      _hour = h;
      _count = 0;
    }
    return _count < 20;
  }

  /// Dio onError 统一入口
  static void reportDio(DioException e) {
    if (!_quota) return;
    _count++;
    final isPlain = e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
    final detail = isPlain
        ? '[net] ${e.type} ${e.requestOptions.uri}'
        : '[net-err] ${e.error ?? e.message ?? e.type} | ${e.requestOptions.uri}';
    _fire('net', detail);
  }

  /// 供全局 catch 块调用（登录/支付等关键路径）
  static void report(String tag, Object error) {
    if (!_quota) return;
    _count++;
    _fire(tag, error.toString());
  }

  static void _fire(String tag, String msg) {
    try {
      final d = _dio ??= Dio(BaseOptions(
        baseUrl: ApiHost.base,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (_) => true,
      ));
      d.post('/api/softlib/log/report', data: {
        'tag': tag,
        'error': msg,
        'device': DeviceInfo.model,
        'os': DeviceInfo.os,
      }).catchError((_) {});
    } catch (_) {}
  }
}
