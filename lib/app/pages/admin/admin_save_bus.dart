import 'package:flutter/foundation.dart';

/// 后台「悬浮保存按钮」总线
///
/// 为什么需要：
///   后台很多页面表单很长，保存按钮在最底部，改完一个字段要一直往下滑。
///   这里让当前可见的子页把自己的保存方法登记进来，
///   由 admin_shell 统一渲染一个右下角悬浮保存按钮。
///
/// ★★ 1020 重做（用户反馈「悬浮保存逻辑有很大问题」）：
///   旧实现只有一个全局 handler 字段，谁最后注册谁覆盖 →
///   后台多个 Tab 同时存活时，切回来点保存**执行的是别的页面的保存方法**，
///   甚至该页已经销毁、点保存直接无效或报错。
///   现在改为「带 owner 的注册表 + 只认当前可见页」。
class AdminSaveBus {
  AdminSaveBus._();

  /// owner → 保存方法
  static final Map<Object, Future<void> Function()> _handlers = {};

  /// 当前显示哪一个 owner（由外壳设置：当前 Tab 对应的页面）
  static Object? activeOwner;

  /// 按钮是否显示（供外壳监听）
  static final ValueNotifier<bool> visible = ValueNotifier<bool>(false);

  /// 是否正在保存（用于按钮转圈）
  static final ValueNotifier<bool> saving = ValueNotifier<bool>(false);

  /// 登记（owner 建议用 State 实例，天然唯一）
  static void register(Object owner, Future<void> Function() fn) {
    _handlers[owner] = fn;
    if (activeOwner == owner) {
      visible.value = true;
    }
  }

  /// 注销（必须在 dispose 里调用，否则会残留已销毁页面的方法）
  static void clear([Object? owner]) {
    if (owner == null) {
      _handlers.clear();
      activeOwner = null;
    } else {
      _handlers.remove(owner);
      if (activeOwner == owner) activeOwner = null;
    }
    saving.value = false;
    visible.value = _handlers.containsKey(activeOwner);
  }

  /// 切换当前页（外壳在 Tab 切换时调用）
  static void setActive(Object? owner) {
    activeOwner = owner;
    visible.value = owner != null && _handlers.containsKey(owner);
  }

  static Future<void> run() async {
    final fn = _handlers[activeOwner];
    if (fn == null || saving.value) return;
    saving.value = true;
    try {
      await fn();
    } finally {
      saving.value = false;
    }
  }
}
