import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../design/app_anim.dart';
import '../../api/admin_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/err_text.dart';
import 'mini_chart.dart';
import 'tabs/online_users_view.dart';

/// ═══════════════════════════════════════════════════════════════
/// 管理后台 · 概览（★ 1020 重构版）
///
/// 设计约束（对照 App 现有设计语言）：
///   · **全部色值取 C.xxx**，跟随后台配色方案切换，不用硬编码色
///   · 页面背景用 Deco.pageBackground（带品牌光晕，不是死灰）
///   · 分区标题带品牌渐变竖条（与 App 其他页面一致）
///   · 主数字用品牌渐变文字（蓝→紫），不是纯黑
///   · 涨跌用 C.mint（涨）/ C.danger（跌），与全站语义色一致
///
/// 内容（该显示的都显示）：
///   ① 今日六项 + 同比昨日 / 上周同期
///   ② 7 日趋势（双线）
///   ③ 收入三档 + 订单
///   ④ 在线四档 + 会话/登录/设备
///   ⑤ 软件榜单
///   ⑥ 失败原因（有数据才显示）
///   ⑦ 底部汇总
/// ═══════════════════════════════════════════════════════════════
class AdminOverviewV2 extends StatefulWidget {
  const AdminOverviewV2({super.key});

  @override
  State<AdminOverviewV2> createState() => _AdminOverviewV2State();
}

class _AdminOverviewV2State extends State<AdminOverviewV2> {
  final _svc = AdminService.instance;

