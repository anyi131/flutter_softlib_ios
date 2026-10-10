////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 解析历史页
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植改造
// (上游 pages/history.dart 思路,历史存储复用 jicun_history_store.dart;
//  条数上限由后台 history_limit 控制,退出清理由 clear_on_exit 控制)。
// 版权与许可遵循上游 MIT License,见仓库 LICENSE。
////////////////////////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import '../jicun_history_store.dart';

class JicunHistoryPage extends StatefulWidget {
  const JicunHistoryPage({super.key});

  @override
  State<JicunHistoryPage> createState() => _JicunHistoryPageState();
}

class _JicunHistoryPageState extends State<JicunHistoryPage> {
  final HistoryStore _store = HistoryStore();
  List<HistoryEntry> _entries = const [];
  bool _loading = true;
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _store.load();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty) return;
    final list = await _store.remove(_selected);
    if (!mounted) return;
    setState(() {
      _entries = list;
      _selected.clear();
    });
    ToastUtil.success('已删除');
  }

  Future<void> _clearAll() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定清空全部解析历史吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _store.clear();
    if (!mounted) return;
    setState(() => _entries = const []);
    ToastUtil.success('已清空');
  }

  String _fmt(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        title: const Text('解析历史'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _removeSelected,
              child: Text('删除(${_selected.length})'),
            ),
          IconButton(
            tooltip: '清空',
            onPressed: _entries.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? EmptyState(
              icon: Icons.history_rounded,
              text: '还没有解析记录',
              hint: '去「即存」Tab 解析一条分享链接吧',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: _entries.length,
                itemBuilder: (c, i) {
                  final e = _entries[i];
                  final r = e.result;
                  final on = _selected.contains(e.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KitCard(
                      onTap: () => setState(() {
                        on ? _selected.remove(e.id) : _selected.add(e.id);
                      }),
                      child: Row(
                        children: [
                          Icon(
                            on
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: on ? C.brand : context.t3,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title.isNotEmpty
                                      ? r.title
                                      : (r.desc.isEmpty ? '(无标题)' : r.desc),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: context.t1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${r.platform.isEmpty ? '未知平台' : r.platform}'
                                  ' · ${_fmt(e.parsedAt)}'
                                  '${e.sourceUrl.isEmpty ? '' : ' · ${e.sourceUrl}'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.t3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
