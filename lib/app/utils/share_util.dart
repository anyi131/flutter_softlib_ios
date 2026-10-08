import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 系统分享辅助
///
/// ★ iOS 适配项：iPad 上系统分享面板是 **popover**，必须给出弹出锚点
///   （`sharePositionOrigin`），否则 share_plus 会抛异常、分享直接失败。
///   Android 会**忽略**该参数，因此这里统一返回值对安卓行为零影响。
class ShareUtil {
  ShareUtil._();

  /// 计算当前页面的分享锚点（非 iOS / 取不到时返回 null）
  static Rect? origin([BuildContext? context]) {
    final ctx = context ?? Get.context;
    if (ctx == null) return null;
    try {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return box.localToGlobal(Offset.zero) & box.size;
    } catch (_) {
      return null;
    }
  }
}
