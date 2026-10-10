import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/lzy_folder_parser.dart';
import '../../../api/soft_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/app_style.dart';
import '../../../design/app_style_controller.dart';
import '../../../design/app_anim.dart';
import '../../../design/theme_controller.dart';
import '../../../design/ui.dart';
import '../../../models/app_cat.dart';
import '../../../models/app_config.dart';
import '../../../models/app_item.dart';
import '../../../routes/app_pages.dart';
import '../../../widgets/tab_bottom_pad.dart';

/// 软件库 —— 分类 + 卡片列表（支持下拉刷新/上拉加载）
class AppComponent extends StatefulWidget {
  const AppComponent({super.key});

  @override
  State<AppComponent> createState() => _AppComponentState();
}

class _AppComponentState extends State<AppComponent> {
  final _svc = SoftService.instance;
  final _refreshCtrl = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  List<AppCat> _cats = [];
  List<AppItem> _apps = [];
  int _cat = 0;
  bool _loading = true;

  /// 列表正在加载更多（不遮全屏，只在底部转圈）
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const _size = 15;
  String _kw = '';

  /// 数据源（后台可配）：all / local / lzy
  String _source = 'all';
  bool _folderParsing = false;
  String _folderProgress = '';

  @override
  void initState() {
    super.initState();
    _initSource();
    _loadCats();
  }

  Future<void> _initSource() async {
    // ★ 并发：配置与列表同时请求，不再串行等待（首屏快一倍）
    final results = await Future.wait([
      _svc.fetchConfig(),
      _svc.fetchApps(
        catId: _cat,
        keyword: _kw,
        provider: '', // 先用全部，配置回来后再决定是否重取
        force: false,
      ),
    ]);
    if (!mounted) return;
    final cfg = results[0] as AppConfig?;
    final list = results[1] as List<AppItem>;
    final src = cfg?.appSource ?? 'all';
    setState(() {
      _source = src;
      _apps = list;
      _loading = false;
    });
    // ★ 应用后台下发的默认列表样式（用户本地选过则不覆盖）—— 需求 #9
    if (cfg != null) {
      // ★ v52：列表样式与主题统一由后台「界面配置」下发
      AppStyleController.instance.applyServerDefault(cfg.uiConfig.listStyle);
      ThemeController.instance.applyServerPalette(cfg.uiConfig.themePalette);
    }
    // 若配置指定了数据源筛选，且与「全部」结果不同，再静默重取一次
    if (src != 'all') {
      await _load(reset: true);
    }
  }

  @override
  void dispose() {
    _refreshCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    final c = await _svc.fetchCats();
    if (!mounted) return;
    setState(
      () => _cats = [
        AppCat(id: 0, title: '全部', count: 0),
        ...c.where((e) => e.id != 0),
      ],
    );
  }

