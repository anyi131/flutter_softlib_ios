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

  /// ★ v3.3.4：drawer 模板的分组展开状态（key = 分组标题）
  final Map<String, bool> _drawerOpen = {};

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
    final tail = SliverToBoxAdapter(
      child: SizedBox(height: context.tabSpace + 40),
    );

    // ★ v3.3.4 首页模板体系重做：
    //   旧 8 款只是把「问候/搜索/宫格/banner/公告/推荐」这 6 个积木换顺序，
    //   用户反馈「都是同款换色」（其实是同款换顺序）。
    //   新 8 款是**骨架级**差异：信息架构、首屏主视觉、滚动结构各不相同。
    //
    //   classic    经典双列   问候+搜索+快捷+banner+公告+双列推荐（原版）
    //   magazine   杂志流     全宽大图首屏 → 单列图文流（推荐项全宽大卡）
    //   gridwall   宫格墙     顶部搜索 + 三列紧凑宫格铺满，无 banner
    //   immersive  沉浸大图   banner 全出血打底 + 悬浮玻璃层叠信息
    //   drawer     分组抽屉   快捷入口折叠成分组抽屉（可展开/收起）
    //   timeline   时间轴     左侧导轨 + 单列时间轴推荐（原 feed 增强）
    //   minimal    极简文档   纯排版，无卡无图，只有文字列表
    //   store      便利店     顶部横向滚动分类条 + 双列商品式卡片
    switch (tpl) {
      // ── ① 经典双列（原版全模块）──
      case 'classic':
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _search()),
            SliverToBoxAdapter(child: _quickGrid()),
            SliverToBoxAdapter(child: _banner()),
            if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _referralTitle()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _referralGrid()),
            tail,
          ],
        );

      // ── ② 杂志流：首屏全宽大图 + 单列图文流 ──
      case 'magazine':
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _magazineHero()),
            SliverToBoxAdapter(child: _search()),
            if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _magazineTitle()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _magazineList()),
            tail,
          ],
        );

      // ── ③ 宫格墙：三列紧凑宫格铺满 ──
      case 'gridwall':
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _search()),
            if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
            SliverToBoxAdapter(child: _gridWallTabs()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _gridWall()),
            tail,
          ],
        );

      // ── ④ 沉浸大图：banner 出血打底 + 悬浮玻璃叠层 ──
      case 'immersive':
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _immersiveTop()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _referralTitle()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _referralGrid()),
            tail,
          ],
        );

      // ── ⑤ 分组抽屉：快捷入口折叠成分组 ──
      case 'drawer':
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _search()),
            SliverToBoxAdapter(child: _drawerGroups()),
            if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _referralTitle()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _referralGrid()),
            tail,
          ],
        );

      // ── ⑥ 时间轴 ──
      case 'timeline':
      case 'feed':
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _search()),
            if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
            if (uiCfg.featureReferral)
              SliverToBoxAdapter(child: _referralTimeline()),
            tail,
          ],
        );

      // ── ⑦ 极简文档：纯排版无卡无图 ──
      case 'minimal':
      case 'clean':
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _minimalHeader()),
            if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _minimalList()),
            tail,
          ],
        );

      // ── ⑧ 便利店：横向分类条 + 双列商品卡 ──
      case 'store':
      case 'cards':
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _storeTopBar()),
            SliverToBoxAdapter(child: _storeCats()),
            if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _storeGrid()),
            tail,
          ],
        );

      // 其余旧模板名 → 落到各自最接近的新骨架
      case 'focus':
      case 'compact_top':
      case 'grid_quick':
      case 'banner_top':
      default:
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _search()),
            SliverToBoxAdapter(child: _quickGrid()),
            SliverToBoxAdapter(child: _banner()),
            if (uiCfg.featureNotice) SliverToBoxAdapter(child: _notice()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _referralTitle()),
            if (uiCfg.featureReferral) SliverToBoxAdapter(child: _referralGrid()),
            tail,
          ],
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  v3.3.4 新增骨架：magazine / gridwall / immersive / drawer /
  //                    minimal / store
  // ═══════════════════════════════════════════════════════════════

  // ── 杂志流 ──

  /// 首屏：全宽大图（取第一个轮播或推荐图），下压圆角覆盖问候语
  Widget _magazineHero() {
    return GetBuilder<HomeLogic>(
      id: 'carousel',
      builder: (logic) {
        final list = logic.carouses;
        final refs = logic.referrals;
        String img = '';
        String title = '发现好软件';
        String sub = '每日精选 · 持续更新';
        if (list != null && list.isNotEmpty) {
          img = list.first.image ?? '';
          if ((list.first.title ?? '').isNotEmpty) title = list.first.title!;
        } else if (refs != null && refs.isNotEmpty) {
          img = refs.first.image ?? '';
          if ((refs.first.title ?? '').isNotEmpty) title = refs.first.title!;
        }
        return Stack(
          children: [
            // 全宽大图
            SizedBox(
              height: 268,
              width: double.infinity,
              child: img.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: img,
                      fit: BoxFit.cover,
                      memCacheWidth: 1000,
                      placeholder: (_, __) =>
                          Container(color: context.cardBg),
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: Deco.brandGradient,
                        ),
                      ),
                    )
                  : Container(decoration: BoxDecoration(gradient: Deco.brandGradient)),
            ),
            // 底部渐隐
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 150,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xE6000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            // 标题压在图上
            Positioned(
              left: context.pagePadding,
              right: context.pagePadding,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sub,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            // 右上角两个圆按钮（悬浮在图上）
            Positioned(
              right: context.pagePadding - 6,
              top: MediaQuery.of(context).padding.top + 8,
              child: Row(
                children: [
                  if (logic.configData?.groupBtnOn != false)
                    _circleBtnGlass(
                      Icons.group_add_outlined,
                      () => logic.joinGroup(),
                    ),
                  if (logic.configData?.userBtnOn != false) ...[
                    const SizedBox(width: 8),
                    _circleBtnGlass(
                      Icons.support_agent_outlined,
                      () => logic.joinUser(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _circleBtnGlass(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(70),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(70)),
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }

  Widget _magazineTitle() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        20,
        context.pagePadding,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 17,
            decoration: BoxDecoration(
              gradient: Deco.brandGradient,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 9),
          Text('最新推荐', style: Ty.h3.copyWith(color: context.t1)),
        ],
      ),
    );
  }

  /// 单列全宽图文卡（区别于双列网格）
  Widget _magazineList() {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (logic) {
        final list = logic.referrals;
        if (list == null || list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
          sliver: SliverList.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final d = list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => logic.onReferralTap(d),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(R.lg),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 150,
                          width: double.infinity,
                          child: (d.image ?? '').isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: d.image!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 900,
                                  placeholder: (_, __) =>
                                      Container(color: C.brand.withAlpha(18)),
                                  errorWidget: (_, __, ___) => Container(
                                    color: C.brand.withAlpha(18),
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: context.t3,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: C.brand.withAlpha(18),
                                  child: Icon(
                                    Icons.apps_rounded,
                                    color: C.brand.withAlpha(140),
                                    size: 34,
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.title ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ty.h3.copyWith(color: context.t1),
                              ),
                              if ((d.content ?? '').isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  d.content!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ty.small.copyWith(
                                    color: context.t3,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── 宫格墙 ──

  Widget _gridWallTabs() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        16,
        context.pagePadding,
        10,
      ),
      child: Row(
        children: [
          Text('全部应用', style: Ty.h3.copyWith(color: context.t1)),
          const Spacer(),
          Text(
            '共 ${logic.referrals?.length ?? 0} 个',
            style: Ty.tiny.copyWith(color: context.t3),
          ),
        ],
      ),
    );
  }

  /// 三列紧凑宫格（比双列更密，一屏看到更多）
  Widget _gridWall() {
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
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
            delegate: SliverChildBuilderDelegate((context, i) {
              final d = list[i];
              return GestureDetector(
                onTap: () => logic.onReferralTap(d),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(R.md),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (d.image ?? '').isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: d.image!,
                                fit: BoxFit.cover,
                                memCacheWidth: 400,
                                placeholder: (_, __) => Container(
                                  color: C.brand.withAlpha(16),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: C.brand.withAlpha(16),
                                  child: Icon(
                                    Icons.apps_rounded,
                                    color: C.brand.withAlpha(140),
                                  ),
                                ),
                              )
                            : Container(
                                color: C.brand.withAlpha(16),
                                child: Icon(
                                  Icons.apps_rounded,
                                  color: C.brand.withAlpha(140),
                                  size: 26,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      d.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Ty.tiny.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                  ],
                ),
              );
            }, childCount: list.length),
          ),
        );
      },
    );
  }

  // ── 沉浸大图 ──

  Widget _immersiveTop() {
    return GetBuilder<HomeLogic>(
      id: 'carousel',
      builder: (logic) {
        final list = logic.carouses;
        return Column(
          children: [
            // 出血大图 + 悬浮玻璃信息层
            SizedBox(
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (list != null && list.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: list.first.image ?? '',
                      fit: BoxFit.cover,
                      memCacheWidth: 1100,
                      placeholder: (_, __) =>
                          Container(color: context.cardBg),
                      errorWidget: (_, __, ___) => Container(
                        decoration:
                            BoxDecoration(gradient: Deco.brandGradient),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(gradient: Deco.brandGradient),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x22000000)],
                      ),
                    ),
                  ),
                  // 悬浮玻璃问候层（叠在图上一半）
                  Positioned(
                    left: context.pagePadding,
                    right: context.pagePadding,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? Colors.white.withAlpha(26)
                            : Colors.white.withAlpha(235),
                        borderRadius: BorderRadius.circular(R.lg),
                        border: Border.all(
                          color: Colors.white.withAlpha(
                            context.isDark ? 46 : 200,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '发现好软件',
                                  style: Ty.h2.copyWith(color: context.t1),
                                ),
                                const SizedBox(height: 3),
                                _wordLine(),
                              ],
                            ),
                          ),
                          if (logic.configData?.groupBtnOn != false)
                            _circleBtn(
                              Icons.group_add_outlined,
                              () => logic.joinGroup(),
                            ),
                          if (logic.configData?.userBtnOn != false) ...[
                            const SizedBox(width: 6),
                            _circleBtn(
                              Icons.support_agent_outlined,
                              () => logic.joinUser(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 74),
            _search(),
          ],
        );
      },
    );
  }

  // ── 分组抽屉 ──

  Widget _drawerGroups() {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 18, context.pagePadding, 4),
      child: Column(
        children: [
          _drawerGroup(
            '快捷功能',
            Icons.bolt_rounded,
            C.amber,
            [
              if (logic.configData?.uiConfig.quickSign ?? true)
                _drawerItem(
                  '每日签到',
                  Icons.emoji_events_rounded,
                  C.amber,
                  () => Get.find<NavigateLogic>().goMine(),
                ),
              if (logic.configData?.uiConfig.quickVip ?? true)
                _drawerItem(
                  'VIP会员',
                  Icons.workspace_premium_rounded,
                  C.gold,
                  () => Get.toNamed(Routes.vip),
                ),
              if (logic.configData?.uiConfig.quickService ?? true)
                _drawerItem(
                  '联系客服',
                  Icons.headset_mic_rounded,
                  C.cyan,
                  () => logic.joinUser(),
                ),
              if (logic.configData?.uiConfig.quickUpdate ?? true)
                _drawerItem(
                  '检查更新',
                  Icons.auto_awesome_rounded,
                  C.violet,
                  () => UpdateFlow.check(showLatestTip: true),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _drawerGroup(
            '我的资产',
            Icons.account_balance_wallet_rounded,
            C.mint,
            [
              _drawerItem(
                '充值余额',
                Icons.add_card_rounded,
                C.mint,
                () => Get.toNamed(Routes.recharge),
              ),
              _drawerItem(
                '下载管理',
                Icons.download_rounded,
                C.cyan,
                () => Get.toNamed(Routes.appDownload),
              ),
              _drawerItem(
                '卡密商城',
                Icons.storefront_rounded,
                C.gold,
                () => Get.toNamed(Routes.cardShop),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 可展开/收起的抽屉分组
  Widget _drawerGroup(
    String title,
    IconData icon,
    Color color,
    List<Widget> items,
  ) {
    final open = _drawerOpen[title] ?? true;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _drawerOpen[title] = !open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color.withAlpha(28),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      style: Ty.h3.copyWith(color: context.t1),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.t3,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: open
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                for (final it in items) it,
                const SizedBox(height: 6),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 10, 14, 10),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13.5, color: context.t1),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 17, color: context.t3),
          ],
        ),
      ),
    );
  }

  // ── 极简文档 ──

  Widget _minimalHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        18,
        context.pagePadding,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('发现好软件', style: Ty.display.copyWith(color: context.t1)),
          const SizedBox(height: 8),
          _wordLine(),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: context.isDark
                ? Colors.white.withAlpha(16)
                : Colors.black.withAlpha(10),
          ),
        ],
      ),
    );
  }

  /// 纯文字列表：无卡片、无图、无圆角
  Widget _minimalList() {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (logic) {
        final list = logic.referrals;
        if (list == null || list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
          sliver: SliverList.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final d = list[i];
              return InkWell(
                onTap: () => logic.onReferralTap(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: context.isDark
                            ? Colors.white.withAlpha(12)
                            : Colors.black.withAlpha(8),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: Ty.tiny.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: i < 3 ? C.brand : context.t3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: context.t1,
                              ),
                            ),
                            if ((d.content ?? '').isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                d.content!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ty.tiny.copyWith(color: context.t3),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: context.t3,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── 便利店 ──

  Widget _storeTopBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        14,
        context.pagePadding,
        0,
      ),
      child: Row(
        children: [
          Expanded(child: _searchInline()),
          if (logic.configData?.userBtnOn != false) ...[
            const SizedBox(width: 10),
            _circleBtn(Icons.support_agent_outlined, () => logic.joinUser()),
          ],
        ],
      ),
    );
  }

  /// 内联搜索框（store 模板专用，与 _search() 的独立搜索区不同）
  Widget _searchInline() {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.appSearch),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(R.full),
          border: Border.all(
            color: context.isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(8),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: context.t3),
            const SizedBox(width: 8),
            Text(
              '搜软件、找工具',
              style: Ty.small.copyWith(color: context.t3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storeCats() {
    final ui = logic.configData?.uiConfig;
    final cats = <(String, IconData)>[
      if (ui?.quickSign ?? true) ('签到', Icons.emoji_events_rounded),
      if (ui?.quickVip ?? true) ('会员', Icons.workspace_premium_rounded),
      ('充值', Icons.add_card_rounded),
      ('下载', Icons.download_rounded),
      ('卡密', Icons.storefront_rounded),
      if (ui?.quickService ?? true) ('客服', Icons.headset_mic_rounded),
      if (ui?.quickUpdate ?? true) ('更新', Icons.auto_awesome_rounded),
    ];
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(context.pagePadding, 16, context.pagePadding, 6),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final c = cats[i];
          return GestureDetector(
            onTap: () {
              switch (c.$1) {
                case '签到':
                  Get.find<NavigateLogic>().goMine();
                case '会员':
                  Get.toNamed(Routes.vip);
                case '充值':
                  Get.toNamed(Routes.recharge);
                case '下载':
                  Get.toNamed(Routes.appDownload);
                case '卡密':
                  Get.toNamed(Routes.cardShop);
                case '客服':
                  logic.joinUser();
                case '更新':
                  UpdateFlow.check(showLatestTip: true);
              }
            },
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: C.brand.withAlpha(context.isDark ? 30 : 20),
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                  child: Icon(c.$2, size: 21, color: C.brand),
                ),
                const SizedBox(height: 6),
                Text(
                  c.$1,
                  style: Ty.tiny.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.t2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 双列商品式卡（图在左、信息在右的紧凑行卡）
  Widget _storeGrid() {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (logic) {
        final list = logic.referrals;
        if (list == null || list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            6,
            context.pagePadding,
            0,
          ),
          sliver: SliverList.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final d = list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: GestureDetector(
                  onTap: () => logic.onReferralTap(d),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(R.md),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: (d.image ?? '').isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: d.image!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 220,
                                    placeholder: (_, __) => Container(
                                      color: C.brand.withAlpha(16),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: C.brand.withAlpha(16),
                                      child: Icon(
                                        Icons.apps_rounded,
                                        color: C.brand.withAlpha(140),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: C.brand.withAlpha(16),
                                    child: Icon(
                                      Icons.apps_rounded,
                                      color: C.brand.withAlpha(140),
                                    ),
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
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.t1,
                                ),
                              ),
                              if ((d.content ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  d.content!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ty.tiny.copyWith(
                                    color: context.t3,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: C.brand.withAlpha(20),
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                          child: Text(
                            '查看',
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
                ),
              );
            },
          ),
        );
      },
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
        () => Get.find<NavigateLogic>().goMine(),
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

  // ───────── feed：时间轴信息流（安全布局版） ─────────
  ///
  /// 教训（fcfa408 旧版）：IntrinsicHeight(Row(stretch)+Expanded) 会随
  /// CachedNetworkImage 加载反复重跑整棵 intrinsic 布局，数据量大时 O(N²)
  /// 布局风暴导致真机冻死。新版：
  ///  · 左导轨固定宽 18px：圆点固定 8px + 竖线固定 60px，不撑满行高；
  ///  · 行高仅由右侧内容（文本自适应）决定，无 IntrinsicHeight/IntrinsicWidth；
  ///  · 缩略图固定尺寸 + memCacheWidth 限解码。
  Widget _referralTimeline() {
    return GetBuilder<HomeLogic>(
      id: 'referral',
      builder: (logic) {
        final list = logic.referrals;
        if (list == null || list.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            18,
            context.pagePadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '推荐时间线',
                style: Ty.h3.copyWith(color: context.t1, fontSize: 15),
              ),
              const SizedBox(height: 14),
              for (int i = 0; i < list.length; i++)
                _timelineTile(list[i], i == list.length - 1),
            ],
          ),
        );
      },
    );
  }

  Widget _timelineTile(ReferralData d, bool last) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左导轨：固定宽 18 = 圆点 8px + 固定长度竖线（不撑满）
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: C.brandBright,
                    border: Border.all(color: C.brand.withAlpha(90), width: 2),
                  ),
                ),
                if (!last)
                  Container(
                    width: 2,
                    height: 60,
                    margin: const EdgeInsets.only(top: 4),
                    color: C.brand.withAlpha(50),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
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
                    // 文本区（自适应行高来源）
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
                    // 缩略图：固定尺寸 + 解码限宽
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
        ],
      ),
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
