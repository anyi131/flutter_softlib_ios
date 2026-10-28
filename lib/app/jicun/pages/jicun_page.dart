////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 主 Tab 页
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植改造:
// 上游 pages/parse.dart + preview.dart 的核心交互(粘贴→解析→结果卡→下载→历史)
// 按宿主设计体系(lib/app/design)重写;下载落盘到应用目录(非系统媒体库)。
// 版权与许可遵循上游 MIT License,见仓库 LICENSE。
////////////////////////////////////////////////////////////////////////////////
import 'dart:io';

import '../../utils/err_text.dart';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import '../jicun_config.dart';
import '../jicun_download_controller.dart';
import '../jicun_history_store.dart';
import '../jicun_parse_service.dart';
import '../jicun_platform.dart';
import 'jicun_history_page.dart';
import 'jicun_video_player_page.dart';
import '../../design/glass.dart';

class JicunPage extends StatefulWidget {
  const JicunPage({super.key});

  @override
  State<JicunPage> createState() => _JicunPageState();
}

class _JicunPageState extends State<JicunPage> with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _settings = JicunSettings.instance;
  final _tasks = JicunDownloadController.I;

  bool _parsing = false;
  ParseResult? _result;
  String _sourceUrl = '';
  VideoQuality? _pickedQuality;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 后台配置拉一次(剪贴板/公告等即时生效)
    _settings.refresh();
    _ensureStorage();
  }

  /// Android 11+ 公共目录(/storage/emulated/0/安逸软件汇)需要「所有文件访问」授权
  Future<void> _ensureStorage() async {
    if (!Platform.isAndroid) return;
    try {
      final m = Permission.manageExternalStorage;
      if (await m.isGranted) return;
      await m.request();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 后台 clear_on_exit:退出页面清历史
    _tasks.clearHistoryIfConfigured();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 后台 auto_paste:回到前台自动读剪贴板
    if (state == AppLifecycleState.resumed &&
        _settings.cfg.autoPaste &&
        _ctrl.text.trim().isEmpty) {
      _autoPaste();
    }
  }

  Future<void> _autoPaste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text ?? '';
      final url = extractShareUrl(raw);
      if (url != null && mounted) {
        setState(() => _ctrl.text = raw);
      }
    } catch (_) {}
  }

  Future<void> _parse() async {
    final raw = _ctrl.text.trim();
    final url = extractShareUrl(raw);
    if (url == null) {
      ToastUtil.info('先粘贴一条分享链接');
      return;
    }
    setState(() {
      _parsing = true;
      _sourceUrl = url;
      _result = null;
      _pickedQuality = null;
    });
    try {
      final r = await jicunParseService.parse(url);
      if (!mounted) return;
      setState(() {
        _result = r;
        // 后台 quality_default: highest 直接取最高档,ask 交给用户在结果卡里选
        _pickedQuality = _settings.cfg.qualityDefault == 'ask'
            ? null
            : (r.videos.isNotEmpty && r.videos.first.qualities.isNotEmpty
                  ? r.videos.first.qualities.first
                  : null);
      });
    } on ParseException catch (e) {
      ToastUtil.error('${e.message}');
    } catch (e) {
      // v331w：显示真实原因（超时/断网/接口异常各不同），不再笼统
      final m = ErrText.of(e);
      ToastUtil.error(m.length > 40 ? '解析失败:$m'.substring(0, 40) : '解析失败:$m');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _download() async {
    final r = _result;
    if (r == null) return;
    // 清晰度策略 ask:视频有第二档时先弹选择
    var quality = _pickedQuality;
    if (r.videos.isNotEmpty &&
        quality == null &&
        _settings.cfg.qualityDefault == 'ask') {
      final chosen = await _pickQuality(r.videos.first);
      if (chosen == null && r.videos.first.qualities.length > 1) return;
      quality = chosen ?? r.videos.first.qualities.firstOrNull;
    }
    final task = _tasks.enqueueResult(r, _sourceUrl, quality: quality);
    ToastUtil.success('已加入下载队列');
    setState(() {
      // 下载中卡片由 tasks 列表驱动
    });
    debugPrint('[jicun] task ${task.id} enqueued');
  }

  Future<VideoQuality?> _pickQuality(VideoItem v) async {
    if (v.qualities.length <= 1) return v.qualities.firstOrNull;
    return showModalBottomSheet<VideoQuality>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => SafeArea(
        child: SheetSurface(
          color: c.isDark ? C.bg2 : Colors.white,
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(16),
          radius: R.lg,
          onlyTop: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择清晰度',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.t1,
                ),
              ),
              const SizedBox(height: 10),
              ...v.qualities.map(
                (q) => ListTile(
                  dense: true,
                  leading: Icon(Icons.hd_rounded, color: C.brand, size: 22),
                  title: Text(
                    '${q.label}${q.size > 0 ? ' · ${_sizeText(q.size)}' : ''}',
                    style: TextStyle(fontSize: 14, color: c.t1),
                  ),
                  onTap: () => Navigator.pop(c, q),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sizeText(int bytes) {
    if (bytes >= (1 << 30))
      return '${(bytes / (1 << 30)).toStringAsFixed(1)}GB';
    if (bytes >= (1 << 20))
      return '${(bytes / (1 << 20)).toStringAsFixed(0)}MB';
    return '${(bytes / (1 << 10)).toStringAsFixed(0)}KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => _settings.refresh(force: true),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  10,
                  context.pagePadding,
                  120,
                ),
                children: [
                  _header(),
                  if (_settings.cfg.notice.isNotEmpty) _notice(),
                  const SizedBox(height: 12),
                  _pasteBox(),
                  const SizedBox(height: 12),
                  if (_parsing)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (_result != null) _resultCard(),
                  const SizedBox(height: 12),
                  _taskList(),
                  const SizedBox(height: 12),
                  _historyEntry(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: C.brandGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.download_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                JicunSettings.instance.cfg.tabName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.t1,
                ),
              ),
              Text(
                '粘贴分享链接 · 解析并下载(保存到应用目录)',
                style: TextStyle(fontSize: 12, color: context.t3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notice() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.amber.withAlpha(context.isDark ? 30 : 22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.amber.withAlpha(60)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.campaign_rounded,
              color: Color(0xFFB45309),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _settings.cfg.notice,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pasteBox() {
    return KitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            maxLines: 3,
            minLines: 2,
            style: TextStyle(fontSize: 14, color: context.t1),
            decoration: InputDecoration(
              hintText: '粘贴抖音/快手/小红书/B站/微博等分享链接或文案…',
              hintStyle: TextStyle(fontSize: 13, color: context.t3),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: _parsing ? '解析中…' : '开始解析',
                  icon: Icons.travel_explore_rounded,
                  onPressed: _parsing ? null : _parse,
                ),
              ),
              const SizedBox(width: 10),
              MiniAction(
                icon: Icons.content_paste_rounded,
                label: '粘贴',
                onTap: _autoPaste,
              ),
              const SizedBox(width: 8),
              MiniAction(
                icon: Icons.clear_all_rounded,
                label: '清空',
                onTap: () => setState(() {
                  _ctrl.clear();
                  _result = null;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final r = _result!;
    final quality = _pickedQuality;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: KitCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: C.brand.withAlpha(24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.platform.isEmpty ? '未知平台' : r.platform,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: C.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.t3),
                  ),
                ),
              ],
            ),
            if (r.title.isNotEmpty || r.desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                r.title.isNotEmpty ? r.title : r.desc,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: context.t1,
                ),
              ),
            ],
            _mediaPreview(r),
            const SizedBox(height: 10),
            _mediaSummary(r),
            if (r.videos.isNotEmpty && r.videos.first.qualities.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final q = await _pickQuality(r.videos.first);
                    if (q != null) setState(() => _pickedQuality = q);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.isDark ? C.bg0 : C.lbg2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: context.t2),
                        const SizedBox(width: 6),
                        Text(
                          '清晰度:${quality?.label ?? '点击选择'}',
                          style: TextStyle(fontSize: 13, color: context.t2),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: context.t3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: '下载到应用目录',
              icon: Icons.save_alt_rounded,
              onPressed: _download,
            ),
          ],
        ),
      ),
    );
  }

  // ── 媒体预览区：图集 > 视频封面 > 兜底单图 ────────────────────────────

  Widget _mediaPreview(ParseResult r) {
    if (r.imageUrls.isNotEmpty) {
      return _galleryPreview(r.imageUrls);
    }
    final videoCover = r.videos.isNotEmpty
        ? (r.videos.first.coverUrl ?? r.coverUrl)
        : null;
    final cover = videoCover ?? (r.videos.isEmpty ? r.coverUrl : null);
    if (cover != null && cover.isNotEmpty) {
      return _singleCoverPreview(cover, height: 160);
    }
    return const SizedBox.shrink();
  }

  /// 图集：横向滚动缩略图行，点击进入全屏查看器。
  Widget _galleryPreview(List<String> urls) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: urls.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: EdgeInsets.only(right: i == urls.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => _showImageViewer(urls, initialIndex: i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 96, child: _netImage(urls[i])),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 单封面（视频封面或兜底封面）：全幅高度块 + 中央播放图标（仅视频）。
  /// 视频封面点击 → 全屏视频播放页；图集/兜底图点击 → 全屏图片查看器。
  Widget _singleCoverPreview(String url, {required double height}) {
    final isVideo = _result?.videos.isNotEmpty ?? false;
    final videos = _result?.videos ?? const [];
    final cover = videos.isNotEmpty ? videos.first.coverUrl : null;
    final showPlay = isVideo && (cover == null || cover == url);
    return GestureDetector(
      onTap: () {
        if (showPlay) {
          final v = videos.first;
          final vurl = _pickedQuality?.url ?? v.url;
          if (vurl.isEmpty) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => JicunVideoPlayerPage(url: vurl),
            ),
          );
        } else {
          _showImageViewer([url]);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _netImage(url),
              if (showPlay)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(110),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 全屏图片查看器：黑底 dialog + PageView 左右滑 + InteractiveViewer 双指缩放。
  void _showImageViewer(List<String> urls, {int initialIndex = 0}) {
    final controller = PageController(initialPage: initialIndex);
    final pageNotifier = ValueNotifier<int>(initialIndex);
    controller.addListener(() {
      final page = controller.page?.round() ?? initialIndex;
      if (page != pageNotifier.value) pageNotifier.value = page;
    });
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: urls.length,
                itemBuilder: (context, i) {
                  return InteractiveViewer(
                    maxScale: 4,
                    child: Center(
                      child: _netImage(urls[i], fit: BoxFit.contain),
                    ),
                  );
                },
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
              if (urls.length > 1)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ValueListenableBuilder<int>(
                        valueListenable: pageNotifier,
                        builder: (context, page, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(120),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${page + 1} / ${urls.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  /// 网络图：加载中灰底占位，失败图标占位。
  Widget _netImage(String url, {BoxFit fit = BoxFit.cover}) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: context.isDark ? C.bg0 : C.lbg2,
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, size: 24, color: context.t3),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: context.isDark ? C.bg0 : C.lbg2,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, size: 28, color: context.t3),
        );
      },
    );
  }

  Widget _mediaSummary(ParseResult r) {
    final parts = <String>[
      if (r.hasVideo) '视频',
      if (r.imageUrls.isNotEmpty) '图集 ${r.imageUrls.length} 张',
      if (r.livePhotos.isNotEmpty) '实况 ${r.livePhotos.length} 张',
      if (r.hasAudio) '音频',
    ];
    if (parts.isEmpty) {
      return Text(
        '未识别到可下载的媒体',
        style: TextStyle(fontSize: 13, color: context.t3),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final p in parts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.isDark ? C.bg0 : C.lbg2,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              p,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.t2,
              ),
            ),
          ),
      ],
    );
  }

  Widget _taskList() {
    return Obx(() {
      final list = _tasks.tasks;
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '下载任务',
            action: TextButton(
              onPressed: _tasks.clearFinished,
              child: Text('清掉已完成', style: TextStyle(fontSize: 12)),
            ),
          ),
          for (final t in list) _taskCard(t),
        ],
      );
    });
  }

  Widget _taskCard(JicunTask t) {
    return Obx(() {
      final status = t.status.value;
      final color = switch (status) {
        JicunTaskStatus.done => C.mint,
        JicunTaskStatus.failed => C.rose,
        JicunTaskStatus.cancelled => C.amber,
        _ => C.brand,
      };
      final label = switch (status) {
        JicunTaskStatus.waiting => '排队中',
        JicunTaskStatus.running =>
          '下载中 ${(t.progress.value * 100).toStringAsFixed(0)}%'
              '${t.items.length > 1 ? ' · ${t.doneCount.value}/${t.items.length}' : ''}',
        JicunTaskStatus.done => '完成 · 已存到应用目录',
        JicunTaskStatus.failed => '失败',
        JicunTaskStatus.cancelled => '已取消',
      };
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: KitCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == JicunTaskStatus.done
                        ? Icons.check_circle_rounded
                        : status == JicunTaskStatus.failed
                        ? Icons.error_rounded
                        : Icons.downloading_rounded,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${t.platform.isEmpty ? '' : '${t.platform} · '}${t.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                  ),
                  if (t.isBusy)
                    InkWell(
                      onTap: () => _tasks.cancel(t.id),
                      child: Text(
                        '取消',
                        style: TextStyle(fontSize: 12, color: C.rose),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: status == JicunTaskStatus.done
                      ? 1
                      : t.progress.value.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: context.isDark ? C.bg0 : C.lbg2,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.message ?? label,
                style: TextStyle(fontSize: 11, color: context.t3),
              ),
              if (t.files.any((f) => f.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DirectoryeofNote(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: context.t3),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  static String DirectoryeofNote(JicunTask t) {
    final first = t.files.firstWhere((f) => f.isNotEmpty, orElse: () => '');
    return first.isEmpty ? '' : first;
  }

  Widget _historyEntry() {
    return KitCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JicunHistoryPage()),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 20, color: C.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '解析历史',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.t1,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: context.t3),
        ],
      ),
    );
  }
}

extension _QFirstOrNull on List<VideoQuality> {
  VideoQuality? get firstOrNull => isEmpty ? null : first;
}
