import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../api/user_service.dart';
import '../../../design/lucide.dart';
import '../../../design/title_badge.dart';
import '../../../design/buttons.dart';
import '../../../design/components.dart';
import '../../../design/ui.dart';
import 'forum_gallery.dart';
import 'post_content.dart';
import 'user_space_page.dart';
import '../../../design/user_medals.dart';
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
  int _replyTo = 0;
  String _replyName = '';
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  int _cPage = 1;
  bool _cMore = false;
  bool _cLoadingMore = false;

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
      _cPage = 1;
      _cMore = c.length >= 20;
      _loading = false;
    });
  }

  /// 1109：删除帖子（作者本人 / 管理员）
  Future<void> _confirmDelPost() async {
    final ok = await showAppConfirm(
      context,
      title: '删除帖子',
      message: '删除后帖子将从圈子消失，且无法恢复。',
      okText: '删除',
      danger: true,
    );
    if (!ok) return;
    try {
      await _svc.postDel(widget.postId);
      ToastUtil.success('已删除');
      Get.back();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
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
      ToastUtil.success(r['marked'] == 1 ? '已收藏' : '已取消收藏');
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
      await _svc.addComment(widget.postId, t, parent: _replyTo);
      _input.clear();
      setState(() => _replyTo = 0);
      FocusScope.of(context).unfocus();
      if (!mounted) return; // 1107r
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
      // 1109：键盘手动抬升（系统缩放会把内容挤压且收不回）
      resizeToAvoidBottomInset: false,
      backgroundColor: context.isDark ? C.bg0 : Colors.white,
      appBar: AppBar(
        title: Text('${p?['section_name'] ?? '帖子'}', style: const TextStyle(fontSize: 15)),
        backgroundColor: context.isDark ? C.bg0 : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (p != null &&
              (UserService.instance.user?.id ==
                      int.tryParse('${p['user_id'] ?? 0}') ||
                  UserService.instance.user?.isAdmin == true))
            // 1109：自绘圆形按钮 + 底部动作面板
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppIconButton(
                icon: Lz.more,
                onTap: () => showAppActionSheet(
                  context,
                  title: '帖子操作',
                  actions: [
                    AppActionItem(
                      label: '分享',
                      icon: Lz.share,
                      onTap: _sharePost,
                    ),
                    AppActionItem(
                      label: '删除帖子',
                      icon: Lz.trash2,
                      danger: true,
                      onTap: _confirmDelPost,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : p == null
              ? Center(child: Text('帖子不存在', style: TextStyle(color: context.t3)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ('${p['is_top'] ?? 0}' == '1') ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 3, right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: C.danger.withAlpha(28),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text('置顶',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: C.danger,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                              Expanded(
                                child: Text('${p['title'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: context.t1,
                                        height: 1.35)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // 1109：作者行改成两行（昵称弹性 + 元信息下移），
                          //   原来 7 个元素挤一行必然溢出/被裁。
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => Get.to(() => UserSpacePage(
                                      user: Map<String, dynamic>.from(
                                          (p['user'] as Map?) ?? const {}),
                                    )),
                                child: CircleAvatar(
                                radius: 24,
                                backgroundColor: C.brand.withAlpha(30),
                                backgroundImage:
                                    '${((p['user'] as Map?)?['avatar'] ?? '')}'.isNotEmpty
                                        ? NetworkImage('${(p['user'] as Map?)?['avatar']}')
                                        : null,
                                child: '${((p['user'] as Map?)?['avatar'] ?? '')}'.isEmpty
                                    ? Icon(Lz.user, size: 18, color: C.brand)
                                    : null,
                              ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Flexible(
                                        child: Text(
                                            '${(p['user'] as Map?)?['nickname'] ?? '匿名'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: context.t1)),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 5),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: C.gold.withAlpha(40),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                            'Lv.${((int.tryParse('${(p['user'] as Map?)?['score'] ?? 0}') ?? 0) ~/ 10) + 1}',
                                            style: TextStyle(
                                                fontSize: 9.5,
                                                color: const Color(0xFF8A5A00),
                                                fontWeight: FontWeight.w800)),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: C.brand.withAlpha(28),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text('楼主',
                                            style: TextStyle(
                                                fontSize: 9.5,
                                                color: C.brand,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      _titleBadge(
                                          '${(p['user'] as Map?)?['title'] ?? ''}'),
                                      InlineMedals(
                                        medals: (((p['user'] as Map?)?['medals']
                                                    as List?) ??
                                                const [])
                                            .map((e) => '$e')
                                            .toList(),
                                        isVip:
                                            '${(p['user'] as Map?)?['is_vip'] ?? 0}' == '1',
                                        size: 15,
                                        compact: true,
                                      ),
                                      if ('${((p['user'] as Map?)?['is_admin'] ?? 0)}' == '1')
                                        _adminBadge()
                                      else if ('${((p['user'] as Map?)?['is_vip'] ?? 0)}' == '1')
                                        _vipBadge(),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${p['views'] ?? 0} 阅读 · ${_comments.length} 评论    ${p['time_text'] ?? ''}',
                                      style: TextStyle(fontSize: 11, color: context.t3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // 1109：正文富文本（标题/列表/引用/图片/粗体）
                          // 1109：图片交给下面的 PostGallery 统一渲染
                          //   （那边支持点击全屏 + 长按保存），这里再传一次会重复显示两张
                          PostContent(text: '${p['content'] ?? ''}'),
                          if ((p['images'] as List?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            PostGallery(
                              images: (p['images'] as List)
                                  .map((e) => '$e')
                                  .where((e) => e.isNotEmpty)
                                  .toList(),
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
                          const SizedBox(height: 6),
                          Text('评论 ${_comments.length}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.t1)),
                          const SizedBox(height: 6),
                          if (_comments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              child: Column(
                                children: [
                                  Icon(Lz.messageCircle,
                                      size: 40,
                                      color: context.isDark ? C.bg3 : C.lbg2),
                                  const SizedBox(height: 10),
                                  Text('还没有评论',
                                      style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: context.t2)),
                                  const SizedBox(height: 4),
                                  Text('说说你的看法，抢个沙发',
                                      style: TextStyle(
                                          fontSize: 11.5, color: context.t3)),
                                  const SizedBox(height: 14),
                                  GestureDetector(
                                    onTap: () {
                                      _replyTo = 0;
                                      _replyName = '';
                                      FocusScope.of(context)
                                          .requestFocus(FocusNode());
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: C.brand.withAlpha(24),
                                        borderRadius:
                                            BorderRadius.circular(99),
                                        border: Border.all(
                                            color: C.brand.withAlpha(90)),
                                      ),
                                      child: Text('写评论',
                                          style: TextStyle(
                                              fontSize: 12.5,
                                              color: C.brand,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            for (var ci = 0; ci < _comments.length; ci++)
                              _commentTile(_comments[ci], ci + 1),
                            if (_cMore)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: _cLoadingMore
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : AppChip('加载更多评论',
                                          onTap: _loadMoreComments),
                                ),
                              ),

                        ],
                      ),
                    ),
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: SafeArea(
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
                                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                minLines: 1,
                                maxLines: 3,
                                style: TextStyle(fontSize: 13, color: context.t1),
                                decoration: InputDecoration(
                                  hintText: _replyTo > 0 ? '回复 @$_replyName' : '写评论…',
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
                    ),
                  ],
                ),
    );
  }

  /// 1109：点赞/收藏统一成胶囊按钮（带图标、按压反馈、激活态高亮）
  Widget _action(IconData icon, String text, Color color, VoidCallback onTap) {
    final active = color != context.t2;
    return AppChip(
      text,
      onTap: onTap,
      icon: icon,
      primary: active,
      dense: true,
    );
  }

  /// 1108z10：VIP 会员标识
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

  /// 1108z10：管理员标识
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

  /// 1109：称号徽章（统一炫酷样式；标题为空不渲染）
  Widget _titleBadge(String title) => TitleBadge(title, scale: 0.95);

  /// 1109：评论分页加载
  Future<void> _loadMoreComments() async {
    if (_cLoadingMore || !_cMore) return;
    setState(() => _cLoadingMore = true);
    try {
      final next = await _svc.comments(widget.postId, page: _cPage + 1);
      if (!mounted) return;
      setState(() {
        _cPage += 1;
        _comments.addAll(next);
        _cMore = next.length >= 20;
        _cLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cLoadingMore = false);
    }
  }

  /// 1109：分享（复制链接）
  Future<void> _sharePost() async {
    final link = 'https://flrjk.52yfx.cn/forum/post/${widget.postId}';
    await Clipboard.setData(ClipboardData(text: link));
    ToastUtil.success('链接已复制');
  }

  Widget _commentTile(Map<String, dynamic> c, [int floor = 0]) {
    final u = (c['user'] as Map?) ?? const {};
    final isReply = (int.tryParse('${c['parent_id'] ?? 0}') ?? 0) > 0;
    final canDel = UserService.instance.user?.id == int.tryParse('${c['user_id'] ?? 0}') ||
        UserService.instance.user?.isAdmin == true;
    return GestureDetector(
      onLongPress: canDel ? () => _confirmDelComment(int.tryParse('${c['id']}') ?? 0) : null,
      child: Padding(
      padding: EdgeInsets.only(left: isReply ? 26 : 0, top: 7, bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: C.brand.withAlpha(30),
            backgroundImage: '${u['avatar'] ?? ''}'.isNotEmpty ? NetworkImage('${u['avatar']}') : null,
            child: '${u['avatar'] ?? ''}'.isEmpty ? Icon(Lz.user, size: 15, color: C.brand) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1109：昵称弹性收缩，时间挪到操作行 —— 原来 4 个元素挤一行必溢出
                Row(
                  children: [
                    Flexible(
                      child: Text('${u['nickname'] ?? '匿名'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: context.t2)),
                    ),
                    _titleBadge('${u['title'] ?? ''}'),
                    // 楼主标识（作者自己回帖）
                    if ('${c['user_id'] ?? 0}' == '${_post?['user_id'] ?? -1}')
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: C.brand.withAlpha(28),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('楼主',
                            style: TextStyle(
                                fontSize: 9,
                                color: C.brand,
                                fontWeight: FontWeight.w700)),
                      ),
                    InlineMedals(
                      medals: ((u['medals'] as List?) ?? const [])
                          .map((e) => '$e')
                          .toList(),
                      isVip: '${u['is_vip'] ?? 0}' == '1',
                      size: 14,
                      compact: true,
                    ),
                    if ('${u['is_admin'] ?? 0}' == '1')
                      _adminBadge()
                    else if ('${u['is_vip'] ?? 0}' == '1')
                      _vipBadge(),
                  ],
                ),
                const SizedBox(height: 3),
                // 引用被回复的评论（葫芦侠同款灰底块）
                if (c['ref'] is Map) ...[
                  Builder(builder: (_) {
                    final ref = Map<String, dynamic>.from(c['ref'] as Map);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                      decoration: BoxDecoration(
                        color: context.isDark ? C.bg3 : C.lbg1,
                        border: Border(
                            left: BorderSide(
                                color: C.brand.withAlpha(150), width: 2.5)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('回复 ${ref['nick'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: C.brand)),
                          const SizedBox(height: 2),
                          Text('${ref['text'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, color: context.t3, height: 1.4)),
                        ],
                      ),
                    );
                  }),
                ],
                Text('${c['content'] ?? ''}',
                    style: TextStyle(fontSize: 13, height: 1.5, color: context.t1)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyTo = int.tryParse('${c['id']}') ?? 0;
                          _replyName = '${u['nickname'] ?? ''}';
                        });
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                      child: Text('回复',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: C.brand)),
                    ),
                    const SizedBox(width: 8),
                    Text('·',
                        style: TextStyle(fontSize: 11, color: context.t3.withAlpha(120))),
                    const SizedBox(width: 8),
                    Text('${c['time_text'] ?? ''}',
                        style: TextStyle(fontSize: 10.5, color: context.t3)),
                    const Spacer(),
                    if (floor > 0)
                      Text('$floor 楼',
                          style: TextStyle(fontSize: 10, color: context.t3.withAlpha(160))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  /// 长按删除自己的评论（管理员可删任意）
  Future<void> _confirmDelComment(int id) async {
    final okdel = await showAppConfirm(
      context,
      title: '删除评论',
      message: '删除后无法恢复，确定删除这条评论吗？',
      okText: '删除',
      danger: true,
    );
    if (!okdel) return;
    try {
      await _svc.commentDel(id);
      if (!mounted) return;
      ToastUtil.success('已删除');
      _load();
    } catch (e) {
      if (!mounted) return;
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
