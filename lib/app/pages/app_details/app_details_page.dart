import 'dart:typed_data';
import '../../api/api_http.dart';

import '../../design/app_anim.dart';
import '../../api/task_service.dart';
import '../../utils/err_text.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:flutter/material.dart';

import 'resolve_overlay.dart';

import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';

import '../../api/api_host.dart';
import '../../api/soft_service.dart';
import '../../api/user_service.dart';
import '../../api/unlock_service.dart';

import 'dart:ui';

import '../../config.dart';
import '../../design/glass_theme.dart';
import '../../design/adaptive.dart';
import '../../design/app_style.dart';
import '../../design/app_style_controller.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../design/glass.dart';
import '../../utils/jump_util.dart';
import '../../utils/toast_util.dart';
import '../../models/app_item.dart';
import '../../models/http/results/lzy_file_info_model.dart';
import '../../routes/app_pages.dart';
import '../../widgets/review/review_tab.dart';
import 'app_details_logic.dart';
import 'detail_aurora.dart';
import 'detail_neon.dart';

/// 软件详情页
class AppDetailsPage extends StatefulWidget {
  const AppDetailsPage({super.key});

  @override
  State<AppDetailsPage> createState() => _AppDetailsPageState();
}

class _AppDetailsPageState extends State<AppDetailsPage>
    with SingleTickerProviderStateMixin {
  final AppDetailsLogic logic = Get.find<AppDetailsLogic>();
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    // ★ 1020：进页面就查一次收藏状态（顶栏星标亮不亮）
    _favIdsFuture = _loadFavIds();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  AppItem? get item => logic.item;

  /// 路由参数变了 → 原地重新加载（同一个控制器内完成）
  void _syncRouteArgs() {
    final args = Get.arguments;
    if (args is! Map) return;
    final want = int.tryParse('${args['appId'] ?? 0}') ?? 0;
    if (want <= 0) return;
    if (logic.appIdInt == want && logic.item != null) return;

    // 放到帧后执行，避免在 build 期间改状态
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 页面本地状态也要重置（简介折叠 / 收藏星标）
      setState(() {
        _descExpanded = false;
        _favIdsFuture = null;
      });
      await logic.reloadWith(args);
      if (!mounted) return;
      setState(() => _favIdsFuture = _loadFavIds());
    });
  }

  @override
  Widget build(BuildContext context) {
    // ★★ 1020：详情页内跳转（精品推荐 / 你可能还喜欢）时，
    //   GetX 会把同一个路由复用，控制器不重建、onInit 不再执行，
    //   结果新页面还是旧软件的数据。
    //   这里每次 build 比对「路由传入的 appId」和「控制器当前 appId」，
    //   不一致就原地重新加载 —— 不依赖 GetX 的路由复用行为。
    _syncRouteArgs();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          GetBuilder<AppDetailsLogic>(
            id: 'appInfo',
            builder: (logic) {
              // ★ 骨架屏：内容框架先占位，数据到了就地填充
              //   避免「空白转圈 → 内容」的突变闪烁
              if (logic.isLoadingInfo) {
                final topInset = MediaQuery.of(context).padding.top;
                return ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    topInset + 56,
                    context.pagePadding,
                    30,
                  ),
                  children: [
                    // 主卡（图标 + 标题 + 标签）
                    KitCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Skeleton(width: 76, height: 76, radius: R.lg),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Skeleton(width: 160, height: 17),
                                SizedBox(height: 10),
                                Skeleton(width: 110, height: 12),
                                SizedBox(height: 10),
                                Skeleton(width: 200, height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Skeleton(height: 68, radius: R.lg),
                    const SizedBox(height: 16),
                    const Skeleton(height: 40, radius: R.lg),
                    const SizedBox(height: 14),
                    const Skeleton(width: 120, height: 16),
                    const SizedBox(height: 12),
                    ...List.generate(
                      4,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Skeleton(height: 13),
                      ),
                    ),
                  ],
                );
              }
              if (logic.appInfo == null) {
                return ErrorState(
                  text: logic.msgError ?? '获取软件信息失败',
                  hint: '请检查网络连接后重试',
                  onRetry: logic.getAppInfo,
                );
              }
              // 顶部留白避开悬浮玻璃顶栏，避免主卡被遮挡
              final topInset = MediaQuery.of(context).padding.top;
              // v331j：Obx 包裹——后台切详情模板后（含 Get 路由复用实例）立即生效
              return Obx(
                () => ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    topInset + 56,
                    context.pagePadding,
                    30,
                  ),
                  children: _bodyChildren(context),
                ),
              );
            },
          ),
          // 顶部导航（玻璃）
          _topBar(),
        ],
      ),
      bottomNavigationBar: _bottom(),
    );
  }

  /// v53d：详情页 5 套大改版模板
  List<Widget> _bodyChildren(BuildContext context) {
    final tpl = AppStyleController.instance.detailStyle.value;
    final isDark = context.isDark;
    final tabArea = <Widget>[
      const SizedBox(height: 16),
      _tabBarCard(isDark),
      const SizedBox(height: 12),
      AnimatedBuilder(
        animation: _tab,
        builder: (context, _) =>
            _tab.index == 0 ? _detail(isDark) : ReviewTab(appId: item?.id ?? 0),
      ),
    ];
    switch (tpl) {
      case AppDetailStyle.poster:
        // 沉浸海报版：全屏头图打底 + 悬浮玻璃信息卡
        return [_hero(), const SizedBox(height: 14), _info(), ...tabArea];
      case AppDetailStyle.dark:
        // 暗黑影院版：深底整卡包裹
        return [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.bg0,
              borderRadius: BorderRadius.circular(R.xl),
              border: Border.all(color: C.brand.withAlpha(70)),
            ),
            child: Column(
              children: [_hero(), const SizedBox(height: 12), _info()],
            ),
          ),
          ...tabArea,
        ];
      case AppDetailStyle.minimal:
        // v54 极简文档版：无头图 + 扁平数据行（纯排版，无任何卡）
        return [_hero(), const SizedBox(height: 10), _infoFlat(), ...tabArea];
      case AppDetailStyle.compact:
        // v54 紧凑版：横向信息头条（无大头图，一行式骨架）
        return [
          _heroCompact(),
          const SizedBox(height: 10),
          _infoFlat(),
          const SizedBox(height: 12),
          _tabBarCard(isDark),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _tab,
            builder: (context, _) => _tab.index == 0
                ? _detail(isDark)
                : ReviewTab(appId: item?.id ?? 0),
          ),
        ];
      // ★ 1020 新增第 6 套：极光版（不改动上面 5 套的任何逻辑）
      case AppDetailStyle.aurora:
        return _auroraBody(isDark, tabArea);
      case AppDetailStyle.neon:
        return _neonBody(isDark, tabArea);
      default:
        return [_hero(), const SizedBox(height: 14), _info(), ...tabArea];
    }
  }

  // ═══════════ 新增模板共用：取通用展示数据 ═══════════

  ({String topLabel, String sizeText, String verText, List<String> shots})
  _tplData() {
    final it = item;
    final info = logic.appInfo;
    final isVipItem = it?.isVipItem ?? false;
    final hasP = it?.hasPrice ?? false;
    final priceTxt = it?.vipPrice ?? '';
    final topLabel = hasP ? '¥$priceTxt 购买' : (isVipItem ? '会员专享' : '免费下载');
    final sizeText = info?.fileSize ?? it?.size ?? '-';
    final verText = it?.version ?? '';
    final shots = (it?.screenshots ?? const <String>[])
        .where((e) => e.isNotEmpty)
        .toList();
    return (
      topLabel: topLabel,
      sizeText: sizeText,
      verText: verText,
      shots: shots,
    );
  }

  // ═══════════ 新模板共用：详情 Tab 内容 ═══════════
  //
  // ★★ 1020 修复「内容重复两遍」：
  //   `_detail()` 内部已经包含 软件介绍 + 应用截图 + 精品推荐 + 你可能还喜欢，
  //   上一版我在它外面又加了一遍 → 每块内容出现两次（用户截图实锤）。
  //   现在新模板自己拼 Tab：详情页里只放一次「截图 + 介绍」，
  //   推荐/你可能还喜欢只放在最外层一次。

  Widget _newTplTabArea(
    BuildContext context, {
    required bool isDark,
    required List<String> shots,
    required String desc,
    required Widget Function(String title, Widget? trailing) sectionHeader,
    required Widget Function() officialBadge,
    required Widget Function() shotsWidget,
    Color? accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tabBarCard(isDark, accent: accent),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _tab,
          builder: (c, _) {
            if (_tab.index != 0) {
              return ReviewTab(appId: item?.id ?? 0);
            }
            final text = desc.isEmpty ? '暂无详细介绍' : desc;
            final needToggle = text.length > 120;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shots.isNotEmpty) ...[
                  sectionHeader(
                    '应用截图',
                    Text(
                      '共 ${shots.length} 张',
                      style: Ty.tiny.copyWith(fontSize: 10, color: c.t3),
                    ),
                  ),
                  shotsWidget(),
                  const SizedBox(height: 26),
                ],
                sectionHeader('软件介绍', officialBadge()),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: _descExpanded ? null : 6,
                  overflow: _descExpanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.9,
                    color: isDark ? Colors.grey[300] : const Color(0xFF41454B),
                  ),
                ),
                if (needToggle) ...[
                  const SizedBox(height: 8),
                  AppPressable(
                    onTap: () => setState(() => _descExpanded = !_descExpanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _descExpanded ? '收起' : '展开全文',
                          // ★ C.brand 是可变静态量，不能放进 const
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: C.brand,
                          ),
                        ),
                        Icon(
                          _descExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 15,
                          color: C.brand,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ═══════════ 第 6 套：极光渐变 ═══════════

  List<Widget> _auroraBody(bool isDark, List<Widget> tabArea) {
    final it = item;
    final info = logic.appInfo;
    final d = _tplData();
    final desc = (info?.fileDesc ?? it?.description ?? '').trim();

    return [
      DetailAurora.header(
        context,
        item: it,
        iconUrl: info?.fileIcon ?? '',
        topLabel: d.topLabel,
        badges: [
          if (d.sizeText != '-' && d.sizeText.isNotEmpty) ('size', d.sizeText),
          if (d.verText.isNotEmpty) ('ver', 'v${d.verText}'),
        ],
        // ★ 1020：数据条画在头图渐变内部（深色底上白字才看得清）
        statCells: [
          (d.sizeText, '安装包'),
          ('${it?.downCount ?? 0}', '下载'),
          ('${it?.views ?? 0}', '浏览'),
          (it?.ageRating ?? '16+', '适龄'),
        ],
      ),
      const SizedBox(height: 14),
      _newTplTabArea(
        context,
        isDark: isDark,
        shots: d.shots,
        desc: desc,
        sectionHeader: (t, trail) =>
            DetailAurora.section(context, t, trailing: trail),
        officialBadge: DetailAurora.officialBadge,
        shotsWidget: () => DetailAurora.screenshots(
          context,
          shots: d.shots,
          onTap: (i) => _previewGallery(d.shots, i),
        ),
        accent: DetailAurora.aViolet,
      ),
      const SizedBox(height: 24),
      _recommend(accent: DetailAurora.aViolet),
      _alsoLike(accent: DetailAurora.aViolet),
    ];
  }

  // ═══════════ 第 7 套：霓虹（深浅自适应）═══════════

  List<Widget> _neonBody(bool isDark, List<Widget> tabArea) {
    final it = item;
    final info = logic.appInfo;
    final d = _tplData();
    final desc = (info?.fileDesc ?? it?.description ?? '').trim();
    final dark = isDark;

    return [
      DetailNeon.header(
        context,
        item: it,
        iconUrl: info?.fileIcon ?? '',
        topLabel: d.topLabel,
        sizeText: d.sizeText,
        dark: dark,
      ),
      const SizedBox(height: 24),
      DetailNeon.statBar(
        context,
        dark: dark,
        cells: [
          (d.sizeText, 'SIZE', DetailNeon.blue(dark)),
          ('${it?.downCount ?? 0}', 'DOWN', DetailNeon.mint(dark)),
          ('${it?.views ?? 0}', 'VIEW', DetailNeon.blue(dark)),
          (it?.ageRating ?? '16+', 'AGE', DetailNeon.violet(dark)),
        ],
      ),
      const SizedBox(height: 26),
      _newTplTabArea(
        context,
        isDark: isDark,
        shots: d.shots,
        desc: desc,
        sectionHeader: (t, trail) =>
            DetailNeon.section(context, t, dark: dark, trailing: trail),
        officialBadge: () => DetailNeon.officialBadge(dark),
        shotsWidget: () => DetailNeon.screenshots(
          context,
          shots: d.shots,
          dark: dark,
          onTap: (i) => _previewGallery(d.shots, i),
        ),
        accent: DetailNeon.mint(dark),
      ),
      const SizedBox(height: 24),
      _recommend(accent: DetailNeon.mint(dark)),
      _alsoLike(accent: DetailNeon.mint(dark)),
    ];
  }

  /// 顶部返回/分享（悬浮玻璃）
  /// v52i #4：海报模板头图（截图 > 图标，都没有退品牌渐变）
  /// v52m #2：头图高度（compact=46，minimal=0，其它 106）
  double _headerHeight() {
    final tpl = AppStyleController.instance.detailStyle.value;
    // ★ 1014 需求5：minimal/compact 原本高度过小，图标（84/68px）压出容器外，
    //   与下方标题/标签重叠；统一抬到能容纳图标的高度。
    if (tpl == AppDetailStyle.minimal) return 0;
    if (tpl == AppDetailStyle.compact) return 58;
    if (tpl == AppDetailStyle.poster) return 240;
    return 106;
  }

  /// ★ 1014 需求5：头图与下方内容的间距（必须 ≥ 悬浮图标溢出高度的一半）
  double _headerBottomGap() {
    final tpl = AppStyleController.instance.detailStyle.value;
    if (tpl == AppDetailStyle.minimal) return 0;
    if (tpl == AppDetailStyle.compact) return 46; // 图标 68 → 溢出 34
    if (tpl == AppDetailStyle.poster) return 56; // 图标 96 → 溢出 48
    return 50; // standard/dark：图标 84 → 溢出 42
  }

  /// v52m #2：头图装饰 —— standard渐变 / poster大图 / dark暗黑 / compact渐变 / minimal无
  Decoration _headerDecoration(BuildContext context, LzyFileInfoData? info) {
    final tpl = AppStyleController.instance.detailStyle.value;
    final radius = BorderRadius.circular(R.xl);
    if (tpl == AppDetailStyle.minimal) {
      return BoxDecoration(borderRadius: radius);
    }
    if (tpl == AppDetailStyle.dark) {
      return BoxDecoration(
        color: C.bg0,
        border: Border.all(color: C.brand.withAlpha(90)),
        borderRadius: radius,
      );
    }
    if (tpl == AppDetailStyle.poster) {
      final has =
          info != null &&
          (logic.item?.screenshots.isNotEmpty == true ||
              (info.fileIcon ?? '').isNotEmpty ||
              (logic.item?.icon ?? '').isNotEmpty);
      // v54-fix：poster 头图不再通栏出血（去掉负外边距），统一内嵌圆角
      // ★ 1014 需求5 修复：渐变常驻打底，图片失败/加载中不再出现整块空白
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [
            C.brand.withAlpha(context.isDark ? 150 : 120),
            C.violet.withAlpha(context.isDark ? 110 : 90),
          ],
        ),
        image: has
            ? DecorationImage(fit: BoxFit.cover, image: _posterProvider(info)!)
            : null,
        borderRadius: radius,
      );
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          C.brand.withAlpha(context.isDark ? 150 : 120),
          C.violet.withAlpha(context.isDark ? 110 : 90),
        ],
      ),
      borderRadius: radius,
    );
  }

  /// ★ 1014 需求2：海报头图的内容层
  ///   有截图 → 横向可滑动的截图轮播；没截图 → 退图标大图；都没 → 渐变打底。
  Widget _posterGallery() {
    final shots = logic.item?.screenshots ?? const <String>[];
    final info = logic.appInfo;
    if (shots.isEmpty) {
      final icon = info?.fileIcon ?? logic.item?.icon ?? '';
      if (icon.isEmpty) return const SizedBox.shrink();
      return CachedNetworkImage(
        imageUrl: icon,
        fit: BoxFit.cover,
        memCacheWidth: 720,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return PageView.builder(
      itemCount: shots.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (_, i) => CachedNetworkImage(
        imageUrl: shots[i],
        fit: BoxFit.cover,
        memCacheWidth: 1000,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  ImageProvider? _posterProvider(LzyFileInfoData? info) {
    final shots = logic.item?.screenshots ?? const [];
    if (shots.isNotEmpty) return CachedNetworkImageProvider(shots.first);
    final icon = info?.fileIcon ?? logic.item?.icon ?? '';
    if (icon.isNotEmpty) return CachedNetworkImageProvider(icon);
    return null;
  }

  bool _descExpanded = false;

  /// v54-fix：顶部标题过长时省略，避免 Row 溢出
  Widget _topBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 6,
              bottom: 8,
              left: 12,
              right: 12,
            ),
            color: (context.isDark ? C.bg0 : C.lbg0).withAlpha(150),
            child: Row(
              children: [
                _topBtn(Icons.arrow_back_ios_new_rounded, () => Get.back()),
                // ★★ 1020：标题两侧各有一个 Spacer（各占 1 份弹性空间），
                //   标题只能分到 1/3 宽度 → 永远显示成 "Tomato Vi..."。
                //   改成固定小间距，让 Expanded 吃满剩余空间。
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item?.title ?? '软件详情',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Ty.h3.copyWith(color: context.t1, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 4),
                // ★ 1020：收藏按钮（后台可关，关闭时不占位）
                if (SoftService.instance.cachedConfig?.uiConfig.featureAppFav ??
                    true)
                  _favBtn(),
                const SizedBox(width: 8),
                _topBtn(
                  Icons.ios_share_rounded,
                  () => logic.showSharePopUps(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 收藏按钮（详情页顶栏）
  ///
  /// ★ 1020：软件收藏接口早就有了（/api/softlib/appfav），
  ///   但详情页一直没有入口 → 用户看不到收藏功能。
  Widget _favBtn() {
    return FutureBuilder<Set<int>>(
      future: _favIdsFuture,
      builder: (context, snap) {
        final favs = snap.data ?? <int>{};
        final id = item?.id ?? 0;
        final on = id > 0 && favs.contains(id);
        return AppPressable(
          onTap: () => _toggleFav(id, on),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withAlpha(20) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.isDark
                    ? Colors.white12
                    : Colors.black.withAlpha(6),
              ),
            ),
            child: Icon(
              on ? Icons.star_rounded : Icons.star_border_rounded,
              size: 19,
              color: on ? C.amber : context.t2,
            ),
          ),
        );
      },
    );
  }

  Future<Set<int>>? _favIdsFuture;

  Future<Set<int>> _loadFavIds() async {
    try {
      final r =
          await ApiHttp.create(
            BaseOptions(
              baseUrl: ApiHost.base,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8),
            ),
          ).post(
            '/api/softlib/appfavids',
            data: {'token': UserService.instance.token},
          );
      if (r.data is Map && r.data['code'] == 1) {
        final list = (r.data['data']?['ids'] as List?) ?? [];
        return list.map((e) => (e as num).toInt()).toSet();
      }
    } catch (_) {}
    return <int>{};
  }

  Future<void> _toggleFav(int id, bool currentlyOn) async {
    if (id <= 0) return;
    if (!UserService.instance.isLoggedIn) {
      ToastUtil.info('登录后才能收藏');
      return;
    }
    try {
      final r =
          await ApiHttp.create(
            BaseOptions(
              baseUrl: ApiHost.base,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8),
            ),
          ).post(
            '/api/softlib/appfav',
            data: {'app_id': id, 'token': UserService.instance.token},
          );
      if (r.data is Map && r.data['code'] == 1) {
        ToastUtil.success(currentlyOn ? '已取消收藏' : '已收藏，可在「我的收藏」查看');
        setState(() {
          _favIdsFuture = _loadFavIds();
        });
      } else {
        ToastUtil.error('${r.data is Map ? r.data['msg'] : '操作失败'}');
      }
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Widget _topBtn(IconData i, VoidCallback f) => AppPressable(
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

  // ═════════ 主卡 ═════════
  Widget _hero() {
    final it = item;
    final info = logic.appInfo;
    final tpl = AppStyleController.instance.detailStyle.value;
    final isVipItem = it?.isVipItem ?? false;
    final hasP = it?.hasPrice ?? false;
    final priceTxt = it?.vipPrice ?? '';
    // ★ 标签反映真实付费状态：有价格 → 「¥xx 购买」，会员专享 → 「会员专享」，否则「免费下载」
    final String topLabel = hasP
        ? '¥$priceTxt 购买'
        : (isVipItem ? '会员专享' : '免费下载');
    final Color topColor = hasP ? C.mint : (isVipItem ? C.amber : C.mint);
    final IconData topIcon = hasP
        ? Icons.paid_rounded
        : (isVipItem
              ? Icons.workspace_premium_rounded
              : Icons.download_done_rounded);
    final icon = info?.fileIcon ?? '';
    // ★ 详情页美化（需求 #7）：顶部加品牌渐变头图 + 更大的图标 + 光晕
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // v52m #2：详情页头图（5 模板装饰见 _headerDecoration）
            // v54：poster 通栏出血（负外边距顶出 ListView 内边距）
            Container(
              height: _headerHeight(),
              margin: EdgeInsets.only(bottom: _headerBottomGap()),
              decoration: _headerDecoration(context, info),
              child: Stack(
                children: [
                  // 装饰光斑（poster 大图模式下去掉，避免盖在截图上）
                  if (tpl != AppDetailStyle.poster) ...[
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(28),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -10,
                      bottom: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(18),
                        ),
                      ),
                    ),
                  ] else
                    // ★ 1014 需求2：海报模板完善 —— 原来是「一张图 + 底部压暗」，
                    //   现在改为：多张截图可左右滑动 + 页码指示 + 完整压暗层，
                    //   标题信息浮在图上，才是真正的海报观感。
                    Positioned.fill(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 可滑动的截图轮播（有截图时）
                          _posterGallery(),
                          // 压暗渐层（顶部轻、底部重，保证文字可读）
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withAlpha(70),
                                  Colors.transparent,
                                  Colors.black.withAlpha(170),
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                          // 页码指示（多张截图时）
                          if ((logic.item?.screenshots.length ?? 0) > 1)
                            Positioned(
                              bottom: 12,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(110),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '共 ${logic.item!.screenshots.length} 张',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 悬浮图标（v53d：poster 96px 居左出血感，compact 68px）
            // ★ 1014 需求5：minimal 模板没有头图，图标改为内嵌在标题行，
            //   这里不再叠一个悬浮图标（否则会与标题重叠错位）。
            if (tpl != AppDetailStyle.minimal)
              Positioned(
                left: tpl == AppDetailStyle.compact ? 14 : 18,
                bottom: 0,
                child: Container(
                  width: tpl == AppDetailStyle.poster
                      ? 96
                      : (tpl == AppDetailStyle.compact ? 68 : 84),
                  height: tpl == AppDetailStyle.poster
                      ? 96
                      : (tpl == AppDetailStyle.compact ? 68 : 84),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(R.lg + 4),
                    border: Border.all(
                      color: context.isDark ? C.bg1 : Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: C.brand.withAlpha(context.isDark ? 90 : 60),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(R.lg),
                    child: icon.isEmpty
                        ? _phIcon()
                        : CachedNetworkImage(
                            imageUrl: icon,
                            fit: BoxFit.cover,
                            memCacheWidth: 220,
                            placeholder: (_, __) => _phIcon(),
                            errorWidget: (_, __, ___) => _phIcon(),
                          ),
                  ),
                ),
              ),
            // 状态标签（右上角）
            Positioned(
              right: 12,
              top: 12,
              child: _chip(topLabel, Colors.white, topIcon),
            ),
            // NEW 角标（★ 1014 需求5：移到左上角，避免与 poster/standard 模板的
            //   左下角悬浮图标重叠错位；右上角是状态标签）
            if (it?.isNew == true)
              Positioned(
                left: 14,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFB923C)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withAlpha(140),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 名称 + 版本 + 标签
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info?.fileName?.isNotEmpty == true
                    ? info!.fileName!
                    : (it?.title ?? '未知软件'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Ty.h1.copyWith(color: context.t1, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip('人工亲测', C.brandBright, Icons.verified_rounded),
                  const SizedBox(width: 6),
                  if (isVipItem && !hasP)
                    _chip('会员专享', C.amber, Icons.workspace_premium_rounded),
                  const Spacer(),
                  if ((it?.scoreCount ?? 0) > 0) ...[
                    Icon(Icons.star_rounded, size: 16, color: C.amber),
                    const SizedBox(width: 3),
                    Text(
                      it!.scoreAvg.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: C.amber,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '(${it.scoreCount})',
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ] else
                    Text(
                      '版本 ${it?.version.isNotEmpty == true ? it!.version : '未知'}',
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 安全检测条
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                C.mint.withAlpha(context.isDark ? 40 : 26),
                C.cyan.withAlpha(context.isDark ? 26 : 16),
              ],
            ),
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.mint.withAlpha(75), width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: C.mint.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded, size: 13, color: C.mint),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '已通过安全检测 · 无病毒 · 无恶意插件',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: C.mint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    decoration: BoxDecoration(
      color: color.withAlpha(context.isDark ? 36 : 24),
      borderRadius: BorderRadius.circular(R.full),
      border: Border.all(color: color.withAlpha(75), width: 0.7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.5, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );

  // ═════════ 数据卡 ═════════
  /// 数量格式化：1.2k / 3.4w（万）——展示下载量用
  String _fmtCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return '${v >= 10 ? v.round() : double.parse(v.toStringAsFixed(1))}w';
    }
    if (n >= 10000) {
      final v = n / 10000;
      return '${v >= 10 ? v.round() : double.parse(v.toStringAsFixed(1))}w';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return '${v >= 10 ? v.round() : double.parse(v.toStringAsFixed(1))}k';
    }
    return '$n';
  }

  Widget _info() {
    final it = item;
    final info = logic.appInfo;
    // ★ 1014 需求3：网页跳转类内容隐藏 大小/浏览/下载 等不适用的格子
    final linkType = it?.isLinkType ?? false;
    final cells = linkType
        ? [
            (
              Icons.language_rounded,
              (it?.linkUrl ?? '').replaceFirst(RegExp(r'^https?://'), ''),
              '链接',
              C.cyan,
            ),
            (
              Icons.schedule_rounded,
              _shortDate(it?.uploadDate ?? ''),
              '上传',
              C.violet,
            ),
          ]
        : [
            (
              Icons.sd_storage_rounded,
              info?.fileSize ?? it?.size ?? '-',
              '大小',
              C.brandBright,
            ),
            (Icons.visibility_rounded, '${it?.views ?? 0}', '浏览', C.cyan),
            (
              Icons.download_rounded,
              _fmtCount(it?.downCount ?? 0),
              '下载',
              C.mint,
            ),
            (
              Icons.schedule_rounded,
              _shortDate(it?.uploadDate ?? ''),
              '上传',
              C.violet,
            ),
            (Icons.face_rounded, it?.ageRating ?? '16+', '年龄', C.mint),
          ];
    // ★ 1014 重做：5 格信息条改为「一行均分」，不再折行错位。
    //   关键：用 Expanded 均分 + 小图标 + 缩小字号，让日期（10-12）也放得下，
    //   彻底避免「2026-10…」被截断，视觉上也更整齐。
    return Deco.glass(
      context,
      radius: R.lg,
      alpha: 0.055,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cells[i].$1, size: 16, color: cells[i].$4),
                  const SizedBox(height: 7),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      cells[i].$2,
                      maxLines: 1,
                      style: Ty.h3.copyWith(
                        color: context.t1,
                        fontSize: 13.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(cells[i].$3, style: Ty.tiny.copyWith(color: context.t3)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ★ 1014：日期紧凑化 —— 「2026-10-12 / 2026.10.12」→「10-12」
  ///    信息横幅里日期较长，短格式更整齐且不会被挤压省略。
  String _shortDate(String s) {
    final t = s.trim();
    if (t.isEmpty || t == '-') return '-';
    final m = RegExp(r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})').firstMatch(t);
    if (m != null) {
      final mm = m.group(2)!.padLeft(2, '0');
      final dd = m.group(3)!.padLeft(2, '0');
      return '$mm-$dd';
    }
    return t;
  }

  /// v54：minimal/compact 扁平数据行（无玻璃卡，细分隔）
  /// ★ 1014 重做：与玻璃卡版一致，一行均分 + FittedBox 自适应，
  ///   不再折行产生「4 格 + 1 格」的错位观感。
  Widget _infoFlat() {
    final it = item;
    final info = logic.appInfo;
    // ★ 1014 需求3：网页跳转类内容隐藏不适用的格子
    final linkType = it?.isLinkType ?? false;
    final cells = linkType
        ? [
            (
              Icons.language_rounded,
              (it?.linkUrl ?? '').replaceFirst(RegExp(r'^https?://'), ''),
              '链接',
            ),
            (Icons.schedule_rounded, _shortDate(it?.uploadDate ?? ''), '上传'),
          ]
        : [
            (Icons.sd_storage_rounded, info?.fileSize ?? it?.size ?? '-', '大小'),
            (Icons.visibility_rounded, '${it?.views ?? 0}', '浏览'),
            (Icons.download_rounded, _fmtCount(it?.downCount ?? 0), '下载'),
            (Icons.schedule_rounded, _shortDate(it?.uploadDate ?? ''), '上传'),
            (Icons.face_rounded, it?.ageRating ?? '16+', '年龄'),
          ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.isDark
                ? Colors.white.withAlpha(16)
                : Colors.black.withAlpha(12),
          ),
          bottom: BorderSide(
            color: context.isDark
                ? Colors.white.withAlpha(16)
                : Colors.black.withAlpha(12),
          ),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cells[i].$1, size: 15, color: context.t3),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      cells[i].$2,
                      maxLines: 1,
                      style: Ty.body.copyWith(
                        color: context.t1,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(cells[i].$3, style: Ty.tiny.copyWith(color: context.t3)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// v54：compact 横向信息头条（一行式骨架，无大头图）
  Widget _heroCompact() {
    final it = item;
    final info = logic.appInfo;
    final icon = info?.fileIcon ?? '';
    final isVipItem = it?.isVipItem ?? false;
    final hasP = it?.hasPrice ?? false;
    final priceTxt = it?.vipPrice ?? '';
    final String topLabel = hasP ? '¥$priceTxt' : (isVipItem ? '会员专享' : '免费');
    final Color topColor = hasP ? C.mint : (isVipItem ? C.amber : C.mint);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GlassTheme.enabled
            ? GlassTheme.cardColor(context)
            : (context.isDark ? Colors.white.withAlpha(8) : Colors.white),
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withAlpha(18)
              : Colors.black.withAlpha(10),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(R.md),
            child: icon.isEmpty
                ? _phIcon()
                : CachedNetworkImage(
                    imageUrl: icon,
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    placeholder: (_, __) => _phIcon(),
                    errorWidget: (_, __, ___) => _phIcon(),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it?.title ?? '未知软件',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.h2.copyWith(color: context.t1, fontSize: 16.5),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _chip(topLabel, topColor, Icons.sell_outlined),
                    const SizedBox(width: 6),
                    _chip(
                      'v${it?.version.isNotEmpty == true ? it!.version : '?'}',
                      C.brandBright,
                      Icons.tag_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ★ 1020：支持传模板主色 —— 切模板时 Tab 指示条也跟着变，
  ///   否则整页只有上半部分换肤，Tab 还是旧蓝。
  Widget _tabBarCard(bool isDark, {Color? accent}) {
    final ac = accent ?? C.brand;
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.enabled
            ? GlassTheme.cardColor(context)
            : (isDark ? Colors.white.withAlpha(14) : Colors.white),
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(18)
              : Colors.black.withAlpha(8),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: TabBar(
              controller: _tab,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              indicatorColor: ac,
              labelColor: ac,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '详情'),
                Tab(text: '评论'),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: Colors.grey.withAlpha(30)),
        ],
      ),
    );
  }

  Widget _detail(bool isDark) {
    final info = logic.appInfo;
    final desc = info?.fileDesc ?? '';
    final shots = item?.screenshots ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 15,
              decoration: BoxDecoration(
                color: C.brand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '软件介绍',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: C.brand.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '官方详情',
                style: TextStyle(
                  fontSize: 10.5,
                  color: C.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        // v54-fix：长简介默认折叠（6 行），可展开/收起
        Text(
          desc.isEmpty ? '暂无详细介绍' : desc,
          maxLines: _descExpanded ? null : 6,
          overflow: _descExpanded ? null : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.9,
            letterSpacing: 0.1,
            color: isDark ? Colors.grey[300] : const Color(0xFF41454B),
          ),
        ),
        if (desc.length > 120) ...[
          const SizedBox(height: 6),
          AppPressable(
            onTap: () => setState(() => _descExpanded = !_descExpanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _descExpanded ? '收起' : '展开全部',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: C.brand,
                  ),
                ),
                Icon(
                  _descExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: C.brand,
                ),
              ],
            ),
          ),
        ],
        if (shots.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            '应用截图',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          // ★ 1014 需求2 修复：原来宽 130px + BoxFit.cover 会把截图裁成
          //   中间一条，用户必须点开才能看全。现在改为：
          //   按截图原始宽高比完整显示（BoxFit.contain），横排可滑动，
          //   一看就是完整的手机截图。
          // ★ 1015 修复：不再写死 9/19.5 竖版比例 + BoxFit.cover。
          //   采集来的「截图」很多是横版拼图（例：1920×1280，3 图横拼），
          //   写死竖比例再 cover，只会裁出中间一条竖缝 → 用户看到「显示不全」。
          //   现在：按图片原始比例完整显示（contain），宽度自适应，横向可滑。
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => AppPressable(
                onTap: () => _previewGallery(shots, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: isDark
                        ? Colors.white.withAlpha(18)
                        : const Color(0xFFF0F1F5),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.88,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: shots[i],
                        height: 230,
                        fit: BoxFit.contain, // 按原始比例完整显示，绝不裁切
                        placeholder: (_, __) => const SizedBox(
                          width: 150,
                          height: 230,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const SizedBox(
                          width: 150,
                          height: 230,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '共 ${shots.length} 张 · 点击可放大查看',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '下载前请确认软件名称与更新时间，安装包以当前详情页为准。',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[600],
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _recommend(),
        // ★ 1020（待办）：弱化版「你可能还喜欢」
        //   复用推荐数据，但视觉极轻：纯文字 + 小图标，不抢精品推荐的视觉
        _alsoLike(),
      ],
    );
  }

  /// 你可能还喜欢（极轻量，纯文字 + 16px 小图标）
  Widget _alsoLike({Color? accent}) {
    _recFuture ??= _loadRecommend();
    return FutureBuilder<List<AppItem>>(
      future: _recFuture,
      builder: (context, snap) {
        final all = snap.data ?? const <AppItem>[];
        if (all.length < 4) return const SizedBox.shrink();
        final picks = all.skip(4).take(3).toList();
        if (picks.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 13,
                    color: accent ?? context.t3,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '你可能还喜欢',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.t3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...picks.map(
                (a) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Get.offAndToNamed(
                    Routes.appDetails,
                    arguments: {'appId': a.id.toString(), 'item': a},
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: CachedNetworkImage(
                            imageUrl: a.icon,
                            width: 16,
                            height: 16,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const SizedBox(width: 16, height: 16),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.t2,
                            ),
                          ),
                        ),
                        if (a.size.isNotEmpty)
                          Text(
                            a.size,
                            style: TextStyle(fontSize: 10, color: context.t3),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== 精品推荐（同类软件） =====
  //
  // ★ 1020（反馈 #6）：原实现有三个明确问题
  //   ① 拉的是「全站最新 8 个」，跟当前软件**毫无关系**（用户说「太乱」）
  //   ② 卡片只有 58px 图标 + 11px 标题，没有分类/大小/版本，信息单薄
  //   ③ 图标为空时只剩一个灰方块，横向高度写死 118，长标题会溢出错位
  //   现在：同分类优先 → 不足再按「热门」补位 → 卡片信息完整、样式统一
  /// ★ 1020：支持传模板配色 —— 切换模板时底部推荐区也要跟着变，
  ///   否则整页「上新生、下半旧」，看起来只换了一半。
  Widget _recommend({Color? accent}) {
    // 首次构建时惰性发起请求（推荐区在页面底部，前面内容先渲染）
    _recFuture ??= _loadRecommend();
    return FutureBuilder<List<AppItem>>(
      future: _recFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final others = snap.data ?? const <AppItem>[];
        if (others.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ★ 1020：标题 + 副标题（去掉「同类应用」小徽章，更干净）
            Row(
              children: [
                Container(
                  width: 3.5,
                  height: 15,
                  decoration: BoxDecoration(
                    gradient: accent == null
                        ? Deco.brandGradient
                        : LinearGradient(
                            colors: [accent, accent.withAlpha(150)],
                          ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '精品推荐',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '为你精选更多实用应用',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            // ★ 1020：改成九宫格（3 列）卡片，不再横向滑动
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: others.length > 9 ? 9 : others.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, i) => _recCard(others[i], accent: accent),
            ),
          ],
        );
      },
    );
  }

  /// 推荐数据只算一次（避免每次重建都发请求）
  Future<List<AppItem>>? _recFuture;
  bool _recSameCat = true;

  Future<List<AppItem>> _loadRecommend() async {
    final cur = item;
    final cat = cur?.catId ?? 0;
    List<AppItem> pool = const [];
    try {
      // ① 同分类（catId > 0 才有意义）
      if (cat > 0) pool = await SoftService.instance.fetchApps(catId: cat);
    } catch (_) {}
    var list = pool
        .where((e) => e.id != (cur?.id ?? 0) && e.icon.isNotEmpty)
        .toList();
    _recSameCat = list.length >= 3;
    // ② 同分类不足 → 用全站补，但按热度排序（不是随便取最新 8 个）
    if (list.length < 6) {
      try {
        final all = await SoftService.instance.fetchApps();
        final rest =
            all
                .where(
                  (e) =>
                      e.id != (cur?.id ?? 0) &&
                      e.icon.isNotEmpty &&
                      !list.any((x) => x.id == e.id),
                )
                .toList()
              ..sort((a, b) => b.downCount.compareTo(a.downCount));
        list = [...list, ...rest];
      } catch (_) {}
    }
    return list.take(8).toList();
  }

  /// 推荐卡（九宫格单元）：浅底圆角卡 + 图标 + 两行名称
  Widget _recCard(AppItem a, {Color? accent}) {
    final dark = context.isDark;
    return GestureDetector(
      // ★ 1020：改用 toNamed（push 新页面）。
      //   offAndToNamed 在「详情页 → 另一个详情页」时会先移除当前页再压栈，
      //   GetX 在这个时序上会丢参数 / 复用旧路由，表现为「点了没反应」。
      //   toNamed 是纯 push，本仓库首页/应用页都用它，行为稳定。
      // ★★ 必须用 offAndToNamed：toNamed 是 push，
      //   旧详情页还活着 → 它的控制器没被销毁 →
      //   Get.lazyPut 直接返回同一个控制器，onInit 不重跑 →
      //   新页面拿到的还是旧 item（就是「点了还是原来的软件」）。
      //   offAndToNamed 会移除旧页面、销毁控制器，配合 fenix 重建。
      onTap: () => Get.offAndToNamed(
        Routes.appDetails,
        arguments: {'appId': a.id.toString(), 'item': a},
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          // ★ 1020：卡片跟随模板配色
          color: dark ? Colors.white.withAlpha(12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent == null
                ? (dark
                      ? Colors.white.withAlpha(14)
                      : Colors.black.withAlpha(6))
                : accent.withAlpha(dark ? 70 : 46),
            width: accent == null ? 1 : 1.1,
          ),
          boxShadow: accent == null
              ? null
              : [
                  BoxShadow(
                    color: accent.withAlpha(dark ? 26 : 18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: accent == null
                    ? (dark
                          ? Colors.white.withAlpha(10)
                          : const Color(0xFFF2F4F9))
                    : accent.withAlpha(dark ? 26 : 14),
              ),
              clipBehavior: Clip.antiAlias,
              child: a.icon.isEmpty
                  ? Icon(Icons.android, color: C.brand, size: 24)
                  : CachedNetworkImage(
                      imageUrl: a.icon,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) =>
                          Icon(Icons.android, color: C.brand, size: 24),
                    ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                a.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: context.t2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 底部：单个下载按钮（无左右双栏） ============
  Widget _bottom() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVipItem = item?.isVipItem ?? false;
    final loggedIn = UserService.instance.isLoggedIn;
    // ★ 1014 修复：管理员同样可免费下载。
    //   且改用 canFreeDownload（会员 或 管理员，并按 vip_expire 时间戳兜底），
    //   避免「字段格式差异」或「本地缓存过期」导致会员被误判。
    final isVipUser = UserService.instance.user?.canFreeDownload == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: GlassTheme.enabled
            ? GlassTheme.cardColor(context)
            : (isDark ? C.bg2 : Colors.white),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 70 : 16),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GetBuilder<AppDetailsLogic>(
          id: 'download',
          builder: (download) {
            final task = download.downloadTask;
            // ★ 1012b：完成态以状态机 phase 为准（任务记录被清理时也稳定显示
            //   「安装」，绝不闪回「下载」按钮）
            if (download.downloadUiPhase == 'done') {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _bottomHint(
                    Icons.check_circle_outline_rounded,
                    '下载完成 · 点击即可安装',
                    C.success,
                  ),
                  const SizedBox(height: 9),
                  PrimaryButton(
                    label: '安装',
                    icon: Icons.install_mobile_rounded,
                    // v52f #4：安装按钮统一品牌渐变（绿色仅用于状态标识）
                    onPressed: download.openDownloadFile,
                  ),
                ],
              );
            }
            // 下载中 → 进度卡片（含任务对象瞬时查不到的粘滞态）
            if (task != null || download.downloadUiPhase == 'downloading') {
              return _progressPanel(download, task);
            }
            // ★ 需求1（防首帧抖动）：无任务但 3 秒内刚点过下载 →
            //   保持进度条初始态，不跳回「下载按钮」
            if (download.pendingDownloadUi) {
              return _pendingDownloadPanel(download);
            }
            // 未下载
            // ★ 1014 需求3：网页跳转类内容（browser / webview）→ 不走下载流程
            final urlType = item?.urlType ?? 'apk';
            if (urlType == 'browser' || urlType == 'webview') {
              final isBrowser = urlType == 'browser';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _bottomHint(
                    isBrowser
                        ? Icons.open_in_browser_rounded
                        : Icons.language_rounded,
                    isBrowser ? '跳转系统浏览器打开' : 'App 内置浏览器打开',
                    C.cyan,
                  ),
                  const SizedBox(height: 9),
                  PrimaryButton(
                    label: isBrowser ? '打开链接' : '打开页面',
                    color: C.cyan,
                    icon: isBrowser
                        ? Icons.open_in_new_rounded
                        : Icons.language_rounded,
                    onPressed: () {
                      final u = item?.linkUrl ?? '';
                      if (u.isEmpty) {
                        ToastUtil.error('未配置链接');
                        return;
                      }
                      if (isBrowser) {
                        JumpUtil.openUrl(u);
                      } else {
                        Get.toNamed(
                          Routes.urlWebview,
                          arguments: {'url': u, 'title': item?.title ?? '页面'},
                        );
                      }
                    },
                  ),
                ],
              );
            }
            final String label;
            final IconData icon;
            final Color color;
            final String sub;
            final needUnlock = item?.needUnlock ?? false;
            final priceTxt = item?.vipPrice ?? '';
            final hasP = (double.tryParse(priceTxt.trim()) ?? 0) > 0;
            if (needUnlock) {
              // ★ 只要涉及付费/会员，都必须校验（不再只看 isVipItem）
              if (hasP && !isVipUser) {
                label = '购买下载 ¥$priceTxt';
                icon = Icons.paid_rounded;
                color = C.mint;
                sub = '余额支付 · 购买后永久可下载';
              } else if (hasP && isVipUser) {
                label = '会员免费下载';
                icon = Icons.workspace_premium_rounded;
                color = C.gold;
                sub = '会员专享 · 高速下载';
              } else {
                label = isVipUser ? '会员下载' : '开通会员下载';
                icon = Icons.workspace_premium_rounded;
                color = C.gold;
                sub = isVipUser ? '会员专享 · 高速下载' : '该资源仅会员可下载';
              }
            } else if (item?.isLocal == true) {
              label = '下载安装';
              icon = Icons.download_rounded;
              color = C.brand;
              sub = '服务器直连 · 极速下载';
            } else {
              label = '解析并下载';
              icon = Icons.cloud_download_rounded;
              color = C.brand;
              sub = '来自蓝奏云 · 解析后自动开始下载';
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _bottomHint(icon, sub, color),
                const SizedBox(height: 9),
                PrimaryButton(
                  label: label,
                  color: color,
                  icon: icon,
                  gold: needUnlock && !hasP,
                  onPressed: () async =>
                      await _onDownload(needUnlock, loggedIn, isVipUser),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 底部按钮上方的说明行（图标 + 文字）
  Widget _bottomHint(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color.withAlpha(190)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: context.t2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 下载中：进度面板（统一设计语言）
  /// ★ 1012b：task 可为 null（粘滞态），进度一律取逻辑层单调不减的
  ///   uiProgress，杜绝 显示层进度回退 抖动
  Widget _progressPanel(AppDetailsLogic download, DownloadTask? task) {
    final total = download.appInfo?.fileSize ?? '';
    final progress = download.uiProgress;
    final done = calculateDownloadedSize(total, progress);
    final st = task?.status;
    final isPaused = st == DownloadTaskStatus.paused;
    final isFailed = st == DownloadTaskStatus.failed;

    // ★ 1020（待办 #1）：静默重连中 —— 不显示「失败」，进度保持不变
    final retrying = download.silentRetrying;
    final Color accent = retrying
        ? C.amber
        : (isFailed ? C.danger : (isPaused ? C.warning : C.brand));
    final String title = retrying
        ? '连接中断，正在重连…'
        : (isFailed ? '下载失败' : (isPaused ? '已暂停' : '正在下载中'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accent.withAlpha(38),
                shape: BoxShape.circle,
              ),
              child: Icon(
                retrying
                    ? Icons.sync_rounded
                    : (isFailed
                          ? Icons.error_outline_rounded
                          : (isPaused
                                ? Icons.pause_rounded
                                : Icons.downloading_rounded)),
                size: 14,
                color: accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const Spacer(),
            Text(
              '$progress%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 9),
        KitProgress(value: progress / 100, color: accent),
        const SizedBox(height: 9),
        Row(
          children: [
            Text(
              '$done / ${total.isEmpty ? '未知' : total}',
              style: TextStyle(fontSize: 11.5, color: context.t2),
            ),
            const Spacer(),
            if (isFailed)
              MiniAction(
                label: '重试',
                icon: Icons.refresh_rounded,
                onTap: download.retryDownload,
                color: accent,
              )
            else if (isPaused)
              MiniAction(
                label: '继续',
                icon: Icons.play_arrow_rounded,
                onTap: download.resumeDownload,
                color: accent,
              )
            else
              MiniAction(
                label: '暂停',
                icon: Icons.pause_rounded,
                onTap: download.pauseDownload,
                color: accent,
              ),
            const SizedBox(width: 8),
            MiniAction(
              label: '取消',
              icon: Icons.close_rounded,
              onTap: download.cancelDownload,
              color: const Color(0xFF6B7280),
            ),
          ],
        ),
      ],
    );
  }

  /// ★ 需求1：进度条初始态（任务刚创建、DB 记录尚未落库时的过渡 UI）
  Widget _pendingDownloadPanel(AppDetailsLogic download) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: C.brand.withAlpha(38),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.downloading_rounded, size: 14, color: C.brand),
            ),
            const SizedBox(width: 8),
            Text(
              '正在创建下载任务…',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: C.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        KitProgress(value: 0, color: C.brand),
        const SizedBox(height: 9),
        Text(
          '正在解析下载直链，请稍候',
          style: TextStyle(fontSize: 11.5, color: context.t2),
        ),
      ],
    );
  }

  /// 下载前置校验
  ///
  /// 规则（与后台「会员专享 + 会员价」配置一致）：
  ///   · 会员 / 管理员 / 已购买过 → 直接下载
  ///   · 普通用户 + 有价格       → 可用「余额」购买（不足则引导充值）
  ///   · 未设价格               → 免费下载
  ///
  /// ★ 关键修复（用户反馈 #2）：
  ///   以前这里只判断 `isVipItem`（后台的「会员专享」开关），
  ///   完全没看 vip_price → 设了价格但没勾会员专享的软件，
  ///   任何用户点了就直接下载，不扣钱也不用买。
  /// ★ 现在以「服务端为唯一权威」：
  ///   已登录用户一律先问服务端（本地数据可能过期/被改）；
  ///   未登录用户只在「看起来免费」时直接下载，涉及付费则引导登录。
  Future<void> _onDownload(
    bool isVipItem,
    bool loggedIn,
    bool isVipUser,
  ) async {
    // appInfo 是解析后的文件信息，没有 id；id 在 item 上
    final appId = logic.item?.id ?? 0;
    final fileName = logic.appInfo?.fileName ?? '未知文件名';

    // 本地初步判断：会员专享 或 设置了会员价
    final localNeedPay = isVipItem || (logic.item?.hasPrice ?? false);

    // ═══════ ★ 1014 需求：全量强制登录 + 服务端鉴权 ═══════
    // 免费资源也必须登录后才能下载，不再有「未登录直接下」的快捷路径。
    if (!loggedIn) {
      _dialog(
        '需要登录',
        localNeedPay ? '该资源为付费资源，请先登录账号' : '下载前请先登录账号（所有下载都需要经过服务端校验）',
        '去登录',
        Routes.login,
      );
      return;
    }

    // 已登录：一律向服务端确认（服务端是唯一权威，避免本地数据过期被绕过）
    // ★ 没有 id 时（如蓝奏云文件夹里的软件）按标题反查库里的 id，拿到才校验。
    if (appId <= 0) {
      final resolvedId = await _resolveAppIdByTitle();
      if (!mounted) return;
      if (resolvedId <= 0) {
        _dialog(
          '无法校验',
          '暂时无法确认该资源在软件库中的归属，出于安全考虑已停止下载。\n请从软件列表或搜索页重新进入后下载。',
          '知道了',
          null,
        );
        return;
      }
      // 用查到的 id 继续走正常的服务端校验流程
      return _onDownloadWithId(resolvedId, fileName, isVipUser);
    }

    UnlockStatus st;
    try {
      st = await UnlockService.instance.status(appId);
    } catch (e) {
      // ★ 服务端不可达 → 一律拒绝（不再按本地判断放行，避免离线绕过）
      ToastUtil.error('无法连接服务器完成校验，请检查网络后重试');
      return;
    }
    if (!mounted) return;
    await _applyUnlockResult(st, fileName, isVipUser, appId: appId);
  }

  /// ★ 1014：按标题向服务端查软件 id（无 id 时的付费兜底校验）
  /// 从搜索页/列表页拿不到 id 的场景（如蓝奏云文件夹），用标题反查库里记录。
  Future<int> _resolveAppIdByTitle() async {
    final title = (logic.item?.title ?? '').trim();
    if (title.isEmpty) return 0;
    try {
      final list = await SoftService.instance.fetchApps(
        keyword: title,
        force: true,
      );
      // ★ 1014 安全：只接受「完全同名」的唯一匹配。
      //   原先的 contains 双向模糊匹配，会把付费资源误判到同名的免费条目上，
      //   从而通过免费 id 的校验 —— 这在强制鉴权模型下是绕过口，已收紧。
      final exact = list
          .where((a) => a.id > 0 && a.title.trim() == title)
          .toList();
      if (exact.length == 1) return exact.first.id;
      // 多个完全同名 → 无法唯一确定，宁可不下载
      if (exact.length > 1) return 0;
    } catch (_) {}
    return 0;
  }

  /// ★ 1014：拿到 id 后的统一校验流程（供无 id 兜底分支复用）
  Future<void> _onDownloadWithId(
    int appId,
    String fileName,
    bool isVipUser,
  ) async {
    UnlockStatus st;
    try {
      st = await UnlockService.instance.status(appId);
    } catch (e) {
      // 兜底分支：服务端不可达时保守拒绝（已判定为付费资源，不能放行）
      ToastUtil.error(ErrText.of(e));
      return;
    }
    if (!mounted) return;
    await _applyUnlockResult(st, fileName, isVipUser, appId: appId);
  }

  /// ★ 1014：把服务端判定结果落到 UI（抽出来便于兜底分支复用）
  Future<void> _applyUnlockResult(
    UnlockStatus st,
    String fileName,
    bool isVipUser, {
    int appId = 0,
  }) async {
    if (!mounted) return;
    if (st.canDownload) {
      // ★ 1014：服务端已确认可下载 → 放行标志交给 addDownload
      logic.unlockVerified = true;
      runDownloadWithOverlay(() => logic.addDownload(fileName));
      return;
    }

    // ★ 1016：任务通道是否开启（后台 task_pwd.enable）
    var taskEnabled = false;
    try {
      final cfg = await TaskService.instance.config();
      taskEnabled = '${cfg?['enable'] ?? 0}' == '1';
    } catch (_) {}

    // 需要购买
    final price = st.price;
    // ★ 服务端说价格是 0 且已判定可下载 → 上面 canDownload 已处理；
    //   这里若价格为空或为 0，说明是「会员专享但未设价」，只引导开会员
    final hasPrice = price.isNotEmpty && (double.tryParse(price) ?? 0) > 0;
    if (!hasPrice) {
      await Get.dialog(
        AppDialog(
          title: const Text(
            '会员专享资源',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            '该资源需要开通会员后才能下载。',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('取消')),
            // ★ 1016：给普通用户一条「白嫖」通道 —— 做任务免费领会员
            if (taskEnabled)
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed(Routes.task);
                },
                child: const Text('做任务免费领'),
              ),
            FilledButton(
              onPressed: () {
                Get.back();
                Get.toNamed(Routes.vip);
              },
              child: const Text('开通会员'),
            ),
          ],
        ),
      );
      return;
    }

    final balance = st.balance;
    final enough =
        (double.tryParse(balance) ?? 0) >= (double.tryParse(price) ?? 0);
    final title = isVipUser ? '会员专享资源' : '付费资源';
    await Get.dialog(
      AppDialog(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '该软件需支付 ¥$price 后下载。',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: C.mint.withAlpha(22),
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Text(
                '当前余额 ¥$balance',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: C.mint,
                ),
              ),
            ),
            if (!enough) ...[
              const SizedBox(height: 8),
              Text(
                '余额不足，请先充值后再购买。',
                style: TextStyle(fontSize: 12, color: C.warning),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '会员用户可直接免费下载。',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            if (taskEnabled) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Get.back();
                  Get.toNamed(Routes.task);
                },
                child: Text(
                  '不想充值？完成简单任务可免费领会员 →',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: C.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Get.back();
              Get.toNamed(Routes.vip);
            },
            child: const Text('开通会员'),
          ),
          FilledButton(
            onPressed: () {
              Get.back();
              if (enough) {
                _buyWithBalance(appId, fileName, price);
              } else {
                Get.toNamed(Routes.recharge);
              }
            },
            child: Text(enough ? '余额支付 ¥$price' : '去充值'),
          ),
        ],
      ),
    );
  }

  /// 用余额购买并解锁
  Future<void> _buyWithBalance(int appId, String fileName, String price) async {
    final ok = await Get.dialog<bool>(
      AppDialog(
        title: const Text('确认支付'),
        content: Text(
          '将使用账户余额支付 ¥$price 购买该软件。\n'
          '购买后可永久下载，不再重复扣费。',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('支付 ¥$price'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await UnlockService.instance.buy(appId);
      await UserService.instance.refreshProfile();
      if (!mounted) return;
      ToastUtil.success('购买成功，开始下载');
      logic.unlockVerified = true; // 已支付
      runDownloadWithOverlay(() => logic.addDownload(fileName));
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// 提示弹窗。route 为空时只显示「知道了」关闭，不做跳转。
  void _dialog(String title, String msg, String okText, String? route) {
    Get.dialog(
      AppDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          if (route != null && route.isNotEmpty)
            TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Get.back();
              if (route != null && route.isNotEmpty) Get.toNamed(route);
            },
            child: Text(okText),
          ),
        ],
      ),
    );
  }

  Widget _phIcon() => Container(
    width: 80,
    height: 80,
    color: C.brand.withAlpha(35),
    child: Icon(Icons.android, color: C.brand, size: 38),
  );

  /// 截图画廊：左右滑动切换 + 保存到相册
  void _previewGallery(List<String> images, int start) {
    // ★ 全屏画廊不套玻璃壳：GlassShell/Dialog 约束会把 insetPadding:0 的
    //   Positioned.fill 压成居中小块（1027 真机翻车），必须原生 showDialog
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => _GalleryDialog(images: images, initial: start),
    );
  }

  void _preview(String url) => _previewGallery([url], 0);
}

/// 全屏画廊（PageView 左右切换 + 保存）
class _GalleryDialog extends StatefulWidget {
  final List<String> images;
  final int initial;
  const _GalleryDialog({required this.images, required this.initial});

  @override
  State<_GalleryDialog> createState() => _GalleryDialogState();
}

class _GalleryDialogState extends State<_GalleryDialog> {
  late final PageController _pc = PageController(initialPage: widget.initial);
  late int _cur = widget.initial;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final url = widget.images[_cur];
      final resp = await ApiHttp.attach(Dio()).get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = resp.data;
      if (data == null) {
        ToastUtil.error('保存失败');
        return;
      }
      final ok = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(data),
        name: 'softlib_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (ok != null) ToastUtil.success('已保存到相册');
    } catch (e) {
      ToastUtil.error('保存失败：请检查相册权限');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          // 图片区
          Positioned.fill(
            child: PageView.builder(
              controller: _pc,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _cur = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[i],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 顶部：关闭 + 页码
          Positioned(
            top: 44,
            left: 16,
            right: 16,
            child: Row(
              children: [
                AppPressable(
                  onTap: Get.back,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_cur + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          // 底部：保存
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: AppPressable(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: C.brand,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '保存图片',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
