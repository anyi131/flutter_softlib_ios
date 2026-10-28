////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 主 Tab 页
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植改造:
// 上游 pages/parse.dart + preview.dart 的核心交互(粘贴→解析→结果卡→下载→历史)
// 按宿主设计体系(lib/app/design)重写;下载落盘到应用目录(非系统媒体库)。
// 版权与许可遵循上游 MIT License,见仓库 LICENSE。
////////////////////////////////////////////////////////////////////////////////
import 'dart:async';

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
import '../jicun_downloader.dart';
import '../jicun_parse_service.dart';
import '../jicun_download_naming.dart';
import '../jicun_prefs.dart';
import '../jicun_network.dart';
import '../jicun_platform.dart';
import '../jicun_playback_headers.dart';
import '../jicun_save_album.dart';
import '../jicun_save_remote.dart';
import '../widgets/jicun_gallery.dart';
import 'jicun_audio_player_page.dart';
import 'jicun_history_page.dart';
import 'jicun_settings_page.dart';
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
  final _prefs = JicunPrefs.instance;
  final _tasks = JicunDownloadController.I;

  bool _parsing = false;

  /// 正在保存到相册的任务 id（防连点，也用来把按钮文案切成「保存中…」）
  final Set<String> _savingIds = <String>{};
  ParseResult? _result;
  String _sourceUrl = '';
  VideoQuality? _pickedQuality;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 后台配置拉一次(剪贴板/公告等即时生效)
    _settings.refresh();
    // 本机偏好（自动粘贴/存储目录/通知开关）先读一次，首屏就能拿到
    unawaited(_prefs.load().then((_) {
      if (!mounted) return;
      // 冷启动也自动粘贴一次（以前只有从后台回来才触发）
      if (_prefs.autoPaste && _ctrl.text.trim().isEmpty) {
        unawaited(_autoPaste());
      }
    }));
    // 下载完成/失败提醒（开关在本机偏好里）
    _tasks.onTaskSettled = _onTaskSettled;
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

  /// 任务收尾提醒：完成/失败各一个开关，关掉就静默
  void _onTaskSettled(JicunTask task, JicunTaskStatus status) {
    if (status == JicunTaskStatus.done) {
      if (!_prefs.notifyOnDone) return;
      ToastUtil.success('「${_shortTitle(task.title)}」下载完成');
    } else if (status == JicunTaskStatus.failed) {
      if (!_prefs.notifyOnFail) return;
      ToastUtil.error('「${_shortTitle(task.title)}」下载失败');
    }
  }

  /// 标题太长会把提示条撑爆，超过 12 个字截断
  String _shortTitle(String raw) {
    final t = raw.trim().isEmpty ? '任务' : raw.trim();
    return t.length > 12 ? '${t.substring(0, 12)}…' : t;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_tasks.onTaskSettled == _onTaskSettled) {
      _tasks.onTaskSettled = null;
    }
    // 后台 clear_on_exit:退出页面清历史
    _tasks.clearHistoryIfConfigured();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 后台 auto_paste:回到前台自动读剪贴板
    if (state == AppLifecycleState.resumed &&
        _prefs.autoPaste &&
        _ctrl.text.trim().isEmpty) {
      _autoPaste();
    }
  }

  Future<void> _autoPaste() async {
    await _prefs.load();
    if (!mounted) return;
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
    // 仅 Wi-Fi 下载：判不准（null）时放行，别把用户卡死
    if (_prefs.wifiOnly && await jicunIsCellular() == true) {
      if (mounted) ToastUtil.info('已开启仅 Wi-Fi 下载，当前是移动网络');
      return;
    }
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
      showDragHandle: false,
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
                '粘贴分享链接 · 解析 · 下载后可存到相册',
                style: TextStyle(fontSize: 12, color: context.t3),
              ),
            ],
          ),
        ),
        MiniAction(
          icon: Icons.tune_rounded,
          label: '设置',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const JicunSettingsPage(),
            ),
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
            // ★ 1028：解析结果里只要有视频，就给一个明确的「在线播放」入口。
            // 之前只有「点封面」才能进播放器 —— 带图集、或视频没有封面时，
            // 用户根本点不到播放器（这是「播放器怎么用不了」的主要来源）。
            if (r.videos.isNotEmpty) ...[
              const SizedBox(height: 10),
              _playEntry(r),
            ],
            if ((r.audioUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              _audioEntry(r),
            ],
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

  // ── 在线播放入口 ──────────────────────────────────────────────────────

  /// 打开全屏播放页（清晰度优先用用户选中的那一档）
  void _openPlayer() {
    final r = _result;
    if (r == null || r.videos.isEmpty) return;
    final v = r.videos.first;
    final vurl = _pickedQuality?.url ?? v.url;
    if (vurl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JicunVideoPlayerPage(url: vurl),
      ),
    );
  }

  /// 音频直链单独一条入口（有些平台解析出来只有音频）—— 上游同样的位置。
  Widget _audioEntry(ParseResult r) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openAudio,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: C.brand.withAlpha(context.isDark ? 26 : 14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.brand.withAlpha(56)),
        ),
        child: Row(
          children: [
            Icon(Icons.graphic_eq_rounded, size: 22, color: C.brand),
            const SizedBox(width: 8),
            Text(
              '在线收听',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: C.brand,
              ),
            ),
            const Spacer(),
            Text('音频', style: TextStyle(fontSize: 12, color: context.t3)),
            Icon(Icons.chevron_right_rounded, size: 18, color: C.t3),
          ],
        ),
      ),
    );
  }

  void _openAudio() {
    final r = _result;
    final url = r?.audioUrl ?? '';
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JicunAudioPlayerPage(
          url: url,
          title: r?.title ?? '',
          cover: r?.coverUrl ?? '',
        ),
      ),
    );
  }

  Widget _playEntry(ParseResult r) {
    final first = r.videos.first;
    final label = _pickedQuality?.label ??
        (first.qualities.isNotEmpty ? first.qualities.first.label : '');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openPlayer,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: C.brand.withAlpha(context.isDark ? 26 : 14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.brand.withAlpha(56)),
        ),
        child: Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, size: 22, color: C.brand),
            const SizedBox(width: 8),
            Text(
              '在线播放',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: C.brand,
              ),
            ),
            const Spacer(),
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(fontSize: 12, color: context.t3),
              ),
            Icon(Icons.chevron_right_rounded, size: 18, color: C.t3),
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
          _openPlayer();
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
    final images = urls.where((u) => u.isNotEmpty).toList(growable: false);
    if (images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JicunGalleryPage(
          images: images,
          initialIndex: initialIndex.clamp(0, images.length - 1),
          headers: jicunPlaybackHeaders(images.first),
          onSave: (index) async {
            final url = images[index];
            final res = await jicunSaveToAlbumFromUrl(
              url,
              kind: MediaKind.image.wireName,
              displayName: jicunCleanTitle(_result?.title ?? ''),
            );
            if (!mounted) return;
            res.ok ? ToastUtil.success(res.message) : ToastUtil.info(res.message);
          },
        ),
      ),
    );
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
              if (t.files.any((f) => f.isNotEmpty)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _firstFileOf(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: context.t3),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: MiniAction(
                      icon: _savingIds.contains(t.id)
                          ? Icons.hourglass_top_rounded
                          : Icons.photo_library_rounded,
                      label: _savingIds.contains(t.id) ? '保存中…' : '存到相册',
                      onTap: () => _saveTaskToAlbum(t),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  /// 把任务里已落盘的文件存进系统相册（视频/图片）或文档目录（音频）。
  ///
  /// 相册插件是按条写的，所以一批图集会逐条存；失败不中断，最后统一报结果 ——
  /// 用户要的是「哪些存进去了」，不是第一条失败就整体回滚。
  Future<void> _saveTaskToAlbum(JicunTask t) async {
    if (_savingIds.contains(t.id)) return;
    final idx = <int>[
      for (var i = 0; i < t.files.length; i++)
        if (t.files[i].isNotEmpty) i,
    ];
    if (idx.isEmpty) {
      ToastUtil.info('还没有可保存的文件');
      return;
    }
    setState(() => _savingIds.add(t.id));
    final base = jicunCleanTitle(t.title);
    var ok = 0;
    String? firstFail;
    try {
      for (final i in idx) {
        final kind = i < t.items.length
            ? t.items[i].kind.wireName
            : MediaKind.video.wireName;
        // 图集会有多张同名标题，补个序号才分得清是哪一张。
        final name = idx.length > 1 ? '${base}_${i + 1}' : base;
        final res = await jicunSaveToAlbum(
          t.files[i],
          kind: kind,
          displayName: name.isEmpty ? null : name,
        );
        if (res.ok) {
          ok++;
        } else {
          firstFail ??= res.message;
        }
      }
    } finally {
      if (mounted) setState(() => _savingIds.remove(t.id));
    }
    if (!mounted) return;
    if (ok == idx.length) {
      ToastUtil.success(ok > 1 ? '已保存 $ok 个文件' : '已保存到相册');
    } else if (ok > 0) {
      ToastUtil.info('已保存 $ok/${idx.length}，其余失败：${firstFail ?? '未知原因'}');
    } else {
      ToastUtil.info(firstFail ?? '保存失败，请重试');
    }
  }

  static String _firstFileOf(JicunTask t) {
    final first = t.files.firstWhere((f) => f.isNotEmpty, orElse: () => '');
    return first.isEmpty ? '' : first;
  }

  Widget _historyEntry() {
    return KitCard(
      // ★ 1028：历史页点一条记录会把原始链接 pop 回来，这里回填并立刻重解析
      onTap: () async {
        final url = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const JicunHistoryPage()),
        );
        if (!mounted) return;
        if (url == null || url.trim().isEmpty) return;
        _ctrl.text = url.trim();
        await _parse();
      },
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
