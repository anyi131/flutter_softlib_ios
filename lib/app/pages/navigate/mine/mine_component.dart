import 'package:cached_network_image/cached_network_image.dart';

import '../../../design/app_anim.dart';
import '../../../design/title_badge.dart';
import '../../../design/user_medals.dart';
import '../../../utils/safe_ctx.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/soft_service.dart';
import '../../../models/ui_config.dart';
import '../../../api/user_service.dart';
import '../../../api/goal_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/glass.dart';
import '../../../design/theme_controller.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';
import '../../../routes/app_pages.dart';
import '../../navigate/navigate_logic.dart';
import 'mine_logic.dart';

/// 我的 —— 沉浸式个人中心
///
/// 结构：
///  ① 头像卡（玻璃 + 极光描边 + 积分/VIP 徽标）
///  ② 数据条（消息/关注/粉丝/签到）
///  ③ 会员横幅（金色渐变，独立视觉重量）
///  ④ 服务宫格（4 列，渐变图标）
///  ⑤ 退出/登录按钮
class MineComponent extends StatelessWidget {
  const MineComponent({super.key});

  /// v52m #11：后台「功能开关」读取（无配置时全开）
  static UiConfig get _uiCfg =>
      SoftService.instance.cachedConfig?.uiConfig ?? const UiConfig();

