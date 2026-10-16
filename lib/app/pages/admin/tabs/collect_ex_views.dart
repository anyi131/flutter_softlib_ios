import 'package:flutter/material.dart';

import '../admin_ui_kit.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：版权梦 · 软件数据统计（商业化展示）
///
/// 数据源：/api/softlib/admin/collect_ex  sub=app_stats_all
///   每个软件 4 项：启动次数 / 加群次数 / 联系作者 / 分享次数
///   （来自版权梦 tongji.php，统计信息仅供参考，实际以加群人数为准）
/// ═══════════════════════════════════════════════════════════════
class CollectStatsView extends StatefulWidget {
  const CollectStatsView({super.key});

  @override
  State<CollectStatsView> createState() => _CollectStatsViewState();
}

class _CollectStatsViewState extends State<CollectStatsView> {
  final _svc = AdminService.instance;

  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _err = '';
        _page = 1;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      // ★ 1016：一次抓 50 个（服务端内部翻 5 页），并用服务端返回的 nextPage 翻页
      final d = await _svc.collectEx('app_stats_all', {
        'page': _page,
        'limit': 50,
      });
      final list = ((d['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = reset ? list : [..._items, ...list];
        // ★ 1016：按服务端返回的 nextPage 翻页（写死 +1 会重复抓同一批 → 只显示十个）
        _page = int.tryParse('${d['nextPage'] ?? ''}') ?? (_page + 5);
        _hasMore = list.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int _sum(String key) {
    var t = 0;
    for (final it in _items) {
      final st = it['stats'];
      if (st is Map) t += (int.tryParse('${st[key] ?? 0}') ?? 0);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(text: '加载软件数据…');
    if (_err.isNotEmpty && _items.isEmpty) {
      return EmptyState(
        text: _err,
        hint: '下拉重试',
        icon: Icons.error_outline_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          6,
          context.pagePadding,
          30,
        ),
        children: [
          _summaryCard(),
          const SizedBox(height: 14),
          AdSection(
            title: '各软件数据明细',
            subtitle: '统计信息仅供参考，实际以加群人数为准',
            accent: C.brand,
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const EmptyState(text: '暂无软件数据', hint: '采集到软件后这里会显示启动/加群等统计')
          else
            ..._items.map(_appCard),
          if (_hasMore) ...[
            const SizedBox(height: 8),
            Center(
              child: SoftButton(
                label: _loadingMore ? '加载中…' : '加载更多',
                height: 40,
                onPressed: _loadingMore
                    ? null
                    : () {
                        _page++;
                        _load();
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 顶部总览（商业化数据卡）
  Widget _summaryCard() {
    final cards = [
      ('软件总数', '${_items.length}', C.brand, Icons.apps_rounded),
      ('总启动', '${_sum('启动次数')}', C.brandBright, Icons.play_circle_fill_rounded),
      ('总加群', '${_sum('加群次数')}', C.mint, Icons.group_add_rounded),
      ('联系作者', '${_sum('联系作者')}', C.accentOrange, Icons.support_agent_rounded),
      ('总分享', '${_sum('分享次数')}', C.violet, Icons.share_rounded),
    ];
    return AdCard(
      radius: R.xl,
      padding: const EdgeInsets.all(16),
      glow: C.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: C.brandGradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('软件数据总览', style: Ty.h3.copyWith(color: context.t1)),
              ),
              IconButton(
                onPressed: () => _load(reset: true),
                icon: Icon(Icons.refresh_rounded, size: 19, color: context.t3),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards.map((c) => _statChip(c)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _statChip((String, String, Color, IconData) c) {
    final (label, value, color, icon) = c;
    return Container(
      width:
          (MediaQuery.of(context).size.width -
              context.pagePadding * 2 -
              (context.isCompact ? 10 : 14) -
              (context.isWide ? 40 : 28)) /
          (context.isWide ? 5 : 2),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(context.isDark ? 30 : 18),
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单个软件的数据卡（4 格 + 比例条）
  Widget _appCard(Map<String, dynamic> it) {
    final st = (it['stats'] is Map)
        ? Map<String, dynamic>.from(it['stats'] as Map)
        : <String, dynamic>{};
    int v(String k) => int.tryParse('${st[k] ?? 0}') ?? 0;
    final qd = v('启动次数');
    final jq = v('加群次数');
    final zz = v('联系作者');
    final fx = v('分享次数');
    final maxV = [qd, jq, zz, fx].reduce((a, b) => a > b ? a : b);
    final title = '${it['title'] ?? ''}';
    final appid = '${it['appid'] ?? ''}';

    return AdCard(
      radius: R.lg,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '软件 $appid' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.h3.copyWith(fontSize: 14.5, color: context.t1),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: C.brand.withAlpha(context.isDark ? 40 : 22),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ID $appid',
                  style: Ty.tiny.copyWith(fontSize: 10, color: C.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _cell('启动次数', qd, C.brandBright, maxV),
              const SizedBox(width: 8),
              _cell('加群次数', jq, C.mint, maxV),
              const SizedBox(width: 8),
              _cell('联系作者', zz, C.accentOrange, maxV),
              const SizedBox(width: 8),
              _cell('分享次数', fx, C.violet, maxV),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, int value, Color color, int maxV) {
    final ratio = maxV <= 0 ? 0.0 : (value / maxV).clamp(0.0, 1.0);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: color.withAlpha(context.isDark ? 26 : 16),
          borderRadius: BorderRadius.circular(R.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 3,
                backgroundColor: color.withAlpha(40),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ty.tiny.copyWith(fontSize: 10, color: context.t3),
            ),
          ],
        ),
      ),
    );
  }
}
