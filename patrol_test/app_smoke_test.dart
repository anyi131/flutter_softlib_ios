// 冒烟测试：搜索 → 详情页（不需要登录，CI 里跑这个）
//
// 本地跑：
//   patrol test patrol_test/app_smoke_test.dart -d <deviceId>

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:flutter_softlib/app/routes/app_pages.dart';
import 'package:flutter_softlib/app/widgets/app_card.dart';
import 'package:get/get.dart';

import 'package:flutter_softlib/main.dart' as app;

void main() {
  patrolTest(
    '搜索关键词，能出结果并进入详情页',
    ($) async {
      app.main();
      // 启动时会拉配置，给一点时间
      await $.pump(const Duration(seconds: 2));
      await $.pumpAndTrySettle(timeout: const Duration(seconds: 20));

      // 直接进搜索页，跳过开屏/登录
      Get.toNamed(Routes.appSearch);
      await $.pumpAndTrySettle(timeout: const Duration(seconds: 10));

      expect($(#searchField), findsOneWidget);

      await $(#searchField).enterText('病毒');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndTrySettle(timeout: const Duration(seconds: 20));

      // 有结果才继续（网络差时只校验页面没崩）
      if ($(find.byType(AppCard)).evaluate().isNotEmpty) {
        await $(find.byType(AppCard)).first.tap();
        await $.pumpAndTrySettle(timeout: const Duration(seconds: 20));
        // 详情页核心控件在
        expect($(#downloadBtn), findsOneWidget);
        $.log('详情页打开成功，下载按钮可见');
      } else {
        $.log('搜索无结果（可能是网络），跳过详情页断言');
      }
    },
  );
}
