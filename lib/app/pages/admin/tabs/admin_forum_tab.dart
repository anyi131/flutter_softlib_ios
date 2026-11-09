import 'package:flutter/material.dart';

import '../../../api/forum_service.dart';
import '../../../design/app_anim.dart';
import '../admin_ui_kit.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';

/// ★ 1107b 后台：圈子管理（板块增删改 + 帖子置顶/删除）
class AdminForumTab extends StatefulWidget {
  const AdminForumTab({super.key});

  @override
  State<AdminForumTab> createState() => _AdminForumTabState();
}

class _AdminForumTabState extends State<AdminForumTab> {
  final _svc = ForumService.instance;
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await _svc.adminSections();
      final p = await _svc.adminPosts();
      if (!mounted) return;
      setState(() {
        _sections = s;
        _posts = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _editSection([Map<String, dynamic>? s]) async {
    final name = TextEditingController(text: '${s?['name'] ?? ''}');
    final descr = TextEditingController(text: '${s?['descr'] ?? ''}');
    final sort = TextEditingController(text: '${s?['sort'] ?? 0}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s == null ? '新增板块' : '编辑板块'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: '名称')),
            TextField(controller: descr, decoration: const InputDecoration(labelText: '简介')),
            TextField(
                controller: sort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '排序（越小越前）')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.adminSectionSave({
        if (s != null) 'id': s['id'],
        'name': name.text.trim(),
        'descr': descr.text.trim(),
        'sort': int.tryParse(sort.text.trim()) ?? 0,
        'enable_switch': 1,
      });
      ToastUtil.success('已保存');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _delSection(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除板块'),
        content: Text('确定删除「${s['name']}」？板块下有帖子时不允许删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.adminSectionDel(int.tryParse('${s['id']}') ?? 0);
      ToastUtil.success('已删除');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _postAction(Map<String, dynamic> p, String kind) async {
    final id = int.tryParse('${p['id']}') ?? 0;
    try {
      if (kind == 'top') {
        await _svc.adminPostSet(id, 'is_top', p['is_top'] == 1 ? 0 : 1);
      } else if (kind == 'hide') {
        await _svc.adminPostSet(id, 'status', p['status'] == 1 ? 0 : 1);
      } else {
        await _svc.adminPostDel(id);
      }
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final totalPosts = _sections.fold<int>(
        0, (s, x) => s + ((x['post_count'] as num?)?.toInt() ?? 0));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          // ── 统计头 ──
          Row(
            children: [
              Expanded(child: _stat('板块', '${_sections.length}', C.brand)),
              const SizedBox(width: 10),
              Expanded(child: _stat('帖子', '$totalPosts', C.violet)),
              const SizedBox(width: 10),
              Expanded(child: _stat('待处理', '${_posts.where((p) => p['status'] != 1).length}', C.warning)),
            ],
          ),
          const SizedBox(height: 16),

          // ── 板块 ──
          Row(
            children: [
              Container(width: 3, height: 15,
                  decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 7),
              Text('板块管理', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
              const Spacer(),
              AppPressable(
                onTap: () => _editSection(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: C.brand.withAlpha(22), borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Lz.plus, size: 14, color: C.brand),
                    const SizedBox(width: 3),
                    Text('新增', style: TextStyle(fontSize: 12, color: C.brand, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final s in _sections)
            AdCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${s['name'] ?? ''}'.isEmpty ? '版' : '${s['name']}'.substring(0, 1),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: C.brand),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['name'] ?? ''}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.t1)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Pill('${s['post_count'] ?? 0} 帖', color: C.brand, small: true),
                          const SizedBox(width: 5),
                          Pill('排序 ${s['sort'] ?? 0}', color: C.violet, small: true),
                          if ('${s['descr'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text('${s['descr']}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10.5, color: context.t3)),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Lz.pencil, size: 18, color: context.t2),
                    onPressed: () => _editSection(s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: C.danger),
                    onPressed: () => _delSection(s),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // ── 帖子 ──
          Row(
            children: [
              Container(width: 3, height: 15,
                  decoration: BoxDecoration(color: C.violet, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 7),
              Text('帖子审核', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
              const Spacer(),
              Text('${_posts.length} 条', style: TextStyle(fontSize: 11, color: context.t3)),
            ],
          ),
          const SizedBox(height: 10),
          if (_posts.isEmpty)
            AdCard(
              padding: const EdgeInsets.symmetric(vertical: 34),
              child: Center(
                child: Column(children: [
                  Icon(Lz.messageCircle, size: 34, color: context.t3.withAlpha(90)),
                  const SizedBox(height: 8),
                  Text('暂无帖子', style: TextStyle(fontSize: 12.5, color: context.t3)),
                ]),
              ),
            ),
          for (final p in _posts)
            AdCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (p['is_top'] == 1) ...[
                        Pill('置顶', color: C.gold, small: true),
                        const SizedBox(width: 5),
                      ],
                      if (p['status'] != 1) ...[
                        Pill('已隐藏', color: C.danger, small: true),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text('${p['title'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700, color: context.t1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Lz.user, size: 12, color: context.t3),
                    const SizedBox(width: 3),
                    Text('${p['nickname'] ?? '匿名'}',
                        style: TextStyle(fontSize: 11, color: context.t2)),
                    const SizedBox(width: 8),
                    Pill('${p['section_name'] ?? '未分类'}', color: C.brand, small: true),
                    const SizedBox(width: 8),
                    Text('${p['time_text'] ?? ''}',
                        style: TextStyle(fontSize: 10.5, color: context.t3)),
                  ]),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      _chip(p['is_top'] == 1 ? '取消置顶' : '置顶', () => _postAction(p, 'top')),
                      const SizedBox(width: 8),
                      _chip(p['status'] == 1 ? '隐藏' : '恢复显示', () => _postAction(p, 'hide')),
                      const Spacer(),
                      _chip('删除', () => _postAction(p, 'del'), danger: true),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return AdCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: context.t3)),
      ]),
    );
  }

  Widget _chip(String text, VoidCallback onTap, {bool danger = false}) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (danger ? C.danger : C.brand).withAlpha(24),
          borderRadius: BorderRadius.circular(R.full),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.5, color: danger ? C.danger : C.brand, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
