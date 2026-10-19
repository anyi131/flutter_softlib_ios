import 'package:flutter/scheduler.dart';

import 'glass_theme.dart';

/// 运行时性能哨兵
///
/// ★ 目的：设备能力探测只是静态判断（内存/系统版本），
///   但真实卡顿可能来自别的地方（后台进程、发热降频、大图列表）。
///   所以再加一层「实测」：连续出现长帧就自动把玻璃降一档。
///
/// 策略（避免误判）：
///   - 只统计「连续 2 秒内 ≥ 3 次超长帧（> 40ms）」才算真卡
///   - 每次降档后进入 30 秒观察冷却，期间不再统计
///   - 最低降到 low，不会再关掉（low 已经没有模糊了）
class GlassPerfGuard {
  GlassPerfGuard._();

  static bool _running = false;
  static int _slowCount = 0;
  static int _firstSlowAt = 0;
  static int _cooldownUntil = 0;

  static const int _slowFrameMs = 40; // 40ms ≈ 25fps 以下
  static const int _windowMs = 2000;
  static const int _threshold = 3;
  static const int _cooldownMs = 30000;

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
    for (final t in timings) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
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
      GlassTheme.degrade(reason: '检测到连续长帧');
      _slowCount = 0;
      _cooldownUntil = now + _cooldownMs;
    }
  }
}
