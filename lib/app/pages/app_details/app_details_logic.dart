import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'resolve_overlay.dart';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';

import '../../config.dart';
import '../../database/database.dart' as db;
import '../../database/tables/download_task_table.dart';
import '../../design/app_style.dart';
import '../../design/app_style_controller.dart';
import '../../design/ui.dart';
import '../../models/app_item.dart';
import '../../models/http/results/lzy_file_info_model.dart';
import '../../api/api_host.dart';
import '../../api/soft_service.dart';
import '../../api/user_service.dart';
import '../../utils/apk_installer.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';
import '../../widgets/posters/posters_widget.dart';

@pragma('vm:entry-point')
class AppDetailsLogic extends GetxController {
  /// 参数：appId(String) + item(AppItem) 【或旧格式 dowUrl】
  int appIdInt = 0;

  /// 下载任务唯一标识
  /// ★ 文件夹里的软件 id=0，必须用 url 生成唯一 key，否则不同软件共用下载状态
  String _taskKey = '';
  AppItem? item;

  String get appId => _taskKey.isNotEmpty ? _taskKey : appIdInt.toString();

  /// 蓝奏云情况下需要的信息来源
  String dowUrl = '';

  SoftService service = SoftService.instance;
  GlobalKey posterKey = GlobalKey();

  /// 统一详情模型（复用蓝奏云文件信息模型展示）
  LzyFileInfoData? appInfo;
  String? msgError;
  bool isLoadingInfo = true;

