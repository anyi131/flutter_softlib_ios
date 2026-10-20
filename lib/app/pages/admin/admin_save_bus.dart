import 'package:flutter/foundation.dart';

/// 后台「悬浮保存按钮」总线
///
/// 为什么需要：
///   后台很多页面表单很长，保存按钮在最底部，改完一个字段要一直往下滑。
///   这里让当前可见的子页把自己的保存方法登记进来，
///   由 admin_shell 统一渲染一个右下角悬浮保存按钮。
class AdminSaveBus {
  AdminSaveBus._();

  /// 当前页面的保存方法（null 表示当前页没有保存动作）
  static Future<void> Function()? handler;

  /// 当前页面是否正在保存（用于按钮转圈）
  static final ValueNotifier<bool> saving = ValueNotifier<bool>(false);

  /// 登记 / 注销
  static void register(Future<void> Function() fn) {
    handler = fn;
    saving.value = false;
  }

  static void clear() {
    handler = null;
    saving.value = false;
  }

  static Future<void> run() async {
    final fn = handler;
    if (fn == null || saving.value) return;
    saving.value = true;
    try {
      await fn();
    } finally {
      saving.value = false;
    }
  }
}
