import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../generated/assets.dart';
import '../../models/http/results/report_cat_list_model.dart';
import '../../design/ui.dart';
import '../../api/soft_service.dart';
import '../../widgets/tab_bottom_pad.dart';
import 'report_list_logic.dart';

class ReportListWidget extends StatefulWidget {
  final int? id;

  const ReportListWidget({super.key, this.id});

  @override
  State<ReportListWidget> createState() => _ReportListWidgetState();
}

class _ReportListWidgetState extends State<ReportListWidget>
    with AutomaticKeepAliveClientMixin<ReportListWidget> {
  late ReportListLogic logic;

  @override
  void initState() {
    super.initState();
    logic = Get.find<ReportListLogic>(tag: widget.id.toString());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GetBuilder<ReportListLogic>(
      id: 'reports',
      tag: widget.id.toString(),
      builder: (logic) {
        List<ReportData>? reports = logic.reports;
        if (logic.isLoading) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 3),
          );
        }
        if (reports == null || reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: Theme.of(context).disabledColor.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无相关报告',
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }
        return EasyRefresh(
          onLoad: logic.loadNextPage,
          onRefresh: logic.reload,
          controller: logic.easyRefreshController,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 16, 16, tabBottomPadding(context)),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              ReportData report = reports[index];
              final tpl = SoftService
                      .instance.cachedConfig?.uiConfig.tipsTemplate ??
                  'card';
              return switch (tpl) {
                'compact' => _buildCompact(context, report, logic),
                'timeline' => _buildTimeline(context, report, logic),
                'minimal_row' => _buildMiniRow(context, report, logic),
                'rich' => _buildRich(context, report, logic),
                'chat' => _buildChat(context, report, logic),
                _ => _buildItem(context, report),
              };
            },
          ),
        );
      },
    );
  }

  /// 构建列表元素
  Widget _buildItem(BuildContext context, ReportData report) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black45;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => logic.goToReadPage(report),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面图
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: report.image ?? '',
                    width: 110,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: theme.dividerColor.withAlpha(20),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Image.asset(
                      Assets.imagesSucceed,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 内容区
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 标题
                        Text(
                          report.title ?? '无标题',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        // 底部信息
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 浏览量
                            Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 14,
                                  color: secondaryTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${report.views ?? 0}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                            // 时间
                            Text(
                              logic.formatDateTime(report.createtime ?? 0),
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  /// v52m/v52t：紧凑单行
  Widget _buildCompact(
      BuildContext context, ReportData report, ReportListLogic logic) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ts = report.createtime ?? 0;
    final dt = ts > 0
        ? '${DateTime.fromMillisecondsSinceEpoch(ts * 1000).month}/${DateTime.fromMillisecondsSinceEpoch(ts * 1000).day}'
        : '';
    return InkWell(
      onTap: () => logic.goToReadPage(report),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                gradient: C.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                report.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? C.t1 : C.lt1,
                ),
              ),
            ),
            Text(dt,
                style: TextStyle(
                    fontSize: 10.5, color: isDark ? C.t3 : C.lt3)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: isDark ? C.t3 : C.lt3),
          ],
        ),
      ),
    );
  }

  /// v52t：时间轴
  Widget _buildTimeline(
      BuildContext context, ReportData report, ReportListLogic logic) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ts = report.createtime ?? 0;
    final dt = ts > 0
        ? '${DateTime.fromMillisecondsSinceEpoch(ts * 1000).month}/${DateTime.fromMillisecondsSinceEpoch(ts * 1000).day}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: C.brandGradient,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child:
                      Container(width: 2, color: C.brand.withAlpha(60)),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => logic.goToReadPage(report),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? C.t1 : C.lt1,
                            height: 1.35),
                      ),
                      const SizedBox(height: 4),
                      Text(dt,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? C.t3 : C.lt3)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// v52t：极简行
  Widget _buildMiniRow(
      BuildContext context, ReportData report, ReportListLogic logic) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () => logic.goToReadPage(report),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        child: Row(
          children: [
            Icon(Icons.flash_on_rounded,
                size: 14, color: C.brand.withAlpha(200)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                report.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: isDark ? C.t1 : C.lt1),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 15, color: isDark ? C.t3 : C.lt3),
          ],
        ),
      ),
    );
  }

  /// v52t：大图卡（无图退回经典卡）
  Widget _buildRich(
      BuildContext context, ReportData report, ReportListLogic logic) {
    final img = (report.image ?? '').toString();
    if (img.isEmpty) return _buildItem(context, report);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () => logic.goToReadPage(report),
      borderRadius: BorderRadius.circular(R.lg),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(R.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                report.title ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? C.t1 : C.lt1,
                    height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// v52w：聊天流模板（头像圆点 + 气泡）
  Widget _buildChat(
      BuildContext context, ReportData report, ReportListLogic logic) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ts = report.createtime ?? 0;
    final dt = ts > 0
        ? '${DateTime.fromMillisecondsSinceEpoch(ts * 1000).month}/${DateTime.fromMillisecondsSinceEpoch(ts * 1000).day}'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            child: Icon(Icons.campaign_rounded,
                size: 15, color: Colors.white),
            backgroundColor: C.brand.withAlpha(200),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('线报速递 · $dt',
                    style: TextStyle(
                        fontSize: 10, color: isDark ? C.t3 : C.lt3)),
                const SizedBox(height: 3),
                InkWell(
                  onTap: () => logic.goToReadPage(report),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(isDark ? 30 : 18),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Text(
                      report.title ?? '',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? C.t1 : C.lt1),
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

}
