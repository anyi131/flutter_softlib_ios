import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../api/user_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';

/// 帖子详情 + 评论
class PostPage extends StatefulWidget {
  const PostPage({super.key, required this.postId});
  final int postId;

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _svc = ForumService.instance;
  final _input = TextEditingController();
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await _svc.postInfo(widget.postId);
    final c = await _svc.comments(widget.postId);
    if (!mounted) return;
    setState(() {
      _post = p;
      _comments = c;
      _loading = false;
    });
  }

  Future<void> _like() async {
    if (!UserService.instance.isLoggedIn) return ToastUtil.info('请先登录');
    try {
      final r = await _svc.toggleLike(widget.postId);
      if (!mounted || _post == null) return;
      setState(() {
        _post!['liked'] = r['liked'];
        _post!['likes'] = r['likes'];
      });
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _mark() async {
    if (!UserService.instance.isLoggedIn) return ToastUtil.info('请先登录');
    try {
      final r = await _svc.toggleMark(widget.postId);
      if (!mounted || _post == null) return;
      setState(() => _post!['marked'] = r['marked']);
      ToastUtil.success('${r['marked'] == 1 ? '已收藏' : '已取消收藏'}');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty || _sending) return;
    if (!UserService.instance.isLoggedIn) return ToastUtil.info('请先登录');
    setState(() => _sending = true);
    try {
      await _svc.addComment(widget.postId, t);
      _input.clear();
      FocusScope.of(context).unfocus();
      await _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        title: Text('${p?['section_name'] ?? '帖子'}', style: const TextStyle(fontSize: 15)),
        backgroundColor: context.isDark ? C.bg0 : C.lbg0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : p == null
              ? Center(child: Text('帖子不存在', style: TextStyle(color: context.t3)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          Text('${p['title'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w900, color: context.t1, height: 1.35)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('${(p['user'] as Map?)?['nickname'] ?? '匿名'}',
                                  style: TextStyle(fontSize: 12, color: context.t2)),
                              const SizedBox(width: 8),
                              Text('${p['time_text'] ?? ''}',
                                  style: TextStyle(fontSize: 11, color: context.t3)),
                              const SizedBox(width: 8),
                              Text('${p['views'] ?? 0} 阅读',
                                  style: TextStyle(fontSize: 11, color: context.t3)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SelectableText('${p['content'] ?? ''}',
                              style: TextStyle(fontSize: 14, height: 1.75, color: context.t1)),
                          if ((p['images'] as List?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final img in (p['images'] as List))
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network('$img',
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                              width: 100,
                                              height: 100,
                                              color: context.isDark ? C.bg3 : C.lbg2,
                                            )),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _action(
                                p['liked'] == 1 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                '${p['likes'] ?? 0}',
                                p['liked'] == 1 ? C.danger : context.t2,
                                _like,
                              ),
                              const SizedBox(width: 18),
                              _action(
                                p['marked'] == 1 ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                '收藏',
                                p['marked'] == 1 ? C.brand : context.t2,
                                _mark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(color: context.isDark ? Colors.white12 : Colors.black12),
                          Text('评论 ${_comments.length}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.t1)),
                          const SizedBox(height: 6),
                          if (_comments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              child: Center(
                                  child: Text('还没有评论，说说你的看法',
                                      style: TextStyle(fontSize: 12, color: context.t3))),
                            )
                          else
                            for (final c in _comments) _commentTile(c),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        decoration: BoxDecoration(
                          color: context.isDark ? C.bg1 : Colors.white,
                          border: Border(
                              top: BorderSide(
                                  color: context.isDark ? Colors.white12 : Colors.black12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 3,
                                style: TextStyle(fontSize: 13, color: context.t1),
                                decoration: InputDecoration(
                                  hintText: '写评论…',
                                  hintStyle: TextStyle(fontSize: 13, color: context.t3),
                                  isDense: true,
                                  filled: true,
                                  fillColor: context.isDark ? C.bg2 : C.lbg2,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(R.full),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _sending ? null : _send,
                              style: FilledButton.styleFrom(
                                backgroundColor: C.brand,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(R.full)),
                              ),
                              child: _sending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('发送', style: TextStyle(fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _action(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> c) {
    final u = (c['user'] as Map?) ?? const {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: C.brand.withAlpha(30),
            backgroundImage: '${u['avatar'] ?? ''}'.isNotEmpty ? NetworkImage('${u['avatar']}') : null,
            child: '${u['avatar'] ?? ''}'.isEmpty ? Icon(Lz.user, size: 12, color: C.brand) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${u['nickname'] ?? '匿名'}',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700, color: context.t2)),
                    const SizedBox(width: 6),
                    Text('${c['time_text'] ?? ''}',
                        style: TextStyle(fontSize: 10, color: context.t3)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${c['content'] ?? ''}',
                    style: TextStyle(fontSize: 13, height: 1.5, color: context.t1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
