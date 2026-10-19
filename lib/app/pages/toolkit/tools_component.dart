import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/soft_service.dart' show SoftService;
import '../../api/toolbox_service.dart';
import '../../design/ad.dart';
import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../api/user_service.dart';
import '../../utils/err_text.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';
import '../../widgets/tab_bottom_pad.dart';
import 'tool_kit.dart';
import 'tool_api_page.dart';
import 'tool_cache.dart';
import 'tool_browser_page.dart';
import 'tool_router.dart';

/// ═══════════════════════════════════════════════════════════════
/// 工具箱 Tab 主页面（v3.3.4）
///
/// 界面骨架（用户指定，参考样本「简助手」）：
///   · 顶部：标题「工具箱」+ 工具总数 + 右上 3 个图标（搜索/布局/收藏）
///   · 分类 = 圆角大卡
///       卡头：52×52 品牌色圆角图标块 + 中文分类名(17sp粗)
///             + 英文副标题(11.5sp灰) + 右侧「N 个」胶囊
///       卡体：工具为**自适应胶囊 chips**（品牌色淡底 + 文字）
///   · 布局可切：flow 胶囊流式(默认) / square 方形宫格 / circle 圆形宫格
/// ═══════════════════════════════════════════════════════════════
class ToolsComponent extends StatefulWidget {
  const ToolsComponent({super.key});

  @override
  State<ToolsComponent> createState() => _ToolsComponentState();
}

