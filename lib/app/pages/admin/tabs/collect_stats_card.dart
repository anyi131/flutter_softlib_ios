import 'package:flutter/material.dart';
import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// ★ 1016：概览 · 软件数据（商业化总览卡）
///
/// 数据源：版权梦 tongji.php（经服务端 collect_ex sub=app_stats_summary）
/// 异步加载：不阻塞概览其它数据；失败静默（不干扰主流程）
/// ═══════════════════════════════════════════════════════════════
class CollectStatsCard extends StatefulWidget {
  const CollectStatsCard({super.key});

  @override
  State<CollectStatsCard> createState() => _CollectStatsCardState();
}

class _CollectStatsCardState extends State<CollectStatsCard> {
  bool _loading = true;
  String _err = '';
  int _count = 0;
  Map<String, dynamic> _totals = {};
  List<Map<String, dynamic>> _top = [];

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
      final d = await AdminService.instance.collectEx('app_stats_summary', {
        'limit': 12,
      });
      final totals = (d['totals'] is Map)
          ? Map<String, dynamic>.from(d['totals'] as Map)
          : <String, dynamic>{};
      final top = ((d['top'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _count = int.tryParse('${d['count'] ?? 0}') ?? 0;
        _totals = totals;
        _top = top;
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

  int _v(String k) => int.tryParse('${_totals[k] ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_err.isNotEmpty) {
      return AdCard(
        radius: R.lg,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: context.t3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '软件数据暂不可用（$_err）',
                style: Ty.tiny.copyWith(color: context.t3),
              ),
            ),
            TextButton(
              onPressed: _load,
              child: const Text('重试', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
    if (_loading) {
      return AdCard(
        radius: R.lg,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('正在统计软件数据…', style: Ty.tiny.copyWith(color: context.t3)),
          ],
        ),
      );
    }
    return AdCard(
      radius: R.xl,
      padding: const EdgeInsets.all(16),
      glow: C.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: C.violet.withAlpha(context.isDark ? 40 : 24),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: C.violet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('软件数据统计', style: Ty.h3.copyWith(color: context.t1)),
                    Text(
                      '版权梦行为统计 · 已统计 $_count 个软件',
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _load,
                child: Icon(Icons.refresh_rounded, size: 18, color: context.t3),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _cell(
                '总启动',
                _v('启动次数'),
                C.brandBright,
                Icons.play_circle_fill_rounded,
              ),
              const SizedBox(width: 8),
              _cell('总加群', _v('加群次数'), C.mint, Icons.group_add_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _cell(
                '联系作者',
                _v('联系作者'),
                C.accentOrange,
                Icons.support_agent_rounded,
              ),
              const SizedBox(width: 8),
              _cell('总分享', _v('分享次数'), C.violet, Icons.share_rounded),
            ],
          ),
          if (_top.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '最活跃软件',
              style: Ty.tiny.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.t3,
              ),
            ),
            const SizedBox(height: 7),
            for (int i = 0; i < _top.length; i++)
              Builder(
                builder: (c) {
                  final it = _top[i];
                  final st = (it['stats'] is Map)
                      ? Map<String, dynamic>.from(it['stats'] as Map)
                      : <String, dynamic>{};
                  final qd = int.tryParse('${st['启动次数'] ?? 0}') ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? C.gold.withAlpha(46)
                                : C.brand.withAlpha(24),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: Ty.tiny.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: i == 0 ? C.gold : C.brand,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '${it['title'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.small.copyWith(
                              fontSize: 12.5,
                              color: context.t1,
                            ),
                          ),
                        ),
                        Text(
                          '启动 $qd',
                          style: Ty.tiny.copyWith(
                            fontSize: 11,
                            color: C.brandBright,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _cell(String label, int value, Color color, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: color.withAlpha(context.isDark ? 30 : 18),
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
