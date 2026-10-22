import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_softlib/app/database/database.dart' as db;
import 'package:flutter_softlib/app/database/tables/download_task_table.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/unlock_service.dart';
import '../../utils/jump_util.dart';

import 'package:flutter/services.dart';

import '../../utils/app_action.dart';
import '../../utils/download_dir.dart';
import '../../api/soft_service.dart';
import '../../api/user_service.dart';
import '../../utils/apk_installer.dart';
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

  /// 按软件名/文件名回查 appId（下载记录里缺 appId 时用）
  Future<int> _guessAppIdFromName(String name) async {
    if (name.isEmpty) return 0;
    try {
      // 去掉扩展名与时间戳后缀：Peach_Blossom（正能量）_1792583000.apk
      var key = name.replaceAll('_', ' ');
      key = key.replaceAll(RegExp(r'\.apk$', caseSensitive: false), '');
      key = key.replaceAll(RegExp(r'\s*\d{10,}$'), '').trim();
      if (key.isEmpty) return 0;
      final apps = await SoftService.instance.fetchApps(keyword: key);
      for (final a in apps) {
        final t = a.title.replaceAll(' ', '');
        if (t.contains(key.replaceAll(' ', '')) ||
            key.replaceAll(' ', '').contains(t)) {
          return a.id;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// ★ 1014 安全：续传/重试前必须重新通过服务端鉴权。
  /// 原来这两个入口直接调 FlutterDownloader.resume/retry，复用任务库里的旧 URL，
  /// 完全不问服务端 —— 只要任务表里还有一条暂停/失败任务，
  /// 未登录或会员已过期也能把 APK 拉完。现在统一在此拦截。
  Future<bool> _recheckAuth(DownInfo? dowInfo) async {
    if (!UserService.instance.isLoggedIn) {
      ToastUtil.error('请先登录后再下载');
      return false;
    }
    var appId = int.tryParse('${dowInfo?.appId ?? 0}') ?? 0;
    // ★★ 1020 修复「无法确认该资源的归属」误拦：
    //   appId 来自本地 download_task 表，而这张表只在「详情页下载」时写入。
    //   从下载管理页重试、或旧版本留下的任务，appId 就是 null/0 →
    //   直接走进安全拦截，用户根本下不了（截图实锤）。
    //   现在：appId 缺失时先按「文件名 → 软件名」回查一次；仍查不到则**放行**，
    //   因为服务端的解析接口本身就有鉴权，不会因为这里少拦一次就被白嫖。
    if (appId <= 0) {
      appId = await _guessAppIdFromName(
        dowInfo?.appName ?? dowInfo?.fileName ?? '',
      );
    }
    if (appId <= 0) {
      // 查不到归属：不阻断，交给服务端解析接口鉴权
      return true;
    }
    try {
      final st = await UnlockService.instance.status(appId);
      if (!st.canDownload) {
        ToastUtil.error(
          st.price.isNotEmpty && (double.tryParse(st.price) ?? 0) > 0
              ? '该资源需支付 ¥${st.price} 后下载'
              : '该资源需要开通会员后下载',
        );
        return false;
      }
      return true;
    } catch (_) {
      ToastUtil.error('无法连接服务器完成校验，请检查网络后重试');
      return false;
    }
  }

  ///恢复下载
  Future<void> resumeDownload(DownInfo? dowInfo) async {
    String? taskId = dowInfo?.taskId;
    if (taskId == null || taskId.isEmpty) {
      ToastUtil.error('下载任务ID无效，请稍后重试');
      return;
    }
    // ★ 1014 安全：续传前重新鉴权
    if (!await _recheckAuth(dowInfo)) return;
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
  /// 重试下载
  ///
  /// ★★ 1020 重做：原来直接 FlutterDownloader.retry(taskId)，
  ///   复用的是**任务里存的旧直链**。而蓝奏云直链几小时就过期，
  ///   所以「直链过期」这一类失败，点多少次重试都是同一个结果。
  ///
  ///   现在：先重新走一遍解析拿新直链；拿到就新建任务，拿不到就
  ///   给用户「浏览器打开」兜底，别让人卡在原地。
  Future<void> retryDownload(DownInfo? dowInfo) async {
    final taskId = dowInfo?.taskId;
    if (taskId == null || taskId.isEmpty) {
      ToastUtil.error('下载任务ID无效，请稍后重试');
      return;
    }
    if (!await _recheckAuth(dowInfo)) return;

    // ① 找到原始分享链接（lanzou 页面地址）
    String rawUrl = '';
    try {
      final appId = int.tryParse('${dowInfo?.appId ?? 0}') ?? 0;
      if (appId > 0) {
        final it = await SoftService.instance.fetchAppDetail(id: appId);
        rawUrl = it?.url ?? '';
      }
    } catch (_) {}

    // ② 重新解析拿新直链
    if (rawUrl.isNotEmpty) {
      AppAction.showLoading('正在重新获取下载地址…');
      String? fresh;
      try {
        fresh = await SoftService.instance.resolveLzy(rawUrl);
      } catch (_) {}
      AppAction.hideLoading();

      if (fresh != null && fresh.isNotEmpty) {
        try {
          await FlutterDownloader.remove(
            taskId: taskId,
            shouldDeleteContent: true,
          );
        } catch (_) {}
        final newId = await FlutterDownloader.enqueue(
          url: fresh,
          fileName: _retryFileName(dowInfo),
          savedDir: await DownloadDir.path(),
          showNotification: true,
          saveInPublicStorage: false,
          openFileFromNotification: true,
        );
        if (newId != null) {
          try {
            await downloadTaskDao.updateDownloadTask(
              appId: dowInfo!.appId ?? '',
              taskId: newId,
              appSize: dowInfo.appSize ?? '',
              appName: dowInfo.appName ?? '',
              appIcon: dowInfo.appIcon ?? '',
            );
          } catch (_) {}
          ToastUtil.success('已重新开始下载');
          getAllDownInfos();
          return;
        }
      }

      // ③ 重新解析失败 → 给浏览器兜底
      _showBrowserFallback(rawUrl);
      return;
    }

    // ④ 拿不到原始链接 → 退回原来的原地重试
    final taskIdTemp = await FlutterDownloader.retry(taskId: taskId);
    if (taskIdTemp == null) {
      ToastUtil.error('重试下载失败，请稍后重试');
      return;
    }
    try {
      await downloadTaskDao.updateDownloadTask(
        appId: dowInfo!.appId ?? '',
        taskId: taskIdTemp,
        appSize: dowInfo.appSize ?? '',
        appName: dowInfo.appName ?? '',
        appIcon: dowInfo.appIcon ?? '',
      );
    } catch (_) {}
    update(['${dowInfo?.appId}']);
  }

  /// 重试时的文件名（带时间戳，避免和旧文件冲突）
  String _retryFileName(DownInfo? d) {
    var name = (d?.appName ?? d?.fileName ?? 'download').replaceAll(' ', '_');
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (name.toLowerCase().endsWith('.apk')) {
      name = name.substring(0, name.length - 4);
    }
    name = name.replaceAll(RegExp(r'_\d{10,}$'), '');
    return '${name}_${DateTime.now().millisecondsSinceEpoch}.apk';
  }

  /// 解析不了时：让用户用浏览器打开原链接
  void _showBrowserFallback(String rawUrl) {
    Get.dialog<void>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('暂时无法自动下载', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '下载地址获取失败，可能是源站限制。\n你可以用浏览器打开原页面手动下载。',
              style: TextStyle(fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: 10),
            SelectableText(
              rawUrl,
              style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rawUrl));
              ToastUtil.success('链接已复制');
            },
            child: const Text('复制链接'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              JumpUtil.openUrl(rawUrl);
            },
            child: const Text('浏览器打开'),
          ),
        ],
      ),
    );
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
      await Share.shareXFiles([
        XFile(path),
      ], text: dowInfo?.appName ?? '分享一个安装包');
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
      ToastUtil.error('未找到安装包');
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
