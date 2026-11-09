import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/lucide.dart';
import '../../../design/title_badge.dart';
import '../../../design/ui.dart';
import '../../../design/user_medals.dart';
import 'post_page.dart';

/// 1109：用户空间（对齐葫芦侠 space 页）
///   头像 + 昵称 + 称号 + 勋章 + 积分 + TA 的帖子
class UserSpacePage extends StatefulWidget {
  const UserSpacePage({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<UserSpacePage> createState() => _UserSpacePageState();
}

class _UserSpacePageState extends State<UserSpacePage> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = int.tryParse('${widget.user['id']}') ?? 0;
    try {
      final r = await ForumService.instance.posts(userId: uid, limit: 20);
      if (!mounted) return;
      setState(() {
        _posts = ((r['list'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final avatar = '${u['avatar'] ?? ''}';
    final medals = ((u['medals'] as List?) ?? const []).map((e) => '$e').toList();
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${u['nickname'] ?? '用户'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // 资料卡
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.isDark ? C.bg2 : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.isDark ? C.bg3 : C.lbg2),
                boxShadow: context.isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: C.brand.withAlpha(30),
                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty
                        ? Icon(Lz.user, size: 26, color: C.brand)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text('${u['nickname'] ?? '匿名'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: context.t1)),
                          ),
                          TitleBadge('${u['title'] ?? ''}',
                              isVip: '${u['is_vip'] ?? 0}' == '1',
                              isAdmin: '${u['is_admin'] ?? 0}' == '1',
                              scale: 1.0),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          InlineMedals(
                            medals: medals,
                            isVip: '${u['is_vip'] ?? 0}' == '1',
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Icon(Lz.trophy, size: 12, color: C.gold),
                          const SizedBox(width: 3),
                          Text('${u['score'] ?? 0} 积分',
                              style: TextStyle(fontSize: 11.5, color: C.gold)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                      color: C.brand, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 7),
              Text('TA 的帖子',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.t1)),
              const Spacer(),
              Text('${_posts.length} 篇',
                  style: TextStyle(fontSize: 11, color: context.t3)),
            ]),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_posts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 44),
                child: Center(
                  child: Column(children: [
                    Icon(Lz.messageCircle, size: 34, color: context.t3.withAlpha(90)),
                    const SizedBox(height: 8),
                    Text('TA 还没有发过帖子',
                        style: TextStyle(fontSize: 12.5, color: context.t3)),
                  ]),
                ),
              )
            else
              for (final p in _posts)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.isDark ? C.bg2 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.isDark ? C.bg3 : C.lbg2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Get.to(
                        () => PostPage(postId: int.tryParse('${p['id']}') ?? 0)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['title'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w800,
                                  color: context.t1)),
                          const SizedBox(height: 6),
                          Text(
                            '${p['section_name'] ?? ''} · ${p['time_text'] ?? ''} · '
                            '${p['views'] ?? 0} 阅读 · ${p['comments'] ?? 0} 评论',
                            style: TextStyle(fontSize: 10.5, color: context.t3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            SizedBox(height: context.tabSpace),
          ],
        ),
      ),
    );
  }
}
