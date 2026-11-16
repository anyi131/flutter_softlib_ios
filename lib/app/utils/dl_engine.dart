import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bg;
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart' as fd;

/// 1109：下载引擎适配层
/// ————————————————————————————————————————————————
/// 新引擎：background_downloader 的 ParallelDownloadTask（多连接分段，IDM 式）
///   · Android WorkManager / iOS URLSession background —— App 切后台/被杀也继续
///   · chunks 条并发 Range 请求，中转 700KB/s → 约 2.8MB/s
/// 旧引擎：flutter_downloader（单连接），保留用于历史任务与降级
///
/// taskId 以 `pdl_` 开头的走新引擎，其余走旧引擎 —— 老任务/老安装不受影响。
class _StallWatch {
  _StallWatch({
    required this.fileName,
    required this.savedDir,
    required this.proxyUrl,
  });

  final String fileName;
  final String savedDir;
  final String proxyUrl;
  int pct = 0;
  DateTime at = DateTime.now();
  bool retried = false;
  bool switching = false;
  bool reported = false;
  bool done = false;
}

class DlEngine {
  DlEngine._();

  /// 分段数（4 段已被实践验证；过高会被源站限流）
  static const int chunks = 4;

  /// 小于该体积（字节）不分段：小文件分段的握手开销反而更慢
  static const int minParallelBytes = 8 * 1024 * 1024;

  /// 新引擎总开关（出问题可一键降级：false 则完全走旧引擎）
  static const bool enabled = true;

  static const String prefix = 'pdl_';

  /// 事件出口：由 main.dart 注入 → AppDetailsLogic.downloadCallback
  static void Function(String id, int status, int progress)? onEvent;

  static StreamSubscription? _sub;

  /// 卡死上报出口（由 main.dart 注入 → SoftService.reportLogStatic）
  static void Function(String msg)? onStallReport;

  /// 每个新引擎任务的卡死监控
  static final Map<String, _StallWatch> _watch = {};
  static Timer? _stallTimer;
  static final Map<String, bg.DownloadTask> _tasks = {};
  static final Map<String, String> _paths = {};

  static bool isNewTask(String? taskId) =>
      taskId != null && taskId.startsWith(prefix);

  // ───────────────── 入队 ─────────────────

  /// 返回 taskId；返回 null 表示失败（调用方可回退旧引擎）
  static Future<String?> enqueue({
    required String url,
    required String fileName,
    required String savedDir,
    bool showNotification = true,
    int? expectedBytes,
    /// 1109e：中转兜底地址 —— 新引擎自己检测卡死并用它重下，
    ///   不再依赖详情页轮询（详情页查不到 pdl_ 任务，检测永远不执行）
    String proxyUrl = '',
    /// 1109e：自定义请求头（urlV4 需要带 Host 头）
    Map<String, String> headers = const {},
  }) async {
    if (!enabled) return null;
    // 小文件不用分段
    final useParallel = expectedBytes == null || expectedBytes >= minParallelBytes;
    final id = '$prefix${DateTime.now().microsecondsSinceEpoch}';
    try {
      final task = bg.ParallelDownloadTask(
        taskId: id,
        url: url,
        filename: fileName,
        directory: savedDir,
        baseDirectory: bg.BaseDirectory.root, // savedDir 是绝对路径
        chunks: useParallel ? chunks : 1,
        allowPause: true,
        retries: 2,
        updates: bg.Updates.progress,
        requiresWiFi: false,
        headers: headers,
      );
      _bind();
      _tasks[id] = task;
      _paths[id] = _join(savedDir, fileName);
      _watch[id] = _StallWatch(
        fileName: fileName,
        savedDir: savedDir,
        proxyUrl: proxyUrl,
      );
      _ensureStallTimer();
      final ok = await bg.FileDownloader().enqueue(task);
      if (!ok) {
        _emit(id, 4, 0); // failed
        return null;
      }
      return id;
    } catch (e) {
      debugPrint('[DlEngine] enqueue 失败，回退旧引擎: $e');
      return null;
    }
  }

  // ───────────────── 事件绑定 ─────────────────

  static void _bind() {
    _sub ??= bg.FileDownloader().updates.listen(_onUpdate);
  }

  static void _onUpdate(bg.TaskUpdate u) {
    final id = u.task.taskId;
    if (!id.startsWith(prefix)) return;
    if (u is bg.TaskProgressUpdate) {
      final p = (u.progress * 100).round().clamp(0, 100);
      _emit(id, 2, p); // running
      final w = _watch[id];
      if (w != null && p > w.pct) {
        w.pct = p;
        w.at = DateTime.now();
      }
    } else if (u is bg.TaskStatusUpdate) {
      _emit(id, _mapStatus(u.status), u.status == bg.TaskStatus.complete ? 100 : 0);
      if (u.status == bg.TaskStatus.complete ||
          u.status == bg.TaskStatus.failed ||
          u.status == bg.TaskStatus.canceled) {
        final w = _watch[id];
        if (w != null) w.done = true;
        _watch.remove(id);
      }
    }
  }