  db.AppDatabase appDatabase = Get.find<db.AppDatabase>();
  ReceivePort port = ReceivePort();
  late DownloadTaskDao downloadTaskDao;
  DownloadTask? downloadTask;
  String? taskId;
  Timer? _progressTimer;

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(
      'app_details_downloader_send_port',
    );
    send?.send([id, status, progress]);
  }

  @override
  void onInit() {
    super.onInit();
    // ★ 修复：后台切换「软件详情页模板」不生效 ——
    //   服务端下发的 ui_config.home.detail_style 之前没有任何地方应用到
    //   AppStyleController.detailStyle，详情页永远落在默认分支。
    //   进入详情页时以服务端配置强制同步（后台选哪个，详情页就变哪个）。
    final serverDetail =
        SoftService.instance.cachedConfig?.uiConfig.detailStyle;
    if (serverDetail != null && serverDetail.isNotEmpty) {
      AppStyleController.instance.detailStyle.value = parseDetailStyle(
        serverDetail,
      );
    }
    downloadTaskDao = DownloadTaskDao(appDatabase);
    _parseArguments();
    // 浏览量 +1（真实数据采集）
    if (appIdInt > 0) service.addAppView(appIdInt);
    getAppInfo();
    getTaskInfo();
    // ★ 重新进入页面时，若已有进行中的任务，恢复进度轮询
    Future.delayed(const Duration(milliseconds: 500), () {
      final st = downloadTask?.status;
      if (st == DownloadTaskStatus.running ||
          st == DownloadTaskStatus.enqueued ||
          st == DownloadTaskStatus.paused) {
        _startProgressPolling();
      }
    });
    IsolateNameServer.removePortNameMapping('app_details_downloader_send_port');
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      'app_details_downloader_send_port',
    );
    port.listen((dynamic data) {
      if (data is List && data.length >= 3) {
        final status = data[1] is int ? data[1] as int : 0;
        getTaskInfo();
        // 下载完成 → 弹窗确认安装
        if (status == 3 /* complete */ ) {
          _onDownloadComplete();
        }
      }
    });
    FlutterDownloader.registerCallback(downloadCallback);
  }

  void _parseArguments() {
    final args = Get.arguments;
    if (args is Map) {
      final it = args['item'];
      if (it is AppItem) {
        item = it;
        appIdInt = it.id;
        dowUrl = it.url;
        // ★ 唯一标识：优先用 url（文件夹软件 id=0 会冲突）
        _taskKey = it.url.isNotEmpty
            ? 'u_${it.url.hashCode.abs()}'
            : (it.id > 0 ? 'i_${it.id}' : 'n_${it.title.hashCode.abs()}');
      }
      final rawId = args['appId'];
      if (rawId != null && appIdInt == 0) {
        appIdInt = int.tryParse(rawId.toString()) ?? 0;
      }
      final rawUrl = args['dowUrl'];
      if (rawUrl != null && dowUrl.isEmpty) dowUrl = rawUrl.toString();
      if (_taskKey.isEmpty && dowUrl.isNotEmpty) {
        _taskKey = 'u_${dowUrl.hashCode.abs()}';
      }
    }
  }

  /// 获取软件信息（双数据源）
  /// ★ 性能：先用列表页已带过来的数据立即渲染（秒开），
  ///   仅在关键信息缺失时才在后台静默补全，绝不阻塞首屏。
  Future<void> getAppInfo() async {
    isLoadingInfo = true;
    update(['appInfo', 'share', 'download']);

    // ① 立即用本地已有数据构造（不等待任何网络）
    if (item != null) {
      final it = item!;
      final hasLocalInfo =
          it.description.isNotEmpty ||
          it.size.isNotEmpty ||
          it.icon.isNotEmpty ||
          it.title.isNotEmpty;
      if (hasLocalInfo || it.fromFolder) {
        appInfo = LzyFileInfoData(
          fileIcon: it.icon,
          fileName: it.title,
          fileSize: it.size,
          fileTime: it.fromFolder
              ? (it.uploadDate.isNotEmpty ? it.uploadDate : '最近更新')
              : it.version,
          fileType: it.isLocal ? '服务器直传' : '蓝奏云',
          fileDesc: it.description.isNotEmpty
              ? it.description
              : (it.fromFolder ? '本软件来自蓝奏云文件夹，请放心下载。' : ''),
          fileImage: it.screenshots.isNotEmpty ? it.screenshots.first : '',
        );
        isLoadingInfo = false;
        update(['appInfo', 'share', 'download']);
      }
    }

    // ② 后台静默补全（仅当关闭了本地数据仍不完整时）
    final needFetch = item == null
        ? dowUrl.isNotEmpty
        : (!item!.isLocal &&
              item!.url.isNotEmpty &&
              (item!.description.isEmpty || item!.size.isEmpty));
    if (!needFetch) return;

    try {
      final target = item?.url ?? dowUrl;
      final info = await service.lzyFileInfo(target);
      if (info != null) {
        final it = item;
        final dbIcon = it?.icon ?? '';
        final parsedIcon = (info['icon'] ?? '').toString();
        appInfo = LzyFileInfoData(
          fileIcon: dbIcon.isNotEmpty ? dbIcon : parsedIcon,
          fileName: (it?.title.isNotEmpty == true)
              ? it!.title
              : (info['name'] ?? '').toString(),
          fileSize: (it?.size.isNotEmpty == true)
              ? it!.size
              : (info['size'] ?? '').toString(),
          fileTime: (info['time'] ?? it?.version ?? '').toString(),
          fileType: (info['type'] ?? '蓝奏云').toString(),
          fileDesc: (it?.description.isNotEmpty == true)
              ? it!.description
              : (info['des'] ?? '').toString(),
        );
      }
    } catch (e) {
      logger.e(e.toString());
      // 已有本地数据时不报错，静默处理
      if (appInfo == null) msgError ??= '网络异常，请稍后重试';
    } finally {
      isLoadingInfo = false;
      update(['appInfo', 'share', 'download']);
    }
  }

  /// 解析失败弹窗：引导用浏览器打开原链接下载（需求 #2）
  Future<void> _showParseFailedDialog(String originUrl) async {
    final ctx = Get.context;
    if (ctx == null) {
      ToastUtil.error('直链解析失败，请稍后重试');
      return;
    }
    final go = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.link_off_rounded, color: C.danger, size: 22),
            SizedBox(width: 8),
            Text(
              '直链解析失败',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '暂时无法解析出下载直链（可能是网盘临时限制或网络抖动）。\n\n'
              '你可以用浏览器打开原链接，在网页里手动下载。',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            if (originUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: C.brand.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  originUrl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: C.brand),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('重试'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.open_in_browser_rounded, size: 17),
            label: const Text('浏览器下载'),
          ),
        ],
      ),
    );
    if (go == true && originUrl.isNotEmpty) {
      JumpUtil.openUrl(originUrl);
    } else if (go == false) {
      // 用户选「重试」
      addDownload(appInfo?.fileName ?? '未知文件名');
    }
  }

  /// 下载完成：弹窗确认是否安装
  bool _askedInstall = false;
  Future<void> _onDownloadComplete() async {
    if (_askedInstall) return;
    _askedInstall = true;
    await Future.delayed(const Duration(milliseconds: 400));
    final ctx = Get.context;
    if (ctx == null) return;
    final name = appInfo?.fileName ?? '安装包';
    final go = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 22),
            SizedBox(width: 8),
            Text(
              '下载完成',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          '$name 已下载完成，是否立即安装？',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('立即安装'),
          ),
        ],
      ),
    );
    _askedInstall = false;
    if (go == true) {
      await openDownloadFile();
    }
  }

  Future<void> getTaskInfo() async {
    String? taskIdTemp = await downloadTaskDao.queryDownloadTaskByAppId(appId);
    taskId = taskIdTemp;
    downloadTask = null;
    if (taskId != null && taskId!.isNotEmpty) {
      List<DownloadTask>? tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task WHERE task_id='$taskId'",
      );
      if (tasks != null && tasks.isNotEmpty) {
        downloadTask = tasks.first;
      }
    }
    // ★ 兜底：DB 记录失效（被清理/写入失败）时，按文件名在全部任务里找，
    //   避免「下载已开始但底部不显示进度条」
    if (downloadTask == null) {
      final name = appInfo?.fileName;
      if (name != null && name.isNotEmpty) {
        try {
          final all = await FlutterDownloader.loadTasks();
          if (all != null) {
            final key = name.replaceAll(' ', '_');
            for (final t in all.reversed) {
              final fn = t.filename ?? '';
              if (fn.startsWith(key) || fn.contains(key)) {
                downloadTask = t;
                taskId = t.taskId;
                break;
              }
            }
          }
        } catch (e) {
          logger.e(e.toString());
        }
      }
    }
    update(['download']);
  }

  /// 添加下载（双来源统一入口）
  ///
  /// ★ 需求 #2：直链解析失败时，不只是 Toast 提示，
  ///   要弹窗让用户选择「用浏览器打开原链接下载」。
  Future<void> addDownload(String fileName, [String? lzyUrl]) async {
    // v52 #3：解析阶段显示加载浮层，任务创建成功/失败后关闭
    ResolveOverlay.show(stage: ResolveStages.resolving);
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 解析真实下载地址
    String? parseUrl;
    String originUrl = '';
    if (item != null && item!.canDirectDownload) {
      parseUrl = item!.file; // 服务器直传：无需解析
    } else {
      final target = (lzyUrl != null && lzyUrl.isNotEmpty)
          ? lzyUrl
          : (item?.url ?? dowUrl);
      originUrl = target;
      if (target.isEmpty) {
        ResolveOverlay.dismiss();
        ToastUtil.error('下载地址为空');
        return;
      }
      // 解析真实直链（先自建 API，再后端解析）
      // ★ 重试一次：解析偶发失败多半是临时网络抖动
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          parseUrl = await service.resolveLzy(target);
        } catch (e) {
          logger.e(e.toString());
        }
        if (parseUrl != null && parseUrl.isNotEmpty) break;
        if (attempt == 0) {
          ResolveOverlay.stage(ResolveStages.retrying);
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
      // ★ 解析失败不再「用原链接硬下」（会下到 0 字节网页文件），
      //   改为弹窗让用户选择用浏览器打开原链接（需求 #2）
      if (parseUrl == null || parseUrl.isEmpty) {
        ResolveOverlay.dismiss();
        await _showParseFailedDialog(originUrl);
        return;
      }
    }

    if (parseUrl.isEmpty) {
      ResolveOverlay.dismiss();
      ToastUtil.error('下载地址无效');
      return;
    }

    fileName = fileName.trim().replaceAll(' ', '_');
    if (!fileName.contains('.')) fileName = '$fileName.apk';
    if (fileName.endsWith('.apk')) {
      fileName = fileName.substring(0, fileName.length - 4);
      fileName += '_${DateTime.now().millisecondsSinceEpoch}.apk';
    }

    final newTaskId = await FlutterDownloader.enqueue(
      url: parseUrl,
      fileName: fileName,
      savedDir: '/storage/emulated/0/Download',
      showNotification: true,
      saveInPublicStorage: true,
      openFileFromNotification: true,
    );
    if (newTaskId == null) {
      ResolveOverlay.dismiss();
      ToastUtil.error('下载失败，请稍后重试');
      return;
    }
    // ★ 下载真正开始 → 自动取消加载动画
    ResolveOverlay.stage(ResolveStages.starting);
    ResolveOverlay.dismiss();
    // v52f #3：上报「下载软件」操作日志（服务端不感知客户端下载）
    UserService.instance.downloadLog(
      appInfo?.fileName ?? fileName.replaceAll(RegExp(r'_\d+\.apk$'), ''),
    );
    // 记录任务（失败也不能中断后续流程，否则进度条不会出现）
    try {
      await downloadTaskDao.setDownloadTask(
        taskId: newTaskId,
        appId: appId,
        appIcon: appInfo?.fileIcon ?? '',
        appName: appInfo?.fileName ?? fileName,
        appSize: appInfo?.fileSize ?? '',
      );
    } catch (e) {
      logger.e('保存下载记录失败: $e');
    }
    _askedInstall = false;
    await getTaskInfo();
    // 轮询进度（FlutterDownloader 回调在部分机型不稳定）
    _startProgressPolling();
  }

  /// 轮询下载进度（保证进度条实时更新）
  void _startProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 700), (
      t,
    ) async {
      // 交给 getTaskInfo 处理（内含 DB + 文件名兜底），它同时负责 update
      await getTaskInfo();
      final t0 = downloadTask;
      if (t0 == null) {
        // 一条任务都没找到，停止轮询
        t.cancel();
        return;
      }
      if (t0.status == DownloadTaskStatus.complete) {
        t.cancel();
        _onDownloadComplete();
      }
      if (t0.status == DownloadTaskStatus.canceled ||
          t0.status == DownloadTaskStatus.failed) {
        t.cancel();
      }
    });
  }

  Future<void> pauseDownload() async {
    if (taskId == null || taskId!.isEmpty) {
      ToastUtil.error('下载任务ID无效');
      return;
    }
    await FlutterDownloader.pause(taskId: taskId!);
    update(['download']);
  }

  Future<void> resumeDownload() async {
    if (taskId == null || taskId!.isEmpty) {
      ToastUtil.error('下载任务ID无效');
      return;
    }
    String? taskIdTemp = await FlutterDownloader.resume(taskId: taskId!);
    if (taskIdTemp == null) {
      ToastUtil.error('恢复下载失败');
      return;
    }
    taskId = taskIdTemp;
    update(['download']);
  }

  Future<void> retryDownload() async {
    if (taskId == null || taskId!.isEmpty) {
      ToastUtil.error('下载任务ID无效');
      return;
    }
    String? taskIdTemp = await FlutterDownloader.retry(taskId: taskId!);
    if (taskIdTemp == null) {
      ToastUtil.error('重试下载失败');
      return;
    }
    taskId = taskIdTemp;
    update(['download']);
  }

  Future<void> cancelDownload() async {
    if (taskId == null || taskId!.isEmpty) {
      ToastUtil.error('下载任务ID无效');
      return;
    }
    await FlutterDownloader.remove(taskId: taskId!, shouldDeleteContent: true);
    downloadTaskDao.deleteDownloadTask(appId);
    taskId = null;
    downloadTask = null;
    update(['download']);
  }

  /// 安装已下载的软件（原生安装器 + 多级兜底）
  Future<void> openDownloadFile() async {
    if (taskId == null || taskId!.isEmpty) {
      ToastUtil.error('下载任务ID无效');
      return;
    }

    // 1) 检查「安装未知应用」权限
    if (Platform.isAndroid) {
      final ok = await ApkInstaller.canInstall();
      if (!ok) {
        final go = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('需要安装权限'),
            content: const Text('安装应用需要您允许「安装未知应用」权限，前往设置开启？'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('去设置'),
              ),
            ],
          ),
        );
        if (go == true) {
          await ApkInstaller.openInstallSettings();
          ToastUtil.info('开启权限后请重新点击安装');
        }
        return;
      }
    }

    // 2) 找安装包本地路径
    final path = await _findApkPath();
    if (path == null) {
      ToastUtil.error('未找到安装包，请在下载管理中查看');
      return;
    }

    // 3) 调用原生安装器
    final ok = await ApkInstaller.install(path);
    if (ok) return;

    // 4) 兜底：open_filex
    try {
      await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      return;
    } catch (_) {}

    ToastUtil.error('无法调起安装，请到文件管理器手动安装');
  }

  /// 查找已下载 APK 的本地路径
  Future<String?> _findApkPath() async {
    try {
      // 优先用 FlutterDownloader 的任务记录
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
    } catch (e) {
      logger.e('find apk path failed: $e');
    }
    // 兜底：扫描公共下载目录
    for (final dir in [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Android/data/com.soft.anyi/files',
    ]) {
      try {
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        final apks = d
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.apk'))
            .toList();
        if (apks.isEmpty) continue;
        apks.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
        );
        return apks.first.path;
      } catch (_) {}
    }
    return null;
  }

  /// 分享：会员资源不允许分享下载链接（防止绕过会员校验）
  void showSharePopUps(BuildContext context) {
    if (item?.isVipItem == true) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('会员专享资源'),
          content: const Text('该资源为会员专享，不支持分享下载链接。\n如需分享，请在广场发帖推荐。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('我知道了'),
            ),
          ],
        ),
      );
      return;
    }
    // 分享出去的是「详情页地址」而不是下载直链，避免直链被直接拿走
    showDialog(
      context: context,
      builder: (_) => PostersWidget(
        appInfo: appInfo,
        dowUrl: shareUrl,
        qrData: _sharePageUrl(),
      ),
    );
  }

  /// 分享页地址（指向站点详情页，非下载直链）
  String _sharePageUrl() {
    if (item == null) return ApiHost.base;
    return ApiHost.appPage(item!.id);
  }

  /// 对外分享/下载的地址
  String get shareUrl => _shareUrl();

  /// 分享出去的地址：服务器直传用直链，蓝奏云用原分享页
  String _shareUrl() {
    if (item != null && item!.canDirectDownload) return item!.file;
    return item?.url.isNotEmpty == true ? item!.url : dowUrl;
  }

  void showPreviewImage(String imageUrl) {
    showDialog(
      context: Get.context!,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: Get.back,
          child: Center(
            child: PhotoView(
              backgroundDecoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
              ),
              imageProvider: NetworkImage(imageUrl),
            ),
          ),
        );
      },
    );
  }
}
