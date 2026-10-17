import 'dart:async';
import '../../utils/lzy_local_parser.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';

import '../../api/soft_service.dart';
import '../../design/app_anim.dart';
import '../../design/ui.dart';
import '../../utils/apk_installer.dart';
import '../../utils/download_dir.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// ═══════════════════════════════════════════════════════════════
/// 更新体验 v52 —— 精美更新弹窗 + 应用内下载进度（需求 #4）
///
///  · 渐变头图 + 版本徽章 + 更新日志
///  · 点「立即更新」弹窗内直接显示下载进度（环形 + 百分比 + 已下载/总大小）
///  · 100% 自动拉起安装器；失败降级浏览器
/// ═══════════════════════════════════════════════════════════════
class UpdateFlow {
  UpdateFlow._();

  /// 检查更新（公开：首页四宫格 / 启动时调用）
  static Future<void> check({bool showLatestTip = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final data = await SoftService.instance.checkVersion(version);
      if (data != null) {
        // ★ 1016：稍微延后，等首页真正渲染完再弹（避免启动时序导致弹窗异常）
        await Future.delayed(const Duration(milliseconds: 700));
        if (Get.context == null) return;
        await show(data);
      } else if (showLatestTip) {
        ToastUtil.success('已是最新版本（v$version）');
      }
    } catch (e) {
      if (showLatestTip) ToastUtil.error('检查更新失败，请稍后重试');
    }
  }

  /// 显示更新弹窗（直接用 Map，避开 Retrofit 模型的类型限制）
  static Future<void> show(Map<String, dynamic> d) async {
    final title = (d['title'] ?? '发现新版本').toString();
    final ver = (d['version'] ?? '').toString();
    final content = (d['content'] ?? '请及时更新以获取最佳体验').toString();
    final url = (d['dow_url'] ?? '').toString();
    final forced = '${d['forced_switch']}' == '1' || d['forced_switch'] == true;
    // 模板：后台 ui_config.update_template 下发
    // ★ 1015 修复：必须用 force 拉最新配置。原来走缓存（10 分钟 TTL），
    //   后台刚改完模板时弹窗读到的还是旧值 → 用户以为「切换没生效」。
    String template = 'classic';
    try {
      final cfg = await SoftService.instance.fetchConfig(force: true);
      final t = cfg?.uiConfig.updateTemplate ?? '';
      if (t.isNotEmpty) template = t;
    } catch (_) {}

    // ★ 1016：后台模板照常生效（不再强制安全款）。
    //   卡死的真因不是模板本身，而是模板里 30~40 的大范围阴影 ——
    //   已把阴影统一调轻（见各模板），观感几乎不变但开销小很多。
    if (url.isEmpty) return;
    // ★ 1016 路标：卡死时 Dart 层不会有任何日志，所以这里提前上报一条，
    //   配合下面「已显示」那条，就能判断卡死是否发生在弹窗构建阶段。
    try {
      SoftService.reportLogStatic(
        tag: 'update',
        error: '[update] 准备弹窗 tpl=$template ver=$ver',
      ).catchError((_) {});
    } catch (_) {}
    // ★ 1016：安全取 context（启动阶段可能为 null，绝不能崩）
    final ctx = Get.context ?? Get.key.currentContext;
    if (ctx == null) return;
    showDialog(
      // ★ 1016：原来是 Get.context! —— 启动阶段 / 页面切换时 Get.context 可能为 null，
      //   会直接抛「Null check operator used on a null value」（已在真机日志里抓到）。
      context: ctx,
      barrierDismissible: !forced,
      barrierColor: Colors.black.withAlpha(120),
      builder: (context) => PopScope(
        canPop: !forced,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 34,
            vertical: 40,
          ),
          child: _UpdateCard(
            title: title,
            version: ver,
            content: content,
            url: url,
            forced: forced,
            template: template,
          ),
        ),
      ),
    );
    // ★ 1016 路标：能走到这里说明弹窗已经进入渲染队列
    try {
      SoftService.reportLogStatic(
        tag: 'update',
        error: '[update] 弹窗已显示 tpl=$template',
      ).catchError((_) {});
    } catch (_) {}
  }
}

class _UpdateCard extends StatefulWidget {
  final String title;
  final String version;
  final String content;
  final String url;
  final bool forced;