  Future<void> _load({bool reset = false, bool showLoading = true}) async {
    final cat = _currentCat;
    final isFolder = cat != null && cat.isFolder;
    if (reset) {
      _page = 1;
      _hasMore = true;
      // v54-fix：下拉刷新时EasyRefresh 自带指示器；
      // 若这里再切全屏 LoadingState，会把 EasyRefresh 从树上摘掉，
      // 导致随后 finishRefresh() 操作已失联的 controller。
      if (showLoading) setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final cat = _currentCat;
      // ★ 蓝奏云文件夹分类：优先用【客户端本地解析】
      //   （服务器 IP 会被蓝奏云限流只能拿 500 条，客户端可拿全部）
      List<AppItem>? folderItems;
      if (cat != null && cat.isFolder) {
        setState(() {
          _folderParsing = true;
          _folderProgress = '正在打开文件夹…';
        });
        try {
          folderItems = await LzyFolderParser.instance.parse(
            cat.url,
            defaultDesc: cat.defaultDesc,
            defaultShots: cat.defaultShots,
            defaultIcon: cat.defaultIcon,
            pwd: cat.pwd.isEmpty ? 'password' : cat.pwd,
            onProgress: (pg, cnt) {
              if (mounted) {
                setState(() {
                  _folderProgress = '已解析 $cnt 个（第 $pg 页）';
                });
              }
            },
          );
        } catch (e) {
          // 客户端解析失败 → 退回服务端缓存/解析
          debugPrint('[Softlib] client parse failed: $e');
          folderItems = null;
        } finally {
          if (mounted) {
            setState(() {
              _folderParsing = false;
              _folderProgress = '';
            });
          }
        }
      }

      final all = (folderItems != null)
          ? folderItems
          : ((cat != null && cat.isFolder)
                ? await _svc.fetchFolder(cat.url, pwd: cat.pwd, pgs: _page)
                : await _svc.fetchApps(
                    catId: _cat,
                    keyword: _kw,
                    provider: _source == 'all' ? '' : _source,
                    force: reset,
                  ));
      final isFolderMode = cat != null && cat.isFolder;
      debugPrint(
        '[Softlib] _load: cat=${cat?.title} isFolder=$isFolderMode '
        'folderItems=${folderItems?.length} all=${all.length} page=$_page reset=$reset',
      );
      List<AppItem> slice;
      bool hasMore;
      if (isFolderMode) {
        // ★ 文件夹模式：客户端一次性解析出全部（几百条），
        //   本地切片展示：首批 50 条，滚到底自动加载下一批，
        //   这样避免一次性渲染几百张远程图标导致卡顿。
        final src = all;
        final start = reset ? 0 : _apps.length;
        slice = start >= src.length
            ? <AppItem>[]
            : src.sublist(start, (start + _size).clamp(0, src.length));
        hasMore = (start + slice.length) < src.length;
        if (!mounted) return;
        setState(() {
          if (reset) {
            _apps = slice;
          } else {
            _apps.addAll(slice);
          }
          _hasMore = hasMore;
          _loading = false;
          _loadingMore = false;
        });
        return;
      }
      {
        final start = (_page - 1) * _size;
        slice = start >= all.length
            ? <AppItem>[]
            : all.sublist(start, (start + _size).clamp(0, all.length));
        hasMore = slice.length >= _size;
      }
      if (!mounted) return;
      setState(() {
        if (reset) {
          _apps = slice;
        } else {
          _apps.addAll(slice);
        }
        _hasMore = hasMore;
        if (hasMore) _page++;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  /// 当前分类（用于判断是否蓝奏云文件夹）
  AppCat? get _currentCat => _cats.where((c) => c.id == _cat).isEmpty
      ? null
      : _cats.firstWhere((c) => c.id == _cat);

  void _switch(int id) {
    if (_cat == id) return;
    setState(() {
      _cat = id;
      _apps = [];
      _loading = true;
    });
    _load(reset: true);
  }

  /// 搜索（弹窗输入关键词）
  Future<void> _search() async {
    final ctrl = TextEditingController(text: _kw);
    final v = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.lg),
        ),
        title: const Text(
          '搜索软件',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入软件名称',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onSubmitted: (s) => Get.back(result: s.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: ''),
            child: const Text('重置'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: ctrl.text.trim()),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    if (v == null) return;
    setState(() {
      _kw = v;
      _apps = [];
      _loading = true;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                _catBar(),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───── 顶部 ─────
  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 14, 12, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('软件库', style: Ty.display.copyWith(color: context.t1)),
                const SizedBox(height: 5),
                Text(
                  _kw.isEmpty ? '为你精选 · 综合软件合集' : '搜索「$_kw」',
                  style: Ty.small.copyWith(color: context.t3),
                ),
              ],
            ),
          ),
          _circleBtn(
            _kw.isEmpty ? Icons.search_rounded : Icons.close_rounded,
            () {
              if (_kw.isEmpty) {
                _search();
              } else {
                setState(() {
                  _kw = '';
                  _apps = [];
                  _loading = true;
                });
                _load(reset: true);
              }
            },
          ),
          _circleBtn(
            Icons.download_rounded,
            () => Get.toNamed(Routes.appDownload),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData i, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: GestureDetector(
      onTap: f,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withAlpha(14) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: context.isDark
                ? Colors.white.withAlpha(22)
                : Colors.black.withAlpha(8),
          ),
          boxShadow: context.isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF2C3550).withAlpha(18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Icon(i, size: 20, color: context.t2),
      ),
    ),
  );

  // ───── 分类 ─────
  Widget _catBar() {
    if (_cats.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          14,
          context.pagePadding,
          8,
        ),
        itemCount: _cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _cats[i];
          final sel = _cat == c.id;
          return GestureDetector(
            onTap: () => _switch(c.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel ? Deco.brandGradient : null,
                color: sel
                    ? null
                    : (context.isDark
                          ? Colors.white.withAlpha(12)
                          : Colors.white),
                borderRadius: BorderRadius.circular(R.full),
                border: Border.all(
                  color: sel
                      ? Colors.transparent
                      : (context.isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(8)),
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: C.brand.withAlpha(72),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : (context.isDark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF2C3550).withAlpha(14),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.isFolder)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.cloud_outlined,
                        size: 13,
                        color: sel ? Colors.white : C.cyan,
                      ),
                    ),
                  Text(
                    c.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                      color: sel ? Colors.white : context.t2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───── 列表 ─────
  Widget _body() {
    if (_loading) {
      // 文件夹解析时展示实时进度，其它情况用统一加载态
      return LoadingState(
        text: _folderParsing
            ? (_folderProgress.isEmpty ? '正在解析蓝奏云文件夹…' : _folderProgress)
            : null,
      );
    }
    if (_apps.isEmpty) {
      return EmptyState(
        text: _kw.isEmpty ? '该分类暂无软件' : '没有找到「$_kw」',
        hint: _kw.isEmpty ? '换个分类看看吧' : '试试更换关键词搜索',
        icon: _kw.isEmpty ? Icons.inbox_rounded : Icons.search_off_rounded,
      );
    }
    return EasyRefresh(
      controller: _refreshCtrl,
      header: const MaterialHeader(),
      footer: const MaterialFooter(),
      onRefresh: () async {
        await _load(reset: true, showLoading: false);
        _refreshCtrl.finishRefresh();
      },
      onLoad: () async {
        if (!_hasMore) {
          _refreshCtrl.finishLoad(IndicatorResult.noMore);
          return;
        }
        await _load();
        _refreshCtrl.finishLoad(
          _hasMore ? IndicatorResult.success : IndicatorResult.noMore,
        );
      },
      child: Obx(() {
        final style = AppStyleController.instance.listStyle.value;
        // ★ 需求 #9：三种列表样式（后台可切默认，用户可覆盖）
        if (style == AppListStyle.grid) {
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              8,
              context.pagePadding,
              tabBottomPadding(context) + 12,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: _apps.length,
            itemBuilder: (context, i) => RepaintBoundary(
              key: ValueKey('g_${_apps[i].id}'),
              child: AppStaggerIn(index: i, child: _gridCard(_apps[i])),
            ),
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.only(
            top: 8,
            bottom: tabBottomPadding(context) + 12,
          ),
          itemCount: _apps.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= _apps.length) return _loadMoreFooter();
            final a = _apps[i];
            return RepaintBoundary(
              key: ValueKey('l_${a.id}'),
              child: AppStaggerIn(
                index: i,
                child: switch (style) {
                  AppListStyle.compact => _compactCard(a),
                  AppListStyle.large => _largeCard(a),
                  AppListStyle.minimal => _minimalCard(a),
                  _ => _card(a),
                },
              ),
            );
          },
        );
      }),
    );
  }

  /// 样式四：封面大图卡（v52f #9）
  Widget _largeCard(AppItem a) {
    final vip = a.isVipItem;
    final cover = a.screenshots.isNotEmpty ? a.screenshots.first : a.icon;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        6,
        context.pagePadding,
        6,
      ),
      child: KitCard(
        radius: R.xl,
        padding: EdgeInsets.zero,
        onTap: () => Get.toNamed(
          Routes.appDetails,
          arguments: {'appId': a.id.toString(), 'item': a},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover.isEmpty
                      ? _ph()
                      : CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          memCacheWidth: 720,
                          placeholder: (_, __) => _ph(),
                          errorWidget: (_, __, ___) => _ph(),
                        ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        if (a.isNew) _badge('NEW', const Color(0xFFFF6B35)),
                        if (vip) ...[
                          if (a.isNew) const SizedBox(width: 6),
                          _badge('会员', C.gold),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 信息
            Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(R.md),
                    child: a.icon.isEmpty
                        ? _ph(46)
                        : CachedNetworkImage(
                            imageUrl: a.icon,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _ph(46),
                            errorWidget: (_, __, ___) => _ph(46),
                          ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title.isEmpty ? '未知应用' : a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.h3.copyWith(color: context.t1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (a.version.isNotEmpty) a.version,
                            if (a.size.isNotEmpty) a.size,
                          ].join(' · '),
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: context.t3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }

  /// 样式五：极简单行（v52f #9）
  Widget _minimalCard(AppItem a) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        2,
        context.pagePadding,
        2,
      ),
      child: AppPressable(
        onTap: () => Get.toNamed(
          Routes.appDetails,
          arguments: {'appId': a.id.toString(), 'item': a},
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.md),
            color: context.isDark ? Colors.white.withAlpha(8) : Colors.white,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: a.icon.isEmpty
                    ? _ph(38)
                    : CachedNetworkImage(
                        imageUrl: a.icon,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _ph(38),
                        errorWidget: (_, __, ___) => _ph(38),
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  a.title.isEmpty ? '未知应用' : a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.t1,
                  ),
                ),
              ),
              if (a.isVipItem)
                Icon(Icons.workspace_premium_rounded, size: 15, color: C.gold)
              else if (a.isNew)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B35),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 样式二：紧凑列表（一行一款）
  Widget _compactCard(AppItem a) {
    final vip = a.isVipItem;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        3,
        context.pagePadding,
        3,
      ),
      child: KitCard(
        radius: R.md,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        onTap: () => Get.toNamed(
          Routes.appDetails,
          arguments: {'appId': a.id.toString(), 'item': a},
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(R.sm),
              child: a.icon.isEmpty
                  ? _phSmall()
                  : CachedNetworkImage(
                      imageUrl: a.icon,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      memCacheWidth: 96,
                      placeholder: (_, __) => _phSmall(),
                      errorWidget: (_, __, ___) => _phSmall(),
                    ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.title.isEmpty ? '未知应用' : a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.t1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (a.size.isNotEmpty) a.size,
                      if (a.version.isNotEmpty) 'v${a.version}',
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.t3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Pill(vip ? '会员' : '免费', color: vip ? C.amber : C.mint, small: true),
          ],
        ),
      ),
    );
  }

  /// 样式三：双列网格
  Widget _gridCard(AppItem a) {
    final vip = a.isVipItem;
    return KitCard(
      radius: R.lg,
      padding: const EdgeInsets.all(12),
      onTap: () => Get.toNamed(
        Routes.appDetails,
        arguments: {'appId': a.id.toString(), 'item': a},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(R.lg),
                    boxShadow: [
                      BoxShadow(
                        color: C.brand.withAlpha(context.isDark ? 45 : 26),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(R.lg),
                    child: a.icon.isEmpty
                        ? _ph()
                        : CachedNetworkImage(
                            imageUrl: a.icon,
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                            memCacheWidth: 160,
                            placeholder: (_, __) => _ph(),
                            errorWidget: (_, __, ___) => _ph(),
                          ),
                  ),
                ),
                if (a.isNew)
                  Positioned(
                    left: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFB923C)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            a.title.isEmpty ? '未知应用' : a.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: context.t1,
            ),
          ),
          const SizedBox(height: 5),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pill(
                  vip ? '会员' : '免费',
                  color: vip ? C.amber : C.mint,
                  small: true,
                ),
                if (a.size.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      a.size,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: context.t3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _phSmall() => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [C.brand.withAlpha(50), C.violet.withAlpha(50)],
      ),
    ),
  );

  /// 底部「加载更多」指示（文件夹模式分批加载时显示）
  Widget _loadMoreFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: C.brand),
          ),
          const SizedBox(width: 10),
          Text('正在加载更多…', style: Ty.tiny.copyWith(color: context.t3)),
        ],
      ),
    );
  }

  /// 卡片
  Widget _card(AppItem a) {
    final vip = a.isVipItem;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        5,
        context.pagePadding,
        5,
      ),
      child: KitCard(
        radius: R.lg,
        onTap: () => Get.toNamed(
          Routes.appDetails,
          arguments: {'appId': a.id.toString(), 'item': a},
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 图标
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.md),
                boxShadow: [
                  BoxShadow(
                    color: C.brand.withAlpha(context.isDark ? 45 : 26),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(R.md),
                    child: a.icon.isEmpty
                        ? _ph()
                        : CachedNetworkImage(
                            imageUrl: a.icon,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _ph(),
                            errorWidget: (_, __, ___) => _ph(),
                          ),
                  ),
                  // ★ NEW 角标（图标左上角）
                  if (a.isNew)
                    Positioned(
                      left: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFB923C)],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withAlpha(120),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.4,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题 + 版本
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.title.isEmpty ? '未知应用' : a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: context.t1,
                          ),
                        ),
                      ),
                      if (a.version.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          a.version,
                          style: TextStyle(fontSize: 10.5, color: context.t3),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 一行装完：会员/免费 + 评分 + 大小
                  Row(
                    children: [
                      Pill(
                        vip ? '会员' : '免费',
                        color: vip ? C.amber : C.mint,
                        small: true,
                      ),
                      const SizedBox(width: 7),
                      if (a.scoreCount > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: C.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          a.scoreAvg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: C.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (a.size.isNotEmpty)
                        Flexible(
                          child: Text(
                            a.size,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: context.t3),
                          ),
                        ),
                    ],
                  ),
                  if (a.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      a.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: context.t3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: context.t3),
          ],
        ),
      ),
    );
  }

  Widget _ph([double size = 60]) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [C.brand.withAlpha(50), C.violet.withAlpha(50)],
      ),
    ),
    child: Icon(Icons.android_rounded, color: Colors.white, size: size * 0.48),
  );
}
