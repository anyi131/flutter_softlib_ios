import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../design/app_anim.dart';
import '../../api/user_service.dart';
import '../../api/wish_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/err_text.dart';
import '../../utils/toast_util.dart';
import '../../design/glass.dart';

/// 求软件 · 需求投票
///
/// ★ 1020（待办 #2）
/// 背景：用户搜不到想要的软件就走了，而你不知道他们想要什么。
/// 这里让用户提交需求、互相点赞，后台按票数决定优先采集哪个。
///
/// 设计要点：
///   · 顶部说明「提交后我们会按票数优先采集」—— 给用户一个「投了有用」的预期
///   · 列表按票数排序，票数多的排前面（视觉上形成「大家都要这个」）
///   · 「我投过」的卡片高亮，点一下可取消
///   · 同名需求自动合并（服务端做），用户不会看到一堆重复
class WishPage extends StatefulWidget {
  const WishPage({super.key, this.initialKeyword = ''});

  /// 从搜索无结果跳进来时，预填搜索词
  final String initialKeyword;

  @override
  State<WishPage> createState() => _WishPageState();
}

class _WishPageState extends State<WishPage> {
  final _svc = WishService.instance;
  final _kwCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String _sort = 'votes';
  int _page = 1;
  bool _hasMore = false;
  final Set<int> _voting = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword.isNotEmpty) {
      _kwCtrl.text = widget.initialKeyword;
    }
    _load();
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) {
      setState(() => _loading = true);
      _page = 1;
    }
    final r = await _svc.list(
      sort: _sort,
      page: _page,
      size: 20,
      kw: _kwCtrl.text.trim(),
    );
    if (!mounted) return;
    final list = ((r['list'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    setState(() {
      _list = more ? [..._list, ...list] : list;
      _hasMore = r['has_more'] == true;
      _loading = false;
    });
  }

  /// 投票（乐观更新）
  Future<void> _vote(Map<String, dynamic> w) async {
    if (!UserService.instance.isLoggedIn) {
      ToastUtil.info('登录后才能投票');
      return;
    }
    final id = (w['id'] as num?)?.toInt() ?? 0;
    if (id <= 0 || _voting.contains(id)) return;
    _voting.add(id);
    final wasVoted = w['voted'] == true;
    final oldVotes = (w['votes'] as num?)?.toInt() ?? 0;
    setState(() {
      w['voted'] = !wasVoted;
      w['votes'] = oldVotes + (wasVoted ? -1 : 1);
    });
    try {
      final r = await _svc.vote(id, token: UserService.instance.token);
      if (!mounted) return;
      setState(() {
        w['voted'] = r['voted'] == true;
        w['votes'] = (r['votes'] as num?)?.toInt() ?? w['votes'];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        w['voted'] = wasVoted;
        w['votes'] = oldVotes;
      });
      ToastUtil.error(ErrText.of(e));
    } finally {
      _voting.remove(id);
    }
  }

  void _openSubmit() {
    if (!UserService.instance.isLoggedIn) {
      ToastUtil.info('登录后才能提交需求');
      return;
    }
    final titleCtrl = TextEditingController(text: _kwCtrl.text.trim());
    String catName = '';
    Get.bottomSheet(
      Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SheetSurface(
          color: context.isDark ? C.bg1 : Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          radius: 22,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: Deco.brandGradient,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.wb_incandescent_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '我想要一个软件',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.t1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '提交后其他人可以点赞，票数越高越优先采集',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  maxLength: 60,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: '软件名称',
                    hintText: '例如：微信、抖音',
                    counterStyle: const TextStyle(fontSize: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contentCtrl,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: '补充说明（选填）',
                    hintText: '用途、版本要求、为什么需要它',
                    counterStyle: const TextStyle(fontSize: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  children: [
                    for (final c in const ['社交', '影音', '工具', '游戏', '学习', '其他'])
                      ChoiceChip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        selected: catName == c,
                        onSelected: (v) => setState(() => catName = v ? c : ''),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final t = titleCtrl.text.trim();
                      if (t.length < 2) {
                        ToastUtil.error('请填写软件名称');
                        return;
                      }
                      Get.back();
                      try {
                        final r = await _svc.add(
                          title: t,
                          content: _contentCtrl.text.trim(),
                          catName: catName,
                          token: UserService.instance.token,
                        );
                        ToastUtil.success(
                          r['merged'] == true ? '已有相同需求，已为它投一票' : '需求已提交',
                        );
                        _contentCtrl.clear();
                        _load();
                      } catch (e) {
                        ToastUtil.error(ErrText.of(e));
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: C.brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      '提交需求',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: _loading
                      ? const LoadingState(text: '加载需求…')
                      : (_list.isEmpty
                            ? EmptyState(
                                icon: Icons.wb_incandescent_outlined,
                                text: '还没有人提需求',
                                hint: '点右下角按钮，告诉我们需要什么',
                              )
                            : RefreshIndicator(
                                onRefresh: () => _load(),
                                color: C.brand,
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.fromLTRB(
                                    context.pagePadding,
                                    4,
                                    context.pagePadding,
                                    100,
                                  ),
                                  itemCount: _list.length + (_hasMore ? 1 : 0),
                                  itemBuilder: (c, i) {
                                    if (i >= _list.length) {
                                      _page++;
                                      _load(more: true);
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return _wishCard(_list[i]);
                                  },
                                ),
                              )),
                ),
              ],
            ),
          ),
          // 右下角提交按钮
          Positioned(
            right: 18,
            bottom: 24,
            child: FloatingActionButton.extended(
              onPressed: _openSubmit,
              backgroundColor: C.brand,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                '求软件',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        8,
        context.pagePadding,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppPressable(
                onTap: () => Get.back(),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 19,
                  color: context.t1,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '求软件',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.t1,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: C.brand.withAlpha(22),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${_list.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: C.brand,
                  ),
                ),
              ),
              const Spacer(),
              _sortTab('票数', 'votes'),
              const SizedBox(width: 6),
              _sortTab('最新', 'new'),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withAlpha(14) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.isDark
                    ? Colors.white10
                    : Colors.black.withAlpha(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 17, color: context.t3),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: _kwCtrl,
                    onSubmitted: (_) => _load(),
                    style: TextStyle(fontSize: 13, color: context.t1),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '搜索需求',
                      hintStyle: TextStyle(fontSize: 13, color: context.t3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortTab(String label, String key) {
    final sel = _sort == key;
    return GestureDetector(
      onTap: () {
        if (_sort == key) return;
        setState(() => _sort = key);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? C.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : context.t3,
          ),
        ),
      ),
    );
  }

  Widget _wishCard(Map<String, dynamic> w) {
    final votes = (w['votes'] as num?)?.toInt() ?? 0;
    final voted = w['voted'] == true;
    final status = '${w['status'] ?? 'pending'}';
    final title = '${w['title'] ?? ''}';
    final content = '${w['content'] ?? ''}';
    final cat = '${w['cat_name'] ?? ''}';
    final adopted = status == 'adopted';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withAlpha(12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: adopted
                ? C.mint.withAlpha(90)
                : (context.isDark ? Colors.white10 : Colors.black.withAlpha(7)),
            width: adopted ? 1.3 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 投票按钮
            AppPressable(
              onTap: () => _vote(w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: voted ? C.brand : C.brand.withAlpha(18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  children: [
                    Icon(
                      voted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                      size: 16,
                      color: voted ? Colors.white : C.brand,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$votes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: voted ? Colors.white : C.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.t1,
                          ),
                        ),
                      ),
                      if (adopted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: C.mint.withAlpha(30),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            '已采纳',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: C.mint,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.tiny.copyWith(color: context.t2, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (cat.isNotEmpty) ...[
                        Text(
                          cat,
                          style: Ty.tiny.copyWith(fontSize: 10, color: C.brand),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${w['time_text'] ?? ''}',
                        style: Ty.tiny.copyWith(
                          fontSize: 10,
                          color: context.t3,
                        ),
                      ),
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
}
