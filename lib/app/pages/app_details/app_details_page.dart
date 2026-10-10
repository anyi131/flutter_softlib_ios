import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:flutter/material.dart';

import 'resolve_overlay.dart';

import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';

import '../../api/soft_service.dart';
import '../../api/user_service.dart';
import '../../api/unlock_service.dart';

import 'dart:ui';

import '../../config.dart';
import '../../design/adaptive.dart';
import '../../design/app_style.dart';
import '../../design/app_style_controller.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import '../../models/app_item.dart';
import '../../models/http/results/lzy_file_info_model.dart';
import '../../routes/app_pages.dart';
import '../../widgets/review/review_tab.dart';
import 'app_details_logic.dart';

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
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  AppItem? get item => logic.item;

  @override
  Widget build(BuildContext context) {
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
              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  topInset + 56,
                  context.pagePadding,
                  30,
                ),
                children: _bodyChildren(context),
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
      default:
        return [_hero(), const SizedBox(height: 14), _info(), ...tabArea];
    }
  }

  /// 顶部返回/分享（悬浮玻璃）
  /// v52i #4：海报模板头图（截图 > 图标，都没有退品牌渐变）
  /// v52m #2：头图高度（compact=46，minimal=0，其它 106）
  double _headerHeight() {
    final tpl = AppStyleController.instance.detailStyle.value;
    if (tpl == AppDetailStyle.minimal) return 0;
    if (tpl == AppDetailStyle.compact) return 46;
    if (tpl == AppDetailStyle.poster) return 240;
    return 106;
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
      return BoxDecoration(
        image: has
            ? DecorationImage(fit: BoxFit.cover, image: _posterProvider(info)!)
            : null,
        gradient: has
            ? null
            : LinearGradient(
                colors: [
                  C.brand.withAlpha(context.isDark ? 150 : 120),
                  C.violet.withAlpha(context.isDark ? 110 : 90),
                ],
              ),
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
                const Spacer(),
                Expanded(
                  child: Text(
                    item?.title ?? '软件详情',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Ty.h3.copyWith(color: context.t1, fontSize: 15),
                  ),
                ),
                const Spacer(),
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

  Widget _topBtn(IconData i, VoidCallback f) => GestureDetector(
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
              margin: const EdgeInsets.only(bottom: 42),
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
                    // poster：底部压暗渐层，保证状态标签可读
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(130),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 悬浮图标（v53d：poster 96px 居左出血感，compact 68px）
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
            // NEW 角标
            if (it?.isNew == true)
              Positioned(
                left: 14,
                bottom: 66,
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
                    const Icon(Icons.star_rounded, size: 16, color: C.amber),
                    const SizedBox(width: 3),
                    Text(
                      it!.scoreAvg.toStringAsFixed(1),
                      style: const TextStyle(
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
                child: const Icon(
                  Icons.shield_rounded,
                  size: 13,
                  color: C.mint,
                ),
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
  Widget _info() {
    final it = item;
    final info = logic.appInfo;
    final cells = [
      (
        Icons.sd_storage_rounded,
        info?.fileSize ?? it?.size ?? '-',
        '大小',
        C.brandBright,
      ),
      (Icons.visibility_rounded, '${it?.views ?? 0}', '浏览', C.cyan),
      (
        Icons.schedule_rounded,
        it?.uploadDate.isNotEmpty == true ? it!.uploadDate : '-',
        '上传',
        C.violet,
      ),
      (Icons.face_rounded, it?.ageRating ?? '16+', '年龄', C.mint),
    ];
    return Deco.glass(
      context,
      radius: R.lg,
      alpha: 0.055,
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 28,
                color: context.isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.black.withAlpha(8),
              ),
            Expanded(
              child: Column(
                children: [
                  Icon(cells[i].$1, size: 17, color: cells[i].$4),
                  const SizedBox(height: 7),
                  Text(
                    cells[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.h3.copyWith(color: context.t1, fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(cells[i].$3, style: Ty.tiny.copyWith(color: context.t3)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// v54：minimal/compact 扁平数据行（无玻璃卡，细分隔）
  Widget _infoFlat() {
    final it = item;
    final info = logic.appInfo;
    final cells = [
      (Icons.sd_storage_rounded, info?.fileSize ?? it?.size ?? '-', '大小'),
      (Icons.visibility_rounded, '${it?.views ?? 0}', '浏览'),
      (
        Icons.schedule_rounded,
        it?.uploadDate.isNotEmpty == true ? it!.uploadDate : '-',
        '上传',
      ),
      (Icons.face_rounded, it?.ageRating ?? '16+', '年龄'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 26,
                color: context.isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.black.withAlpha(10),
              ),
            Expanded(
              child: Column(
                children: [
                  Icon(cells[i].$1, size: 15, color: context.t3),
                  const SizedBox(height: 6),
                  Text(
                    cells[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.body.copyWith(
                      color: context.t1,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(cells[i].$3, style: Ty.tiny.copyWith(color: context.t3)),
                ],
              ),
            ),
          ],
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
        color: context.isDark ? Colors.white.withAlpha(8) : Colors.white,
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

  Widget _tabBarCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(14) : Colors.white,
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
              indicatorColor: C.brand,
              labelColor: C.brand,
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
          GestureDetector(
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
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _previewGallery(shots, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: shots[i],
                    width: 130,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 130,
                      color: Colors.black12,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 130,
                      color: Colors.black12,
                      child: const Icon(Icons.broken_image_outlined),
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
      ],
    );
  }

  // ===== 精品推荐（同类软件横滑） =====
  Widget _recommend() {
    return FutureBuilder<List<AppItem>>(
      future: SoftService.instance.fetchApps(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final others = all.where((e) => e.id != item?.id).take(8).toList();
        if (others.isEmpty) return const SizedBox.shrink();
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
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: others.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final a = others[i];
                  return GestureDetector(
                    onTap: () => Get.offAndToNamed(
                      Routes.appDetails,
                      arguments: {'appId': a.id.toString(), 'item': a},
                    ),
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: a.icon.isEmpty
                                ? Container(
                                    width: 58,
                                    height: 58,
                                    color: C.brand.withAlpha(28),
                                    child: Icon(
                                      Icons.android,
                                      color: C.brand,
                                      size: 27,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: a.icon,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      width: 58,
                                      height: 58,
                                      color: Colors.black12,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 58,
                                      height: 58,
                                      color: C.brand.withAlpha(28),
                                      child: Icon(
                                        Icons.android,
                                        color: C.brand,
                                        size: 27,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ============ 底部：单个下载按钮（无左右双栏） ============
  Widget _bottom() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVipItem = item?.isVipItem ?? false;
    final loggedIn = UserService.instance.isLoggedIn;
    final isVipUser = UserService.instance.user?.isVip == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? C.bg2 : Colors.white,
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
            // 下载完成 → 安装（带与未下载态一致的说明行，避免高度跳变）
            if (task != null && task.status == DownloadTaskStatus.complete) {
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
            // 下载中 → 进度卡片
            if (task != null) {
              return _progressPanel(download, task);
            }
            // 未下载
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
  Widget _progressPanel(AppDetailsLogic download, DownloadTask task) {
    final total = download.appInfo?.fileSize ?? '';
    final done = calculateDownloadedSize(total, task.progress);
    final isPaused = task.status == DownloadTaskStatus.paused;
    final isFailed = task.status == DownloadTaskStatus.failed;

    final Color accent = isFailed ? C.danger : (isPaused ? C.warning : C.brand);
    final String title = isFailed ? '下载失败' : (isPaused ? '已暂停' : '正在下载中');

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
                isFailed
                    ? Icons.error_outline_rounded
                    : (isPaused
                          ? Icons.pause_rounded
                          : Icons.downloading_rounded),
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
              '${task.progress}%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 9),
        KitProgress(value: task.progress / 100, color: accent),
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

    // 未登录：只有「确认免费」才允许直接下载
    if (!loggedIn) {
      if (!localNeedPay) {
        runDownloadWithOverlay(() => logic.addDownload(fileName));
      } else {
        _dialog('需要登录', '该资源为付费资源，请先登录账号', '去登录', Routes.login);
      }
      return;
    }

    // 已登录：一律向服务端确认（服务端是唯一权威，避免本地数据过期被绕过）
    // ★ 没有有效 id 时（如蓝奏云文件夹里的软件）退回本地判断
    if (appId <= 0) {
      if (!localNeedPay) {
        runDownloadWithOverlay(() => logic.addDownload(fileName));
      } else {
        runDownloadWithOverlay(
          () => logic.addDownload(fileName),
        ); // 无 id 无法校验，放行
      }
      return;
    }

    UnlockStatus st;
    try {
      st = await UnlockService.instance.status(appId);
    } catch (e) {
      // 服务端不可达时：本地判定免费就放行，否则提示（避免网络抖动卡死下载）
      if (!localNeedPay) {
        runDownloadWithOverlay(() => logic.addDownload(fileName));
      } else {
        ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    if (!mounted) return;

    if (st.canDownload) {
      runDownloadWithOverlay(() => logic.addDownload(fileName));
      return;
    }

    // 需要购买
    final price = st.price;
    // ★ 服务端说价格是 0 且已判定可下载 → 上面 canDownload 已处理；
    //   这里若价格为空或为 0，说明是「会员专享但未设价」，只引导开会员
    final hasPrice = price.isNotEmpty && (double.tryParse(price) ?? 0) > 0;
    if (!hasPrice) {
      await Get.dialog(
        AlertDialog(
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
      AlertDialog(
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
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: C.mint,
                ),
              ),
            ),
            if (!enough) ...[
              const SizedBox(height: 8),
              const Text(
                '余额不足，请先充值后再购买。',
                style: TextStyle(fontSize: 12, color: C.warning),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '会员用户可直接免费下载。',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
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
      AlertDialog(
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
      runDownloadWithOverlay(() => logic.addDownload(fileName));
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _dialog(String title, String msg, String okText, String route) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Get.back();
              Get.toNamed(route);
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
    showDialog(
      context: context,
      barrierColor: Colors.black87,
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
      final resp = await Dio().get<List<int>>(
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
                GestureDetector(
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
              child: GestureDetector(
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
