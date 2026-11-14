import 'package:flutter/scheduler.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/soft_service.dart';

/// 1109：帧耗时探针
///
/// 只报 max 不够——必须分开 UI 线程（build）和 GPU 线程（raster），
/// 否则永远不知道该优化代码还是优化绘制。
/// 另外单独记录「切页后第一帧」，页面首次构建的代价都在这。
class PerfProbe {
  PerfProbe._();

  static double _maxBuild = 0;
  static double _maxRaster = 0;
  static double _sumMs = 0;
  static int _frames = 0;
  static int _slowCount = 0;
  static int _slowBuild = 0;
  static int _slowRaster = 0;
  static String _page = '';
  static DateTime _lastFlush = DateTime.now();
  static bool _installed = false;
  static String _version = '';

  // 切页后的第一帧
  static bool _awaitFirstFrame = false;
  static double _firstBuild = 0;
  static double _firstRaster = 0;

  static void install() {
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    PackageInfo.fromPlatform()
        .then((i) => _version = 'v${i.version}+${i.buildNumber}')
        .catchError((_) {});
  }

  /// 页面切换时调用：归类 + 标记下一帧为首帧
  static void mark(String page) {
    _page = page;
    _awaitFirstFrame = true;
    _firstBuild = 0;
    _firstRaster = 0;
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;

      if (_awaitFirstFrame) {
        _awaitFirstFrame = false;
        _firstBuild = buildMs;
        _firstRaster = rasterMs;
      }

      _frames++;
      _sumMs += buildMs > rasterMs ? buildMs : rasterMs;
      if (buildMs > _maxBuild) _maxBuild = buildMs;
      if (rasterMs > _maxRaster) _maxRaster = rasterMs;
      if (buildMs >= 32) _slowBuild++;
      if (rasterMs >= 32) _slowRaster++;
      if (buildMs >= 32 || rasterMs >= 32) _slowCount++;
    }
    final now = DateTime.now();
    if (_slowCount >= 8 || now.difference(_lastFlush).inSeconds >= 60) {
      _flush();
      _lastFlush = now;
    }
  }

  static void _flush() {
    if (_frames == 0) return;
    final avgMs = _sumMs / _frames;
    final msg =
        '[$_page] frames=$_frames slow=$_slowCount'
        '(ui=$_slowBuild/gpu=$_slowRaster) avg=${avgMs.toStringAsFixed(1)}ms '
        'ui=${_maxBuild.toStringAsFixed(0)}ms gpu=${_maxRaster.toStringAsFixed(0)}ms '
        'first=${_firstBuild.toStringAsFixed(0)}/${_firstRaster.toStringAsFixed(0)}ms';
    try {
      SoftService.reportLogStatic(
        tag: 'perf',
        error: msg,
        version: _version,
      ).catchError((_) {});
    } catch (_) {}
    _frames = 0;
    _sumMs = 0;
    _slowCount = 0;
    _slowBuild = 0;
    _slowRaster = 0;
    _maxBuild = 0;
    _maxRaster = 0;
  }
}
