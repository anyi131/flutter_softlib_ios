import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/goal_service.dart';
import '../../api/user_service.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';

/// 1108z W1：任务中心 + 成就墙（统一事件引擎）
/// 设计：上 Tab 切任务/成就；条目=进度条卡片；reached 未领显示「领取」按钮。
class GoalCenterPage extends StatefulWidget {
  const GoalCenterPage({super.key});

  @override
  State<GoalCenterPage> createState() => _GoalCenterPageState();
}

class _GoalCenterPageState extends State<GoalCenterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _svc = GoalService.instance;

  List<GoalItem> _all = [];
  bool _loading = true;
  String _err = '';
  bool _loggedIn = false;
  final Set<int> _claiming = {};

  @override
  void initState() {
    super.initState();
    _loggedIn = UserService.instance.token.isNotEmpty;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final goals = await _svc.list();
      if (!mounted) return;
      setState(() {
        _all = goals;
        _loggedIn = UserService.instance.token.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '加载失败，请下拉重试';
        _loading = false;
      });
    }
  }

  List<GoalItem> get _tasks =>
      _all.where((g) => g.isTask && !g.titleMasked).toList();
  List<GoalItem> get _achieves =>
      _all.where((g) => g.isAchievement).toList();

  Future<void> _claim(GoalItem g) async {
    if (_claiming.contains(g.id)) return;
    setState(() => _claiming.add(g.id));
    try {
      final msg = await _svc.claim(g.id);
      if (!mounted) return;
      ToastUtil.success(msg);
      // 称号类奖励：刷新用户信息让「我的」页徽章立即生效
      if (g.rewardType == 'title') {
        try { await UserService.instance.refreshProfile(); } catch (_) {}
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _claiming.remove(g.id));
    }
  }

  String _rewardText(GoalItem g) {
    switch (g.rewardType) {
      case 'score':
        return '积分 +${g.rewardValue}';
      case 'money':
        return '余额 +${g.rewardValue}';
      case 'vip_days':
        return '会员 +${g.rewardValue} 天';
      case 'title':
        return '专属称号';
      default:
        return '奖励';
    }
  }

  IconData _rewardIcon(GoalItem g) {
    switch (g.rewardType) {
      case 'money':
        return Icons.account_balance_wallet_rounded;
      case 'vip_days':
        return Icons.workspace_premium_rounded;
      case 'title':
        return Icons.military_tech_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  Color _rewardColor(GoalItem g) {
    switch (g.rewardType) {
      case 'money':
        return C.mint;
      case 'vip_days':
        return C.gold;
      case 'title':
        return C.violet;
      default:
        return C.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        backgroundColor: context.isDark ? C.bg0 : C.lbg0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('任务与成就'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '任务'), Tab(text: '成就')],
          labelColor: C.brand,
          unselectedLabelColor: context.isDark ? C.t2 : C.lt2,
          indicatorColor: C.brand,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err.isNotEmpty
              ? _ErrorView(err: _err, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _list(_tasks, emptyText: '暂无任务，敬请期待'),
                      _list(_achieves, emptyText: '暂无成就，敬请期待'),
                    ],
                  ),
                ),
    );
  }

  Widget _list(List<GoalItem> items, {required String emptyText}) {
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.emoji_events_outlined,
              size: 64, color: context.isDark ? C.t3 : C.lt3),
          const SizedBox(height: 12),
          Center(
            child: Text(emptyText, style: TextStyle(color: context.isDark ? C.t2 : C.lt2)),
          ),
        ],
      );
    }
    // 已领取的沉底
    final sorted = [...items]
      ..sort((a, b) {
        int rank(GoalItem g) => g.done ? 2 : (g.canClaim ? 0 : 1);
        return rank(a).compareTo(rank(b));
      });
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: sorted.length + (_loggedIn ? 0 : 1),
      itemBuilder: (context, i) {
        if (i >= sorted.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '登录后同步你的任务进度',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.isDark ? C.t2 : C.lt2, fontSize: 12),
            ),
          );
        }
        return _GoalCard(
          item: sorted[i],
          claiming: _claiming.contains(sorted[i].id),
          rewardText: _rewardText(sorted[i]),
          rewardIcon: _rewardIcon(sorted[i]),
          rewardColor: _rewardColor(sorted[i]),
          onClaim: () => _claim(sorted[i]),
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  final GoalItem item;
  final bool claiming;
  final String rewardText;
  final IconData rewardIcon;
  final Color rewardColor;
  final VoidCallback onClaim;

  const _GoalCard({
    required this.item,
    required this.claiming,
    required this.rewardText,
    required this.rewardIcon,
    required this.rewardColor,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? C.bg2 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.isDark ? C.bg3 : C.lbg2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.done
                      ? C.success.withAlpha(28)
                      : rewardColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.done ? Icons.check_circle_rounded : rewardIcon,
                  color: item.done ? C.success : rewardColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: rewardColor.withAlpha(22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rewardText,
                            style: TextStyle(
                                fontSize: 10,
                                color: rewardColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: context.isDark ? C.t2 : C.lt2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildAction(context),
            ],
          ),
          if (!item.done) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: item.target <= 0
                    ? 0
                    : min(1.0, item.progress / item.target),
                minHeight: 6,
                backgroundColor: context.isDark ? C.bg3 : C.lbg2,
                valueColor: AlwaysStoppedAnimation(
                  item.canClaim ? C.success : C.brand,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${item.progress}/${item.target}',
              style: TextStyle(fontSize: 11, color: context.isDark ? C.t2 : C.lt2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (item.done) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg3 : C.lbg2,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('已领取',
            style: TextStyle(fontSize: 12, color: context.isDark ? C.t2 : C.lt2)),
      );
    }
    if (item.canClaim) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: claiming ? null : onClaim,
          style: ElevatedButton.styleFrom(
            backgroundColor: rewardColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99)),
            elevation: 0,
          ),
          child: claiming
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('领取',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    }
    return Text(
      '${item.progress}/${item.target}',
      style: TextStyle(fontSize: 12, color: context.isDark ? C.t2 : C.lt2),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String err;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.err, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: context.isDark ? C.t3 : C.lt3),
          const SizedBox(height: 10),
          Text(err, style: TextStyle(color: context.isDark ? C.t2 : C.lt2)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
