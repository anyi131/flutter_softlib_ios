import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// ★ 1016：安全获取 BuildContext
///
/// 背景：项目里有 27 处 `Get.context!`，一旦页面已销毁 / App 启动期
/// context 为 null，直接 `!` 就会抛
/// 「Null check operator used on a null value」导致首页白屏/崩溃。
class SafeCtx {
  SafeCtx._();

  /// 当前可用 context（优先 Get，其次 navigatorKey）
  static BuildContext? of() {
    final c = Get.context;
    if (c != null) return c;
    return Get.key.currentContext;
  }

  /// 安全 pop
  static void pop<T>([T? result]) {
    final c = of();
    if (c == null) return;
    try {
      Navigator.of(c).maybePop(result);
    } catch (_) {}
  }

  /// 安全弹窗
  static Future<T?> showDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    final c = of();
    if (c == null) return null;
    try {
      return await showGeneralDialog<T>(
        context: c,
        barrierDismissible: barrierDismissible,
        barrierLabel: '',
        pageBuilder: (ctx, _, __) => builder(ctx),
        transitionDuration: const Duration(milliseconds: 180),
        transitionBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      );
    } catch (_) {
      return null;
    }
  }

  /// 安全 SnackBar
  static void snack(String msg) {
    final c = of();
    if (c == null) return;
    try {
      ScaffoldMessenger.of(c).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {}
  }
}
