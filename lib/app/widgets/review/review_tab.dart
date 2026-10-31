import 'dart:io';

import '../../utils/err_text.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

import '../../api/review_service.dart';
import '../../api/user_service.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../design/glass.dart';
import '../../models/review_item.dart';
import '../../routes/app_pages.dart';
import 'star_rating.dart';

/// 评价 Tab（评分卡 + 筛选 + 评论列表）
class ReviewTab extends StatefulWidget {
  final int appId;
  const ReviewTab({super.key, required this.appId});

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  final ReviewService _svc = ReviewService.instance;

  ReviewSummary _summary = ReviewSummary.empty();
  List<ReviewItem> _list = [];
  String _filter = 'all';
  String _sort = 'latest';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _svc.summary(widget.appId);
    final l = await _svc.list(widget.appId, filter: _filter, sort: _sort);
    if (!mounted) return;
    setState(() {
      _summary = s;
      _list = l;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // 本组件嵌在外层 ListView 中（高度无约束），给一个固定高度，
      // 避免 Center 在无约束高度下失去居中效果。
      return const SizedBox(height: 180, child: LoadingState(text: '正在加载评价…'));
    }
    // 注意：本组件嵌在外层 ListView 中，必须用 Column（不能用 ListView 嵌套）
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryCard(),
          const SizedBox(height: 16),
          SectionHeader(
            title: '用户评价',
            accent: C.brand,
            action: GestureDetector(
              onTap: _toggleSort,
              child: Row(
                children: [
                  Text(
                    _sort == 'latest' ? '最新' : '最热',
                    style: Ty.small.copyWith(color: context.t2),
                  ),
                  Icon(Icons.swap_vert, size: 15, color: context.t3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _filterRow(),
          const SizedBox(height: 12),
          if (_list.isEmpty)
            const SizedBox(
              height: 240,
              child: EmptyState(
                text: '还没有评价，来写第一条吧',
                hint: '你的评价会帮助更多人',
                icon: Icons.rate_review_outlined,
              ),
            )
          else
            ..._list.map((r) => _reviewTile(r)),
        ],
      ),
    );
  }

  void _toggleSort() {
    setState(() => _sort = _sort == 'latest' ? 'hot' : 'latest');
    _load();
  }

  // ===== 评分卡 =====
  Widget _summaryCard() {
    final total = _summary.count;
    final good = _summary.good;
    final mid = _summary.mid;
    final bad = _summary.bad;
    return KitCard(
      padding: const EdgeInsets.all(16),
      radius: R.md,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧大分数
              Column(
                children: [
                  Text(
                    total > 0 ? _summary.avg.toStringAsFixed(1) : '—',
                    style: Ty.display.copyWith(
                      fontSize: 40,
                      height: 1.0,
                      color: context.t1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  StarRating(score: _summary.avg, size: 13),
                ],
              ),
              const SizedBox(width: 18),
              // 右侧进度条
              Expanded(
                child: Column(
                  children: [
                    _bar(good, total, C.brand),
                    const SizedBox(height: 5),
                    _bar(mid, total, C.amber),
                    const SizedBox(height: 5),
                    _bar(bad, total, C.danger),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // 写评论按钮
              SoftButton(
                label: '写评论',
                icon: Icons.add_circle_outline_rounded,
                height: 34,
                onPressed: _openCompose,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: context.isDark
                ? Colors.white.withAlpha(24)
                : Colors.black.withAlpha(20),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$total 人参与了评分',
                style: Ty.small.copyWith(fontSize: 12, color: context.t2),
              ),
              const SizedBox(width: 14),
              Text(
                '${_summary.goodRate}% 好评率',
                style: Ty.small.copyWith(
                  fontSize: 12,
                  color: C.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(int value, int total, Color color) {
    final ratio = total > 0 ? value / total : 0.0;
    return Row(
      children: [
        Expanded(
          child: KitProgress(value: ratio, color: color, height: 6),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 18,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: Ty.tiny.copyWith(color: context.t2),
          ),
        ),
      ],
    );
  }

  // ===== 筛选 =====
  Widget _filterRow() {
    final items = [
      ('all', '全部', _summary.count),
      ('good', '好评', _summary.good),
      ('mid', '中评', _summary.mid),
      ('bad', '差评', _summary.bad),
    ];
    return Row(
      children: items.map((e) {
        final sel = _filter == e.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              if (_filter == e.$1) return;
              setState(() => _filter = e.$1);
              _load();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? C.brand
                    : (context.isDark
                          ? Colors.white.withAlpha(22)
                          : Colors.black.withAlpha(16)),
                borderRadius: BorderRadius.circular(R.full),
              ),
              child: Text(
                '${e.$2}${e.$3 > 0 ? ' ${e.$3}' : ''}',
                style: Ty.small.copyWith(
                  fontSize: 12.5,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                  color: sel ? Colors.white : context.t2,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===== 单条评价 =====
  Widget _reviewTile(ReviewItem r) {
    final myId = UserService.instance.user?.id ?? 0;
    final isAdmin = UserService.instance.user?.isAdmin == true;
    final canDelete = r.userId == myId || isAdmin;
    return KitCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      radius: R.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: r.avatar.isNotEmpty
                    ? CachedNetworkImage(
                          memCacheWidth: 108,
                        imageUrl: r.avatar,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        color: C.brand.withAlpha(26),
                        child: Icon(Icons.person, size: 19, color: C.brand),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.nickname.isEmpty ? '匿名用户' : r.nickname,
                      style: Ty.small.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        StarRating(score: r.score.toDouble(), size: 12.5),
                        const SizedBox(width: 6),
                        Text(
                          '${r.score}.0',
                          style: Ty.tiny.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: C.amber,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          r.levelText,
                          style: Ty.tiny.copyWith(
                            fontSize: 11.5,
                            color: r.level == 'good'
                                ? C.success
                                : (r.level == 'mid' ? C.warning : C.danger),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.content,
              style: Ty.body.copyWith(
                fontSize: 14,
                height: 1.6,
                color: context.t1,
              ),
            ),
          ],
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: r.images
                  .map(
                    (u) => GestureDetector(
                      onTap: () => _preview(u),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(R.xs),
                        child: CachedNetworkImage(
                                   memCacheWidth: 228,
                          imageUrl: u,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(width: 76, color: Colors.black12),
                          errorWidget: (_, __, ___) => Container(
                            width: 76,
                            height: 76,
                            color: Colors.black12,
                            child: const Icon(Icons.broken_image, size: 18),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          // ===== 回复列表 =====
          if (r.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
              decoration: BoxDecoration(
                color: context.isDark ? C.bg1 : C.lbg2,
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: r.replies
                    .map(
                      (rp) => GestureDetector(
                        onLongPress: () => _replyActions(rp),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: RichText(
                            text: TextSpan(
                              style: Ty.small.copyWith(
                                fontSize: 12.5,
                                height: 1.55,
                                color: context.t2,
                              ),
                              children: [
                                TextSpan(
                                  text: rp.nickname,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: C.brand,
                                  ),
                                ),
                                if (rp.replyTo.isNotEmpty)
                                  TextSpan(
                                    text: ' 回复 ${rp.replyTo}',
                                    style: Ty.tiny.copyWith(
                                      color: context.t3,
                                      fontSize: 12,
                                    ),
                                  ),
                                TextSpan(text: '：${rp.content}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                r.timeText,
                style: Ty.tiny.copyWith(fontSize: 11.5, color: context.t3),
              ),
              const SizedBox(width: 16),
              _miniBtn('回复', () => _openReply(r)),
              if (canDelete) ...[
                const SizedBox(width: 12),
                _miniBtn('删除', () async {
                  final ok = await _svc.remove(r.id);
                  if (ok) {
                    _load();
                    _toast('已删除');
                  } else {
                    _toast('删除失败');
                  }
                }, color: C.danger),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final n = await _svc.like(r.id);
                  if (n != null) setState(() => _load());
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 15,
                      color: context.t3,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${r.likeCount}',
                      style: Ty.tiny.copyWith(
                        fontSize: 11.5,
                        color: context.t2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap, {Color? color}) =>
      GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: Ty.tiny.copyWith(
            fontSize: 11.5,
            color: color ?? context.t2,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  /// 回复操作（长按删除）
  Future<void> _replyActions(ReviewReply rp) async {
    final myId = UserService.instance.user?.id ?? 0;
    final isAdmin = UserService.instance.user?.isAdmin == true;
    if (rp.userId != myId && !isAdmin) return;
    final ok = await Get.dialog<bool>(
      AppDialog(
        title: const Text('删除回复'),
        content: Text('确定删除这条回复吗？\n「${rp.content}」'),
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
    final done = await _svc.removeReply(rp.id);
    if (done) {
      _toast('已删除');
      _load();
    } else {
      _toast('删除失败');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ===== 回复弹窗 =====
  Future<void> _openReply(ReviewItem r) async {
    if (!UserService.instance.isLoggedIn) {
      final go = await Get.dialog<bool>(
        AppDialog(
          title: const Text('需要登录'),
          content: const Text('回复需要先登录账号'),
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
    final ctrl = TextEditingController();
    bool sending = false;
    String err = '';
    await showGlassDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AppDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.md),
            ),
            title: Text(
              '回复 ${r.nickname}',
              style: Ty.h3.copyWith(fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  maxLength: 500,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '写下你的回复…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.sm),
                    ),
                  ),
                ),
                if (err.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      err,
                      style: Ty.tiny.copyWith(fontSize: 12, color: C.danger),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.brand),
                onPressed: sending
                    ? null
                    : () async {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) {
                          setD(() => err = '请输入回复内容');
                          return;
                        }
                        setD(() {
                          sending = true;
                          err = '';
                        });
                        try {
                          await _svc.reply(
                            reviewId: r.id,
                            content: text,
                            replyTo: '',
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _toast('回复成功');
                          _load();
                        } catch (e) {
                          setD(() {
                            sending = false;
                            err = ErrText.of(e);
                          });
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('发送'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== 写评论弹窗 =====
  Future<void> _openCompose() async {
    if (!UserService.instance.isLoggedIn) {
      final go = await Get.dialog<bool>(
        AppDialog(
          title: const Text('需要登录'),
          content: const Text('评价软件需要先登录账号'),
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

    int score = 5;
    final ctrl = TextEditingController();
    final images = <String>[];
    final files = <File>[];
    bool sending = false;
    String err = '';

    await showGlassDialog(
      context: context,
      barrierDismissible: false,
      // ★ 1028：内容自带贴底面壳，外层不要再加玻璃壳（原来是两层底 + 上下留白）
      bare: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          const emojis = [
            '😀',
            '😄',
            '😊',
            '😍',
            '🤩',
            '😎',
            '👍',
            '🔥',
            '💯',
            '🎉',
            '❤️',
            '🙏',
            '😅',
            '🤔',
            '😭',
            '😡',
          ];
          const scoreText = ['很差', '较差', '一般', '满意', '超赞'];

          Future<void> pick() async {
            try {
              final picked = await ImagePicker().pickMultiImage(
                imageQuality: 82,
              );
              if (picked.isEmpty) return;
              for (final f in picked) {
                if (images.length >= 6) break;
                files.add(File(f.path));
                images.add(f.path);
              }
              setD(() {});
            } catch (e) {
              setD(() => err = '选择图片失败，请允许相册权限');
            }
          }

          return BottomPanel(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 标题行 ──
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 15,
                            decoration: BoxDecoration(
                              gradient: C.brandGradient,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '写评论',
                            style: Ty.h3.copyWith(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: sending ? null : () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? Colors.white.withAlpha(20)
                                    : Colors.black.withAlpha(10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: context.t2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── 评分 ──
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: C.brand.withAlpha(context.isDark ? 34 : 15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '综合评分',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  scoreText[score - 1],
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: C.brand,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            StarInput(
                              value: score,
                              size: 26,
                              onChanged: (v) => setD(() => score = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── 输入框 ──
                      Container(
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? Colors.white.withAlpha(12)
                              : C.lbg2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.isDark
                                ? Colors.white.withAlpha(16)
                                : Colors.black.withAlpha(8),
                            width: 0.8,
                          ),
                        ),
                        child: TextField(
                          controller: ctrl,
                          maxLines: 4,
                          minLines: 4,
                          maxLength: 500,
                          style: const TextStyle(fontSize: 14.5, height: 1.5),
                          decoration: InputDecoration(
                            hintText: '说说这个软件用起来怎么样…',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: context.t3,
                            ),
                            border: InputBorder.none,
                            counterStyle: TextStyle(
                              fontSize: 10.5,
                              color: context.t3,
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(
                              14,
                              12,
                              14,
                              4,
                            ),
                          ),
                          onChanged: (_) => setD(() {}),
                        ),
                      ),

                      // ── 已选图片 ──
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int i = 0; i < images.length; i++)
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(images[i]),
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: -5,
                                    top: -5,
                                    child: GestureDetector(
                                      onTap: () => setD(() {
                                        images.removeAt(i);
                                        files.removeAt(i);
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.all(2.5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(150),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.isDark
                                                ? C.bg2
                                                : Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 11,
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

                      const SizedBox(height: 10),
                      Text(
                        '选择表情',
                        style: Ty.small.copyWith(
                          fontSize: 12,
                          color: context.t3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 表情横向滚动，不再挤成两排
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: emojis.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 2),
                          itemBuilder: (_, i) => InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              ctrl.text += emojis[i];
                              setD(() {});
                            },
                            child: Container(
                              width: 34,
                              alignment: Alignment.center,
                              child: Text(
                                emojis[i],
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (err.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 13,
                              color: C.danger,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                err,
                                style: Ty.tiny.copyWith(
                                  fontSize: 12,
                                  color: C.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),
                      Row(
                        children: [
                          SoftButton(
                            label: '图片',
                            icon: Icons.image_outlined,
                            height: 46,
                            onPressed: sending ? null : pick,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: '发布评论',
                              height: 46,
                              loading: sending,
                              onPressed: sending
                                  ? null
                                  : () async {
                                      final content = ctrl.text.trim();
                                      if (content.isEmpty && images.isEmpty) {
                                        setD(() => err = '请输入评论内容或添加图片');
                                        return;
                                      }
                                      setD(() {
                                        sending = true;
                                        err = '';
                                      });
                                      try {
                                        final urls = <String>[];
                                        for (final f
                                            in List<File>.from(files)) {
                                          urls.add(await _svc.uploadImage(f));
                                        }
                                        await _svc.create(
                                          appId: widget.appId,
                                          score: score,
                                          content: content,
                                          images: urls,
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        _toast('评论成功 ✅');
                                        _load();
                                      } catch (e) {
                                        setD(() {
                                          sending = false;
                                          err = ErrText.of(e);
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
