import 'dart:async';

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

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
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
    // 模板：后台 ui_config.update_template 下发（取不到用 classic）
    String template = 'classic';
    try {
      final cfg = await SoftService.instance.fetchConfig();
      final t = cfg?.uiConfig.updateTemplate ?? '';
      if (t.isNotEmpty) template = t;
    } catch (_) {}
    if (url.isEmpty) return;
    showDialog(
      context: Get.context!,
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
    // 解析直链
    String? direct = widget.url;
    if (widget.url.contains('lanzou') || widget.url.contains('lzy')) {
      try {
        direct = await SoftService.instance.resolveLzy(widget.url);
      } catch (_) {
        direct = null;
      }
    }
    if (direct == null || direct.isEmpty) {
      // ★ 1014：解析失败（未登录/无票据/接口异常）时，提示可改用浏览器下载，
      //   而不是静默失败。App 自身更新包属可信来源，允许直接打开。
      if (mounted) {
        ToastUtil.info('将用浏览器打开下载页（也可在软件详情页下载）');
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
        await Future.delayed(const Duration(milliseconds: 500));
        final path = '${tk.savedDir}/${tk.filename}';
        try {
          await ApkInstaller.install(path);
        } catch (_) {}
        if (mounted && !widget.forced) Navigator.of(context).pop();
      } else if (tk.status == DownloadTaskStatus.failed ||
          tk.status == DownloadTaskStatus.canceled) {
        t.cancel();
        setState(() => _phase = 'failed');
      }
    });
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

  /// ★ 1014：把后台填写的更新说明转成 HTML。
  /// 后台常用「回车换行」分隔条目，但 HtmlWidget 按 HTML 解析，
  /// 纯文本中的 \n 会被折叠成空格 → 显示成一大段。
  /// 这里：未含 HTML 标签时，把换行转成 <br>；已是 HTML 则原样保留。
  String _contentToHtml(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final hasHtml = RegExp(r'<[a-zA-Z/][^>]*>').hasMatch(t);
    if (hasHtml) return t; // 后台自己写了 HTML → 直接用
    // 纯文本：转义后换行变 <br>
    return t
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', '<br>');
  }

  String _sizeText(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / 1048576;
    return '${mb.toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    // ★ v3.3.4 更新弹窗模板体系重做：
    //   旧 7 款只是「同一张卡换头图/换底色」，用户反馈「都是同款换色」。
    //   新 8 款是**骨架级**差异：信息架构、动线、底部操作区各不相同。
    //   旧模板名做了向后兼容映射（后台存的旧值不会白屏）。
    final tpl = switch (widget.template) {
      'minimal' => 'minimal', // 保持：极简竖条 → 已重做
      'dark' => 'neon', // 暗黑 → 暗夜霓虹
      'poster' => 'poster', // 保持：海报大字
      'compact' => 'meta', // 紧凑 → 信息双列
      'ticket' => 'ticket', // 保持：更新券
      'side' => 'banner', // 左竖条 → 通告条
      'aurora' => 'aurora',
      'neon' => 'neon',
      'banner' => 'banner',
      'combo' => 'combo',
      'meta' => 'meta',
      final v => v,
    };
    return switch (tpl) {
      'minimal' => _tplMinimal(),
      'neon' => _tplNeon(),
      'poster' => _tplPoster(),
      'meta' => _tplMeta(),
      'ticket' => _tplTicket(),
      'banner' => _tplBanner(),
      'combo' => _tplCombo(),
      _ => _tplAurora(),
    };
  }

  // ═══════════════════════════════════════════════════════════════
  //  v3.3.4 更新弹窗 8 款骨架级模板
  //
  //  设计原则（用户反馈「都是同款换色」后重做）：
  //    每款的信息架构、动线、底部操作区都不同，
  //    而不仅仅是换头图/换底色。
  //
  //    ① aurora  流光玻璃  渐变 Hero + 上浮玻璃日志卡
  //    ② minimal 极简竖条  零装饰，左竖条 + 纯文字 + 双按钮
  //    ③ neon    暗夜霓虹  深底 + 霓虹描边 + 发光进度
  //    ④ ticket  更新券    票券打孔 + 虚线撕口 + 信息栏
  //    ⑤ poster  海报大字  版本号当主角 + 满血渐变
  //    ⑥ meta    信息双列  版本/大小/时间 数据网格
  //    ⑦ banner  通告条    顶部通栏 + 大留白正文
  //    ⑧ combo   图标双钮  拖拽手柄 + 大图标 + 三键行
  // ═══════════════════════════════════════════════════════════════

  /// 模板① aurora —— 流光玻璃：渐变 Hero 头 + 上浮玻璃日志卡
  Widget _tplAurora() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(isDark ? 60 : 70),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变 Hero：内部叠两个半透明圆做流光
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
                  decoration: BoxDecoration(gradient: Deco.brandGradient),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.rocket_launch_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              widget.title.isEmpty ? '发现新版本' : widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(60),
                          borderRadius: BorderRadius.circular(R.full),
                        ),
                        child: Text(
                          'v${widget.version} · 全新体验',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 装饰光斑
                Positioned(
                  right: -40,
                  top: -50,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(34),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            // 日志卡上浮叠在 Hero 上
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: isDark ? C.bg1 : Colors.white,
                    borderRadius: BorderRadius.circular(R.md),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 60 : 14),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _scrollBody(isDark),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: _actionRow(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 模板⑥ meta —— 信息双列：版本/大小/时间 数据网格
  Widget _tplMeta() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 70 : 18),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: Deco.brandGradient,
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
            // 数据网格：2 列，中间用 1px 分隔线
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(14)
                        : Colors.black.withAlpha(8),
                  ),
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(14)
                        : Colors.black.withAlpha(8),
                  ),
                ),
              ),
              child: Column(
                children: [
                  _metaRow(isDark, [
                    ('版本号', 'v${widget.version}'),
                    ('安装包', _sizeText(_total)),
                  ]),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withAlpha(14)
                        : Colors.black.withAlpha(8),
                  ),
                  _metaRow(isDark, [
                    ('发布时间', _today()),
                    ('强制更新', widget.forced ? '是' : '否'),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: _scrollBody(isDark),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: _actionRow(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(bool isDark, List<(String, String)> cells) {
    return Row(
      children: [
        for (int i = 0; i < cells.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 34,
              color: isDark
                  ? Colors.white.withAlpha(14)
                  : Colors.black.withAlpha(8),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cells[i].$1,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? C.t3 : C.lt3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cells[i].$2.isEmpty ? '—' : cells[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark ? C.t1 : C.lt1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 模板⑦ banner —— 通告条：顶部通栏 + 大留白正文 + 文字「稍后提醒我」
  Widget _tplBanner() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 70 : 18),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 通栏条：左右到边，无圆角（与卡同宽）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [C.brand, C.brandBright],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '版本更新通知 · v${widget.version}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: _scrollBody(isDark),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: _actionRow(isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// 模板⑧ combo —— 图标双钮：拖拽手柄 + 大图标 + 三键行
  Widget _tplCombo() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 80 : 22),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖拽手柄
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(30)
                      : Colors.black.withAlpha(20),
                  borderRadius: BorderRadius.circular(R.full),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: Deco.brandGradient,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '安逸软件汇',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? C.t1 : C.lt1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'v${widget.version} 已发布'
                          '${_total > 0 ? ' · ${_sizeText(_total)}' : ''}',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: _scrollBody(isDark),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: _actionRow(isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// 模板② minimal —— 极简竖条
  /// 骨架：零装饰（无头图/无渐变头/无阴影），左竖条 + 时间副标 + 纯文字 + 深色实心主按钮
  Widget _tplMinimal() {
  /// 模板③ neon —— 暗夜霓虹
  /// 骨架：深底 + 霓虹描边 + 顶部状态行 + 发光进度条 + 等宽数字
  Widget _tplNeon() {
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: C.bg0,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: C.brandBright.withAlpha(110), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(70),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部状态行：信号灯 + 版本（像终端状态栏）
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, color: C.brandBright, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NEW · v${widget.version}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: C.brandBright,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: C.mint,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: C.mint.withAlpha(160), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'READY',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: C.mint.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
            _tplBody(true),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: _actionRow(true),
            ),
          ],
        ),
      ),
    );
  }

    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: Deco.brandGradient,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '发现新版本 v${widget.version}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? C.t1 : C.lt1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _tplBody(isDark),
            const SizedBox(height: 14),
            _actionRow(isDark),
          ],
        ),
      ),
    );
  }

  /// 正文滚动区（各模板共用，替代旧的 _tplBody 命名）
  /// 模板④ ticket —— 更新券
  /// 骨架：票券打孔（两侧半圆缺口）+ 虚线撕口 + 三格信息栏 + 底部圆角主按钮
  Widget _tplTicket() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(isDark ? 45 : 60),
              blurRadius: 28,
              offset: const Offset(0, 11),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: Deco.brandGradient,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '新版本 v${widget.version}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? C.t1 : C.lt1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '安逸软件汇 · 更新券',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? C.t3 : C.lt3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(isDark ? 36 : 22),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '官方',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: C.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 撕口：左右半圆缺口 + 虚线
            SizedBox(
              height: 18,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 14,
                    right: 14,
                    child: CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DashLinePainter(
                        color: isDark
                            ? Colors.white.withAlpha(30)
                            : Colors.black.withAlpha(24),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -9,
                    child: _notch(isDark),
                  ),
                  Positioned(
                    right: -9,
                    child: _notch(isDark),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 2),
              child: _tplBody(isDark),
            ),
            // 三格信息栏
            Container(
              margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(14)
                        : Colors.black.withAlpha(8),
                  ),
                ),
              ),
              child: Row(
                children: [
                  for (final c in [
                    ('版本', 'v${widget.version}'),
                    ('大小', _total > 0 ? _sizeText(_total) : '—'),
                    ('类型', widget.forced ? '强制' : '正式版'),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          children: [
                            Text(
                              c.$1,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? C.t3 : C.lt3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              c.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? C.t1 : C.lt1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: _actionRow(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notch(bool isDark) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: isDark ? C.bg1 : const Color(0xFFF1F3F9),
      shape: BoxShape.circle,
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
      ),
    ),
  );

  /// 模板⑤ poster —— 海报大字
  /// 骨架：版本号当主角（超大字） + 满血渐变满卡 + 内嵌白卡承载正文
  Widget _tplPoster() {
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: Deco.brandGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(90),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 4),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(46),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'v${widget.version}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title.isEmpty ? '安逸软件汇 · 发现新版本' : widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tplBody(false),
                  const SizedBox(height: 12),
                  _actionRow(false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scrollBody(bool isDark) => _tplBody(isDark);

  /// 今天的日期（meta 模板用）
  String _today() {
    final d = DateTime.now();
    return '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
  /// 正文区（更新日志 / 进度态）——各模板共用
  Widget _tplBody(bool isDark) {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
        child: _phase == 'idle'
            ? HtmlWidget(
                // ★ 1014：后台填写的更新说明常用「换行」分隔，
                //   但 HtmlWidget 按 HTML 解析 —— 纯文本里的 \n 会被
                //   当成空白折叠（不换行），必须转成 <br>。
                _contentToHtml(widget.content),
                textStyle: TextStyle(
                  fontSize: 13.8,
                  height: 1.65,
                  color: isDark ? C.t2 : C.lt2,
                ),
                onTapUrl: (u) {
                  JumpUtil.openUrl(u);
                  return true;
                },
              )
            : _progressBody(isDark),
      ),
    );
  }

  Widget _progressBody(bool isDark) {
    if (_phase == 'done') {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: C.success, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '下载完成，正在安装…',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? C.t1 : C.lt1,
              ),
            ),
          ),
        ],
      );
    }
    if (_phase == 'failed') {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: C.danger, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '下载失败，请重试或用浏览器下载',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: isDark ? C.t1 : C.lt1,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _progress / 100,
                    strokeWidth: 3,
                    backgroundColor: C.brand.withAlpha(isDark ? 46 : 28),
                    valueColor: AlwaysStoppedAnimation(C.brand),
                  ),
                  Text(
                    '$_progress%',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: C.brand,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在下载更新包…',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? C.t1 : C.lt1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _total > 0
                        ? '${_sizeText((_progress * _total / 100).round())} / ${_sizeText(_total)}'
                        : '已下载 $_progress%',
                    style: TextStyle(fontSize: 11.5, color: context.t3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress / 100),
            duration: AppAnim.base,
            curve: AppAnim.emphasized,
            builder: (c, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: C.brand.withAlpha(isDark ? 36 : 22),
              valueColor: AlwaysStoppedAnimation(C.brand),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionRow(bool isDark) {
    if (_phase == 'downloading') {
      return const SizedBox(height: 6);
    }
    // 失败态：关闭 / 浏览器下载 / 重试（v52f #1）
    if (_phase == 'failed') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: isDark ? C.t3.withAlpha(80) : C.lt3.withAlpha(70),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                '关闭',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? C.t2 : C.lt2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: _fallbackBrowser,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: C.brand.withAlpha(120)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded, size: 16, color: C.brand),
                  const SizedBox(width: 5),
                  Text(
                    '浏览器下载',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: C.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppPressable(
              onTap: () => setState(() => _phase = 'idle'),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: C.brandGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '重试',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        if (!widget.forced) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: isDark ? C.t3.withAlpha(80) : C.lt3.withAlpha(70),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                '稍后再说',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? C.t2 : C.lt2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        // ★ 1014 新增：浏览器下载（用原链接）
        //   App 内解析失败或想用外部浏览器时，直接打开原始下载链接。
        Expanded(
          flex: 2,
          child: AppPressable(
            onTap: _openInBrowser,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? C.bg2 : const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark ? C.t3.withAlpha(80) : C.lt3.withAlpha(70),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_browser_rounded,
                      size: 17, color: isDark ? C.t2 : C.lt2),
                  const SizedBox(width: 6),
                  Text(
                    '浏览器下载',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? C.t2 : C.lt2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: AppPressable(
            onTap: _start,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: C.brandGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: C.brand.withAlpha(70),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                '立即更新',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 虚线画笔（ticket 模板的撕口线）
class _DashLinePainter extends CustomPainter {
  final Color color;
  _DashLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 5.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashLinePainter old) => old.color != color;
}
