import 'package:flutter/material.dart';

import '../../api/admin_service.dart';
import '../../api/user_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'admin_template.dart';
import 'tabs/admin_apps_tab.dart';
import 'tabs/admin_collect_tab.dart';
import 'tabs/admin_content_tab.dart';
import 'tabs/admin_jicun_tab.dart';
import 'tabs/admin_logs_tab.dart';
import 'tabs/admin_orders_tab.dart';
import 'tabs/admin_splash_tab.dart';
import 'tabs/admin_security_tab.dart';
import 'tabs/admin_ui_tab.dart';
import 'tabs/admin_users_tab.dart';

/// 软件内嵌管理系统（管理员专用）
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 10, vsync: this);

  bool _checking = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // v54：后台模板热切换（「界面」Tab 保存后即时生效）
    adminTemplateNotifier.addListener(_onTplChanged);
    _check();
  }

  void _onTplChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    adminTemplateNotifier.removeListener(_onTplChanged);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final u = UserService.instance.user;
    if (!UserService.instance.isLoggedIn) {
      setState(() {
        _checking = false;
        _isAdmin = false;
      });
      return;
    }
    if (u?.isAdmin != true) {
      await UserService.instance.refreshProfile();
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _isAdmin = UserService.instance.user?.isAdmin == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Deco.pageBackground(context),
            const LoadingState(text: '正在校验管理员权限…'),
          ],
        ),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Deco.pageBackground(context),
            const EmptyState(
              icon: Icons.lock_outline_rounded,
              text: '仅管理员可访问',
              hint: '请使用管理员账号登录后重试',
            ),
          ],
        ),
      );
    }

    // v54：管理后台整体界面模板（light_card/dark_console/minimal/brand/desk）
    final tpl = adminTemplateCurrent;
    if (adminTemplateNotifier.value != tpl) adminTemplateNotifier.value = tpl;
    return AdminTemplateShell(
      tab: _tab,
      onRefresh: () => setState(() {}),
      children: const [
        _OverviewTab(),
        AdminAppsTab(),
        AdminUsersTab(),
        AdminOrdersTab(),
        AdminCollectTab(),
        AdminContentTab(),
        AdminUiTab(),
        AdminLogsTab(),
        AdminSplashTab(),
        AdminSecurityTab(),
      ],
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic> _d = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AdminService.instance.dashboard();
      if (mounted) {
        setState(() {
          _d = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState(text: '加载概览数据…');
    }
    // v52f #8：概览顶部系统信息卡（视觉重构的一部分）
    final sysCard = GlassCard(
      radius: R.xl,
      padding: const EdgeInsets.all(16),
      glow: C.brand,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: C.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('系统运行正常', style: Ty.h3.copyWith(color: context.t1)),
                const SizedBox(height: 3),
                Text(
                  'API · 数据库 · 采集服务 · 支付通道（状态以上方开关为准）',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Colors.transparent,
          ),
        ],
      ),
    );

    final items = [
      ('软件总数', _d['apps'], C.brandBright, Icons.apps_rounded),
      ('用户总数', _d['users'], C.mint, Icons.people_rounded),
      ('今日注册', _d['today_users'], C.accentOrange, Icons.person_add_rounded),
      ('会员数', _d['vip_users'], C.amber, Icons.workspace_premium_rounded),
      ('动态数', _d['posts'], C.violet, Icons.forum_rounded),
      ('评价数', _d['reviews'], C.pink, Icons.rate_review_rounded),
      ('线报', _d['reports'], C.cyan, Icons.article_rounded),
      ('卡密', _d['cards'], C.rose, Icons.confirmation_number_rounded),
    ];
    // 经营数据（收入 / 订单 / 浏览）
    final biz = [
      (
        '累计收入',
        '¥${_d['total_money'] ?? '0.00'}',
        C.gold,
        Icons.account_balance_wallet_rounded,
      ),
      (
        '今日收入',
        '¥${_d['today_money'] ?? '0.00'}',
        C.success,
        Icons.trending_up_rounded,
      ),
      (
        '已付订单',
        '${_d['paid_orders'] ?? 0}',
        C.brand,
        Icons.receipt_long_rounded,
      ),
      (
        '待付订单',
        '${_d['unpaid_orders'] ?? 0}',
        C.warning,
        Icons.pending_actions_rounded,
      ),
    ];
    final trend = (_d['trend'] as List?) ?? [];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          10,
          context.pagePadding,
          30,
        ),
        children: [
          sysCard,
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: context.isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: items
                .map(
                  (it) => GlassCard(
                    radius: R.lg,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: it.$3.withAlpha(context.isDark ? 36 : 24),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(it.$4, size: 16, color: it.$3),
                        ),
                        Text(
                          '${it.$2 ?? 0}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: context.t1,
                          ),
                        ),
                        Text(it.$1, style: Ty.tiny.copyWith(color: context.t3)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: '经营数据', accent: C.gold),
          GridView.count(
            crossAxisCount: context.isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: biz
                .map(
                  (it) => GlassCard(
                    radius: R.lg,
                    padding: const EdgeInsets.all(14),
                    glow: it.$3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: it.$3.withAlpha(context.isDark ? 36 : 24),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(it.$4, size: 16, color: it.$3),
                        ),
                        Text(
                          it.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: it.$3,
                          ),
                        ),
                        Text(it.$1, style: Ty.tiny.copyWith(color: context.t3)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          if (trend.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionHeader(
              title: '近 7 日趋势',
              subtitle: '新增用户 / 收入',
              accent: C.brand,
            ),
            GlassCard(
              radius: R.lg,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
              child: Column(
                children: [
                  for (final t in trend)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 42,
                            child: Text(
                              '${t['date'] ?? ''}',
                              style: Ty.tiny.copyWith(color: context.t3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _trendBar(
                              double.tryParse('${t['users'] ?? 0}') ?? 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${t['users'] ?? 0}人',
                            style: Ty.tiny.copyWith(color: C.mint),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 58,
                            child: Text(
                              '¥${t['money'] ?? '0.00'}',
                              textAlign: TextAlign.right,
                              style: Ty.tiny.copyWith(color: C.gold),
                            ),
                          ),
                        ],
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

  /// 趋势条（按 7 日内最大值归一化）
  Widget _trendBar(double value) {
    final trend = (_d['trend'] as List?) ?? [];
    double maxV = 1;
    for (final t in trend) {
      final v = double.tryParse('${t['users'] ?? 0}') ?? 0;
      if (v > maxV) maxV = v;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.full),
      child: LinearProgressIndicator(
        value: (value / maxV).clamp(0.06, 1.0),
        minHeight: 8,
        backgroundColor: context.isDark
            ? Colors.white.withAlpha(16)
            : Colors.black.withAlpha(8),
        valueColor: AlwaysStoppedAnimation<Color>(C.brand.withAlpha(200)),
      ),
    );
  }
}
