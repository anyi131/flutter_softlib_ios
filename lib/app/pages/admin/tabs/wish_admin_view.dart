import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/app_action.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';
import '../admin_ui_kit.dart';

/// 后台 · 需求投票（求软件）
///
/// ★ 1020（待办 #2）：用户在 App 里提的「我想要什么软件」，
///   按票数排序 —— 票数最高的就是最该去采集的。
///   管理员可以：采纳（标记已上架）/ 拒绝 / 删除 / 填备注。
class WishAdminView extends StatefulWidget {
  const WishAdminView({super.key});

  @override
  State<WishAdminView> createState() => _WishAdminViewState();
}

class _WishAdminViewState extends State<WishAdminView>
    with AutomaticKeepAliveClientMixin {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic> _stat = {};
  bool _loading = true;
  String _status = 'all';

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
      final r = await _svc.wishList(status: _status);
      if (!mounted) return;
      setState(() {
        _list = ((r['list'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        // ★ 1020：同上，空数组会崩
        final rawStat = r['stat'];
        _stat = rawStat is Map
            ? Map<String, dynamic>.from(rawStat)
            : <String, dynamic>{};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _review(Map<String, dynamic> w, String status) async {
    final id = (w['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    String note = '${w['admin_note'] ?? ''}';
    if (status == 'adopted') {
      final ctrl = TextEditingController(text: note);
      final ok = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('标记为已采纳'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: '备注（用户可见，如「已上架」）',
              isDense: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = ctrl.text.trim();
    }
    try {
      await AppAction.run(
        () => _svc.wishReview(id: id, status: status, note: note),
        loading: '处理中…',
        success: '已更新',
      );
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> w) async {
    final id = (w['id'] as num?)?.toInt() ?? 0;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除需求'),
        content: Text('确定删除「${w['title']}」？投票记录也会一并删除。'),
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
      await AppAction.run(
        () => _svc.wishDelete(id),
        loading: '删除中…',
        success: '已删除',
      );
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  int _n(String k) => (_stat[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // 统计 + 筛选
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            6,
            context.pagePadding,
            6,
          ),
          child: Row(
            children: [
              _statChip('全部', _n('all'), 'all', C.brand),
              const SizedBox(width: 6),
              _statChip('待处理', _n('pending'), 'pending', C.amber),
              const SizedBox(width: 6),
              _statChip('已采纳', _n('adopted'), 'adopted', C.mint),
              const SizedBox(width: 6),
              _statChip('已拒绝', _n('rejected'), 'rejected', context.t3),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingState(text: '加载需求…')
              : (_list.isEmpty
                    ? const EmptyState(
                        text: '还没有用户提需求',
                        hint: '用户在 App 搜索无结果时可以提交',
                      )
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
                          itemBuilder: (c, i) => _card(_list[i], i + 1),
                        ),
                      )),
        ),
      ],
    );
  }

  Widget _statChip(String label, int n, String key, Color color) {
    final sel = _status == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_status == key) return;
          setState(() => _status = key);
          _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: sel ? color.withAlpha(28) : context.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? color.withAlpha(120) : C.stroke,
              width: sel ? 1.2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$n',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: sel ? color : context.t1,
                ),
              ),
              Text(
                label,
                style: Ty.tiny.copyWith(fontSize: 9.5, color: context.t3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> w, int rank) {
    final votes = (w['votes'] as num?)?.toInt() ?? 0;
    final status = '${w['status'] ?? 'pending'}';
    final Color stColor = status == 'adopted'
        ? C.mint
        : (status == 'rejected' ? C.danger : C.amber);
    final String stText = status == 'adopted'
        ? '已采纳'
        : (status == 'rejected' ? '已拒绝' : '待处理');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AdCard(
        radius: R.md,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 排名
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? C.brand.withAlpha(30)
                        : (context.isDark
                              ? Colors.white10
                              : Colors.black.withAlpha(6)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: rank <= 3 ? C.brand : context.t3,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${w['title'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: context.t1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Icon(Icons.thumb_up_rounded, size: 13, color: C.brand),
                    const SizedBox(width: 3),
                    Text(
                      '$votes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: C.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: stColor.withAlpha(28),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    stText,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: stColor,
                    ),
                  ),
                ),
              ],
            ),
            if ('${w['content'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${w['content']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Ty.tiny.copyWith(color: context.t2, height: 1.5),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              [
                if ('${w['nickname'] ?? ''}'.isNotEmpty) '${w['nickname']}',
                if ('${w['cat_name'] ?? ''}'.isNotEmpty) '${w['cat_name']}',
                '${w['time_text'] ?? ''}',
              ].join(' · '),
              style: Ty.tiny.copyWith(fontSize: 10, color: context.t3),
            ),
            if ('${w['admin_note'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                '备注：${w['admin_note']}',
                style: Ty.tiny.copyWith(fontSize: 10, color: C.mint),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _btn('采纳', C.mint, () => _review(w, 'adopted')),
                const SizedBox(width: 6),
                _btn('拒绝', context.t3, () => _review(w, 'rejected')),
                if (status != 'pending') ...[
                  const SizedBox(width: 6),
                  _btn('还原', C.amber, () => _review(w, 'pending')),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => _delete(w),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: C.danger,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withAlpha(22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.withAlpha(70)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    ),
  );
}
