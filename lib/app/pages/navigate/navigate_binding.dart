import 'package:get/get.dart';

import 'home/home_logic.dart';
import 'mine/mine_logic.dart';
import 'navigate_logic.dart';
import 'tips/tips_logic.dart';

class NavigateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NavigateLogic());
    Get.lazyPut(() => HomeLogic());
    Get.lazyPut(() => TipsLogic());
    // v54：MineLogic 注册收进 binding（此前在 build 里 Get.put，反模式）
    Get.lazyPut(() => MineLogic(), tag: 'mine', fenix: true);
  }
}
