import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../api/global_error_reporter.dart';

/// 1109：真机帧耗时采集 —— 不需要用户截图，App 自己上报
///
/// 原理：监听每一帧的时间戳，单帧超过 [slowMs] 就累计；
/// 每满 [flushEvery] 次慢帧（或 60s 定时）把聚合数据上报：
///   tag = perf
///   error = 页面|慢帧数|最大帧耗ms|平均帧耗ms
///
/// 服务端落 fa_softlib_crash_log，后台能直接看。
class PerfProbe {
  PerfProbe._();

  static FrameTiming? _worst;
  static int _slowCount = 0;
  static double _sumMs = 0;
  static int _frames = 0;
  static String _page = '';
  static DateTime _lastFlush = DateTime.now();
  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// 页面切换时调用，让上报能按页面归类
  static void mark(String page) => _page = page;

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      // UI 线程 + Raster 线程取较大者 = 这一帧的真实耗时
      final buildMs = t.buildDuration.inMicroseconds / 1000;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000;
      final ms = buildMs > rasterMs ? buildMs : rasterMs;
      _frames++;
      _sumMs += ms;
      if (ms > (_worst?.buildDuration.inMicroseconds / 1000 ?? 0)) {
        _worst = t;
      }
      if (ms >= 32) {
        _slowCount++;
        if (_worst == null ||
            ms > (_worst!.buildDuration.inMicroseconds / 1000)) {
          _worst = t;
        }
      }
    }
    final now = DateTime.now();
    if (_slowCount >= 5 ||
        now.difference(_lastFlush).inSeconds >= 60) {
      _flush();
      _lastFlush = now;
    }
  }

  static void _flush() {
    if (_frames == 0) return;
    final worstMs = _worst == null
        ? 0
        : (_worst!.buildDuration.inMicroseconds / 1000)
            .clamp(0, 99999);
    final avgMs = _sumMs / _frames;
    final msg = '[$_page] frames=$_frames slow=$_slowCount '
        'avg=${avgMs.toStringAsFixed(1)}ms worst=${worstMs.toStringAsFixed(0)}ms';
    // 走现成的上报通道（节流每小时 20 条由通道自己控制）
    GlobalErrorReporter.report('perf', msg);
    _frames = 0;
    _sumMs = 0;
    _slowCount = 0;
    _worst = null;
  }
}
