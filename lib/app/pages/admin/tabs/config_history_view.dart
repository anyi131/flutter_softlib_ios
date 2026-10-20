import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/app_anim.dart';
import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';
import '../admin_ui_kit.dart';

/// 后台 · 配置历史与回滚
///
/// ★ 1020（待办）：后台改错一个配置（导航模板/更新地址/轮播）可能直接把 App 搞坏，
///   而且不知道「刚才是什么值」。这里每次保存都自动留快照，可一键回滚。
class ConfigHistoryView extends StatefulWidget {
  const ConfigHistoryView({super.key});

  @override
  State<ConfigHistoryView> createState() => _ConfigHistoryViewState();
}

class _ConfigHistoryViewState extends State<ConfigHistoryView> {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.configHistory();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _rollback(Map<String, dynamic> v) async {
    final file = '${v['file']}';
    // 先看差异再确认
    Map<String, dynamic> view = {};
    try {
      view = await _svc.configHistoryView(file);
    } catch (_) {}
    if (!mounted) return;
    final diffs = ((view['diff'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('回滚配置'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将把配置恢复到 ${v['time']} 的状态。',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 10),
              if (diffs.isEmpty)
                Text(
                  '与当前配置无差异',
                  style: TextStyle(fontSize: 12, color: context.t3),
                )
              else ...[
                Text(
                  '共 ${diffs.length} 项会变化：',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? Colors.black26
                        : const Color(0xFFF5F7FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ListView(
                    shrinkWrap: true,
                    children: diffs.take(30).map((d) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d['key']}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: C.brand,
                              ),
                            ),
                            Text(
                              '${d['from']}  →  ${d['to']}',
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.4,
                                color: context.t2,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                '回滚前会自动保存当前配置，回滚错了还能再回来。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            child: const Text('确认回滚'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.configRollback(file);
      ToastUtil.success('已回滚');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> v) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除该版本'),
        content: Text('删除 ${v['time']} 的快照？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('删除', style: TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.configHistoryDelete('${v['file']}');
      ToastUtil.success('已删除');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  String _size(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState(text: '加载配置历史…');
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            8,
            context.pagePadding,
            4,
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: context.t3),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '每次保存配置都会自动留一份快照，改错了可以一键回滚',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, size: 18, color: context.t3),
              ),
            ],
          ),
        ),
        Expanded(
          child: _list.isEmpty
              ? const EmptyState(text: '还没有配置快照', hint: '去「界面配置」保存一次就会生成')
              : RefreshIndicator(
                  onRefresh: _load,
                  color: C.brand,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      4,
                      context.pagePadding,
                      20,
                    ),
                    itemCount: _list.length,
                    itemBuilder: (c, i) => _tile(_list[i], i == 0),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> v, bool latest) {
    final isRollback = '${v['action']}' == 'rollback';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AdCard(
        radius: R.md,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (isRollback ? C.amber : C.brand).withAlpha(24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isRollback ? Icons.restore_rounded : Icons.history_rounded,
                size: 18,
                color: isRollback ? C.amber : C.brand,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${v['time']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.t1,
                        ),
                      ),
                      if (latest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: C.mint.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '最新',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: C.mint,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${v['keys']} 项配置 · ${_size((v['size'] as num?)?.toInt() ?? 0)}',
                    style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
                  ),
                ],
              ),
            ),
            AppPressable(
              onTap: () => _rollback(v),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: C.brand.withAlpha(22),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: C.brand.withAlpha(70)),
                ),
                child: Text(
                  '回滚',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: C.brand,
                  ),
                ),
              ),
            ),
            AppPressable(
              onTap: () => _delete(v),
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: context.t3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
