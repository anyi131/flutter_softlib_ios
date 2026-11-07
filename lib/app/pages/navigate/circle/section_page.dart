import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import 'forum_gallery.dart';
import 'post_page.dart';

/// 板块页（对照 ARC pages-sub/forum/section.vue）
/// 头图 + 关注按钮 + 帖子流
class SectionPage extends StatefulWidget {
  const SectionPage({super.key, required this.section});
  final Map<String, dynamic> section;

  @override
  State<SectionPage> createState() => _SectionPageState();
}

class _SectionPageState extends State<SectionPage> {
  final _svc = ForumService.instance;
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _list = [];
  late Map<String, dynamic> _sec = Map<String, dynamic>.from(widget.section);
  bool _loading = true;
  bool _more = true;
  int _page = 1;
  String _order = 'created';

  int get _sid => int.tryParse('${widget.section['id']}') ?? 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _loadSec();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSec() async {
    final d = await _svc.sectionInfo(_sid);
    if (d != null && mounted) setState(() => _sec = {...widget.section, ...d});
  }

  Future<void> _toggleFollow() async {
    final r = await _svc.follow(_sid);
    if (r == null) return;
    setState(() {
      _sec['is_follow'] = r['follow'];
      _sec['followers'] = r['followers'];
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (!_more || _loading)) return;
    if (reset) {
      _page = 1;
      _more = true;
      _list.clear();
      setState(() => _loading = true);
    }
    final d = await _svc.posts(section: _sid, order: _order, page: _page, limit: 15);
    final list = (d['list'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (!mounted) return;
    setState(() {
      _list.addAll(list);
      _more = d['has_more'] == true;
      _page++;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg1 : C.lbg1,
      appBar: AppBar(
        backgroundColor: context.isDark ? C.bg1 : C.lbg1,
        elevation: 0,
        foregroundColor: context.t1,
        title: Text('${_sec['name'] ?? '板块'}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.t1)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadSec();
          await _load(reset: true);
        },
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: _list.length + 2,
          itemBuilder: (c, i) {
            if (i == 0) return _hero();
            if (i == 1) {
              if (_list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 90),
                  child: Column(children: [
                    Icon(Lz.fileText, size: 40, color: context.t3.withAlpha(120)),
                    const SizedBox(height: 10),
                    Text(_loading ? '加载中…' : '这个板块还没有帖子',
                        style: TextStyle(fontSize: 13, color: context.t3)),
                  ]),
                );
              }
              return const SizedBox.shrink();
            }
            return _postTile(_list[i - 2]);
          },
        ),
      ),
    );
  }

  Widget _hero() {
    final name = '${_sec['name'] ?? '板块'}';
    final descr = '${_sec['descr'] ?? ''}';
    final cover = '${_sec['cover'] ?? ''}';
    final count = _sec['post_count'] ?? 0;
    final followers = _sec['followers'] ?? 0;
    final followed = '${_sec['is_follow'] ?? 0}' == '1';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            if (cover.isNotEmpty)
              Image.network(cover,
                  height: 116,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _coverFallback())
            else
              _coverFallback(),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withAlpha(25), Colors.black.withAlpha(125)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('$count 帖 · $followers 关注${descr.isEmpty ? '' : ' · $descr'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: Colors.white.withAlpha(220))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 30,
                    child: TextButton(
                      onPressed: _toggleFollow,
                      style: TextButton.styleFrom(
                        backgroundColor: followed ? Colors.white.withAlpha(46) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text(followed ? '已关注' : '+ 关注',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: followed ? Colors.white : C.brand)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() => Container(
        height: 116,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [C.brand, Color.lerp(C.brand, Colors.black, 0.45)!],
          ),
        ),
      );

  Widget _postTile(Map<String, dynamic> p) {
    final u = (p['user'] as Map?) ?? const {};
    final imgs = (p['images'] as List?) ?? const [];
    final imgsStr = imgs.map((e) => '$e').toList();
    return AppPressable(
      onTap: () => Get.to(() => PostPage(postId: int.tryParse('${p['id']}') ?? 0)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: C.brand.withAlpha(29),
                backgroundImage: '${u['avatar'] ?? ''}'.isNotEmpty
                    ? NetworkImage('${u['avatar']}')
                    : null,
                child: '${u['avatar'] ?? ''}'.isEmpty
                    ? Icon(Lz.user, size: 10, color: C.brand)
                    : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${u['nickname'] ?? '匿名'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.t2)),
              ),
              if ('${u['title'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: C.gold.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${u['title']}',
                      style: TextStyle(fontSize: 9, color: C.gold)),
                ),
              ],
              const Spacer(),
              Text('${p['time_text'] ?? ''}',
                  style: TextStyle(fontSize: 11, color: context.t3)),
            ]),
            const SizedBox(height: 8),
            Text('${p['title'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: context.t1)),
            if ('${p['text'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('${p['text']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.5, color: context.t2)),
            ],
            if (imgsStr.isNotEmpty) ...[
              const SizedBox(height: 9),
              PostGallery(images: imgsStr, maxVisible: 9),
            ],
            const SizedBox(height: 8),
            Row(children: [
              _meta(Lz.eye, '${p['views'] ?? 0}'),
              const SizedBox(width: 14),
              _meta(Lz.heart, '${p['likes'] ?? 0}'),
              const SizedBox(width: 14),
              _meta(Lz.messageCircle, '${p['comments'] ?? 0}'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: context.t3),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11.5, color: context.t3)),
      ]);
}
