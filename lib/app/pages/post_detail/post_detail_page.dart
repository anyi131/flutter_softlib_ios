import 'dart:io';

import '../../utils/err_text.dart';

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

import '../../api/post_service.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../routes/app_pages.dart';
import '../../utils/toast_util.dart';
import '../../api/user_service.dart';
import '../../models/post_item.dart';
import '../navigate/square/emoji_panel.dart';
import '../../widgets/post_video_player.dart';

/// 动态详情页（正文 + 图片 + 评论区）
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostService _svc = PostService.instance;

  PostItem? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;

  /// ★ 1014 P0：点赞本地状态 + 请求锁（防连点、失败必须有反馈）
  bool _liked = false;
  bool _likeBusy = false;

  /// 正在回复哪条评论（0 = 普通评论）
  int _replyTo = 0;
  String _replyNick = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final id = int.tryParse('${Get.arguments?['id']}') ?? 0;
    if (id <= 0) {
      setState(() => _loading = false);
      return;
    }
    final d = await _svc.fetchDetail(id);
    final cs = await _svc.comments(id);
    if (!mounted) return;
    setState(() {
      _post = d;
      _comments = cs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      // ★ 与其他页面一致的页面底色 + 光晕（透明 Scaffold 会让页面露出
      //   MaterialApp 的白底，从别的页面切进来会「整屏闪白」）
      backgroundColor: Colors.transparent,
      // ★ 键盘弹出时不要顶起整页（默认 true 会把顶部内容也推上去、非常难看），
      //   只让底部输入栏跟着上移即可
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          Padding(
            padding: EdgeInsets.only(
              top: topInset + 48,
              // 键盘高度：手动给底部输入栏让位，同时避免整页上移
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: _loading
                ? const LoadingState(text: '正在加载动态…')
                : (_post == null
                      ? const EmptyState(
                          text: '动态不存在或已删除',
                          hint: '内容可能已被作者删除',
                          icon: Icons.article_outlined,
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  6,
                                  14,
                                  16,
                                ),
                                children: [
                                  _postCard(),
                                  const SizedBox(height: 12),
                                  _commentHeader(),
                                  const SizedBox(height: 8),
                                  if (_comments.isEmpty)
                                    const SizedBox(
                                      height: 240,
                                      child: EmptyState(
                                        text: '还没有评论，快来抢沙发~',
                                        hint: '说说你的看法吧',
                                        icon: Icons.chat_bubble_outline_rounded,
                                      ),
                                    )
                                  else
                                    ..._comments.map((c) => _commentTile(c)),
                                ],
                              ),
                            ),
                            _inputBar(),
                          ],
                        )),
          ),
          // 悬浮玻璃顶栏（与详情页一致，替代 Material AppBar）
          _topBar(topInset),
        ],
      ),
    );
  }

  /// 悬浮玻璃顶栏
  Widget _topBar(double topInset) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.only(
              top: topInset + 6,
              bottom: 8,
              left: 12,
              right: 12,
            ),
            color: (context.isDark ? C.bg0 : C.lbg0).withAlpha(150),
            child: Row(
              children: [
                _topBtn(Icons.arrow_back_ios_new_rounded, () => Get.back()),
                const Spacer(),
                Text(
                  '动态详情',
                  style: Ty.h3.copyWith(color: context.t1, fontSize: 15),
                ),
                const Spacer(),
                if (_canDelete())
                  _topBtn(Icons.delete_outline_rounded, _deletePost)
                else
                  const SizedBox(width: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBtn(IconData i, VoidCallback f) => GestureDetector(
    onTap: f,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withAlpha(14) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: context.isDark
              ? Colors.white.withAlpha(20)
              : Colors.black.withAlpha(8),
        ),
      ),
      child: Icon(i, size: 16, color: context.t1),
    ),
  );

  Widget _postCard() {
    final p = _post!;
    return KitCard(
      padding: const EdgeInsets.all(15),
      radius: R.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: p.avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: p.avatar,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        color: C.brand.withAlpha(26),
                        child: Icon(Icons.person, size: 21, color: C.brand),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.nickname.isEmpty ? '匿名用户' : p.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.body.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: context.t1,
                            ),
                          ),
                        ),
                        if (p.isAdmin) ...[
                          const SizedBox(width: 5),
                          const Pill(
                            '管理',
                            color: C.danger,
                            solid: true,
                            small: true,
                          ),
                        ],
                        if (p.isVip) ...[
                          const SizedBox(width: 4),
                          const Pill(
                            'VIP',
                            color: C.gold,
                            solid: true,
                            small: true,
                          ),
                        ],
                        if (p.title.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Pill(p.title, color: C.brand, small: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (p.catTitle.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: C.brand.withAlpha(22),
                              borderRadius: BorderRadius.circular(R.xs),
                            ),
                            child: Text(
                              p.catTitle,
                              style: Ty.tiny.copyWith(
                                fontSize: 10,
                                color: C.brand,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        // 1013d：本人待审动态标记
                        if (p.mine && p.status == 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: C.warning.withAlpha(28),
                              borderRadius: BorderRadius.circular(R.xs),
                            ),
                            child: Text(
                              '审核中',
                              style: Ty.tiny.copyWith(
                                fontSize: 10,
                                color: C.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          p.relTime,
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.visibility_outlined,
                          size: 12,
                          color: context.t3,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${p.views}',
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              p.content,
              style: Ty.body.copyWith(
                fontSize: 15,
                height: 1.65,
                color: context.t1,
              ),
            ),
          ],
          // 视频（与列表页一致）
          if (p.videoUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            PostVideoPlayer(
              url: p.videoUrl,
              type: p.videoType,
              postId: p.id,
              source: p.videoSource,
              cover: p.videoCover,
              maxHeight: 420,
            ),
          ],
          if (p.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final img in p.images)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _preview(img),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(R.sm),
                    child: CachedNetworkImage(
                      imageUrl: img,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(height: 180, color: Colors.black12),
                      errorWidget: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.black12,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: context.isDark
                ? Colors.white.withAlpha(25)
                : Colors.black.withAlpha(20),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _action(
                _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                '${p.likeCount}',
                () async {
                  if (_likeBusy) return; // ★ P0：防连点
                  _likeBusy = true;
                  try {
                    final n = await _svc.like(p.id);
                    if (!mounted || n == null) return;
                    // ★ 用 copyWith：避免手动重建时漏字段导致视频/图片丢失
                    setState(() {
                      _post = p.copyWith(likeCount: n);
                      _liked = !_liked;
                    });
                  } catch (e) {
                    // ★ P0：失败必须有反馈（原来完全静默）
                    if (mounted) {
                      ToastUtil.error(ErrText.of(e));
                    }
                  } finally {
                    _likeBusy = false;
                  }
                },
                color: _liked ? C.danger : null,
              ),
              const SizedBox(width: 20),
              _action(
                Icons.chat_bubble_outline_rounded,
                '${p.commentCount}',
                () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(R.xs),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color ?? context.t3),
          const SizedBox(width: 4),
          Text(
            label,
            style: Ty.small.copyWith(fontSize: 12.5, color: context.t2),
          ),
        ],
      ),
    ),
  );

  Widget _commentHeader() => Row(
    children: [
      SectionHeader(title: '评论', accent: C.brand),
      const Spacer(),
      Text('${_comments.length} 条', style: Ty.tiny.copyWith(color: context.t3)),
    ],
  );

  /// 评论条目：头像 + 昵称 + 身份徽标 + 内容 + @回复 + 操作
  Widget _commentTile(Map<String, dynamic> c) {
    final avatar = (c['avatar'] ?? '').toString();
    final nickname = (c['nickname'] ?? '匿名用户').toString();
    final isAdmin = c['is_admin'] == true || c['is_admin'] == 1;
    final isVip = c['is_vip'] == true || c['is_vip'] == 1;
    final title = (c['title'] ?? '').toString();
    final replyNick = (c['reply_nickname'] ?? '').toString();
    final replyTo = (c['reply_to'] as num?)?.toInt() ?? 0;
    final canDel = _canDeleteComment(c);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 32,
                    height: 32,
                    color: C.brand.withAlpha(26),
                    child: Icon(Icons.person, size: 17, color: C.brand),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 昵称 + 身份徽标
                Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      nickname,
                      style: Ty.small.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                    if (isAdmin)
                      const Pill(
                        '管理',
                        color: C.danger,
                        solid: true,
                        small: true,
                      ),
                    if (isVip)
                      const Pill(
                        'VIP',
                        color: C.gold,
                        solid: true,
                        small: true,
                      ),
                    if (title.isNotEmpty)
                      Pill(title, color: C.brand, small: true),
                  ],
                ),
                const SizedBox(height: 4),
                // 内容（回复时先显示 @某人）
                RichText(
                  text: TextSpan(
                    style: Ty.body.copyWith(
                      fontSize: 14,
                      height: 1.5,
                      color: context.t1,
                    ),
                    children: [
                      if (replyTo > 0 && replyNick.isNotEmpty)
                        TextSpan(
                          text: '@$replyNick ',
                          style: TextStyle(
                            color: C.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      TextSpan(text: '${c['content'] ?? ''}'),
                    ],
                  ),
                ),
                if (c['images'] is List && (c['images'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (c['images'] as List)
                          .map(
                            (u) => GestureDetector(
                              onTap: () => _preview('$u'),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(R.xs),
                                child: CachedNetworkImage(
                                  imageUrl: '$u',
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 70,
                                    height: 70,
                                    color: Colors.black12,
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 70,
                                    height: 70,
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      _relTime((c['createtime'] as num?)?.toInt() ?? 0),
                      style: Ty.tiny.copyWith(
                        fontSize: 10.5,
                        color: context.t3,
                      ),
                    ),
                    // v52k #1：IP 属地（小胶囊）
                    if ((c['ip_area'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? Colors.white.withAlpha(14)
                              : Colors.black.withAlpha(10),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'IP·${ipShort((c['ip_area']).toString())}',
                          style: Ty.tiny.copyWith(
                            fontSize: 9.5,
                            color: context.t3,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _startReply(c),
                      child: Text(
                        '回复',
                        style: Ty.tiny.copyWith(
                          fontSize: 11.5,
                          color: C.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (canDel) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _deleteComment(c),
                        child: Text(
                          '删除',
                          style: Ty.tiny.copyWith(
                            fontSize: 11.5,
                            color: C.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 自己发的或管理员可删
  bool _canDeleteComment(Map<String, dynamic> c) {
    final u = UserService.instance.user;
    if (u == null) return false;
    if (u.isAdmin) return true;
    final cid = (c['user_id'] as num?)?.toInt() ?? 0;
    return cid > 0 && cid == u.id;
  }

  Future<void> _deleteComment(Map<String, dynamic> c) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除评论'),
        content: const Text('确定删除这条评论吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await _svc.deleteComment((c['id'] as num?)?.toInt() ?? 0);
    if (done) {
      ToastUtil.success('已删除');
      setState(() => _comments.remove(c));
    } else {
      ToastUtil.error('删除失败');
    }
  }

  /// 点击「回复」→ 打开独立的回复面板（比内嵌输入栏体验好得多）
  void _startReply(Map<String, dynamic> c) {
    final id = (c['id'] as num?)?.toInt() ?? 0;
    final nick = (c['nickname'] ?? '匿名用户').toString();
    if (id <= 0) {
      ToastUtil.info('请稍候，该评论正在同步');
      return;
    }
    _openComposer(replyTo: id, replyNick: nick);
  }

  /// 回复/评论面板：底部弹层，自动聚焦、自动避让键盘、发送后即关
  Future<void> _openComposer({int replyTo = 0, String replyNick = ''}) async {
    final user = UserService.instance.user;
    if (user == null) {
      final go = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('需要登录'),
          content: const Text('评论需要先登录账号'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
      if (go == true) await Get.toNamed(Routes.login);
      return;
    }

    final ctrl = TextEditingController();
    final focus = FocusNode();
    final List<String> images = [];
    final List<File> localImages = [];
    bool sending = false;
    String err = '';
    bool showEmoji = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> pickImage() async {
            try {
              final picked = await ImagePicker().pickMultiImage(
                imageQuality: 82,
              );
              if (picked.isEmpty) return;
              for (final f in picked) {
                if (images.length >= 6) break;
                localImages.add(File(f.path));
                images.add(f.path);
              }
              setSheet(() {});
            } catch (e) {
              setSheet(() => err = '选择图片失败，请允许相册权限');
            }
          }

          Future<void> send() async {
            final text = ctrl.text.trim();
            if (text.isEmpty && images.isEmpty) {
              setSheet(() => err = '请输入内容或添加图片');
              return;
            }
            setSheet(() {
              sending = true;
              err = '';
            });
            try {
              // 先上传本地图片
              final urls = <String>[];
              for (final f in List<File>.from(localImages)) {
                urls.add(await _svc.uploadImage(f));
              }
              final ok = await _svc.comment(
                postId: _post!.id,
                nickname: user.nickname.isEmpty ? '匿名用户' : user.nickname,
                content: text.isEmpty ? '[图片]' : text,
                avatar: user.avatar,
                images: urls,
                replyTo: replyTo,
              );
              if (!ctx.mounted) return;
              if (ok) {
                Navigator.pop(ctx);
                if (!mounted) return;
                ToastUtil.success(replyTo > 0 ? '回复成功' : '评论成功');
                _refreshComments();
              } else {
                setSheet(() {
                  sending = false;
                  err = '发送失败，请重试';
                });
              }
            } catch (e) {
              setSheet(() {
                sending = false;
                err = ErrText.of(e);
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: ctx.isDark ? C.bg2 : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(R.lg),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        replyTo > 0 ? '回复 @$replyNick' : '发表评论',
                        style: Ty.h3.copyWith(color: ctx.t1, fontSize: 15),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: ctx.t2),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    focusNode: focus,
                    autofocus: true,
                    maxLines: 5,
                    minLines: 3,
                    maxLength: 500,
                    style: const TextStyle(fontSize: 14.5, height: 1.5),
                    decoration: InputDecoration(
                      hintText: replyTo > 0 ? '回复 @$replyNick…' : '说点什么…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(R.md),
                      ),
                    ),
                  ),
                  // 已选图片预览
                  if (images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 66,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(R.xs),
                                child: Image.file(
                                  File(images[i]),
                                  width: 66,
                                  height: 66,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => setSheet(() {
                                    images.removeAt(i);
                                    localImages.removeAt(i);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // 表情面板
                  if (showEmoji)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EmojiPanel(
                        onPick: (e) {
                          ctrl.text += e;
                          ctrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: ctrl.text.length),
                          );
                          setSheet(() {});
                        },
                      ),
                    ),
                  if (err.isNotEmpty) ...[
                    Text(
                      err,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: C.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      // 图片
                      GestureDetector(
                        onTap: pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.image_outlined,
                            size: 22,
                            color: ctx.t3,
                          ),
                        ),
                      ),
                      // 表情
                      GestureDetector(
                        onTap: () => setSheet(() => showEmoji = !showEmoji),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.emoji_emotions_outlined,
                            size: 22,
                            color: showEmoji ? C.brand : ctx.t3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${ctrl.text.length}/500',
                        style: Ty.tiny.copyWith(color: ctx.t3),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 104,
                        child: PrimaryButton(
                          label: '发送',
                          icon: Icons.send_rounded,
                          height: 42,
                          loading: sending,
                          expand: false,
                          onPressed: sending ? null : send,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    focus.dispose();
    ctrl.dispose();
  }

  String _relTime(int ts) {
    if (ts <= 0) return '';
    final d = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts * 1000),
    );
    if (d.inMinutes < 1) return '刚刚';
    if (d.inHours < 1) return '${d.inMinutes}分钟前';
    if (d.inDays < 1) return '${d.inHours}小时前';
    if (d.inDays < 30) return '${d.inDays}天前';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// 底部评论栏：点击即打开评论面板（不再内嵌输入框，避免键盘挤压整页）
  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: BoxDecoration(
        color: context.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(context.isDark ? 60 : 12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _openComposer(),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: context.isDark ? Colors.white.withAlpha(12) : C.lbg2,
                    borderRadius: BorderRadius.circular(R.full),
                    border: Border.all(color: C.stroke),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: context.t3),
                      const SizedBox(width: 8),
                      Text('写评论…', style: Ty.small.copyWith(color: context.t3)),
                      const Spacer(),
                      Text(
                        '${_comments.length}',
                        style: Ty.tiny.copyWith(color: context.t3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _openComposer(),
              child: Container(
                width: 46,
                height: 42,
                decoration: BoxDecoration(
                  gradient: Deco.brandGradient,
                  borderRadius: BorderRadius.circular(R.full),
                  boxShadow: [
                    BoxShadow(
                      color: C.brand.withAlpha(90),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 是否可删除（作者本人或管理员）
  bool _canDelete() {
    final p = _post;
    if (p == null) return false;
    final u = UserService.instance.user;
    return u != null && (p.userId == u.id || u.isAdmin);
  }

  Future<void> _deletePost() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除动态'),
        content: const Text('确定删除这条动态吗？评论也会一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await _svc.deletePost(_post!.id);
    if (done) {
      ToastUtil.success('已删除');
      Get.back();
    } else {
      ToastUtil.error('删除失败');
    }
  }

  Future<void> _refreshComments() async {
    final cs = await _svc.comments(_post!.id);
    if (!mounted || cs.isEmpty) return;
    setState(() => _comments = cs);
  }

  void _preview(String url) {
    showDialog(
      context: context,
      builder: (_) => GestureDetector(
        onTap: Get.back,
        child: Container(
          color: Colors.black.withAlpha(220),
          child: Center(child: PhotoView(imageProvider: NetworkImage(url))),
        ),
      ),
    );
  }
}

/// v52k #1：IP 属地短名 —— "江苏省苏州市 联通" → "江苏"，"北京市" → "北京"
String ipShort(String raw) {
  final a = raw.trim();
  if (a.isEmpty) return '';
  final first = a.split(' ').first; // 去掉运营商
  if (first.length >= 3 && first.endsWith('省'))
    return first.substring(0, first.length - 1);
  if (first.length >= 3 && first.endsWith('市'))
    return first.substring(0, first.length - 1);
  if (first.contains('自治区')) {
    final i = first.indexOf('自治区');
    final head = first.substring(0, i);
    return head.length > 4 ? head.substring(head.length - 2) : head;
  }
  if (first.length >= 3 && first.endsWith('特别行政区')) {
    return first.replaceAll('特别行政区', '');
  }
  return first;
}
