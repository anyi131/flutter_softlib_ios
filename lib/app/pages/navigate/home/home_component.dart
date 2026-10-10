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
  late final PageController _cardsPc = PageController(viewportFraction: 0.86);

  @override
  void dispose() {
    _cardsPc.dispose();
    super.dispose();
  }

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
    // v54：全模板骨架级差异化 —— 每套独立排版骨架，不再只是模块换序
    if (tpl == 'clean') return _tplClean(uiCfg); // 纯排版无卡：行式列表
    if (tpl == 'focus') return _tplFocus(uiCfg); // 搜索沉浸：渐变搜索 Hero
    if (tpl == 'banner_top') return _tplBannerTop(uiCfg, logic); // 全屏沉浸头图
    if (tpl == 'cards') return _tplCards(uiCfg, logic); // 横滑大卡 PageView
    if (tpl == 'feed') return _tplFeed(uiCfg, logic); // 时间轴信息流
    if (tpl == 'compact_top') return _tplCompactTop(uiCfg, logic); // 横排色条
    if (tpl == 'grid_quick') return _tplGridQuick(uiCfg, logic); // 三列小网格
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
        if (uiCfg.featureReferral) _referralState(),
        SliverToBoxAdapter(child: SizedBox(height: context.tabSpace + 40)),
      ],
    );
  }

  // ═══════ v54 模板骨架库 ═══════
  Widget _tplSpacer() =>
      SliverToBoxAdapter(child: SizedBox(height: context.tabSpace + 40));

  SliverToBoxAdapter get _noticeSliver => SliverToBoxAdapter(child: _notice());

  /// clean —— 纯排版无卡：扁平搜索条 + 推荐行式列表
  Widget _tplClean(UiConfig uiCfg) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _flatSearch()),
        if (uiCfg.featureNotice) _noticeSliver,
        if (uiCfg.featureReferral) _referralTitle(),
        if (uiCfg.featureReferral)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
            sliver: SliverToBoxAdapter(child: _referralRowList()),
          ),
        if (uiCfg.featureReferral) _referralState(),
        _tplSpacer(),
      ],
    );
  }

  /// 扁平搜索条（clean 专属：无玻璃、细边框、左对齐）
  Widget _flatSearch() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        14,
        context.pagePadding,
        0,
      ),
      child: GestureDetector(
        onTap: () => Get.toNamed(Routes.appSearch),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withAlpha(8) : Colors.white,
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(
              color: context.isDark
                  ? Colors.white.withAlpha(22)
                  : Colors.black.withAlpha(14),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: context.t3),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '搜索软件…',
                  style: Ty.small.copyWith(color: context.t3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _referralRowList() {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (logic) {
        final list = logic.referrals;
        if (list == null || list.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (int i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _referralRow(list[i], logic),
              ),
          ],
        );
      },
    );
  }

  Widget _referralRow(ReferralData d, HomeLogic logic) {
    return GestureDetector(
      onTap: () => logic.onReferralTap(d),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withAlpha(8) : Colors.white,
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(
            color: context.isDark
                ? Colors.white.withAlpha(16)
                : Colors.black.withAlpha(10),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(R.sm),
              child: CachedNetworkImage(
                imageUrl: d.image ?? '',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                placeholder: (_, __) => Container(
                  width: 56,
                  height: 56,
                  color: context.isDark ? C.bg2 : C.lbg2,
                ),
                errorWidget: (_, __, ___) => Image.asset(
                  Assets.imagesSucceed,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.t1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (d.content ?? '').isEmpty ? '官方精选推荐' : d.content!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.tiny.copyWith(color: context.t3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.t3),
          ],
        ),
      ),
    );
  }

  /// focus —— 搜索沉浸：全宽品牌渐变搜索 Hero 打底，内容下沉
  Widget _tplFocus(UiConfig uiCfg) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: -context.pagePadding),
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              16,
              context.pagePadding,
              28,
            ),
            decoration: BoxDecoration(
              gradient: C.brandGradient,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => Deco.aurora().createShader(r),
                  child: Text(
                    '搜你想搜',
                    style: Ty.display.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '海量软件 · 一键直达',
                  style: Ty.small.copyWith(color: Colors.white.withAlpha(210)),
                ),
                const SizedBox(height: 18),
                // Hero 搜索条：白底胶囊、带投影，视觉重量全给搜索
                GestureDetector(
                  onTap: () => Get.toNamed(Routes.appSearch),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(R.full),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 20, color: C.brand),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '输入软件名，立即找到',
                            style: Ty.body.copyWith(color: context.t3),
                          ),
                        ),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: C.brandGradient,
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                          child: const Text(
                            '搜索',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _quickGrid()),
        if (uiCfg.featureNotice) _noticeSliver,
        if (uiCfg.featureReferral) _referralTitle(),
        if (uiCfg.featureReferral) _referralGrid(),
        if (uiCfg.featureReferral) _referralState(),
        _tplSpacer(),
      ],
    );
  }

  /// banner_top —— 全屏沉浸：首帧 banner 通栏出血铺顶，底部圆角压内容
  Widget _tplBannerTop(UiConfig uiCfg, HomeLogic logic) {
    return GetBuilder<HomeLogic>(
      id: 'carousel',
      builder: (l) {
        final list = l.carouses;
        final first = (list == null || list.isEmpty) ? null : list.first;
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _fullBleedHero(first, l)),
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _quickGrid()),
            if (uiCfg.featureNotice) _noticeSliver,
            if (uiCfg.featureReferral) _referralTitle(),
            if (uiCfg.featureReferral) _referralGrid(),
            if (uiCfg.featureReferral) _referralState(),
            _tplSpacer(),
          ],
        );
      },
    );
  }

  Widget _fullBleedHero(CarouselData? item, HomeLogic logic) {
    return GestureDetector(
      onTap: item == null ? null : () => logic.onCarouselTap(item),
      child: Container(
        height: 232,
        margin: EdgeInsets.symmetric(horizontal: -context.pagePadding),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if ((item?.image ?? '').isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item!.image!,
                  fit: BoxFit.cover,
                  memCacheWidth: 1000,
                  placeholder: (_, __) => Container(
                    decoration: BoxDecoration(gradient: C.brandGradient),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(gradient: C.brandGradient),
                  ),
                )
              else
                Container(decoration: BoxDecoration(gradient: C.brandGradient)),
              // 底部压暗渐层（非 const）
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(120)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: context.pagePadding,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(R.full),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        '精选推荐',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
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
  }

  /// cards —— 横滑大卡：推荐转全宽 PageView 大卡（轮播页卡骨架）
  Widget _tplCards(UiConfig uiCfg, HomeLogic logic) {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (l) {
        final list = l.referrals ?? const <ReferralData>[];
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (list.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 244,
                  child: PageView.builder(
                    controller: _cardsPc,
                    itemCount: list.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      child: _bigPageCard(list[i], l),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: _quickGrid()),
            if (uiCfg.featureReferral) _referralState(),
            if (uiCfg.featureNotice) _noticeSliver,
            _tplSpacer(),
          ],
        );
      },
    );
  }

  Widget _bigPageCard(ReferralData d, HomeLogic logic) {
    return GestureDetector(
      onTap: () => logic.onReferralTap(d),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.xl),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(context.isDark ? 40 : 26),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.xl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: d.image ?? '',
                fit: BoxFit.cover,
                memCacheWidth: 800,
                placeholder: (_, __) =>
                    Container(color: context.isDark ? C.bg2 : C.lbg2),
                errorWidget: (_, __, ___) =>
                    Image.asset(Assets.imagesSucceed, fit: BoxFit.cover),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withAlpha(190), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (d.content ?? '').isEmpty ? '立即查看' : d.content!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// feed —— 时间轴信息流：左侧时间轴导轨 + 圆点节点
  Widget _tplFeed(UiConfig uiCfg, HomeLogic logic) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _search()),
        if (uiCfg.featureNotice) _noticeSliver,
        if (uiCfg.featureReferral)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              18,
              context.pagePadding,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _referralTimeline(logic)),
          ),
        if (uiCfg.featureReferral) _referralState(),
        _tplSpacer(),
      ],
    );
  }

  Widget _referralTimeline(HomeLogic logic) {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (l) {
        final list = l.referrals;
        if (list == null || list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '推荐时间线',
              style: Ty.h3.copyWith(color: context.t1, fontSize: 15),
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < list.length; i++)
              _timelineTile(list[i], l, i == list.length - 1),
          ],
        );
      },
    );
  }

  Widget _timelineTile(ReferralData d, HomeLogic logic, bool last) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左导轨：圆点 + 竖线
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: C.brandBright,
                    border: Border.all(color: C.brand.withAlpha(90), width: 2),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: C.brand.withAlpha(50),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => logic.onReferralTap(d),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? Colors.white.withAlpha(8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(R.md),
                    border: Border.all(
                      color: context.isDark
                          ? Colors.white.withAlpha(16)
                          : Colors.black.withAlpha(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ty.body.copyWith(
                                fontWeight: FontWeight.w800,
                                color: context.t1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (d.content ?? '').isEmpty ? '官方精选推荐' : d.content!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Ty.tiny.copyWith(color: context.t3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(R.sm),
                        child: CachedNetworkImage(
                          imageUrl: d.image ?? '',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          placeholder: (_, __) => Container(
                            width: 48,
                            height: 48,
                            color: context.isDark ? C.bg2 : C.lbg2,
                          ),
                          errorWidget: (_, __, ___) => Image.asset(
                            Assets.imagesSucceed,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// compact_top —— 横排色条：快捷入口改为通栏色条行（条形清单骨架）
  Widget _tplCompactTop(UiConfig uiCfg, HomeLogic logic) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            14,
            context.pagePadding,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _quickBars()),
        ),
        SliverToBoxAdapter(child: _banner()),
        if (uiCfg.featureNotice) _noticeSliver,
        if (uiCfg.featureReferral) _referralTitle(),
        if (uiCfg.featureReferral) _referralGrid(),
        if (uiCfg.featureReferral) _referralState(),
        _tplSpacer(),
      ],
    );
  }

  /// 快捷入口色条（compact_top 专属骨架）
  Widget _quickBars() {
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
    return Column(
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: it.$2,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: it.$1.color.withAlpha(context.isDark ? 22 : 14),
                  borderRadius: BorderRadius.circular(R.md),
                  border: Border.all(
                    color: it.$1.color.withAlpha(60),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    // 左侧色条标识
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: it.$1.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(it.$1.icon, size: 20, color: it.$1.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        it.$1.label,
                        style: Ty.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.t1,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: context.t3,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// grid_quick —— 三列小网格：推荐改 3 列密排瓷砖（网格骨架）
  Widget _tplGridQuick(UiConfig uiCfg, HomeLogic logic) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _quickGrid()),
        if (uiCfg.featureNotice) _noticeSliver,
        if (uiCfg.featureReferral) _referralTitle(),
        if (uiCfg.featureReferral)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _tileCard(logic.referrals![i], logic, i),
                childCount: logic.referrals?.length ?? 0,
              ),
            ),
          ),
        if (uiCfg.featureReferral) _referralState(),
        _tplSpacer(),
      ],
    );
  }

  static final List<Color> _tileTints = [
    C.brand,
    C.violet,
    C.cyan,
    C.mint,
    C.amber,
    C.rose,
  ];

  Widget _tileCard(ReferralData d, HomeLogic logic, int i) {
    final tint = _tileTints[i % _tileTints.length];
    return GestureDetector(
      onTap: () => logic.onReferralTap(d),
      child: Container(
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withAlpha(8) : Colors.white,
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: tint.withAlpha(50), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(R.md),
                ),
                child: CachedNetworkImage(
                  imageUrl: d.image ?? '',
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  placeholder: (_, __) => Container(color: tint.withAlpha(26)),
                  errorWidget: (_, __, ___) =>
                      Image.asset(Assets.imagesSucceed, fit: BoxFit.cover),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    d.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: context.t1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                                decoration: BoxDecoration(
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
  /// 推荐区状态条：各推荐项热度胶囊（数据来自 referrals 计数字段，无则隐藏）
  Widget _referralState() {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (logic) {
        final list = logic.referrals;
        if (list == null || list.length < 2) {
          return const SizedBox.shrink();
        }
        final hot = list.take(4);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              for (var i = 0; i < hot.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded,
                            size: 14, color: C.brand),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${hot[i].title ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600),
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
      },
    );
  }

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
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xE6000000), Color(0x00000000)],
                  ),
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
