import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';

import '../../api/soft_service.dart';
import '../../design/app_anim.dart';
import '../../design/ui.dart';
import '../../utils/apk_installer.dart';
import '../../utils/install_helper.dart';
import '../../utils/jump_util.dart';
import '../../utils/platform_util.dart';
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
      _fallbackBrowser();
      return;
    }
    setState(() => _phase = 'downloading');
    // ★ 跨平台：Android 仍是 /storage/emulated/0/Download（行为不变）；
    //   iOS 为沙盒 Documents/Download（iOS 不允许写沙盒外）
    final savedDir = await PlatUtil.downloadDir();
    final taskId = await FlutterDownloader.enqueue(
      url: direct,
      fileName: 'softlib_update_${DateTime.now().millisecondsSinceEpoch}.apk',
      savedDir: savedDir,
      showNotification: true,
      saveInPublicStorage: PlatUtil.saveInPublicStorage,
      openFileFromNotification: PlatUtil.openFileFromNotification,
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
        if (PlatUtil.isAndroid) {
          try {
            await ApkInstaller.install(path);
          } catch (_) {}
        } else {
          // iOS 不支持安装 APK → 降级为「存储/分享」或「用其他应用打开」
          await InstallHelper.openOnIos(path, name: tk.filename);
        }
        if (mounted && !widget.forced) Navigator.of(context).pop();
      } else if (tk.status == DownloadTaskStatus.failed ||
          tk.status == DownloadTaskStatus.canceled) {
        t.cancel();
        setState(() => _phase = 'failed');
      }
    });
  }

  void _fallbackBrowser() {
    JumpUtil.openUrl(widget.url);
  }

  String _sizeText(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / 1048576;
    return '${mb.toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.template) {
      'minimal' => _tplMinimal(),
      'dark' => _tplDark(),
      'poster' => _tplPoster(),
      'compact' => _tplCompact(),
      'ticket' => _tplTicket(),
      _ => _tplClassic(),
    };
  }

  /// 模板一：classic —— 渐变头图卡（原版增强：标题不再与版本徽章重复）
  Widget _tplClassic() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              decoration: BoxDecoration(gradient: C.brandGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '发现新版本',
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
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(46),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'v${widget.version} · 全新体验',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _tplBody(isDark),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
              child: _actionRow(isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// 模板二：minimal —— 极简白卡（左竖条标题，无头图）
  Widget _tplMinimal() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(24),
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
                    gradient: C.brandGradient,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '发现新版本 v${widget.version}',
                  style: TextStyle(
                    fontSize: 17.5,
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

  /// 模板三：dark —— 暗黑霓虹
  Widget _tplDark() {
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: C.bg0,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: C.brand.withAlpha(110), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(60),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: C.brandBright,
                    size: 24,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'NEW · v${widget.version}',
                      style: TextStyle(
                        color: C.brandBright,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _tplBody(true),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
              child: _actionRow(true),
            ),
          ],
        ),
      ),
    );
  }

  /// 模板四：poster —— 全卡渐变海报
  Widget _tplPoster() {
    return AppScaleIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: C.brandGradient,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 6),
              child: Column(
                children: [
                  const Icon(
                    Icons.system_update_alt_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v${widget.version}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tplBody(false),
                  const SizedBox(height: 10),
                  _actionRow(false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 模板六：ticket —— 票券风（两侧圆孔 + 虚线分隔）
  Widget _tplTicket() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: C.brandGradient,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.confirmation_number_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('升级通知',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? C.t1 : C.lt1)),
                        const SizedBox(height: 3),
                        Text('v${widget.version} 已发布',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? C.t3 : C.lt3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 虚线 + 打孔
            Row(
              children: [
                _ticketNotch(isDark, Alignment.centerLeft),
                Expanded(
                  child: LayoutBuilder(builder: (c, box) {
                    return Flex(
                      direction: Axis.horizontal,
                      mainAxisSize: MainAxisSize.max,
                      children: List.generate(
                          (box.maxWidth / 9).floor(), (i) {
                        return Container(
                          width: 5,
                          height: 1.4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: context.t3.withAlpha(70),
                        );
                      }),
                    );
                  }),
                ),
                _ticketNotch(isDark, Alignment.centerRight),
              ],
            ),
            _tplBody(isDark),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: _actionRow(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketNotch(bool isDark, Alignment align) {
    return Container(
      width: 20,
      height: 20,
      alignment: align,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: isDark ? C.bg1 : C.lbg1,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// 模板五：compact —— 紧凑小卡
  Widget _tplCompact() {
    final isDark = context.isDark;
    return AppScaleIn(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: C.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '发现新版本 v${widget.version}',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: isDark ? C.t1 : C.lt1,
              ),
            ),
            const SizedBox(height: 10),
            _tplBody(isDark),
            const SizedBox(height: 14),
            _actionRow(isDark),
          ],
        ),
      ),
    );
  }

  /// 正文区（更新日志 / 进度态）——各模板共用
  Widget _tplBody(bool isDark) {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
        child: _phase == 'idle'
            ? HtmlWidget(
                widget.content,
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
