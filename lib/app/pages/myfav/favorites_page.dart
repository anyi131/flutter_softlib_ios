import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/api_host.dart';
import '../../api/user_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../toolkit/tool_router.dart';
import '../toolkit/tool_api_page.dart';
import '../toolkit/tool_browser_page.dart';
import '../../utils/tool_ctx.dart';
import '../../routes/app_pages.dart';
import '../../utils/err_text.dart';
import '../../utils/toast_util.dart';

/// 我的收藏（统一收藏夹）
///
/// ★ 1020：原来软件收藏和工具收藏是两套，用户要跑两个地方找。
///   这里做成一个页面，分「软件 / 工具」两个 Tab。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 1),
  );

  bool _loading = true;
  List<Map<String, dynamic>> _software = [];
  List<Map<String, dynamic>> _tools = [];

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

  Dio get _dio => Dio(
    BaseOptions(
      baseUrl: ApiHost.base,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([_fetchSoftware(), _fetchTools()]);
    if (!mounted) return;
    setState(() {
      _software = results[0];
      _tools = results[1];
      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchSoftware() async {
    try {
      final r = await _dio.post(
        '/api/softlib/appfavlist',
        data: {'token': UserService.instance.token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        final list = (r.data['data']?['list'] as List?) ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[Fav] software: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchTools() async {
    try {
      final r = await _dio.post(
        '/api/softlib/jzs/fav_list',
        data: {'token': UserService.instance.token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        final list = (r.data['data']?['list'] as List?) ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[Fav] tools: $e');
    }
    return [];
  }

  Future<void> _unfavSoftware(Map<String, dynamic> a) async {
    final id = (a['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    setState(() => _software.removeWhere((e) => '${e['id']}' == '$id'));
    try {
      await _dio.post(
        '/api/softlib/appfav',
        data: {'app_id': id, 'token': UserService.instance.token},
      );
      ToastUtil.success('已取消收藏');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
      _load();
    }
  }

  Future<void> _unfavTool(Map<String, dynamic> t) async {
    final id = (t['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    setState(() => _tools.removeWhere((e) => '${e['id']}' == '$id'));
    try {
      await _dio.post(
        '/api/softlib/jzs/fav',
        data: {'tool_id': id, 'token': UserService.instance.token},
      );
      ToastUtil.success('已取消收藏');
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _software.length + _tools.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            child: Column(
              children: [
                _header(total),
                TabBar(
                  controller: _tab,
                  labelColor: C.brand,
                  unselectedLabelColor: context.t3,
                  indicatorColor: C.brand,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: '软件 ${_software.length}'),
                    Tab(text: '工具 ${_tools.length}'),
                  ],
                ),
                Expanded(
                  child: _loading
                      ? const LoadingState(text: '加载收藏…')
                      : TabBarView(
                          controller: _tab,
                          children: [_softwareList(), _toolList()],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(int total) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        8,
        context.pagePadding,
        4,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: context.t1,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '我的收藏',
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
              '$total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: C.brand,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, size: 19, color: context.t3),
          ),
        ],
      ),
    );
  }

  Widget _softwareList() {
    if (_software.isEmpty) {
      return _empty('还没有收藏软件', '在软件详情页点收藏即可加入这里');
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          10,
          context.pagePadding,
          24,
        ),
        itemCount: _software.length,
        itemBuilder: (c, i) => _appTile(_software[i]),
      ),
    );
  }

  Widget _toolList() {
    if (_tools.isEmpty) {
      return _empty('还没有收藏工具', '在工具箱长按任意工具即可收藏');
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: C.brand,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          10,
          context.pagePadding,
          24,
        ),
        itemCount: _tools.length,
        itemBuilder: (c, i) => _toolTile(_tools[i]),
      ),
    );
  }

  Widget _empty(String text, String hint) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  C.brand.withAlpha(context.isDark ? 55 : 30),
                  C.accent.withAlpha(context.isDark ? 35 : 18),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.star_border_rounded, size: 38, color: C.amber),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.t1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: Ty.small.copyWith(color: context.t3, height: 1.6),
          ),
        ],
      ),
    ),
  );

  Widget _appTile(Map<String, dynamic> a) {
    final icon = '${a['icon'] ?? ''}';
    final vip = a['is_vip'] == true;
    return _tile(
      leading: icon.isEmpty
          ? Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: C.brand.withAlpha(20),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.android, color: C.brand, size: 22),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: CachedNetworkImage(
                imageUrl: icon,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 46,
                  height: 46,
                  color: C.brand.withAlpha(20),
                  child: Icon(Icons.android, color: C.brand, size: 22),
                ),
              ),
            ),
      title: '${a['title'] ?? ''}',
      subtitle: [
        if ('${a['size'] ?? ''}'.isNotEmpty) '${a['size']}',
        if ('${a['version'] ?? ''}'.isNotEmpty) 'v${a['version']}',
        if (vip) '会员专享',
      ].join(' · '),
      onTap: () =>
          Get.toNamed(Routes.appDetails, arguments: {'appId': '${a['id']}'}),
      onUnfav: () => _unfavSoftware(a),
    );
  }

  /// 打开工具（真正跳转，不再只弹提示）
  ///
  /// ★ 1020：原来收藏页点工具只弹「请在工具箱中打开」，
  ///   用户根本打不开 —— 等于收藏没用。
  ///   现在复用 toolRoute 直接进工具页，并设置 ToolCtx 让工具页能显示收藏星标。
  void _openTool(Map<String, dynamic> t) {
    final id = (t['id'] as num?)?.toInt() ?? 0;
    final kind = '${t['kind'] ?? ''}';
    final route = '${t['route'] ?? ''}';
    final title = '${t['title'] ?? ''}';
    final apiUrl = '${t['api_url'] ?? ''}';

    ToolCtx.set(id, title);

    final fn = toolRoute(kind, route: route);
    if (fn != null) {
      fn(title: title, apiUrl: apiUrl);
      return;
    }
    // 兜底：外部链接 / 通用接口
    final target = '${t['target'] ?? ''}';
    final apiPath = '${t['api_path'] ?? ''}';
    if (apiUrl.startsWith('http') && apiPath.isNotEmpty) {
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
    ToastUtil.info('「$title」暂未开放');
  }

  Widget _toolTile(Map<String, dynamic> t) {
    final icon = '${t['icon'] ?? ''}';
    final isEmoji = icon.isNotEmpty && icon.runes.first > 0x2000;
    return _tile(
      leading: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              C.brand.withAlpha(context.isDark ? 46 : 20),
              C.accent.withAlpha(context.isDark ? 30 : 12),
            ],
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: isEmoji
            ? Text(icon, style: const TextStyle(fontSize: 21))
            : Icon(Icons.widgets_rounded, size: 21, color: C.brand),
      ),
      title: '${t['title'] ?? ''}',
      subtitle: '${t['subtitle'] ?? t['cat'] ?? ''}',
      onTap: () => _openTool(t),
      onUnfav: () => _unfavTool(t),
    );
  }

  Widget _tile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onUnfav,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Dismissible(
        key: ValueKey('$title${subtitle.hashCode}'),
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
        onDismissed: (_) => onUnfav(),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withAlpha(12) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.isDark
                    ? Colors.white10
                    : Colors.black.withAlpha(7),
              ),
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: context.t1,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ty.tiny.copyWith(color: context.t3),
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onUnfav,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.star_rounded, size: 21, color: C.amber),
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