  /// ★ 1015：头像旁的版本徽标 —— 自动跟随真实版本（原来写死 'v3.3'）
  static final RxString verTag = 'v3.3.4'.obs;
  static bool _verLoaded = false;
  static Future<void> _loadVer() async {
    if (_verLoaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      verTag.value = 'v${info.version}';
      _verLoaded = true;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _loadVer(); // 首次进入异步读取（无 await，不阻塞首帧）
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: GetBuilder<MineLogic>(
              // v54：反模式修复——控制器改由 NavigateBinding lazyPut 注册，
              // 不再在 build 里 Get.put（防重建风暴/实例替换）
              tag: 'mine',
              builder: (logic) {
                return RefreshIndicator(
                  onRefresh: logic.load,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      12,
                      context.pagePadding,
                      context.tabSpace + 40,
                    ),
                    children: _mineBody(
                      context,
                      logic,
                      SoftService.instance.configVersion.value,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) {
    return Row(
      children: [
        Text('我的', style: Ty.display.copyWith(color: context.t1)),
        const Spacer(),
        AppPressable(
          onTap: () => Get.find<NavigateLogic>().changePage(0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withAlpha(12) : Colors.white,
              borderRadius: BorderRadius.circular(R.full),
              border: Border.all(
                color: context.isDark
                    ? Colors.white.withAlpha(18)
                    : Colors.black.withAlpha(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Lz.home, size: 14, color: context.t3),
                const SizedBox(width: 5),
                Text('回首页', style: Ty.tiny.copyWith(color: context.t3)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════ v54 模板骨架库（仅用旧版验证过的布局组合：Row/Column/Container/Wrap/KitCard） ═══════
  /// clean：扁平头像行（无玻璃卡）
  Widget _flatProfile(BuildContext context, MineLogic logic) {
    final logged = logic.isLoggedIn;
    return Row(
      children: [
        AppPressable(
          onTap: () => logged ? logic.openProfileEdit() : logic.openLogin(),
          child: Container(
            width: 58,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.isDark ? C.bg2 : Colors.white,
              border: Border.all(
                color: logged ? C.brandBright : context.t3.withAlpha(80),
                width: 2,
              ),
            ),
            child: logic.avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                      memCacheWidth: 400,
                    imageUrl: logic.avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _defaultAvatar(context),
                    errorWidget: (_, __, ___) => _defaultAvatar(context),
                  )
                : _defaultAvatar(context),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Text(
                    logic.nickname.isEmpty ? '点击登录' : logic.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.h2.copyWith(color: context.t1, fontSize: 20),
                  ),
                ),
                _userTitleBadge(logic.userTitle),
                // 1109：勋章显示在头像昵称后面
                _MyMedalsInline(isVip: logic.isVip),
              ]),
              const SizedBox(height: 4),
              Text(
                logged ? 'UID ${logic.uid}' : '登录后享受完整功能',
                style: Ty.small.copyWith(color: context.t3),
              ),
            ],
          ),
        ),
        Icon(Lz.chevronRight, color: context.t3, size: 20),
      ],
    );
  }

  /// clean：通栏服务清单（无卡片，细分隔线）
  Widget _flatServiceRows(BuildContext context, MineLogic logic) {
    final items = _serviceItems(logic);
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _serviceRow(context, items[i]),
          if (i < items.length - 1)
            Divider(
              height: 1,
              thickness: 0.5,
              color: context.isDark
                  ? Colors.white.withAlpha(14)
                  : Colors.black.withAlpha(10),
            ),
        ],
      ],
    );
  }

  /// simple：分组列表行（包在白卡里，带组内分隔线）
  Widget _groupedServiceRows(BuildContext context, MineLogic logic, int group) {
    final items = _serviceItems(logic);
    final mid = (items.length / 2).ceil();
    final sub = group == 0
        ? items.take(mid).toList()
        : items.skip(mid).toList();
    return KitCard(
      radius: R.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < sub.length; i++) ...[
            _serviceRow(context, sub[i]),
            if (i < sub.length - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                color: context.isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.black.withAlpha(10),
              ),
          ],
        ],
      ),
    );
  }

  Widget _serviceRow(BuildContext context, _S s) {
    // 用 GestureDetector（与旧版 _gridCell 同款），不引入 InkWell 新依赖
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: s.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: s.color.withAlpha(context.isDark ? 30 : 20),
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Icon(s.icon, size: 17, color: s.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.label,
                style: Ty.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.t1,
                ),
              ),
            ),
            Icon(Lz.chevronRight, size: 18, color: context.t3),
          ],
        ),
      ),
    );
  }

  /// stats_hero：大号数据英雄卡（品牌渐变三联大数字）
  Widget _statsHeroCard(BuildContext context, MineLogic logic) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        gradient: C.brandGradient,
        borderRadius: BorderRadius.circular(R.xl),
        boxShadow: [
          BoxShadow(
            color: C.brand.withAlpha(context.isDark ? 55 : 70),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _heroStatCell(context, '积分', '${logic.points}'),
          _heroStatDivider(),
          _heroStatCell(context, '余额', '¥${logic.money}'),
          _heroStatDivider(),
          _heroStatCell(context, '会员', logic.isVip ? '生效中' : '未开通'),
        ],
      ),
    );
  }

  Widget _heroStatCell(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(190),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStatDivider() =>
      Container(width: 1, height: 30, color: Colors.white.withAlpha(60));

  /// dark_card：深色卡里的分组标题（浅色模式下卡片也是深底，标题需白色）
  Widget _sectionTitleDark(BuildContext context, String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [C.brand, C.brand.withAlpha(90)],
              ),
              borderRadius: BorderRadius.circular(R.full),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            t,
            style: Ty.h2.copyWith(
              color: context.isDark ? context.t1 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ───────── ① 头像卡 ─────────
  /// v52m #5：我的页面模板 classic / clean / gradient
  /// 1109：所有「我的」模板统一入口 —— 在标题下方插入勋章条，
  ///   让勋章真正「接入显示」（不只在弹窗里）。
  List<Widget> _mineBody(BuildContext context, MineLogic logic, int configVer) {
    // 1109：勋章改为「头像昵称后面」的小徽章（不再顶部堆一条大横幅）
    return _mineBodyInner(context, logic, configVer);
  }

  List<Widget> _mineBodyInner(BuildContext context, MineLogic logic, int configVer) {
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.mineTemplate ?? 'classic';
    if (tpl == 'gradient') {
      // 渐变描边：品牌渐变描边头像卡 + 通栏服务分组
      return [
        _title(context),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            gradient: Deco.brandGradient,
            borderRadius: BorderRadius.circular(R.xl),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.isDark ? C.bg1 : Colors.white,
              borderRadius: BorderRadius.circular(R.xl - 2.5),
            ),
            child: _profileCardInner(context, logic, logic.isLoggedIn),
          ),
        ),
        const SizedBox(height: 14),
        _statsRow(context, logic),
        const SizedBox(height: 20),
        _sectionTitle(context, '我的服务'),
        const SizedBox(height: 10),
        _serviceGrid(context, logic),
        const SizedBox(height: 18),
        _actionButton(context, logic),
      ];
    }
    if (tpl == 'clean') {
      // v54：纯排版无卡 —— 扁平头像行 + 通栏服务清单（无卡片容器）
      return [
        _title(context),
        const SizedBox(height: 16),
        _flatProfile(context, logic),
        const SizedBox(height: 20),
        _sectionTitle(context, '我的服务'),
        const SizedBox(height: 6),
        _flatServiceRows(context, logic),
        const SizedBox(height: 18),
        _actionButton(context, logic),
      ];
    }
    if (tpl == 'dark_card') {
      // v54：暗色影院卡 —— 整页内容包进一张深色大卡（深底 + 品牌描边）
      // 注：全部用旧版验证过的 Container/Column/Row 组合，无新布局原语
      return [
        _title(context),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.isDark ? C.bg0 : C.lt1,
            borderRadius: BorderRadius.circular(R.xl),
            border: Border.all(color: C.brand.withAlpha(80)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(context.isDark ? 90 : 40),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              _profileCard(context, logic),
              const SizedBox(height: 14),
              _statsRow(context, logic),
              const SizedBox(height: 14),
              _vipBanner(context, logic),
              const SizedBox(height: 18),
              _sectionTitleDark(context, '我的服务'),
              const SizedBox(height: 10),
              _serviceGrid(context, logic),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _actionButton(context, logic),
      ];
    }
    if (tpl == 'stats_hero') {
      // v54：数据英雄卡 —— 大号渐变数据 Hero（积分/余额/VIP 状态三联）
      return [
        _title(context),
        const SizedBox(height: 16),
        _profileCard(context, logic),
        const SizedBox(height: 14),
        _statsHeroCard(context, logic),
        const SizedBox(height: 14),
        _vipBanner(context, logic),
        const SizedBox(height: 20),
        _sectionTitle(context, '我的服务'),
        const SizedBox(height: 10),
        _serviceGrid(context, logic),
        const SizedBox(height: 18),
        _actionButton(context, logic),
      ];
    }
    if (tpl == 'simple') {
      // v54：分组列表 —— 服务按「资产交易 / 通用」两组分行展示
      return [
        _title(context),
        const SizedBox(height: 16),
        _profileCard(context, logic),
        const SizedBox(height: 14),
        _statsRow(context, logic),
        const SizedBox(height: 20),
        _sectionTitle(context, '资产与交易'),
        const SizedBox(height: 10),
        _groupedServiceRows(context, logic, 0),
        const SizedBox(height: 18),
        _sectionTitle(context, '通用功能'),
        const SizedBox(height: 10),
        _groupedServiceRows(context, logic, 1),
        const SizedBox(height: 18),
        _actionButton(context, logic),
      ];
    }
    if (tpl == 'split') {
      // v53：split 增强 —— 顶部渐变问候横幅 + 分组列表，视觉与其他模板明显区分
      return [
        _title(context),
        const SizedBox(height: 16),
        _splitHero(context, logic),
        const SizedBox(height: 14),
        _profileCard(context, logic),
        const SizedBox(height: 14),
        _statsRow(context, logic),
        const SizedBox(height: 20),
        _sectionTitle(context, '我的服务'),
        const SizedBox(height: 10),
        _serviceGrid(context, logic),
        const SizedBox(height: 18),
        _actionButton(context, logic),
      ];
    }
    if (tpl == 'wallet') {
      // ★ v3.3.4：钱包仪表盘 —— 余额/积分/VIP 三块数据块横向并列置顶，
      //   头像退居其后（信息架构与前几款完全不同：数据优先，身份其次）
      return [
        _title(context),
        const SizedBox(height: 16),
        _dashboardCard(context, logic),
        const SizedBox(height: 14),
        _profileCard(context, logic),
        const SizedBox(height: 20),
        _sectionTitle(context, '常用功能'),
        const SizedBox(height: 10),
        _denseList(context, logic),
        const SizedBox(height: 18),
        _actionButton(context, logic),
      ];
    }
    if (tpl == 'sidebar') {
      // ★ v3.3.4：左栏式 —— 左侧固定头像竖栏 + 右侧滚动内容，
      //   移动端少见的左右分栏骨架，与所有纵向堆叠模板区分明显
      return [
        _title(context),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左栏：头像 + 竖排数据
              SizedBox(
                width: 108,
                child: Column(
                  children: [
                    _sideAvatar(context, logic),
                    const SizedBox(height: 14),
                    _sideStat(context, logic, '余额', logic.money),
                    const SizedBox(height: 10),
                    _sideStat(context, logic, '积分', '${logic.points}'),
                    const SizedBox(height: 10),
                    _sideStat(context, logic, '状态', logic.isVip ? 'VIP' : '普通'),
                    const SizedBox(height: 16),
                    _actionButton(context, logic),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // 右栏：服务清单（单列大行）
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我的服务', style: Ty.h3.copyWith(color: context.t1)),
                    const SizedBox(height: 10),
                    _sideServiceList(context, logic),
                  ],
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      _title(context),
      const SizedBox(height: 16),
      _profileCard(context, logic),
      const SizedBox(height: 14),
      _statsRow(context, logic),
      const SizedBox(height: 14),
      _vipBanner(context, logic),
      const SizedBox(height: 20),
      _sectionTitle(context, '我的服务'),
      const SizedBox(height: 10),
      _serviceGrid(context, logic),
      const SizedBox(height: 18),
      _actionButton(context, logic),
    ];
  }

  // ═══════ v3.3.4 新增：wallet 模板的三块数据仪表盘 ═══════
  Widget _dashboardCard(BuildContext context, MineLogic logic) {
    final cells = <(String, String, IconData, Color)>[
      ('余额', logic.money, Lz.payWallet, C.mint),
      ('积分', '${logic.points}', Lz.sparkles, C.amber),
      (
        '会员',
        logic.isVip ? '已开通' : '未开通',
        Lz.vip,
        C.gold,
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        gradient: context.isDark ? null : Deco.brandGradient,
        color: context.isDark ? C.bg2 : null,
        borderRadius: BorderRadius.circular(R.lg),
        boxShadow: [
          BoxShadow(
            color: C.brand.withAlpha(context.isDark ? 30 : 80),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withAlpha(context.isDark ? 24 : 60),
              ),
            Expanded(
              child: Column(
                children: [
                  Icon(
                    cells[i].$3,
                    size: 19,
                    color: context.isDark
                        ? cells[i].$4
                        : Colors.white.withAlpha(230),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    cells[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.isDark ? C.t1 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cells[i].$1,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.isDark
                          ? C.t3
                          : Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// wallet 模板：单列密集列表（与宫格/分组都不同）
  Widget _denseList(BuildContext context, MineLogic logic) {
    final items = _serviceItems(logic);
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 52,
                color: context.isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.black.withAlpha(7),
              ),
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: items[i].color.withAlpha(28),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        items[i].icon,
                        size: 16,
                        color: items[i].color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: context.t1,
                        ),
                      ),
                    ),
                    Icon(
                      Lz.chevronRight,
                      size: 18,
                      color: context.t3,
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

  // ═══════ v3.3.4 新增：sidebar 模板的左栏元件 ═══════
  Widget _sideAvatar(BuildContext context, MineLogic logic) {
    final logged = logic.isLoggedIn;
    return AppPressable(
      onTap: () => logged ? logic.openProfileEdit() : logic.openLogin(),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(R.lg),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: logged ? Deco.goldGradient : Deco.brandGradient,
              ),
              child: SizedBox(
                width: 52,
                height: 52,
                child: ClipOval(
                  child: logic.avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                            memCacheWidth: 400,
                          imageUrl: logic.avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _defaultAvatar(context),
                          errorWidget: (_, __, ___) => _defaultAvatar(context),
                        )
                      : _defaultAvatar(context),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Text(
                    logged
                        ? (logic.nickname.isEmpty ? '用户' : logic.nickname)
                        : '点击登录',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: context.t1,
                    ),
                  ),
                ),
                _userTitleBadge(logic.userTitle),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideStat(
    BuildContext context,
    MineLogic logic,
    String label,
    String value,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ty.tiny.copyWith(fontSize: 10, color: context.t3)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: C.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideServiceList(BuildContext context, MineLogic logic) {
    final items = _serviceItems(logic);
    return Column(
      children: [
        for (final s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(R.md),
              onTap: s.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(R.md),
                ),
                child: Row(
                  children: [
                    Icon(s.icon, size: 17, color: s.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.t1,
                        ),
                      ),
                    ),
                    Icon(
                      Lz.chevronRight,
                      size: 17,
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

  Widget _profileCardInner(BuildContext context, MineLogic logic, bool logged) {
    return Row(
      children: [
        // 头像 + 光晕环
        AppPressable(
          onTap: () => logged ? logic.openProfileEdit() : logic.openLogin(),
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: logged ? Deco.goldGradient : Deco.brandGradient,
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.isDark ? C.bg2 : Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: logic.avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                        memCacheWidth: 400,
                      imageUrl: logic.avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _defaultAvatar(context),
                      errorWidget: (_, __, ___) => _defaultAvatar(context),
                    )
                  : _defaultAvatar(context),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    logged ? logic.openProfileEdit() : logic.openLogin(),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    logic.nickname.isEmpty ? '点击登录' : logic.nickname,
                    style: Ty.h1.copyWith(color: context.t1, fontSize: 21),
                  ),
                  _userTitleBadge(logic.userTitle),
                ]),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      logged
                          ? ((UserService.instance.user?.qq ?? '').isNotEmpty
                                ? 'QQ ${UserService.instance.user!.qq}'
                                : '账号 ${logic.uid}')
                          : '登录后享受完整功能',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.small.copyWith(color: context.t3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(30),
                      borderRadius: BorderRadius.circular(R.xs),
                    ),
                    child: Obx(
                      () => Text(
                        // ★ 1015 修复：原来写死 'v3.3'，永远不跟随真实版本
                        MineComponent.verTag.value,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: C.brandBright,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ★ 必须用 Wrap：三个徽标在窄屏 Row 里会溢出，
              //   右侧「未开通 VIP」被裁掉（截图里可见）
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  if (logged) ...[
                    // ★ 积分徽标：可点击进「积分兑换」，带金币图标更醒目
                    _tappableBadge(
                      context,
                      '积分 ${logic.points}',
                      C.violet,
                      icon: Lz.money,
                      onTap: _uiCfg.featureExchange
                          ? () => logic.pointsExchange()
                          : null,
                    ),
                    _badge(
                      context,
                      '余额 ¥${logic.money}',
                      C.mint,
                      icon: Lz.payWallet,
                    ),
                  ],
                  _badge(
                    context,
                    logic.isVip ? 'VIP 会员' : '未开通 VIP',
                    logic.isVip ? C.amber : C.t3,
                    icon: Lz.vip,
                  ),
                ],
              ),
            ],
          ),
        ),
        Icon(Lz.chevronRight, color: context.t3, size: 22),
      ],
    );
  }

  /// split 模板专属：渐变问候横幅（按时段问候，品牌渐变 + 投影）
  Widget _splitHero(BuildContext context, MineLogic logic) {
    final logged = logic.isLoggedIn;
    final hour = DateTime.now().hour;
    final greet = hour < 6
        ? '夜深了'
        : hour < 12
        ? '早上好'
        : hour < 14
        ? '中午好'
        : hour < 18
        ? '下午好'
        : '晚上好';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      decoration: BoxDecoration(
        gradient: C.brandGradient,
        borderRadius: BorderRadius.circular(R.xl),
        boxShadow: [
          BoxShadow(
            color: C.brand.withAlpha(context.isDark ? 55 : 75),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(46),
              shape: BoxShape.circle,
            ),
            child: Icon(
              logged ? Lz.hand : Lz.userPlus,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  logged ? greet : '欢迎回来',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  logged ? '今日也要元气满满哦' : '登录后体验更多功能',
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
    );
  }

  Widget _profileCard(BuildContext context, MineLogic logic) {
    final logged = logic.isLoggedIn;
    final grad =
        (SoftService.instance.cachedConfig?.uiConfig.mineTemplate ?? '') ==
        'gradient';
    if (grad) {
      // v52m #5：gradient 模板 —— 渐变描边
      return Container(
        padding: const EdgeInsets.all(1.4),
        decoration: BoxDecoration(
          gradient: C.brandGradient,
          borderRadius: BorderRadius.circular(R.xl + 1.4),
        ),
        child: Deco.glass(
          context,
          radius: R.xl,
          alpha: 0.07,
          padding: const EdgeInsets.all(16.6),
          glow: C.brand,
          child: _profileCardInner(context, logic, logged),
        ),
      );
    }
    return Deco.glass(
      context,
      radius: R.xl,
      alpha: 0.07,
      padding: const EdgeInsets.all(18),
      glow: C.brand,
      child: _profileCardInner(context, logic, logged),
    );
  }

  Widget _defaultAvatar(BuildContext context) => Container(
    color: context.isDark ? C.bg2 : C.lbg2,
    alignment: Alignment.center,
    child: Icon(Lz.user, size: 34, color: C.brandBright),
  );

  Widget _badge(
    BuildContext context,
    String text,
    Color color, {
    IconData? icon,
  }) {
    return Pill(text, color: color, icon: icon);
  }

  /// 可点击徽标（积分 → 积分兑换）
  Widget _tappableBadge(
    BuildContext context,
    String text,
    Color color, {
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final p = Pill(text, color: color, icon: icon);
    if (onTap == null) return p;
    return GestureDetector(onTap: onTap, child: p);
  }

  // ───────── ② 数据条 ─────────
  Widget _statsRow(BuildContext context, MineLogic logic) {
    final items = [
      (
        '消息',
        !logic.isLoggedIn
            ? '-'
            : (logic.messageCount > 0 ? '${logic.messageCount}' : '0'),
        Lz.messageCircle,
        C.brandBright,
      ),
      (
        '关注',
        logic.isLoggedIn ? '${logic.followCount}' : '-',
        Lz.userPlus,
        C.cyan,
      ),
      (
        '粉丝',
        logic.isLoggedIn ? '${logic.fansCount}' : '-',
        Icons.groups_rounded,
        C.mint,
      ),
      (
        _uiCfg.featureCheckin
            ? (!logic.isLoggedIn ? '-' : (logic.signedToday ? '已签' : '签到'))
            : '未开放',
        _uiCfg.featureCheckin
            ? (!logic.isLoggedIn
                  ? '-'
                  : (logic.signedToday ? logic.signedDate : '未签'))
            : '',
        Lz.badge,
        C.amber,
      ),
    ];
    return Deco.glass(
      context,
      radius: R.lg,
      alpha: 0.055,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 26,
                color: context.isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.black.withAlpha(8),
              ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!logic.isLoggedIn) {
                    logic.openLogin();
                    return;
                  }
                  if (items[i].$1 == '签到' || items[i].$1 == '已签') {
                    if (_uiCfg.featureCheckin) logic.signIn();
                  } else if (items[i].$1 == '消息') {
                    logic.openMessages();
                  }
                },
                child: Column(
                  children: [
                    // ★ 1109：有未读消息时，图标右上角加红点（原来只有数字，不够醒目）
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(items[i].$3, size: 19, color: items[i].$4),
                        if (items[i].$1 == '消息' && logic.messageCount > 0)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: C.danger,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.isDark ? C.bg0 : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      items[i].$2,
                      style: Ty.h3.copyWith(
                        // 有未读时数字标红，和红点呼应
                        color: items[i].$1 == '消息' && logic.messageCount > 0
                            ? C.danger
                            : context.t1,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$1,
                      style: Ty.tiny.copyWith(color: context.t3),
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

  // ───────── ③ 会员横幅 ─────────
  Widget _vipBanner(BuildContext context, MineLogic logic) {
    return GestureDetector(
      onTap: () =>
          logic.isLoggedIn ? Get.toNamed(Routes.vip) : logic.openLogin(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
        decoration: BoxDecoration(
          // ★ 1105l：会员横幅跟随全局配色（原写死金色，与主题「格格不入」）
          gradient: Deco.vipGradient(context),
          borderRadius: BorderRadius.circular(R.lg),
          boxShadow: [
            BoxShadow(
              color: Deco.vipAccent(context).withAlpha(context.isDark ? 60 : 45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(28),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Lz.vip,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '赞助会员',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    !logic.isLoggedIn
                        ? '登录后可开通会员'
                        : (logic.vipExpire.isEmpty
                              ? '开通享全部特权'
                              : '有效期至 ${logic.vipExpire}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(205),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(R.full),
              ),
              // v52f #11：已是会员显示「立即续费」，未开通才显示「立即开通」
              child: Text(
                logic.isLoggedIn && logic.isVip ? '立即续费' : '立即开通',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── ④ 服务宫格 ─────────
  Widget _sectionTitle(BuildContext context, String t) =>
      SectionHeader(title: t);

  Widget _serviceGrid(BuildContext context, MineLogic logic) {
    return Obx(
      () => _serviceGridInner(
        context,
        logic,
        SoftService.instance.configVersion.value,
      ),
    );
  }

  Widget _serviceGridInner(BuildContext context, MineLogic logic, int _) {
    final items = _serviceItems(logic);

    return KitCard(
      radius: R.lg,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i += context.serviceCols)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  for (int j = i; j < i + context.serviceCols; j++)
                    Expanded(
                      child: j < items.length
                          ? _gridCell(context, items[j])
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 1109：勋章墙（成就 → 勋章；未获得显示灰色）
  Future<void> _showMedals() async {
    List<GoalItem> list = [];
    try {
      list = await GoalService.instance.list();
    } catch (_) {}
    final achs = list.where((g) => g.kind == 1).toList();
    final earned = achs.where((g) => g.claimed == 1).length;
    final ctx0 = Get.context!;
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx0).size.height * 0.75),
        decoration: BoxDecoration(
          color: ctx0.isDark ? C.bg2 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
                color: ctx0.t3.withAlpha(60),
                borderRadius: BorderRadius.circular(99)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFD86F), Color(0xFFFF8A3D)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.military_tech_rounded,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我的勋章',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ctx0.t1)),
                    Text('已点亮 ${earned + (Get.isRegistered<MineLogic>(tag: 'mine') && Get.find<MineLogic>(tag: 'mine').isVip ? 1 : 0)} / ${achs.length + 1}',
                        style: TextStyle(fontSize: 11, color: ctx0.t3)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Lz.x, size: 20, color: ctx0.t3),
                onPressed: () => Get.back(),
              ),
            ]),
          ),
          Divider(height: 1, color: ctx0.t3.withAlpha(20)),
          Flexible(
            child: achs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(36),
                    child: Text('还没有成就勋章，去「任务与成就」看看',
                        style: TextStyle(fontSize: 12.5, color: ctx0.t3)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.86),
                    itemCount: achs.length + 1, // 末尾固定一个「会员勋章」
                    itemBuilder: (_, i) {
                      if (i == achs.length) {
                        return VipMedalBadge(
                          earned: Get.isRegistered<MineLogic>(tag: 'mine')
                              ? (Get.find<MineLogic>(tag: 'mine').isVip)
                              : false,
                          size: 54,
                        );
                      }
                      final g = achs[i];
                      final got = g.claimed == 1;
                      final tier = medalTierOf(
                          g.titleMasked ? '神秘成就' : g.title);
                      return MedalBadge(
                        name: (g.titleMasked || g.title.contains('？')) && !got ? '神秘成就' : g.title,
                        icon: tier.icon,
                        earned: got,
                        size: 54,
                        rarity: g.titleMasked
                            ? TitleRarity.legend
                            : (got ? tier.rarity : TitleRarity.common),
                      );
                    },
                  ),
          ),
        ]),
      ),
      isScrollControlled: true,
    );
  }

  IconData _medalIcon(GoalItem g) {
    final t = '${g.title}${g.category}';
    if (t.contains('下载')) return Lz.download;
    if (t.contains('购买') || t.contains('消费')) return Lz.wallet;
    if (t.contains('签到') || t.contains('登录')) return Lz.calendar;
    if (t.contains('邀请')) return Lz.users;
    if (t.contains('评论') || t.contains('发帖')) return Lz.messageCircle;
    if (t.contains('狂') || t.contains('神')) return Lz.flame;
    return Lz.trophy;
  }

  /// 1108z9：自定义称号弹窗（入口已移除；称号改由后台管理员配置。保留备用）
  // ignore: unused_element
  Future<void> _editTitleDialog(BuildContext ctx) async {
    final logic = Get.isRegistered<MineLogic>(tag: 'mine')
        ? Get.find<MineLogic>(tag: 'mine')
        : Get.find<MineLogic>();
    final ctrl = TextEditingController(text: logic.userTitle);
    final dark = Theme.of(ctx).brightness == Brightness.dark;
    final okdel = await Get.dialog<bool>(AlertDialog(
      backgroundColor: dark ? C.bg2 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('自定义称号', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('展示在昵称旁，最多 12 字，留空清除',
              style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLength: 12,
            decoration: InputDecoration(
              hintText: '如：软件达人',
              counterText: '',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (okdel != true) return;
    try {
      await UserService.instance.setTitle(ctrl.text.trim());
      await logic.refreshUserTitle(ctrl.text.trim());
      ToastUtil.success(ctrl.text.trim().isEmpty ? '称号已清除' : '称号已更新');
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 1109：称号徽章（我的页大号）
  /// ★ 修复崩溃：MineLogic 是用 tag:'mine' 注册的（navigate_binding），
  ///   这里必须带 tag 查找，且找不到时不能抛异常（否则整个「我的」页白屏）。
  Widget _userTitleBadge(String title) {
    bool vip = false;
    try {
      final l = Get.isRegistered<MineLogic>(tag: 'mine')
          ? Get.find<MineLogic>(tag: 'mine')
          : (Get.isRegistered<MineLogic>() ? Get.find<MineLogic>() : null);
      vip = l?.isVip ?? false;
    } catch (_) {}
    return TitleBadge(title, isVip: vip, scale: 1.15);
  }

  /// v54：服务条目统一抽取（宫格 / 分组列表 / 扁平列表共用）
  List<_S> _serviceItems(MineLogic logic) {
    return [
      // ★ 1016：做任务领会员 —— 放在最前面，方便普通用户「白嫖」
      _S(
        '免费领会员',
        Lz.gift,
        C.accentOrange,
        () => Get.toNamed(Routes.task),
      ),
      // ★ 1108z W1：任务与成就（统一事件引擎）
      _S(
        '任务与成就',
        Icons.emoji_events_rounded,
        C.gold,
        () => Get.toNamed(Routes.goal),
      ),
      // ★ 1109：我的勋章（成就可视化）
      _S(
        '我的勋章',
        Icons.military_tech_rounded,
        C.violet,
        () => _showMedals(),
      ),

      if (_uiCfg.featureInvite)
        _S(
          '邀请好友',
          Lz.gift,
          C.rose,
          () => Get.toNamed(Routes.invite),
        ),
      // ★ 1020（待办）：统一收藏夹 —— 软件 + 工具一个入口（后台可关）
      if (_uiCfg.featureFavorites)
        _S(
          '我的收藏',
          Lz.star,
          C.amber,
          () => Get.toNamed(Routes.favorites),
        ),
      // ★ 1020（待办）：使用历史（可删除 / 批量清理，后台可关）
      if (_uiCfg.featureHistory)
        _S(
          '使用历史',
          Lz.history,
          C.violet,
          () => Get.toNamed(Routes.history),
        ),
      _S(
        '充值余额',
        Lz.payWallet,
        C.mint,
        () => logic.recharge(),
      ),
      // ★ 1016：绑定 QQ —— 老用户用它把 QQ 绑到自己原有的账号上
      // ★ 1020：已绑定时改为「解绑QQ」，并且能解绑（之前只能绑、不能解）
      if (logic.isLoggedIn)
        _S(
          logic.qqBound ? 'QQ 已绑定' : '绑定QQ',
          logic.qqBound ? Lz.badge : Lz.link,
          logic.qqBound ? C.brand : C.brand,
          () {
            if (logic.qqBound) {
              // ★ 1028：已绑定的用户经常发现还是「QQ用户1234」默认名 ——
              //   给一个显式的「重新同步昵称/头像」入口，不用解绑再绑
              Get.dialog<bool>(
                AppDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  title: const Text('QQ 已绑定', style: TextStyle(fontSize: 16)),
                  content: const Text(
                    '昵称/头像显示的还是默认值？可以重新同步一次 QQ 资料。\n'
                    '（同步会用 QQ 昵称和头像覆盖当前资料）',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Get.back();
                        logic.unbindQQ();
                      },
                      child: const Text('解绑', style: TextStyle(color: C.danger)),
                    ),
                    TextButton(
                      onPressed: () {
                        Get.back();
                        logic.bindQQ(sync: true);
                      },
                      child: Text(
                        '同步资料',
                        style: TextStyle(color: C.brand),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              logic.bindQQ();
            }
          },
        ),
      if (_uiCfg.featureDonateRank)
        _S(
          '赞助排行',
          Lz.trophy,
          C.amber,
          () => logic.sponsorRank(),
        ),
      if (_uiCfg.featureCardRedeem)
        _S(
          '使用卡密',
          Lz.ticket,
          C.rose,
          () => logic.redeem(),
        ),
      // ★ 1014 需求5：卡密商城（原来只能使用卡密，没地方买）
      if (_uiCfg.featureCardShop)
        _S(
          '卡密商城',
          Lz.store,
          C.gold,
          () => Get.toNamed(Routes.cardShop),
        ),
      _S(
        '下载管理',
        Lz.download,
        C.mint,
        () => Get.toNamed(Routes.appDownload),
      ),
      if (_uiCfg.featureQqGroup)
        _S('QQ通知群', Icons.forum_rounded, C.cyan, () {
          logic.joinGroup();
        }),
      // ★ 1014 需求3：分享本软件（分享文案后台可配）
      if (_uiCfg.featureShareApp)
        _S('分享本体', Lz.share, C.brandBright, () => logic.shareApp()),
      if (_uiCfg.featureExchange)
        _S(
          '积分兑换',
          Lz.money,
          C.accentOrange,
          () => logic.pointsExchange(),
        ),
      // 后台「允许用户自选明暗」打开时才出现
      if (_uiCfg.allowUserThemeToggle)
        _S(
          '外观',
          Lz.moon,
          C.violet,
          () {
            final c = SafeCtx.of();
            if (c != null) _pickTheme(c);
          },
        ),
      // 后台「关于页开关」关掉后不再出现
      if (SoftService.instance.cachedConfig?.aboutEnable ?? true)
        _S('关于软件', Lz.info, C.brandBright, () {
          final c = SafeCtx.of();
          if (c != null) logic.about(c);
        }),
      _S(
        '用户协议',
        Lz.fileText,
        C.violet,
        () => logic.showAgreementPage('agreement'),
      ),
      _S(
        '隐私政策',
        Lz.shield,
        C.pink,
        () => logic.showAgreementPage('privacy'),
      ),
      if (_uiCfg.featureReplaceSplash)
        _S('替换开屏', Lz.image, C.mint, () => logic.replaceSplash()),
      if (logic.isAdmin)
        _S(
          '后台管理',
          Icons.admin_panel_settings_rounded,
          C.rose,
          () => logic.openAdminPanel(),
        ),
    ];
  }

  Widget _gridCell(BuildContext context, _S s) {
    return AppPressable(
      onTap: s.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: s.color.withAlpha(context.isDark ? 34 : 24),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: s.color.withAlpha(60), width: 0.8),
              ),
              child: Icon(s.icon, color: s.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              s.label,
              style: Ty.tiny.copyWith(
                color: context.t2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── ⑤ 底部按钮 ─────────
  Widget _actionButton(BuildContext context, MineLogic logic) {
    final logged = logic.isLoggedIn;
    // 未登录：主行动按钮（醒目实心蓝）—— 引导注册/登录
    // 已登录：柔和描边（退出登录是低频/危险操作，不该高亮吸睛）
    return logged
        ? SoftButton(
            label: '退出登录',
            color: C.rose,
            height: 52,
            expand: true,
            onPressed: logic.logout,
          )
        : PrimaryButton(
            label: '登录 / 注册',
            icon: Lz.logIn,
            height: 52,
            onPressed: logic.openLogin,
          );
  }

  /// 外观选择：浅色 / 深色 / 跟随系统（后台允许用户自选时才有入口）
  Future<void> _pickTheme(BuildContext c) async {
    final cur = ThemeController.instance.mode.value;
    final v = await showGlassSheet<String>(
      context: c,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('外观', style: Ty.h3.copyWith(color: ctx.t1)),
            ),
          ),
          for (final e in const <(String, ThemeMode, IconData)>[
            ('浅色', ThemeMode.light, Lz.sun),
            ('深色', ThemeMode.dark, Lz.moon),
            ('跟随系统', ThemeMode.system, Icons.brightness_auto_rounded),
          ])
            ListTile(
              dense: true,
              leading: Icon(e.$3, size: 20, color: ctx.t2),
              title: Text(e.$1, style: Ty.small.copyWith(color: ctx.t1)),
              trailing: cur == e.$2
                  ? Icon(Lz.check, size: 18, color: C.brand)
                  : null,
              onTap: () => Navigator.pop(ctx, e.$1),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (v == null) return;
    // 主题模式是 Rx，main.dart 的 Obx 会自动重建整个 App，这里不用 setState
    await ThemeController.instance.setMode(switch (v) {
      '深色' => ThemeMode.dark,
      '跟随系统' => ThemeMode.system,
      _ => ThemeMode.light,
    });
  }
}

class _S {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _S(this.label, this.icon, this.color, this.onTap);
}


/// 1109：勋章条 —— 我的页顶部横向展示已点亮勋章
class _MedalStrip extends StatefulWidget {
  const _MedalStrip({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_MedalStrip> createState() => _MedalStripState();
}

class _MedalStripState extends State<_MedalStrip> {
  List<GoalItem> _achs = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await GoalService.instance.list();
      if (!mounted) return;
      setState(() {
        _achs = all.where((g) => g.kind == 1).toList();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_achs.isEmpty) return const SizedBox.shrink();
    final earned = _achs.where((g) => g.claimed == 1).toList();
    final show = earned.isNotEmpty ? earned : _achs;
    return AppPressable(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(
            color: context.isDark ? C.bg3 : C.lbg2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.military_tech_rounded, size: 15, color: C.gold),
              const SizedBox(width: 6),
              Text('我的勋章',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.t1)),
              const SizedBox(width: 6),
              Text('已点亮 ${earned.length}/${_achs.length}',
                  style: TextStyle(fontSize: 10.5, color: context.t3)),
              const Spacer(),
              Text('全部', style: TextStyle(fontSize: 10.5, color: context.t3)),
              Icon(Lz.chevronRight, size: 12, color: context.t3),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: show.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final g = show[i];
                  final got = g.claimed == 1;
                  return MedalBadge(
                    name: g.titleMasked && !got ? '神秘成就' : g.title,
                    icon: _iconFor(g),
                    earned: got,
                    size: 46,
                    rarity: g.titleMasked
                        ? TitleRarity.legend
                        : (got ? TitleRarity.epic : TitleRarity.common),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(GoalItem g) {
    final t = '${g.title}${g.category}';
    if (t.contains('下载')) return Lz.download;
    if (t.contains('购买') || t.contains('消费')) return Lz.wallet;
    if (t.contains('签到') || t.contains('登录')) return Lz.calendar;
    if (t.contains('邀请')) return Lz.users;
    if (t.contains('评论') || t.contains('发帖')) return Lz.messageCircle;
    if (t.contains('狂') || t.contains('神')) return Lz.flame;
    return Lz.trophy;
  }
}


/// 1109：昵称后的小勋章（读当前用户已获得的成就）
class _MyMedalsInline extends StatefulWidget {
  const _MyMedalsInline({this.isVip = false});
  final bool isVip;

  @override
  State<_MyMedalsInline> createState() => _MyMedalsInlineState();
}

class _MyMedalsInlineState extends State<_MyMedalsInline> {
  List<String> _names = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await GoalService.instance.list();
      if (!mounted) return;
      setState(() {
        _names = all
            .where((g) => g.kind == 1 && g.claimed == 1 && !g.titleMasked)
            .map((g) => g.title)
            .take(3)
            .toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_names.isEmpty && !widget.isVip) return const SizedBox.shrink();
    return InlineMedals(medals: _names, isVip: widget.isVip, size: 16);
  }
}
