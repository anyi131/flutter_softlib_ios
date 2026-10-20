import 'package:get/get.dart';

import 'app_details_logic.dart';

class AppDetailsBinding extends Bindings {
  @override
  void dependencies() {
    // ★★ 1020 修复「精品推荐 / 你可能还喜欢 点击后不刷新」：
    //   详情页跳到另一个详情页时走 offAndToNamed，页面被移除、控制器被销毁，
    //   但 lazyPut 没开 fenix → 下次进入拿到的还是已销毁的旧实例，
    //   onInit 不再执行 → item 仍指向上一个软件，看起来就是「点了没反应」。
    //   fenix: true 表示「销毁后可重建」，保证每次进入都是全新的控制器。
    Get.lazyPut(() => AppDetailsLogic(), fenix: true);
  }
}
