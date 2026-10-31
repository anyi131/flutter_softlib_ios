import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../design/app_anim.dart';
import '../../utils/err_text.dart';

import 'package:get/get.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../api/message_service.dart';
import '../../routes/app_pages.dart';
import '../../utils/toast_util.dart';

/// 消息通知中心
class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  // ★ 1031q：批量操作（多选模式）
  bool _selecting = false;
  final Set<int> _sel = <int>{};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
    }
    setState(() => _loading = true);
    try {
      final r = await MessageService.instance.list(page: _page);
      if (!mounted) return;
      final list = ((r['list'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        if (reset) {
          _list = list;
        } else {
          _list.addAll(list);
        }
        _hasMore = list.length >= 20;
        _loading = false;
        // ★ 1031q：清掉已不存在的选中项
        final ids = _list.map((m) => (m['id'] as num?)?.toInt() ?? 0).toSet();
        _sel.removeWhere((id) => !ids.contains(id));
        if (_sel.isEmpty) _selecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// ★ 1031q：一键全部已读（顶栏 done_all 图标）
  Future<void> _markAllRead() async {
    try {
      await MessageService.instance.markRead();
      if (!mounted) return;
      setState(() {
        for (final m in _list) {
          m['is_read'] = 1;
        }
      });
      ToastUtil.success('已全部标记为已读');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    try {
      final did = (m['id'] as num?)?.toInt() ?? 0;
      await MessageService.instance.remove(did);
      if (!mounted) return;
      setState(() {
        _list.remove(m);
        _sel.remove(did);
        if (_sel.isEmpty) _selecting = false;
      });
      ToastUtil.success('已删除');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// 点击消息跳转到对应内容
  Future<void> _open(Map<String, dynamic> m) async {
    final id = (m['id'] as num?)?.toInt() ?? 0;
    if ((m['is_read'] as num?)?.toInt() == 0) {
      try {
        await MessageService.instance.markRead(id: id);
        if (mounted) setState(() => m['is_read'] = 1);
      } catch (_) {}
    }
    final lt = (m['link_type'] ?? '').toString();
    final lid = (m['link_id'] as num?)?.toInt() ?? 0;
    if (lt == 'post' && lid > 0) {
      await Get.toNamed(Routes.postDetail, arguments: {'id': lid});
      _load(reset: true);
    } else if (lt.isEmpty) {
      // ★ 1031q：system/无链接消息点开 = 底部弹层看全文
      if (!mounted) return;
      await _showDetail(m);
    } else if (lt == 'recharge') {
      Get.toNamed(Routes.recharge);
    } else if (lt == 'vip') {
      Get.toNamed(Routes.vip);
    } else if (lt == 'app' && lid > 0) {
      Get.toNamed(Routes.appDetails, arguments: {'id': lid});
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          Padding(
            padding: EdgeInsets.only(top: topInset + 54),
            child: _loading && _list.isEmpty
                ? const LoadingState(text: '加载消息…')
                : _list.isEmpty
                ? const EmptyState(
                    text: '暂无消息',
                    hint: '收到评论、点赞、订单通知时会显示在这里',
                    icon: Icons.notifications_none_rounded,
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        context.pagePadding,
                        6,
                        context.pagePadding,
                        30,
                      ),
                      itemCount: _list.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _list.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: SoftButton(
                              label: '加载更多',
                              height: 40,
                              onPressed: () {
                                _page++;
                                _load();
                              },
                            ),
                          );
                        }
                        return _card(_list[i])
                            .animate(delay: (60 * (i % 12)).ms)
                            .fadeIn(curve: Curves.easeOutCubic)
                            .slideY(begin: 0.04, end: 0);
                      },
                    ),
                  ),
          ),
          if (_selecting && _sel.isNotEmpty) _batchBar(),
          _topBar(topInset),
        ],
      ),
    );
  }

  /// ★ 1031q：底部批量操作栏（已读/删除/全选）
  Widget _batchBar() {
    final dark = context.isDark;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: dark ? C.bg2 : Colors.white,
            borderRadius: BorderRadius.circular(R.lg),
            border: Border.all(color: C.stroke),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2C3550).withAlpha(20),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              AppPressable(
                onTap: () => setState(() {
                  if (_sel.length == _list.length) {
                    _sel.clear();
                  } else {
                    _sel.addAll(_list.map((m) => (m['id'] as num?)?.toInt() ?? 0));
                  }
                }),
                child: Text(
                  _sel.length == _list.length ? '取消全选' : '全选',
                  style: Ty.small.copyWith(fontSize: 13, color: context.t2),
                ),
              ),
              const Spacer(),
              Text('已选 ${_sel.length}',
                  style: Ty.small.copyWith(fontSize: 12.5, color: context.t3)),
              const SizedBox(width: 12),
              AppPressable(
                onTap: _batchRead,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: C.brand.withAlpha(dark ? 46 : 26),
                    borderRadius: BorderRadius.circular(R.sm),
                  ),
                  child: Text('标记已读',
                      style: Ty.small.copyWith(fontSize: 12.5, color: C.brand)),
                ),
              ),
              const SizedBox(width: 8),
              AppPressable(
                onTap: _batchDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: C.danger.withAlpha(dark ? 42 : 24),
                    borderRadius: BorderRadius.circular(R.sm),
                  ),
                  child: Text('删除',
                      style: Ty.small.copyWith(fontSize: 12.5, color: C.danger)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ★ 1031q：多选切换
  void _toggleSel(int id) => setState(() {
        _sel.contains(id) ? _sel.remove(id) : _sel.add(id);
      });

  /// ★ 1031q：批量已读
  Future<void> _batchRead() async {
    try {
      for (final id in _sel) {
        await MessageService.instance.markRead(id: id);
      }
      if (!mounted) return;
      setState(() {
        for (final m in _list) {
          if (_sel.contains((m['id'] as num?)?.toInt() ?? 0)) m['is_read'] = 1;
        }
        _sel.clear();
        _selecting = false;
      });
      ToastUtil.success('已标记为已读');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// ★ 1031q：批量删除
  Future<void> _batchDelete() async {
    try {
      for (final id in _sel) {
        await MessageService.instance.remove(id);
      }
      if (!mounted) return;
      setState(() {
        _list.removeWhere((m) => _sel.contains((m['id'] as num?)?.toInt() ?? 0));
        _sel.clear();
        _selecting = false;
      });
      ToastUtil.success('已删除');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Widget _card(Map<String, dynamic> m) {
    final unread = (m['is_read'] as num?)?.toInt() == 0;
    final mid = (m['id'] as num?)?.toInt() ?? 0;
    final type = (m['type'] ?? 'system').toString();
    final (IconData icon, Color color) = switch (type) {
      'comment' => (Icons.chat_bubble_rounded, C.brand),
      'reply' => (Icons.reply_rounded, C.brandBright),
      'like' => (Icons.favorite_rounded, C.rose),
      'order' => (Icons.receipt_long_rounded, C.mint),
      'vip' => (Icons.workspace_premium_rounded, C.gold),
      _ => (Icons.campaign_rounded, C.violet),
    };

    return KitCard(
      margin: const EdgeInsets.only(bottom: 8),
      radius: R.md,
      padding: const EdgeInsets.all(13),
      onTap: _selecting ? () => _toggleSel(mid) : () => _open(m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selecting) ...[
            Icon(
              _sel.contains(mid)
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: _sel.contains(mid) ? C.brand : context.t3,
            ),
            const SizedBox(width: 10),
          ],
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(context.isDark ? 40 : 24),
              borderRadius: BorderRadius.circular(R.sm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${m['title'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ty.small.copyWith(
                          fontSize: 13.5,
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: context.t1,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: C.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if ((m['content'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${m['content']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.tiny.copyWith(color: context.t2, height: 1.5),
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '${m['time_text'] ?? ''}',
                      style: Ty.tiny.copyWith(
                        fontSize: 10.5,
                        color: context.t3,
                      ),
                    ),
                    const Spacer(),
                    AppPressable(
                      onTap: () => _delete(m),
                      child: Text(
                        '删除',
                        style: Ty.tiny.copyWith(fontSize: 11, color: C.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(double topInset) {
    final unread = _list
        .where((m) => (m['is_read'] as num?)?.toInt() == 0)
        .length;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(
          top: topInset + 8,
          left: 12,
          right: 12,
          bottom: 8,
        ),
        child: Row(
          children: [
            AppPressable(
              onTap: Get.back,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.isDark ? C.bg2 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.stroke),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: context.t1,
                ),
              ),
            ),
            const Spacer(),
            Text(
              unread > 0 ? '消息（$unread）' : '消息',
              style: Ty.h3.copyWith(color: context.t1, fontSize: 15),
            ),
            const Spacer(),
            AppPressable(
              onTap: unread > 0 ? _markAllRead : null,
              child: SizedBox(
                width: 36,
                child: unread > 0
                    ? Icon(Icons.done_all_rounded, size: 19, color: C.brand)
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 6),
            AppPressable(
              onTap: _list.isEmpty ? null : () => setState(() {
                _selecting = !_selecting;
                _sel.clear();
              }),
              child: SizedBox(
                width: 40,
                child: Text(
                  _selecting ? '取消' : '管理',
                  style: Ty.tiny.copyWith(
                    fontSize: 13,
                    color: _list.isEmpty ? context.t3 : C.brand,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ★ 1031q：system 消息全文详情弹层
  Future<void> _showDetail(Map<String, dynamic> m) async {
    await Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg2 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.t3.withAlpha(70),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${m['title'] ?? ''}',
                        style: Ty.h3.copyWith(
                          color: context.t1,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AppPressable(
                      onTap: Get.back,
                      child: Icon(Icons.close_rounded, size: 20, color: context.t3),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${m['time_text'] ?? ''}',
                  style: Ty.tiny.copyWith(fontSize: 11, color: context.t3),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      '${m['content'] ?? ''}',
                      style: Ty.body.copyWith(
                        color: context.t2,
                        height: 1.7,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
