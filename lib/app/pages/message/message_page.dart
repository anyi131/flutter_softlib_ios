import 'package:flutter/material.dart';
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

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
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    try {
      await MessageService.instance.remove((m['id'] as num?)?.toInt() ?? 0);
      if (!mounted) return;
      setState(() => _list.remove(m));
      ToastUtil.success('已删除');
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
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
                              context.pagePadding, 6, context.pagePadding, 30),
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
                            return _card(_list[i]);
                          },
                        ),
                      ),
          ),
          _topBar(topInset),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> m) {
    final unread = (m['is_read'] as num?)?.toInt() == 0;
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
      onTap: () => _open(m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      child: Text('${m['title'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.small.copyWith(
                              fontSize: 13.5,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                              color: context.t1)),
                    ),
                    if (unread)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: C.danger, shape: BoxShape.circle),
                      ),
                  ],
                ),
                if ((m['content'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${m['content']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.tiny.copyWith(color: context.t2, height: 1.5)),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text('${m['time_text'] ?? ''}',
                        style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _delete(m),
                      child: Text('删除',
                          style: Ty.tiny
                              .copyWith(fontSize: 11, color: C.danger)),
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
    final unread =
        _list.where((m) => (m['is_read'] as num?)?.toInt() == 0).length;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(
            top: topInset + 8, left: 12, right: 12, bottom: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: Get.back,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.isDark ? C.bg2 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.stroke),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: context.t1),
              ),
            ),
            const Spacer(),
            Text(unread > 0 ? '消息（$unread）' : '消息',
                style: Ty.h3.copyWith(color: context.t1, fontSize: 15)),
            const Spacer(),
            GestureDetector(
              onTap: unread > 0 ? _markAllRead : null,
              child: SizedBox(
                width: 36,
                child: unread > 0
                    ? Icon(Icons.done_all_rounded,
                        size: 19, color: C.brand)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
