import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../design/ui.dart';
import '../utils/err_text.dart';
import '../utils/toast_util.dart';

/// 统一的操作反馈
///
/// ★ 1020（用户反馈「点击后没有加载动画，其他地方也是」）：
///   原来每个页面各自处理 loading，大部分异步操作**点完毫无反应**，
///   用户以为没按上，就反复点 → 重复提交 / 状态错乱。
///
///   这里提供三个语义化方法，全 App 统一使用：
///     · run()       —— 执行异步操作：自动显示 loading、成功提示、失败提示
///     · runQuiet()  —— 同上但不弹成功提示（适合刷新类）
///     · guard()     —— 只做防重复点击（快操作，不弹 loading）
class AppAction {
  AppAction._();

  static int _running = 0;

  /// 是否有操作在进行中
  static bool get isBusy => _running > 0;

  /// 执行一个异步操作（带加载动画 + 成功/失败提示）
  ///
  /// [loading] 加载文案，null 表示不显示加载层（极快的操作）
  /// [success] 成功提示，null 表示不提示
  static Future<T?> run<T>(
    Future<T> Function() action, {
    String? loading = '处理中…',
    String? success,
    String? failPrefix,
    VoidCallback? onError,
  }) async {
    if (_running > 0) return null; // 防重复
    _running++;
    if (loading != null) {
      EasyLoading.show(status: loading, maskType: EasyLoadingMaskType.clear);
    }
    try {
      final r = await action();
      if (loading != null) EasyLoading.dismiss();
      if (success != null) ToastUtil.success(success);
      return r;
    } catch (e) {
      if (loading != null) EasyLoading.dismiss();
      ToastUtil.error(
        failPrefix != null ? '$failPrefix：${ErrText.of(e)}' : ErrText.of(e),
      );
      onError?.call();
      return null;
    } finally {
      _running--;
    }
  }

  /// 执行但不弹成功提示（刷新、轮询类）
  static Future<T?> runQuiet<T>(
    Future<T> Function() action, {
    String? loading,
  }) => run<T>(action, loading: loading, success: null);

  /// 防重复点击的守卫
  ///
  /// 用于快速操作（切换开关、收藏）—— 不弹 loading，但避免连点。
  static Future<void> guard(Future<void> Function() action) async {
    if (_running > 0) return;
    _running++;
    try {
      await action();
    } finally {
      _running--;
    }
  }

  /// 包一次「提交/删除」类操作：自动 loading + 异常兜底 + 一定关闭 loading
  ///
  /// ★ 1020：后台大量删除/保存按钮原来是「点了没反应」或「异常后 loading 卡死」。
  ///   这个封装保证：
  ///     · 点击立刻有 loading
  ///     · 无论成功/失败/异常，loading 一定被关掉
  ///     · 失败自动 Toast 人话错误
  static Future<bool> act(
    Future<void> Function() action, {
    String loading = '处理中…',
    String? success,
  }) async {
    showLoading(loading);
    try {
      await action();
      if (success != null) ToastUtil.success(success);
      return true;
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
      return false;
    } finally {
      hideLoading();
    }
  }

  /// 手动控制（复杂场景）
  static void showLoading([String text = '处理中…']) {
    EasyLoading.show(status: text, maskType: EasyLoadingMaskType.clear);
  }

  static void hideLoading() {
    if (EasyLoading.isShow) EasyLoading.dismiss();
  }

  /// 通用错误弹窗（比 Toast 更醒目，用于关键失败）
  static void showError(String title, Object error, {String? hint}) {
    final ctx = Get.context;
    if (ctx == null) {
      ToastUtil.error(ErrText.of(error));
      return;
    }
    showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: C.danger, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ErrText.of(error),
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
            if (hint != null && hint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                style: TextStyle(fontSize: 11.5, height: 1.5, color: c.t3),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
