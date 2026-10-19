import 'package:flutter/material.dart';

import '../../utils/err_text.dart';

import 'admin_ui_kit.dart';

import 'admin_shell_v2.dart';
import 'admin_overview_v2.dart';

import 'tabs/collect_stats_card.dart';

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
import 'tabs/admin_tools_tab.dart';
import 'tabs/admin_users_tab.dart';

/// 软件内嵌管理系统（管理员专用）
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 12, vsync: this);

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
    // ★ 1016 后台外壳重做：改用新的商业化导航壳 AdminShellV2
    //   （旧 AdminTemplateShell 的 12 个胶囊挤一行 → 现在分组 + 图标 + 横向滚动）
    //   功能不变：仍是同样的 12 个子页
    return AdminShellV2(
      tab: _tab,
      templateName: adminTemplateCurrent, // ★ 1016：传入模板名 → 5 套真实架构
      onRefresh: () => setState(() {}),
      children: const [
        AdminOverviewV2(), // ★ 1016 阶段2：概览彻底重写为商业化仪表盘
        AdminAppsTab(),
        AdminUsersTab(),
        AdminOrdersTab(),
        AdminCollectTab(),
        AdminContentTab(),
        AdminUiTab(),
        AdminLogsTab(),
        AdminSplashTab(),
        AdminSecurityTab(),
        AdminJicunTab(),
        AdminToolsTab(),
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
      ToastUtil.error(ErrText.of(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState(text: '加载概览数据…');
    }
    // v52f #8：概览顶部系统信息卡（视觉重构的一部分）
    final sysCard = AdCard(
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
                  (it) => AdCard(
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
          const AdSection(title: '经营数据', accent: C.gold),
          GridView.count(
            crossAxisCount: context.isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: biz
                .map(
                  (it) => AdCard(
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
          // ═════ ★ 1016 软件数据（商业化总览，异步加载）═════
          const SizedBox(height: 20),
          const CollectStatsCard(),
          // ═════ 启动数据 ═════
          const SizedBox(height: 20),
          AdSection(
            title: '启动数据',
            subtitle: 'App 每次启动都会上报（tag=boot）',
            accent: C.brandBright,
          ),
          AdCard(
            radius: R.lg,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _miniStat(
                      '今日启动',
                      '${_d['boot_today'] ?? 0}',
                      C.brandBright,
                    ),
                    const SizedBox(width: 10),
                    _miniStat(
                      '今日设备',
                      '${_d['boot_devices_today'] ?? 0}',
                      C.mint,
                    ),
                    const SizedBox(width: 10),
                    _miniStat(
                      '昨日启动',
                      '${(() {
                        final bt = (_d['boot_trend'] as List?) ?? [];
                        if (bt.length < 2) return 0;
                        final y = bt[bt.length - 2];
                        return y is Map ? (y['count'] ?? 0) : 0;
                      })()}',
                      C.accentOrange,
                    ),
                  ],
                ),
                if (((_d['boot_trend'] as List?) ?? []).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (final b in (_d['boot_trend'] as List))
                    if (b is Map)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 42,
                              child: Text(
                                '${b['date'] ?? ''}',
                                style: Ty.tiny.copyWith(color: context.t3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _trendBar(
                                double.tryParse('${b['count'] ?? 0}') ?? 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 42,
                              child: Text(
                                '${b['count'] ?? 0}次',
                                textAlign: TextAlign.right,
                                style: Ty.tiny.copyWith(color: C.brandBright),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ],
            ),
          ),
          // ═════ 在线数据 ═════
          const SizedBox(height: 20),
          AdSection(
            title: '在线数据',
            subtitle: '按最后活跃时间统计（5 分钟内有请求算活跃）',
            accent: C.mint,
          ),
          AdCard(
            radius: R.lg,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    _miniStat('5 分钟', '${_d['online_5m'] ?? 0}', C.mint),
                    const SizedBox(width: 10),
                    _miniStat('15 分钟', '${_d['online_15m'] ?? 0}', C.cyan),
                    const SizedBox(width: 10),
                    _miniStat('60 分钟', '${_d['online_60m'] ?? 0}', C.brand),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniStat('24 小时', '${_d['online_24h'] ?? 0}', C.violet),
                    const SizedBox(width: 10),
                    _miniStat('活跃会话', '${_d['active_tokens'] ?? 0}', C.amber),
                    const SizedBox(width: 10),
                    _miniStat(
                      '今日登录用户',
                      '${_d['today_active_users'] ?? 0}',
                      C.pink,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ═════ 下载数据 + 下载记录 ═════
          const SizedBox(height: 20),
          AdSection(
            title: '下载数据',
            subtitle: '今日下载 / 失败 / 累计 · 点记录看详情',
            accent: C.cyan,
          ),
          AdCard(
            radius: R.lg,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _miniStat('今日下载', '${_d['down_today'] ?? 0}', C.mint),
                    const SizedBox(width: 10),
                    _miniStat('今日失败', '${_d['down_today_fail'] ?? 0}', C.rose),
                    const SizedBox(width: 10),
                    _miniStat('累计下载', '${_d['total_down'] ?? 0}', C.cyan),
                  ],
                ),
                const SizedBox(height: 12),
                if (((_d['recent_downloads'] as List?) ?? []).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '暂无下载记录（App 下载成功/失败都会上报）',
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  )
                else
                  for (final r in (_d['recent_downloads'] as List))
                    if (r is Map)
                      Builder(
                        builder: (c) {
                          final ok = '${r['status']}' == 'ok';
                          return InkWell(
                            onTap: () => _showDownloadDetail(r),
                            borderRadius: BorderRadius.circular(R.sm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: ok ? C.mint : C.rose,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  SizedBox(
                                    width: 62,
                                    child: Text(
                                      '${r['time_text'] ?? ''}',
                                      style: Ty.tiny.copyWith(
                                        color: context.t3,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${r['app_title'] ?? ''}'
                                      '${ok ? '' : ' · ${r['error'] ?? ''}'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Ty.small.copyWith(
                                        color: ok ? context.t1 : C.rose,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    ok ? '成功' : '失败',
                                    style: Ty.tiny.copyWith(
                                      color: ok ? C.mint : C.rose,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: Colors.transparent,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
          // ═════ 热门软件 ═════
          if (((_d['top_apps'] as List?) ?? []).isNotEmpty) ...[
            const SizedBox(height: 20),
            AdSection(
              title: '热门软件 Top5',
              subtitle: '按下载量排序 · 累计下载 ${_d['total_down'] ?? 0} 次',
              accent: C.rose,
            ),
            AdCard(
              radius: R.lg,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (int i = 0; i < (_d['top_apps'] as List).length; i++)
                    Builder(
                      builder: (c) {
                        final a = (_d['top_apps'] as List)[i];
                        final title = a is Map ? '${a['title'] ?? ''}' : '';
                        final down = a is Map ? '${a['down_count'] ?? 0}' : '0';
                        final views = a is Map ? '${a['views'] ?? 0}' : '0';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? C.gold.withAlpha(40)
                                      : C.brand.withAlpha(24),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: Ty.tiny.copyWith(
                                    color: i == 0 ? C.gold : C.brand,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ty.small.copyWith(color: context.t1),
                                ),
                              ),
                              Text(
                                '下载 $down',
                                style: Ty.tiny.copyWith(color: C.mint),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '浏览 $views',
                                style: Ty.tiny.copyWith(color: context.t3),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
          if (trend.isNotEmpty) ...[
            const SizedBox(height: 20),
            AdSection(title: '近 7 日趋势', subtitle: '新增用户 / 收入', accent: C.brand),
            AdCard(
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

  /// 下载记录详情（含失败原因、IP、设备、用户）
  void _showDownloadDetail(Map r) {
    final ok = '${r['status']}' == 'ok';
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ok ? '下载成功' : '下载失败'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _dlRow('时间', '${r['time_text'] ?? ''}'),
              _dlRow('软件', '${r['app_title'] ?? ''}'),
              _dlRow(
                '用户',
                '${r['nickname'] ?? ''}'
                    '${(r['user_id'] ?? 0).toString() == '0' ? '（未登录）' : ' (ID ${r['user_id']})'}',
              ),
              _dlRow('状态', ok ? '成功' : '失败'),
              _dlRow('IP', '${r['ip'] ?? '-'}'),
              _dlRow('设备', '${r['device'] ?? '-'}'),
              if (!ok) ...[
                const SizedBox(height: 8),
                const Text(
                  '失败原因',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  '${r['error'] ?? ''}'.isEmpty ? '(未记录)' : '${r['error']}',
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _dlRow(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            k,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5))),
      ],
    ),
  );

  /// 迷你数据块（启动/在线用）
  Widget _miniStat(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: color.withAlpha(context.isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    ),
  );

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
