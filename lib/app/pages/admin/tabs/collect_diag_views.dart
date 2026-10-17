import 'package:flutter/material.dart';
import '../../../utils/err_text.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/ui.dart';
import '../admin_ui_kit.dart';

/// ═══════════════════════════════════════════════════════════════
/// 后台 · 接口自测（1016）
///   一键检测：数据库 / 软件列表 / 版权梦登录 / 版权梦接口 / 蓝奏云解析
///   显示：每项是否正常 + 耗时(ms) + 失败原因
/// ═══════════════════════════════════════════════════════════════
class CollectSelftestView extends StatefulWidget {
  const CollectSelftestView({super.key});

  @override
  State<CollectSelftestView> createState() => _CollectSelftestViewState();
}

class _CollectSelftestViewState extends State<CollectSelftestView> {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _items = [];
  int _okCount = 0;
  int _total = 0;
  bool _loading = false;
  String _err = '';
  int _costMs = 0;

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    final sw = Stopwatch()..start();
    try {
      final d = await _svc.apiSelftest();
      if (!mounted) return;
      setState(() {
        _items = ((d['list'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _okCount = int.tryParse('${d['okCount'] ?? 0}') ?? 0;
        _total = int.tryParse('${d['total'] ?? 0}') ?? 0;
        _costMs = sw.elapsedMilliseconds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = ErrText.of(e);
        _loading = false;
        _costMs = sw.elapsedMilliseconds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allOk = _total > 0 && _okCount == _total;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(context.pagePadding, 12,
          context.pagePadding, 40),
      children: [
        AdCard(
          border: _total > 0 && !allOk,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _total == 0
                        ? Icons.science_rounded
                        : (allOk ? Icons.verified_rounded : Icons.warning_rounded),
                    size: 20,
                    color: _total == 0
                        ? C.brand
                        : (allOk ? C.mint : C.warning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _total == 0
                          ? '接口自测'
                          : (_okCount == _total
                              ? '全部正常 $_okCount/$_total'
                              : '异常 ${_total - _okCount} 项（$_okCount/$_total 正常）'),
                      style: Ty.h3.copyWith(fontSize: 15),
                    ),
                  ),
                  if (_costMs > 0)
                    AdTag(text: '${_costMs}ms', color: C.brand),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '检测数据库、软件列表、版权梦登录与各接口、蓝奏云解析是否可用',
                style: Ty.tiny.copyWith(color: context.t3),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _run,
                  icon: _loading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(_loading
                      ? '检测中…'
                      : (_total == 0 ? '开始检测' : '重新检测')),
                ),
              ),
            ],
          ),
        ),
        if (_err.isNotEmpty) ...[
          const SizedBox(height: 10),
          AdCard(
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 18, color: C.rose),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_err,
                      style: Ty.small.copyWith(color: C.rose, fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ],
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdSection(
            title: '检测结果',
            subtitle: '失败项会给出具体原因，便于定位',
            accent: C.brand,
          ),
          AdCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Ad.stroke(context)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 11),
                    child: Row(
                      children: [
                        Icon(
                          _items[i]['ok'] == true
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 17,
                          color: _items[i]['ok'] == true ? C.mint : C.rose,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_items[i]['name'] ?? ''}',
                                style: Ty.small.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_items[i]['ok'] != true &&
                                  '${_items[i]['msg'] ?? ''}'.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${_items[i]['msg']}',
                                    style: Ty.tiny.copyWith(
                                        color: C.rose, fontSize: 11.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${_items[i]['ms'] ?? 0}ms',
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// 后台 · 解析记录（1016）
///   每次蓝奏云/直链解析的成功/失败 + 原因 + 耗时，点开看详情
/// ═══════════════════════════════════════════════════════════════
class CollectParseLogView extends StatefulWidget {
  const CollectParseLogView({super.key});

  @override
  State<CollectParseLogView> createState() => _CollectParseLogViewState();
}

class _CollectParseLogViewState extends State<CollectParseLogView> {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _list = [];
  int _total = 0;
  int _todayFail = 0;
  int _todayOk = 0;
  int _page = 1;
  bool _loading = true;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _loading = true);
    try {
      final d = await _svc.parseLogs(page: _page);
      if (!mounted) return;
      final l = ((d['list'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _list = reset ? l : [..._list, ...l];
        _total = int.tryParse('${d['total'] ?? 0}') ?? 0;
        _todayFail = int.tryParse('${d['todayFail'] ?? 0}') ?? 0;
        _todayOk = int.tryParse('${d['todayOk'] ?? 0}') ?? 0;
        _loading = false;
        _err = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = ErrText.of(e);
        _loading = false;
      });
    }
  }

  void _detail(Map<String, dynamic> r) {
    final ok = r['ok'] == 1 || r['ok'] == true;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ok ? '解析成功' : '解析失败'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdKvList(
                rows: [
                  ('时间', '${r['time_text'] ?? ''}'),
                  ('软件', '${r['app_title'] ?? '-'}'),
                  ('耗时', '${r['cost_ms'] ?? 0} ms'),
                  ('IP', '${r['ip'] ?? '-'}'),
                  if (!ok) ('失败原因', '${r['error'] ?? '未记录'}'),
                  ('原始链接', '${r['raw_url'] ?? '-'}'),
                  if ('${r['req_params'] ?? ''}'.isNotEmpty)
                    ('请求参数', '${r['req_params']}'),
                  if ('${r['resp_snippet'] ?? ''}'.isNotEmpty)
                    ('接口返回', '${r['resp_snippet']}'),
                ],
              ),
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _list.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
            context.pagePadding, 12, context.pagePadding, 40),
        children: [
          AdCard(
            child: Row(
              children: [
                Expanded(
                  child: AdMetric(
                    label: '今日成功',
                    value: '$_todayOk',
                    color: C.mint,
                    icon: Icons.check_circle_outline_rounded,
                    compact: true,
                  ),
                ),
                const SizedBox(width: Ad.gapS),
                Expanded(
                  child: AdMetric(
                    label: '今日失败',
                    value: '$_todayFail',
                    color: C.rose,
                    icon: Icons.error_outline_rounded,
                    compact: true,
                  ),
                ),
                const SizedBox(width: Ad.gapS),
                Expanded(
                  child: AdMetric(
                    label: '累计记录',
                    value: '$_total',
                    color: C.brand,
                    icon: Icons.history_rounded,
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
          if (_err.isNotEmpty) ...[
            const SizedBox(height: 10),
            AdCard(
              child: Text(_err,
                  style: Ty.small.copyWith(color: C.rose, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 16),
          AdSection(
            title: '解析记录',
            subtitle: '点记录看详情与失败原因',
            accent: C.cyan,
          ),
          if (_list.isEmpty)
            AdCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    '暂无解析记录\n（App 解析直链成功/失败都会上报）',
                    textAlign: TextAlign.center,
                    style: Ty.tiny.copyWith(color: context.t3),
                  ),
                ),
              ),
            )
          else
            AdCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _list.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: Ad.stroke(context)),
                    InkWell(
                      onTap: () => _detail(_list[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 11),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_list[i]['ok'] == 1 ||
                                        _list[i]['ok'] == true)
                                    ? C.mint
                                    : C.rose,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 58,
                              child: Text(
                                '${_list[i]['time_text'] ?? ''}',
                                style: Ty.tiny.copyWith(color: context.t3),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${_list[i]['app_title'] ?? '-'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ty.small.copyWith(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${_list[i]['cost_ms'] ?? 0}ms',
                              style: Ty.tiny.copyWith(color: context.t3),
                            ),
                            const SizedBox(width: 8),
                            AdTag(
                              text: (_list[i]['ok'] == 1 ||
                                      _list[i]['ok'] == true)
                                  ? '成功'
                                  : '失败',
                              color: (_list[i]['ok'] == 1 ||
                                      _list[i]['ok'] == true)
                                  ? C.mint
                                  : C.rose,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_list.length < _total) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: () {
                  _page++;
                  _load();
                },
                child: const Text('加载更多'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
