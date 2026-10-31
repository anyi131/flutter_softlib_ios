import 'dart:io';

import '../../../design/glass.dart';
import '../../../utils/err_text.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/post_service.dart';
import '../../../api/user_service.dart';
import '../../../models/post_item.dart';
import '../../../routes/app_pages.dart';
import '../../../design/adaptive.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../widgets/tab_bottom_pad.dart';
import 'emoji_panel.dart';
import '../../../widgets/post_video_player.dart';

/// 广场 - 社区动态
class SquareComponent extends StatefulWidget {
  const SquareComponent({super.key});

  @override
  State<SquareComponent> createState() => _SquareComponentState();
}

class _SquareComponentState extends State<SquareComponent> {
  final PostService _svc = PostService.instance;
  final EasyRefreshController _refresh = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  List<PostCat> _cats = [];
  List<PostItem> _posts = [];
  int _currentCat = 0;
  int _page = 1;
  bool _loading = true;

  /// ★ 1014 P0：本地「已赞」集合 + 请求中锁
  ///   · _likeBusy 防连点把 like_count 点爆（服务端已改为切换语义，双保险）
  ///   · _liked 记录本地已赞态，用于切换图标（实心/空心爱心）
  final Set<int> _liked = <int>{};
  final Set<int> _likeBusy = <int>{};

