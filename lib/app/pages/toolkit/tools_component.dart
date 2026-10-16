import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/soft_service.dart' show SoftService;
import '../../api/toolbox_service.dart';
import '../../design/ad.dart';
import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
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

  @override
  void initState() {
    super.initState();
    // ★ 1015 修复：工具 Tab 常驻不重建，原来只在 initState 拉一次目录，
    //   后台新增/改动的工具在 App 里永远看不到。
    //   现在回到前台（从后台管理页切回）自动静默刷新一次。
    WidgetsBinding.instance.addObserver(this);
    _load();
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
      if (!['grid', 'card', 'compact', 'banner'].contains(layout)) layout = 'grid';
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
        (cfg['groups'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    var layout = '${cfg['default_style'] ?? 'grid'}';
    if (!['grid', 'card', 'compact', 'banner'].contains(layout)) layout = 'grid';
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
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.only(
                                    top: 4,
                                    bottom: tabBottomPadding(context) + 24,
                                  ),
                                  itemCount: _groups.length,
                                  itemBuilder: (c, i) => _groupCard(_groups[i]),
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
              _actionBtn(Icons.search_rounded, '搜索', () => Get.to(() => const ToolSearchPage())),
              const SizedBox(width: 8),
              _actionBtn(Icons.star_rounded, '收藏', () => Get.to(() => const ToolFavPage())),
            ],
          ),
        ],
      ),
    );
  }

  /// 圆形玻璃操作按钮
  Widget _actionBtn(IconData icon, String tip, VoidCallback onTap) => Tooltip(
    message: tip,
    child: AppPressable(
      onTap: onTap,
      child: Container(
        width: Ad.s(context, 42),
        height: Ad.s(context, 42),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withAlpha(16) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(context.isDark ? 60 : 16),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: context.t1),
      ),
    ),
  );

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

  Widget _toolArea(List<Map<String, dynamic>> tools) {
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
    final w = (MediaQuery.of(context).size.width -
            context.pagePadding * 2 -
            8 * (n - 1)) /
        n;
    return Wrap(
      spacing: 8,
      runSpacing: 14,
      children: tools.map<Widget>((t) {
        return SizedBox(
          width: w,
          child: AppPressable(
          onTap: () => _open(t),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: Ad.s(context, 52),
                height: Ad.s(context, 52),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withAlpha(16) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  // ★ 1015 性能：小图标不加阴影（302 个工具 = 302 次阴影计算，
                  //   GPU 密集 → 滚动卡顿）。用 1px 描边代替，视觉差异很小。
                  border: Border.all(
                    color: context.isDark ? Colors.white10 : Colors.black.withAlpha(8),
                    width: 1,
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

  /// ② 大卡列表：单列 + 图标 + 标题副标 + 箭头
  Widget _bigCardList(List<Map<String, dynamic>> tools) {
    return Column(
      children: tools.map<Widget>((t) {
        final sub = '${t['subtitle'] ?? ''}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: AppPressable(
            onTap: () => _open(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: context.isDark ? Colors.white.withAlpha(12) : Colors.white,
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
                              style: Ty.tiny.copyWith(fontSize: 11, color: context.t3),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: context.t3),
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
    if (u.contains('/api/') || u.contains('api.') || u.endsWith('.json')) return false;
    // 明显是网页的
    if (u.endsWith('.html') || u.endsWith('.htm') || u.endsWith('/')) return true;
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
    final isApiTool = kind == 'apitool' || (apiUrl.startsWith('http') && !_looksLikePage(apiUrl));
    if (apiUrl.startsWith('http') && (apiPath.isNotEmpty || isApiTool)) {
      Get.to(() => ApiToolPage(
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
      ));
      return;
    }
    final link = target.isNotEmpty ? target : apiUrl;
    if (link.startsWith('http')) {
      Get.to(() => ToolBrowserPage(
        title: title,
        url: link,
      ));
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
        error: '[open] ${t['title']} kind=${t['kind']} url=${t['api_url'] ?? t['target'] ?? ''}',
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
      Get.to(() => ApiToolPage(
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
      ));
      return;
    }
    final link = target.isNotEmpty ? target : api;
    if (link.startsWith('http')) {
      Get.to(() => ToolBrowserPage(
        title: '${t['title'] ?? ''}',
        url: link,
      ));
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

class ToolFavPage extends StatefulWidget {
  const ToolFavPage({super.key});

  @override
  State<ToolFavPage> createState() => _ToolFavPageState();
}

class _ToolFavPageState extends State<ToolFavPage> {
  final _svc = ToolboxService.instance;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

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

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: '我的收藏',
      subtitle: '共 ${_list.length} 个',
      child: _loading
          ? const LoadingState(text: '加载收藏…')
          : (_list.isEmpty
                ? const EmptyState(
                    icon: Icons.star_border_rounded,
                    text: '还没有收藏任何工具',
                    hint: '在工具页点右上角☆可收藏',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: C.brand,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: _list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final t = _list[i];
                        final icon = '${t['icon'] ?? ''}';
                        final isEmoji =
                            icon.isNotEmpty && icon.runes.first > 0x2000;
                        return ToolCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          onTap: () {
                            final fn = toolRoute(
                              '${t['kind'] ?? ''}',
                              route: '${t['route'] ?? ''}',
                            );
                            if (fn != null) {
                              fn(
                                title: '${t['title'] ?? ''}',
                                apiUrl: '${t['api_url'] ?? ''}',
                              );
                            } else {
                              ToastUtil.info('「${t['title']}」暂未开放');
                            }
                          },
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
                                    ? Text(
                                        icon,
                                        style: const TextStyle(fontSize: 21),
                                      )
                                    : Icon(
                                        ToolIcons.of('${t['kind'] ?? ''}'),
                                        size: 22,
                                        color: C.brand,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${t['title'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.t1,
                                  ),
                                ),
                              ),
                              AppPressable(
                                onTap: () async {
                                  try {
                                    await _svc.toggleFav(
                                      int.tryParse('${t['id']}') ?? 0,
                                    );
                                    ToastUtil.success('已取消收藏');
                                    _load();
                                  } catch (e) {
                                    ToastUtil.error(
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    );
                                  }
                                },
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 22,
                                  color: C.amber,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )),
    );
  }
}
