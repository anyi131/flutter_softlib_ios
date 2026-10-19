import 'package:flutter/material.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';
import '../admin_ui_kit.dart';

/// 后台 · 性能监控
///
/// ★ 1020（待办）：以前只能靠「感觉」猜哪个接口慢。
///   这里看：P50/P95、最慢 Top10、失败率 Top10。
class PerfMonitorView extends StatefulWidget {
  const PerfMonitorView({super.key});

  @override
  State<PerfMonitorView> createState() => _PerfMonitorViewState();
}

class _PerfMonitorViewState extends State<PerfMonitorView> {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _slowest = [];
  List<Map<String, dynamic>> _failTop = [];
  Map<String, dynamic> _meta = {};
  bool _loading = true;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _svc.perfSummary(days: _days);
      if (!mounted) return;
      setState(() {
        _slowest = ((r['slowest'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _failTop = ((r['fail_top'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _meta = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  Color _speedColor(int ms) {
    if (ms >= 1000) return C.danger;
    if (ms >= 500) return C.amber;
    if (ms >= 200) return C.violet;
    return C.mint;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            8,
            context.pagePadding,
            6,
          ),
          child: Row(
            children: [
              _dayChip(1, '今天'),
              const SizedBox(width: 6),
              _dayChip(7, '7 天'),
              const SizedBox(width: 6),
              _dayChip(30, '30 天'),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, size: 18, color: context.t3),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingState(text: '加载性能数据…')
              : (_slowest.isEmpty && _failTop.isEmpty
                    ? const EmptyState(
                        text: '暂无性能数据',
                        hint: '只有耗时超过 200ms 的请求会被记录',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: C.brand,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            4,
                            context.pagePadding,
                            24,
                          ),
                          children: [
                            _summaryCard(),
                            const SizedBox(height: 14),
                            if (_slowest.isNotEmpty) ...[
                              const AdSection(
                                title: '最慢接口 Top 10',
                                accent: C.danger,
                              ),
                              ..._slowest.map((e) => _perfRow(e, true)),
                              const SizedBox(height: 14),
                            ],
                            if (_failTop.isNotEmpty) ...[
                              const AdSection(
                                title: '失败率 Top 10',
                                accent: C.amber,
                              ),
                              ..._failTop.map((e) => _perfRow(e, false)),
                            ],
                          ],
                        ),
                      )),
        ),
      ],
    );
  }

  Widget _dayChip(int d, String label) {
    final sel = _days == d;
    return GestureDetector(
      onTap: () {
        if (_days == d) return;
        setState(() => _days = d);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? C.brand : context.cardBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: sel ? C.brand : C.stroke),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : context.t2,
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return AdCard(
      radius: R.md,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _cell('采样数', '${_meta['sampled'] ?? 0}', C.brand),
          _div(),
          _cell('慢于 1s', '${_meta['slow_1s'] ?? 0}', C.danger),
          _div(),
          _cell('监控天数', '${_meta['days'] ?? 0}', C.violet),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c),
        ),
        const SizedBox(height: 2),
        Text(label, style: Ty.tiny.copyWith(fontSize: 10, color: context.t3)),
      ],
    ),
  );

  Widget _div() => Container(
    width: 1,
    height: 24,
    color: context.isDark ? Colors.white12 : Colors.black.withAlpha(10),
  );

  Widget _perfRow(Map<String, dynamic> r, bool bySpeed) {
    final action = '${r['action'] ?? ''}';
    final p50 = (r['p50'] as num?)?.toInt() ?? 0;
    final p95 = (r['p95'] as num?)?.toInt() ?? 0;
    final failRate = (r['fail_rate'] as num?)?.toDouble() ?? 0;
    final count = (r['count'] as num?)?.toInt() ?? 0;
    final color = bySpeed
        ? _speedColor(p95)
        : (failRate >= 20 ? C.danger : C.amber);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AdCard(
        radius: R.md,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: context.t1,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'P50 $p50ms · P95 $p95ms · $count 次',
                    style: Ty.tiny.copyWith(fontSize: 9.5, color: context.t3),
                  ),
                ],
              ),
            ),
            if (bySpeed)
              Text(
                '$p95ms',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              )
            else
              Text(
                '${failRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
