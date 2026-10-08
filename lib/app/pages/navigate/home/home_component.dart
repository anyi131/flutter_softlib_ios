import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:marquee/marquee.dart';

import '../../../../generated/assets.dart';
import '../../../api/soft_service.dart';
import '../../../models/ui_config.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../models/http/results/carousel_model.dart';
import '../../../models/http/results/referral_model.dart';
import '../../../routes/app_pages.dart';
import '../navigate_logic.dart';
import '../update_flow.dart';
import 'home_logic.dart';

/// 首页 —— 沉浸式玻璃拟态布局
///
/// 结构（自上而下）：
///  ① 顶部问候 + 光晕背景
///  ② 大搜索胶囊（玻璃）
///  ③ 快捷四宫格（渐变图标块）
///  ④ 轮播横幅（大圆角 + 光晕投影）
///  ⑤ 跑马灯公告（玻璃条）
///  ⑥ 官方推荐（瀑布卡片）
class HomeComponent extends StatefulWidget {
  const HomeComponent({super.key});

  @override
  State<HomeComponent> createState() => _HomeComponentState();
}

class _HomeComponentState extends State<HomeComponent> {
  final HomeLogic logic = Get.find<HomeLogic>();
  int _carouselIdx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 页面背景光晕
          Deco.pageBackground(context),
          SafeArea(bottom: false, child: _homeBody()),
        ],
      ),
    );
  }

  /// v52i #4：首页两套模板（后台「界面」Tab home.template 可切）
  Widget _homeBody() {
    // v52q：监听 configVersion —— 后台保存后本页立即重建
    return Obx(() => _homeBodyInner(SoftService.instance.configVersion.value));
  }

  Widget _homeBodyInner(int _) {
    final uiCfg =
        SoftService.instance.cachedConfig?.uiConfig ?? const UiConfig();
    final tpl = uiCfg.homeTemplate;
    if (tpl == 'clean') {
      // 极简模板：问候 + 公告 + 推荐直出
      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header()),
          if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
          if (uiCfg.featureReferral) _referralTitle(),
          if (uiCfg.featureReferral) _referralGrid(),
          SliverToBoxAdapter(child: SizedBox(height: context.tabSpace + 40)),
        ],
      );
    }
    if (tpl == 'focus') {
      // v52t：搜索突出模板
      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _search()),
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(child: _quickGrid()),
          if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
          if (uiCfg.featureReferral) _referralTitle(),
          if (uiCfg.featureReferral) _referralGrid(),
          SliverToBoxAdapter(child: SizedBox(height: context.tabSpace + 40)),
        ],
      );
    }
    if (tpl == 'banner_top') {
      // v52t：大banner置顶模板
      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _banner()),
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(child: _search()),
          SliverToBoxAdapter(child: _quickGrid()),
          if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
          if (uiCfg.featureReferral) _referralTitle(),
          if (uiCfg.featureReferral) _referralGrid(),
          SliverToBoxAdapter(child: SizedBox(height: context.tabSpace + 40)),
        ],
      );
    }
    if (tpl == 'grid_quick') {
      // v52t：宫格快捷模板（双行宫格置顶）
      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(child: _quickGrid()),
          SliverToBoxAdapter(child: _search()),
          if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
          if (uiCfg.featureReferral) _referralTitle(),
          if (uiCfg.featureReferral) _referralGrid(),
          SliverToBoxAdapter(child: SizedBox(height: context.tabSpace + 40)),
        ],
      );
    }
    // classic 标准模板（原版全模块）
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _search()),
        SliverToBoxAdapter(child: _quickGrid()),
        SliverToBoxAdapter(child: _banner()),
        if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
        if (uiCfg.featureReferral) _referralTitle(),
        if (uiCfg.featureReferral) _referralGrid(),
        SliverToBoxAdapter(child: SizedBox(height: context.tabSpace + 40)),
      ],
    );
  }

  // ───────── ① 顶部问候 ─────────
  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        14,
        context.pagePadding,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => Deco.aurora().createShader(r),
                  child: Text(
                    '发现好软件',
                    style: Ty.display.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                _wordLine(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 两个按钮可在后台配置（开关 + 链接）
          if (logic.configData?.groupBtnOn != false) ...[
            _circleBtn(Icons.group_add_outlined, () => logic.joinGroup()),
            const SizedBox(width: 8),
          ],
          if (logic.configData?.userBtnOn != false)
            _circleBtn(Icons.support_agent_outlined, () => logic.joinUser()),
        ],
      ),
    );
  }

  Widget _wordLine() {
    return GetBuilder<HomeLogic>(
      id: 'word',
      builder: (logic) {
        final w = logic.word;
        if (w == null || w.isEmpty) {
          return Text(
            '每日精选 · 持续更新',
            style: Ty.small.copyWith(color: context.t3),
          );
        }
        return Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: C.cyan,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: SizedBox(
                height: 17,
                child: Marquee(
                  text: w,
                  style: Ty.small.copyWith(color: context.t2),
                  scrollAxis: Axis.horizontal,
                  blankSpace: 60,
                  velocity: 26,
                  startPadding: 6,
                  accelerationDuration: const Duration(milliseconds: 700),
                  decelerationDuration: const Duration(milliseconds: 700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withAlpha(12) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: context.isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(8),
          ),
        ),
        child: Icon(icon, size: 20, color: context.t2),
      ),
    );
  }

  // ───────── ② 搜索 ─────────
  Widget _search() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        18,
        context.pagePadding,
        0,
      ),
      child: Deco.glass(
        context,
        radius: R.full,
        alpha: 0.08,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        onTap: () => Get.toNamed(Routes.appSearch),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: C.brandBright),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '搜索你想要的软件',
                style: Ty.body.copyWith(color: context.t3, fontSize: 13.5),
              ),
            ),
            Pill('搜索', color: C.brand, solid: true, small: true),
          ],
        ),
      ),
    );
  }

  // ───────── ③ 快捷入口 ─────────
  Widget _quickGrid() {
    // v52f #10：快捷入口去重 —— 移除与「我的/应用/线报 Tab」重复的
    // 下载管理/软件搜索/线报速递，换成独有功能
    // v52i #7：快捷入口由后台「界面」Tab 热配置（开关即时生效）
    final ui = logic.configData?.uiConfig;
    final all = [
      (
        _QI(Icons.emoji_events_rounded, '每日签到', C.amber),
        () => Get.find<NavigateLogic>().changePage(4),
        ui?.quickSign ?? true,
      ),
      (
        _QI(Icons.workspace_premium_rounded, 'VIP会员', C.gold),
        () => Get.toNamed(Routes.vip),
        ui?.quickVip ?? true,
      ),
      (
        _QI(Icons.headset_mic_rounded, '联系客服', C.cyan),
        () => logic.joinUser(),
        ui?.quickService ?? true,
      ),
      (
        _QI(Icons.auto_awesome_rounded, '检查更新', C.violet),
        () => UpdateFlow.check(showLatestTip: true),
        ui?.quickUpdate ?? true,
      ),
    ];
    final items = all.where((e) => e.$3).map((e) => (e.$1, e.$2)).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding - 6,
        20,
        context.pagePadding - 6,
        4,
      ),
      child: Row(
        children: items
            .map(
              (it) => Expanded(
                child: GestureDetector(
                  onTap: it.$2,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: it.$1.color.withAlpha(
                            context.isDark ? 34 : 24,
                          ),
                          borderRadius: BorderRadius.circular(R.md + 2),
                          border: Border.all(
                            color: it.$1.color.withAlpha(60),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(it.$1.icon, color: it.$1.color, size: 26),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        it.$1.label,
                        style: Ty.small.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.t2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ───────── ④ 轮播 ─────────
  Widget _banner() {
    return GetBuilder<HomeLogic>(
      id: 'carousel',
      builder: (logic) {
        final list = logic.carouses;
        if (list == null || list.isEmpty) return const SizedBox.shrink();
        final idx = _carouselIdx.clamp(0, list.length - 1);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            16,
            context.pagePadding,
            0,
          ),
          child: Column(
            children: [
              CarouselSlider.builder(
                itemCount: list.length,
                itemBuilder: (context, i, _) {
                  final item = list[i];
                  return GestureDetector(
                    onTap: () => logic.onCarouselTap(item),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(R.xl),
                        boxShadow: [
                          BoxShadow(
                            color: C.brand.withAlpha(context.isDark ? 45 : 30),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(R.xl),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: item.image ?? '',
                              fit: BoxFit.cover,
                              memCacheWidth: 900,
                              placeholder: (_, __) => Container(
                                color: context.cardBg,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: context.cardBg,
                                child: Image.asset(
                                  Assets.imagesSucceed,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // 底部渐隐 + 标题
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  26,
                                  16,
                                  14,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xCC000000),
                                      Color(0x00000000),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  item.title ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                options: CarouselOptions(
                  height: 156,
                  autoPlay: true,
                  viewportFraction: 0.92,
                  enlargeCenterPage: true,
                  enlargeFactor: 0.14,
                  autoPlayInterval: const Duration(seconds: 4),
                  autoPlayAnimationDuration: const Duration(milliseconds: 700),
                  autoPlayCurve: Curves.easeOutCubic,
                  onPageChanged: (i, _) {
                    if (_carouselIdx != i) {
                      setState(() => _carouselIdx = i);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  list.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 5,
                    width: i == idx ? 20 : 5,
                    decoration: BoxDecoration(
                      gradient: i == idx ? Deco.brandGradient : null,
                      color: i == idx ? null : context.t3.withAlpha(70),
                      borderRadius: BorderRadius.circular(R.full),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────── ⑤ 公告 ─────────
  Widget _notice() {
    return GetBuilder<HomeLogic>(
      id: 'placard',
      builder: (logic) {
        final text = logic.configData?.placard ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            16,
            context.pagePadding,
            0,
          ),
          child: Deco.glass(
            context,
            radius: R.md,
            alpha: 0.06,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: Deco.brandGradient,
                    borderRadius: BorderRadius.circular(R.xs - 1),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 18,
                    child: Marquee(
                      text: text,
                      style: Ty.small.copyWith(
                        color: context.t2,
                        fontSize: 12.5,
                      ),
                      blankSpace: 90,
                      velocity: 30,
                      accelerationDuration: const Duration(milliseconds: 800),
                      decelerationDuration: const Duration(milliseconds: 800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────── ⑥ 推荐 ─────────
  Widget _referralTitle() {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (logic) {
        final list = logic.referrals;
        if (list == null || list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              26,
              context.pagePadding,
              12,
            ),
            child: SectionHeader(
              title: '官方推荐',
              accent: C.brandBright,
              action: Pill(
                '${list.length} 款',
                color: C.brandBright,
                small: true,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _referralGrid() {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (logic) {
        final list = logic.referrals;
        if (list == null || list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
          sliver: SliverGrid(
            gridDelegate: AdaptiveGrid.referral(context),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _referralCard(list[i]),
              childCount: list.length,
            ),
          ),
        );
      },
    );
  }

  Widget _referralCard(ReferralData d) {
    return KitCard(
      padding: EdgeInsets.zero,
      radius: R.lg,
      onTap: () => logic.onReferralTap(d),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: d.image ?? '',
              fit: BoxFit.cover,
              memCacheWidth: 600,
              placeholder: (_, __) =>
                  Container(color: context.isDark ? C.bg2 : C.lbg2),
              errorWidget: (_, __, ___) =>
                  Image.asset(Assets.imagesSucceed, fit: BoxFit.cover),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xE6000000), Color(0x00000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  d.title ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QI {
  final IconData icon;
  final String label;
  final Color color;
  const _QI(this.icon, this.label, this.color);
}
