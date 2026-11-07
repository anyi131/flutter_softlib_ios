import 'package:flutter/material.dart';

import '../../../api/forum_service.dart';
import '../../../design/app_anim.dart';
import '../admin_ui_kit.dart';
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              Text('板块', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.t1)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editSection(),
                icon: Icon(Lz.plus, size: 16, color: C.brand),
                label: Text('新增', style: TextStyle(fontSize: 12.5, color: C.brand)),
              ),
            ],
          ),
          for (final s in _sections)
            AdCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['name'] ?? ''}',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w800, color: context.t1)),
                        const SizedBox(height: 2),
                        Text('${s['post_count'] ?? 0} 帖 · 排序 ${s['sort'] ?? 0}',
                            style: TextStyle(fontSize: 11, color: context.t3)),
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
          const SizedBox(height: 8),
          Text('帖子', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.t1)),
          const SizedBox(height: 6),
          for (final p in _posts)
            AdCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (p['is_top'] == 1)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: C.brand.withAlpha(30),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('置顶',
                              style: TextStyle(fontSize: 9.5, color: C.brand)),
                        ),
                      if (p['status'] != 1)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: C.danger.withAlpha(30),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('已隐藏',
                              style: TextStyle(fontSize: 9.5, color: C.danger)),
                        ),
                      Expanded(
                        child: Text('${p['title'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: context.t1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${p['nickname'] ?? '匿名'} · ${p['section_name'] ?? ''} · ${p['time_text'] ?? ''}',
                      style: TextStyle(fontSize: 11, color: context.t3)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip('置顶', () => _postAction(p, 'top')),
                      const SizedBox(width: 8),
                      _chip(p['status'] == 1 ? '隐藏' : '显示', () => _postAction(p, 'hide')),
                      const SizedBox(width: 8),
                      _chip('删除', () => _postAction(p, 'del'), danger: true),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
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
