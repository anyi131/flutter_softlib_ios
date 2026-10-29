import 'dart:async';

import '../../utils/safe_ctx.dart';
import '../../utils/net_guard.dart';
import '../../utils/sound_util.dart';

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'resolve_overlay.dart';

import 'package:flutter/services.dart';
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
import '../../design/glass.dart';
import '../../models/app_item.dart';
import '../../routes/app_pages.dart';
import '../../models/http/results/lzy_file_info_model.dart';
import '../../api/api_host.dart';
import '../../utils/app_action.dart';
import '../../api/soft_service.dart';
import '../../api/user_service.dart';
import '../../utils/apk_installer.dart';
import '../../utils/download_dir.dart';
import '../../utils/lzy_local_parser.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';
import '../../widgets/posters/posters_widget.dart';
import '../../design/kit.dart';
import '../../utils/disk_space.dart';

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

  /// ★ 需求1（防乱闪）状态去抖：
  ///   记录上一次真正渲染到 UI 的快照，只有快照真正变化才 update(['download'])；
  ///   「有任务 → 查不到任务」需要连续两次确认（DB 写入延迟时文件名兜底会抖动）。
  String? _renderedTaskId;
  int _renderedStatus = -1;
  int _renderedProgress = -1;

  /// ★ 需求1：刚点过下载的宽限窗口（3 秒内 UI 保持进度条初始态，
  ///   防止任务记录尚未落库时按钮闪回「下载」态）
  DateTime? _lastDownloadTap;

  /// ★ 1012b 状态机加固：
  ///   _uiPhase 是 UI 唯一真相源（idle=按钮 / downloading=进度条 / done=安装）。
  ///   一旦进入 downloading/done，除非任务取消/失败或用户显式取消/重开下载，
  ///   绝不回退成按钮；进度显示层单调不减（max(prev, cur)），杜绝回退抖动。
  static const String phaseIdle = 'idle';
  static const String phaseDownloading = 'downloading';
  static const String phaseDone = 'done';
  String _uiPhase = phaseIdle;
  int _shownProgress = 0;
  bool _explicitReset = false;

  String get downloadUiPhase => _uiPhase;

  /// 显示层进度：与真实任务进度取 max，保证单调不减
  int get uiProgress {
    final t = downloadTask;
    if (t != null && t.status != DownloadTaskStatus.failed) {
      return _shownProgress > t.progress ? _shownProgress : t.progress;
    }
    return _shownProgress;
  }

  bool get pendingDownloadUi {
    final t = _lastDownloadTap;
    if (t == null) return false;
    if (_uiPhase != phaseIdle) return false;
    if (downloadTask != null) return false;
    return DateTime.now().difference(t).inMilliseconds < 3000;
  }

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
    // ★ 1012b：进入页面时若已有进行中任务，由 getTaskInfo 内部自动恢复轮询
    //   （原 500ms 定时读 downloadTask 存在竞态：getTaskInfo 尚未完成时为 null，
    //    导致重进页面不恢复进度轮询）
    IsolateNameServer.removePortNameMapping('app_details_downloader_send_port');
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      'app_details_downloader_send_port',
    );
    port.listen((dynamic data) {
      if (data is List && data.length >= 3) {
        final id = data[0]?.toString() ?? '';
        final status = data[1] is int ? data[1] as int : 0;
        final prog = data[2] is int ? data[2] as int : 0;
        // ★ v331n：只处理当前页面任务的事件——其他软件/旧任务的事件
        //   会让本页误弹「下载完成」并打乱进度状态机。
        if (taskId == null || taskId!.isEmpty) {
          getTaskInfo();
          return;
        }
        if (id.isNotEmpty && id != taskId) return;
        // ★ v331r：回调自带 progress——先实时刷新显示（不等 DB 查询），
        //   彻底解决进度条滞后/不实时
        if (status == 2 /* running */ && prog > _shownProgress) {
          _shownProgress = prog;
          _uiPhase = phaseDownloading;
          update(['download']);
        }
        getTaskInfo();
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
  /// 路由参数变化后原地重新加载（同一个控制器实例内）
  ///
  /// ★★ 1020：GetX 在「详情页 → 详情页」时会复用路由与控制器，
  ///   onInit 不会重跑，item 还是上一个软件的。
  ///   页面在 build 时比对 appId，不一致就调这里重置状态。
  Future<void> reloadWith(Map args) async {
    final rawId = int.tryParse('${args['appId'] ?? 0}') ?? 0;
    final it = args['item'];

    // 清掉上一个软件的所有状态
    item = null;
    appIdInt = 0;
    dowUrl = '';
    appInfo = null;
    isLoadingInfo = true;
    msgError = null;
    _silentRetry = 0;
    _shownProgress = 0;
    _uiPhase = phaseIdle;
    _taskKey = '';

    // 写入新参数
    if (it is AppItem) {
      item = it;
      appIdInt = it.id;
      dowUrl = it.url;
      _taskKey = it.url.isNotEmpty
          ? 'u_${it.url.hashCode.abs()}'
          : (it.id > 0 ? 'i_${it.id}' : 'n_${it.title.hashCode.abs()}');
    }
    if (rawId > 0) appIdInt = rawId;
    final rawUrl = args['dowUrl'];
    if (rawUrl != null && '$rawUrl'.isNotEmpty && dowUrl.isEmpty) {
      dowUrl = '$rawUrl';
    }
    if (_taskKey.isEmpty && dowUrl.isNotEmpty) {
      _taskKey = 'u_${dowUrl.hashCode.abs()}';
    }

    update(['appInfo', 'share', 'download', 'review']);
    if (appIdInt > 0) service.addAppView(appIdInt);
    await getAppInfo();
    await getTaskInfo();
  }

  Future<void> getAppInfo() async {
    isLoadingInfo = true;
    update(['appInfo', 'share', 'download']);

    // ★★ 1020 修复「详情页永远卡骨架屏」：
    //   有些入口只传 appId、不传 item（收藏页、首页兜底列表）。
    //   原来 item==null && dowUrl 为空时直接 return，
    //   isLoadingInfo 永远为 true → 骨架屏转不停，页面打不开。
    //   现在：没有 item 但有 appId → 先按 id 拉一次详情再走后续流程。
    // ★★ 1020：以 args 里的 appId 为准。
    //   即使 item 不为空，只要 id 和 appId 对不上（控制器复用、路由缓存、
    //   列表项与点击项错位等情况），一律按 appId 重新拉取，
    //   避免「点了 A 却显示 B」。
    final idMismatch = item != null && appIdInt > 0 && item!.id != appIdInt;
    if (idMismatch) {
      item = null;
      dowUrl = '';
      _taskKey = '';
    }
    if ((item == null || idMismatch) && appIdInt > 0) {
      try {
        final fetched = await service.fetchAppDetail(id: appIdInt);
        if (fetched != null) {
          item = fetched;
          if (dowUrl.isEmpty) dowUrl = fetched.url;
          if (_taskKey.isEmpty) {
            _taskKey = fetched.url.isNotEmpty
                ? 'u_${fetched.url.hashCode.abs()}'
                : 'i_${fetched.id}';
          }
        }
      } catch (e) {
        logger.e('[detail] fetch by id failed: $e');
      }
      if (item == null) {
        // 拉不到也要结束 loading，并给明确提示，不能一直转圈
        isLoadingInfo = false;
        msgError ??= '软件信息加载失败，请返回重试';
        update(['appInfo', 'share', 'download']);
        return;
      }
    }

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
    if (!needFetch) {
      // ★ 1020：即使不补全，也必须结束骨架屏，否则页面永远是骨架
      isLoadingInfo = false;
      update(['appInfo', 'share', 'download']);
      return;
    }

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
  /// ★ 1020（待办 #3）：同类替代推荐
  ///   软件失效/解析失败时，不要让用户直接走 —— 给 3 个同分类的可用软件。
  ///   排序：下载量优先（别人用得多的更可能可用）
  Future<List<AppItem>> _similarApps({int limit = 3}) async {
    try {
      final cat = item?.catId ?? 0;
      List<AppItem> pool = const [];
      if (cat > 0) {
        pool = await service.fetchApps(catId: cat);
      }
      if (pool.isEmpty) {
        pool = await service.fetchApps();
      }
      final me = item?.id ?? 0;
      final list =
          pool
              .where(
                (e) => e.id != me && e.icon.isNotEmpty && e.title.isNotEmpty,
              )
              .toList()
            ..sort((a, b) => b.downCount.compareTo(a.downCount));
      return list.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _showParseFailedDialog(String originUrl) async {
    final ctx = Get.context;
    if (ctx == null) {
      ToastUtil.error('直链解析失败，请稍后重试');
      return;
    }
    // 先取同类替代（失败也不影响弹窗本身）
    final alternatives = await _similarApps();
    if (!ctx.mounted) return;
    final go = await showDialog<bool>(
      context: ctx,
      builder: (c) => AppDialog(
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
            if (SoftService.lastParseError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '失败原因：${SoftService.lastParseError}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: C.danger,
                ),
              ),
            ],
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
            // ★ 1020（待办 #3）：同类替代 —— 别让用户空手离开
            if (alternatives.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 15, color: C.mint),
                  const SizedBox(width: 5),
                  const Text(
                    '试试这些同类软件',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...alternatives.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pop(c, null);
                      Get.offAndToNamed(
                        Routes.appDetails,
                        arguments: {'appId': a.id.toString(), 'item': a},
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: C.mint.withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.mint.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                                       memCacheWidth: 96,
                              imageUrl: a.icon,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 32,
                                height: 32,
                                color: C.mint.withAlpha(30),
                                child: const Icon(
                                  Icons.android,
                                  size: 16,
                                  color: C.mint,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  a.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (a.size.isNotEmpty)
                                  Text(
                                    a.size,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
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
      // ★ 1014：此处是「解析失败后的浏览器兜底」，属于用户已通过校验
      //   后的降级路径，显式允许直链。
      JumpUtil.openUrl(originUrl, allowDownload: true);
    } else if (go == false) {
      // 用户选「重试」——★ 1016：令牌现在只在「真正发起下载」时消费，
      //   解析失败时并未消耗，所以这里**不能清零**（清零必然触发
      //   「该资源尚未通过服务端校验」）。
      addDownload(appInfo?.fileName ?? '未知文件名');
    }
  }

  /// 下载完成：弹窗确认是否安装
  /// ★ 1016：把 "34.1 M" / "512K" / "1.2GB" 正确转成字节
  /// （旧代码只按 MB 换算，"512K" 会被当成 512MB）
  int _sizeToBytes(String raw) {
    final t = raw.trim().toUpperCase().replaceAll(' ', '');
    if (t.isEmpty) return 0;
    final m = RegExp(r'^([0-9.]+)([KMGT]?)B?$').firstMatch(t);
    if (m == null) return 0;
    final n = double.tryParse(m.group(1) ?? '') ?? 0;
    const k = 1024;
    switch (m.group(2) ?? '') {
      case 'K':
        return (n * k).round();
      case 'M':
        return (n * k * k).round();
      case 'G':
        return (n * k * k * k).round();
      case 'T':
        return (n * k * k * k * k).round();
      default:
        return n.round();
    }
  }

  bool _askedInstall = false;
  Future<void> _onDownloadComplete() async {
    if (_askedInstall) return;
    // ★ v331s：完成校验以「文件实际大小」为准——下载器偶发把断流判为
    //   complete（上一版用 _shownProgress 判断会误伤正常完成：显示层
    //   滞后于真实进度）。文件大小 ≥ 期望大小的 90% 视为真完成；
    //   大小不可得时信任下载器（progress 由回调实时驱动，已修）。
    // ★ 1016：下载完整性校验（重写，避免误判）
    //   旧逻辑问题：
    //     ① 期望大小取自「采集时记录」的 fileSize —— 蓝奏云文件更新后会不一致；
    //     ② 文件名对不上 / appInfo 为空 → 直接跳过校验（等于没校验）；
    //     ③ 单位只按 MB，像 "512K" 会被当成 512MB。
    //   新逻辑：优先用服务端**最新**文件大小；再退到本地记录；
    //          实际文件按「下载目录里最新修改的 apk」兜底找；容忍 15% 差异。
    var fileOk = true;
    try {
      String dir = downloadTask?.savedDir ?? '';
      if (dir.isEmpty) dir = await DownloadDir.path();
      final fn = downloadTask?.filename ?? (appInfo?.fileName ?? '');

      File? f;
      if (dir.isNotEmpty && fn.isNotEmpty) {
        final t = File('$dir/$fn');
        if (t.existsSync()) f = t;
      }
      // 兜底：下载目录里 5 分钟内更新的 apk
      if (f == null) {
        final dirs = await DownloadDir.fallbackDirs();
        File? newest;
        for (final d in dirs) {
          final dd = Directory(d);
          if (!dd.existsSync()) continue;
          for (final e in dd.listSync()) {
            if (e is! File || !e.path.toLowerCase().endsWith('.apk')) continue;
            if (newest == null ||
                e.statSync().modified.isAfter(newest.statSync().modified)) {
              newest = e;
            }
          }
        }
        if (newest != null &&
            DateTime.now().difference(newest.statSync().modified).inMinutes <=
                5) {
          f = newest;
        }
      }

      if (f != null) {
        final actual = f.lengthSync();
        int expectBytes = 0;
        // ① 先问服务端最新大小（蓝奏云文件可能已更新）
        try {
          final fresh = await SoftService.instance.lzyFileInfo(dowUrl);
          expectBytes = _sizeToBytes('${fresh?['size'] ?? ''}');
        } catch (_) {}
        // ② 退到本地记录的 fileSize
        if (expectBytes <= 0) {
          expectBytes = _sizeToBytes(appInfo?.fileSize ?? '');
        }
        if (actual < 1024) {
          fileOk = false;
        } else if (expectBytes > 0 && actual < expectBytes * 0.85) {
          fileOk = false;
        }
      }
    } catch (e) {
      logger.e('[download] 校验异常(放行): $e');
    }
    if (!fileOk) {
      _askedInstall = false;
      _uiPhase = phaseIdle;
      _shownProgress = 0;
      _explicitReset = true;
      update(['download']);
      ToastUtil.error('下载不完整（网络波动），请重新下载');
      // ★ 1016：上报失败（后台「下载记录」可查）
      SoftService.instance.reportDownloadResult(
        appId: appIdInt,
        title: (item?.title ?? '').isNotEmpty
            ? item!.title
            : (appInfo?.fileName ?? ''),
        url: dowUrl,
        ok: false,
        error: '下载不完整：文件大小未达到预期（网络中断或源站限速）',
      );
      return;
    }
    _askedInstall = true;
    SoundUtil.playDownload(); // ★ 音效：下载完成
    // ★ 1016：上报成功（后台「下载记录」可查）
    SoftService.instance.reportDownloadResult(
      appId: appIdInt,
      title: (item?.title ?? '').isNotEmpty
          ? item!.title
          : (appInfo?.fileName ?? ''),
      url: dowUrl,
      ok: true,
    );
    await Future.delayed(const Duration(milliseconds: 400));
    final ctx = Get.context;
    if (ctx == null) return;
    final name = appInfo?.fileName ?? '安装包';
    final go = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AppDialog(
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
                // ★ 需求1：兜底命中后把 taskId 写回 downloadTaskDao，
                //   下次轮询直查 DB，不再走「文件名兜底」抖动路径
                try {
                  await downloadTaskDao.setDownloadTask(
                    taskId: t.taskId,
                    appId: appId,
                    appName: appInfo?.fileName ?? (t.filename ?? ''),
                    appSize: appInfo?.fileSize ?? '',
                    appIcon: appInfo?.fileIcon ?? '',
                  );
                } catch (e) {
                  logger.e('回写下载任务记录失败: $e');
                }
                break;
              }
            }
          }
        } catch (e) {
          logger.e(e.toString());
        }
      }
    }
    // ★ 1012b 状态机：以 phase 为 UI 唯一真相源
    //   · complete → done（稳定显示安装态，不再闪回）
    //   · canceled/failed → idle（允许回按钮/重试）
    //   · 其余 → downloading；任务对象瞬时查不到时粘滞在当前 phase，
    //     绝不因 DB 写入延迟/查询抖动回退成按钮
    final t = downloadTask;
    var phase = _uiPhase;
    if (t != null) {
      switch (t.status) {
        case DownloadTaskStatus.complete:
          phase = phaseDone;
          break;
        case DownloadTaskStatus.failed:
        case DownloadTaskStatus.canceled:
          phase = phaseIdle;
          break;
        default:
          phase = phaseDownloading;
      }
    } else if (!_explicitReset &&
        (_uiPhase == phaseDownloading || _uiPhase == phaseDone)) {
      // 无任务但未显式取消/重开：粘滞保持当前态（进度条/安装态）
      phase = _uiPhase;
    }
    if (t != null && t.status != DownloadTaskStatus.failed) {
      // 进度单调不减（显示层）
      if (t.progress > _shownProgress) _shownProgress = t.progress;
    }
    if (phase == phaseDone) _shownProgress = 100;

    final newId = t?.taskId;
    final changed =
        newId != _renderedTaskId ||
        phase != _uiPhase ||
        _shownProgress != _renderedProgress;
    if (!changed && _renderedTaskId != null) {
      // 快照未变也要确保轮询活着（onInit 恢复路径）
      _ensurePolling(phase);
      return;
    }
    _renderedTaskId = newId;
    _renderedStatus = t?.status.index ?? -1;
    _renderedProgress = _shownProgress;
    _uiPhase = phase;
    _ensurePolling(phase);
    update(['download']);
  }

  /// ★ 1012b：download/downloading 态必须持续轮询（含 onInit 重进页面恢复），
  ///   替代原先依赖 500ms 定时器读 downloadTask 的竞态写法
  void _ensurePolling(String phase) {
    if (phase != phaseDownloading) return;
    final active = _progressTimer != null && _progressTimer!.isActive;
    if (!active) _startProgressPolling();
  }

  /// 添加下载（双来源统一入口）
  ///
  /// ★ 需求 #2：直链解析失败时，不只是 Toast 提示，
  ///   要弹窗让用户选择「用浏览器打开原链接下载」。
  /// ★ 1014 安全：一次性放行令牌。
  /// 只有 app_details_page._onDownload 完成服务端校验后才会置 true；
  /// 消费一次立即失效（用完即清），避免跨页面/跨软件残留导致跳过校验。
  bool _unlockToken = false;

  /// 设置放行令牌（仅鉴权通过后调用）
  set unlockVerified(bool v) => _unlockToken = v;
  bool get unlockVerified => _unlockToken;

  Future<void> addDownload(String fileName, [String? lzyUrl]) async {
    // ★ 1014 安全兜底（全量强制鉴权）：无论免费还是付费，
    //   未经服务端校验一律不允许发起下载。
    if (!_unlockToken) {
      ResolveOverlay.dismiss();
      ToastUtil.error('该资源尚未通过服务端校验，已停止下载');
      return;
    }
    // ★ 1016：流量提醒 —— 移动网络下载大安装包前先确认
    try {
      final expect =
          double.tryParse(
            (appInfo?.fileSize ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          0;
      final msg = await NetGuard.confirmMessage((expect * 1024 * 1024).round());
      if (msg != null) {
        final ctx0 = Get.context;
        if (ctx0 != null) {
          final ok = await showDialog<bool>(
            context: ctx0,
            builder: (c) => AppDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '流量提醒',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              content: Text(
                msg,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('继续下载'),
                ),
              ],
            ),
          );
          if (ok != true) {
            _unlockToken = true; // 取消后保留令牌，用户可再点
            return;
          }
          NetGuard.allowMobileThisSession = true;
        }
      }
    } catch (_) {}

    // ★ 1029：下载前先看真实剩余空间 —— 原来没有这一步，空间不够也照样入队，
    //   白白重试 3 次再报「CDN 中断」，用户完全不知道是存储满了。
    try {
      final freeMb = await DiskSpace.freeMb();
      final needMb = _fileSizeMb();
      if (freeMb > 0 && needMb > 0 && freeMb < needMb + 50) {
        ToastUtil.error('存储空间不足：剩余 $freeMb MB，安装包 $needMb MB，请清理后再试');
        _unlockToken = true;
        return;
      }
    } catch (_) {}
    // ★★ 1016：令牌**不再一进来就消费** —— 原来先置 false，一旦解析失败
    //   （蓝奏云文件被取消分享等），用户点「重试」就会被判「尚未通过服务端校验」。
    //   改为「真正要发起下载任务前」再消费（见下方 enqueue 之前），
    //   既保持一次性、杜绝复用，又不影响失败重试。
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
      SoftService.lastParseChannel = 'direct';
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
      // ★ 1016：记录解析总耗时（后台「解析记录」显示）
      final _parseSw = Stopwatch()..start();

      // ═══ 三级降级：① 本地解析 → ② 外置接口 → ③ 原链接浏览器 ═══
      //   本地解析只用于**免费资源**：客户端算法可被反编译，
      //   付费/会员资源必须走服务端票据，否则付费墙失效。
      final isFree = item == null || (!item!.isVipItem && !item!.hasPrice);
      if (isFree && LzyLocalParser.isLzyUrl(target)) {
        ResolveOverlay.stage('本地解析中…');
        try {
          SoftService.lastParseChannel = '';
          parseUrl = await LzyLocalParser.parse(target);
          if (parseUrl != null && parseUrl.isNotEmpty) {
            SoftService.lastParseChannel = 'local';
          }
        } catch (e) {
          logger.e('[local-parse] $e');
        }
        if (parseUrl != null && parseUrl.isNotEmpty) {
          ResolveOverlay.dismiss();
          SoftService.reportParseResult(
            appId: appIdInt,
            title: (item?.title ?? '').isNotEmpty
                ? item!.title
                : (appInfo?.fileName ?? ''),
            rawUrl: target,
            ok: true,
            reqParams: 'url=$target',
            respSnippet: '本地解析成功',
            channel: 'local',
            costMs: _parseSw.elapsedMilliseconds,
          );
        } else {
          // 本地失败 → 记录原因，继续走外置接口
          final why = LzyLocalParser.lastError.isEmpty
              ? '本地解析无返回'
              : LzyLocalParser.lastError;
          SoftService.lastParseError = why;
          // ★ 1016：把本地解析的失败原因上报（后台可查，不用再猜）
          SoftService.reportParseResult(
            appId: appIdInt,
            title: (item?.title ?? '').isNotEmpty
                ? item!.title
                : (appInfo?.fileName ?? ''),
            rawUrl: target,
            ok: false,
            error: '[本地解析失败] $why',
            reqParams: 'url=$target',
            respSnippet: LzyLocalParser.lastError,
            channel: 'local',
            costMs: _parseSw.elapsedMilliseconds,
          );
          ResolveOverlay.stage('切换到备用解析…');
        }
      }

      // ② 外置/服务端解析（含票据、自建 API、后端兜底）
      // ★ 重试一次：解析偶发失败多半是临时网络抖动
      for (
        var attempt = 0;
        attempt < 2 && (parseUrl == null || parseUrl.isEmpty);
        attempt++
      ) {
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
        // ★ 1016：上报解析失败（后台「解析记录」可查原因与耗时）
        SoftService.reportParseResult(
          appId: appIdInt,
          title: (item?.title ?? '').isNotEmpty
              ? item!.title
              : (appInfo?.fileName ?? ''),
          rawUrl: originUrl,
          ok: false,
          error:
              '[解析失效] ${SoftService.lastParseError.isEmpty ? '解析接口无返回' : SoftService.lastParseError}',
          reqParams: 'url=$originUrl',
          respSnippet: SoftService.lastParseResp,
          channel: SoftService.lastParseChannel.isEmpty
              ? 'failed'
              : SoftService.lastParseChannel,
          costMs: _parseSw.elapsedMilliseconds,
        );
        await _showParseFailedDialog(originUrl);
        return;
      }
      // ★ 1016：解析成功也记一笔（便于对比成功率）
      SoftService.reportParseResult(
        appId: appIdInt,
        title: (item?.title ?? '').isNotEmpty
            ? item!.title
            : (appInfo?.fileName ?? ''),
        rawUrl: originUrl,
        ok: true,
        reqParams: 'url=$originUrl',
        respSnippet: SoftService.lastParseResp,
        channel: SoftService.lastParseChannel.isEmpty
            ? 'server'
            : SoftService.lastParseChannel,
        costMs: _parseSw.elapsedMilliseconds,
      );
    }

    if (parseUrl.isEmpty) {
      ResolveOverlay.dismiss();
      ToastUtil.error('下载地址无效');
      return;
    }

    // ★ 需求1：标记「刚点过下载」，3 秒内 UI 保持进度条初始态不闪回按钮
    _lastDownloadTap = DateTime.now();
    _renderedTaskId = null;
    _renderedStatus = -1;
    _renderedProgress = -1;
    // ★ 1012b：新开下载 → 进入 downloading 态，进度从 0 计
    _uiPhase = phaseDownloading;
    _shownProgress = 0;
    _explicitReset = false;
    update(['download']);

    fileName = fileName.trim().replaceAll(' ', '_');
    if (!fileName.contains('.')) fileName = '$fileName.apk';
    if (fileName.endsWith('.apk')) {
      fileName = fileName.substring(0, fileName.length - 4);
      fileName += '_${DateTime.now().millisecondsSinceEpoch}.apk';
    }

    // Android 11+ 写入公共目录「安逸软件汇」需要「所有文件访问」授权
    if (Platform.isAndroid) {
      try {
        final m = Permission.manageExternalStorage;
        if (!await m.isGranted) await m.request();
      } catch (_) {}
    }

    // ★ 一次性令牌：**在这里**消费（解析已成功，即将真正下载）
    if (!_unlockToken) {
      ResolveOverlay.dismiss();
      ToastUtil.error('该资源尚未通过服务端校验，已停止下载');
      return;
    }
    _unlockToken = false;
    final newTaskId = await FlutterDownloader.enqueue(
      url: parseUrl,
      fileName: fileName,
      savedDir: await DownloadDir.path(),
      showNotification: true,
      saveInPublicStorage: false,
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
    // ★ 1014：带上 appId，服务端按 id 精确校验付费权限
    UserService.instance.downloadLog(
      appInfo?.fileName ?? fileName.replaceAll(RegExp(r'_\d+\.apk$'), ''),
      appId: appIdInt,
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
      // 交给 getTaskInfo 处理（内含 DB + 文件名兜底 + update）
      await getTaskInfo();
      final t0 = downloadTask;
      if (t0 == null) {
        // ★ 1012b：任务瞬时查不到不停止轮询（状态机粘滞由 getTaskInfo 负责），
        //   避免查空一次后轮询停摆、进度条永远卡住
        return;
      }
      if (t0.status == DownloadTaskStatus.complete) {
        t.cancel();
        _onDownloadComplete();
      }
      if (t0.status == DownloadTaskStatus.canceled ||
          t0.status == DownloadTaskStatus.failed) {
        t.cancel();
        // ★ 1020（待办 #1）：失败先静默重连，不立刻报错
        //   用户取消（canceled）不重试 —— 那是主动行为
        if (t0.status == DownloadTaskStatus.failed && !_silentRetrying) {
          final recovered = await _trySilentRetry();
          if (recovered) return; // 已重新入队，轮询由新任务接管
        }
        // ★★ 1020：静默重试也失败后，给用户两条出路，别只剩一句「下载失败」
        //   （之前用户只能反复点，但用的是已过期的直链，永远失败）
        if (t0.status == DownloadTaskStatus.failed && !_shownFailDialog) {
          _shownFailDialog = true;
          _showDownloadFailedSheet();
        }
        // ★ 1016：上报失败（后台「下载记录」可查）
        SoftService.instance.reportDownloadResult(
          appId: appIdInt,
          title: (item?.title ?? '').isNotEmpty
              ? item!.title
              : (appInfo?.fileName ?? ''),
          url: dowUrl,
          ok: false,
          // ★ 1016：失败原因细分 —— 后台一眼能判断是「解析问题」还是「网络问题」
          errCode: () {
            if (t0.status == DownloadTaskStatus.canceled) {
              return _userCanceled ? 'USER_CANCEL' : 'SYS_CANCEL';
            }
            return 'DL_FAIL';
          }(),
          freeMb: await _freeSpaceMb(),
          fileMb: _fileSizeMb(),
          progress: _shownProgress,
          retryCnt: _silentRetry,
          error: () {
            if (t0.status == DownloadTaskStatus.canceled) {
              return _userCanceled
                  ? '[用户取消] 用户主动取消下载'
                  : '[系统中断] 下载被系统终止（存储不足/权限/省电策略）';
            }
            final u = dowUrl.toLowerCase();
            final isLzy =
                u.contains('lanzou') ||
                u.contains('lzy') ||
                u.contains('52yfx.cn/lzy');
            if (u.isEmpty) return '[解析失败] 下载地址为空（解析接口无返回）';
            if (isLzy) {
              return '[解析失效] 蓝奏云直链不可用（解析接口返回异常/链接过期）'
                  '\n解析来源：${u.length > 60 ? u.substring(0, 60) : u}';
            }
            // ★ 1027：lanosso CDN 域名单独归类（lanzou 已在 isLzy 前面分支处理）
            if (u.contains('lanosso.com')) {
              // ★ 1029：原来写「正在自动换线路重试」——根本没有换线路机制，
              //   用户以为软件在自救，实际是连不上就结束。改为如实描述。
              return '[下载线路] 蓝奏 CDN 连不上（常见于移动网络/运营商拦截）'
                  '\n建议：改用浏览器打开，或换 Wi-Fi 再试';
            }
            return '[网络异常] 连接中断或源站不可用'
                '\n地址：${u.length > 60 ? u.substring(0, 60) : u}';
          }(),
        );
      }
    });
  }

  bool _shownFailDialog = false;

  /// 下载失败后的可选操作（重新解析下载 / 浏览器打开）
  void _showDownloadFailedSheet() {
    final origin = dowUrl.isNotEmpty ? dowUrl : (item?.url ?? '');
    Get.dialog<void>(
      AppDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('下载没有完成', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '下载中断了，通常是网络波动或源站限速。\n你可以重新获取地址再下一遍，或者直接用浏览器下载。',
              style: TextStyle(fontSize: 13, height: 1.75),
            ),
            if (origin.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                origin,
                style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('稍后')),
          if (origin.isNotEmpty)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: origin));
                ToastUtil.success('链接已复制');
              },
              child: const Text('复制链接'),
            ),
          if (origin.isNotEmpty)
            TextButton(
              onPressed: () {
                Get.back();
                JumpUtil.openUrl(origin);
              },
              child: const Text('浏览器打开'),
            ),
          FilledButton(
            onPressed: () async {
              Get.back();
              _shownFailDialog = false;
              _silentRetry = 0; // 允许新一轮静默重试
              await retryDownload();
            },
            child: const Text('重新下载'),
          ),
        ],
      ),
    );
  }

  // ═══════════════ 静默重试（用户待办 #1）═══════════════
  //
  // 背景：下载失败/被源站中断时，原来直接进 failed 态，用户得手动点重试，
  //       而且 retryDownload 会**把进度清零** —— 下了 20MB 再从头开始。
  //
  // 现在：失败后在后台自动重试 3 次（3s / 8s / 20s），每次换解析通道重新取直链；
  //       重试期间界面显示「正在重连(第 n 次)」，进度条保持不动、不归零；
  //       三次全败才真正进 failed 态并提示用户。
  int _silentRetry = 0;
  Timer? _silentRetryTimer;
  bool _silentRetrying = false;

  /// 是否正在静默重试（UI 用来显示「正在重连」而不是「失败」）
  bool get silentRetrying => _silentRetrying;

  /// 重试间隔：第 1/2/3 次
  static const List<int> _retryDelays = [3, 8, 20];

  /// 下载失败时的入口：先尝试静默重连，全败才交给上层显示失败
  Future<bool> _trySilentRetry() async {
    // ★ 1020：后台可关闭「下载静默重试」
    if (SoftService.instance.cachedConfig?.uiConfig.featureSilentRetry ==
        false) {
      return false;
    }
    if (_silentRetry >= _retryDelays.length) return false;
    final delay = _retryDelays[_silentRetry];
    _silentRetry++;
    _silentRetrying = true;
    update(['download']);
    _silentRetryTimer?.cancel();
    final done = Completer<bool>();
    _silentRetryTimer = Timer(Duration(seconds: delay), () async {
      try {
        // ★ 1027（真机实测）：首次失败大多是「CDN 瞬时拒连」（直链 30 分钟有效期内）        //   先用原直链重连（换新 TCP 连接），只有直链签发超 20 分钟才重新解析。
        //   之前每次重试都 resolveLzy，反而撞上蓝奏云上游抖动，白白浪费重试机会。
        var ok = false;
        int signedAt = 0;
        try {
          final m = RegExp(r'/([0-9a-f]{8})/').firstMatch(dowUrl);
          if (m != null) {
            final h = int.tryParse(m.group(1)!, radix: 16);
            if (h != null && h > 1000000000 && h < 2000000000) signedAt = h;
          }
        } catch (_) {}
        final freshLink = signedAt > 0 &&
            DateTime.now().millisecondsSinceEpoch ~/ 1000 - signedAt < 1200;
        if (freshLink && dowUrl.isNotEmpty) {
          // 直链还年轻 → 直接复用重连
          ok = await _enqueueSilentRetry(dowUrl);
        }
        if (!ok) {
          // 直链已老 / 复用失败 → 重新解析换新链
          try {
            final t = item?.url ?? dowUrl;
            if (t.isNotEmpty) {
              final fresh = await service.resolveLzy(t);
              if (fresh != null && fresh.isNotEmpty) {
                ok = await _enqueueSilentRetry(fresh);
              }
            }
          } catch (_) {}
        }
        // 换通道失败 → 试试原任务 retry（部分情况是网络瞬断，原链接仍可用）
        if (!ok && taskId != null && taskId!.isNotEmpty) {
          final nt = await FlutterDownloader.retry(taskId: taskId!);
          if (nt != null && nt.isNotEmpty) {
            taskId = nt;
            ok = true;
          }
        }
        if (ok) {
          _silentRetrying = false;
          // ★ 不重置 _shownProgress：进度条保持不动，用户感知是「接着下」
          _uiPhase = phaseDownloading;
          _explicitReset = false;
          update(['download']);
          _startProgressPolling();
          done.complete(true);
        } else {
          _silentRetrying = false;
          update(['download']);
          final again = await _trySilentRetry();
          done.complete(again);
        }
      } catch (_) {
        _silentRetrying = false;
        update(['download']);
        done.complete(false);
      }
    });
    return done.future;
  }

  /// 用新直链重新入队（保留原进度语义：清掉旧任务，新任务从断点续传）
  Future<bool> _enqueueSilentRetry(String freshUrl) async {
    try {
      // 删除失败的旧任务（避免列表里堆一串失败记录）
      final old = taskId;
      if (old != null && old.isNotEmpty) {
        try {
          await FlutterDownloader.remove(
            taskId: old,
            shouldDeleteContent: false,
          );
        } catch (_) {}
      }
      final nt = await FlutterDownloader.enqueue(
        url: freshUrl,
        savedDir: await DownloadDir.path(),
        fileName: appInfo?.fileName ?? '',
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );
      if (nt == null || nt.isEmpty) return false;
      taskId = nt;
      dowUrl = freshUrl;
      return true;
    } catch (_) {
      return false;
    }
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
    // ★ 1012b：恢复下载 → 回到 downloading 态
    _uiPhase = phaseDownloading;
    _explicitReset = false;
    update(['download']);
  }

  /// 重试下载
  ///
  /// ★★ 1020：原来直接 FlutterDownloader.retry 复用**旧直链**，
  ///   而蓝奏云直链几小时就过期 → 直链失效后点多少次重试都是同一个失败。
  ///   现在先重新解析拿新直链，再新建任务；解析失败才退回原地重试。
  /// 手机剩余空间（MB），拿不到返回 -1
  ///
  /// ★ 1029：原来取 `Directory.systemTemp.statSync().size` —— 那是目录 inode 的大小
  ///   （一般 4096 字节），除下来恒定 0 MB，后台据此判「存储不足」，把 CDN 断流
  ///   误诊成空间问题。改为走原生 StatFs，取不到就报 -1（未知）。
  Future<int> _freeSpaceMb() => DiskSpace.freeMb();

  /// 安装包大小（MB），拿不到返回 -1
  int _fileSizeMb() {
    try {
      final v = double.tryParse(
        (appInfo?.fileSize ?? item?.size ?? '').replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        ),
      );
      return v != null && v > 0 ? v.round() : -1;
    } catch (_) {
      return -1;
    }
  }

  Future<void> retryDownload() async {
    final origin = dowUrl.isNotEmpty ? dowUrl : (item?.url ?? '');
    if (origin.isNotEmpty) {
      AppAction.showLoading('正在重新获取下载地址…');
      String? fresh;
      try {
        fresh = await service.resolveLzy(origin);
      } catch (_) {}
      AppAction.hideLoading();

      if (fresh != null && fresh.isNotEmpty) {
        // ★ 1020：解析已通过服务端鉴权（resolveLzy 内部走 /lzy/auth 发票据），
        //   这里重新授予一次性令牌，否则 addDownload 会以「未通过校验」拦下。
        _unlockToken = true;
        // 删掉旧任务，用新直链重新入队
        if (taskId != null && taskId!.isNotEmpty) {
          try {
            await FlutterDownloader.remove(
              taskId: taskId!,
              shouldDeleteContent: true,
            );
          } catch (_) {}
        }
        _shownFailDialog = false;
        _silentRetry = 0;
        await addDownload(
          (appInfo?.fileName ?? item?.title ?? 'download'),
          fresh,
        );
        return;
      }
    }

    // 兜底：拿不到新直链 → 原地重试（至少能续上没下完的部分）
    if (taskId == null || taskId!.isEmpty) {
      ToastUtil.error('下载任务ID无效');
      return;
    }
    final taskIdTemp = await FlutterDownloader.retry(taskId: taskId!);
    if (taskIdTemp == null) {
      ToastUtil.error('重试失败，可尝试用浏览器打开原链接');
      return;
    }
    taskId = taskIdTemp;
    _uiPhase = phaseDownloading;
    _shownProgress = 0;
    _explicitReset = false;
    update(['download']);
  }

  /// 用户是否主动点了取消（区分「用户取消」和「系统中断」）
  ///
  /// ★★ 1020：FlutterDownloader 的 canceled 状态有两种来源 ——
  ///   用户点取消、或下载被系统终止（存储满/权限撤销/省电策略），
  ///   之前一律报「用户取消」，把系统问题也发进告警邮件。
  bool _userCanceled = false;

  Future<void> cancelDownload() async {
    if (taskId == null || taskId!.isEmpty) {
      ToastUtil.error('下载任务ID无效');
      return;
    }
    _userCanceled = true; // ★ 只有走这里才认定为「用户主动取消」
    await FlutterDownloader.remove(taskId: taskId!, shouldDeleteContent: true);
    downloadTaskDao.deleteDownloadTask(appId);
    taskId = null;
    downloadTask = null;
    _renderedTaskId = null;
    _renderedStatus = -1;
    _renderedProgress = -1;
    // ★ 1012b：唯一允许「进度条 → 按钮」的显式入口之一
    _explicitReset = true;
    _uiPhase = phaseIdle;
    _shownProgress = 0;
    _progressTimer?.cancel();
    _lastDownloadTap = null;
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
          AppDialog(
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
    for (final dir in await DownloadDir.fallbackDirs()) {
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
      showGlassDialog(
        context: context,
        builder: (_) => AppDialog(
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
    showGlassDialog(
      context: context,
      // ★ 1028：海报内容自带 BottomPanel 贴底面壳，外层绝不能再套 Center+GlassShell
      //   否则会变成「居中悬浮卡 + 底部露出下载栏」，真机看着就是两个弹窗
      bare: true,
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
    final _ctx = SafeCtx.of();
    if (_ctx == null) return;
    showDialog(
      context: _ctx,
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