  /// 弹窗模板（后台 ui_config.update_template 下发）
  final String template;
  const _UpdateCard({
    required this.title,
    required this.version,
    required this.content,
    required this.url,
    required this.forced,
    this.template = 'classic',
  });

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  // idle / downloading / done / failed
  String _phase = 'idle';
  int _progress = 0; // 0-100
  int _total = 0;
  Timer? _poll;

  /// 最近一次下载完成的文件路径（安装/重试用）
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    // ★ 1016：「安装包」大小在下载前是未知的（_total 要等下载才有值），
    //   所以这里用 HEAD 请求先把远端文件大小拿回来，弹窗一打开就能显示。
    _fetchRemoteSize();
  }

  /// 取远端安装包大小
  ///   · 直链文件（.apk/.ipa/.zip 或本站 /uploads/）→ HEAD 取 content-length
  ///   · 蓝奏云等分享页 → 先查文件信息接口拿 file_size（不用下载），
  ///     拿不到再解析出直链后 HEAD（这两个都会慢一点，所以是兜底顺序）
  Future<void> _fetchRemoteSize() async {
    final u = widget.url.trim();
    if (u.isEmpty) return;
    final lower = u.toLowerCase();

    // ── 蓝奏云 / 分享页 ──
    final isShare = lower.contains('lanzou') ||
        lower.contains('lzy') ||
        lower.contains('lanzo') ||
        lower.contains('/b0') ||
        lower.contains('/i');
    if (isShare && !lower.endsWith('.apk') && !lower.endsWith('.ipa')) {
      // ① 文件信息（最快，直接给大小）
      try {
        final info = await SoftService.instance.lzyFileInfo(u);
        // 服务端返回的键是 size（有的版本叫 file_size），两种都认
        final bytes = _parseSizeText(
          '${info?['size'] ?? info?['file_size'] ?? ''}',
        );
        if (bytes > 0 && mounted && _total == 0) {
          setState(() => _total = bytes);
          return;
        }
      } catch (_) {}
      // ② 兜底：解析出直链再 HEAD
      try {
        final direct = await SoftService.instance.resolveLzy(u);
        if (direct != null && direct.isNotEmpty) {
          await _headSize(direct);
        }
      } catch (_) {}
      return;
    }

    final looksFile = lower.endsWith('.apk') ||
        lower.endsWith('.ipa') ||
        lower.endsWith('.zip') ||
        lower.contains('/uploads/');
    if (!looksFile) return;
    await _headSize(u);
  }

  /// 把 "1.2 M" / "28.3MB" / "1024 K" 这类文本转成字节数
  int _parseSizeText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final m = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*([kKmMgG]?)').firstMatch(t);
    if (m == null) return 0;
    final v = double.tryParse(m.group(1) ?? '') ?? 0;
    if (v <= 0) return 0;
    final unit = (m.group(2) ?? '').toUpperCase();
    final mul = switch (unit) {
      'K' => 1024.0,
      'M' => 1048576.0,
      'G' => 1073741824.0,
      _ => 1.0,
    };
    return (v * mul).round();
  }

  /// HEAD 取 content-length
  Future<void> _headSize(String url) async {
    try {
      final r = await SoftService.instance.dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final len =
          int.tryParse('${r.headers.value('content-length') ?? ''}') ?? 0;
      final ct = '${r.headers.value('content-type') ?? ''}'.toLowerCase();
      final lower = url.toLowerCase();
      final isFile = ct.contains('android') ||
          ct.contains('octet-stream') ||
          ct.contains('zip') ||
          ct.contains('ipa') ||
          lower.endsWith('.apk') ||
          lower.endsWith('.ipa');
      if (len > 0 && isFile && mounted && _total == 0) {
        setState(() => _total = len);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_phase == 'downloading') return;
    // 权限
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    // ═══ 解析直链：三级降级（本地 → 服务端 → 浏览器）═══
    //   ★ 1016：原来只有「服务端解析」一跳，未登录/票据失败就直接跳浏览器，
    //   用户看到的是「没解析就跳浏览器」。现在更新包也走完整降级链。
    String? direct = widget.url;
    final needParse =
        widget.url.contains('lanzou') || widget.url.contains('lzy');
    if (needParse) {
      // ① 本地解析（更新包属免费资源，可本地）
      try {
        direct = await LzyLocalParser.parse(widget.url);
      } catch (_) {
        direct = null;
      }
      // ② 服务端解析（服务端对更新包已免登录发票据）
      if (direct == null || direct.isEmpty) {
        try {
          direct = await SoftService.instance.resolveLzy(widget.url);
        } catch (_) {
          direct = null;
        }
      }
    }
    if (direct == null || direct.isEmpty) {
      // ③ 浏览器兜底 —— 带上真实原因，不再静默跳转
      final why = SoftService.lastParseError.isNotEmpty
          ? SoftService.lastParseError
          : LzyLocalParser.lastError;
      if (mounted) {
        ToastUtil.info(
          why.isEmpty ? '解析失败，改用浏览器下载' : '解析失败（$why），改用浏览器',
        );
      }
      _fallbackBrowser();
      return;
    }
    setState(() => _phase = 'downloading');
    final taskId = await FlutterDownloader.enqueue(
      url: direct,
      fileName: 'softlib_update_${DateTime.now().millisecondsSinceEpoch}.apk',
      savedDir: await DownloadDir.path(),
      showNotification: true,
      saveInPublicStorage: true,
      openFileFromNotification: true,
    );
    if (taskId == null) {
      _fallbackBrowser();
      return;
    }
    _poll = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task WHERE task_id='$taskId'",
      );
      if (tasks == null || tasks.isEmpty) return;
      final tk = tasks.first;
      if (!mounted) return;
      setState(() {
        _progress = tk.progress;
      });
      if (tk.status == DownloadTaskStatus.complete) {
        t.cancel();
        setState(() => _phase = 'done');
        _lastPath = '${tk.savedDir}/${tk.filename}';
        await Future.delayed(const Duration(milliseconds: 400));
        await _install();
      } else if (tk.status == DownloadTaskStatus.failed ||
          tk.status == DownloadTaskStatus.canceled) {
        t.cancel();
        setState(() => _phase = 'failed');
      }
    });
  }

  /// ★ 1016：统一的「安装已下载的包」流程。
  ///   原来只有 `try { install() } catch (_) {}` —— 异常被吞掉、
  ///   也从没检查「安装未知应用」权限（Android 8+ 没这权限时调起安装器会
  ///   **静默失败**），所以真机上「下载完成」之后什么都不发生。
  Future<void> _install() async {
    final reported = _lastPath;
    if (reported == null || reported.isEmpty) {
      ToastUtil.error('安装包路径丢失，请用「浏览器下载」重试');
      return;
    }
    // ① 「安装未知应用」权限
    var can = await ApkInstaller.canInstall();
    if (!can && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('需要「安装未知应用」权限'),
          content: const Text(
            '系统要求先允许本应用安装其他应用，才能自动完成更新。'
            '点「去设置」打开开关，回来后会自动继续安装。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('用浏览器下载'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      if (go == true) {
        await ApkInstaller.openInstallSettings();
        await Future.delayed(const Duration(seconds: 3));
        can = await ApkInstaller.canInstall();
      } else {
        _openInBrowser();
        return;
      }
    }
    if (!can) {
      ToastUtil.error('未获得安装权限，可用「浏览器下载」手动安装');
      _report('未获得安装权限');
      return;
    }
    // ② 文件兜底：saveInPublicStorage 时上报路径可能与实际落盘目录不一致
    final file = await _resolveApk(reported);
    if (file == null) {
      ToastUtil.error('安装包未找到，请用「浏览器下载」');
      _report('安装包未找到: ' + reported);
      return;
    }
    // ③ 调起安装器（失败要说话，不能再吞）
    final ok = await ApkInstaller.install(file.path);
    if (!ok) {
      ToastUtil.error('未能调起安装器，请用「浏览器下载」手动安装');
      _report('调起安装器失败: ' + file.path);
      return;
    }
    if (mounted && !widget.forced) Navigator.of(context).pop();
  }

  /// 在常见下载目录里兜底找安装包
  Future<File?> _resolveApk(String reported) async {
    try {
      final f = File(reported);
      if (f.existsSync()) return f;
      final name = reported.split('/').last;
      for (final d in await DownloadDir.fallbackDirs()) {
        final c = File(d + '/' + name);
        if (c.existsSync()) return c;
      }
    } catch (_) {}
    return null;
  }

  void _report(String msg) {
    try {
      SoftService.reportLogStatic(
        tag: 'update',
        error: '[update-install] ' + msg,
      ).catchError((_) {});
    } catch (_) {}
  }

  void _fallbackBrowser() {
    // ★ 1014 修复：App 自身更新包属于可信来源，不属于需要鉴权的付费资源，
    //   这里必须显式放行直链，否则会被 openUrl 的下载直链白名单误拦
    //   （用户反馈：点「立即更新」弹「该链接为下载地址，请从软件详情页下载」）。
    JumpUtil.openUrl(widget.url, allowDownload: true);
  }

  /// ★ 1014 新增：用浏览器打开原链接下载
  /// 直接把后台配置的更新地址（原链接，如蓝奏云分享页）交给系统浏览器，
  /// 由浏览器完成下载，绕开 App 内的解析环节。
  void _openInBrowser() {
    final u = widget.url.trim();
    if (u.isEmpty) {
      ToastUtil.error('更新地址为空，请联系管理员');
      return;
    }
    ToastUtil.info('已用浏览器打开下载页');
    JumpUtil.openUrl(u, allowDownload: true);
  }

  /// ★ 1016：把后台说明转成**纯文本**。
  ///   原来这里交给 HtmlWidget 渲染 —— 那是一个完整的 HTML 引擎，
  ///   在「无界高度 + 弹窗」里做同步解析/布局，是**跨平台死循环（卡死）**的经典来源，
  ///   而且卡住时 Dart 层不会有任何日志（只能看到系统 ANR/看门狗杀进程）。
  ///   更新说明本来就是纯文字，用 Text 渲染 100% 安全、外观一样。
  String _contentToText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    return t
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String _sizeText(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / 1048576;
    return '${mb.toStringAsFixed(1)}MB';
  }

  @override
  // ═══════════════════════════════════════════════════════════════
  //  ★ 1016 更新弹窗模板体系 —— 全部重做（六套）
  //
  //  这次重写是为了根治之前反复出问题的根源。下面每一条都是踩过的坑：
  //    · 绝不做「初始透明度 0、靠动画变可见」的包装 —— 动画一不跑内容就永远看不见
  //    · 绝不用 HtmlWidget 渲染正文 —— 它在无界高度里会死循环（安卓/iOS 通杀）
  //    · 阴影一律 ≤ 10 —— 弹窗是整屏遮罩，30~40 的大阴影会把主线程/GPU 拖死
  //    · 卡片总高 ≤ 屏幕 72%；正文区用 Flexible（必须是 Column 直接子级）自适应 + 可滚动
  //    · 六套是**结构级差异**：信息架构 / 排版动线 / 操作区各不相同，不是换色
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final tpl = switch (widget.template) {
      'classic' => 'classic',
      'banner' => 'banner',
      'poster' => 'poster',
      'list' => 'list',
      'split' => 'split',
      'sheet' => 'sheet',
      'meta' => 'meta',
      'triple' => 'triple',
      'timeline' => 'timeline',
      // 旧模板名一律映射到最接近的新模板（后台存旧值也不会白屏）
      'aurora' || 'neon' || 'dark' => 'banner',
      'compact' => 'triple',
      'checklist' || 'steps' => 'timeline',
      'ticket' => 'list',
      'combo' || 'side' => 'sheet',
      'minimal' || 'simple' => 'classic',
      final v => v,
    };
    return switch (tpl) {
      'banner' => _tplBanner(),
      'poster' => _tplPoster(),
      'list' => _tplList(),
      'split' => _tplSplit(),
      'sheet' => _tplSheet(),
      'meta' => _tplMeta(),
      'triple' => _tplTriple(),
      'timeline' => _tplTimeline(),
      _ => _tplClassic(),
    };
  }

  // ─────────── 公共：安全骨架 ───────────

  /// 卡片外壳：总高 ≤ 屏幕 72%，中段正文自适应且可滚动（超长也不会把按钮挤出屏幕）
  Widget _shell({
    required List<Widget> top,
    required List<Widget> bottom,
    double radius = 20,
    Color? bg,
    Widget? body,
  }) {
    final isDark = context.isDark;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg ?? (isDark ? C.bg2 : Colors.white),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 80 : 22),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...top,
            // ★ Flexible 必须是 Column 的直接子级（松约束 → 内容多高就多高，超了才滚动）
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: body ?? _currentBody(),
              ),
            ),
            ...bottom,
          ],
        ),
      ),
    );
  }

  /// 正文区：正常态显示更新说明，下载/完成/失败态显示进度
  Widget _currentBody() {
    if (_phase != 'idle') return _progressBody();
    final t = _contentToText(widget.content);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: Text(
        t.isEmpty ? '请更新到最新版本以获取完整体验。' : t,
        style: TextStyle(
          fontSize: 13.4,
          height: 1.7,
          color: context.isDark ? C.t2 : C.lt2,
        ),
      ),
    );
  }

  /// 操作区：主按钮独占一行，次要操作为下方小字（永不被挤成两行）
  Widget _actions({bool compact = false}) {
    if (_phase == 'downloading') return const SizedBox(height: 10);
    final isDark = context.isDark;
    final minorStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: isDark ? C.t3 : C.lt3,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 18, 4, compact ? 16 : 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPressable(
            onTap: _phase == 'done'
                ? _install
                : (_phase == 'failed'
                      ? () => setState(() => _phase = 'idle')
                      : _start),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: C.brandGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _phase == 'done'
                    ? '立即安装'
                    : (_phase == 'failed' ? '重试' : '立即更新'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _openInBrowser,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text('浏览器下载', style: minorStyle),
              ),
              if (!widget.forced)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text('稍后再说', style: minorStyle),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────── 模板① classic 经典卡（最朴素可靠，默认兜底）───────────
  Widget _tplClassic() {
    final isDark = context.isDark;
    return _shell(
      top: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: C.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title.isEmpty ? '发现新版本' : widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isDark ? C.t1 : C.lt1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '新版本 v${widget.version} 已发布',
                style: TextStyle(fontSize: 12.5, color: isDark ? C.t3 : C.lt3),
              ),
            ],
          ),
        ),
      ],
      bottom: [_actions()],
    );
  }

  // ─────────── 模板② banner 通栏条（顶部满宽渐变 + 大留白正文）───────────
  Widget _tplBanner() {
    final isDark = context.isDark;
    return _shell(
      radius: 18,
      top: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
          decoration: BoxDecoration(gradient: C.brandGradient),
          child: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Colors.white, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.title.isEmpty ? '版本更新通知' : widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'v${widget.version}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: [_actions()],
    );
  }

  // ─────────── 模板③ poster 海报大字（版本号当主角 + 极简正文）───────────
  Widget _tplPoster() {
    final isDark = context.isDark;
    return _shell(
      radius: 24,
      top: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(gradient: C.brandGradient),
          child: Column(
            children: [
              const Text(
                '发现新版本',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'v${widget.version}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              if (_total > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '安装包约 ${_sizeText(_total)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ],
          ),
        ),
      ],
      bottom: [_actions()],
    );
  }

  // ─────────── 模板④ list 更新清单（逐条圆点清单，信息密度最高）───────────
  Widget _tplList() {
    final isDark = context.isDark;
    return _shell(
      radius: 20,
      body: _listBody(),
      top: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: C.brand.withAlpha(isDark ? 40 : 22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.checklist_rounded, size: 19, color: C.brand),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本次更新 v${widget.version}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? C.t1 : C.lt1,
                      ),
                    ),
                    Text(
                      _today(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? C.t3 : C.lt3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: [_actions()],
    );
  }

  // ─────────── 模板⑤ split 左右分栏（左窄栏放版本，右侧正文+操作）───────────
  Widget _tplSplit() {
    final isDark = context.isDark;
    return _shell(
      radius: 20,
      top: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左：窄栏
              Container(
                width: 92,
                decoration: BoxDecoration(gradient: C.brandGradient),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.system_update_alt_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.version,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '新版本',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              // 右：正文 + 操作
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                        child: _currentBody(),
                      ),
                    ),
                    _actions(compact: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: const [],
    );
  }

  // ─────────── 模板⑥ sheet 底部抽屉（拖拽手柄 + 大图标行）───────────
  Widget _tplSheet() {
    final isDark = context.isDark;
    return _shell(
      radius: 26,
      top: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: C.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.downloading_rounded,
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
                      widget.title.isEmpty ? '有新版本可用' : widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? C.t1 : C.lt1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${widget.version}${_total > 0 ? ' · ${_sizeText(_total)}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? C.t3 : C.lt3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: [_actions()],
    );
  }

  // ─────────── 进度/结果态（下载中 / 已完成 / 失败）───────────
  Widget _progressBody() {
    final isDark = context.isDark;
    final subStyle = TextStyle(fontSize: 12, color: isDark ? C.t3 : C.lt3);
    if (_phase == 'done') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF34D399),
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '下载完成',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? C.t1 : C.lt1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('正在调起安装…', style: subStyle),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (_phase == 'failed') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFFB7185),
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '下载失败',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? C.t1 : C.lt1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('可重试，或用浏览器打开下载页', style: subStyle),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // downloading
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '正在下载 $_progress%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? C.t1 : C.lt1,
                ),
              ),
              const Spacer(),
              if (_total > 0)
                Text(
                  '${_sizeText((_progress * _total / 100).round())} / ${_sizeText(_total)}',
                  style: subStyle,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progress <= 0 ? null : _progress / 100,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : C.brand.withAlpha(24),
              color: C.brand,
            ),
          ),
          const SizedBox(height: 10),
          Text('请保持 App 在前台，下载完成后会自动调起安装', style: subStyle),
        ],
      ),
    );
  }

  /// list 模板专用正文：把更新说明按行拆成「圆点条目」清单
  ///   —— 与其它模板的整段文字排版是**结构级差异**
  Widget _listBody() {
    if (_phase != 'idle') return _progressBody();
    final isDark = context.isDark;
    final lines = _contentToText(widget.content)
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return _currentBody();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: C.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 13.4,
                        height: 1.55,
                        color: isDark ? C.t2 : C.lt2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────── 模板⑦ meta 信息双列（2×2 数据网格 —— 经典耐看款）───────────
  Widget _tplMeta() {
    final isDark = context.isDark;
    final line = isDark ? Colors.white24 : Colors.black12;
    return _shell(
      radius: 20,
      top: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: C.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title.isEmpty ? '发现新版本' : widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? C.t1 : C.lt1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '建议在 WiFi 环境下载',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? C.t3 : C.lt3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 2×2 数据网格
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: line),
              bottom: BorderSide(color: line),
            ),
          ),
          child: Column(
            children: [
              _metaRow(isDark, [
                ('版本号', 'v${widget.version}'),
                ('安装包', _sizeText(_total).isEmpty ? '—' : _sizeText(_total)),
              ]),
              Divider(height: 1, color: line),
              _metaRow(isDark, [
                ('发布时间', _today()),
                ('更新类型', widget.forced ? '强制' : '可选'),
              ]),
            ],
          ),
        ),
      ],
      bottom: [_actions()],
    );
  }

  /// 双列数据行：两格 + 中间 1px 分隔
  Widget _metaRow(bool isDark, List<(String, String)> cells) {
    final line = isDark ? Colors.white24 : Colors.black12;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, thickness: 1, color: line),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cells[i].$1,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? C.t3 : C.lt3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cells[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? C.t1 : C.lt1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────── 模板⑧ triple 三列数据条（版本 | 大小 | 日期 横排三格）───────────
  Widget _tplTriple() {
    final isDark = context.isDark;
    final line = isDark ? Colors.white24 : Colors.black12;
    final items = [
      ('当前版本', 'v${widget.version}'),
      ('安装包', _sizeText(_total).isEmpty ? '—' : _sizeText(_total)),
      ('日期', _today()),
    ];
    return _shell(
      radius: 22,
      top: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Text(
            widget.title.isEmpty ? '发现新版本' : widget.title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: isDark ? C.t1 : C.lt1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: line),
              bottom: BorderSide(color: line),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    VerticalDivider(width: 1, thickness: 1, color: line),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 6,
                      ),
                      child: Column(
                        children: [
                          Text(
                            items[i].$2,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? C.t1 : C.lt1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            items[i].$1,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? C.t3 : C.lt3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      bottom: [_actions()],
    );
  }

  // ─────────── 模板⑨ timeline 更新时间线（左侧竖线 + 节点，逐条）───────────
  Widget _tplTimeline() {
    final isDark = context.isDark;
    return _shell(
      radius: 20,
      body: _timelineBody(),
      top: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: C.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title.isEmpty ? '本次更新要点' : widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? C.t1 : C.lt1,
                  ),
                ),
              ),
              Text(
                'v${widget.version}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: C.brand,
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: [_actions()],
    );
  }

  /// timeline 模板正文：左侧竖线 + 圆点 + 右侧文字
  Widget _timelineBody() {
    if (_phase != 'idle') return _progressBody();
    final isDark = context.isDark;
    final lines = _contentToText(widget.content)
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return _currentBody();
    final line = isDark ? Colors.white24 : Colors.black12;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < lines.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: i == 0
                                ? C.brand
                                : (isDark ? Colors.white30 : Colors.black26),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i != lines.length - 1)
                          Expanded(child: Container(width: 1.4, color: line)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        lines[i],
                        style: TextStyle(
                          fontSize: 13.4,
                          height: 1.55,
                          color: isDark ? C.t2 : C.lt2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 今天的日期（list 模板用）
  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
