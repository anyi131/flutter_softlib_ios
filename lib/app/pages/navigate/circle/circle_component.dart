import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../api/user_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import 'forum_gallery.dart';
import '../../../utils/toast_util.dart';
import 'my_forum_page.dart';
import 'post_page.dart';
import 'publish_page.dart';
import 'section_page.dart';

/// ★ 1107c 圈子首页 —— 按 ARC（规则之树）圈子 Tab 一比一复刻
///
/// 结构（自上下）：
///   头部：圈子 + 搜索 / 发帖
///   下划线 Tab：最新 / 热门
///   「逛板块」标题行：全部 N 个 →
///   板块卡（横向 2 列，方形图标 + 名称 + 帖子数）
///   帖子流（card 变体：头像/昵称/时间·板块/标题/摘要/图片 1/3 张/计数）
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
      _posts = (p['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
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
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _tabs()),
              if (_sections.isNotEmpty) ...[
                SliverToBoxAdapter(child: _sectionTitle()),
                SliverToBoxAdapter(child: _boardGrid()),
              ],
              if (_posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                    child: Text('最新帖子',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: context.t2)),
                  ),
                ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              else if (_posts.isEmpty)
                SliverToBoxAdapter(child: _empty())
              else
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    decoration: BoxDecoration(
                      color: context.isDark ? C.bg2 : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(context.isDark ? 45 : 9),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (int i = 0; i < _posts.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 0.6,
                              thickness: 0.6,
                              indent: 12,
                              endIndent: 12,
                              color: context.isDark ? C.bg3 : C.lbg2,
                            ),
                          _postCard(_posts[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('圈子',
                      style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          height: 1.1,
                          color: context.t1)),
                  const SizedBox(height: 3),
                  Text('和同好聊聊软件，分享好用的工具',
                      style: TextStyle(fontSize: 12, color: context.t3)),
                ],
              ),
            ),
            _roundBtn(Lz.search, () => Get.to(
                  () => SectionPage(section: const {'id': 0, 'name': '全部帖子'}),
                )?.then((_) => _load())),
            const SizedBox(width: 8),
            _roundBtn(Lz.pencil, _openPublish, primary: true),
            const SizedBox(width: 8),
            _roundBtn(Lz.user, () => Get.to(() => MyForumPage())),
          ],
        ),
      );

  Widget _roundBtn(IconData icon, VoidCallback onTap, {bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary ? C.brand : (context.isDark ? C.bg2 : Colors.white),
          boxShadow: primary
              ? [
                  BoxShadow(
                      color: C.brand.withAlpha(70),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ]
              : null,
        ),
        child: Icon(icon,
            size: 19, color: primary ? Colors.white : context.t2),
      ),
    );
  }

  /// 下划线 Tab（与 ARC 的 arc-tabs 一致：选中实线下划线 + 加粗）
  Widget _tabs() {
    Widget item(String label, String value) {
      final sel = _order == value;
      return GestureDetector(
        onTap: () {
          if (sel) return;
          setState(() => _order = value);
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: sel ? FontWeight.w900 : FontWeight.w500,
                      color: sel ? context.t1 : context.t3)),
              const SizedBox(height: 5),
              Container(
                height: 3,
                width: 18,
                decoration: BoxDecoration(
                  color: sel ? C.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Row(children: [item('最新', 'created'), item('热门', 'hot')]),
    );
  }

  Widget _sectionTitle() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Text('逛板块',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: context.t1)),
            const Spacer(),
            GestureDetector(
              onTap: () => Get.to(
                () => SectionPage(section: const {'id': 0, 'name': '全部帖子'}),
              ),
              child: Row(
                children: [
                  Text('全部 ${_sections.length} 个',
                      style: TextStyle(fontSize: 11.5, color: context.t3)),
                  Icon(Lz.chevronRight, size: 11, color: context.t3),
                ],
              ),
            ),
          ],
        ),
      );

  /// 板块入口：白卡 + 四列网格（对照 tab-forum 的 .boards/.board）
  ///   ARC 数值：tile 88rpx=44pt、radius 26rpx=13pt、名称 22rpx=11pt、gap 12rpx
  Widget _boardGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(builder: (c, box) {
          final w = box.maxWidth / 4;
          return Wrap(
            children: [
              for (final s in _sections)
                SizedBox(
                  width: w,
                  child: AppPressable(
                    onTap: () =>
                        Get.to(() => SectionPage(section: s))?.then((_) => _load()),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  C.brand.withAlpha(context.isDark ? 60 : 26),
                                  C.brand.withAlpha(context.isDark ? 22 : 8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${s['name'] ?? '#'}'.isEmpty
                                  ? '#'
                                  : '${s['name']}'.characters.first,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: context.t2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Text('${s['name'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.t2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  /// 帖子卡（对齐 ARC 的 arc-post-row card 变体）
  Widget _postCard(Map<String, dynamic> p) {
    final u = (p['user'] as Map?) ?? const {};
    final imgs = (p['images'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final avatar = '${u['avatar'] ?? ''}';
    return GestureDetector(
      onTap: () => Get.to(() => PostPage(postId: int.tryParse('${p['id']}') ?? 0))
          ?.then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: context.isDark ? Colors.white10 : Colors.black.withAlpha(8)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: C.brand.withAlpha(30),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty ? Icon(Lz.user, size: 13, color: C.brand) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text('${u['nickname'] ?? '匿名'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: context.t2)),
                      ),
                      if ('${p['section_name'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: C.brand.withAlpha(22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${p['section_name']}',
                              style: TextStyle(fontSize: 9.5, color: C.brand)),
                        ),
                      ],
                    ],
                  ),
                ),
                Text('${p['time_text'] ?? ''}',
                    style: TextStyle(fontSize: 10.5, color: context.t3)),
              ],
            ),
            const SizedBox(height: 9),
            Text('${p['title'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.t1,
                    height: 1.35)),
            if ('${p['summary'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('${p['summary']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: context.t2, height: 1.55)),
            ],
            if (imgs.isNotEmpty) ...[
              const SizedBox(height: 9),
              _images(imgs),
            ],
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(Lz.eye, size: 13, color: context.t3),
                const SizedBox(width: 3),
                Text('${p['views'] ?? 0}',
                    style: TextStyle(fontSize: 11, color: context.t3)),
                const SizedBox(width: 14),
                Icon(Lz.star, size: 13, color: context.t3),
                const SizedBox(width: 3),
                Text('${p['likes'] ?? 0}',
                    style: TextStyle(fontSize: 11, color: context.t3)),
                const SizedBox(width: 14),
                Icon(Lz.messageCircle, size: 13, color: context.t3),
                const SizedBox(width: 3),
                Text('${p['comments'] ?? 0}',
                    style: TextStyle(fontSize: 11, color: context.t3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 图片区：交给 PostGallery（1 张大图 / 2-3 张方图 / 4+ 九宫格 + 点击全屏）
  Widget _images(List imgs) =>
      PostGallery(images: imgs.map((e) => '$e').where((e) => e.isNotEmpty).toList());

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Center(
          child: Column(
            children: [
              Icon(Lz.messageCircle, size: 42, color: context.t3),
              const SizedBox(height: 10),
              Text('还没有帖子，来发第一帖吧',
                  style: TextStyle(fontSize: 13, color: context.t3)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _openPublish,
                style: FilledButton.styleFrom(
                  backgroundColor: C.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(R.full)),
                ),
                child: const Text('发第一帖', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
}
