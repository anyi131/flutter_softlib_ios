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
                Icon(Icons.rocket_launch_rounded,
                    color: C.brand, size: 52),
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
              padding: const EdgeInsets.fromLTRB(0, 40, 0, 46),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(160),
                  ],
                ),
              ),
              child: Column(
                children: [
                  if (title.isNotEmpty)
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(desc,
                        style: TextStyle(
                            color: Colors.white.withAlpha(190),
                            fontSize: 12.5)),
                  ],
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
            const Icon(Icons.rocket_launch_rounded,
                color: Colors.white, size: 64),
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
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.noticeTemplate ?? 'card';
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
    final body = SingleChildScrollView(
      child: HtmlWidget(
        cfg.noticeContent,
        textStyle: const TextStyle(fontSize: 14.5, height: 1.6),
      ),
    );

    // v52m #9：公告三模板 card / banner / minimal
    if (tpl == 'banner') {
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: context.isDark ? C.bg2 : Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(gradient: C.brandGradient),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(cfg.noticeTitle,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5)),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: body,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
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
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: context.isDark ? C.bg2 : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                            gradient: C.brandGradient,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(cfg.noticeTitle,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(child: body),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    if (tpl == 'sheet') {
      // v52t：底部弹出
      showModalBottomSheet(
        context: Get.context!,
        isDismissible: !cfg.noticeForce,
        enableDrag: !cfg.noticeForce,
        backgroundColor: context.isDark ? C.bg2 : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                          color: context.t3.withAlpha(60),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: C.brand, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cfg.noticeTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: HtmlWidget(
                      cfg.noticeContent,
                      textStyle: const TextStyle(
                          fontSize: 14.5, height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (tpl == 'fullscreen') {
      // v52t：全屏公告页
      Navigator.of(Get.context!).push(MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: context.isDark ? C.bg1 : Colors.white,
          appBar: AppBar(
            title: Text(cfg.noticeTitle),
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: !cfg.noticeForce,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: HtmlWidget(
              cfg.noticeContent,
              textStyle: const TextStyle(fontSize: 15, height: 1.7),
            ),
          ),
          bottomNavigationBar: actions.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: actions),
                  ),
                ),
        ),
      ));
      return;
    }

    if (tpl == 'banner_card') {
      // v52w：渐变大横幅+圆角正文卡
      showDialog(
        context: Get.context!,
        barrierDismissible: !cfg.noticeForce,
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: C.brandGradient,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: Colors.white, size: 30),
                      const SizedBox(height: 8),
                      Text(cfg.noticeTitle,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Container(
                  color: context.isDark ? C.bg2 : Colors.white,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: HtmlWidget(
                            cfg.noticeContent,
                            textStyle: const TextStyle(
                                fontSize: 14.5, height: 1.65),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // card（原版）
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
          content: body,
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
