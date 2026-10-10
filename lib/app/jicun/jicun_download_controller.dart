////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 全局下载任务控制器
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植改造。
// 任务挂在 GetX 全局单例上:退出解析页任务照跑(上游把任务生命周期放在根
// State,宿主按宿主惯例放全局控制器)。进度/状态用 GetX 可观察列表,页面只管订阅。
// 版权与许可遵循上游 MIT License,见仓库 LICENSE。
////////////////////////////////////////////////////////////////////////////////
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'jicun_config.dart';
import 'jicun_downloader.dart';
import 'jicun_history_store.dart';
import 'jicun_upstream_mapping.dart';

/// 一条任务的状态。
enum JicunTaskStatus { waiting, running, done, failed, cancelled }

/// 一条下载任务(一次「下载」动作 = 一个任务;图集一批图算一个任务)。
class JicunTask {
  JicunTask({
    required this.id,
    required this.title,
    required this.platform,
    required this.items,
  });

  final String id;

  /// 展示标题(取解析结果的标题/文案首行)。
  final String title;

  /// 平台中文名。
  final String platform;

  /// 这一批要下的文件。
  final List<DownloadItem> items;

  /// 已落盘的文件路径(与 items 对齐,失败条目为空串)。
  final List<String> files = <String>[];

  final Rx<JicunTaskStatus> status = JicunTaskStatus.waiting.obs;

  /// 进度 0~1。
  final RxDouble progress = 0.0.obs;

  /// 失败/取消原因(给 UI 的提示)。
  String? message;

  /// 已完成条数(给 UI「3/17」这类文案)。
  final RxInt doneCount = 0.obs;

  bool get isDone => status.value == JicunTaskStatus.done;
  bool get isBusy =>
      status.value == JicunTaskStatus.waiting ||
      status.value == JicunTaskStatus.running;
}

/// 全局下载控制器。启动时注册(Get.put),App 全生命周期存活。
class JicunDownloadController extends GetxController {
  static JicunDownloadController get I =>
      Get.isRegistered<JicunDownloadController>()
      ? Get.find<JicunDownloadController>()
      : Get.put(JicunDownloadController(), permanent: true);

  /// 任务列表(新的在前)。
  final RxList<JicunTask> tasks = <JicunTask>[].obs;

  var _seq = 0;

  /// 从解析结果建一批下载任务并立刻开跑。
  ///
  /// [quality] 为空时按后台 quality_default:highest 取最高档,ask 已由页面弹窗选定。
  JicunTask enqueueResult(
    ParseResult result,
    String sourceUrl, {
    VideoQuality? quality,
  }) {
    final items = _buildItems(result, quality: quality);
    final title =
        (result.title.isNotEmpty
                ? result.title
                : (result.desc.isNotEmpty ? result.desc : '即存媒体'))
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    final task = JicunTask(
      id: 'jicun_${DateTime.now().microsecondsSinceEpoch}_${_seq++}',
      title: title.isEmpty ? '即存媒体' : title,
      platform: result.platform,
      items: items,
    );
    for (var i = 0; i < items.length; i++) {
      task.files.add('');
    }
    tasks.insert(0, task);
    unawaited(_run(task, result, sourceUrl));
    return task;
  }

