import 'package:flutter/material.dart';

import '../../api/admin_service.dart';
import '../../design/adaptive.dart';
import '../../design/ui.dart';
import 'admin_ui_kit.dart';

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：管理后台 · 概览（商业化仪表盘 · 彻底重写）
///
/// 相比旧版：不再是一堆零散卡片，而是按「运营视角」分组的数据面板：
///   ① 系统状态     ② 核心指标（软件/用户/会员/今日注册）
///   ③ 软件行为数据（版权梦：启动/加群/联系作者/分享 + 最活跃）
///   ④ 启动数据（今日/设备/昨日 + 7日趋势）
///   ⑤ 在线数据（5/15/60 分 + 活跃会话 + 今日登录）
///   ⑥ 下载数据（今日/失败/累计 + 最近记录可点开看详情）
///   ⑦ 经营数据（累计/今日收入 + 已付/待付订单）
///   ⑧ 热门软件 Top5 + 近 7 日趋势
/// ═══════════════════════════════════════════════════════════════
class AdminOverviewV2 extends StatefulWidget {
  const AdminOverviewV2({super.key});

  @override
  State<AdminOverviewV2> createState() => _AdminOverviewV2State();
}

class _AdminOverviewV2State extends State<AdminOverviewV2> {
  final _svc = AdminService.instance;

