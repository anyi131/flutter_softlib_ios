import 'dart:io';

import 'package:dio/dio.dart';

/// ★ 1016：把技术错误翻成人话
///
/// 之前界面会直接显示 `DioException [connection error]`、
/// `SocketException: Failed host lookup` 这类内容，用户完全看不懂。
///
/// 用法：`ToastUtil.error(ErrText.of(e))`
class ErrText {
  ErrText._();

  static String of(Object? e) {
    final s = '$e';
    if (s.isEmpty) return '出了点问题，请稍后重试';

    // ── 网络 ──
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (s.contains('connectionError') || s.contains('Connection refused')) {
      return '无法连接服务器，请检查网络';
    }
    if (s.contains('ReceiveTimeout') || s.contains('receiveTimeout')) {
      return '服务器响应超时，请稍后重试';
    }
    if (s.contains('ConnectTimeout') || s.contains('connectTimeout')) {
      return '连接超时，网络可能较慢';
    }
    if (s.contains('SendTimeout')) return '发送超时，请重试';

    // ── 状态码 ──
    if (s.contains('status code of 401') || s.contains('401')) {
      return '登录已失效，请重新登录';
    }
    if (s.contains('403')) return '没有权限访问';
    if (s.contains('404')) return '内容不存在或已下架';
    if (s.contains('500') || s.contains('502') || s.contains('503')) {
      return '服务器暂时不可用，请稍后重试';
    }

    // ── 解析 ──
    if (s.contains('FormatException') || s.contains('type ') && s.contains('is not a subtype')) {
      return '数据格式异常，请稍后重试';
    }

    // ── 文件 ──
    if (s.contains('FileSystemException')) return '文件读写失败，请检查存储权限';
    if (s.contains('ENOSPC') || s.contains('No space left')) return '存储空间不足';

    // ── 业务提示：去掉 Exception: 前缀后若已是中文，直接展示 ──
    var t = s.replaceFirst(RegExp(r'^(Exception|DioException|Error|FormatException):\s*'), '');
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(t)) {
      return t.length > 60 ? '${t.substring(0, 60)}…' : t;
    }

    // ── 兜底 ──
    return '操作失败，请稍后重试';
  }

  /// 直接拿 Dio / Socket 异常
  static String dio(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return '连接超时，请检查网络';
        case DioExceptionType.receiveTimeout:
          return '服务器响应超时，请稍后重试';
        case DioExceptionType.sendTimeout:
          return '发送超时，请重试';
        case DioExceptionType.connectionError:
          return '网络连接失败，请检查网络后重试';
        case DioExceptionType.cancel:
          return '请求已取消';
        default:
          return of(e);
      }
    }
    if (e is SocketException) return '网络连接失败，请检查网络后重试';
    return of(e);
  }
}
