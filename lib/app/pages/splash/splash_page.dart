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
    final localFuture = LocalSplash.get();
    final cfgFuture = SoftService.instance.fetchConfig();

    _localSplash = await localFuture;
    if (mounted && _localSplash.isNotEmpty) {
      setState(() {});
    }

    final cfg = await cfgFuture;
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
                  child: Image.asset(Assets.imagesApp,
                      width: 52, height: 52, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                if (title.isNotEmpty)
                  Text(title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: C.brand)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(desc,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: _localSplash.isNotEmpty
                ? Image.file(File(_localSplash),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultSplash())
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
            Text(greet,
                style: TextStyle(
                    color: Colors.white.withAlpha(190), fontSize: 15)),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc,
                  style: TextStyle(
                      color: Colors.white.withAlpha(200), fontSize: 13.5)),
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
                      offset: const Offset(0, 14)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  width: 220,
                  height: 300,
                  child: _localSplash.isNotEmpty
                      ? Image.file(File(_localSplash),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultSplash())
                      : _defaultSplash(),
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (title.isNotEmpty)
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: context.isDark ? C.t1 : C.lt1)),
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
            Image.file(File(_localSplash),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultSplash())
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
                    Text(title,
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
                                  offset: Offset(0, 2)),
                            ])),
                  ],
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(desc,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withAlpha(200), fontSize: 12.5)),
                  ],
                  const SizedBox(height: 18),
                  // 品牌胶囊条：图标 + 名称（毛玻璃质感）
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
                          child: Image.asset(Assets.imagesApp,
                              width: 22, height: 22, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 8),
                        const Text('安逸软件汇',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2)),
                      ],
                    ),
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
              child: Image.asset(Assets.imagesApp,
                  width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc,
                  style: TextStyle(
                      color: Colors.white.withAlpha(200), fontSize: 14)),
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
                      ? Image.file(File(_localSplash), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _defaultSplash())
                      : _defaultSplash(),
                ),
              ),
            ),
            const Spacer(),
            if (title.isNotEmpty)
              Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF181818))),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(desc,
                  style: TextStyle(fontSize: 13.5, color: Colors.grey[600])),
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
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF181818))),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(desc,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey[600])),
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

    // ─────────────────────────────────────────────────────────────
    // v53 公告 6 套模板全面重做：每套独立设计语言，一眼可辨
    // ─────────────────────────────────────────────────────────────

    if (tpl == 'card') {
      // 精致卡片：顶部彩色横条 + 圆角图标章 + 柔和投影
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
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: C.brand.withAlpha(dark ? 50 : 60),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部渐变横条
                  Container(
                    height: 6,
                    decoration: BoxDecoration(gradient: C.brandGradient),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: C.brandGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                  Icons.campaign_rounded,
                                  color: Colors.white,
                                  size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cfg.noticeTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    height: 1.3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(height: 1, color: ctx.t3.withAlpha(24)),
                        const SizedBox(height: 16),
                        Flexible(
                          child: SingleChildScrollView(child: content(14.5, 1.65)),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (cfg.noticeUrl.isNotEmpty)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    JumpUtil.openUrl(cfg.noticeUrl);
                                    if (!cfg.noticeForce) {
                                      Navigator.of(Get.context!).pop();
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    side: BorderSide(
                                        color: C.brand.withAlpha(90)),
                                  ),
                                  child: const Text('查看详情'),
                                ),
                              ),
                            if (cfg.noticeUrl.isNotEmpty)
                              const SizedBox(width: 10),
                            if (!cfg.noticeForce)
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      Navigator.of(Get.context!).pop(),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text('我知道了'),
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

    if (tpl == 'banner') {
      // 整宽渐变横幅 + 居中大标题 + 下探圆角内容卡
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        barrierColor: Colors.black.withAlpha(dark ? 150 : 100),
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(dark ? 90 : 50),
                    blurRadius: 44,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.fromLTRB(24, 30, 24, 40),
                        decoration: BoxDecoration(
                          gradient: C.brandGradient,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(46),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: Colors.white,
                                  size: 28),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              cfg.noticeTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  height: 1.3,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: -18,
                        top: -18,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(26),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -12,
                        bottom: -22,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                                child: content(14.5, 1.7)),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.of(Get.context!).pop(),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('我知道了'),
                            ),
                          ),
                          if (cfg.noticeUrl.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                JumpUtil.openUrl(cfg.noticeUrl);
                                if (!cfg.noticeForce) {
                                  Navigator.of(Get.context!).pop();
                                }
                              },
                              child: Text('查看详情 →',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      color: ctx.t2,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
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

    if (tpl == 'minimal') {
      // 极简排版：无图标无色块，大标题 + 细分隔线 + 充足留白
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        barrierColor: dark ? Colors.white.withAlpha(16) : Colors.black26,
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: cardBg,
            elevation: dark ? 0 : 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 36),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('公告',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: ctx.t3)),
                  const SizedBox(height: 10),
                  Text(cfg.noticeTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          height: 1.35)),
                  const SizedBox(height: 16),
                  Container(
                      height: 1,
                      color: ctx.t3.withAlpha(dark ? 40 : 28)),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(child: content(14.5, 1.75)),
                  ),
                  const SizedBox(height: 22),
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
                              textStyle: const TextStyle(
                                  fontSize: 14, letterSpacing: 0.5)),
                          child: const Text('查看详情'),
                        ),
                      const SizedBox(width: 8),
                      if (!cfg.noticeForce)
                        TextButton(
                          onPressed: () => Navigator.of(Get.context!).pop(),
                          style: TextButton.styleFrom(
                              foregroundColor: C.brand,
                              textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
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

    if (tpl == 'sheet') {
      // 底部弹出面板：拖动把手 + 图标徽章 + 整宽主按钮
      showModalBottomSheet(
        context: Get.context!,
        isDismissible: !cfg.noticeForce,
        enableDrag: !cfg.noticeForce,
        isScrollControlled: true,
        backgroundColor: cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: ctx.t3.withAlpha(70),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: C.brandGradient,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: C.brand.withAlpha(70),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.campaign_rounded,
                          color: Colors.white, size: 25),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(cfg.noticeTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 17)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: ctx.t3.withAlpha(22)),
                const SizedBox(height: 4),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: content(14.5, 1.65),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (cfg.noticeUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        JumpUtil.openUrl(cfg.noticeUrl);
                        if (!cfg.noticeForce) Navigator.of(Get.context!).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: C.brand.withAlpha(90)),
                      ),
                      child: const Text('查看详情'),
                    ),
                  ),
                if (cfg.noticeUrl.isNotEmpty) const SizedBox(height: 10),
                if (!cfg.noticeForce)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(Get.context!).pop(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('我知道了'),
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
      Navigator.of(Get.context!).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: pageBg,
          body: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 218,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: C.brandGradient,
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
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
                          child: const Icon(Icons.campaign_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 14),
                        Text(cfg.noticeTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.3)),
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
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 26),
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
                              top: Radius.circular(28)),
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
                              for (final a in actions)
                                Expanded(child: a),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ));
      return;
    }

    if (tpl == 'banner_card') {
      // 横幅 + 卡片组合：顶部渐变横幅，下方内容卡上浮交叠
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        barrierColor: Colors.black.withAlpha(dark ? 150 : 95),
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 128,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: C.brandGradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: C.brand.withAlpha(dark ? 40 : 80),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(44),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                    Icons.notifications_active_rounded,
                                    color: Colors.white,
                                    size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text('重 要 通 知',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(cfg.noticeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
                // 上浮内容卡
                Positioned(
                  left: 14,
                  right: 14,
                  top: 98,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 420),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: dark
                          ? Border.all(color: Colors.white.withAlpha(14))
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(dark ? 80 : 46),
                          blurRadius: 34,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                              child: content(14.5, 1.65)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFF465CFF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(cfg.noticeTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
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
                const Icon(Icons.construction_rounded,
                    size: 72, color: Color(0xFF465CFF)),
                const SizedBox(height: 20),
                const Text('系统维护中',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(
                  (_config?.maintainText ?? '').isEmpty
                      ? '请稍后再试'
                      : _config?.maintainText ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withAlpha(180), height: 1.6),
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
          const Text('安逸软件汇',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('优质软件 · 持续更新',
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
        ],
      ),
    );
  }
}