  static int _mapStatus(bg.TaskStatus s) {
    switch (s) {
      case bg.TaskStatus.enqueued:
      case bg.TaskStatus.waitingToRetry:
        return 1;
      case bg.TaskStatus.running:
        return 2;
      case bg.TaskStatus.complete:
        return 3;
      case bg.TaskStatus.failed:
      case bg.TaskStatus.notFound:
        return 4;
      case bg.TaskStatus.canceled:
        return 5;
      case bg.TaskStatus.paused:
        return 6;
    }
  }

  static void _ensureStallTimer() {
    _stallTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      _checkStalls();
    });
  }

  /// 每 2 秒扫一遍：进度 8 秒没增长 → 用中转地址重下一次（每任务一次）
  static void _checkStalls() {
    if (_watch.isEmpty) return;
    final now = DateTime.now();
    for (final e in _watch.entries.toList()) {
      final id = e.key;
      final w = e.value;
      if (w.done || w.switching) continue;
      final idle = now.difference(w.at).inSeconds;
      if (idle < 8) continue;
      if (w.retried || w.proxyUrl.isEmpty) {
        // 已经试过中转（或没有中转地址）→ 只上报，不再重试
        if (!w.reported) {
          w.reported = true;
          onStallReport?.call(
            '[stall] 任务 ${w.pct}% 停住 ${idle}s 无法继续'
            '${w.proxyUrl.isEmpty ? "（无中转地址）" : "（中转也失败）"}',
          );
        }
        continue;
      }
      w.retried = true;
      w.switching = true;
      onStallReport?.call('[stall] ${w.pct}% 停住 ${idle}s，切换中转重下');
      _switchToProxy(id, w);
    }
  }

  static Future<void> _switchToProxy(String oldId, _StallWatch w) async {
    try {
      await remove(oldId, shouldDeleteContent: true);
    } catch (_) {}
    _watch.remove(oldId);
    _tasks.remove(oldId);
    try {
      final newId = await enqueue(
        url: w.proxyUrl,
        fileName: w.fileName,
        savedDir: w.savedDir,
        proxyUrl: '',
      );
      if (newId != null) {
        onEvent?.call(newId, 1, 0);
        onStallReport?.call('[stall] 已用中转重下 newTask=${newId.substring(0, 8)}');
      } else {
        onStallReport?.call('[stall] 中转重下失败（enqueue 返回 null）');
      }
    } catch (e) {
      onStallReport?.call('[stall] 中转重下异常 $e');
    }
  }

  static void _emit(String id, int status, int progress) {
    onEvent?.call(id, status, progress);
  }

  // ───────────────── 控制 ─────────────────

  /// 删除任务（新引擎：取消并删临时文件）
  static Future<void> remove(String taskId, {bool shouldDeleteContent = true}) async {
    if (isNewTask(taskId)) {
      try {
        await bg.FileDownloader().cancelTaskWithId(taskId);
      } catch (_) {}
      if (shouldDeleteContent) {
        final p = _paths[taskId];
        if (p != null) {
          try {
            final f = File(p);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
      }
      return;
    }
    try {
      await fd.FlutterDownloader.remove(
        taskId: taskId,
        shouldDeleteContent: shouldDeleteContent,
      );
    } catch (_) {}
  }

  /// 暂停
  static Future<void> pause(String taskId) async {
    if (isNewTask(taskId)) {
      // ParallelDownloadTask 支持暂停（allowPause: true）
      final t = await _taskOf(taskId);
      if (t != null) {
        try {
          await bg.FileDownloader().pause(t);
        } catch (_) {}
      }
      return;
    }
    try {
      await fd.FlutterDownloader.pause(taskId: taskId);
    } catch (_) {}
  }

  /// 恢复
  static Future<void> resume(String taskId) async {
    if (isNewTask(taskId)) {
      final t = await _taskOf(taskId);
      if (t != null) {
        try {
          await bg.FileDownloader().resume(t);
        } catch (_) {}
      }
      return;
    }
    try {
      await fd.FlutterDownloader.resume(taskId: taskId);
    } catch (_) {}
  }

  /// 已完成任务的最终文件路径（新引擎用）
  static Future<String?> finishedPath(String taskId) async {
    return _paths[taskId];
  }

  /// 取任务对象（内存优先，重启后从数据库记录里取）
  static Future<bg.DownloadTask?> _taskOf(String taskId) async {
    final mem = _tasks[taskId];
    if (mem != null) return mem;
    try {
      final rec = await bg.FileDownloader().database.recordForId(taskId);
      final t = rec?.task;
      if (t is bg.DownloadTask) return t;
    } catch (_) {}
    return null;
  }

  static String _join(String dir, String name) =>
      dir.endsWith('/') ? '$dir$name' : '$dir/$name';

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
