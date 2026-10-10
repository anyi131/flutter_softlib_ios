import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../generated/assets.dart';
import '../../../api/soft_service.dart';
import '../../../models/ui_config.dart';
import '../../../api/user_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: GetBuilder<MineLogic>(
              init: Get.put(MineLogic(), tag: 'mine'),
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
        GestureDetector(
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
                Icon(Icons.home_rounded, size: 14, color: context.t3),
                const SizedBox(width: 5),
                Text('回首页', style: Ty.tiny.copyWith(color: context.t3)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════ v54 模板骨架库 ═══════
  /// clean：扁平头像行（无玻璃卡）
  Widget _flatProfile(BuildContext context, MineLogic logic) {
    final logged = logic.isLoggedIn;
    return Row(
      children: [
        GestureDetector(
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
              Text(
                logic.nickname.isEmpty ? '点击登录' : logic.nickname,
                style: Ty.h2.copyWith(color: context.t1, fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                logged ? 'UID ${logic.uid}' : '登录后享受完整功能',
                style: Ty.small.copyWith(color: context.t3),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: context.t3, size: 20),
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
    return InkWell(
      onTap: s.onTap,
      borderRadius: BorderRadius.circular(R.sm),
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
            Icon(Icons.chevron_right_rounded, size: 18, color: context.t3),
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

  Widget _heroStatCell(
    BuildContext context,
    String label,
    String value,
  ) {
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

  Widget _heroStatDivider() => Container(
    width: 1,
    height: 30,
    color: Colors.white.withAlpha(60),
  );

  // ───────── ① 头像卡 ─────────
  /// v52m #5：我的页面模板 classic / clean / gradient
  List<Widget> _mineBody(BuildContext context, MineLogic logic, int configVer) {
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.mineTemplate ?? 'classic';
    // v54：骨架级差异化 —— 每套独立排版骨架
    if (tpl == 'clean') {
      // clean：纯排版无卡 —— 扁平头像行 + 通栏服务清单（无卡片容器）
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
      return [
        _title(context),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.isDark ? C.bg0 : const Color(0xFF171A22),
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
              _sectionTitle(context, '我的服务'),
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

  Widget _profileCardInner(BuildContext context, MineLogic logic, bool logged) {
    return Row(
      children: [
        // 头像 + 光晕环
        GestureDetector(
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
                child: Text(
                  logic.nickname.isEmpty ? '点击登录' : logic.nickname,
                  style: Ty.h1.copyWith(color: context.t1, fontSize: 21),
                ),
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
                    child: Text(
                      'v3.3',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: C.brandBright,
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
                      icon: Icons.monetization_on_rounded,
                      onTap: _uiCfg.featureExchange
                          ? () => logic.pointsExchange()
                          : null,
                    ),
                    _badge(
                      context,
                      '余额 ¥${logic.money}',
                      C.mint,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ],
                  _badge(
                    context,
                    logic.isVip ? 'VIP 会员' : '未开通 VIP',
                    logic.isVip ? C.amber : C.t3,
                    icon: Icons.workspace_premium_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: context.t3, size: 22),
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
              logged ? Icons.waving_hand_rounded : Icons.person_add_alt_rounded,
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
    color: context.isDark ? C.bg2 : const Color(0xFFEDF0F7),
    alignment: Alignment.center,
    child: Icon(Icons.person_rounded, size: 34, color: C.brandBright),
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
        Icons.chat_bubble_rounded,
        C.brandBright,
      ),
      (
        '关注',
        logic.isLoggedIn ? '${logic.followCount}' : '-',
        Icons.person_add_rounded,
        C.cyan,
      ),
      (
        '粉丝',
        logic.isLoggedIn ? '${logic.fansCount}' : '-',
        Icons.groups_rounded,
        C.mint,
      ),
      (
        '已签',
        _uiCfg.featureCheckin
            ? (!logic.isLoggedIn
                  ? '-'
                  : (logic.signedToday ? logic.signedDate : '未签'))
            : '未开放',
        Icons.verified_rounded,
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
                  if (items[i].$1 == '已签') {
                    if (_uiCfg.featureCheckin) logic.signIn();
                  } else if (items[i].$1 == '消息') {
                    logic.openMessages();
                  }
                },
                child: Column(
                  children: [
                    Icon(items[i].$3, size: 19, color: items[i].$4),
                    const SizedBox(height: 7),
                    Text(
                      items[i].$2,
                      style: Ty.h3.copyWith(color: context.t1, fontSize: 14),
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
          gradient: Deco.goldGradient,
          borderRadius: BorderRadius.circular(R.lg),
          boxShadow: [
            BoxShadow(
              color: C.amber.withAlpha(context.isDark ? 60 : 45),
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
                color: Colors.white.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFF3A2E10),
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '赞助会员',
                    style: TextStyle(
                      color: Color(0xFF3A2E10),
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
                    style: const TextStyle(
                      color: Color(0xCC3A2E10),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2410),
                borderRadius: BorderRadius.circular(R.full),
              ),
              // v52f #11：已是会员显示「立即续费」，未开通才显示「立即开通」
              child: Text(
                logic.isLoggedIn && logic.isVip ? '立即续费' : '立即开通',
                style: const TextStyle(
                  color: Color(0xFFF7D57A),
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

  /// v54：服务条目统一抽取（宫格 / 分组列表 / 扁平列表共用）
  List<_S> _serviceItems(MineLogic logic) {
    return [
      if (_uiCfg.featureInvite)
        _S(
          '邀请好友',
          Icons.card_giftcard_rounded,
          C.rose,
          () => Get.toNamed(Routes.invite),
        ),
      _S(
        '充值余额',
        Icons.account_balance_wallet_rounded,
        C.mint,
        () => logic.recharge(),
      ),
      if (_uiCfg.featureDonateRank)
        _S(
          '赞助排行',
          Icons.emoji_events_rounded,
          C.amber,
          () => logic.sponsorRank(),
        ),
      _S(
        '使用卡密',
        Icons.confirmation_number_rounded,
        C.rose,
        () => logic.redeem(),
      ),
      _S(
        '下载管理',
        Icons.download_rounded,
        C.mint,
        () => Get.toNamed(Routes.appDownload),
      ),
      _S('QQ通知群', Icons.forum_rounded, C.cyan, () => logic.joinGroup()),
      if (_uiCfg.featureExchange)
        _S(
          '积分兑换',
          Icons.monetization_on_rounded,
          C.accentOrange,
          () => logic.pointsExchange(),
        ),
      _S('关于软件', Icons.info_rounded, C.brandBright, () => logic.about(context)),
      _S(
        '用户协议',
        Icons.description_rounded,
        C.violet,
        () => logic.showAgreementPage('agreement'),
      ),
      _S(
        '隐私政策',
        Icons.privacy_tip_rounded,
        C.pink,
        () => logic.showAgreementPage('privacy'),
      ),
      _S('替换开屏', Icons.image_rounded, C.mint, () => logic.replaceSplash()),
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
    return GestureDetector(
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
            icon: Icons.login_rounded,
            height: 52,
            onPressed: logic.openLogin,
          );
  }
}

class _S {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _S(this.label, this.icon, this.color, this.onTap);
}