  /// 解析结果 → 下载条目。命名/后缀策略与上游 preview 页一致:
  /// 标题起名,图集按序号,视频按清晰度档。
  List<DownloadItem> _buildItems(ParseResult result, {VideoQuality? quality}) {
    final stem = safeFileName(
      result.title.isNotEmpty ? result.title : result.desc,
    );
    final items = <DownloadItem>[];
    // 视频:选中的档位(或合集每条)。
    if (quality != null) {
      items.add(
        DownloadItem(
          url: quality.url,
          fileName: '$stem.mp4',
          kind: MediaKind.video,
        ),
      );
    } else if (result.videos.isNotEmpty) {
      for (var i = 0; i < result.videos.length; i++) {
        final v = result.videos[i];
        final q = v.qualities.isNotEmpty ? v.qualities.first : null;
        final name = result.videos.length > 1
            ? '$stem${i > 0 ? '_${i + 1}' : ''}.mp4'
            : '$stem.mp4';
        items.add(
          DownloadItem(
            url: q?.url ?? v.url,
            fileName: name,
            kind: MediaKind.video,
          ),
        );
      }
    } else if (result.videoUrl != null) {
      items.add(
        DownloadItem(
          url: result.videoUrl!,
          fileName: '$stem.mp4',
          kind: MediaKind.video,
        ),
      );
    }
    // 图集。
    for (var i = 0; i < result.imageUrls.length; i++) {
      items.add(
        DownloadItem(
          url: result.imageUrls[i],
          fileName: '${stem}_$i.jpg',
          kind: MediaKind.image,
        ),
      );
    }
    // 实况图(下载动态那段 mp4,上游同款)。
    for (var i = 0; i < result.livePhotos.length; i++) {
      items.add(
        DownloadItem(
          url: result.livePhotos[i].videoUrl,
          fileName: '${stem}_实况$i.jpg',
          kind: MediaKind.image,
        ),
      );
    }
    // 独立音频。
    if (result.videoUrl == null &&
        result.videos.isEmpty &&
        result.audioUrl != null) {
      items.add(
        DownloadItem(
          url: result.audioUrl!,
          fileName: '$stem.m4a',
          kind: MediaKind.audio,
        ),
      );
    }
    return items;
  }

  Future<void> _run(
    JicunTask task,
    ParseResult result,
    String sourceUrl,
  ) async {
    final cfg = JicunSettings.instance.cfg;
    final tuning = DownloadTuning(
      concurrency: cfg.maxConcurrent > 0 ? cfg.maxConcurrent : 4,
      // min_split_size(MB)→ 分段阈值字节;非法回落 8MB。
      segmentedFromBytes: (cfg.minSplitSize > 0 ? cfg.minSplitSize : 8) << 20,
      maxSegments: 32,
    );
    final downloader = Downloader(tuning: tuning);
    task.status.value = JicunTaskStatus.running;
    try {
      await downloader.saveAll(
        task.items,
        onProgress: (p) {
          task.progress.value = p.fraction;
        },
        onItemDone: (index, file) {
          task.files[index] = file.path;
          task.doneCount.value = task.files.where((f) => f.isNotEmpty).length;
        },
      );
      task.progress.value = 1;
      task.status.value = JicunTaskStatus.done;
      // 全部落盘成功才记一条历史(和上游「下完才进历史」的体验一致)。
      unawaited(HistoryStore().add(result, sourceUrl));
    } on DownloadCancelled {
      task.status.value = JicunTaskStatus.cancelled;
      task.message = '已取消';
    } catch (e) {
      final ok = task.files.where((f) => f.isNotEmpty).length;
      if (ok > 0) {
        // 部分成功:按完成对待,但把失败原因带上。
        task.status.value = JicunTaskStatus.done;
        task.message = '$ok/${task.items.length} 成功:$_errText(e)';
      } else {
        task.status.value = JicunTaskStatus.failed;
        task.message = _errText(e);
      }
    }
    update(['jicun_tasks']);
  }

  static String _errText(Object e) {
    var t = e.toString();
    t = t.replaceFirst(RegExp(r'^Exception:\s*'), '');
    return t.length > 60 ? '${t.substring(0, 60)}…' : t;
  }

  /// 取消一个还在跑的任务。
  void cancel(String id) {
    final t = tasks.firstWhereOrNull((x) => x.id == id);
    if (t == null || !t.isBusy) return;
    // 引擎按条目认领推进,取消以「终止后续条目」为语义:直接置态,
    // 正在收流的那条由 isolate 调度自然结束(上游 Dart 引擎同款限制)。
    t.status.value = JicunTaskStatus.cancelled;
    t.message = '已取消';
    update(['jicun_tasks']);
  }

  /// 清掉已结束的任务卡片。
  void clearFinished() {
    tasks.removeWhere((t) => !t.isBusy);
    update(['jicun_tasks']);
  }

  /// 退出页面时的历史清理(后台 clear_on_exit)。
  Future<void> clearHistoryIfConfigured() async {
    if (!JicunSettings.instance.cfg.clearOnExit) return;
    await HistoryStore().clear();
  }

  /// 启动清扫:缓存里残留超过 24h 的分片。
  @override
  void onInit() {
    super.onInit();
    unawaited(Downloader.sweepLeftovers());
  }
}