  Map<String, dynamic> _d = {};
  bool _loading = true;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
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
        _err = ErrText.of(e);
      });
    }
  }

  int _i(String k) => int.tryParse('${_d[k] ?? 0}') ?? 0;
  String _s(String k) => '${_d[k] ?? ''}';
  double _f(String k) =>
      double.tryParse('${_d[k] ?? 0}'.replaceAll('%', '')) ?? 0;
  Map<String, dynamic> _m(String k) {
    final v = _d[k];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(text: '加载中…');
    if (_err.isNotEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        text: '概览加载失败',
        hint: _err,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          6,
          context.pagePadding,
          28,
        ),
        children: [
          _todayBlock(),
          const SizedBox(height: 12),
          _trendBlock(),
          const SizedBox(height: 12),
          _moneyBlock(),
          const SizedBox(height: 12),
          _onlineBlock(),
          if (_failItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _failBlock(),
          ],
          if (_rankItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _rankBlock(),
          ],
          const SizedBox(height: 12),
          _summaryBlock(),
        ],
      ),
    );
  }

  // ═════════ 通用外壳 ═════════

  /// 卡片 + 带品牌渐变竖条的分区标题
  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
    Color? accent,
  }) {
    final c = accent ?? C.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withAlpha(14)
              : Colors.black.withAlpha(7),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C3550).withAlpha(context.isDark ? 40 : 10),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 品牌渐变竖条（与 App 其他分区标题一致）
              Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c, c.withAlpha(140)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.t1,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ═════════ ① 今天 ═════════

  Widget _todayBlock() {
    final cmp = _m('cmp_yesterday');
    final down = _i('down_today');
    final users = _i('today_users');
    final active = _i('today_active_users');
    final boot = _i('boot_today');

    return _section(
      title: '今天',
      accent: C.brand,
      trailing: Text(
        _dateText(),
        style: TextStyle(fontSize: 10, color: context.t3),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mainNum(down, '今日下载', (cmp['downs'] as num?)?.toInt(), C.brand),
              _mainNum(
                users,
                '新增用户',
                (cmp['users'] as num?)?.toInt(),
                C.violet,
              ),
              _mainNum(active, '活跃用户', null, C.cyan),
            ],
          ),
          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 12),
          // 次级指标
          Row(
            children: [
              _smallStat('启动次数', '$boot', C.brand),
              _smallStat(
                '下载转化率',
                '${_f('conv_rate').toStringAsFixed(1)}%',
                C.mint,
              ),
              _smallStat(
                '下载失败率',
                '${_f('down_fail_rate').toStringAsFixed(1)}%',
                _f('down_fail_rate') > 10 ? C.danger : C.mint,
              ),
              _smallStat(
                '人均下载',
                '${_f('per_user_down').toStringAsFixed(2)}',
                C.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 主数字：品牌渐变文字 + 涨跌徽标
  Widget _mainNum(int value, String label, int? yesterday, Color color) {
    Widget cmpWidget;
    if (yesterday == null) {
      cmpWidget = _pill('—', context.t3);
    } else if (yesterday == 0) {
      cmpWidget = value > 0 ? _pill('新增', C.mint) : _pill('—', context.t3);
    } else {
      final diff = (value - yesterday) / yesterday * 100;
      final flat = diff.abs() < 1;
      final up = diff > 0;
      cmpWidget = _pill(
        flat ? '持平' : '${up ? '↑' : '↓'}${diff.abs().toStringAsFixed(0)}%',
        flat ? context.t3 : (up ? C.mint : C.danger),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 数字用品牌渐变，但每个指标不同色相 → 用 ShaderMask
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withAlpha(170)],
            ).createShader(rect),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: context.t2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              cmpWidget,
              if (yesterday != null && yesterday > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '昨日$yesterday',
                  style: TextStyle(fontSize: 9, color: context.t3),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withAlpha(context.isDark ? 50 : 26),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c),
    ),
  );

  Widget _smallStat(String label, String value, Color c) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: context.t3)),
      ],
    ),
  );

  Widget _divider() => Container(
    height: 1,
    color: context.isDark ? Colors.white10 : Colors.black.withAlpha(6),
  );

  // ═════════ ② 趋势 ═════════

  Widget _trendBlock() {
    final trend = (_d['trend'] as List?) ?? const [];
    if (trend.isEmpty) return const SizedBox.shrink();
    final users = <double>[];
    final downs = <double>[];
    final labels = <String>[];
    for (final e in trend) {
      final m = Map<String, dynamic>.from(e as Map);
      users.add((m['users'] as num?)?.toDouble() ?? 0);
      downs.add((m['downs'] as num?)?.toDouble() ?? 0);
      labels.add('${m['date'] ?? ''}'.replaceFirst(RegExp(r'^\d{2}-'), ''));
    }

    // 周环比：本周合计 vs 上 7 天
    final sumDown = downs.fold<double>(0, (a, b) => a + b);
    final sumUser = users.fold<double>(0, (a, b) => a + b);

    return _section(
      title: '近 7 日趋势',
      trailing: Row(
        children: [
          _legendDot(C.mint, '新增'),
          const SizedBox(width: 8),
          _legendDot(C.brand, '下载'),
        ],
      ),
      child: Column(
        children: [
          DualLineChart(
            seriesA: users,
            seriesB: downs,
            colorA: C.mint,
            colorB: C.brand,
            labels: labels,
            height: 108,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: C.brand.withAlpha(context.isDark ? 30 : 12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '7 日合计：下载 ${sumDown.toInt()} 次 · '
                    '新增 ${sumUser.toInt()} 人',
                    style: TextStyle(fontSize: 10, color: context.t2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 9.5, color: context.t3)),
    ],
  );

  // ═════════ ③ 收入 ═════════

  Widget _moneyBlock() {
    final cmp = _m('cmp_yesterday');
    final todayMoney = double.tryParse(_s('today_money')) ?? 0;
    final yMoney = double.tryParse('${cmp['money'] ?? 0}') ?? 0;
    final diff = yMoney > 0 ? (todayMoney - yMoney) / yMoney * 100 : null;

    return _section(
      title: '收入',
      accent: C.gold,
      trailing: diff == null
          ? null
          : _pill(
              diff.abs() < 1
                  ? '持平昨日'
                  : '${diff > 0 ? '↑' : '↓'}${diff.abs().toStringAsFixed(0)}% 昨日',
              diff > 0 ? C.mint : C.danger,
            ),
      child: Column(
        children: [
          Row(
            children: [
              _moneyCell('今日', '¥${_s('today_money')}', C.gold),
              _moneyCell('本月', '¥${_s('month_money')}', C.amber),
              _moneyCell('累计', '¥${_s('total_money')}', C.violet),
            ],
          ),
          const SizedBox(height: 12),
          _divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              _smallStat('已付订单', '${_i('paid_orders')}', C.mint),
              _smallStat('待付订单', '${_i('unpaid_orders')}', C.amber),
              _smallStat('今日订单', '${_i('today_orders')}', C.brand),
              _smallStat('上周同日', '¥${cmp['money'] ?? '0.00'}', context.t3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyCell(String label, String value, Color c) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.t3)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: c,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ),
  );

  // ═════════ ④ 在线 ═════════

  Widget _onlineBlock() {
    final list = (_d['online_users'] as List?) ?? const [];
    final users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final cur = _i('online_5m');

    return _section(
      title: '实时在线',
      accent: C.cyan,
      trailing: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: C.mint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '当前 $cur 人',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: C.mint,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          // 时段分布
          Row(
            children: [
              _onlineCell('5 分钟', _i('online_5m'), C.mint),
              _onlineCell('15 分钟', _i('online_15m'), C.brand),
              _onlineCell('60 分钟', _i('online_60m'), C.violet),
              _onlineCell('24 小时', _i('online_24h'), C.cyan),
            ],
          ),
          const SizedBox(height: 12),
          _divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              _smallStat('有效会话', '${_i('active_tokens')}', C.brand),
              _smallStat('今日登录', '${_i('today_active_users')}', C.mint),
              _smallStat('启动设备', '${_i('boot_devices_today')}', C.violet),
              _smallStat('今日启动', '${_i('boot_today')}', C.cyan),
            ],
          ),
          // ★ 1020：在线用户明细（用户要求「要看到是哪些用户」）
          if (users.isNotEmpty) ...[
            const SizedBox(height: 12),
            _divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '最近 60 分钟活跃',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.t3,
                  ),
                ),
                const Spacer(),
                Text(
                  '${users.length} 人',
                  style: TextStyle(fontSize: 10, color: context.t3),
                ),
                const SizedBox(width: 8),
                // ★ 1020：点这里看全部在线用户（不再限制 8 个）
                AppPressable(
                  onTap: () => Get.to(() => const OnlineUsersView()),
                  child: Row(
                    children: [
                      Text(
                        '查看全部',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: C.brand,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 13,
                        color: C.brand,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...users.take(8).map(_onlineUserRow),
            if (users.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AppPressable(
                  onTap: () => Get.to(() => const OnlineUsersView()),
                  child: Text(
                    '还有 ${users.length - 8} 人，点击查看全部 ›',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: C.brand,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 在线用户一行：头像 + 昵称 + 最近活跃时间 + IP
  Widget _onlineUserRow(Map<String, dynamic> u) {
    final booting = u['booting'] == true;
    final nick = '${u['nickname'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          // 头像（无头像时用首字）
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (booting ? C.mint : C.brand).withAlpha(
                context.isDark ? 50 : 22,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              nick.isEmpty ? '?' : nick.characters.first,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: booting ? C.mint : C.brand,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nick,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.t1,
                        ),
                      ),
                    ),
                    if (u['vip'] == true) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: C.amber.withAlpha(36),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: C.amber,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${u['ip'] ?? ''}',
                  style: TextStyle(fontSize: 9, color: context.t3),
                ),
              ],
            ),
          ),
          Text(
            '${u['time_text'] ?? ''}',
            style: TextStyle(
              fontSize: 9,
              color: booting ? C.mint : context.t3,
              fontWeight: booting ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlineCell(String label, int n, Color c) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '$n',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.t1,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, color: context.t3)),
      ],
    ),
  );

  // ═════════ ⑤ 失败原因 ═════════

  List<MapEntry<String, double>> get _failItems {
    final raw = _m('fail_by_reason');
    final list = <MapEntry<String, double>>[];
    raw.forEach((k, v) {
      final n = (v as num?)?.toDouble() ?? 0;
      if (n > 0) list.add(MapEntry('$k', n));
    });
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  Widget _failBlock() {
    final items = _failItems;
    final total = items.fold<double>(0, (s, e) => s + e.value).toInt();
    return _section(
      title: '今日下载失败',
      accent: C.danger,
      trailing: _pill('$total 次', C.danger),
      child: MiniBarList(items: items, color: C.danger, maxItems: 4),
    );
  }

  // ═════════ ⑥ 榜单 ═════════

  List<MapEntry<String, double>> get _rankItems {
    final top = (_d['top_apps'] as List?) ?? const [];
    final items = <MapEntry<String, double>>[];
    for (final a in top) {
      final m = Map<String, dynamic>.from(a as Map);
      items.add(
        MapEntry(
          '${m['title'] ?? ''}',
          (m['down_count'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return items;
  }

  Widget _rankBlock() {
    return _section(
      title: '热门软件',
      accent: C.violet,
      trailing: Text(
        '在库 ${_i('apps')} · 总下载 ${_i('total_down')}',
        style: TextStyle(fontSize: 9.5, color: context.t3),
      ),
      child: MiniBarList(items: _rankItems, color: C.brand, maxItems: 5),
    );
  }

  // ═════════ ⑦ 汇总 ═════════

  Widget _summaryBlock() {
    final m30 = _m('month30');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: C.brand.withAlpha(context.isDark ? 26 : 10),
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '近 30 日',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: C.brand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '新增 ${m30['users'] ?? 0} 人 · '
            '下载 ${m30['downs'] ?? 0} 次 · '
            '收入 ¥${m30['money'] ?? '0.00'}',
            style: TextStyle(fontSize: 11, height: 1.6, color: context.t2),
          ),
          const SizedBox(height: 4),
          Text(
            '累计 ${_i('users')} 个用户 · '
            '${_i('total_views')} 次浏览 · '
            '${_i('total_down')} 次下载',
            style: TextStyle(fontSize: 10, color: context.t3, height: 1.6),
          ),
        ],
      ),
    );
  }

  String _dateText() {
    final n = DateTime.now();
    const w = ['一', '二', '三', '四', '五', '六', '日'];
    return '${n.month}月${n.day}日 周${w[n.weekday - 1]}';
  }
}
