import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../api/soft_service.dart';
import '../../../api/user_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/adaptive.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import '../../../design/title_badge.dart';
import '../../../design/user_medals.dart';
import '../../../design/skeleton.dart';
import '../../../design/tokens.dart';
import 'forum_gallery.dart';
import 'user_space_page.dart';
import '../../../utils/toast_util.dart';
import 'my_forum_page.dart';
import 'circle_search_page.dart';
import 'post_page.dart';
import 'section_page.dart';
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
  List<Map<String, dynamic>> _rankList = [];
  List<Map<String, dynamic>> _secList = [];
  bool _secCollapsed = false;
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
    // 1109：sections/rank/posts 一次并发拉全，避免 _secList 异步竞态导致统计/横滑空白
    final results = await Future.wait([
      _svc.sections(),
      _svc.posts(order: _order, limit: 20),
      _rankList.isEmpty ? _svc.userRank() : Future.value(_rankList),
    ]);
    final secs = results[0] as List<Map<String, dynamic>>;
    final p = results[1] as Map<String, dynamic>;
    final rank = results[2] as List<Map<String, dynamic>>;
    if (!mounted) return;
    setState(() {
      _sections = secs;
      _secList = secs;
      _rankList = rank;
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
              SliverToBoxAdapter(child: _rich ? _headerRich() : _header()),
              SliverToBoxAdapter(child: _tabs()),
              if (_sections.isNotEmpty) ...[
                SliverToBoxAdapter(child: _sectionTitle()),
                SliverToBoxAdapter(child: _rich ? _boardGridRich() : _boardGrid()),
              ],
              // 1109：用户榜独立区块（原来塞在帖子卡里，把布局挤乱）
              if (!_rich) SliverToBoxAdapter(child: _userRank()),
              if (_posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                    child: Text('最新帖子',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: context.t2)),
                  ),
                ),
              if (_loading)
                const SliverToBoxAdapter(child: SkeletonPosts())
              else if (_posts.isEmpty)
                SliverToBoxAdapter(child: _empty())
              else
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    decoration: BoxDecoration(
                      color: context.isDark ? C.bg2 : Colors.white,
                      borderRadius: BorderRadius.circular(Tokens.cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(context.isDark ? 45 : 9),
                          blurRadius: Tokens.cardShadow,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // 1109：用户榜已提到帖子列表之前独立成块

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
              // 玻璃底栏悬浮：末尾留出 tab 高度，避免最后一条被挡住
              if (_rich) SliverToBoxAdapter(child: _userRank()),
              SliverToBoxAdapter(child: SizedBox(height: context.tabSpace + 16)),
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
                          fontSize: Tokens.headerSize,
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
            _roundBtn(Lz.search, () => Get.to(() => const CircleSearchPage())),
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
      padding: EdgeInsets.symmetric(horizontal: Tokens.pagePad),
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
                            width: Tokens.boardTile,
                            height: Tokens.boardTile,
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

  /// 1109：列表卡缩略图（渐变蒙层 + 计数）
  Widget _listThumb(BuildContext context, String url, double size, String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 288,
              placeholder: (_, __) =>
                  Container(color: context.isDark ? C.bg2 : C.lbg2),
              errorWidget: (_, __, ___) =>
                  Container(color: context.isDark ? C.bg2 : C.lbg2),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Colors.black.withAlpha(150),
                    Colors.transparent,
                  ],
                  stops: const [0, .55],
                ),
              ),
            ),
            Positioned(
              left: 7,
              bottom: 6,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Lz.image, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(blurRadius: 3, color: Colors.black45)
                        ])),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// 1109：卡片文字区（标题 + 摘要）
  Widget _cardText(Map<String, dynamic> p, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
              style: TextStyle(
                  fontSize: 12.5, color: context.t2, height: 1.55)),
        ],
      ],
    );
  }
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
                      _titleBadge('${u['title'] ?? ''}'),
                      InlineMedals(
                        medals: ((u['medals'] as List?) ?? const [])
                            .map((e) => '$e')
                            .toList(),
                        isVip: '${u['is_vip'] ?? 0}' == '1',
                        size: 14,
                        compact: true,
                      ),
                      if ('${u['is_admin'] ?? 0}' == '1') _adminBadge(),
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
            // 1109：列表卡图片三态——1张：左96px+蒙层计数；2~3张：下方横排；>3张：横排3张+末张+N
            if (imgs.length == 1)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _listThumb(context, imgs.first, 96, '1图'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 96,
                      child: _cardText(p, context),
                    ),
                  ),
                ],
              )
            else
              _cardText(p, context),
            if (imgs.length > 1) ...[
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                final w = ((c.maxWidth - 12) / 3).clamp(56.0, 120.0);
                return Row(
                  children: [
                    for (int i = 0; i < 3 && i < imgs.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: i < 2 && imgs.length > 1 ? 6 : 0),
                        child: _listThumb(
                            context,
                            imgs[i],
                            w,
                            imgs.length > 3 && i == 2
                                ? '+${imgs.length - 3}'
                                : '${i + 1}'),
                      ),
                  ],
                );
              }),
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
  /// 1108z14：板块数据
  Future<void> _ensureSections() async {
    if (_secList.isNotEmpty && _rankList.isNotEmpty) return;
    try {
      final list = _secList.isEmpty ? await ForumService.instance.sections() : _secList;
      final rank = _rankList.isEmpty ? await ForumService.instance.userRank() : _rankList;
      if (!mounted) return;
      setState(() {
        _secList = list;
        _rankList = rank;
      });
    } catch (_) {}
  }

  /// 1108z14：板块宫格（3列圆角图标卡）
  Widget _secGrid() {
    if (_secList.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.isDark ? C.bg2 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.isDark ? C.bg3 : C.lbg2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 7),
          Text('板块', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.t1)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _secCollapsed = !_secCollapsed),
            child: Row(children: [
              Text(_secCollapsed ? '展开' : '收起', style: TextStyle(fontSize: 11.5, color: context.t3)),
              Icon(_secCollapsed ? Lz.chevronDown : Lz.chevronUp, size: 13, color: context.t3),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        if (!_secCollapsed)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10,
                childAspectRatio: 0.98),
            itemCount: _secList.length,
            itemBuilder: (context, i) {
              final s = _secList[i];
              final name = '${s['name'] ?? ''}';
              return GestureDetector(
                onTap: () => Get.to(() => SectionPage(section: s))?.then((_) => _load()),
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    height: 62,
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.brand.withAlpha(36)),
                    ),
                    child: Center(
                      child: Text(name.isNotEmpty ? name.substring(0, 1) : '版',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.brand)),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: context.t2)),
                  Text('${s['post_count'] ?? 0} 帖', style: TextStyle(fontSize: 10, color: context.t3)),
                ]),
              );
            },
          ),
      ]),
    );
  }

  /// 1109：点用户榜 → 用户卡片 + TA 的帖子
  void _showUser(Map<String, dynamic> u) {
    final uid = int.tryParse('${u['id']}') ?? 0;
    if (uid <= 0) return;
    final ctx0 = Get.context!;
    final dark = ctx0.isDark;
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(ctx0).size.height * 0.72,
        decoration: BoxDecoration(
          color: dark ? C.bg2 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
                color: ctx0.t3.withAlpha(60),
                borderRadius: BorderRadius.circular(99)),
          ),
          // 用户卡片
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: C.brand.withAlpha(30),
                backgroundImage: '${u['avatar'] ?? ''}'.isNotEmpty
                    ? NetworkImage('${u['avatar']}') : null,
                child: '${u['avatar'] ?? ''}'.isEmpty
                    ? Icon(Lz.user, size: 22, color: C.brand) : null,
              ),
              const SizedBox(width: 12),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: ctx0.t1)),
                      ),
                      TitleBadge('${u['title'] ?? ''}',
                          isVip: '${u['is_vip'] ?? 0}' == '1',
                          isAdmin: '${u['is_admin'] ?? 0}' == '1'),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Lz.trophy, size: 12, color: C.gold),
                      const SizedBox(width: 3),
                      Text('${u['score'] ?? 0} 积分',
                          style: TextStyle(fontSize: 11.5, color: C.gold)),
                      const SizedBox(width: 10),
                      Text('TA 的帖子',
                          style: TextStyle(fontSize: 11.5, color: ctx0.t3)),
                    ]),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.to(() => UserSpacePage(user: Map<String, dynamic>.from(u)));
                },
                child: const Text('主页', style: TextStyle(fontSize: 12.5)),
              ),
              IconButton(
                icon: Icon(Lz.x, size: 20, color: ctx0.t3),
                onPressed: () => Get.back(),
              ),
            ]),
          ),
          Divider(height: 1, color: ctx0.t3.withAlpha(24)),
          // 帖子列表
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: ForumService.instance.posts(userId: uid, limit: 20),
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                final list = ((snap.data?['list'] as List?) ?? [])
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
                if (list.isEmpty) {
                  return Center(
                    child: Text('TA 还没有发过帖子',
                        style: TextStyle(fontSize: 12.5, color: ctx0.t3)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: ctx0.t3.withAlpha(18)),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      dense: true,
                      title: Text('${p['title'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: ctx0.t1)),
                      subtitle: Text(
                        '${p['section_name'] ?? ''} · ${p['time_text'] ?? ''} · '
                        '${p['views'] ?? 0} 阅读 · ${p['comments'] ?? 0} 评论',
                        style: TextStyle(fontSize: 10.5, color: ctx0.t3),
                      ),
                      trailing: Icon(Lz.chevronRight,
                          size: 15, color: ctx0.t3.withAlpha(120)),
                      onTap: () {
                        Get.back();
                        Get.to(() =>
                            PostPage(postId: int.tryParse('${p['id']}') ?? 0));
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(top: false, child: const SizedBox(height: 6)),
        ]),
      ),
      isScrollControlled: true,
    );
  }

  /// 1108z16：用户榜横滑（活跃用户 top8）
  /// 1109：当前圈子首页模板（后台 ui_config.forum_template）
  bool get _rich =>
      (SoftService.instance.cachedConfig?.uiConfig.forumTemplate ?? 'lean') ==
      'rich';

  Widget _roundBtnWhite(IconData icon, VoidCallback onTap,
      {bool solid = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: solid ? Colors.white : Colors.white.withAlpha(46),
          border: Border.all(
              color: solid ? Colors.white : Colors.white.withAlpha(64)),
          boxShadow: solid
              ? [
                  BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 12,
                      offset: const Offset(0, 5)),
                ]
              : null,
        ),
        child: Icon(icon,
            size: 17, color: solid ? C.brand : Colors.white),
      ),
    );
  }

  Widget _statChip(String v, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(38),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(52)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 9.5, color: Colors.white.withAlpha(190))),
            ],
          ),
        ),
      );

  /// 增强版头图：品牌渐变 + 统计
  Widget _headerRich() {
    final total = _secList.fold<int>(
        0, (m, s) => m + (int.tryParse('${s['post_count'] ?? 0}') ?? 0));
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.brand, C.violet, const Color(0xFFA855F7)],
        ),
        boxShadow: [
          BoxShadow(
            color: C.violet.withAlpha(70),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withAlpha(52),
                  Colors.white.withAlpha(0),
                ]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('圈子',
                          style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.6,
                              height: 1.15)),
                      const SizedBox(height: 5),
                      Text('和同好聊聊软件，分享好用的工具',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withAlpha(200))),
                    ],
                  ),
                ),
                _roundBtnWhite(Lz.search,
                    () => Get.to(() => const CircleSearchPage())),
                const SizedBox(width: 8),
                _roundBtnWhite(Lz.pencil, _openPublish, solid: true),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _statChip('$total', '帖子'),
                const SizedBox(width: 8),
                _statChip('${_secList.length}', '板块'),
                const SizedBox(width: 8),
                _statChip('${_rankList.length}', '活跃用户'),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  /// 增强版板块：横滑彩色卡
  Widget _boardGridRich() {
    if (_secList.isEmpty) return const SizedBox.shrink();
    const palettes = [
      [Color(0xFF5B9BFF), Color(0xFF2E6BFF)],
      [Color(0xFF34D399), Color(0xFF059669)],
      [Color(0xFFFBBF24), Color(0xFFF59E0B)],
      [Color(0xFFA78BFA), Color(0xFF7C4DFF)],
      [Color(0xFFF472B6), Color(0xFFDB2777)],
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _secList.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final s = _secList[i];
            final name = '${s['name'] ?? ''}';
            final c = palettes[i % palettes.length];
            return GestureDetector(
              onTap: () =>
                  Get.to(() => SectionPage(section: s))?.then((_) => _load()),
              child: Container(
                width: 96,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
                decoration: BoxDecoration(
                  color: context.isDark ? C.bg2 : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: context.isDark
                      ? null
                      : [
                          BoxShadow(
                              color: Colors.black.withAlpha(10),
                              blurRadius: 14,
                              offset: const Offset(0, 6)),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(colors: c),
                        boxShadow: [
                          BoxShadow(
                              color: c.last.withAlpha(90),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1) : '版',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: context.t1)),
                    const SizedBox(height: 2),
                    Text('${s['post_count'] ?? 0} 帖',
                        style:
                            TextStyle(fontSize: 10, color: context.t3)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _userRank() {
    if (_rankList.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 0, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(children: [
            Container(width: 3, height: 14, decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 7),
            Text('用户榜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.t1)),
            const Spacer(),
            Text('积分排行', style: TextStyle(fontSize: 10.5, color: context.t3)),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          // 1109：加了称号徽章后 86 不够，底部昵称/积分被裁 → 110
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _rankList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final u = _rankList[i];
              final av = '${u['avatar'] ?? ''}';
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showUser(u),
                child: SizedBox(
                width: 56,
                child: Column(children: [
                  Stack(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: C.brand.withAlpha(30),
                      backgroundImage: av.isNotEmpty ? NetworkImage(av) : null,
                      child: av.isEmpty ? Icon(Lz.user, size: 20, color: C.brand) : null,
                    ),
                    if (i < 3)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                              color: [C.gold, Colors.grey, Colors.brown][i],
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: Colors.white, width: 1.5)),
                          child: Center(
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white))),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 5),
                  Text('${u['nickname'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: context.t2)),
                  if ('${u['title'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SizedBox(
                        width: 56,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: TitleBadge('${u['title']}',
                              isVip: '${u['is_vip'] ?? 0}' == '1',
                              isAdmin: '${u['is_admin'] ?? 0}' == '1',
                              scale: 0.72),
                        ),
                      ),
                    ),
                  Text('${u['score'] ?? 0} 分',
                      style: TextStyle(fontSize: 9.5, color: C.gold)),
                ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  /// 1108z10：VIP 会员标识（金色小冠）
  Widget _vipBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: C.gold.withAlpha(40),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: C.gold.withAlpha(170), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Lz.crown, size: 9, color: C.gold),
        const SizedBox(width: 2),
        const Text('VIP',
            style: TextStyle(
                fontSize: 9.5, color: C.gold, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  /// 1108z10：管理员标识（蓝底）
  Widget _adminBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: C.brand.withAlpha(30),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text('管理',
          style: TextStyle(
              fontSize: 9.5, color: C.brand, fontWeight: FontWeight.w700)),
    );
  }

  /// 1109：称号徽章（统一炫酷样式）
  Widget _titleBadge(String title) => TitleBadge(title, scale: 0.9);

  Widget _images(List imgs) =>
      PostGallery(images: imgs.map((e) => '$e').where((e) => e.isNotEmpty).toList());

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 46),
        child: Center(
          child: Column(
            children: [
              // 插图：三层同心圆 + 图标（无需图片资源）
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.brand.withAlpha(context.isDark ? 22 : 12),
                      ),
                    ),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.brand.withAlpha(context.isDark ? 38 : 20),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [C.brand, Color.lerp(C.brand, Colors.black, 0.25)!],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: C.brand.withAlpha(70),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Lz.messageCircle, size: 26, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('还没有人发帖',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: context.t1)),
              const SizedBox(height: 6),
              Text('来发第一帖，让圈子热闹起来',
                  style: TextStyle(fontSize: 12.5, color: context.t3)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openPublish,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('发第一帖', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: C.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(R.full)),
                ),
              ),
            ],
          ),
        ),
      );
}
