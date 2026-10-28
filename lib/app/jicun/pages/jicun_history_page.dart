////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 解析历史页
// 来源：开源项目 jicun（https://github.com/dhvbjvvb/jicun，MIT License）移植改造
// (上游 pages/history.dart:普通点击=回填并重新解析,长按=进入多选删除;
//  历史存储复用 jicun_history_store.dart;
//  条数上限由后台 history_limit 控制,退出清理由 clear_on_exit 控制)。
// 版权与许可遵循上游 MIT License,见仓库 LICENSE。
//
// ★ 1028 修：原来是「每行常驻一个空复选框，点一下只是勾选」——用户看到
// 一排空框，既不能重解析也不能干别的。改成对齐上游：
//   点击 → 带 url 返回上一页，那边自动回填 + 重新解析
//   长按 → 进入多选；多选时点击才切换勾选，标题栏出全选/删除/取消
////////////////////////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

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

  /// 选中集合非空 = 多选模式（不再用独立开关，避免两个状态不同步）
  bool get _selecting => _selected.isNotEmpty;

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

  void _exitSelecting() {
    if (_selected.isEmpty) return;
    setState(_selected.clear);
  }

  void _toggle(HistoryEntry e) {
    setState(() {
      if (!_selected.remove(e.id)) _selected.add(e.id);
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == _entries.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_entries.map((e) => e.id));
      }
    });
  }

  /// 普通点击：把原始链接带回上一页重新解析
  void _reparse(HistoryEntry e) {
    final url = e.sourceUrl.trim();
    if (url.isEmpty) {
      ToastUtil.info('这条记录没有留下原始链接');
      return;
    }
    Navigator.pop(context, url);
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty) return;
    final n = _selected.length;
    final list = await _store.remove(_selected);
    if (!mounted) return;
    setState(() {
      _entries = list;
      _selected.clear();
    });
    ToastUtil.success('已删除 $n 条');
  }

  Future<void> _clearAll() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialog(
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
    setState(() {
      _entries = const [];
      _selected.clear();
    });
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
        leading: _selecting
            ? IconButton(
                tooltip: '退出多选',
                onPressed: _exitSelecting,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(_selecting ? '已选 ${_selected.length} 条' : '解析历史'),
        actions: [
          if (_selecting) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(_selected.length == _entries.length ? '取消全选' : '全选'),
            ),
            TextButton(
              onPressed: _removeSelected,
              child: Text(
                '删除',
                style: TextStyle(color: C.danger, fontWeight: FontWeight.w700),
              ),
            ),
          ] else
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HistoryTile(
                      entry: e,
                      selecting: _selecting,
                      selected: _selected.contains(e.id),
                      timeText: _fmt(e.parsedAt),
                      onTap: () => _selecting ? _toggle(e) : _reparse(e),
                      onLongPress: () => _toggle(e),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.selecting,
    required this.selected,
    required this.timeText,
    required this.onTap,
    required this.onLongPress,
  });

  final HistoryEntry entry;
  final bool selecting;
  final bool selected;
  final String timeText;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final r = entry.result;
    final title = r.title.isNotEmpty
        ? r.title
        : (r.desc.isEmpty ? '(无标题)' : r.desc);
    final platform = r.platform.isEmpty ? '未知平台' : r.platform;
    // 缩略图：上游列表带封面，这里若结果里有就用，没有就用平台图标占位
    final cover = r.coverUrl ?? '';

    return GestureDetector(
      onLongPress: onLongPress,
      child: KitCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (selecting) ...[
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? C.brand : context.t3,
              ),
              const SizedBox(width: 10),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: cover.isEmpty
                    ? Container(
                        color: context.isDark ? C.bg2 : const Color(0xFFEEF1F7),
                        child: Icon(
                          Icons.movie_creation_outlined,
                          size: 20,
                          color: context.t3,
                        ),
                      )
                    : Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: context.isDark ? C.bg2 : const Color(0xFFEEF1F7),
                          child: Icon(
                            Icons.movie_creation_outlined,
                            size: 20,
                            color: context.t3,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                    '$platform · $timeText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.t3),
                  ),
                ],
              ),
            ),
            if (!selecting)
              Icon(Icons.refresh_rounded, size: 18, color: context.t3),
          ],
        ),
      ),
    );
  }
}
