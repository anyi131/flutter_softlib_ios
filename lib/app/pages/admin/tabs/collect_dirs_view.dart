import 'package:flutter/material.dart';

import '../admin_ui_kit.dart';

import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 采集 · 目录配置（可增删改，直接同步到采集平台）
///
/// 说明：这里的增删改会直接提交到采集平台，与站点上看到的完全一致。
/// 让你清楚「哪个软件会被传到哪个目录」。
class CollectDirsView extends StatefulWidget {
  const CollectDirsView({super.key});

  @override
  State<CollectDirsView> createState() => _CollectDirsViewState();
}

class _CollectDirsViewState extends State<CollectDirsView>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _dirs = [];
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
      final d = await AdminService.instance.collectDirs();
      if (!mounted) return;
      setState(() {
        _dirs = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _dirs.isEmpty) {
      return const LoadingState(text: '加载目录配置…');
    }
    if (_dirs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 90),
            EmptyState(
              text: '还没有目录配置',
              hint: '请在采集平台网站上添加蓝奏云目录',
              icon: Icons.folder_off_outlined,
              action: SoftButton(label: '重新加载', onPressed: _load),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          8,
          context.pagePadding,
          24,
        ),
        itemCount: _dirs.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AdCard(
                    radius: R.md,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.rule_folder_outlined,
                          size: 18,
                          color: C.brand,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '采集时按「关键词匹配」决定软件传到哪个目录；'
                            '带「兜底」的目录会在都没匹配上时使用。',
                            style: Ty.tiny.copyWith(
                              color: context.t3,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PrimaryButton(
                    label: '添加目录配置',
                    icon: Icons.add_rounded,
                    height: 44,
                    onPressed: () => _editDir(null),
                  ),
                ),
              ],
            );
          }
          return _dirCard(_dirs[i - 1]);
        },
      ),
    );
  }

  Widget _dirCard(Map<String, dynamic> d) {
    final enabled = d['status'] == 1 || d['status'] == '1';
    final fallback = d['is_fallback'] == 1 || d['is_fallback'] == '1';
    final kw = (d['keyword'] ?? '').toString();
    final block = (d['block_keyword'] ?? '').toString();
    final configId = (d['config_id'] as num?)?.toInt() ?? 0;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AdCard(
        margin: const EdgeInsets.only(bottom: 8),
        radius: R.md,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_rounded,
                  size: 19,
                  color: enabled ? C.brand : context.t3,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    (d['name'] ?? '未命名').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.h3.copyWith(fontSize: 14.5, color: context.t1),
                  ),
                ),
                const SizedBox(width: 6),
                if (fallback) Pill('兜底', color: C.accentOrange, small: true),
                if (!enabled) ...[
                  const SizedBox(width: 4),
                  Pill('已禁用', color: C.danger, small: true),
                ],
                const Spacer(),
                // 启用/禁用 开关
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: enabled,
                    activeThumbColor: C.brand,
                    onChanged: configId <= 0 ? null : (v) => _toggle(d, v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _kv(Icons.tag_rounded, '目录 ID  ${d['dir_id']}'),
            if ((d['path'] ?? '').toString().isNotEmpty)
              _kv(Icons.account_tree_outlined, '${d['path']}'),
            _kv(Icons.sort_rounded, '优先级  ${d['priority'] ?? 0}'),
            if (kw.isNotEmpty)
              _kv(Icons.filter_alt_outlined, '关键词  $kw', color: C.mint),
            if (block.isNotEmpty)
              _kv(Icons.block_rounded, '屏蔽  $block', color: C.warning),
            const SizedBox(height: 8),
            Row(
              children: [
                MiniAction(
                  label: '编辑',
                  icon: Icons.edit_outlined,
                  onTap: () => _editDir(d),
                ),
                const SizedBox(width: 7),
                MiniAction(
                  label: '删除',
                  icon: Icons.delete_outline_rounded,
                  color: C.danger,
                  onTap: configId <= 0 ? () {} : () => _delete(d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> d, bool v) async {
    final id = (d['config_id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    try {
      await AdminService.instance.collectDirToggle(id, v);
      ToastUtil.success(v ? '已启用' : '已禁用');
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final id = (d['config_id'] as num?)?.toInt() ?? 0;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除目录配置'),
        content: Text(
          '确定删除「${d['name']}」这条目录配置吗？\n'
          '（只删除采集规则，不会动蓝奏云里的文件）',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.instance.collectDirDelete(id);
      ToastUtil.success('已删除');
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 新增（d == null）或编辑目录
  Future<void> _editDir(Map<String, dynamic>? d) async {
    final nameCtrl = TextEditingController(text: '${d?['name'] ?? ''}');
    final dirIdCtrl = TextEditingController(text: '${d?['dir_id'] ?? ''}');
    final pathCtrl = TextEditingController(text: '${d?['path'] ?? ''}');
    final kwCtrl = TextEditingController(text: '${d?['keyword'] ?? ''}');
    final blockCtrl = TextEditingController(
      text: '${d?['block_keyword'] ?? ''}',
    );
    final priCtrl = TextEditingController(text: '${d?['priority'] ?? 0}');
    bool fallback = d?['is_fallback'] == 1 || d?['is_fallback'] == '1';
    bool enabled = d == null || d['status'] == 1 || d['status'] == '1';
    String err = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.xl),
            ),
            title: Text(
              d == null ? '添加目录配置' : '编辑目录配置',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '目录名称 *',
                        hintText: '如：游戏软件目录',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dirIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '蓝奏云目录ID *',
                        hintText: '蓝奏云文件夹ID',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pathCtrl,
                      decoration: const InputDecoration(
                        labelText: '路径（选填）',
                        hintText: '根目录 / 软件盒子 / xxx',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: kwCtrl,
                      decoration: const InputDecoration(
                        labelText: '关键词（多个用 | 分隔）',
                        hintText: '小说|音乐|影视',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: blockCtrl,
                      decoration: const InputDecoration(
                        labelText: '屏蔽关键词（多个用 | 分隔）',
                        hintText: '正能量|小游戏|加速器',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '优先级（数字越小越优先）',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: fallback,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: C.brand,
                      title: const Text(
                        '设为兜底目录',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        '未匹配到任何规则时使用（只能有一个）',
                        style: TextStyle(fontSize: 11),
                      ),
                      onChanged: (v) => setD(() => fallback = v ?? false),
                    ),
                    CheckboxListTile(
                      value: enabled,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: C.brand,
                      title: const Text('启用', style: TextStyle(fontSize: 13)),
                      onChanged: (v) => setD(() => enabled = v ?? false),
                    ),
                    if (err.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          err,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: C.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    setD(() => err = '请填写目录名称');
                    return;
                  }
                  if (dirIdCtrl.text.trim().isEmpty) {
                    setD(() => err = '请填写蓝奏云目录ID');
                    return;
                  }
                  Get.back(result: true);
                },
                child: Text(d == null ? '添加' : '保存'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.instance.collectDirSave({
        if (d != null) 'config_id': d['config_id'],
        'name': nameCtrl.text.trim(),
        'dir_id': dirIdCtrl.text.trim(),
        'path': pathCtrl.text.trim(),
        'keyword': kwCtrl.text.trim(),
        'block_keyword': blockCtrl.text.trim(),
        'priority': int.tryParse(priCtrl.text.trim()) ?? 0,
        'is_fallback': fallback ? 1 : 0,
        'status': enabled ? 1 : 0,
      });
      ToastUtil.success(d == null ? '目录已添加' : '目录已更新');
      _load();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _kv(IconData i, String text, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, size: 13, color: color ?? context.t3),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Ty.tiny.copyWith(
              fontSize: 11.5,
              color: color ?? context.t3,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
