import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/goal_service.dart';
import '../../api/user_service.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/lucide.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';

/// 1109 精装修：任务中心 + 成就墙
///  · 顶部英雄区：完成进度环 + 可领奖励数 + 一句话激励
///  · 分段 Tab（任务 / 成就）带数量气泡
///  · 卡片：图标色块 + 标题 + 描述 + 渐变进度条 + 奖励胶囊 + 领取按钮
class GoalCenterPage extends StatefulWidget {
  const GoalCenterPage({super.key});

  @override
  State<GoalCenterPage> createState() => _GoalCenterPageState();
}

class _GoalCenterPageState extends State<GoalCenterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _svc = GoalService.instance;
  final Set<int> _claiming = {};

  List<GoalItem> _list = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final r = await _svc.list();
      if (!mounted) return;
      setState(() {
        _list = r;
        _err = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _claim(GoalItem g) async {
    if (_claiming.contains(g.id)) return;
    setState(() => _claiming.add(g.id));
    try {
      final msg = await _svc.claim(g.id);
      if (!mounted) return;
      ToastUtil.success(msg);
      if (g.rewardType == 'title') {
        try {
          await UserService.instance.refreshProfile();
        } catch (_) {}
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _claiming.remove(g.id));
    }
  }

  List<GoalItem> get _tasks => _list.where((g) => g.kind == 0).toList();
  List<GoalItem> get _achs => _list.where((g) => g.kind == 1).toList();
  int get _claimable => _list.where((g) => g.canClaim).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('任务与成就',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Lz.refreshCw, size: 19, color: context.t2),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _err != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _hero(),
                      const SizedBox(height: 16),
                      _segTabs(),
                      const SizedBox(height: 14),
                      if (_tab.index == 0) ..._buildSection(_tasks, '任务'),
                      if (_tab.index == 1) ..._buildSection(_achs, '成就'),
                      if (!UserService.instance.isLoggedIn) _loginHint(),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildSection(List<GoalItem> items, String label) {
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 44),
          child: Center(
            child: Column(children: [
              Icon(Lz.trophy, size: 40, color: context.t3.withAlpha(80)),
              const SizedBox(height: 10),
              Text('暂无$label', style: TextStyle(fontSize: 13, color: context.t3)),
            ]),
          ),
        ),
      ];
    }
    final pending = items.where((g) => !g.done).toList()
      ..sort((a, b) {
        final av = a.canClaim ? 0 : 1;
        final bv = b.canClaim ? 0 : 1;
        if (av != bv) return av - bv;
        return b.percent - a.percent;
      });
    final done = items.where((g) => g.done).toList();
    return [
      for (final g in pending) _goalCard(g),
      if (done.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 3, height: 13,
              decoration: BoxDecoration(color: context.t3, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 7),
          Text('已完成', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.t3)),
        ]),
        const SizedBox(height: 8),
        for (final g in done) _goalCard(g),
      ],
    ];
  }

  /// 顶部英雄区
  Widget _hero() {
    final all = _list.length;
    final doneCnt = _list.where((g) => g.done).length;
    final pct = all == 0 ? 0 : (doneCnt / all * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? [const Color(0xFF1E2A4A), const Color(0xFF2A1E3A)]
              : [const Color(0xFF2B4BFF), const Color(0xFF7B3FE4)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: C.brand.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        // 进度环
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 76,
              height: 76,
              child: CircularProgressIndicator(
                value: pct / 100,
                strokeWidth: 6,
                backgroundColor: Colors.white.withAlpha(50),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
              const Text('完成度',
                  style: TextStyle(fontSize: 9.5, color: Colors.white70)),
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _claimable > 0 ? '有 $_claimable 份奖励待领取' : '任务中心',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(
                _claimable > 0 ? '点击「领取」即可到账，别错过' : '完成任务解锁成就与专属称号',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(children: [
                _heroChip('$doneCnt/$all 已完成'),
                const SizedBox(width: 8),
                if (_claimable > 0) _heroChip('$_claimable 待领', hot: true),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _heroChip(String t, {bool hot = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: hot ? C.gold : Colors.white.withAlpha(40),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(t,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: hot ? Colors.black87 : Colors.white)),
      );

  /// 分段 Tab
  Widget _segTabs() {
    final items = [
      ('任务', _tasks.length, 0),
      ('成就', _achs.length, 1),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark ? C.bg2 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.isDark ? C.bg3 : C.lbg2),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: AppPressable(
                onTap: () => _tab.index = it.$3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _tab.index == it.$3
                        ? C.brand
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(it.$1,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _tab.index == it.$3 ? Colors.white : context.t2)),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _tab.index == it.$3
                              ? Colors.white.withAlpha(60)
                              : C.brand.withAlpha(26),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('${it.$2}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _tab.index == it.$3 ? Colors.white : C.brand)),
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

  Color _rewardColor(String t) => switch (t) {
        'money' => C.mint,
        'vip_days' => C.gold,
        'title' => C.violet,
        _ => C.warning,
      };

  String _rewardText(GoalItem g) {
    if (g.titleMasked) return '神秘奖励';
    return switch (g.rewardType) {
        'title' => '专属称号',
        'money' => '¥${g.rewardValue}',
      'vip_days' => 'VIP ${g.rewardValue} 天',
      _ => '+${g.rewardValue} 积分',
    };
  }

  Widget _goalCard(GoalItem g) {
    final claimed = g.done;
    final claimable = g.canClaim;
    final rc = _rewardColor(g.rewardType);
    final pct = (g.percent.clamp(0, 100)) / 100.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: context.isDark ? C.bg2 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.isDark ? C.bg3 : C.lbg2),
      ),
      child: Opacity(
        opacity: claimed ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 图标色块
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [rc.withAlpha(46), rc.withAlpha(22)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    g.isAchievement ? Lz.trophy : Lz.calendar,
                    size: 20,
                    color: rc,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                              g.titleMasked ? '神秘成就' : g.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: context.t1)),
                        ),
                        if (g.isAchievement) ...[
                          const SizedBox(width: 6),
                          Pill('成就', color: C.gold, small: true),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(
                          g.titleMasked
                              ? '达成目标后揭晓内容与奖励'
                              : g.desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: context.t3, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 右侧：奖励 / 按钮 / 已领取
                if (claimed)
                  Row(children: [
                    Icon(Lz.checkCircle, size: 15, color: C.mint),
                    const SizedBox(width: 4),
                    Text('已领取',
                        style: TextStyle(
                            fontSize: 11, color: C.mint, fontWeight: FontWeight.w700)),
                  ])
                else if (claimable)
                  AppPressable(
                    onTap: () => _claim(g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFB020), Color(0xFFFF7A00)]),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFFF7A00).withAlpha(80),
                              blurRadius: 10,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: _claiming.contains(g.id)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : const Text('领取',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: rc.withAlpha(26),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: rc.withAlpha(80)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          g.rewardType == 'title'
                              ? Lz.crown
                              : g.rewardType == 'money'
                                  ? Lz.wallet
                                  : Lz.sparkles,
                          size: 11,
                          color: rc),
                      const SizedBox(width: 3),
                      Text(_rewardText(g),
                          style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w700, color: rc)),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            // 进度条
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(children: [
                    Container(
                      height: 6,
                      color: (context.isDark ? C.bg3 : C.lbg2),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.02, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            claimed ? C.mint : rc.withAlpha(200),
                            claimed ? C.mint : rc,
                          ]),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                g.titleMasked ? '？？？' : '${g.progress}/${g.target}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: claimed ? C.mint : context.t2),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _loginHint() => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.warning.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.warning.withAlpha(70)),
        ),
        child: Row(children: [
          Icon(Lz.info, size: 16, color: C.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text('登录后同步你的任务进度与奖励',
                style: TextStyle(fontSize: 12, color: context.t2)),
          ),
        ]),
      );

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Lz.alertCircle, size: 40, color: context.t3),
          const SizedBox(height: 10),
          Text(_err ?? '加载失败',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.t3)),
          const SizedBox(height: 14),
          FilledButton(onPressed: _load, child: const Text('重试')),
        ]),
      );
}
