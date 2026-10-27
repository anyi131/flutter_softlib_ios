import 'dart:io';

import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';
import 'wish_admin_view.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../api/post_service.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../design/glass.dart';
import '../../../utils/app_action.dart';
import '../../../utils/toast_util.dart';

/// 内容管理：动态 / 评价 / 协议配置
class AdminContentTab extends StatefulWidget {
  const AdminContentTab({super.key});

  @override
  State<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends State<AdminContentTab>
    with SingleTickerProviderStateMixin {
  final _svc = AdminService.instance;
  late final TabController _tab = TabController(length: 11, vsync: this);

  List<Map<String, dynamic>> _posts = [];
  int _pendingCount = 0;
  bool _reviewOn = false;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _carousels = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _referrals = [];
  List<Map<String, dynamic>> _versions = [];
  List<Map<String, dynamic>> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _svc.posts();
      // ★ 动态审核（1013d）：走审核列表接口，带 status / counts；
      //   失败则回落旧的 posts()（旧服务端没有 status 字段）
      List<Map<String, dynamic>> posts;
      int pending = 0;
      try {
        final rd = await _svc.postReviewList();
        posts = (rd['list'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final counts = Map<String, dynamic>.from(rd['counts'] ?? {});
        pending = (counts['pending'] as num?)?.toInt() ?? 0;
      } catch (_) {
        posts = p;
      }
      bool reviewOn = false;
      try {
        final cfg = await _svc.config();
        reviewOn = '${cfg['post_review_on'] ?? '0'}' == '1';
      } catch (_) {}
      final r = await _svc.reviews();
      final ct = await _svc.appCats();
      final ca = await _svc.carousels();
      final rp = await _svc.reports();
      final cd = await _svc.cards();
      final rf = await _svc.referrals();
      final vs = await _svc.versions();
      final sc = await _svc.sources();
      // 工具（v43 #5）
      try {} catch (_) {}
      if (mounted)
        setState(() {
          _posts = posts;
          _pendingCount = pending;
          _reviewOn = reviewOn;
          _reviews = r;
          _cats = ct;
          _carousels = ca;
          _reports = rp;
          _cards = cd;
          _referrals = rf;
          _versions = vs;
          _sources = sc;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          indicatorColor: C.brand,
          labelColor: C.brand,
          unselectedLabelColor: context.t3,
          labelStyle: Ty.small.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          dividerColor: Colors.transparent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: '动态 ${_posts.length}'),
            Tab(text: '评价 ${_reviews.length}'),
            Tab(text: '分类 ${_cats.length}'),
            Tab(text: '轮播 ${_carousels.length}'),
            Tab(text: '线报 ${_reports.length}'),
            Tab(text: '数据源 ${_sources.length}'),
            Tab(text: '推荐 ${_referrals.length}'),
            Tab(text: '版本 ${_versions.length}'),
            Tab(text: '卡密 ${_cards.length}'),
            const Tab(text: '需求'),
            const Tab(text: '配置'),
          ],
        ),
        Expanded(
          child: _loading
              ? const LoadingState(text: '加载内容数据…')
              : TabBarView(
                  controller: _tab,
                  children: [
                    _postList(),
                    _reviewList(),
                    _catList(),
                    _carouselList(),
                    _reportList(),
                    _sourceList(context),
                    _referralList(),
                    _versionList(),
                    _cardList(),
                    // ★ 1020：需求投票（原来是塞在采集 Tab 里的，不属于采集）
                    const WishAdminView(),
                    _configList(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _postList() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ★ 动态审核卡（1013d）：开关 + 待审数
        AdCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.fact_check_rounded, size: 18, color: C.brand),
              const SizedBox(width: 8),
              Text(
                '动态发布审核',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: C.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '待审 $_pendingCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: C.warning,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Switch(
                value: _reviewOn,
                activeColor: C.brand,
                onChanged: (v) async {
                  setState(() => _reviewOn = v);
                  try {
                    await _svc.postReviewSave(on: v);
                    ToastUtil.success(v ? '已开启审核' : '已关闭审核');
                  } catch (e) {
                    setState(() => _reviewOn = !v);
                    ToastUtil.error(ErrText.of(e));
                  }
                },
              ),
            ],
          ),
        ),
        ..._postCards(),
      ],
    );
  }

  List<Widget> _postCards() {
    if (_posts.isEmpty) {
      return [const EmptyState(text: '暂无动态', hint: '用户发布的动态会显示在这里')];
    }
    return _posts.map((p) {
      final imgs = (p['images'] is List) ? (p['images'] as List) : [];
      final status = int.tryParse('${p['status'] ?? 1}') ?? 1;
      final pending = status == 0;
      final rejected = status == 2;
      return AdCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${p['nickname']}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                if (pending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: C.warning.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '待审核',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: C.warning,
                      ),
                    ),
                  )
                else if (rejected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: C.danger.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '已驳回',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: C.danger,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  '${p['createtime_text']}',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '编辑内容',
                  icon: Icon(Icons.edit_outlined, size: 18, color: C.brand),
                  onPressed: () => _editPost(p),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: C.danger,
                  ),
                  onPressed: () async {
                    await AppAction.act(
                      () => _svc.deletePost(int.tryParse('${p['id']}') ?? 0),
                      loading: '删除中…',
                      success: '已删除',
                    );
                    _load();
                  },
                ),
              ],
            ),
            if ('${p['content']}'.isNotEmpty)
              Text(
                '${p['content']}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
            if (imgs.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imgs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, j) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: '${imgs[j]}',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '赞 ${p['like_count']} · 评论 ${p['comment_count']} · 浏览 ${p['views']}',
                    style: Ty.tiny.copyWith(color: context.t3),
                  ),
                ),
                if (pending) ...[
                  _reviewBtn(
                    '通过',
                    Icons.check_rounded,
                    C.success,
                    () => _doReview(p, 'pass'),
                  ),
                  const SizedBox(width: 8),
                  _reviewBtn(
                    '驳回',
                    Icons.close_rounded,
                    C.danger,
                    () => _doReview(p, 'reject'),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _reviewBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 审核操作（驳回需二次确认）
  Future<void> _doReview(Map p, String action) async {
    final id = int.tryParse('${p['id']}') ?? 0;
    if (id <= 0) return;
    if (action == 'reject') {
      final go = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('驳回动态'),
          content: Text('驳回后该动态将不在广场展示（作者自己仍可见）。确定驳回「${p['nickname']}」的这条动态吗？'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.danger),
              onPressed: () => Get.back(result: true),
              child: const Text('驳回'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    try {
      await _svc.postReview([id], action: action);
      ToastUtil.success(action == 'pass' ? '已通过' : '已驳回');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// 编辑帖子（正文 / 图片 / 视频）—— 对应需求 #11
  Future<void> _editPost(Map p) async {
    final content = TextEditingController(text: '${p['content'] ?? ''}');
    final videoUrl = TextEditingController(text: '${p['video_url'] ?? ''}');
    final videoCover = TextEditingController(text: '${p['video_cover'] ?? ''}');
    // 图片：可能是 List 或逗号串
    final rawImgs = p['images'];
    final imgList = rawImgs is List
        ? rawImgs.map((e) => '$e').toList()
        : '${rawImgs ?? ''}'
              .split(',')
              .where((s) => s.trim().isNotEmpty)
              .toList();
    final images = TextEditingController(text: imgList.join('\n'));
    String videoType = '${p['video_type'] ?? 'file'}';

    await showGlassDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 30,
            ),
            title: const Text('编辑动态'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: content,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '正文内容',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: images,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '图片地址（每行一个，可留空）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: videoType,
                      decoration: const InputDecoration(
                        labelText: '视频类型',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'file',
                          child: Text('直链视频 (mp4)'),
                        ),
                        DropdownMenuItem(
                          value: 'iframe',
                          child: Text('网页嵌入 (iframe)'),
                        ),
                      ],
                      onChanged: (v) => setD(() => videoType = v ?? 'file'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: videoUrl,
                      decoration: const InputDecoration(
                        labelText: '视频地址（留空=无视频）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: videoCover,
                      decoration: const InputDecoration(
                        labelText: '视频封面（选填）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  if (content.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final imgs = images.text
                      .split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .join(',');
                  try {
                    await _svc.savePost({
                      'id': p['id'],
                      'content': content.text.trim(),
                      'cat_id': p['cat_id'] ?? 0,
                      'images': imgs,
                      'video_url': videoUrl.text.trim(),
                      'video_type': videoType,
                      'video_cover': videoCover.text.trim(),
                    });
                    ToastUtil.success('已保存');
                    _load();
                  } catch (e) {
                    ToastUtil.error(ErrText.of(e));
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reviewList() {
    if (_reviews.isEmpty) {
      return const EmptyState(text: '暂无评价', icon: Icons.rate_review_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _reviews.length,
      itemBuilder: (context, i) {
        final r = _reviews[i];
        return AdCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${r['nickname']}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(
                      5,
                      (j) => Icon(
                        j < (int.tryParse('${r['score']}') ?? 0)
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 13,
                        color: C.amber,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: C.danger,
                    ),
                    onPressed: () async {
                      await AppAction.act(
                        () =>
                            _svc.deleteReview(int.tryParse('${r['id']}') ?? 0),
                        loading: '删除中…',
                        success: '已删除',
                      );
                      _load();
                    },
                  ),
                ],
              ),
              Text(
                '${r['content']}',
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                '软件ID ${r['app_id']} · ${r['createtime_text']}',
                style: Ty.tiny.copyWith(color: context.t3),
              ),
            ],
          ),
        );
      },
    );
  }

  // ───── 分类管理 ─────
  Widget _catList() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        PrimaryButton(
          label: '新增分类',
          icon: Icons.add,
          height: 46,
          onPressed: () => _editCat(null),
        ),

        const SizedBox(height: 12),
        for (final c in _cats)
          AdCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c['title']}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c['count'] ?? 0} 个软件 · 权重 ${c['weigh'] ?? 0}',
                        style: Ty.tiny.copyWith(color: context.t3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  onPressed: () => _editCat(c),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: C.danger,
                  ),
                  onPressed: () async {
                    await AppAction.act(
                      () => _svc.deleteCat(int.tryParse('${c['id']}') ?? 0),
                      loading: '删除中…',
                      success: '已删除',
                    );
                    _load();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _editCat(Map? c) async {
    final nameCtrl = TextEditingController(text: '${c?['title'] ?? ''}');
    final weighCtrl = TextEditingController(text: '${c?['weigh'] ?? 0}');
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(c == null ? '新增分类' : '编辑分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '分类名称'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: weighCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '权重（越大越靠前）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.saveCat({
        'id': c?['id'] ?? 0,
        'title': nameCtrl.text.trim(),
        'weigh': int.tryParse(weighCtrl.text) ?? 0,
      });
      ToastUtil.success('保存成功');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  // ───── 轮播图 ─────
  Widget _carouselList() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        PrimaryButton(
          label: '新增轮播图',
          icon: Icons.add,
          height: 46,
          onPressed: () => _editCarousel(null),
        ),

        const SizedBox(height: 12),
        for (final c in _carousels)
          AdCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: '${c['image']}',
                    width: 60,
                    height: 42,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(width: 60, height: 42, color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${c['title']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  onPressed: () => _editCarousel(c),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: C.danger,
                  ),
                  onPressed: () async {
                    await AppAction.act(
                      () =>
                          _svc.deleteCarousel(int.tryParse('${c['id']}') ?? 0),
                      loading: '删除中…',
                      success: '已删除',
                    );
                    _load();
                  },
                ),
              ],
            ),
          ),
        if (_carousels.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                '暂无轮播图，可在网页后台添加',
                style: Ty.small.copyWith(color: context.t3),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editCarousel(Map? c) async {
    final titleCtrl = TextEditingController(text: '${c?['title'] ?? ''}');
    final imgCtrl = TextEditingController(text: '${c?['image'] ?? ''}');
    final urlCtrl = TextEditingController(text: '${c?['url'] ?? ''}');
    final weighCtrl = TextEditingController(text: '${c?['weigh'] ?? 0}');
    String type = '${c?['type'] ?? 'no'}';
    bool uploading = false;
    String err = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.md),
            ),
            title: Text(c == null ? '新增轮播图' : '编辑轮播图'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: '标题'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imgCtrl,
                          decoration: const InputDecoration(
                            labelText: '图片 URL',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '上传图片',
                        icon: uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined, size: 21),
                        onPressed: uploading
                            ? null
                            : () async {
                                try {
                                  final p = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (p == null) return;
                                  setD(() => uploading = true);
                                  final url = await _svc.uploadImage(
                                    File(p.path),
                                  );
                                  setD(() {
                                    imgCtrl.text = url;
                                    uploading = false;
                                  });
                                } catch (e) {
                                  setD(() {
                                    uploading = false;
                                    err = '上传失败';
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: '点击行为'),
                    items: const [
                      DropdownMenuItem(value: 'no', child: Text('不跳转')),
                      DropdownMenuItem(value: 'url', child: Text('跳转网址')),
                    ],
                    onChanged: (v) => setD(() => type = v ?? 'no'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(labelText: '跳转网址'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weighCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '权重'),
                  ),
                  if (err.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        err,
                        style: const TextStyle(fontSize: 12, color: C.danger),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await _svc.saveCarousel({
        'id': c?['id'] ?? 0,
        'title': titleCtrl.text.trim(),
        'image': imgCtrl.text.trim(),
        'type': type,
        'url': urlCtrl.text.trim(),
        'weigh': int.tryParse(weighCtrl.text) ?? 0,
        'enable_switch': 1,
      });
      ToastUtil.success('保存成功');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  // ───── 线报 ─────
  Widget _reportList() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        PrimaryButton(
          label: '新增线报文章',
          icon: Icons.add,
          height: 46,
          onPressed: () => _editReport(null),
        ),

        const SizedBox(height: 12),
        if (_reports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                '暂无线报文章',
                style: Ty.small.copyWith(color: context.t3),
              ),
            ),
          )
        else
          ..._reports.map((r) => _reportTile(r)),
      ],
    );
  }

  Widget _reportTile(Map r) {
    return AdCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['title']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '浏览 ${r['views']}',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 19),
            onPressed: () => _editReport(r),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 19, color: C.danger),
            onPressed: () async {
              await AppAction.act(
                () => _svc.deleteReport(int.tryParse('${r['id']}') ?? 0),
                loading: '删除中…',
                success: '已删除',
              );
              _load();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editReport(Map? r) async {
    // 编辑时先拉取完整正文
    Map<String, dynamic> full = {};
    if (r != null) {
      try {
        full = await _svc.reportDetail(int.tryParse('${r['id']}') ?? 0);
      } catch (_) {}
    }
    final titleCtrl = TextEditingController(
      text: '${full['title'] ?? r?['title'] ?? ''}',
    );
    final contentCtrl = TextEditingController(text: '${full['content'] ?? ''}');
    final imgCtrl = TextEditingController(text: '${full['image'] ?? ''}');
    bool uploading = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.md),
            ),
            title: Text(r == null ? '新增线报' : '编辑线报'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: '文章标题'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imgCtrl,
                            decoration: const InputDecoration(
                              labelText: '封面图 URL',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.image_outlined, size: 21),
                          onPressed: uploading
                              ? null
                              : () async {
                                  try {
                                    final p = await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 85,
                                    );
                                    if (p == null) return;
                                    setD(() => uploading = true);
                                    final url = await _svc.uploadImage(
                                      File(p.path),
                                    );
                                    setD(() {
                                      imgCtrl.text = url;
                                      uploading = false;
                                    });
                                  } catch (_) {
                                    setD(() => uploading = false);
                                  }
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: '正文内容(支持 HTML)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: Text(r == null ? '发布' : '保存'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await _svc.saveReport({
        'id': r?['id'] ?? 0,
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text,
        'image': imgCtrl.text.trim(),
      });
      ToastUtil.success('已保存');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  // ───── 数据源管理（蓝奏云文件夹）─────
  Widget _sourceList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(context.isDark ? 34 : 18),
            borderRadius: BorderRadius.circular(R.sm),
          ),
          child: Text(
            '添加蓝奏云文件夹链接后，App 软件库会多出一个分类，点击实时解析文件夹里的软件。',
            style: Ty.small.copyWith(color: C.brand, height: 1.5),
          ),
        ),
        PrimaryButton(
          label: '添加蓝奏云文件夹',
          icon: Icons.add,
          height: 46,
          onPressed: () => _editSource(null),
        ),

        const SizedBox(height: 12),
        for (final s in _sources)
          AdCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: C.cyan.withAlpha(context.isDark ? 44 : 28),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.cloud_outlined,
                    size: 18,
                    color: C.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s['name']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s['url']}'
                        '${(s['sync_count'] ?? 0) > 0 ? '  ·  已同步 ${s['sync_count']} 条' : '  ·  未同步'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ty.tiny.copyWith(color: context.t3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '同步文件夹内容',
                  icon: const Icon(
                    Icons.sync_rounded,
                    size: 19,
                    color: C.success,
                  ),
                  onPressed: () => _syncSource(s),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  onPressed: () => _editSource(s),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: C.danger,
                  ),
                  onPressed: () async {
                    await AppAction.act(
                      () => _svc.deleteSource(int.tryParse('${s['id']}') ?? 0),
                      loading: '删除中…',
                      success: '已删除',
                    );
                    _load();
                  },
                ),
              ],
            ),
          ),
        if (_sources.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text('暂无数据源', style: Ty.small.copyWith(color: context.t3)),
            ),
          ),
      ],
    );
  }

  Future<void> _editSource(Map? s) async {
    final nameCtrl = TextEditingController(text: '${s?['name'] ?? ''}');
    final urlCtrl = TextEditingController(text: '${s?['url'] ?? ''}');
    final pwdCtrl = TextEditingController(text: '${s?['pwd'] ?? ''}');
    final weighCtrl = TextEditingController(text: '${s?['weigh'] ?? 0}');
    final descCtrl = TextEditingController(text: '${s?['default_desc'] ?? ''}');
    final shotsCtrl = TextEditingController(
      text: '${s?['default_shots'] ?? ''}',
    );
    bool testing = false;
    String testMsg = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.md),
            ),
            title: Text(s == null ? '添加数据源' : '编辑数据源'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '分类名称',
                      hintText: '如：开车软件',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: '蓝奏云文件夹链接',
                      hintText: 'https://xxx.lanzouw.com/bXXXX',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pwdCtrl,
                    decoration: const InputDecoration(labelText: '访问密码(选填)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weighCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '排序权重'),
                  ),
                  const SizedBox(height: 10),
                  // 统一描述（文件夹内所有软件共用）
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '统一软件介绍',
                      helperText: '文件夹里的软件都会显示这段介绍',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 统一截图
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: shotsCtrl,
                          decoration: const InputDecoration(
                            labelText: '统一截图 URL(逗号分隔)',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '上传截图',
                        icon: const Icon(Icons.collections_outlined, size: 21),
                        onPressed: () async {
                          try {
                            final picked = await ImagePicker().pickMultiImage(
                              imageQuality: 80,
                            );
                            if (picked.isEmpty) return;
                            final urls = <String>[];
                            for (final f in picked) {
                              urls.add(await _svc.uploadImage(File(f.path)));
                            }
                            final cur = shotsCtrl.text.trim();
                            shotsCtrl.text = cur.isEmpty
                                ? urls.join(',')
                                : '$cur,${urls.join(',')}';
                            setD(() {});
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: testing
                          ? null
                          : () async {
                              setD(() {
                                testing = true;
                                testMsg = '';
                              });
                              try {
                                final list = await PostService.instance
                                    .fetchFolderForTest(urlCtrl.text.trim());
                                setD(() {
                                  testing = false;
                                  testMsg = '✅ 解析成功，共 $list 个软件';
                                });
                              } catch (e) {
                                setD(() {
                                  testing = false;
                                  testMsg =
                                      '❌ ' +
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      );
                                });
                              }
                            },
                      icon: testing
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find, size: 17),
                      label: const Text('测试解析'),
                    ),
                  ),
                  if (testMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        testMsg,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await _svc.saveSource({
        'id': s?['id'] ?? 0,
        'name': nameCtrl.text.trim(),
        'url': urlCtrl.text.trim(),
        'pwd': pwdCtrl.text.trim(),
        'weigh': int.tryParse(weighCtrl.text) ?? 0,
        'is_dir': 1,
        'enable_switch': 1,
        'default_desc': descCtrl.text.trim(),
        'default_shots': shotsCtrl.text.trim(),
      });
      ToastUtil.success('保存成功');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// 同步数据源（自动分批续传）
  Future<void> _syncSource(Map s) async {
    final id = int.tryParse('${s['id']}') ?? 0;
    if (id <= 0) return;

    // 询问起止页
    final ctrl = TextEditingController(
      text: '${(int.tryParse('${s['sync_count']}') ?? 0) > 0 ? 1 : 1}',
    );
    final pagesCtrl = TextEditingController(text: '10');
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.md),
        ),
        title: const Text('同步文件夹'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '蓝奏云有频率限制，建议每次同步 10 页（500 条），'
              '若提示限流请等待 1-2 分钟后再次同步（已同步的会保留）。',
              style: Ty.small.copyWith(color: context.t2, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '起始页'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pagesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '本批页数'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('开始同步'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    ToastUtil.info('正在同步，请稍候…');
    try {
      final d = await _svc.syncSource(
        id,
        fromPage: int.tryParse(ctrl.text) ?? 1,
        pages: int.tryParse(pagesCtrl.text) ?? 10,
      );
      if (d['throttled'] == true) {
        ToastUtil.error(
          '蓝奏云限流中，请等待 1-2 分钟后重试'
          '（已保留 ${d['total']} 条）',
        );
      } else {
        final next = (d['last_page'] ?? 0) as int;
        final more = d['has_more'] == true;
        ToastUtil.success(
          '已同步 ${d['total']} 条'
          '${more ? '，可继续从第 ${next + 1} 页同步' : ''}',
        );
      }
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  // ───── 首页推荐位 ─────
  Widget _referralList() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        PrimaryButton(
          label: '新增推荐位',
          icon: Icons.add,
          height: 46,
          onPressed: () => _editReferral(null),
        ),

        const SizedBox(height: 12),
        for (final r in _referrals)
          AdCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: '${r['image']}',
                    width: 60,
                    height: 42,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(width: 60, height: 42, color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${r['title']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  onPressed: () => _editReferral(r),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: C.danger,
                  ),
                  onPressed: () async {
                    await AppAction.act(
                      () =>
                          _svc.deleteReferral(int.tryParse('${r['id']}') ?? 0),
                      loading: '删除中…',
                      success: '已删除',
                    );
                    _load();
                  },
                ),
              ],
            ),
          ),
        if (_referrals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text('暂无推荐位', style: Ty.small.copyWith(color: context.t3)),
            ),
          ),
      ],
    );
  }

  Future<void> _editReferral(Map? r) async {
    final titleCtrl = TextEditingController(text: '${r?['title'] ?? ''}');
    final contentCtrl = TextEditingController(text: '${r?['content'] ?? ''}');
    final imgCtrl = TextEditingController(text: '${r?['image'] ?? ''}');
    final urlCtrl = TextEditingController(text: '${r?['url'] ?? ''}');
    String type = '${r?['type'] ?? 'no'}';
    bool uploading = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.md),
            ),
            title: Text(r == null ? '新增推荐位' : '编辑推荐位'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: '标题'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '简介'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imgCtrl,
                          decoration: const InputDecoration(
                            labelText: '封面图 URL',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined, size: 21),
                        onPressed: uploading
                            ? null
                            : () async {
                                try {
                                  final p = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (p == null) return;
                                  setD(() => uploading = true);
                                  final url = await _svc.uploadImage(
                                    File(p.path),
                                  );
                                  setD(() {
                                    imgCtrl.text = url;
                                    uploading = false;
                                  });
                                } catch (_) {
                                  setD(() => uploading = false);
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: '点击行为'),
                    items: const [
                      DropdownMenuItem(value: 'no', child: Text('不跳转')),
                      DropdownMenuItem(value: 'url', child: Text('跳转网址')),
                    ],
                    onChanged: (v) => setD(() => type = v ?? 'no'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(labelText: '跳转网址'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await _svc.saveReferral({
        'id': r?['id'] ?? 0,
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'image': imgCtrl.text.trim(),
        'type': type,
        'url': urlCtrl.text.trim(),
        'switch': 1,
      });
      ToastUtil.success('保存成功');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  // ───── 版本更新管理 ─────
  Widget _versionList() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(context.isDark ? 34 : 18),
            borderRadius: BorderRadius.circular(R.sm),
          ),
          child: Text(
            '提示：版本号需大于 App 当前版本才会提示更新。如当前是 1.0.0，填 v1.1.0 即可触发。',
            style: Ty.small.copyWith(color: C.brand, height: 1.5),
          ),
        ),
        PrimaryButton(
          label: '发布新版本',
          icon: Icons.add,
          height: 46,
          onPressed: () => _editVersion(null),
        ),

        const SizedBox(height: 12),
        for (final v in _versions)
          AdCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${v['version']}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if ('${v['forced_switch']}' == '1')
                            const Pill('强制更新', color: C.danger, small: true),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${v['title'] ?? ''} · ${v['createtime_text'] ?? ''}',
                        style: Ty.tiny.copyWith(color: context.t3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  onPressed: () => _editVersion(v),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: C.danger,
                  ),
                  onPressed: () async {
                    await AppAction.act(
                      () => _svc.deleteVersion(int.tryParse('${v['id']}') ?? 0),
                      loading: '删除中…',
                      success: '已删除',
                    );
                    _load();
                  },
                ),
              ],
            ),
          ),
        if (_versions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                '暂无版本记录',
                style: Ty.small.copyWith(color: context.t3),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editVersion(Map? v) async {
    final verCtrl = TextEditingController(text: '${v?['version'] ?? ''}');
    final titleCtrl = TextEditingController(text: '${v?['title'] ?? ''}');
    final contentCtrl = TextEditingController(text: '${v?['content'] ?? ''}');
    final urlCtrl = TextEditingController(text: '${v?['dow_url'] ?? ''}');
    bool forced = '${v?['forced_switch'] ?? 0}' == '1';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.md),
            ),
            title: Text(v == null ? '发布新版本' : '编辑版本'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: verCtrl,
                    decoration: const InputDecoration(
                      labelText: '版本号',
                      hintText: '如 v1.1.0',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: '版本标题'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '更新说明(支持 HTML)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(labelText: '下载地址'),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('强制更新', style: TextStyle(fontSize: 13.5)),
                      ),
                      Switch(
                        value: forced,
                        activeThumbColor: C.brand,
                        onChanged: (x) => setD(() => forced = x),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('发布'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await _svc.saveVersion({
        'id': v?['id'] ?? 0,
        'version': verCtrl.text.trim(),
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'dow_url': urlCtrl.text.trim(),
        'forced_switch': forced ? 1 : 0,
        'enable_switch': 1,
      });
      ToastUtil.success('保存成功');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  // ───── 卡密管理 ─────
  Widget _cardList() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        PrimaryButton(
          label: '批量生成卡密',
          icon: Icons.add_card,
          height: 46,
          onPressed: _genCards,
        ),

        const SizedBox(height: 12),
        for (final c in _cards)
          AdCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c['code']}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c['type'] == 'vip' ? '会员 ${c['value']} 天' : '积分 ${c['value']}'}'
                        ' · ${c['used'] == 1 ? '已使用' : '未使用'}',
                        style: TextStyle(fontSize: 11.5, color: context.t3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: C.danger,
                  ),
                  onPressed: () async {
                    await AppAction.act(
                      () => _svc.deleteCard(int.tryParse('${c['id']}') ?? 0),
                      loading: '删除中…',
                      success: '已删除',
                    );
                    _load();
                  },
                ),
              ],
            ),
          ),
        if (_cards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                '暂无卡密，点上方按钮生成',
                style: Ty.small.copyWith(color: context.t3),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _genCards() async {
    final countCtrl = TextEditingController(text: '10');
    final valueCtrl = TextEditingController(text: '30');
    String type = 'vip';
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.md),
        ),
        title: const Text('批量生成卡密'),
        content: StatefulBuilder(
          builder: (ctx, setD) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: countCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '生成数量'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '卡密类型'),
                  items: const [
                    DropdownMenuItem(value: 'vip', child: Text('会员时长(天)')),
                    DropdownMenuItem(value: 'score', child: Text('积分')),
                  ],
                  onChanged: (v) => setD(() => type = v ?? 'vip'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: type == 'vip' ? '会员天数' : '积分数量',
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('生成'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.generateCards(
        int.tryParse(countCtrl.text) ?? 10,
        type,
        int.tryParse(valueCtrl.text) ?? 30,
      );
      ToastUtil.success('卡密已生成');
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// 配置页
  ///
  /// ★ 1020（修复「相同功能影响数据」）：
  ///   原来这里能改「用户协议 / 隐私政策」，而「配置 → 用户协议/隐私政策」
  ///   也能改 **同一份数据** —— 两处保存会互相覆盖，非常危险。
  ///   现在：这里只保留「首页通知条」，协议类统一指引到配置页修改。
  Widget _configList() {
    final placard = TextEditingController();
    return FutureBuilder<Map<String, dynamic>>(
      future: _svc.config(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const LoadingState(text: '加载配置…');
        }
        if (placard.text.isEmpty) {
          placard.text = '${snap.data!['placard'] ?? ''}';
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _f('首页通知条（App 首页顶部滚动小字）', placard, 2),
            const SizedBox(height: 4),
            Text(
              '提示：这里是首页顶部的一条短通知，不弹窗。'
              '要改「公告弹窗」请去「配置 → 公告弹窗」。',
              style: TextStyle(fontSize: 11, height: 1.6, color: context.t3),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.amber.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.amber.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: C.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '用户协议 / 隐私政策已移走',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: C.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '为避免两处同时编辑造成互相覆盖，'
                    '协议内容统一在「配置 → 用户协议/隐私政策」里修改。',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: context.t2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: '保存配置',
              icon: Icons.save_rounded,
              height: 46,
              onPressed: () async {
                try {
                  await _svc.saveConfig({'placard': placard.text});
                  ToastUtil.success('保存成功');
                } catch (e) {
                  ToastUtil.error(ErrText.of(e));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _f(String label, TextEditingController c, int lines) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: lines,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm)),
      ),
    ),
  );
}
