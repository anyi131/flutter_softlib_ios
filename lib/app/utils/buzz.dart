import 'package:vibration/vibration.dart';

/// ★ 1101 开源批二：业务触感
/// 全 App 只有系统 UI 级 HapticFeedback（玻璃底栏/工具页），业务节点无震感。
/// 纯新增：各节点可选调用，不支持震动的设备静默跳过。
class Buzz {
  Buzz._();

  /// 短哒一下——轻确认（下载完成、签到成功、消息到达）。
  static Future<void> light() async {
    try {
      if (await Vibration.hasVibrator() != true) return;
      await Vibration.vibrate(duration: 20);
    } catch (_) {}
  }

  /// 哒哒两下——中等反馈（任务完成、开关切换确认）。
  static Future<void> medium() async {
    try {
      if (await Vibration.hasVibrator() != true) return;
      await Vibration.vibrate(pattern: [40, 60, 40]);
    } catch (_) {}
  }

  /// 长震一下——强提示（出错、撤销警告）。
  static Future<void> heavy() async {
    try {
      if (await Vibration.hasVibrator() != true) return;
      await Vibration.vibrate(duration: 120);
    } catch (_) {}
  }
}
