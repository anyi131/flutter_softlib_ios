import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import 'post_page.dart';

/// ★ 1107t 圈子搜索页（修复：右上角放大镜之前误跳「全部帖子」列表）
class CircleSearchPage extends StatefulWidget {
  const CircleSearchPage({super.key});
  @override
  State<CircleSearchPage> createState() => _CircleSearchPageState();
}

class _CircleSearchPageState extends State<CircleSearchPage> {
  final _c = TextEditingController();
  final _svc = ForumService.instance;
  List<Map<String, dynamic>> _hits = [];
  bool _loading = false;
  String? _err;
  bool _searched = false;

  Future<void> _doSearch([String? kw]) async {
    final q = (kw ?? _c.text).trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _err = null;
      _searched = true;
    });
    try {
      final r = await _svc.searchPosts(q);
      if (!mounted) return;
      setState(() => _hits = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.lbg0,
      appBar: AppBar(
        backgroundColor: C.lbg0,
        elevation: 0,
        leading: BackButton(color: C.lt1),
        title: TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _doSearch,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.black.withAlpha(5),
            hintText: '搜索帖子标题 / 内容',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _doSearch(),
            child: const Text('搜索'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!, style: TextStyle(color: C.lt3)))
              : !_searched
                  ? Center(child: Text('输入关键词搜索帖子', style: TextStyle(color: C.lt3)))
                  : _hits.isEmpty
                      ? Center(child: Text('没有找到相关帖子', style: TextStyle(color: C.lt3)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _hits.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final p = _hits[i];
                            return Card(
                              color: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                title: Text('${p['title'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('${p['summary'] ?? ''}',
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                ),
                                trailing: Text('${p['replies'] ?? 0} 评',
                                    style: TextStyle(fontSize: 11, color: C.lt3)),
                                onTap: () => Get.to(() =>
                                    PostPage(postId: int.tryParse('${p['id']}') ?? 0)),
                              ),
                            );
                          },
                        ),
    );
  }
}