  /// ★ 1014 P1：请求代号 —— 快速连切分类时丢弃过期响应，防止旧数据覆盖新分类
  int _reqSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadCats();
    _load(reset: true);
  }

  Future<void> _loadCats() async {
    final cats = await _svc.fetchCats();
    if (!mounted) return;
    setState(() => _cats = cats);
  }

  Future<void> _load({bool reset = false, int? page}) async {
    if (reset) _page = 1;
    final target = page ?? _page;
    final seq = ++_reqSeq;
    try {
      final list = await _svc.fetchPosts(page: target, catId: _currentCat);
      // ★ 1014 P1：请求期间用户可能又切了分类/刷新，过期响应直接丢弃
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        if (reset) {
          _posts = list;
        } else {
          _posts.addAll(list);
        }
        _loading = false;
      });
      reset
          ? _refresh.finishRefresh()
          : _refresh.finishLoad(
              list.length < 20
                  ? IndicatorResult.noMore
                  : IndicatorResult.success,
            );
    } catch (e) {
      if (!mounted || seq != _reqSeq) return;
      setState(() => _loading = false);
      // ★ 1014 P0：失败时结束 loading，但不推进页码（由 onLoad 决定是否提交）
      reset ? _refresh.finishRefresh() : _refresh.finishLoad();
      if (!reset) _toast('加载失败，请检查网络后重试');
    }
  }

  void _switchCat(int id) {
    if (_currentCat == id) return;
    setState(() {
      _currentCat = id;
      _posts = [];
      _page = 1;
      _loading = true;
    });
    // ★ 1014 P1 修复：切分类是「重新开始」，把分页指示器复位为
    //   success（EasyRefresh 3.x 无 resetState），否则上一次失败/无更多
    //   的状态会让新分类的上拉被残留 noMore 拒绝加载。
    _refresh.finishLoad(IndicatorResult.success, true);
    _load(reset: true);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _topBar(),
                _catBar(isDark),
                Expanded(child: _body(isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        14,
        context.pagePadding,
        2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('广场', style: Ty.display.copyWith(color: context.t1)),
                const SizedBox(height: 4),
                Text(
                  '交流分享 · 发现好软',
                  style: Ty.small.copyWith(color: context.t3),
                ),
              ],
            ),
          ),
          // ★ 1028：底部悬浮 FAB 已移除，发布入口收进顶栏
          AppPressable(
            onTap: _compose,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.isDark ? C.bg3 : Colors.white,
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: C.brand.withAlpha(70)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 15, color: C.brand),
                  const SizedBox(width: 5),
                  Text(
                    '发布',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catBar(bool isDark) {
    if (_cats.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _cats[i];
          final sel = _currentCat == c.id;
          return AppPressable(
            onTap: () => _switchCat(c.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel ? Deco.brandGradient : null,
                color: sel ? null : (isDark ? C.bg3 : Colors.white),
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Text(
                c.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                  color: sel
                      ? Colors.white
                      : (isDark ? C.t2 : C.lt2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) {
      return const LoadingState(text: '正在加载动态…');
    }
    if (_posts.isEmpty) {
      return const EmptyState(
        text: '还没有动态，快来发第一条',
        hint: '分享你的想法，让大家看到',
        icon: Icons.forum_outlined,
      );
    }
    return EasyRefresh(
      controller: _refresh,
      onRefresh: () => _load(reset: true),
      onLoad: () async {
        // ★ 1014 P0 修复：请求成功后才提交页码自增，失败则原地不动，
        //   否则 catch 不回滚会让这一页 20 条动态被永久跳过。
        final next = _page + 1;
        final before = _posts.length;
        await _load(page: next);
        if (_posts.length > before) _page = next;
      },
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: 4,
          bottom: tabBottomPadding(context) + 60,
        ),
        itemCount: _posts.length,
        // ★ RepaintBoundary：每张卡片独立图层，滚动时不会整列重绘
        // ★ ValueKey：必须给每项唯一 key！否则刷新后 Flutter 会复用旧的
        //   StatefulWidget 元素 —— 视频播放器会残留上一条视频的内容
        //   （用户反馈的「新视频显示旧数据」就是这个原因）
        itemBuilder: (context, i) => RepaintBoundary(
          key: ValueKey('post_${_posts[i].id}'),
          child: AppStaggerIn(
            index: i % 8,
            child: _postCard(_posts[i], isDark),
          ),
        ),
      ),
    );
  }

  Widget _postCard(PostItem p, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        6,
        context.pagePadding,
        6,
      ),
      child: Deco.glass(
        context,
        radius: R.lg,
        alpha: 0.06,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(R.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(R.lg),
            onTap: () async {
              await Get.toNamed(
                Routes.postDetail,
                arguments: {'id': p.id, 'item': p},
              );
              _load(reset: true);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部：头像 + 昵称 + 分类/时间
                  Row(
                    children: [
                      ClipOval(
                        child: p.avatar.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: p.avatar,
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                memCacheWidth: 96,
                              )
                            : _avatar(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // ★ 昵称弹性收缩，徽章固定宽度不参与挤压，
                                //   避免长昵称 + 多个头衔导致 Row 溢出
                                Flexible(
                                  child: Text(
                                    p.nickname.isEmpty ? '匿名用户' : p.nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Ty.h3.copyWith(color: context.t1),
                                  ),
                                ),
                                if (p.isAdmin) ...[
                                  const SizedBox(width: 5),
                                  const Pill(
                                    '管理',
                                    color: C.danger,
                                    small: true,
                                  ),
                                ],
                                if (p.isVip) ...[
                                  const SizedBox(width: 4),
                                  const Pill(
                                    'VIP',
                                    color: C.amber,
                                    small: true,
                                    solid: true,
                                  ),
                                ],
                                if (p.title.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Pill(
                                      p.title,
                                      color: C.brand,
                                      small: true,
                                    ),
                                  ),
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
                                      borderRadius: BorderRadius.circular(
                                        R.xs / 2,
                                      ),
                                    ),
                                    child: Text(
                                      p.catTitle,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: C.brand,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                // 1013d：本人待审/被驳回动态标记
                                if (p.mine && p.status == 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: C.warning.withAlpha(28),
                                      borderRadius: BorderRadius.circular(
                                        R.xs / 2,
                                      ),
                                    ),
                                    child: Text(
                                      '审核中',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: C.warning,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ] else if (p.mine && p.status == 2) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: C.danger.withAlpha(28),
                                      borderRadius: BorderRadius.circular(
                                        R.xs / 2,
                                      ),
                                    ),
                                    child: Text(
                                      '已驳回',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: C.danger,
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
                                if (p.ipArea.isNotEmpty) ...[
                                  const SizedBox(width: 6),
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
                                      'IP·${ipShort(p.ipArea)}',
                                      style: Ty.tiny.copyWith(
                                        fontSize: 9.5,
                                        color: context.t3,
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
                  if (p.content.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      p.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        color: context.t1,
                      ),
                    ),
                  ],
                  // 视频（本地直链 或 分享链接解析后的播放页）
                  // ★ 列表态用 lazy：只显示封面+播放按钮，点了才加载（避免滚动卡顿）
                  if (p.videoUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    PostVideoPlayer(
                      url: p.videoUrl,
                      type: p.videoType,
                      postId: p.id,
                      source: p.videoSource,
                      cover: p.videoCover,
                      lazy: true,
                    ),
                  ],
                  // 图片九宫格
                  if (p.images.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _imageGrid(p.images),
                  ],
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withAlpha(14)
                        : Colors.black.withAlpha(8),
                  ),
                  const SizedBox(height: 8),
                  // 底部：点赞 + 评论 + 浏览
                  Row(
                    children: [
                      _action(
                        icon: _liked.contains(p.id)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _liked.contains(p.id) ? C.danger : null,
                        label: '${p.likeCount}',
                        onTap: () async {
                          // ★ 1014 P0：请求未回来前禁止连点
                          if (_likeBusy.contains(p.id)) return;
                          _likeBusy.add(p.id);
                          try {
                            final n = await _svc.like(p.id);
                            if (!mounted) return;
                            // ★ 用 copyWith：避免手动重建时漏掉 videoUrl 等字段
                            //   （这正是「点赞后视频消失/数据丢失」的原因）
                            setState(() {
                              final idx = _posts.indexWhere(
                                (e) => e.id == p.id,
                              );
                              if (idx >= 0) {
                                _posts[idx] = p.copyWith(likeCount: n);
                              }
                              if (_liked.contains(p.id)) {
                                _liked.remove(p.id);
                              } else {
                                _liked.add(p.id);
                              }
                            });
                          } catch (e) {
                            // ★ 1014 P0：失败必须有反馈（原来完全静默）
                            if (mounted) {
                              _toast(ErrText.of(e));
                            }
                          } finally {
                            _likeBusy.remove(p.id);
                          }
                        },
                      ),
                      const SizedBox(width: 20),
                      _action(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${p.commentCount}',
                        onTap: () async {
                          await Get.toNamed(
                            Routes.postDetail,
                            arguments: {'id': p.id, 'item': p},
                          );
                          _load(reset: true);
                        },
                      ),
                      const Spacer(),
                      Icon(
                        Icons.visibility_outlined,
                        size: 13,
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
          ),
        ),
      ),
    );
  }

  Widget _imageGrid(List<String> images) {
    final n = images.length;
    if (n == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(R.sm),
        child: CachedNetworkImage(
          imageUrl: images[0],
          height: 180,
          fit: BoxFit.cover,
          memCacheWidth: 900,
        ),
      );
    }
    // ★ 1014 P1 修复：2 图 / 4 图时用 2 列，避免固定 3 列导致右侧空一格
    //   （原先 2 张图排成「两张 + 空白」，4 张图排成「三张 + 一张」，观感错位）
    final cols = (n == 2 || n == 4) ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
      ),
      itemCount: n > 9 ? 9 : n,
      itemBuilder: (context, i) => ClipRRect(
        borderRadius: BorderRadius.circular(R.xs),
        child: CachedNetworkImage(
          imageUrl: images[i],
          fit: BoxFit.cover,
          memCacheWidth: 360,
          placeholder: (_, __) => Container(color: Colors.black12),
          errorWidget: (_, __, ___) => Container(
            color: Colors.black12,
            child: const Icon(Icons.broken_image, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color ?? context.t3),
            const SizedBox(width: 4),
            Text(label, style: Ty.small.copyWith(color: context.t2)),
          ],
        ),
      ),
    );
  }

  Widget _avatar() => Container(
    width: 38,
    height: 38,
    color: C.brand.withAlpha(26),
    child: Icon(Icons.person, size: 20, color: C.brand),
  );

  /// 视频模式选择胶囊
  Widget _videoChip(
    String label,
    String value,
    String cur,
    BuildContext ctx,
    ValueChanged<String> onTap,
  ) {
    final sel = cur == value;
    return AppPressable(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? C.brand : (ctx.isDark ? C.bg3 : C.lbg2),
          borderRadius: BorderRadius.circular(R.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : ctx.t2,
          ),
        ),
      ),
    );
  }

  // ================= 发布 =================
  Future<void> _compose() async {
    if (!UserService.instance.isLoggedIn) {
      final go = await Get.dialog<bool>(
        AppDialog(
          title: const Text('需要登录'),
          content: const Text('发布动态需要先登录账号'),
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
      if (!UserService.instance.isLoggedIn) return;
    }
    final user = UserService.instance.user;
    final contentCtrl = TextEditingController();
    final videoLinkCtrl = TextEditingController();
    final List<String> images = [];
    final List<File> localImages = [];
    // ★ 1014 P1 修复：不再硬编码 cat_id=2。当前在「全部」时，
    //   优先取服务端返回的第一个真实分类；找不到再退回 1，
    //   服务端也会对非法 cat_id 做兜底（见 post_create）。
    final realCats = _cats.where((c) => c.id != 0).toList();
    int catId = _currentCat != 0
        ? _currentCat
        : (realCats.isNotEmpty ? realCats.first.id : 1);
    bool sending = false;
    String err = '';
    bool showEmoji = false;
    // 视频：videoMode = none | local | link
    String videoMode = 'none';
    File? videoFile;
    String videoLink = '';
    String videoPreviewUrl = '';
    String videoPreviewType = '';

    await showGlassSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> pickImage() async {
            try {
              final picker = ImagePicker();
              final files = await picker.pickMultiImage(imageQuality: 82);
              if (files.isEmpty) return;
              for (final f in files) {
                if (images.length >= 9) break;
                localImages.add(File(f.path));
                images.add(f.path);
              }
              if (!ctx.mounted) return;
              setSheet(() {});
            } catch (e) {
              if (!ctx.mounted) return;
              setSheet(() => err = '选择图片失败：请在设置中允许相册权限');
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: ctx.isDark ? C.bg2 : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(R.lg),
              ),
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('发布动态', style: Ty.h3.copyWith(color: ctx.t1)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: ctx.t2),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  // 分类
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cats.where((c) => c.id != 0).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (_, i) {
                        final c = _cats.where((e) => e.id != 0).toList()[i];
                        final sel = catId == c.id;
                        return AppPressable(
                          onTap: () => setSheet(() => catId = c.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel
                                  ? C.brand
                                  : (ctx.isDark ? C.bg3 : C.lbg2),
                              borderRadius: BorderRadius.circular(R.md),
                            ),
                            child: Text(
                              c.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: sel
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: sel ? Colors.white : ctx.t2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 5,
                    maxLength: 2000,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '分享你的想法…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(R.sm),
                      ),
                    ),
                  ),
                  // 已选图片
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (int i = 0; i < images.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.file(
                                  File(images[i]),
                                  width: 74,
                                  height: 74,
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
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                  // ── 视频 ──
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('视频', style: Ty.tiny.copyWith(color: ctx.t3)),
                      const SizedBox(width: 8),
                      _videoChip(
                        '无',
                        'none',
                        videoMode,
                        ctx,
                        (m) => setSheet(() {
                          videoMode = m;
                          videoFile = null;
                          videoLink = '';
                          videoPreviewUrl = '';
                          videoPreviewType = '';
                        }),
                      ),
                      const SizedBox(width: 6),
                      _videoChip(
                        '本地视频',
                        'local',
                        videoMode,
                        ctx,
                        (m) => setSheet(() => videoMode = m),
                      ),
                      const SizedBox(width: 6),
                      _videoChip(
                        '视频链接',
                        'link',
                        videoMode,
                        ctx,
                        (m) => setSheet(() => videoMode = m),
                      ),
                    ],
                  ),
                  if (videoMode == 'local') ...[
                    const SizedBox(height: 8),
                    SoftButton(
                      label: videoFile == null
                          ? '选择本地视频'
                          : '已选：${videoFile!.path.split('/').last}',
                      icon: Icons.video_file_outlined,
                      height: 40,
                      onPressed: () async {
                        try {
                          final picker = ImagePicker();
                          final f = await picker.pickVideo(
                            source: ImageSource.gallery,
                            maxDuration: const Duration(minutes: 5),
                          );
                          if (f == null) return;
                          if (!ctx.mounted) return;
                          setSheet(() {
                            videoFile = File(f.path);
                            videoPreviewUrl = '';
                          });
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setSheet(() => err = '选择视频失败，请允许相册权限');
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '支持 mp4/mov/webm，单个不超过 100MB',
                      style: Ty.tiny.copyWith(color: ctx.t3),
                    ),
                  ],
                  if (videoMode == 'link') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: videoLinkCtrl,
                      decoration: InputDecoration(
                        hintText: '粘贴链接或抖音口令（如 XO3FyvHVKf4）',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(R.sm),
                        ),
                      ),
                      onChanged: (v) => setSheet(() => videoLink = v),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SoftButton(
                          label: '解析预览',
                          icon: Icons.link_rounded,
                          height: 38,
                          onPressed: () async {
                            final u = videoLinkCtrl.text.trim();
                            if (u.isEmpty) {
                              setSheet(() => err = '请先粘贴视频链接');
                              return;
                            }
                            setSheet(() {
                              err = '';
                              videoPreviewUrl = '__loading__';
                            });
                            try {
                              final r = await _svc.parseVideoLink(u);
                              if (!ctx.mounted) return;
                              setSheet(() {
                                videoPreviewUrl = (r['url'] ?? '').toString();
                                videoPreviewType = (r['type'] ?? '').toString();
                              });
                            } catch (e) {
                              final msg = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                              if (!ctx.mounted) return;
                              setSheet(() {
                                videoPreviewUrl = '';
                                err = msg.contains('没有识别到')
                                    ? '没有识别到链接：请粘贴「v.douyin.com/xxx」这类链接，'
                                          '或直接粘贴抖音口令码（10~14 位字母数字）'
                                    : msg;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (videoPreviewUrl == '__loading__')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '解析中…',
                              style: Ty.tiny.copyWith(color: ctx.t3),
                            ),
                          ],
                        ),
                      )
                    else if (videoPreviewUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: PostVideoPlayer(
                          url: videoPreviewUrl,
                          type: videoPreviewType,
                          maxHeight: 240,
                        ),
                      ),
                  ],
                  // 表情面板
                  if (showEmoji)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: EmojiPanel(
                        onPick: (e) {
                          contentCtrl.text += e;
                          contentCtrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: contentCtrl.text.length),
                          );
                          setSheet(() {});
                        },
                      ),
                    ),
                  if (err.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: C.danger.withAlpha(22),
                        borderRadius: BorderRadius.circular(R.sm),
                      ),
                      child: Text(
                        err,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: C.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: pickImage,
                        icon: Icon(Icons.image_outlined, color: ctx.t2),
                        tooltip: '添加图片',
                      ),
                      IconButton(
                        onPressed: () => setSheet(() => showEmoji = !showEmoji),
                        icon: Icon(
                          Icons.emoji_emotions_outlined,
                          color: showEmoji ? C.brand : ctx.t2,
                        ),
                        tooltip: '表情',
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 116,
                        child: PrimaryButton(
                          label: '发布',
                          icon: Icons.send_rounded,
                          loading: sending,
                          height: 44,
                          onPressed: () async {
                            final text = contentCtrl.text.trim();
                            final hasVideo =
                                (videoMode == 'local' && videoFile != null) ||
                                (videoMode == 'link' &&
                                    videoLinkCtrl.text.trim().isNotEmpty);
                            if (text.isEmpty && images.isEmpty && !hasVideo) {
                              setSheet(() => err = '请输入内容、添加图片或视频');
                              return;
                            }
                            setSheet(() {
                              sending = true;
                              err = '';
                            });
                            try {
                              // 先上传本地图片
                              // ★ 1014 P1 修复：按索引「一对一」取 File，
                              //   原先 removeAt(0) 在「删中间图 / 本地图与远程图
                              //   混排」时会与 images 索引错位 → 上传错图或 RangeError。
                              final urls = <String>[];
                              for (int i = 0; i < images.length; i++) {
                                final src = images[i];
                                if (src.startsWith('http')) {
                                  urls.add(src);
                                  continue;
                                }
                                if (i >= localImages.length) {
                                  urls.add(src);
                                  continue;
                                }
                                urls.add(
                                  await PostService.instance.uploadImage(
                                    localImages[i],
                                  ),
                                );
                              }
                              // 视频处理：本地先上传，链接直接交给后端解析
                              String videoUrl = '';
                              String videoKind = '';
                              if (videoMode == 'local' && videoFile != null) {
                                videoUrl = await PostService.instance
                                    .uploadVideo(videoFile!);
                                videoKind = 'local';
                              } else if (videoMode == 'link' &&
                                  videoLinkCtrl.text.trim().isNotEmpty) {
                                videoUrl = videoLinkCtrl.text.trim();
                                videoKind = 'link';
                              }
                              final reviewing = await _svc.create(
                                nickname: user?.nickname ?? '匿名用户',
                                content: text,
                                images: urls,
                                catId: catId,
                                avatar: user?.avatar ?? '',
                                videoUrl: videoUrl,
                                videoType: videoKind,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                // 1013d：开启审核时提示待审
                                _toast(reviewing ? '已提交，审核通过后展示' : '发布成功 🎉');
                                _load(reset: true);
                              }
                            } catch (e) {
                              // ★ 1014 P0：弹窗可能已被用户关闭，须守卫
                              if (!ctx.mounted) return;
                              setSheet(() {
                                sending = false;
                                err = e.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                );
                              });
                            }
                          },
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
