import 'dart:async';
import 'dart:convert';

import '../../design/app_anim.dart';
import '../../utils/safe_ctx.dart';
import '../../utils/toast_util.dart';

import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:marquee/marquee.dart';

import '../../../generated/assets.dart';
import '../../api/soft_service.dart';
import '../../design/ui.dart';
import '../../design/glass.dart';
import '../../api/user_service.dart';
import '../../models/app_config.dart';
import '../../routes/app_pages.dart';
import '../guide/onboard_page.dart';
import '../../utils/jump_util.dart';
import '../../utils/local_splash.dart';
import 'maintain_page.dart';
import '../../design/kit.dart';

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

  /// 维护模式：配置确认开启后，倒计时不再放行
  bool _maintain = false;

  /// 正在执行 _enter（倒计时与兜底定时器可能同时触发）
  bool _entering = false;

  /// 配置请求：维护判定必须等它，但不能等本地图/开屏图
  Future<AppConfig?>? _cfgFuture;

  /// 配置已落地（成功 / 失败 / 超时都算）
  bool _cfgSettled = false;

  /// 维护页「重新加载」正在查配置（防连点）
  bool _reloading = false;

  /// 启动诊断：显示当前卡点（release 可见）
  String _diag = 'boot:start';

  /// 本地自定义开屏图路径（用户「替换开屏」选过才有）
  String _localSplash = '';

  /// ★ 1020：后台配置的开屏网络图（必应每日 / 随机竖图 / 自定义）
  ///   优先于本地开屏图；为空则回退本地图 → 再回退默认品牌页
  String _netSplash = '';

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

  /// 开始倒计时（可重复调用：会用新的剩余秒数覆盖）
  void _startCountdown(int seconds) {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _left = seconds;
      _diag = 'tick:$seconds';
    });
    if (seconds <= 0) {
      _enter();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        _left--;
        _diag = 'tick:$_left';
      });
      if (_left <= 0) {
        t.cancel();
        _enter();
      }
    });
  }

  /// 维护页「重新加载」：只复查配置，**不重启开屏倒计时**
  ///
  /// ★ 旧实现把这个按钮直接接到 _boot() —— 它会把 3 秒倒计时重新启动，
  ///   而倒计时到点就会 _enter() 进首页，于是连点几次「重试」反而能闯进主界面。
  Future<void> _reloadFromMaintain() async {
    if (_reloading) return;
    _reloading = true;
    _entering = false;
    AppConfig? cfg;
    try {
      cfg = await SoftService.instance.fetchConfig(force: true).timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );
    } catch (_) {}
    _reloading = false;
    if (!mounted) return;

    if (cfg == null) {
      ToastUtil.error('网络异常，请稍后再试');
      return;
    }
    if (cfg.maintainEnable) {
      setState(() {
        _config = cfg;
        _diag = 'maintain:still';
      });
      ToastUtil.info('仍在维护中，请稍后再试');
      return;
    }

    // 维护已结束 → 直接进主界面（用户已经等过了，不再走 3 秒开屏）
    _maintain = false;
    setState(() {
      _config = cfg;
      _diag = 'maintain:off';
    });
    await _enter();
  }

  /// 启动流程
  ///
  /// ★★ 1020 启动提速（用户反馈「启动图太慢」）：
  ///   原来必须等 config 接口返回（最多 8 秒）**之后**才开始倒计时，
  ///   等于「网络耗时 + 展示时长」叠加，冷启动很慢。
  ///   现在：
  ///     1. 先用上次缓存的开屏图和秒数**立即开始倒计时**（零等待）
  ///     2. 配置与图片在后台并行拉，回来只做「纠正」（改图/改时长/关开屏）
  ///     3. 整体兜底从 8 秒收紧到「缓存秒数 + 3 秒」
  Future<void> _boot() async {
    // 每次启动重置判定状态（正常只有 initState 会调它）
    _cfgSettled = false;
    _entering = false;
    // ① 读上次缓存（同步读，几十毫秒）
    String cachedUrl = '';
    int cachedSec = 3;
    try {
      final sp = await SharedPreferences.getInstance();
      cachedUrl = sp.getString('splash_net_url') ?? '';
      cachedSec = sp.getInt('splash_sec') ?? 3;
    } catch (_) {}
    if (cachedSec < 1) cachedSec = 3;
    if (cachedSec > 10) cachedSec = 10;

    if (mounted && cachedUrl.isNotEmpty) {
      setState(() => _netSplash = cachedUrl);
    }

    // ② 首次启动（没有缓存图）→ 先等接口最多 1.2 秒拿到图片地址，
    //    否则会先显示渐变兜底、图回来时倒计时已经走完（用户看到的就是"没图"）。
    //    有缓存图时零等待，直接开始倒计时。
    if (cachedUrl.isEmpty) {
      try {
        final quick = await SoftService.instance.fetchSplash().timeout(
          const Duration(milliseconds: 1200),
        );
        final u = (quick['url'] ?? '').toString();
        if (u.isNotEmpty && mounted) {
          setState(() => _netSplash = u);
          try {
            final sp0 = await SharedPreferences.getInstance();
            await sp0.setString('splash_net_url', u);
          } catch (_) {}
        }
      } catch (_) {}
    }

    // ③ 开始倒计时（此时要么已有图，要么确实没图）
    _startCountdown(cachedSec);
    _diag = 'boot:fast-start';

    // ③ 兜底：缓存秒数 + 3 秒，无论如何进主界面
    Future.delayed(Duration(seconds: cachedSec + 3), () {
      if (mounted && !_entered) _enter();
    });

    // ④ 后台并行拉：本地图 / 配置 / 开屏图
    final localFuture = LocalSplash.get().timeout(
      const Duration(seconds: 3),
      onTimeout: () => '',
    );
    final cfgFuture = SoftService.instance
        .fetchConfig(force: true)
        .timeout(const Duration(seconds: 4), onTimeout: () => null);

    _cfgFuture = cfgFuture;
    // 成功/失败都算「配置已落地」；这里接住异常，避免未处理的异步错误
    unawaited(
      cfgFuture.then<void>(
        (_) => _cfgSettled = true,
        onError: (_) => _cfgSettled = true,
      ),
    );
    final netFuture = SoftService.instance.fetchSplash().timeout(
      const Duration(seconds: 4),
      onTimeout: () => const {},
    );

    // 本地开屏图（只在没有网络图时才有意义）
    try {
      final lp = await localFuture;
      if (mounted && lp.isNotEmpty) {
        _localSplash = lp;
        if (_netSplash.isEmpty) setState(() {});
      }
    } catch (_) {}

    // ⑤ 网络开屏图回来 → 换图（不重启倒计时）
    try {
      final sp = await netFuture;
      final u = (sp['url'] ?? '').toString();
      if (mounted && u.isNotEmpty && u != _netSplash) {
        setState(() => _netSplash = u);
      }
      if (u.isNotEmpty) {
        try {
          final s2 = await SharedPreferences.getInstance();
          await s2.setString('splash_net_url', u);
        } catch (_) {}
      }
    } catch (_) {}

    // ⑥ 配置回来 → 纠正时长 / 关闭开屏 / 维护模式
    try {
      final cfg = await cfgFuture;
      if (!mounted) return;
      if (cfg == null) return;

      // ★ 维护模式必须先于「已进主界面」判断处理：
      //   配置一旦晚于倒计时回来，_entered 已为 true，
      //   旧代码在这里直接 return，维护页就永远不会出现
      if (cfg.maintainEnable) {
        _maintain = true;
        _timer?.cancel();
        setState(() {
          _config = cfg;
          _diag = 'boot:maintain';
        });
        return;
      }

      // 关掉维护（用户点了「重新加载」）→ 复位，允许重新走倒计时
      _maintain = false;

      // 已进主界面：维护以外的纠正（开屏时长 / 开关屏）已无意义
      if (_entered) return;

      final on = cfg.splashEnable;
      final cfgSec = (cfg.splashSeconds).clamp(1, 10);
      // 必须 setState：维护页点「重新加载」后要靠这次重建才能退出维护页
      setState(() => _config = cfg);

      // 缓存秒数，下次冷启动直接用
      try {
        final s2 = await SharedPreferences.getInstance();
        await s2.setInt('splash_sec', cfgSec);
      } catch (_) {}

      if (!on) {
        _timer?.cancel();
        _enter();
        return;
      }
      // 时长比剩余时间短、或倒计时已经停了（维护页刚回来）→ 按配置重启
      if (cfgSec < _left || _left <= 0 || _timer?.isActive != true) {
        _startCountdown(cfgSec);
      }
    } catch (e, st) {
      debugPrint('[Splash][cfg] $e\n$st');
    }
  }

  /// 跳转：首次使用 → 引导页；否则 → 首页
  Future<void> _goNext() async {
    bool need = false;
    try {
      need = await shouldShowOnboard();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed(need ? Routes.onboard : Routes.index);
  }

  /// 进入主界面（并弹出公告）
  Future<void> _enter() async {
    if (_entered || _entering || !mounted) return;
    _entering = true;

    // 维护状态未定时先等配置（正常 <0.5s，最慢 2.5s）。
    // 不等的话，配置只要比倒计时晚回来一点，维护期间用户照样会被放进主界面。
    AppConfig? resolvedCfg;
    if (!_cfgSettled) {
      final pending = _cfgFuture;
      if (pending != null) {
        try {
          resolvedCfg = await pending.timeout(
            const Duration(milliseconds: 2500),
            onTimeout: () => null,
          );
        } catch (_) {}
      }
      if (!mounted) {
        _entering = false;
        return;
      }
    }
    // 双重保险：只要当前配置是维护态，任何入口都不放行
    // （旧版维护页点「重新加载」会重启倒计时，3 秒后从这里闯进首页）
    //
    // ★ 注意还要看 resolvedCfg：倒计时和配置几乎同时到点时，
    //   ⑥ 的 setState 可能还没来得及跑，只查 _config 就会漏。
    final blocked =
        _config?.maintainEnable == true ? _config : null;
    final lateBlocked =
        blocked ?? (resolvedCfg?.maintainEnable == true ? resolvedCfg : null);
    if (_maintain || lateBlocked != null) {
      _maintain = true;
      if (lateBlocked != null && !identical(_config, lateBlocked)) {
        setState(() => _config = lateBlocked);
      }
      _entering = false;
      return;
    }
    _entered = true;
    if (mounted) setState(() => _diag = 'enter:navigating');
    // ★ 1020：首次启动先进引导（3 屏讲清下载流程），之后再进首页
    _goNext();
    // 配置可能刚好在这轮 await 里才回来（⑥ 的 setState 还没跑），
    // 直接取这次 await 的结果，公告就不会因为「慢半拍」而被吞掉
    final cfg = _config ?? resolvedCfg;
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

    // ★★ 1020 开屏重构：配置了网络图时，按模板给 3 种不同版式。
    //   原来 7 个模板里有的根本没有图片槽位，这里统一收敛成 3 套可用样式：
    //     fullscreen / poster_center  → A 全屏沉浸
    //     brand_bar / banner          → B 底部品牌条
    //     fade / split / greeting     → C 居中玻璃卡
    if (_netSplash.isNotEmpty) {
      final style = switch (tpl) {
        'fullscreen' || 'poster_center' => 'A',
        'brand_bar' || 'banner' => 'B',
        _ => 'C',
      };
      final brandTitle = title.isEmpty ? '安逸软件汇' : title;
      final brandDesc = desc.isEmpty ? '优质软件 · 持续更新' : desc;

      // 右上角倒计时
      Widget countdown() => Positioned(
        right: 20,
        top: MediaQuery.of(context).padding.top + 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(90),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(60)),
          ),
          child: Text(
            '$_left s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

      if (style == 'A') {
        // ── A 全屏沉浸：图铺满 + 底部左侧文案 ──
        return Stack(
          fit: StackFit.expand,
          children: [
            _splashImage(),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x22000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brandTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    brandDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (_left > 0) countdown(),
          ],
        );
      }

      if (style == 'B') {
        // ── B 底部品牌条：图铺满 + 底部渐变条（图标 + 名称）──
        return Stack(
          fit: StackFit.expand,
          children: [
            _splashImage(),
            // 顶轻微压暗
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            // 底部品牌条
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  34,
                  24,
                  MediaQuery.of(context).padding.bottom + 34,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xE6000000)],
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        Assets.imagesApp,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            brandTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            brandDesc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(190),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_left > 0) countdown(),
          ],
        );
      }

      // ── C 居中玻璃卡：模糊图打底 + 居中卡片 ──
      return Stack(
        fit: StackFit.expand,
        children: [
          _splashImage(),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withAlpha(90)),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 44),
              padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(22),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      Assets.imagesApp,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    brandTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    brandDesc,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(190),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_left > 0) countdown(),
        ],
      );
    }

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
          Expanded(flex: 6, child: _splashImage()),
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
      // ★★ 1020：问候模板原来**完全没有图片**（只有渐变+文字），
      //   后台配了必应/随机图也看不到 —— 这就是「保存了不生效」。
      //   现在：有网络图 → 图片打底 + 深色蒙层；没有 → 回退渐变。
      if (_netSplash.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _splashImage(),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0xCC000000)],
                ),
              ),
            ),
            Center(
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
                    textAlign: TextAlign.center,
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }
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
                child: SizedBox(width: 220, height: 300, child: _splashImage()),
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
          _splashImage(),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
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
                child: AspectRatio(aspectRatio: 4 / 3, child: _splashImage()),
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
        _splashImage(),
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

  Future<void> _showNotice(AppConfig cfg) async {
    // ★ 渲染失败绝不白屏：任何异常都静默降级为「不弹公告」
    try {
      if (!await _noticeQuotaLeft(cfg)) return;
      _showNoticeInner(cfg);
    } catch (_) {}
  }

  /// ★ 1028：后台可设「同一用户每天最多弹几次公告」(notice_daily_limit)，0 = 不限。
  /// 计数按「公告内容指纹 + 当天」存本地；后台换了公告内容会自动重新计数。
  Future<bool> _noticeQuotaLeft(AppConfig cfg) async {
    final limit = cfg.noticeDailyLimit;
    if (limit <= 0) return true;
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}';
    final sig = (cfg.noticeTitle + '|' + cfg.noticeContent).hashCode.toRadixString(16);
    // ★ 1028：按「用户」计数 —— 换了账号各算各的；未登录时算游客。
    String uid = 'guest';
    try {
      final raw = sp.getString('user_info');
      if (raw != null && raw.isNotEmpty) {
        final m = jsonDecode(raw);
        if (m is Map) {
          final id = m['id'] ?? m['user_id'] ?? m['uid'];
          if (id != null && '$id'.isNotEmpty && '$id' != '0') uid = '$id';
        }
      }
    } catch (_) {}
    final kDay = 'notice_q_day_${uid}_$sig';
    final kCnt = 'notice_q_cnt_${uid}_$sig';
    if (sp.getString(kDay) != day) {
      await sp.setString(kDay, day);
      await sp.setInt(kCnt, 0);
    }
    final used = sp.getInt(kCnt) ?? 0;
    if (used >= limit) return false;
    await sp.setInt(kCnt, used + 1);
    return true;
  }

  void _showNoticeInner(AppConfig cfg) {
    final _ctx0 = SafeCtx.of();
    if (_ctx0 == null) return;
    // ignore: unused_local_variable
    final _ctx = _ctx0;
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.noticeTemplate ?? 'card';
    final dark = _noticeIsDark();
    final actions = [
      if (cfg.noticeUrl.isNotEmpty)
        TextButton(
          onPressed: () {
            JumpUtil.openUrl(cfg.noticeUrl);
            if (!cfg.noticeForce) SafeCtx.pop();
          },
          child: const Text('查看详情'),
        ),
      if (!cfg.noticeForce)
        FilledButton(onPressed: () => SafeCtx.pop(), child: const Text('我知道了')),
    ];
    final pageBg = dark ? C.bg1 : Colors.white;
    final cardBg = dark ? C.bg2 : Colors.white;
    final content = (double size, double height) => HtmlWidget(
      cfg.noticeContent,
      textStyle: TextStyle(fontSize: size, height: height),
    );

    // card：紧凑对话框（图标章 + 分隔线 + 右对齐按钮行），最轻量的一套
    if (tpl == 'card') {
      showGlassDialog(
        context: _ctx!,
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
                                    SafeCtx.pop();
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
                                onPressed: () => SafeCtx.pop(),
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
      showGlassDialog(
        context: _ctx!,
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
                                  SafeCtx.pop();
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
                              onPressed: () => SafeCtx.pop(),
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
      showGlassDialog(
        context: _ctx!,
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
                              SafeCtx.pop();
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
                          onPressed: () => SafeCtx.pop(),
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
      showGlassSheet(
        context: _ctx!,
        isDismissible: !cfg.noticeForce,
        isScrollControlled: true,
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
                    // ★ 1028：原来这里写死一个灰字「公告」，和 noticeTitle 重复，
                    // 标题本身就叫公告时看着像打了两遍 → 去掉
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
                          SafeCtx.pop();
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
                      onPressed: () => SafeCtx.pop(),
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
      final _nctx = SafeCtx.of();
      if (_nctx == null) return;
      Navigator.of(_nctx).push(
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
      showGlassDialog(
        context: _ctx!,
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
                                        SafeCtx.pop();
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
                                    onPressed: () => SafeCtx.pop(),
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

    // ticker：顶部跑马灯 —— 顶部细条滚动标题 + 无卡正文 + 底部链接式按钮
    if (tpl == 'ticker') {
      showGlassDialog(
        context: _ctx!,
        barrierDismissible: !cfg.noticeForce,
        barrierColor: dark ? Colors.black.withAlpha(160) : Colors.black38,
        builder: (ctx) => PopScope(
          canPop: !cfg.noticeForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部跑马灯细条
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: Container(
                    height: 40,
                    color: C.brand,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Marquee(
                            text: cfg.noticeTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            scrollAxis: Axis.horizontal,
                            blankSpace: 60,
                            velocity: 42,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: SingleChildScrollView(child: content(14, 1.7)),
                      ),
                      const SizedBox(height: 14),
                      // 底部：链接式按钮（无实心按钮，与其它模板区分）
                      Row(
                        children: [
                          if (cfg.noticeUrl.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                JumpUtil.openUrl(cfg.noticeUrl);
                                if (!cfg.noticeForce) {
                                  SafeCtx.pop();
                                }
                              },
                              child: Text(
                                '查看详情 ›',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: C.brand,
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (!cfg.noticeForce)
                            AppPressable(
                              onTap: () => SafeCtx.pop(),
                              child: Text(
                                '知道了',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: ctx.t3,
                                ),
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
      );
      return;
    }

    // card（原版兜底）：保留默认 AlertDialog
    showGlassDialog(
      context: _ctx!,
      barrierDismissible: !cfg.noticeForce,
      builder: (ctx) => PopScope(
        canPop: !cfg.noticeForce,
        child: AppDialog(
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
    // ★ v3.3.4：维护模式改为独立页面，共 5 款**骨架级**模板
    //   （旧版只有一个灰底图标 + 一行字，用户反馈「太简约」）
    //   模板名由后台 sys_config.maintain_template 下发。
    if (_config?.maintainEnable == true) {
      return MaintainPage(
        text: _config?.maintainText ?? '',
        template: _config?.maintainTemplate ?? 'engineer',
        appName: _config?.aboutName ?? '安逸软件汇',
        onReload: _reloadFromMaintain,
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
    // 后台可配「开屏点击跳转」（splash_url）：配了就整屏可点，
    // 未配置时保持不可点，避免误触。
    final splashUrl = cfg?.splashUrl.trim() ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      body: splashUrl.isEmpty
          ? _splashBody(cfg, netImg)
          : GestureDetector(
              onTap: () => JumpUtil.openUrl(splashUrl),
              child: _splashBody(cfg, netImg),
            ),
    );
  }

  /// 默认开屏（后台未设置图片时）
  /// 开屏图：网络图 > 本地图 > 默认品牌页
  Widget _splashImage() {
    if (_netSplash.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _netSplash,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 1080, // ★ 1031：开屏整屏显示，400 会糊；1080 保证主流屏清晰
        filterQuality: FilterQuality.medium,
        fadeInDuration: const Duration(milliseconds: 260),
        placeholder: (_, __) => _localSplash.isNotEmpty
            ? Image.file(File(_localSplash), fit: BoxFit.cover)
            : _defaultSplash(),
        errorWidget: (_, __, ___) => _localSplash.isNotEmpty
            ? Image.file(
                File(_localSplash),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultSplash(),
              )
            : _defaultSplash(),
      );
    }
    if (_localSplash.isNotEmpty) {
      return Image.file(
        File(_localSplash),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultSplash(),
      );
    }
    return _defaultSplash();
  }

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
          // ★ 1031：白底圆角托盘 + 阴影，深浅 logo 都能放；图从 104 提到 120
          Container(
            width: 144,
            height: 144,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(38),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Image.asset(
              Assets.imagesApp,
              width: 116,
              height: 116,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 26),
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
