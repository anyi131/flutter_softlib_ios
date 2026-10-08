import 'dart:async';
import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_softlib/app/database/database.dart' as db;
import 'package:flutter_softlib/app/database/tables/download_task_table.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/apk_installer.dart';
import '../../utils/install_helper.dart';
import '../../utils/platform_util.dart';
import '../../utils/share_util.dart';
import '../../utils/toast_util.dart';

///下载信息类
class DownInfo {
  String? taskId;
  int? progress;
  String? appId;
  String? appName;
  String? appSize;
  String? appIcon;
  DownloadTaskStatus? status;
  String? createTime;

  /// 任务实际文件名（DB 无记录时的显示兜底，避免出现「未知文件」）
  String? fileName;
}

class AppDownloadLogic extends GetxController {
  db.AppDatabase appDatabase = Get.find<db.AppDatabase>();
  late DownloadTaskDao downloadTaskDao;
  List<DownInfo>? downInfos;
  Timer? timer;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    downloadTaskDao = DownloadTaskDao(appDatabase);
    // 获取所有下载任务信息
    getAllDownInfos();
    // 定时器每100毫秒查询一次下载任务状态
    timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      getAllDownInfos();
    });
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
    if (timer != null) {
      timer?.cancel();
    }
  }

  ///查询所有下载任务
  Future<void> getAllDownInfos() async {
    List<DownloadTask>? downloadTasks = await FlutterDownloader.loadTasks();
    if (downloadTasks != null) {
      downInfos ??= [];
      downInfos!.clear();
      for (var task in downloadTasks) {
        db.DownloadTask? downloadTaskDb = await downloadTaskDao
            .queryDownloadTaskByTaskId(task.taskId);
        downInfos!.add(
          DownInfo()
            ..taskId = task.taskId
            ..status = task.status
            ..progress = task.progress
            ..appId = downloadTaskDb?.appId
            ..appName = downloadTaskDb?.appName
            ..appSize = downloadTaskDb?.appSize
            ..appIcon = downloadTaskDb?.appIcon
            ..fileName = task.filename
            ..createTime = downloadTaskDb?.createTime.toString(),
        );
      }
      // ✅ 添加排序：根据 status 排序
      const statusOrder = {
        DownloadTaskStatus.running: 0,
        DownloadTaskStatus.enqueued: 1,
        DownloadTaskStatus.paused: 2,
        DownloadTaskStatus.complete: 3,
        DownloadTaskStatus.failed: 4,
        DownloadTaskStatus.canceled: 5,
        DownloadTaskStatus.undefined: 6,
      };
      downInfos!.sort((a, b) {
        final aOrder = statusOrder[a.status] ?? 99;
        final bOrder = statusOrder[b.status] ?? 99;
        return aOrder.compareTo(bOrder);
      });
    }

    update(['downInfos']);
  }

  ///暂停下载
  Future<void> pauseDownload(DownInfo? dowInfo) async {
    String? taskId = dowInfo?.taskId;
    if (taskId == null || taskId.isEmpty) {
      ToastUtil.error('下载任务ID无效，请稍后重试');
      return;
    }
    await FlutterDownloader.pause(taskId: taskId);
    update(['${dowInfo?.appId}']);
  }

  ///恢复下载
  Future<void> resumeDownload(DownInfo? dowInfo) async {
    String? taskId = dowInfo?.taskId;
    if (taskId == null || taskId.isEmpty) {
      ToastUtil.error('下载任务ID无效，请稍后重试');
      return;
    }
    String? taskIdTemp = await FlutterDownloader.resume(taskId: taskId);
    if (taskIdTemp == null) {
      ToastUtil.error('恢复下载失败，请稍后重试');
      return;
    }
    taskId = taskIdTemp;
    downloadTaskDao.updateDownloadTask(
      appId: dowInfo!.appId!,
      taskId: taskId,
      appSize: dowInfo.appSize!,
      appName: dowInfo.appName!,
      appIcon: dowInfo.appIcon!,
    );
    update(['${dowInfo.appId}']);
  }

  ///重试下载
  Future<void> retryDownload(DownInfo? dowInfo) async {
    String? taskId = dowInfo?.taskId;
    if (taskId == null || taskId.isEmpty) {
      ToastUtil.error('下载任务ID无效，请稍后重试');
      return;
    }
    String? taskIdTemp = await FlutterDownloader.retry(taskId: taskId);
    if (taskIdTemp == null) {
      ToastUtil.error('重试下载失败，请稍后重试');
      return;
    }
    taskId = taskIdTemp;
    downloadTaskDao.updateDownloadTask(
      appId: dowInfo!.appId!,
      taskId: taskId,
      appSize: dowInfo.appSize!,
      appName: dowInfo.appName!,
      appIcon: dowInfo.appIcon!,
    );
    update(['${dowInfo.appId}']);
  }

  ///取消下载
  Future<void> cancelDownload(DownInfo? dowInfo) async {
    String? taskId = dowInfo?.taskId;
    String? appId = dowInfo?.appId;
    if (taskId == null || taskId.isEmpty) {
      ToastUtil.error('下载任务ID无效，请稍后重试');
      return;
    }
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
    downloadTaskDao.deleteDownloadTask(appId!);
    downInfos?.removeWhere((element) => element.taskId == taskId);
    update(['downInfos']);
  }

  /// 删除下载（记录 + 本地文件）—— 需求 #7
  Future<void> deleteDownload(DownInfo? dowInfo) async {
    final taskId = dowInfo?.taskId;
    final appId = dowInfo?.appId;
    // 先删本地文件
    if (taskId != null && taskId.isNotEmpty) {
      try {
        await FlutterDownloader.remove(
          taskId: taskId,
          shouldDeleteContent: true,
        );
      } catch (_) {}
    }
    // 删数据库记录
    if (appId != null && appId.isNotEmpty) {
      try {
        await downloadTaskDao.deleteDownloadTask(appId);
      } catch (_) {}
    }
    downInfos?.removeWhere((e) => e.taskId == taskId);
    update(['downInfos']);
    ToastUtil.success('已删除');
  }

  /// 批量删除（v52f #2）
  Future<void> deleteMany(List<DownInfo> items) async {
    int ok = 0;
    for (final d in items) {
      final taskId = d.taskId;
      final appId = d.appId;
      if (taskId != null && taskId.isNotEmpty) {
        try {
          await FlutterDownloader.remove(
            taskId: taskId,
            shouldDeleteContent: true,
          );
        } catch (_) {}
      }
      if (appId != null && appId.isNotEmpty) {
        try {
          await downloadTaskDao.deleteDownloadTask(appId);
        } catch (_) {}
      }
      downInfos?.removeWhere((e) => e.taskId == taskId);
      ok++;
    }
    update(['downInfos']);
    ToastUtil.success('已删除 $ok 项');
  }

  /// 清空失败任务（v52f #2）
  Future<void> clearFailed() async {
    final failed =
        downInfos
            ?.where(
              (d) =>
                  d.status == DownloadTaskStatus.failed ||
                  d.status == DownloadTaskStatus.canceled,
            )
            .toList() ??
        [];
    if (failed.isEmpty) {
      ToastUtil.info('没有失败任务');
      return;
    }
    await deleteMany(failed);
  }

  /// 分享下载的文件（调用系统分享面板）—— 需求 #7
  Future<void> shareDownload(DownInfo? dowInfo) async {
    final taskId = dowInfo?.taskId;
    if (taskId == null || taskId.isEmpty) {
      ToastUtil.error('任务无效');
      return;
    }
    final path = await _findPath(taskId);
    if (path == null) {
      ToastUtil.error('找不到文件，可能已被删除');
      return;
    }
    try {
      // ★ iOS：iPad 分享面板需锚点，否则会崩（安卓忽略该参数）
      await Share.shareXFiles([
        XFile(path),
      ], text: dowInfo?.appName ?? '分享一个安装包',
          sharePositionOrigin: ShareUtil.origin());
    } catch (e) {
      ToastUtil.error('分享失败：$e');
    }
  }

  ///安装已下载的软件（原生安装器）
  Future<void> openDownloadFile(DownInfo? dowInfo) async {
    final taskId = dowInfo?.taskId;
    if (taskId == null || taskId.isEmpty) {
      ToastUtil.error('下载任务ID无效');
      return;
    }
    if (Platform.isAndroid) {
      final ok = await ApkInstaller.canInstall();
      if (!ok) {
        await ApkInstaller.openInstallSettings();
        ToastUtil.info('请开启「安装未知应用」权限后重试');
        return;
      }
    }
    final path = await _findPath(taskId);
    if (path == null) {
      ToastUtil.error(PlatUtil.isAndroid ? '未找到安装包' : '未找到下载文件');
      return;
    }
    // ★ iOS：系统不允许安装 APK，降级为「存储/分享」「用其他应用打开」
    //   （Android 不走这里，下面原生安装 + open_filex 兜底一字未改）
    if (!PlatUtil.isAndroid) {
      await InstallHelper.openOnIos(path, name: dowInfo?.appName);
      return;
    }
    if (await ApkInstaller.install(path)) return;
    try {
      await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      return;
    } catch (_) {}
    ToastUtil.error('无法调起安装，请手动安装');
  }

  Future<String?> _findPath(String taskId) async {
    try {
      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task WHERE task_id='$taskId'",
      );
      if (tasks != null && tasks.isNotEmpty) {
        final dir = tasks.first.savedDir ?? '';
        final name = tasks.first.filename;
        if (dir.isNotEmpty) {
          if (name != null && name.isNotEmpty) {
            final f = '$dir/$name';
            if (File(f).existsSync()) return f;
          }
          final d = Directory(dir);
          if (d.existsSync()) {
            final apks = d
                .listSync()
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.apk'))
                .toList();
            if (apks.isNotEmpty) {
              apks.sort(
                (a, b) =>
                    b.statSync().modified.compareTo(a.statSync().modified),
              );
              return apks.first.path;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