class _ToolsComponentState extends State<ToolsComponent>
    with WidgetsBindingObserver {
  final _svc = ToolboxService.instance;

  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic> _meta = {};
  bool _loading = true;
  String _err = '';
  String _layout = 'grid';

  /// ★ 1020（反馈 #5）：工具收藏 —— 之前只能从右上角 ☆ 进收藏页看，
  ///   列表里完全不知道哪些已收藏，也不好收藏（要点进工具再找入口）。
  ///   现在：本地缓存收藏 id 集合 → 卡片上直接显示星标，长按/点星即可收藏，
  ///   顶部还能一键「只看收藏」。
  static const _kFav = 'tool_fav_ids';
  final Set<int> _favIds = <int>{};
  bool _favOnly = false;

  @override
  void initState() {
    super.initState();
    // ★ 1015 修复：工具 Tab 常驻不重建，原来只在 initState 拉一次目录，
    //   后台新增/改动的工具在 App 里永远看不到。
    //   现在回到前台（从后台管理页切回）自动静默刷新一次。
    WidgetsBinding.instance.addObserver(this);
    _load();
    _loadFavs();
  }

  /// 读取收藏 id（先用本地缓存秒出，再用服务端校准）
  Future<void> _loadFavs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getStringList(_kFav) ?? const <String>[];
      final local = raw.map(int.tryParse).whereType<int>().toSet();
      if (mounted && local.isNotEmpty) setState(() => _favIds.addAll(local));
    } catch (_) {}
    try {
      final list = await _svc.favList();
      final remote = list
          .map((e) => int.tryParse('${e['id'] ?? e['tool_id'] ?? 0}') ?? 0)
          .where((e) => e > 0)
          .toSet();
      if (!mounted) return;
      setState(() {
        _favIds
          ..clear()
          ..addAll(remote);
      });
      await _saveFavs();
    } catch (_) {}
  }

  Future<void> _saveFavs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_kFav, _favIds.map((e) => '$e').toList());
    } catch (_) {}
  }

  /// 切换收藏（乐观更新，失败回滚并提示）
  Future<void> _toggleFav(Map<String, dynamic> t) async {
    final id = int.tryParse('${t['id']}') ?? 0;
    final title = '${t['title'] ?? ''}';
    if (id <= 0) {
      ToastUtil.info('该工具不支持收藏');
      return;
    }
    if (!UserService.instance.isLoggedIn) {
      ToastUtil.info('登录后才能收藏工具');
      return;
    }
    final wasFav = _favIds.contains(id);
    setState(() {
      if (wasFav) {
        _favIds.remove(id);
      } else {
        _favIds.add(id);
      }
    });
    try {
      final now = await _svc.toggleFav(id);
      if (!mounted) return;
      setState(() {
        if (now) {
          _favIds.add(id);
        } else {
          _favIds.remove(id);
        }
      });
      await _saveFavs();
      ToastUtil.success(now ? '已收藏「$title」' : '已取消收藏');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFav) {
          _favIds.add(id);
        } else {
          _favIds.remove(id);
        }
      });
      ToastUtil.error(ErrText.of(e));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentReload();
    }
  }

  /// 静默刷新：不闪 loading，拉到新数据再 setState
  Future<void> _silentReload() async {
    try {
      final cfg = await _svc.fetchConfig(force: true);
      if (!mounted || cfg == null) return;
      final groups =
          (cfg['groups'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      var layout = '${cfg['default_style'] ?? 'grid'}';
      if (!['grid', 'card', 'compact', 'banner'].contains(layout))
        layout = 'grid';
      if (groups.length == _groups.length &&
          groups.isNotEmpty &&
          _layout == layout &&
          _meta['updated'] == cfg['updated']) {
        return; // 没变化就不重建
      }
      setState(() {
        _groups = groups;
        _meta = cfg;
        _layout = layout;
        _err = groups.isEmpty ? '工具目录为空，请稍后重试' : '';
      });
      ToolCache.write('jzs_config', cfg);
    } catch (_) {}
  }

  Future<void> _load() async {
    // ★ 1015 优化：先读本地缓存，秒开界面（不用等网络）
    final cached = await ToolCache.read('jzs_config');
    if (cached != null && mounted && _groups.isEmpty) {
      _applyConfig(cached, loading: false);
    } else {
      setState(() {
        _loading = true;
        _err = '';
      });
    }
    // 再拉网络（回来后无感替换）
    try {
      final cfg = await _svc.fetchConfig(force: true);
      if (!mounted || cfg == null) return;
      _applyConfig(cfg, loading: false);
      // 写缓存（下次秒开）
      ToolCache.write('jzs_config', cfg);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // 有缓存就不报错（用户还能看缓存内容）
        _err = _groups.isEmpty ? '加载失败，下拉重试' : '';
      });
    }
  }

  /// 统一应用配置（缓存/网络共用）
  void _applyConfig(Map<String, dynamic> cfg, {required bool loading}) {
    final groups =
        (cfg['groups'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    var layout = '${cfg['default_style'] ?? 'grid'}';
    if (!['grid', 'card', 'compact', 'banner'].contains(layout))
      layout = 'grid';
    setState(() {
      _groups = groups;
      _meta = cfg;
      _layout = layout;
      _loading = loading;
      _err = groups.isEmpty ? '工具目录为空，请稍后重试' : '';
    });
  }

  int get _count {
    var n = 0;
    for (final g in _groups) {
      n += ((g['tools'] as List?) ?? []).length;
    }
    return n;
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
                Expanded(
                  child: _loading
                      ? const LoadingState(text: '正在加载工具箱…')
                      : (_groups.isEmpty
                            ? EmptyState(
                                icon: Icons.widgets_outlined,
                                text: _err.isEmpty ? '暂无工具' : _err,
                                hint: '下拉重试',
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                color: C.brand,
                                child: ListView(
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.only(
                                    top: 4,
                                    bottom: tabBottomPadding(context) + 24,
                                  ),
                                  children: _favOnly
                                      ? _favSection()
                                      : [
                                          // ★ 1020：收藏置顶区（有收藏才显示）
                                          if (_favIds.isNotEmpty)
                                            _favSection(compact: true),
                                          ..._groups.map(_groupCard),
                                        ],
                                ),
                              )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ 顶部 ═══════════

  // ══════════════════════════════════════════════════════════════
  //  ★ 1015 全新 UI（重绘）
  //  设计基调：柔和渐变头 + 玻璃卡片 + 大图标 + 圆润质感
  // ══════════════════════════════════════════════════════════════

  /// 顶部：渐变头图 + 统计胶囊 + 操作按钮
  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 22,
                          decoration: BoxDecoration(
                            gradient: Deco.brandGradient,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '工具箱',
                          style: Ty.display.copyWith(
                            color: context.t1,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Pill(
                          '${_meta['total'] ?? _count} 个工具',
                          icon: Icons.auto_awesome_rounded,
                          small: true,
                        ),
                        const SizedBox(width: 6),
                        if (_groups.isNotEmpty)
                          Pill(
                            '${_groups.length} 个分类',
                            color: C.mint,
                            icon: Icons.folder_rounded,
                            small: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _actionBtn(
                Icons.search_rounded,
                '搜索',
                () => Get.to(() => const ToolSearchPage()),
              ),
              const SizedBox(width: 8),
              // ★ 1020：一键只看收藏（再点一次回到全部）
              _actionBtn(
                _favOnly ? Icons.star_rounded : Icons.star_border_rounded,
                _favOnly ? '显示全部' : '只看收藏',
                () => setState(() => _favOnly = !_favOnly),
                active: _favOnly,
                badge: _favIds.isEmpty ? 0 : _favIds.length,
              ),
              const SizedBox(width: 8),
              _actionBtn(
                Icons.collections_bookmark_rounded,
                '我的收藏',
                () => Get.to(() => const ToolFavPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 圆形玻璃操作按钮
  Widget _actionBtn(
    IconData icon,
    String tip,
    VoidCallback onTap, {
    bool active = false,
    int badge = 0,
  }) => Tooltip(
    message: tip,
    child: AppPressable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: Ad.s(context, 42),
            height: Ad.s(context, 42),
            decoration: BoxDecoration(
              color: active
                  ? C.brand
                  : (context.isDark
                        ? Colors.white.withAlpha(16)
                        : Colors.white),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? C.brand.withAlpha(90)
                      : Colors.black.withAlpha(context.isDark ? 60 : 16),
                  blurRadius: active ? 16 : 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : context.t1,
            ),
          ),
          if (badge > 0)
            Positioned(
              right: -3,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: C.danger,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  /// 全部工具（拍平分类）
  List<Map<String, dynamic>> get _allTools {
    final out = <Map<String, dynamic>>[];
    for (final g in _groups) {
      final list = (g['tools'] as List?) ?? const [];
      for (final t in list) {
        out.add(Map<String, dynamic>.from(t as Map));
      }
    }
    return out;
  }

  /// 收藏区：直接在首页就能用，不用再进二级页
  Widget _favSection({bool compact = false}) {
    final favs = _allTools
        .where((t) => _favIds.contains(int.tryParse('${t['id']}') ?? 0))
        .toList();
    if (favs.isEmpty && !compact) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          10,
          context.pagePadding,
          20,
        ),
        child: const EmptyState(
          icon: Icons.star_border_rounded,
          text: '还没有收藏工具',
          hint: '长按任意工具图标即可收藏',
        ),
      );
    }
    if (favs.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.fromLTRB(
        context.pagePadding,
        3,
        context.pagePadding,
        16,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? [const Color(0xFF2A2140), const Color(0xFF1C1A2A)]
              : [const Color(0xFFFFF7E6), const Color(0xFFFFFBFF)],
        ),
        border: Border.all(
          color: C.amber.withAlpha(context.isDark ? 70 : 60),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: C.amber.withAlpha(context.isDark ? 26 : 18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [C.amber, C.amber.withAlpha(190)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                compact ? '我的收藏' : '收藏夹',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.t1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${favs.length}',
                style: Ty.tiny.copyWith(
                  color: C.amber,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (compact)
                GestureDetector(
                  onTap: () => Get.to(() => const ToolFavPage()),
                  child: Row(
                    children: [
                      Text('全部', style: Ty.tiny.copyWith(color: C.amber)),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: C.amber,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _toolArea(favs, favOnly: true),
        ],
      ),
    );
  }

  /// 分类卡片：玻璃质感 + 渐变图标块
  Widget _groupCard(Map<String, dynamic> g) {
    final tools =
        (g['tools'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    if (tools.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.fromLTRB(
        context.pagePadding,
        3,
        context.pagePadding,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _catHead(g, tools.length),
          const SizedBox(height: 10),
          _toolArea(tools),
        ],
      ),
    );
  }

  /// 分类标题：渐变竖条 + 标题 + 数量 + 副标
  Widget _catHead(Map<String, dynamic> g, int count) {
    final title = '${g['title'] ?? ''}';
    final hint = '${g['hint'] ?? ''}';
    return Row(
      children: [
        // 渐变图标块
        Container(
          width: Ad.s(context, 38),
          height: Ad.s(context, 38),
          decoration: BoxDecoration(
            gradient: Deco.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(ToolIcons.cat(title), size: 20, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.t1,
                  letterSpacing: -0.2,
                ),
              ),
              if (hint.isNotEmpty)
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(context.isDark ? 30 : 14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: C.brand,
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolArea(List<Map<String, dynamic>> tools, {bool favOnly = false}) {
    if (tools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            favOnly ? '收藏里暂时没有这些工具' : '暂无工具',
            style: Ty.tiny.copyWith(color: context.t3),
          ),
        ),
      );
    }
    if (favOnly) return _iconGrid(tools);
    switch (_layout) {
      case 'card':
        return _bigCardList(tools);
      case 'compact':
        return _compactGrid(tools);
      case 'banner':
        return _bannerList(tools);
      default:
        return _iconGrid(tools);
    }
  }

  /// ① 图标网格（默认）：四列 + 圆角渐变图标块
  /// ★★★ 1015 致命性能修复：原来用 GridView.builder(shrinkWrap:true) 嵌在外层
  ///   ListView 里 —— shrinkWrap 会强制「一次性测量所有子项」，
  ///   34 个分类 × 最多 41 个工具 = 上千次布局 → 进页面直接卡死。
  ///   改用 Wrap（按行流式布局，不预计算），性能提升几十倍。
  Widget _iconGrid(List<Map<String, dynamic>> tools) {
    final n = Ad.columns(context, minItem: 82, max: 5);
    final w =
        (MediaQuery.of(context).size.width -
            context.pagePadding * 2 -
            8 * (n - 1)) /
        n;
    return Wrap(
      spacing: 8,
      runSpacing: 14,
      children: tools.map<Widget>((t) {
        final fav = _favIds.contains(int.tryParse('${t['id']}') ?? 0);
        return SizedBox(
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AppPressable(
                onTap: () => _open(t),
                onLongPress: () => _toggleFav(t),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: Ad.s(context, 52),
                      height: Ad.s(context, 52),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? Colors.white.withAlpha(16)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        // ★ 1015 性能：小图标不加阴影（302 个工具 = 302 次阴影计算，
                        //   GPU 密集 → 滚动卡顿）。用 1px 描边代替，视觉差异很小。
                        border: Border.all(
                          color: fav
                              ? C.amber.withAlpha(160)
                              : (context.isDark
                                    ? Colors.white10
                                    : Colors.black.withAlpha(8)),
                          width: fav ? 1.4 : 1,
                        ),
                      ),
                      child: _icon(t, 25),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${t['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: fav ? FontWeight.w800 : FontWeight.w600,
                        color: context.t2,
                      ),
                    ),
                  ],
                ),
              ),
              // ★ 1020（反馈 #5）：星标 —— 一眼看出收藏了哪些，点一下即可取消
              Positioned(
                right: -2,
                top: -4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleFav(t),
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fav
                          ? C.amber
                          : (context.isDark
                                ? const Color(0xFF2B2F3A)
                                : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: fav
                            ? Colors.white.withAlpha(210)
                            : (context.isDark
                                  ? Colors.white24
                                  : Colors.black.withAlpha(14)),
                        width: 1,
                      ),
                      boxShadow: fav
                          ? [
                              BoxShadow(
                                color: C.amber.withAlpha(90),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      fav ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 13,
                      color: fav ? Colors.white : context.t3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// ② 大卡列表：单列 + 图标 + 标题副标 + 箭头
  Widget _bigCardList(List<Map<String, dynamic>> tools) {
    return Column(
      children: tools.map<Widget>((t) {
        final sub = '${t['subtitle'] ?? ''}';
        final fav = _favIds.contains(int.tryParse('${t['id']}') ?? 0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: AppPressable(
            onTap: () => _open(t),
            onLongPress: () => _toggleFav(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(context.isDark ? 45 : 10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: Ad.s(context, 42),
                    height: Ad.s(context, 42),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(context.isDark ? 34 : 14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: _icon(t, 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${t['title'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.t1,
                          ),
                        ),
                        if (sub.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ty.tiny.copyWith(
                                fontSize: 11,
                                color: context.t3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleFav(t),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6, right: 2),
                      child: Icon(
                        fav ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 20,
                        color: fav ? C.amber : context.t3,
                      ),
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
          ),
        );
      }).toList(),
    );
  }

  /// ③ 紧凑宫格：五列小图标，密度最高
  Widget _compactGrid(List<Map<String, dynamic>> tools) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: tools.map<Widget>((t) {
        return AppPressable(
          onTap: () => _open(t),
          child: Container(
            width: Ad.s(context, 58),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withAlpha(10) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _icon(t, 20),
                const SizedBox(height: 5),
                Text(
                  '${t['title'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.t2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// ④ 分类横幅：每工具一条通栏
  Widget _bannerList(List<Map<String, dynamic>> tools) {
    return Column(
      children: tools.map<Widget>((t) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: AppPressable(
            onTap: () => _open(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: context.isDark
                      ? [Colors.white.withAlpha(14), Colors.white.withAlpha(6)]
                      : [C.brand.withAlpha(10), C.brand.withAlpha(3)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  _icon(t, 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${t['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: C.brand),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// emoji 优先，否则内置图标表
  Widget _icon(Map<String, dynamic> t, double size) {
    final icon = '${t['icon'] ?? ''}';
    if (icon.isNotEmpty && icon.runes.first > 0x2000) {
      return Text(icon, style: TextStyle(fontSize: size * 0.92));
    }
    return Icon(
      ToolIcons.of('${t['kind'] ?? ''}', '${t['route'] ?? ''}'),
      size: size,
      color: C.brand,
    );
  }

  // ═══════════ 打开工具 ═══════════

  /// ★ 1015：判断这个 URL 更像「数据接口」还是「网页」
  ///   数据接口特征：含 /api/、返回 json、是已知 API 域
  static bool _looksLikePage(String url) {
    final u = url.toLowerCase();
    // 明显是 API 的
    if (u.contains('/api/') || u.contains('api.') || u.endsWith('.json'))
      return false;
    // 明显是网页的
    if (u.endsWith('.html') || u.endsWith('.htm') || u.endsWith('/'))
      return true;
    // 其他：当作网页（保守）
    return true;
  }

  void openTool(Map<String, dynamic> t) {
    final id = int.tryParse('${t['id']}') ?? 0;
    if (id > 0) _svc.addHistory(id);
    final kind = '${t['kind'] ?? ''}';
    final route = '${t['route'] ?? ''}';
    final title = '${t['title'] ?? ''}';
    final target = '${t['target'] ?? ''}';
    final apiUrl = '${t['api_url'] ?? ''}';

    final fn = toolRoute(kind, route: route);
    if (fn != null) {
      fn(title: title, apiUrl: apiUrl);
      return;
    }
    // ★ 1015：三类兜底，优先级从高到低
    //   ① 配了 api_url（不论 api_path 是否为空）→ 通用接口工具
    //   ② 配了外部链接 target → App 内 WebView 打开
    //   ③ 都没配 → 给可操作的提示
    //
    // ★★★ 1015 致命修复：原来要求 apiPath 非空才走接口页。
    //   但「毒鸡汤/彩虹屁/今日诗词/北京天气」这些单条工具后台没填 api_path，
    //   于是掉进第②条 → **用 WebView 打开一个 JSON API 地址** → 卡死闪退！
    //   api_path 为空时应走「单条模式」（ApiToolPage 内部已支持自动识别）。
    final apiPath = '${t['api_path'] ?? ''}';
    final isApiTool =
        kind == 'apitool' ||
        (apiUrl.startsWith('http') && !_looksLikePage(apiUrl));
    if (apiUrl.startsWith('http') && (apiPath.isNotEmpty || isApiTool)) {
      Get.to(
        () => ApiToolPage(
          title: title,
          apiUrl: apiUrl,
          cfg: {
            'api_path': apiPath,
            'f_title': '${t['f_title'] ?? ''}',
            'f_sub': '${t['f_sub'] ?? ''}',
            'f_image': '${t['f_image'] ?? ''}',
            'f_link': '${t['f_link'] ?? ''}',
            'f_extra': '${t['f_extra'] ?? ''}',
          },
        ),
      );
      return;
    }
    final link = target.isNotEmpty ? target : apiUrl;
    if (link.startsWith('http')) {
      Get.to(() => ToolBrowserPage(title: title, url: link));
      return;
    }
    // 内置页未命中且没配链接 —— 给出可操作的提示，而不是只说「未开放」
    ToastUtil.info('「$title」未配置打开方式（后台填 kind 或外部链接）');
  }

  void _open(Map<String, dynamic> t) {
    // ★ 1015：打开工具前先上报 —— Native 崩溃抓不到堆栈，
    //   但「最后一条准备打开记录」就能指出是哪个工具导致的闪退
    try {
      SoftService.reportLogStatic(
        tag: 'open',
        error:
            '[open] ${t['title']} kind=${t['kind']} url=${t['api_url'] ?? t['target'] ?? ''}',
      ).catchError((_) {});
    } catch (_) {}
    openTool(t);
  }

  // ═══════════ 布局切换 ═══════════
}

// ═══════════════════ 搜索页 ═══════════════════

class ToolSearchPage extends StatefulWidget {
  const ToolSearchPage({super.key});

  @override
  State<ToolSearchPage> createState() => _ToolSearchPageState();
}

class _ToolSearchPageState extends State<ToolSearchPage> {
  final _svc = ToolboxService.instance;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 本地搜索：从已缓存的工具目录过滤（零延迟、离线可用）
  List<Map<String, dynamic>> _local(String kw) {
    final groups = (_svc.cachedConfig?['groups'] as List?) ?? [];
    final out = <Map<String, dynamic>>[];
    for (final g in groups) {
      if (g is! Map) continue;
      for (final t in ((g['tools'] as List?) ?? [])) {
        if (t is Map) {
          final title = '${t['title'] ?? ''}';
          final sub = '${t['subtitle'] ?? ''}';
          if (title.contains(kw) || sub.contains(kw)) {
            out.add(Map<String, dynamic>.from(t));
          }
        }
      }
    }
    return out;
  }

  Future<void> _do(String v) async {
    final kw = v.trim();
    if (kw.isEmpty) {
      setState(() {
        _list = [];
        _searched = false;
      });
      return;
    }
    final local = _local(kw);
    setState(() {
      _list = local;
      _searched = true;
      _loading = local.isEmpty;
    });
    if (local.isNotEmpty) return;
    final r = await _svc.search(kw);
    if (!mounted) return;
    setState(() {
      _list = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '搜索工具',
      child: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withAlpha(10) : Colors.white,
              borderRadius: BorderRadius.circular(R.full),
              border: Border.all(
                color: context.isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: context.t3),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _do,
                    onSubmitted: _do,
                    style: TextStyle(fontSize: 14.5, color: context.t1),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '搜工具名或功能，如「翻译」「壁纸」',
                      hintStyle: TextStyle(fontSize: 13.5, color: context.t3),
                    ),
                  ),
                ),
                if (_ctrl.text.isNotEmpty)
                  AppPressable(
                    onTap: () {
                      _ctrl.clear();
                      _do('');
                    },
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: context.t3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingState(text: '搜索中…');
    if (!_searched) {
      return EmptyState(
        icon: Icons.search_rounded,
        text: '输入关键词搜索工具',
        hint: '共 ${_svc.cachedConfig?['total'] ?? 0} 个工具可用',
      );
    }
    if (_list.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        text: '没有找到相关工具',
        hint: '换个关键词试试',
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (c, i) => _tile(_list[i]),
    );
  }

  void _openTool(Map<String, dynamic> t) {
    final fn = toolRoute('${t['kind'] ?? ''}', route: '${t['route'] ?? ''}');
    if (fn != null) {
      fn(title: '${t['title'] ?? ''}', apiUrl: '${t['api_url'] ?? ''}');
      return;
    }
    // ★ 1015：与主页一致 —— 通用接口 / 外链 / 提示
    final target = '${t['target'] ?? ''}';
    final api = '${t['api_url'] ?? ''}';
    final ap = '${t['api_path'] ?? ''}';
    if (api.startsWith('http') && ap.isNotEmpty) {
      Get.to(
        () => ApiToolPage(
          title: '${t['title'] ?? ''}',
          apiUrl: api,
          cfg: {
            'api_path': ap,
            'f_title': '${t['f_title'] ?? ''}',
            'f_sub': '${t['f_sub'] ?? ''}',
            'f_image': '${t['f_image'] ?? ''}',
            'f_link': '${t['f_link'] ?? ''}',
            'f_extra': '${t['f_extra'] ?? ''}',
          },
        ),
      );
      return;
    }
    final link = target.isNotEmpty ? target : api;
    if (link.startsWith('http')) {
      Get.to(() => ToolBrowserPage(title: '${t['title'] ?? ''}', url: link));
      return;
    }
    ToastUtil.info('「${t['title']}」暂未开放');
  }

  Widget _tile(Map<String, dynamic> t) {
    final icon = '${t['icon'] ?? ''}';
    final isEmoji = icon.isNotEmpty && icon.runes.first > 0x2000;
    return ToolCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _openTool(t),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: C.brand.withAlpha(20),
              borderRadius: BorderRadius.circular(R.md),
            ),
            alignment: Alignment.center,
            child: isEmoji
                ? Text(icon, style: const TextStyle(fontSize: 21))
                : Icon(
                    ToolIcons.of('${t['kind'] ?? ''}'),
                    size: 22,
                    color: C.brand,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t['title'] ?? ''}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.t1,
                  ),
                ),
                if ('${t['subtitle'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${t['subtitle']} · ${t['cat'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.tiny.copyWith(color: context.t3),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.t3),
        ],
      ),
    );
  }
}

// ═══════════════════ 收藏页 ═══════════════════

/// 我的收藏
///
/// ★ 1020（反馈 #5）重做：
///   - 原版是一个「图标 + 标题 + ☆」的朴素列表，和工具页风格完全脱节
///   - 现在：渐变头卡（收藏数 / 分类数）+ 分组宫格 + 滑动删除 + 长按快捷操作
///   - 顶部可直接搜索收藏，空了给可行动的引导（去工具箱逛逛）
class ToolFavPage extends StatefulWidget {
  const ToolFavPage({super.key});

  @override
  State<ToolFavPage> createState() => _ToolFavPageState();
}

class _ToolFavPageState extends State<ToolFavPage> {
  final _svc = ToolboxService.instance;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String _kw = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _svc.favList();
    if (!mounted) return;
    setState(() {
      _list = r;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _shown {
    if (_kw.isEmpty) return _list;
    final k = _kw.toLowerCase();
    return _list.where((t) {
      final s =
          '${t['title'] ?? ''}${t['subtitle'] ?? ''}'
                  '${t['cat'] ?? ''}${t['category'] ?? ''}'
              .toLowerCase();
      return s.contains(k);
    }).toList();
  }

  void _open(Map<String, dynamic> t) {
    final fn = toolRoute('${t['kind'] ?? ''}', route: '${t['route'] ?? ''}');
    if (fn != null) {
      fn(title: '${t['title'] ?? ''}', apiUrl: '${t['api_url'] ?? ''}');
      return;
    }
    final api = '${t['api_url'] ?? ''}';
    final ap = '${t['api_path'] ?? ''}';
    if (api.startsWith('http') && ap.isNotEmpty) {
      Get.to(
        () => ApiToolPage(
          title: '${t['title'] ?? ''}',
          apiUrl: api,
          cfg: {
            'api_path': ap,
            'f_title': '${t['f_title'] ?? ''}',
            'f_sub': '${t['f_sub'] ?? ''}',
            'f_image': '${t['f_image'] ?? ''}',
            'f_link': '${t['f_link'] ?? ''}',
            'f_extra': '${t['f_extra'] ?? ''}',
          },
        ),
      );
      return;
    }
    final target = '${t['target'] ?? ''}';
    final link = target.isNotEmpty ? target : api;
    if (link.startsWith('http')) {
      Get.to(() => ToolBrowserPage(title: '${t['title'] ?? ''}', url: link));
      return;
    }
    ToastUtil.info('「${t['title'] ?? ''}」暂未开放');
  }

  Future<void> _unfav(Map<String, dynamic> t) async {
    final id = int.tryParse('${t['id']}') ?? 0;
    if (id <= 0) return;
    setState(() => _list.removeWhere((e) => '${e['id']}' == '$id'));
    try {
      await _svc.toggleFav(id);
      ToolCache.write('jzs_fav_dirty', {
        't': DateTime.now().millisecondsSinceEpoch,
      });
      ToastUtil.success('已取消收藏');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '我的收藏',
      subtitle: _list.isEmpty ? '还没有收藏' : '共 ${_list.length} 个工具',
      child: _loading
          ? const LoadingState(text: '加载收藏…')
          : (_list.isEmpty ? _empty() : _content()),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    C.amber.withAlpha(context.isDark ? 60 : 40),
                    C.brand.withAlpha(context.isDark ? 40 : 24),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.star_border_rounded, size: 44, color: C.amber),
            ),
            const SizedBox(height: 18),
            Text(
              '还没有收藏任何工具',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.t1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '在工具箱里长按任意工具，\n或者点图标右上角的星标即可收藏',
              textAlign: TextAlign.center,
              style: Ty.small.copyWith(color: context.t3, height: 1.6),
            ),
            const SizedBox(height: 22),
            SoftButton(
              label: '去工具箱逛逛',
              icon: Icons.widgets_rounded,
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final shown = _shown;
    final cats = <String>{};
    for (final t in _list) {
      final c = '${t['cat'] ?? t['category'] ?? ''}';
      if (c.isNotEmpty) cats.add(c);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 24),
        children: [
          _hero(cats.length),
          const SizedBox(height: 14),
          _searchBar(),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Center(
                child: Text(
                  '没有匹配的收藏',
                  style: Ty.small.copyWith(color: context.t3),
                ),
              ),
            )
          else
            ...shown.map(_favTile),
        ],
      ),
    );
  }

  /// 渐变头卡：收藏数 / 分类数
  Widget _hero(int catCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? [const Color(0xFF2B2140), const Color(0xFF1A1D2A)]
              : [const Color(0xFFFFF3DC), const Color(0xFFF4F6FF)],
        ),
        border: Border.all(
          color: C.amber.withAlpha(context.isDark ? 60 : 50),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: C.amber.withAlpha(context.isDark ? 24 : 22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFC24B), Color(0xFFFF9F43)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: C.amber.withAlpha(110),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.star_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_list.length}',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: context.t1,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '个收藏',
                      style: Ty.small.copyWith(
                        color: context.t2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  catCount > 0 ? '分布在 $catCount 个分类里' : '长按工具可快速收藏/取消',
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withAlpha(14) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: context.isDark ? Colors.white10 : Colors.black.withAlpha(8),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: context.t3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _kw = v.trim()),
              style: TextStyle(fontSize: 13.5, color: context.t1),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '搜索收藏的工具',
                hintStyle: TextStyle(fontSize: 13, color: context.t3),
              ),
            ),
          ),
          if (_kw.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _kw = ''),
              child: Icon(Icons.close_rounded, size: 16, color: context.t3),
            ),
        ],
      ),
    );
  }

  Widget _favTile(Map<String, dynamic> t) {
    final icon = '${t['icon'] ?? ''}';
    final isEmoji = icon.isNotEmpty && icon.runes.first > 0x2000;
    final sub = '${t['subtitle'] ?? ''}';
    final cat = '${t['cat'] ?? t['category'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Dismissible(
        key: ValueKey('fav_${t['id']}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: C.danger,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        onDismissed: (_) => _unfav(t),
        child: AppPressable(
          onTap: () => _open(t),
          onLongPress: () => _unfav(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withAlpha(12) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.isDark
                    ? Colors.white10
                    : Colors.black.withAlpha(7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(context.isDark ? 45 : 10),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        C.brand.withAlpha(context.isDark ? 46 : 20),
                        C.accent.withAlpha(context.isDark ? 30 : 12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: isEmoji
                      ? Text(icon, style: const TextStyle(fontSize: 21))
                      : Icon(
                          ToolIcons.of('${t['kind'] ?? ''}'),
                          size: 22,
                          color: C.brand,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${t['title'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: context.t1,
                        ),
                      ),
                      if (sub.isNotEmpty || cat.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            sub.isNotEmpty
                                ? (cat.isNotEmpty ? '$sub · $cat' : sub)
                                : cat,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.tiny.copyWith(color: context.t3),
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _unfav(t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.star_rounded, size: 22, color: C.amber),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
