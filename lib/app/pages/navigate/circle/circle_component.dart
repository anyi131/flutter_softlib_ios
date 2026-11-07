import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../api/user_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';
import 'post_page.dart';
import 'my_forum_page.dart';
import 'publish_page.dart';
import 'section_page.dart';

/// ★ 1107a 圈子首页（替代旧「广场」）
///   顶部：板块入口；下方：热门/最新帖子流
class CircleComponent extends StatefulWidget {
  const CircleComponent({super.key});

  @override
  State<CircleComponent> createState() => _CircleComponentState();
}

class _CircleComponentState extends State<CircleComponent> {
  final _svc = ForumService.instance;
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String _order = 'created';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final secs = await _svc.sections();
    final p = await _svc.posts(order: _order, limit: 20);
    if (!mounted) return;
    setState(() {
      _sections = secs;
      _posts = (p['list'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  void _openPublish() {
    if (!UserService.instance.isLoggedIn) {
      ToastUtil.info('发帖需要先登录');
      return;
    }
    Get.to(() => PublishPage(sections: _sections))?.then((v) {
      if (v == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.isDark ? C.bg0 : C.lbg0,
              surfaceTintColor: Colors.transparent,
              title: Text('圈子', style: Ty.h3.copyWith(color: context.t1)),
              actions: [
                IconButton(
                  icon: Icon(Lz.search, size: 20, color: context.t2),
                  onPressed: () => Get.to(() => SectionPage(section: const {'id': 0, 'name': '全部帖子'}))?.then((_) => _load()),
                ),
                IconButton(
                  icon: Icon(Lz.pencil, size: 20, color: C.brand),
                  onPressed: _openPublish,
                ),
                IconButton(
                  icon: Icon(Lz.user, size: 20, color: context.t2),
                  onPressed: () => Get.to(() => MyForumPage()),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _sectionGrid()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Row(
                  children: [
                    Text('帖子', style: Ty.h3.copyWith(color: context.t1, fontSize: 16)),
                    const Spacer(),
                    _orderChip('最新', 'created'),
                    const SizedBox(width: 8),
                    _orderChip('热门', 'hot'),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else if (_posts.isEmpty)
              SliverToBoxAdapter(child: _empty())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (c, i) => _postTile(_posts[i]),
                  childCount: _posts.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Widget _orderChip(String label, String value) {
    final sel = _order == value;
    return AppPressable(
      onTap: () {
        if (sel) return;
        setState(() => _order = value);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? C.brand : (context.isDark ? C.bg3 : C.lbg2),
          borderRadius: BorderRadius.circular(R.full),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                color: sel ? Colors.white : context.t2)),
      ),
    );
  }

  Widget _sectionGrid() {
    if (_sections.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
        ),
        itemCount: _sections.length,
        itemBuilder: (c, i) {
          final s = _sections[i];
          return AppPressable(
            onTap: () => Get.to(() => SectionPage(section: s))?.then((_) => _load()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.isDark ? C.bg2 : Colors.white,
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(
                    color: context.isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(8)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.t1)),
                  const SizedBox(height: 3),
                  Text('${s['post_count'] ?? 0} 帖 · ${s['descr'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: context.t3)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _postTile(Map<String, dynamic> p) {
    final user = (p['user'] as Map?) ?? const {};
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: GestureDetector(
        onTap: () => Get.to(() => PostPage(postId: int.tryParse('${p['id']}') ?? 0)),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: context.isDark ? C.bg2 : Colors.white,
            borderRadius: BorderRadius.circular(R.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: C.brand.withAlpha(30),
                    backgroundImage: '${user['avatar'] ?? ''}'.isNotEmpty
                        ? NetworkImage('${user['avatar']}')
                        : null,
                    child: '${user['avatar'] ?? ''}'.isEmpty
                        ? Icon(Lz.user, size: 12, color: C.brand)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('${user['nickname'] ?? '匿名'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: context.t2)),
                  ),
                  const SizedBox(width: 6),
                  Text('· ${p['time_text'] ?? ''}',
                      style: TextStyle(fontSize: 10.5, color: context.t3)),
                  const Spacer(),
                  if ('${p['section_name'] ?? ''}'.isNotEmpty)
                    Text('${p['section_name']}',
                        style: TextStyle(fontSize: 10.5, color: C.brand.withAlpha(200))),
                ],
              ),
              const SizedBox(height: 8),
              Text('${p['title'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.t1, height: 1.35)),
              const SizedBox(height: 4),
              Text('${p['summary'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.t2, height: 1.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _stat(Lz.eye, '${p['views'] ?? 0}'),
                  const SizedBox(width: 14),
                  _stat(Lz.star, '${p['likes'] ?? 0}'),
                  const SizedBox(width: 14),
                  _stat(Lz.messageCircle, '${p['comments'] ?? 0}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 13, color: context.t3),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 11, color: context.t3)),
        ],
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Lz.messageCircle, size: 38, color: context.t3),
              const SizedBox(height: 10),
              Text('还没有帖子，来发第一帖吧', style: TextStyle(fontSize: 13, color: context.t3)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _openPublish,
                style: FilledButton.styleFrom(
                  backgroundColor: C.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.full)),
                ),
                child: const Text('发第一帖', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
}
