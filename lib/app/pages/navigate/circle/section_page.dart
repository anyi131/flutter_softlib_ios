import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import 'post_page.dart';

/// 板块帖子列表
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
  bool _loading = true;
  bool _more = true;
  int _page = 1;
  String _order = 'created';

  int get _sid => int.tryParse('${widget.section['id']}') ?? 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
    final list = (d['list'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (!mounted) return;
    setState(() {
      _list.addAll(list);
      _more = d['has_more'] == true;
      _page++;
      _loading = false;
    });
  }

  Widget _hero() {
    final name = '${widget.section['name'] ?? '板块'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.brand, Color.lerp(C.brand, Colors.black, 0.35)!],
        ),
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(name.isEmpty ? '#' : name.characters.first,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text('${_list.length} 帖 · ${widget.section['descr'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withAlpha(200))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        title: Text('${widget.section['name'] ?? '板块'}', style: const TextStyle(fontSize: 15)),
        backgroundColor: context.isDark ? C.bg0 : C.lbg0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _order = _order == 'created' ? 'hot' : 'created');
              _load(reset: true);
            },
            child: Text(_order == 'created' ? '最新' : '热门',
                style: TextStyle(fontSize: 13, color: context.t2)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
          itemCount: _list.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (c, i) {
            if (i == 0) return _hero();
            if (i == _list.length + 1) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_more ? '' : '没有更多了',
                          style: TextStyle(fontSize: 11.5, color: context.t3)),
                ),
              );
            }
            final p = _list[i - 1];
            final u = (p['user'] as Map?) ?? const {};
            return GestureDetector(
              onTap: () => Get.to(() => PostPage(postId: int.tryParse('${p['id']}') ?? 0))
                  ?.then((_) => _load(reset: true)),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: context.isDark ? C.bg2 : Colors.white,
                  borderRadius: BorderRadius.circular(R.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['title'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800, color: context.t1, height: 1.35)),
                    const SizedBox(height: 5),
                    Text('${p['summary'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.t2, height: 1.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Lz.user, size: 12, color: context.t3),
                        const SizedBox(width: 3),
                        Text('${u['nickname'] ?? '匿名'}',
                            style: TextStyle(fontSize: 11, color: context.t3)),
                        const SizedBox(width: 8),
                        Text('${p['time_text'] ?? ''}',
                            style: TextStyle(fontSize: 10.5, color: context.t3)),
                        const Spacer(),
                        Icon(Lz.star, size: 12, color: context.t3),
                        Text(' ${p['likes'] ?? 0}',
                            style: TextStyle(fontSize: 10.5, color: context.t3)),
                        const SizedBox(width: 8),
                        Icon(Lz.messageCircle, size: 12, color: context.t3),
                        Text(' ${p['comments'] ?? 0}',
                            style: TextStyle(fontSize: 10.5, color: context.t3)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
