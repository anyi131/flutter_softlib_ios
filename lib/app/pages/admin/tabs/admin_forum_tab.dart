import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../design/app_anim.dart';
import '../admin_ui_kit.dart';
import '../../../design/kit.dart';
import '../../navigate/circle/post_page.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import '../../../design/buttons.dart';
import '../../../design/components.dart';
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
      } else if (kind == 'pass') {
        await _svc.adminPostSet(id, 'status', 1);
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
                        const SizedBox(height: 5),
                        Wrap(spacing: 5, runSpacing: 4, children: [
                          Pill('${s['post_count'] ?? 0} 帖', color: C.brand, small: true),
                          Pill('排序 ${s['sort'] ?? 0}', color: C.violet, small: true),
                          Pill('${s['followers'] ?? 0} 关注', color: C.cyan, small: true),
                        ]),
                        if ('${s['descr'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${s['descr']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: context.t3)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    padding: EdgeInsets.zero,
                    icon: Icon(Lz.pencil, size: 18, color: context.t2),
                    onPressed: () => _editSection(s),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    padding: EdgeInsets.zero,
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
              GestureDetector(
                onTap: _showComments,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.brand.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('评论管理',
                      style: TextStyle(
                          fontSize: 11,
                          color: C.brand,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Text('待审 ${_posts.where((x) => x['status'] != 1).length} · 共 ${_posts.length}',
                  style: TextStyle(fontSize: 11, color: context.t3)),
            ],
          ),
          const SizedBox(height: 10),
          if (_posts.isEmpty)
            AppCard(
              padding: EdgeInsets.zero,
              child: AppEmpty(
                icon: Lz.messageCircle,
                title: '暂无帖子',
                subtitle: '用户发帖后会出现在这里，可置顶或隐藏',
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
                        Pill('待审核', color: C.warning, small: true),
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
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _chip('查看', () => _openPost(p)),
                    _chip('编辑', () => _editPost(p)),
                    _chip(p['is_top'] == 1 ? '取消置顶' : '置顶', () => _postAction(p, 'top')),
                    if (p['status'] != 1)
                      _chip('通过', () => _postAction(p, 'pass'), primary: true),
                    _chip(p['status'] == 1 ? '隐藏' : '驳回', () => _postAction(p, 'hide')),
                    _chip('删除', () => _postAction(p, 'del'), danger: true),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 1109：后台编辑帖子（标题/正文/版块/置顶）——正文支持 Markdown / HTML
  Future<void> _editPost(Map<String, dynamic> p) async {
    final id = int.tryParse('${p['id']}') ?? 0;
    if (id <= 0) return;
    final titleCtrl = TextEditingController(text: '${p['title'] ?? ''}');
    final contentCtrl = TextEditingController(text: '${p['content'] ?? ''}');
    int secId = int.tryParse('${p['section_id'] ?? 0}') ?? 0;
    bool isTop = p['is_top'] == 1;
    final ok = await Get.dialog<bool>(StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('编辑帖子',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: secId,
                decoration: const InputDecoration(labelText: '版块'),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('未分类')),
                  for (final s in _sections)
                    DropdownMenuItem(
                      value: int.tryParse('${s['id']}') ?? 0,
                      child: Text('${s['name'] ?? ''}'),
                    ),
                ],
                onChanged: (v) => setS(() => secId = v ?? 0),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                minLines: 8,
                maxLines: 16,
                style: const TextStyle(fontSize: 13, height: 1.5),
                decoration: const InputDecoration(
                  labelText: '正文（支持 Markdown / HTML）',
                  helperText: '## 标题   - 列表   > 引用   | 表格 |   **粗体**',
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isTop,
                onChanged: (v) => setS(() => isTop = v),
                title: const Text('置顶', style: TextStyle(fontSize: 13)),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('保存'),
          ),
        ],
      ),
    ));
    if (ok != true) return;
    if (titleCtrl.text.trim().isEmpty) {
      ToastUtil.error('标题不能为空');
      return;
    }
    try {
      await ForumService.instance.adminPostSave(
        id: id,
        title: titleCtrl.text.trim(),
        content: contentCtrl.text,
        sectionId: secId,
        isTop: isTop ? 1 : 0,
      );
      ToastUtil.success('已保存');
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 1109：后台评论管理（列表 + 删除）
  Future<void> _showComments() async {
    final ctx0 = Get.context!;
    final dark = ctx0.isDark;
    List<Map<String, dynamic>> rows = [];
    await Get.bottomSheet(
      StatefulBuilder(builder: (ctx, setS) {
        if (rows.isEmpty) {
          Future.microtask(() async {
            final r = await ForumService.instance.adminComments(page: 1);
            if (ctx.mounted) setS(() => rows = r);
          });
        }
        return Container(
          height: MediaQuery.of(ctx0).size.height * 0.75,
          decoration: BoxDecoration(
            color: dark ? C.bg2 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: ctx0.t3.withAlpha(60),
                  borderRadius: BorderRadius.circular(99)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 10, 8),
              child: Row(children: [
                Text('评论管理',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ctx0.t1)),
                const Spacer(),
                Text('${rows.length} 条',
                    style: TextStyle(fontSize: 11, color: ctx0.t3)),
                IconButton(
                  icon: Icon(Lz.x, size: 18, color: ctx0.t3),
                  onPressed: () => Get.back(),
                ),
              ]),
            ),
            Divider(height: 1, color: ctx0.t3.withAlpha(24)),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text('暂无评论',
                          style:
                              TextStyle(fontSize: 12.5, color: ctx0.t3)))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: ctx0.t3.withAlpha(16)),
                      itemBuilder: (_, i) {
                        final c = rows[i];
                        final u = (c['user'] as Map?) ?? const {};
                        return ListTile(
                          dense: true,
                          title: Row(children: [
                            Text('${u['nickname'] ?? '匿名'}',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: ctx0.t1)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('· ${c['title'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11, color: ctx0.t3)),
                            ),
                          ]),
                          subtitle: Text('${c['content'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(fontSize: 12, color: ctx0.t2)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: C.danger),
                            onPressed: () async {
                              try {
                                await ForumService.instance.commentDel(
                                    int.tryParse('${c['id']}') ?? 0);
                                setS(() => rows.removeAt(i));
                                ToastUtil.success('已删除');
                              } catch (e) {
                                ToastUtil.error('删除失败');
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(top: false, child: const SizedBox(height: 6)),
          ]),
        );
      }),
      isScrollControlled: true,
    );
  }

  /// 1109：后台直接打开帖子（跳到前台详情页）
  void _openPost(Map<String, dynamic> p) {
    final id = int.tryParse('${p['id']}') ?? 0;
    if (id <= 0) return;
    Get.to(() => PostPage(postId: id));
  }

  Widget _stat(String label, String value, Color color) {
    return AppStatTile(value: value, label: label, color: color);
  }

  /// 1109：统一走 AppChip（带图标/描边/按压反馈）
  Widget _chip(String text, VoidCallback onTap,
      {bool danger = false, bool primary = false}) {
    return AppChip(text,
        onTap: onTap,
        danger: danger,
        primary: primary || text == '查看');
  }
}
