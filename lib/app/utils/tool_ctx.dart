import 'package:get/get.dart';

/// 当前打开的工具上下文
///
/// ★ 1020：工具打开后的页面要显示收藏星标，但工具页有 117 个，
///   逐个加 toolId 参数风险极大（漏改一处就编译失败）。
///   这里用一个轻量全局持有器：打开工具时写入 id + 名称，
///   ToolScaffold 读取它来渲染收藏按钮。
class ToolCtx {
  ToolCtx._();

  /// 由 GetX 的 permanent 实例承载，跨页面可读
  static final Rx<int> currentId = 0.obs;
  static final Rx<String> currentTitle = ''.obs;

  static void set(int id, String title) {
    currentId.value = id;
    currentTitle.value = title;
  }

  static void clear() {
    currentId.value = 0;
    currentTitle.value = '';
  }

  static int get id => currentId.value;
}