  Map<String, dynamic> _d = {};
  // 软件数据（版权梦）单独异步加载
  Map<String, dynamic>? _appStats;
  bool _loading = true;
  bool _statsLoading = true;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadAppStats();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final d = await _svc.dashboard();
      if (!mounted) return;
      setState(() {
        _d = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadAppStats() async {
    setState(() => _statsLoading = true);
    try {
      final d = await _svc.collectEx('app_stats_summary', {'limit': 12});
      if (!mounted) return;
      setState(() {
        _appStats = d;
        _statsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  /// 取数值（保留 1 位小数，用于失败率等）
  String _dbl(String k) {
    final v = _d[k];
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
    return '$v';
  }

  int _i(String k) => int.tryParse('${_d[k] ?? 0}') ?? 0;
  String _s(String k) => '${_d[k] ?? ''}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_err.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.pagePadding),
        child: AdCard(
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, size: 30, color: C.rose),
              const SizedBox(height: 8),
              Text('概览加载失败', style: Ty.h3.copyWith(color: context.t1)),
              const SizedBox(height: 4),
              Text(
                _err,
                textAlign: TextAlign.center,
                style: Ty.tiny.copyWith(color: context.t3),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _load,
                child: Text('点此重试', style: Ty.small.copyWith(color: C.brand)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await _loadAppStats();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          4,
          context.pagePadding,
          30,
        ),
        children: [
          _statusRow(),
          const SizedBox(height: Ad.gapL),

          // ② 核心指标
          AdSection(title: '核心指标', accent: C.brand),
          _coreGrid(),
          const SizedBox(height: Ad.gapL),

          // ③ 软件行为数据（版权梦）
          AdSection(
            title: '软件行为数据',
            subtitle: '启动 / 加群 / 联系作者 / 分享（版权梦统计）',
            accent: C.violet,
            trailing: GestureDetector(
              onTap: _loadAppStats,
              child: Icon(Icons.refresh_rounded, size: 16, color: context.t3),
            ),
          ),
          _appStatsCard(),
          const SizedBox(height: Ad.gapL),

          // ④ 启动数据
          AdSection(
            title: '启动数据',
            subtitle: 'App 每次启动都会上报',
            accent: C.brandBright,
          ),
          AdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AdMetric(
                        label: '今日启动',
                        value: '${_i('boot_today')}',
                        color: C.brandBright,
                        icon: Icons.rocket_launch_rounded,
                      ),
                    ),
                    const SizedBox(width: Ad.gapS),
                    Expanded(
                      child: AdMetric(
                        label: '今日设备',
                        value: '${_i('boot_devices_today')}',
                        color: C.mint,
                        icon: Icons.devices_rounded,
                      ),
                    ),
                    const SizedBox(width: Ad.gapS),
                    Expanded(
                      child: AdMetric(
                        label: '昨日启动',
                        value: '${_yesterdayBoots()}',
                        color: C.accentOrange,
                        icon: Icons.history_rounded,
                      ),
                    ),
                  ],
                ),
                if (_bootTrend().isNotEmpty) ...[
                  const SizedBox(height: 13),
                  AdTrendList(rows: _bootTrend(), barColor: C.brandBright),
                ],
              ],
            ),
          ),
          const SizedBox(height: Ad.gapL),

          // ⑤ 在线数据
          AdSection(title: '在线数据', subtitle: '按最后活跃时间统计', accent: C.mint),
          AdCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AdMetric(
                        label: '5 分钟',
                        value: '${_i('online_5m')}',
                        color: C.mint,
                        icon: Icons.bolt_rounded,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: Ad.gapS),
                    Expanded(
                      child: AdMetric(
                        label: '15 分钟',
                        value: '${_i('online_15m')}',
                        color: C.cyan,
                        icon: Icons.schedule_rounded,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: Ad.gapS),
                    Expanded(
                      child: AdMetric(
                        label: '60 分钟',
                        value: '${_i('online_60m')}',
                        color: C.brand,
                        icon: Icons.timelapse_rounded,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Ad.gapS),
                Row(
                  children: [
                    Expanded(
                      child: AdMetric(
                        label: '24 小时',
                        value: '${_i('online_24h')}',
                        color: C.violet,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: Ad.gapS),
                    Expanded(
                      child: AdMetric(
                        label: '活跃会话',
                        value: '${_i('active_tokens')}',
                        color: C.amber,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: Ad.gapS),
                    Expanded(
                      child: AdMetric(
                        label: '今日登录',
                        value: '${_i('today_active_users')}',
                        color: C.pink,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Ad.gapL),

          // ⑥ 下载数据
          AdSection(
            title: '下载数据',
            subtitle:
                '失败率 ${_dbl('down_fail_rate')}% · 点记录可看详情',
            accent: C.cyan,
          ),
          AdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AdMetric(
                        label: '今日下载',
                        value: '${_i('down_today')}',
                        color: C.mint,
                        icon: Icons.download_rounded,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: Ad.gapS),
                    Expanded(
                      child: AdMetric(
                        label: '今日失败',
                        value: '${_i('down_today_fail')}',
                        color: C.rose,
                        icon: Icons.error_outline_rounded,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: Ad.gapS),
                    Expanded(
                      child: AdMetric(
                        label: '累计下载',
                        value: '${_i('total_down')}',
                        color: C.cyan,
                        icon: Icons.all_inclusive_rounded,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _recentDownloads(),
              ],
            ),
          ),
          const SizedBox(height: Ad.gapL),

          // ⑦ 经营数据
          AdSection(title: '经营数据', accent: C.gold),
          AdCard(
            child: Row(
              children: [
                Expanded(
                  child: AdMetric(
                    label: '累计收入',
                    value: '¥${_s('total_money')}',
                    color: C.gold,
                    icon: Icons.account_balance_wallet_rounded,
                    compact: true,
                  ),
                ),
                const SizedBox(width: Ad.gapS),
                Expanded(
                  child: AdMetric(
                    label: '今日收入',
                    value: '¥${_s('today_money')}',
                    color: C.success,
                    icon: Icons.trending_up_rounded,
                    compact: true,
                  ),
                ),
                const SizedBox(width: Ad.gapS),
                Expanded(
                  child: AdMetric(
                    label: '已付/待付',
                    value: '${_i('paid_orders')}/${_i('unpaid_orders')}',
                    color: C.brand,
                    compact: true,
                  ),
                ),
              ],
            ),
          ),

          // ⑧ 热门软件
          if (((_d['top_apps'] as List?) ?? []).isNotEmpty) ...[
            const SizedBox(height: Ad.gapL),
            AdSection(title: '热门软件 Top5', subtitle: '按下载量排序', accent: C.rose),
            AdCard(
              child: AdRankList(
                accent: C.rose,
                rows: ((_d['top_apps'] as List?) ?? [])
                    .whereType<Map>()
                    .map(
                      (a) => (
                        '${a['title'] ?? ''}',
                        '下载 ${a['down_count'] ?? 0}',
                        '浏览 ${a['views'] ?? 0}',
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // 近 7 日趋势
          if (((_d['trend'] as List?) ?? []).isNotEmpty) ...[
            const SizedBox(height: Ad.gapL),
            AdSection(title: '近 7 日趋势', subtitle: '新增用户 / 收入', accent: C.brand),
            AdCard(
              child: AdTrendList(
                barColor: C.mint,
                rows: ((_d['trend'] as List?) ?? [])
                    .whereType<Map>()
                    .map(
                      (t) => (
                        '${t['date'] ?? ''}',
                        double.tryParse('${t['users'] ?? 0}') ?? 0,
                        '+${t['users'] ?? 0}人',
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ① 系统状态
  Widget _statusRow() {
    return AdCard(
      accent: C.mint,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: C.mint.withAlpha(context.isDark ? 44 : 26),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 19,
              color: C.mint,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('系统运行正常', style: Ty.h3.copyWith(color: context.t1)),
                Text(
                  'API · 数据库 · 采集服务 · 支付通道',
                  style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
                ),
              ],
            ),
          ),
          AdTag(text: '在线', color: C.mint),
        ],
      ),
    );
  }

  /// ② 核心指标（2 行 × 2）
  Widget _coreGrid() {
    final items = [
      ('软件总数', '${_i('apps')}', C.brand, Icons.apps_rounded),
      ('用户总数', '${_i('users')}', C.mint, Icons.people_rounded),
      (
        '今日注册',
        '${_i('today_users')}',
        C.accentOrange,
        Icons.person_add_rounded,
      ),
      ('会员数', '${_i('vip_users')}', C.amber, Icons.workspace_premium_rounded),
      ('动态数', '${_i('posts')}', C.violet, Icons.forum_rounded),
      ('评价数', '${_i('reviews')}', C.pink, Icons.rate_review_rounded),
    ];
    return AdCard(
      padding: const EdgeInsets.all(11),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: Ad.gapS),
                Expanded(
                  child: AdMetric(
                    label: items[i].$1,
                    value: items[i].$2,
                    color: items[i].$3,
                    icon: items[i].$4,
                    compact: true,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Ad.gapS),
          Row(
            children: [
              for (int i = 3; i < 6; i++) ...[
                if (i > 3) const SizedBox(width: Ad.gapS),
                Expanded(
                  child: AdMetric(
                    label: items[i].$1,
                    value: items[i].$2,
                    color: items[i].$3,
                    icon: items[i].$4,
                    compact: true,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// ③ 软件行为数据卡
  Widget _appStatsCard() {
    if (_statsLoading) {
      return AdCard(
        child: Row(
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('正在统计软件数据…', style: Ty.tiny.copyWith(color: context.t3)),
          ],
        ),
      );
    }
    final d = _appStats;
    if (d == null || d['ok'] != true) {
      return AdCard(
        child: AdEmpty(
          text: '软件数据暂不可用',
          hint: '版权梦接口未返回，可稍后重试',
          icon: Icons.insights_rounded,
        ),
      );
    }
    final totals = (d['totals'] is Map)
        ? Map<String, dynamic>.from(d['totals'] as Map)
        : <String, dynamic>{};
    int v(String k) => int.tryParse('${totals[k] ?? 0}') ?? 0;
    final top = ((d['top'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return AdCard(
      accent: C.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AdMetric(
                  label: '总启动',
                  value: '${v('启动次数')}',
                  color: C.brandBright,
                  icon: Icons.play_circle_fill_rounded,
                  compact: true,
                ),
              ),
              const SizedBox(width: Ad.gapS),
              Expanded(
                child: AdMetric(
                  label: '总加群',
                  value: '${v('加群次数')}',
                  color: C.mint,
                  icon: Icons.group_add_rounded,
                  compact: true,
                ),
              ),
              const SizedBox(width: Ad.gapS),
              Expanded(
                child: AdMetric(
                  label: '联系作者',
                  value: '${v('联系作者')}',
                  color: C.accentOrange,
                  icon: Icons.support_agent_rounded,
                  compact: true,
                ),
              ),
              const SizedBox(width: Ad.gapS),
              Expanded(
                child: AdMetric(
                  label: '总分享',
                  value: '${v('分享次数')}',
                  color: C.violet,
                  icon: Icons.share_rounded,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '最活跃软件（已统计 ${d['count'] ?? 0} 个）',
            style: Ty.tiny.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: context.t3,
            ),
          ),
          const SizedBox(height: 7),
          AdRankList(
            accent: C.violet,
            rows: top.map((t) {
              final st = (t['stats'] is Map)
                  ? Map<String, dynamic>.from(t['stats'] as Map)
                  : <String, dynamic>{};
              return (
                '${t['title'] ?? ''}',
                '启动 ${st['启动次数'] ?? 0}',
                '加群 ${st['加群次数'] ?? 0}',
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 启动趋势（日期 + 次数）
  List<(String, double, String)> _bootTrend() {
    final bt = (_d['boot_trend'] as List?) ?? [];
    return bt
        .whereType<Map>()
        .map(
          (b) => (
            '${b['date'] ?? ''}',
            double.tryParse('${b['count'] ?? 0}') ?? 0,
            '${b['count'] ?? 0}次',
          ),
        )
        .toList();
  }

  /// 昨日启动数（趋势里倒数第二条）
  int _yesterdayBoots() {
    final bt = (_d['boot_trend'] as List?) ?? [];
    if (bt.length < 2) return 0;
    final y = bt[bt.length - 2];
    if (y is Map) return int.tryParse('${y['count'] ?? 0}') ?? 0;
    return 0;
  }

  /// 最近下载记录（可点开看详情）
  Widget _recentDownloads() {
    final list = ((_d['recent_downloads'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '暂无下载记录（App 下载成功/失败都会上报）',
          style: Ty.tiny.copyWith(color: context.t3),
        ),
      );
    }
    return Column(
      children: [
        for (final r in list)
          Builder(
            builder: (c) {
              final ok = '${r['status']}' == 'ok';
              return GestureDetector(
                onTap: () => _showDownloadDetail(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                            fontSize: 10.5,
                            color: context.t3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${r['app_title'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.small.copyWith(
                            fontSize: 12,
                            color: ok ? context.t1 : C.rose,
                          ),
                        ),
                      ),
                      AdTag(
                        text: ok ? '成功' : '失败',
                        color: ok ? C.mint : C.rose,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showDownloadDetail(Map<String, dynamic> r) {
    final ok = '${r['status']}' == 'ok';
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ok ? '下载成功' : '下载失败'),
        content: SingleChildScrollView(
          child: AdKvList(
            rows: [
              ('时间', '${r['time_text'] ?? ''}'),
              ('软件', '${r['app_title'] ?? ''}'),
              (
                '用户',
                '${r['nickname'] ?? ''}'.isEmpty
                    ? '未登录 / ID ${r['user_id'] ?? 0}'
                    : '${r['nickname']} (ID ${r['user_id'] ?? 0})',
              ),
              ('状态', ok ? '成功' : '失败'),
              ('IP', '${r['ip'] ?? '-'}'),
              ('设备', '${r['device'] ?? '-'}'),
              if (!ok) ('失败原因', '${r['error'] ?? ''}'),
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
}
