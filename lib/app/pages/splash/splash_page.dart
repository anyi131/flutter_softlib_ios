import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';

import '../../../generated/assets.dart';
import '../../api/soft_service.dart';
import '../../design/ui.dart';
import '../../api/user_service.dart';
import '../../models/app_config.dart';
import '../../routes/app_pages.dart';
import '../../utils/jump_util.dart';
import '../../utils/local_splash.dart';

/// 启动页：远程开屏图 + 倒计时 + 公告弹窗（后台可下发，无需发版）
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  AppConfig? _config;
  int _left = 2;
  Timer? _timer;
  bool _entered = false;
  /// 启动诊断：显示当前卡点（release 可见）
  String _diag = 'boot:start';

  /// 本地自定义开屏图路径（用户「替换开屏」选过才有）
  String _localSplash = '';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    // ★ 本地开屏图 与 服务器配置 并行拉取（避免串行等待导致启动变慢）
    // v331b：整体兜底 8 秒——无论配置/权限/任何环节挂起，超时必进主界面
    final localFuture = LocalSplash.get().timeout(
        const Duration(seconds: 5), onTimeout: () => '');
    final cfgFuture = SoftService.instance
        .fetchConfig()
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (mounted) setState(() => _diag = 'boot:awaiting');
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_entered) _enter();
    });

    _localSplash = await localFuture;
    if (mounted) setState(() => _diag = 'boot:local done');
    if (mounted && _localSplash.isNotEmpty) {
      setState(() {});
    }

    if (mounted) setState(() => _diag = 'boot:awaiting cfg');
    final cfg = await cfgFuture;
    if (mounted) setState(() => _diag = 'boot:cfg done');
    if (!mounted) return;

    // 维护模式：直接显示维护页，不进入主界面
    if (cfg != null && cfg.maintainEnable) {
      setState(() => _config = cfg);
      return;
    }

    final seconds = (cfg?.splashEnable ?? true)
        ? (cfg?.splashSeconds ?? 2).clamp(1, 10)
        : 0;
    setState(() {
      _config = cfg;
      _left = seconds;
    });

    if (seconds <= 0) {
      _enter();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _enter();
      }
    });
  }

  /// 进入主界面（并弹出公告）
  void _enter() {
    if (_entered || !mounted) return;
    _entered = true;
    if (mounted) setState(() => _diag = 'enter:navigating');
    Navigator.of(context).pushReplacementNamed(Routes.index);
    final cfg = _config;
    // v52p #11：后台功能开关 notice=0 → 启动公告也不弹
    final noticeOn =
        (SoftService.instance.cachedConfig?.uiConfig.featureNotice ?? true);
    if (cfg != null &&
        noticeOn &&
        cfg.noticeEnable &&
        cfg.noticeContent.trim().isNotEmpty) {
      // 等主界面挂载后再弹公告
      Future.delayed(const Duration(milliseconds: 600), () {
        _showNotice(cfg);
      });
    }
  }

  /// 公告用：全局主题明暗（**不依赖可能已销毁的 State context**）
  bool _noticeIsDark() {
    try {
      final c = Get.context;
      if (c == null) return false;
      return Theme.of(c).brightness == Brightness.dark;
    } catch (_) {
      return false;
    }
  }

  /// 公告弹窗
  /// v52m #6：开屏三模板 fullscreen / banner / fade
  Widget _splashBody(AppConfig? cfg, String netImg) {
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.splashTemplate ??
        'fullscreen';
    final title = cfg?.splashTitle ?? '';
    final desc = cfg?.splashDesc ?? '';

    if (tpl == 'split') {
      // v52t：左右分栏（左文字/logo，右图）
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    Assets.imagesApp,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                if (title.isNotEmpty)
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: C.brand,
                    ),
                  ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: _localSplash.isNotEmpty
                ? Image.file(
                    File(_localSplash),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultSplash(),
                  )
                : _defaultSplash(),
          ),
        ],
      );
    }
    if (tpl == 'greeting') {
      // v52t：时段问候 + 渐变底
      final h = DateTime.now().hour;
      final greet = h < 5
          ? '夜深了'
          : h < 11
          ? '早上好'
          : h < 14
          ? '中午好'
          : h < 18
          ? '下午好'
          : '晚上好';
      return Container(
        decoration: BoxDecoration(gradient: C.brandGradient),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              greet,
              style: TextStyle(
                color: Colors.white.withAlpha(190),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 13.5,
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (tpl == 'poster_center') {
      // v52w：居中海报框（图片带边框阴影居中）
      return Container(
        color: context.isDark ? C.bg1 : const Color(0xFFF2F4F8),
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  width: 220,
                  height: 300,
                  child: _localSplash.isNotEmpty
                      ? Image.file(
                          File(_localSplash),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultSplash(),
                        )
                      : _defaultSplash(),
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (title.isNotEmpty)
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: context.isDark ? C.t1 : C.lt1,
                ),
              ),
          ],
        ),
      );
    }
    if (tpl == 'brand_bar') {
      // v52w：全屏图 + 底部品牌条（渐变条+标题白字）
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_localSplash.isNotEmpty)
            Image.file(
              File(_localSplash),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultSplash(),
            )
          else
            _defaultSplash(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(70),
                    Colors.black.withAlpha(185),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // 渐变短 accent 条
                  Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: C.brandGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  // 品牌胶囊条：图标 + 名称（毛玻璃质感）
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(24),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withAlpha(42)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            Assets.imagesApp,
                            width: 22,
                            height: 22,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '安逸软件汇',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _diag,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (tpl == 'fade') {
      // 品牌渐变 + 淡入标题（不用大图）
      return Container(
        decoration: BoxDecoration(gradient: C.brandGradient),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                Assets.imagesApp,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (tpl == 'banner') {
      // 浅底 + 上图（圆角卡）+ 下标题
      return SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _localSplash.isNotEmpty
                      ? Image.file(
                          File(_localSplash),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultSplash(),
                        )
                      : _defaultSplash(),
                ),
              ),
            ),
            const Spacer(),
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF181818),
                ),
              ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                desc,
                style: TextStyle(fontSize: 13.5, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 46),
          ],
        ),
      );
    }

    // fullscreen（原版）：全屏图 + 底部标题
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_localSplash.isNotEmpty)
          Image.file(
            File(_localSplash),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultSplash(),
          )
        else
          _defaultSplash(),
        if (title.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF181818),
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _showNotice(AppConfig cfg) {
    // ★ 渲染失败绝不白屏：任何异常都静默降级为「不弹公告」
    try {
      _showNoticeInner(cfg);
    } catch (_) {}
  }

  void _showNoticeInner(AppConfig cfg) {
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.noticeTemplate ?? 'card';
    final dark = _noticeIsDark();
    final actions = [
      if (cfg.noticeUrl.isNotEmpty)
        TextButton(
          onPressed: () {
            JumpUtil.openUrl(cfg.noticeUrl);
            if (!cfg.noticeForce) Navigator.of(Get.context!).pop();
          },
          child: const Text('查看详情'),
        ),
      if (!cfg.noticeForce)
        FilledButton(
          onPressed: () => Navigator.of(Get.context!).pop(),
          child: const Text('我知道了'),
        ),
    ];
    final pageBg = dark ? C.bg1 : Colors.white;
    final cardBg = dark ? C.bg2 : Colors.white;
    final content = (double size, double height) => HtmlWidget(
      cfg.noticeContent,
      textStyle: TextStyle(fontSize: size, height: height),
    );

    // card：紧凑对话框（图标章 + 分隔线 + 右对齐按钮行），最轻量的一套
    if (tpl == 'card') {
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        barrierColor: Colors.black.withAlpha(dark ? 140 : 90),
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(dark ? 70 : 44),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: C.brandGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cfg.noticeTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(height: 1, color: ctx.t3.withAlpha(28)),
                        const SizedBox(height: 14),
                        Flexible(
                          child: SingleChildScrollView(
                            child: content(14, 1.65),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (cfg.noticeUrl.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  JumpUtil.openUrl(cfg.noticeUrl);
                                  if (!cfg.noticeForce) {
                                    Navigator.of(Get.context!).pop();
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: ctx.t2,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  '查看详情',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (!cfg.noticeForce)
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(Get.context!).pop(),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '我知道了',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    // banner：中屏布局 —— 顶部横幅固定 + 内容独立滚动 + 底部固定整宽按钮
    if (tpl == 'banner') {
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        barrierColor: Colors.black.withAlpha(dark ? 150 : 100),
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 560),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(dark ? 86 : 52),
                    blurRadius: 36,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部横幅（固定，不随内容滚动）
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: BoxDecoration(gradient: C.brandGradient),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(44),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NOTICE · 公告',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cfg.noticeTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 内容独立滚动
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: content(15, 1.7),
                    ),
                  ),
                  // 底部固定按钮
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(
                        top: BorderSide(
                          color: ctx.t3.withAlpha(dark ? 36 : 24),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (cfg.noticeUrl.isNotEmpty) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                JumpUtil.openUrl(cfg.noticeUrl);
                                if (!cfg.noticeForce) {
                                  Navigator.of(Get.context!).pop();
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: C.brand.withAlpha(90)),
                              ),
                              child: const Text(
                                '查看详情',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (!cfg.noticeForce)
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(Get.context!).pop(),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '我知道了',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    // minimal：纯文字排版 —— 无卡片容器、无渐变，仅字重/细线/留白分层
    if (tpl == 'minimal') {
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        barrierColor: dark ? Colors.black.withAlpha(150) : Colors.black38,
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '公告 · NOTICE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: C.brand,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cfg.noticeTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 23,
                      height: 1.3,
                      color: ctx.t1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('发布于今天', style: TextStyle(fontSize: 12, color: ctx.t3)),
                  const SizedBox(height: 18),
                  Container(height: 1, color: ctx.t3.withAlpha(dark ? 56 : 36)),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(child: content(15, 1.9)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cfg.noticeUrl.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            JumpUtil.openUrl(cfg.noticeUrl);
                            if (!cfg.noticeForce) {
                              Navigator.of(Get.context!).pop();
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: ctx.t2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          child: const Text('查看详情'),
                        ),
                      const SizedBox(width: 8),
                      if (!cfg.noticeForce)
                        TextButton(
                          onPressed: () => Navigator.of(Get.context!).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: C.brand,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          child: const Text('知道了'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    // sheet：底部面板 —— 圆角把手 + 分组内容卡 + 整宽按钮
    if (tpl == 'sheet') {
      showModalBottomSheet(
        context: Get.context!,
        isDismissible: !cfg.noticeForce,
        enableDrag: !cfg.noticeForce,
        isScrollControlled: true,
        backgroundColor: cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部圆角把手
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: ctx.t3.withAlpha(dark ? 90 : 60),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cfg.noticeTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: ctx.t1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '公告',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: ctx.t3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 分组内容：浅色分组容器承载正文
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ctx.t3.withAlpha(dark ? 16 : 10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: content(14.5, 1.65),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 整宽按钮
                if (cfg.noticeUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        JumpUtil.openUrl(cfg.noticeUrl);
                        if (!cfg.noticeForce) {
                          Navigator.of(Get.context!).pop();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: C.brand.withAlpha(90)),
                      ),
                      child: const Text('查看详情', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                if (cfg.noticeUrl.isNotEmpty) const SizedBox(height: 10),
                if (!cfg.noticeForce)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(Get.context!).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('我知道了', style: TextStyle(fontSize: 15)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    if (tpl == 'fullscreen') {
      // 全屏沉浸：渐变 Hero 头图 + 上浮圆角内容卡 + 底部整宽按钮
      Navigator.of(Get.context!).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => Scaffold(
            backgroundColor: pageBg,
            body: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 260,
                      width: double.infinity,
                      decoration: BoxDecoration(gradient: C.brandGradient),
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 52),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(44),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            cfg.noticeTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(24),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 40,
                      bottom: 40,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(20),
                        ),
                      ),
                    ),
                    if (!cfg.noticeForce)
                      Positioned(
                        top: 14,
                        right: 10,
                        child: IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: -24,
                        bottom: 0,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: pageBg,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(22, 50, 22, 12),
                          child: SingleChildScrollView(
                            child: content(15, 1.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: actions.isNotEmpty
                          ? Row(
                              children: [
                                for (final a in actions) Expanded(child: a),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // banner_card：横向布局卡 —— 左侧渐变色条 + 右上角日期戳，唯一横排骨架
    if (tpl == 'banner_card') {
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        barrierColor: Colors.black.withAlpha(dark ? 150 : 95),
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(dark ? 80 : 46),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // 主内容（左侧留出色条空间）
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '重要通知',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: ctx.t3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 右上角日期戳
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: C.brand.withAlpha(dark ? 36 : 22),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: C.brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                          child: Text(
                            cfg.noticeTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                              color: ctx.t1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                          child: Container(
                            height: 1,
                            color: ctx.t3.withAlpha(dark ? 36 : 24),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 340),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                            child: content(14.5, 1.65),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                          child: Row(
                            children: [
                              if (cfg.noticeUrl.isNotEmpty) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      JumpUtil.openUrl(cfg.noticeUrl);
                                      if (!cfg.noticeForce) {
                                        Navigator.of(Get.context!).pop();
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(
                                        color: C.brand.withAlpha(90),
                                      ),
                                    ),
                                    child: const Text(
                                      '查看详情',
                                      style: TextStyle(fontSize: 14.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (!cfg.noticeForce)
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () =>
                                        Navigator.of(Get.context!).pop(),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '我知道了',
                                      style: TextStyle(fontSize: 14.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 左侧渐变色条（贯穿全高）
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 8,
                    child: Container(
                      decoration: BoxDecoration(gradient: C.brandGradient),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    // card（原版兜底）：保留默认 AlertDialog
    showDialog(
      context: Get.context!,
      barrierDismissible: !cfg.noticeForce,
      builder: (ctx) => PopScope(
        canPop: !cfg.noticeForce,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFF465CFF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cfg.noticeTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: content(14.5, 1.6),
          actions: actions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 维护模式
    if (_config?.maintainEnable == true) {
      return Scaffold(
        backgroundColor: const Color(0xFF1F1F1F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 72,
                  color: Color(0xFF465CFF),
                ),
                const SizedBox(height: 20),
                const Text(
                  '系统维护中',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  (_config?.maintainText ?? '').isEmpty
                      ? '请稍后再试'
                      : _config?.maintainText ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 26),
                OutlinedButton(
                  onPressed: _boot,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('重新加载'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cfg = _config;
    // ★ 开屏图优先级（用户 #9 的要求）：
    //   ① 用户「替换开屏」选的本地图（本地文件，秒开）
    //   ② 用户存在服务器上的自定义图（老数据兼容 / 换机后）
    //   ③ 后台下发的全局开屏图
    //   ④ 内置默认开屏
    final userSplash = UserService.instance.user?.splashImage ?? '';
    final netImg = userSplash.isNotEmpty
        ? userSplash
        : (cfg?.splashImage ?? '');
    return Scaffold(
      backgroundColor: Colors.white,
      body: _splashBody(cfg, netImg),
    );
  }

  /// 默认开屏（后台未设置图片时）
  Widget _defaultSplash() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF465CFF), Color(0xFF7B8CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(Assets.imagesApp, width: 104, height: 104),
          ),
          const SizedBox(height: 22),
          const Text(
            '安逸软件汇',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '优质软件 · 持续更新',
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
