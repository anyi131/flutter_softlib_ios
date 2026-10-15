import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/toolbox_service.dart';
import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';
import '../../widgets/tab_bottom_pad.dart';
import 'tool_kit.dart';
import 'tool_api_page.dart';
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
  String _layout = 'flow';

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
      var layout = '${cfg['default_style'] ?? 'flow'}';
      if (!['flow', 'square', 'circle', 'card', 'two'].contains(layout)) layout = 'flow';
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
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final cfg = await _svc.fetchConfig(force: true);
      if (!mounted) return;
      final groups =
          (cfg?['groups'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      var layout = '${cfg?['default_style'] ?? 'flow'}';
      if (!['flow', 'square', 'circle', 'card', 'two'].contains(layout)) layout = 'flow';
      setState(() {
        _groups = groups;
        _meta = cfg ?? {};
        _layout = layout;
        _loading = false;
        _err = groups.isEmpty ? '工具目录为空，请稍后重试' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
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

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        14,
        context.pagePadding - 10,
        6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('工具箱', style: Ty.display.copyWith(color: context.t1)),
                const SizedBox(height: 4),
                Text(
                  '共 ${_meta['total'] ?? _count} 个实用小工具',
                  style: Ty.small.copyWith(color: context.t3),
                ),
              ],
            ),
          ),
          _topIcon(
            Icons.search_rounded,
            '搜索',
            () => Get.to(() => const ToolSearchPage()),
          ),
          _topIcon(Icons.grid_view_rounded, '布局', _pickLayout),
          _topIcon(
            Icons.star_outline_rounded,
            '收藏',
            () => Get.to(() => const ToolFavPage()),
          ),
        ],
      ),
    );
  }

  Widget _topIcon(IconData icon, String tip, VoidCallback onTap) => Tooltip(
    message: tip,
    child: AppPressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: context.t1),
      ),
    ),
  );

  // ═══════════ 分类卡 ═══════════

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
        6,
        context.pagePadding,
        8,
      ),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(R.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(context.isDark ? 44 : 12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _catHead(g, tools.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: _toolArea(tools),
          ),
        ],
      ),
    );
  }

  Widget _catHead(Map<String, dynamic> g, int count) {
    final title = '${g['title'] ?? ''}';
    final hint = '${g['hint'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: C.brand.withAlpha(context.isDark ? 34 : 20),
              borderRadius: BorderRadius.circular(R.md),
            ),
            alignment: Alignment.center,
            child: Icon(ToolIcons.cat(title), size: 25, color: C.brand),
          ),
          const SizedBox(width: 13),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.t1,
                  ),
                ),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.tiny.copyWith(
                      fontSize: 11.5,
                      color: context.t3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: C.brand.withAlpha(context.isDark ? 34 : 18),
              borderRadius: BorderRadius.circular(R.full),
            ),
            child: Text(
              '$count 个',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: C.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolArea(List<Map<String, dynamic>> tools) {
    switch (_layout) {
      case 'square':
        return _grid(tools, circle: false);
      case 'circle':
        return _grid(tools, circle: true);
      // ★ 1015：新增两种真正的骨架差异布局
      case 'card':
        return _bigCardList(tools);   // 大卡列表：单列、图标+标题+副标题+箭头
      case 'two':
        return _twoColumn(tools);     // 双列卡片：两列、图标上标题下
      default:
        return Wrap(
          spacing: 8,
          runSpacing: 9,
          children: tools.map<Widget>(_chip).toList(),
        );
    }
  }

  /// ★ 1015 新布局①：大卡列表
  ///   骨架特征：单列铺满、左侧大图标块 + 中间标题/副标题 + 右侧箭头
  ///   和「胶囊流式」的区别：一行一个、有副标题、可按压整行
  Widget _bigCardList(List<Map<String, dynamic>> tools) {
    return Column(
      children: tools.map<Widget>((t) {
        final sub = '${t['subtitle'] ?? ''}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppPressable(
            onTap: () => _open(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: C.brand.withAlpha(context.isDark ? 18 : 8),
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(context.isDark ? 32 : 16),
                      borderRadius: BorderRadius.circular(R.sm),
                    ),
                    child: _icon(t, 21),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t['title'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: context.t1,
                          ),
                        ),
                        if (sub.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.tiny.copyWith(color: context.t3),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: context.t3),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// ★ 1015 新布局②：双列卡片
  ///   骨架特征：两列网格、图标在上标题在下、每格是独立卡片
  ///   和「方形宫格」的区别：只两列（不是四列）、有卡片背景、横向更宽
  Widget _twoColumn(List<Map<String, dynamic>> tools) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tools.map<Widget>((t) {
            return SizedBox(
              width: w,
              child: AppPressable(
                onTap: () => _open(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: C.brand.withAlpha(context.isDark ? 18 : 8),
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.brand.withAlpha(context.isDark ? 32 : 16),
                          borderRadius: BorderRadius.circular(R.sm),
                        ),
                        child: _icon(t, 19),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${t['title'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.t1,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// 胶囊（flow 布局，样本同款）
  Widget _chip(Map<String, dynamic> t) => AppPressable(
    onTap: () => _open(t),
    child: Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 14, 8),
      decoration: BoxDecoration(
        color: C.brand.withAlpha(context.isDark ? 26 : 12),
        borderRadius: BorderRadius.circular(R.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(t, 20),
          const SizedBox(width: 7),
          Text(
            '${t['title'] ?? ''}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.t1,
            ),
          ),
        ],
      ),
    ),
  );

  /// 宫格（square / circle 布局）
  Widget _grid(List<Map<String, dynamic>> tools, {required bool circle}) {
    final w =
        (MediaQuery.of(context).size.width -
            context.pagePadding * 2 -
            28) /
        4;
    return Wrap(
      spacing: 6,
      runSpacing: 14,
      children: tools
          .map<Widget>(
            (t) => SizedBox(
              width: w,
              child: AppPressable(
                onTap: () => _open(t),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: C.brand.withAlpha(context.isDark ? 30 : 14),
                        shape: circle ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: circle
                            ? null
                            : BorderRadius.circular(R.md),
                      ),
                      alignment: Alignment.center,
                      child: _icon(t, 23),
                    ),
                    const SizedBox(height: 6),
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
            ),
          )
          .toList(),
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
    //   ① 配了 api_url + api_path → 通用接口工具（后台配参数就能出工具）
    //   ② 配了外部链接 → App 内 WebView 打开（不跳浏览器，自带广告清理）
    //   ③ 都没配 → 给可操作的提示
    final apiPath = '${t['api_path'] ?? ''}';
    if (apiUrl.startsWith('http') && apiPath.isNotEmpty) {
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
        blockAds: '${t['block_ads'] ?? 1}' != '0',
      ));
      return;
    }
    // 内置页未命中且没配链接 —— 给出可操作的提示，而不是只说「未开放」
    ToastUtil.info('「$title」未配置打开方式（后台填 kind 或外部链接）');
  }

  void _open(Map<String, dynamic> t) => openTool(t);

  // ═══════════ 布局切换 ═══════════

  Future<void> _pickLayout() async {
    const opts = <(String, String, IconData)>[
      ('flow', '胶囊流式', Icons.view_stream_rounded),
      ('card', '大卡列表', Icons.list_alt_rounded),
      ('two', '双列卡片', Icons.grid_view_rounded),
      ('square', '方形宫格', Icons.grid_view_rounded),
      ('circle', '圆形宫格', Icons.apps_rounded),
    ];
    final r = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('列表样式', style: Ty.h3.copyWith(color: context.t1)),
            ),
            for (final o in opts)
              InkWell(
                onTap: () => Navigator.pop(c, o.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(o.$3, size: 19, color: context.t2),
                      const SizedBox(width: 12),
                      Text(
                        o.$2,
                        style: TextStyle(fontSize: 14.5, color: context.t1),
                      ),
                      const Spacer(),
                      Icon(
                        _layout == o.$1
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 21,
                        color: _layout == o.$1 ? C.brand : context.t3,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (r != null && mounted) setState(() => _layout = r);
  }
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
        blockAds: '${t['block_ads'] ?? 1}' != '0',
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
