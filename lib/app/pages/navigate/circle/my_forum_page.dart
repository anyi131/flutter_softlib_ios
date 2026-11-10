import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import '../../../design/components.dart';
import 'post_page.dart';

/// 我的帖子 / 我的收藏
class MyForumPage extends StatefulWidget {
  const MyForumPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<MyForumPage> createState() => _MyForumPageState();
}

class _MyForumPageState extends State<MyForumPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  final _svc = ForumService.instance;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _marks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await _svc.myPosts();
    final m = await _svc.myMarks();
    if (!mounted) return;
    setState(() {
      _posts = p;
      _marks = m;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        title: const Text('我的圈子', style: TextStyle(fontSize: 15)),
        backgroundColor: context.isDark ? C.bg0 : C.lbg0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: C.brand,
          labelColor: C.brand,
          unselectedLabelColor: context.t3,
          tabs: const [Tab(text: '我的帖子'), Tab(text: '我的收藏')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : TabBarView(
              controller: _tab,
              children: [_list(_posts, '还没发过帖子'), _list(_marks, '还没有收藏')],
            ),
    );
  }

  Widget _list(List<Map<String, dynamic>> data, String empty) {
    if (data.isEmpty) {
      return AppEmpty(
        icon: Lz.inbox,
        title: empty,
        subtitle: '去圈子逛逛，发现感兴趣的话题',
        actionLabel: '去圈子',
        actionIcon: Lz.compass,
        onAction: () => Get.back(),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (c, i) {
        final p = data[i];
        return AppPressable(
          onTap: () => Get.to(() => PostPage(postId: int.tryParse('${p['id']}') ?? 0))
              ?.then((_) => _load()),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800, color: context.t1)),
                const SizedBox(height: 5),
                Text('${p['summary'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.t2, height: 1.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if ('${p['section_name'] ?? ''}'.isNotEmpty)
                      Text('${p['section_name']}',
                          style: TextStyle(fontSize: 10.5, color: C.brand.withAlpha(200))),
                    const SizedBox(width: 8),
                    Text('${p['time_text'] ?? ''}',
                        style: TextStyle(fontSize: 10.5, color: context.t3)),
                    const Spacer(),
                    Icon(Lz.star, size: 12, color: context.t3),
                    Text(' ${p['likes'] ?? 0}',
                        style: TextStyle(fontSize: 10.5, color: context.t3)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
