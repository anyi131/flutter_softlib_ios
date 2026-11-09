import 'package:flutter/material.dart';

import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';
import '../../../design/lucide.dart';

/// 采集 · 采集日志（站点全部历史任务 + 蓝奏云链接）
class CollectLogsView extends StatefulWidget {
  const CollectLogsView({super.key});

  @override
  State<CollectLogsView> createState() => _CollectLogsViewState();
}

class _CollectLogsViewState extends State<CollectLogsView>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic> _stat = {};
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await AdminService.instance.collectLogs();
      if (!mounted) return;
      setState(() {
        _stat = Map<String, dynamic>.from(r['stat'] ?? {});
        _groups = ((r['groups'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _items = ((r['items'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _groups.isEmpty && _items.isEmpty) {
      return const LoadingState(text: '加载采集日志…');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          8,
          context.pagePadding,
          24,
        ),
        children: [
          _statCard(),
          const SizedBox(height: 10),
          if (_groups.isNotEmpty) ...[
            AdSection(title: '任务记录', accent: C.brand),
            const SizedBox(height: 6),
            ..._groups.map(_groupCard),
            const SizedBox(height: 10),
          ],
          if (_items.isNotEmpty) ...[
            const AdSection(title: '可导入的软件', accent: C.mint),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '站点日志里共 ${_items.length} 条结果链接。点「导入」可加入你的软件库。',
                style: Ty.tiny.copyWith(color: context.t3, height: 1.5),
              ),
            ),
            ..._items.map(_itemCard),
          ],
        ],
      ),
    );
  }

  Widget _statCard() {
    int v(String k) => (_stat[k] as num?)?.toInt() ?? 0;
    return AdCard(
      radius: R.md,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _statItem('任务数', '${v('tasks')}', C.brand),
          _divider(),
          _statItem('采集数', '${v('total')}', C.violet),
          _divider(),
          _statItem('成功', '${v('success')}', C.mint),
          _divider(),
          _statItem('失败', '${v('fail')}', C.danger),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 26,
    color: context.isDark
        ? Colors.white.withAlpha(18)
        : Colors.black.withAlpha(10),
  );

  Widget _statItem(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        Text(value, style: Ty.h3.copyWith(fontSize: 17, color: color)),
        const SizedBox(height: 2),
        Text(label, style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3)),
      ],
    ),
  );

  /// 1109 需求3：点任务组 → 明细弹窗（该次采集的软件清单）
  void _showGroupDetail(Map<String, dynamic> g) {
    final t = '${g['time'] ?? ''}';
    final mine = _items.where((it) => '${it['task_time'] ?? ''}' == t).toList();
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg2 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
                color: context.t3.withAlpha(60),
                borderRadius: BorderRadius.circular(99)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Row(children: [
              Icon(Lz.history, size: 18, color: C.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('采集明细 · $t',
                        style: Ty.h3.copyWith(fontSize: 15, color: context.t1)),
                    Text(
                        '共 ${g['total']} 个 · 成功 ${g['success']} · 失败 ${g['fail']}',
                        style: Ty.tiny.copyWith(color: context.t3)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Lz.x, size: 20, color: context.t3),
                onPressed: () => Get.back(),
              ),
            ]),
          ),
          Divider(height: 1, color: context.t3.withAlpha(24)),
          Flexible(
            child: mine.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text('该批次明细已被采集站点清理',
                        style: Ty.small.copyWith(color: context.t3)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: mine.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1, color: context.t3.withAlpha(18)),
                    itemBuilder: (_, i) => _itemCard(mine[i]),
                  ),
          ),
          SafeArea(top: false, child: const SizedBox(height: 6)),
        ]),
      ),
      isScrollControlled: true,
    );
  }

  Widget _groupCard(Map<String, dynamic> g) {
    final fail = (g['fail'] as num?)?.toInt() ?? 0;
    final total = (g['total'] as num?)?.toInt() ?? 0;
    final ok = (g['success'] as num?)?.toInt() ?? 0;
    return GestureDetector(
      onTap: () => _showGroupDetail(g),
      child: AdCard(
      margin: const EdgeInsets.only(bottom: 8),
      radius: R.md,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${g['time']}',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
              ),
              Pill(
                fail == 0 ? '全部成功' : '部分失败',
                color: fail == 0 ? C.mint : C.warning,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '共 $total 个 · 成功 $ok 个 · 失败 $fail 个',
            style: Ty.small.copyWith(fontSize: 12.5, color: context.t1),
          ),
          if ((g['cost'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('耗时 ${g['cost']}', style: Ty.tiny.copyWith(color: context.t3)),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Text('查看明细', style: Ty.tiny.copyWith(color: C.brand)),
            Icon(Lz.chevronRight, size: 13, color: C.brand),
          ]),
        ],
      ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> it) {
    final name = (it['name'] ?? '').toString();
    final url = (it['url'] ?? '').toString();
    return AdCard(
      margin: const EdgeInsets.only(bottom: 7),
      radius: R.sm,
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.small.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.t1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.tiny.copyWith(fontSize: 10.5, color: C.brand),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MiniAction(
            label: '导入',
            icon: Lz.download,
            color: C.mint,
            onTap: () => _import(it),
          ),
        ],
      ),
    );
  }

  Future<void> _import(Map<String, dynamic> it) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('导入软件库'),
        content: Text('把「${it['name']}」加入你的软件库？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await AdminService.instance.collectImport([
        {
          'name': it['name'],
          'url': it['url'],
          'desc': it['desc'],
          'category': it['category'],
        },
      ]);
      ToastUtil.success('已导入 ${r['added']} 条，跳过重复 ${r['skipped']} 条');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }
}
