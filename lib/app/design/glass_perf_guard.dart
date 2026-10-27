import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../api/soft_service.dart';
import 'glass_theme.dart';

/// 运行时性能哨兵
///
/// 策略（避免误判）：
///   - 只统计「连续 2 秒内 ≥ 3 次超长帧（> 40ms）」才算真卡
///   - 每次降档后进入 30 秒观察冷却，期间不再统计
///   - 最低降到 low，不会再关掉（low 已经没有模糊了）
///
/// ★ 1027 新增：卡顿上报（tag='jank'，走 /api/softlib/log/report）
///   降档时上报一次：档位变化 + 最长帧 + 路由 + 设备/版本，
///   后台日志页可看「哪些机型在什么页面卡」。5 分钟内只报一次。
class GlassPerfGuard {
  GlassPerfGuard._();

  static bool _running = false;
  static int _slowCount = 0;
  static int _firstSlowAt = 0;
  static int _cooldownUntil = 0;
  static int _lastReportAt = 0;

  /// main/导航处注入：返回当前路由名（用于定位卡顿页面），可空
  static String? Function()? routeHook;

  static const int _slowFrameMs = 40; // 40ms ≈ 25fps 以下
  static const int _windowMs = 2000;
  static const int _threshold = 3;
  static const int _cooldownMs = 30000;
  static const int _reportGapMs = 300000; // 上报冷却 5 分钟

  /// 只统计一次（重复调用安全）
  static void start() {
    if (_running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (!GlassTheme.bigBlur || GlassTheme.locked) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _cooldownUntil) return;

    var slow = 0;
    var worst = 0.0;
    for (final t in timings) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      if (ms > worst) worst = ms;
      if (ms > _slowFrameMs) slow++;
    }
    if (slow == 0) return;

    if (_slowCount == 0) _firstSlowAt = now;
    _slowCount += slow;

    // 窗口过期就重置
    if (now - _firstSlowAt > _windowMs) {
      _slowCount = slow;
      _firstSlowAt = now;
      if (_slowCount < _threshold) return;
    }

    if (_slowCount >= _threshold) {
      final from = GlassTheme.level;
      GlassTheme.degrade(reason: '检测到连续长帧');
      _slowCount = 0;
      _cooldownUntil = now + _cooldownMs;
      // ★ 降档确实发生了才上报（到 low 后不再报，避免刷屏）
      if (GlassTheme.level != from &&
          now - _lastReportAt > _reportGapMs) {
        _lastReportAt = now;
        _report(from, worst);
      }
    }
  }

  static void _report(dynamic from, double worst) {
    String route = '';
    try {
      route = routeHook?.call() ?? '';
    } catch (_) {}
    if (route.startsWith('/admin')) return; // 后台页面不上报
    debugPrint('[GlassPerfGuard] 上报卡顿: $from → ${GlassTheme.level}, 最长帧 ${worst.toStringAsFixed(0)}ms @ $route');
    try {
      SoftService.reportLogStatic(
        tag: 'jank',
        error: '[玻璃降级 ${from.name}→${GlassTheme.level.name}] 最长帧 '
            '${worst.toStringAsFixed(0)}ms | route=$route',
        version: '',
      ).catchError((_) {});
    } catch (_) {}
  }
}
