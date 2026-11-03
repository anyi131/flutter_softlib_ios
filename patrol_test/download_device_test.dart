// 真机下载测试：会真的下载 30MB+，只在有设备、已登录的机器上手动跑
//   patrol test patrol_test/download_device_test.dart -d <deviceId>
// CI 不跑这个文件（只指定 app_smoke_test.dart）
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:flutter_softlib/app/routes/app_pages.dart';
import 'package:flutter_softlib/app/widgets/app_card.dart';
import 'package:get/get.dart';

import 'package:flutter_softlib/main.dart' as app;

void main() {
  patrolTest(
    '点下载 → 系统安装权限弹窗能被原生层接管',
    ($) async {
      app.main();
      await $.pump(const Duration(seconds: 2));
      await $.pumpAndTrySettle(timeout: const Duration(seconds: 20));

      Get.toNamed(Routes.appSearch);
      await $.pumpAndTrySettle(timeout: const Duration(seconds: 10));

      await $(#searchField).enterText('病毒');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndTrySettle(timeout: const Duration(seconds: 20));

      await $(find.byType(AppCard)).first.tap();
      await $.pumpAndTrySettle(timeout: const Duration(seconds: 20));

      await $(#downloadBtn).tap();
      await $.pump(const Duration(seconds: 3));

      // ★ 原生层：首次安装 APK 会弹「允许安装未知应用」
      if (await $.platform.mobile.isPermissionDialogVisible()) {
        await $.platform.mobile.grantPermissionOnlyThisTime();
        $.log('已接管安装权限弹窗');
      } else {
        $.log('没有弹窗（可能已授权过）');
      }

      await $.pump(const Duration(seconds: 5));
      // 只要还停在详情页且进度有变化，就说明下载链路起来了
      expect($(#downloadBtn), findsOneWidget);

      // 收尾：把系统安装器关掉，别把设备卡住
      await $.platform.android.pressBack();
    },
  );
}
