import 'package:flutter/material.dart';
import 'package:flutter_softlib/app/widgets/report_list/report_list_logic.dart';
import 'package:flutter_softlib/app/widgets/report_list/report_list_widget.dart';
import 'package:get/get.dart';

import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../models/http/results/report_cat_model.dart';
import 'tips_logic.dart';

class TipsComponent extends StatefulWidget {
  const TipsComponent({super.key});

  @override
  State<TipsComponent> createState() => _TipsComponentState();
}

class _TipsComponentState extends State<TipsComponent> {
  final TipsLogic logic = Get.find<TipsLogic>();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TipsLogic>(
      id: 'reportCatList',
      builder: (logic) {
        List<ReportCatData>? reportCats = logic.reportCatList;
        if (reportCats == null) {
          return const LoadingState(text: '正在加载线报分类…');
        }
        if (reportCats.isEmpty) {
          return const EmptyState(
            text: '暂无数据',
            hint: '线报分类还没有内容，稍后再来看看',
            icon: Icons.campaign_outlined,
          );
        }
        return DefaultTabController(
          length: reportCats.length,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('线报', style: Ty.h3),
              bottom: TabBar(
                tabs: reportCats
                    .map((reportCat) => Tab(text: reportCat.title ?? '未知标题'))
                    .toList(),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                overlayColor: WidgetStateColor.transparent,
                indicatorColor: C.brand,
                labelColor: C.brand,
                unselectedLabelColor: context.t2,
              ),
            ),
            body: TabBarView(
              children: reportCats.map((reportCat) {
                Get.lazyPut(
                  () => ReportListLogic(reportCat.id),
                  tag: reportCat.id.toString(),
                );
                return ReportListWidget(id: reportCat.id);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
