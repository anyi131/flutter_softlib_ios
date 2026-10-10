import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 软件管理
class AdminAppsTab extends StatefulWidget {
  const AdminAppsTab({super.key});

  @override
  State<AdminAppsTab> createState() => _AdminAppsTabState();
}

class _AdminAppsTabState extends State<AdminAppsTab> {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String _kw = '';
  // ★ 一键补全缺失参数（支持单选/多选）
  bool _selMode = false;
  bool _filling = false;
  final Set<int> _sel = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final l = await _svc.apps(keyword: _kw);
      if (mounted) setState(() {
        _list = l;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toggleSel(int id) {
    if (id <= 0) return;
    setState(() {
      if (_sel.contains(id)) {
        _sel.remove(id);
      } else {
        _sel.add(id);
      }
    });
  }

  /// ★ 一键补全缺失参数：ids 有值=补选中；all=true=补全部有缺失的
  Future<void> _fill({List<int>? ids, bool all = false}) async {
    if (!all && (ids == null || ids.isEmpty)) {
      ToastUtil.info('请先勾选要补全的软件');
      return;
    }
    setState(() => _filling = true);
    try {
      final r = await _svc.appFill(ids: ids, all: all);
      final total = r['total'] ?? 0;
      final filled = r['filled'] ?? 0;
      final skipped = r['skipped'] ?? 0;
      final failed = r['failed'] ?? 0;
      if (!mounted) return;
      setState(() {
        _filling = false;
        _selMode = false;
        _sel.clear();
      });
      final raw = r['details'];
      final details = raw is List ? raw : const [];
      _showFillResult('检查 $total 个 · 补全 $filled · 已完整 $skipped · 失败 $failed', details);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _filling = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirmFillAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('一键补全缺失参数'),
        content: const Text(
            '将扫描所有「信息不全」的蓝奏云软件，'
            '自动补齐图标 / 大小 / 简介 / 版本号。\n\n'
            '信息已完整的软件不会被改动，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('开始补全')),
        ],
      ),
    );
    if (ok == true) await _fill(all: true);
  }

  void _showFillResult(String title, List details) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.62,
        decoration: BoxDecoration(
          color: ctx.isDark ? C.bg1 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('补全结果', style: Ty.h2.copyWith(fontSize: 17, color: ctx.t1)),
            const SizedBox(height: 4),
            Text(title, style: Ty.small.copyWith(color: ctx.t3)),
            const SizedBox(height: 12),
            Expanded(
              child: details.isEmpty
                  ? Center(
                      child: Text('没有需要补全的软件 ✅',
                          style: Ty.small.copyWith(color: ctx.t3)))
                  : ListView.separated(
                      itemCount: details.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (_, i) {
                        final d = Map<String, dynamic>.from(details[i] as Map);
                        final success = '${d['ok'] ?? 0}' == '1';
                        return Row(
                          children: [
                            Icon(
                                success
                                    ? Icons.check_circle_rounded
                                    : Icons.error_rounded,
                                size: 16,
                                color: success ? C.success : C.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${d['title'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ty.small.copyWith(color: ctx.t2)),
                            ),
                            const SizedBox(width: 8),
                            Text('${d['note'] ?? ''}',
                                style: Ty.tiny.copyWith(color: ctx.t3)),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 小胶囊按钮（工具栏用）
  Widget _miniBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final fg = enabled ? color : context.t3;
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? color.withAlpha(24) : context.t3.withAlpha(12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: enabled ? color.withAlpha(110) : Colors.transparent,
              width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        onSubmitted: (v) {
                          _kw = v;
                          _load();
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '搜索软件名称',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(R.md)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SoftButton(
                    label: '新增',
                    icon: Icons.add_rounded,
                    height: 40,
                    onPressed: () => _edit(null),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: '分类管理',
                    icon: const Icon(Icons.category_rounded,
                        size: 21, color: C.violet),
                    onPressed: _manageCats,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              // ★ 一键补全缺失参数（单选 / 多选）
              Row(
                children: [
                  _miniBtn(
                    icon: Icons.auto_fix_high_rounded,
                    label: _filling ? '补全中…' : '一键补全',
                    color: C.success,
                    onTap: _filling ? null : _confirmFillAll,
                  ),
                  const SizedBox(width: 8),
                  if (!_selMode)
                    _miniBtn(
                      icon: Icons.checklist_rounded,
                      label: '多选',
                      color: C.brand,
                      onTap: () => setState(() => _selMode = true),
                    )
                  else ...[
                    _miniBtn(
                      icon: Icons.auto_fix_high_rounded,
                      label: '补全选中(${_sel.length})',
                      color: C.success,
                      onTap: (_filling || _sel.isEmpty)
                          ? null
                          : () => _fill(ids: _sel.toList()),
                    ),
                    const SizedBox(width: 8),
                    _miniBtn(
                      icon: Icons.select_all_rounded,
                      label: _sel.isNotEmpty && _sel.length == _list.length
                          ? '取消全选'
                          : '全选',
                      color: C.cyan,
                      onTap: () => setState(() {
                        if (_sel.isNotEmpty && _sel.length == _list.length) {
                          _sel.clear();
                        } else {
                          _sel.clear();
                          _sel.addAll(_list
                              .map((a) => int.tryParse('${a['id']}') ?? 0)
                              .where((v) => v > 0));
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    _miniBtn(
                      icon: Icons.close_rounded,
                      label: '取消',
                      color: C.danger,
                      onTap: () => setState(() {
                        _selMode = false;
                        _sel.clear();
                      }),
                    ),
                  ],
                  const Spacer(),
                  if (_selMode && _sel.isNotEmpty)
                    Text('已选 ${_sel.length}',
                        style: Ty.tiny.copyWith(color: context.t3)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingState(text: '加载软件列表…')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                    itemCount: _list.length,
                    itemBuilder: (context, i) {
                      final a = _list[i];
                      final isLocal = a['provider'] == 'local';
                      // ★ 一键补全：多选标记
                      final aid = int.tryParse('${a['id']}') ?? 0;
                      final picked = _sel.contains(aid);
                      return KitCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        onTap: _selMode ? () => _toggleSel(aid) : null,
                        child: Row(
                          children: [
                            if (_selMode) ...[
                              Icon(
                                  picked
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: picked ? C.brand : context.t3),
                              const SizedBox(width: 8),
                            ],
                            AppImage(
                              url: '${a['icon']}',
                              width: 44,
                              height: 44,
                              radius: R.sm,
                              placeholderIcon: Icons.android,
                              errorIcon: Icons.android,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${a['title']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Ty.h3.copyWith(
                                          fontSize: 14.5, color: context.t1)),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Pill(
                                        isLocal ? '服务器' : '蓝奏云',
                                        color: isLocal ? C.cyan : C.gold,
                                        small: true,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '${a['size_str'] ?? ''} ${a['version_name'] ?? ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Ty.tiny
                                              .copyWith(color: context.t3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!_selMode) ...[
                              IconButton(
                                tooltip: '补全此软件',
                                icon: const Icon(
                                    Icons.auto_fix_high_rounded,
                                    size: 19, color: C.success),
                                onPressed: _filling
                                    ? null
                                    : () => _fill(ids: [aid]),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined,
                                    size: 19, color: C.brand),
                                onPressed: () => _edit(a),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 19, color: C.danger),
                                onPressed: () => _del(a),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// 分类管理：增 / 改 / 删
  Future<void> _manageCats() async {
    List<Map<String, dynamic>> cats = [];
    try {
      cats = await _svc.appCats();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Future<void> reload() async {
          final l = await _svc.appCats();
          setS(() => cats = l);
        }

        Future<void> editCat(Map? c) async {
          final t = TextEditingController(text: '${c?['title'] ?? ''}');
          final w = TextEditingController(text: '${c?['weigh'] ?? 0}');
          await showDialog(
            context: ctx,
            builder: (dctx) => AlertDialog(
              title: Text(c == null ? '新增分类' : '编辑分类'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: t,
                    decoration: const InputDecoration(
                        labelText: '分类名称', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: w,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '权重（越大越靠前）', isDense: true),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dctx),
                    child: const Text('取消')),
                FilledButton(
                  onPressed: () async {
                    if (t.text.trim().isEmpty) return;
                    Navigator.pop(dctx);
                    try {
                      await _svc.saveCat({
                        'id': c?['id'] ?? 0,
                        'title': t.text.trim(),
                        'weigh': int.tryParse(w.text) ?? 0,
                      });
                      ToastUtil.success('已保存');
                      await reload();
                    } catch (e) {
                      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          );
        }

        Future<void> delCat(Map c) async {
          final ok = await Get.dialog<bool>(AlertDialog(
            title: const Text('删除分类'),
            content: Text('确定删除「${c['title']}」吗？该分类下的软件会变成未分类。'),
            actions: [
              TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Get.back(result: true),
                  child: const Text('删除')),
            ],
          ));
          if (ok != true) return;
          try {
            await _svc.deleteCat(int.tryParse('${c['id']}') ?? 0);
            ToastUtil.success('已删除');
            await reload();
          } catch (e) {
            ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
          }
        }

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.72,
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark
                ? C.bg1
                : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(R.xl)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.category_rounded, color: C.violet, size: 21),
                  const SizedBox(width: 8),
                  Text('分类管理',
                      style: Ty.h2.copyWith(fontSize: 17, color: ctx.t1)),
                  const Spacer(),
                  SoftButton(
                    label: '新增分类',
                    icon: Icons.add_rounded,
                    height: 36,
                    onPressed: () => editCat(null),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: cats.isEmpty
                    ? const Center(child: Text('暂无分类，点击右上角新增'))
                    : ListView.separated(
                        itemCount: cats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = cats[i];
                          return KitCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${c['title']}',
                                          style: Ty.h3.copyWith(
                                              fontSize: 14.5,
                                              color: ctx.t1)),
                                      const SizedBox(height: 2),
                                      Text(
                                          '权重 ${c['weigh'] ?? 0} · ${c['count'] ?? 0} 款软件',
                                          style: Ty.tiny.copyWith(color: ctx.t3)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      size: 19, color: C.brand),
                                  onPressed: () => editCat(c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 19, color: C.danger),
                                  onPressed: () => delCat(c),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }),
    );
    _load();
  }

  Future<void> _del(Map a) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('删除软件'),
      content: Text('确定删除「${a['title']}」吗？'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false), child: const Text('取消')),
        FilledButton(
            onPressed: () => Get.back(result: true), child: const Text('删除')),
      ],
    ));
    if (ok != true) return;
    try {
      await _svc.deleteApp(int.tryParse('${a['id']}') ?? 0);
      ToastUtil.success('已删除');
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _edit(Map? a) async {
    List<Map<String, dynamic>> cats = [];
    try {
      cats = await _svc.appCats();
    } catch (_) {}

    final title = TextEditingController(text: '${a?['title'] ?? ''}');
    final url = TextEditingController(text: '${a?['url'] ?? ''}');
    final icon = TextEditingController(text: '${a?['icon'] ?? ''}');
    final size = TextEditingController(text: '${a?['size_str'] ?? ''}');
    final ver = TextEditingController(text: '${a?['version_name'] ?? ''}');
    final desc = TextEditingController(text: '${a?['description'] ?? ''}');
    final weigh = TextEditingController(text: '${a?['weigh'] ?? 0}');
    final shots = TextEditingController(text: '${a?['screenshots'] ?? ''}');
    String provider = '${a?['provider'] ?? 'lzy'}';
    String filePath = '${a?['file_path'] ?? ''}';
    int catId = int.tryParse('${a?['cat_id'] ?? 0}') ?? 0;
    bool isVip = '${a?['is_vip'] ?? 0}' == '1';
    final vipPrice = TextEditingController(text: '${a?['vip_price'] ?? ''}');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        bool saving = false;
        bool parsing = false;
        String err = '';
        String okTip = '';

        /// 自动解析（蓝奏云链接 → 名称/大小/图标/描述/版本）
        Future<void> doParse() async {
          if (url.text.trim().isEmpty) {
            setS(() => err = '请先填写蓝奏云链接');
            return;
          }
          setS(() {
            parsing = true;
            err = '';
            okTip = '';
          });
          try {
            final d = await _svc.parse(type: 'lzy', url: url.text.trim());
            setS(() {
              parsing = false;
              if ((d['name'] ?? '').toString().isNotEmpty && title.text.isEmpty) {
                title.text = d['name'].toString().replaceAll('.apk', '');
              }
              if ((d['size_str'] ?? '').toString().isNotEmpty) {
                size.text = d['size_str'].toString();
              }
              if ((d['icon'] ?? '').toString().isNotEmpty) {
                icon.text = d['icon'].toString();
              }
              if ((d['description'] ?? '').toString().isNotEmpty) {
                desc.text = d['description'].toString();
              }
              if ((d['version'] ?? '').toString().isNotEmpty) {
                ver.text = d['version'].toString();
              }
              okTip = '解析成功，已自动填充信息 ✅';
            });
          } catch (e) {
            setS(() {
              parsing = false;
              err = e.toString().replaceFirst('Exception: ', '');
            });
          }
        }

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark
                ? C.bg1
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(a == null ? '新增软件' : '编辑软件',
                      style: Ty.h2.copyWith(
                          fontSize: 17,
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? C.t1
                              : C.lt1)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Expanded(
                child: ListView(
                  children: [
                    // ===== 来源选择 =====
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('蓝奏云链接'),
                            selected: provider == 'lzy',
                            onSelected: (_) => setS(() => provider = 'lzy'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('服务器文件'),
                            selected: provider == 'local',
                            onSelected: (_) => setS(() => provider = 'local'),
                          ),
                        ],
                      ),
                    ),

                    // ===== 蓝奏云：链接 + 一键解析 =====
                    if (provider == 'lzy') ...[
                      TextField(
                        controller: url,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          labelText: '蓝奏云分享链接',
                          hintText: 'https://xxx.lanzoup.com/xxxx',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          suffixIcon: IconButton(
                            tooltip: '自动解析软件信息',
                            icon: parsing
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.auto_fix_high, size: 19),
                            onPressed: parsing ? null : doParse,
                          ),
                        ),
                        onChanged: (v) {},
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: parsing ? null : doParse,
                          icon: const Icon(Icons.cloud_download_outlined,
                              size: 17),
                          label: Text(
                            parsing ? '正在解析…' : '自动解析软件信息（名称/大小/图标/版本）',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],

                    // ===== 本地文件：上传 =====
                    if (provider == 'local') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final picked = await FilePicker.platform
                                  .pickFiles(withData: false);
                              if (picked == null || picked.files.isEmpty) return;
                              final f = picked.files.first;
                              setS(() {
                                parsing = true;
                                err = '';
                              });
                              final d = await _svc.uploadFile(File(f.path!));
                              setS(() {
                                parsing = false;
                                filePath = '${d['file_path'] ?? ''}';
                                if ((d['name'] ?? '').toString().isNotEmpty) {
                                  title.text = '${d['name']}';
                                }
                                if ((d['size_str'] ?? '').toString().isNotEmpty) {
                                  size.text = '${d['size_str']}';
                                }
                                okTip = '上传成功，已自动填充信息 ✅';
                              });
                            } catch (e) {
                              setS(() {
                                parsing = false;
                                err = e.toString().replaceFirst('Exception: ', '');
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 17),
                          label: Text(
                            parsing
                                ? '上传中…'
                                : (filePath.isEmpty ? '选择并上传安装包' : '已上传 ✓ 点击重选'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      if (filePath.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('文件路径：$filePath',
                              style: Ty.tiny.copyWith(color: context.t3)),
                        ),
                    ],

                    if (okTip.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: C.success
                                .withAlpha(context.isDark ? 40 : 22),
                            borderRadius: BorderRadius.circular(R.sm),
                          ),
                          child: Text(okTip,
                              style: Ty.small.copyWith(color: C.success)),
                        ),
                      ),

                    const SizedBox(height: 14),
                    Text('基础信息',
                        style: Ty.h3.copyWith(
                            fontSize: 13, color: context.t3)),
                    const SizedBox(height: 8),
                    _field('软件名称 *', title),
                    // 图标：URL + 上传
                    Row(
                      children: [
                        Expanded(child: _field('图标 URL', icon)),
                        IconButton(
                          tooltip: '上传图标',
                          icon: const Icon(Icons.add_photo_alternate_outlined,
                              size: 21),
                          onPressed: () async {
                            try {
                              final picked = await ImagePicker()
                                  .pickImage(source: ImageSource.gallery,
                                      imageQuality: 85);
                              if (picked == null) return;
                              setS(() => parsing = true);
                              final url = await _svc
                                  .uploadImage(File(picked.path));
                              setS(() {
                                icon.text = url;
                                parsing = false;
                                okTip = '图标上传成功 ✅';
                              });
                            } catch (e) {
                              setS(() {
                                parsing = false;
                                err = e.toString().replaceFirst('Exception: ', '');
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    _field('文件大小', size),
                    _field('版本号', ver),
                    _field('软件描述', desc, maxLines: 3),
                    Row(
                      children: [
                        Expanded(child: _field('截图 URL（逗号分隔）', shots)),
                        IconButton(
                          tooltip: '上传截图（可多选）',
                          icon: const Icon(Icons.collections_outlined, size: 21),
                          onPressed: () async {
                            try {
                              final picked = await ImagePicker()
                                  .pickMultiImage(imageQuality: 80);
                              if (picked.isEmpty) return;
                              setS(() => parsing = true);
                              final urls = <String>[];
                              for (final f in picked) {
                                urls.add(await _svc.uploadImage(File(f.path)));
                              }
                              final cur = shots.text.trim();
                              shots.text = cur.isEmpty
                                  ? urls.join(',')
                                  : '$cur,${urls.join(',')}';
                              setS(() {
                                parsing = false;
                                okTip = '已上传 ${urls.length} 张截图 ✅';
                              });
                            } catch (e) {
                              setS(() {
                                parsing = false;
                                err = e.toString().replaceFirst('Exception: ', '');
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    // ===== 会员专享 + 付费设置 =====
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: C.gold.withAlpha(context.isDark ? 34 : 20),
                        borderRadius: BorderRadius.circular(R.sm),
                        border: Border.all(color: C.gold.withAlpha(90)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.workspace_premium_rounded,
                                  size: 18, color: C.gold),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('会员专享资源',
                                    style: Ty.h3.copyWith(
                                        fontSize: 13.5, color: C.gold)),
                              ),
                              Switch(
                                value: isVip,
                                activeThumbColor: C.gold,
                                onChanged: (v) => setS(() => isVip = v),
                              ),
                            ],
                          ),
                          Text('开启后，非会员下载时会提示开通会员',
                              style: Ty.tiny.copyWith(color: context.t3)),
                          const SizedBox(height: 10),
                          // ★ 会员价独立于「会员专享」开关：
                          //   只要填了价格（>0），非会员就必须「余额购买」才能下载。
                          //   （以前只勾会员专享才显示价格框，导致设了价也白设）
                          _field('会员价 / 购买价（¥，填了即需付费，留空=免费）',
                              vipPrice),
                          Text('填了价格后：会员可免费下，非会员需用余额购买',
                              style: Ty.tiny.copyWith(color: context.t3)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<int>(
                        initialValue: catId,
                        decoration: const InputDecoration(
                          labelText: '所属分类',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('未分类')),
                          ...cats.map((c) => DropdownMenuItem(
                                value: int.tryParse('${c['id']}') ?? 0,
                                child: Text('${c['title']}'),
                              )),
                        ],
                        onChanged: (v) => setS(() => catId = v ?? 0),
                      ),
                    ),
                    _field('权重（越大越靠前）', weigh),
                    if (err.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(err,
                            style: Ty.small.copyWith(color: C.danger)),
                      ),
                  ],
                ),
              ),
              PrimaryButton(
                label: '保存',
                loading: saving,
                height: 46,
                onPressed: saving
                    ? null
                    : () async {
                        if (title.text.trim().isEmpty) {
                          setS(() => err = '软件名称不能为空');
                          return;
                        }
                        if (provider == 'lzy' && url.text.trim().isEmpty) {
                          setS(() => err = '请填写蓝奏云链接');
                          return;
                        }
                        if (provider == 'local' && filePath.isEmpty) {
                          setS(() => err = '请先上传安装包');
                          return;
                        }
                        setS(() {
                          saving = true;
                          err = '';
                        });
                        try {
                          await _svc.saveApp({
                            'id': a?['id'] ?? 0,
                            'title': title.text.trim(),
                            'provider': provider,
                            'url': url.text.trim(),
                            'icon': icon.text.trim(),
                            'size_str': size.text.trim(),
                            'version_name': ver.text.trim(),
                            'description': desc.text.trim(),
                            'screenshots': shots.text.trim(),
                            'cat_id': catId,
                            'weigh': int.tryParse(weigh.text) ?? 0,
                            'enable_switch': 1,
                            'file_path': filePath,
                            'is_vip': isVip ? 1 : 0,
                            'vip_price': vipPrice.text.trim(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          ToastUtil.success('保存成功');
                          _load();
                        } catch (e) {
                          setS(() {
                            saving = false;
                            err = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md)),
        ),
      ),
    );
  }
}
