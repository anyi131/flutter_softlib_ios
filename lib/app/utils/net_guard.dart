import 'dart:io';

/// ★ 1016：流量提醒
///
/// 需求：非 WiFi 下下载大安装包前，先提示用户（避免流量焦虑）
///
/// 实现：不引入 connectivity_plus（少一个原生依赖），
///      Android 用 `ip route` 判断默认路由是否走 wlan，
///      iOS 无法可靠判断时**按 WiFi 处理**（避免误拦截），
///      并记住用户的「总是允许」选择。
class NetGuard {
  NetGuard._();

  /// 记住「本次/总是允许移动网络下载」（内存级，重启失效即可）
  static bool allowMobileThisSession = false;

  /// 是否处于移动网络（尽量准确，判断不了时返回 false = 不打扰）
  static Future<bool> isMobile() async {
    if (!Platform.isAndroid) return false;
    try {
      final r = await Process.run('ip', [
        'route',
        'get',
        '1.1.1.1',
      ]).timeout(const Duration(seconds: 2));
      final out = '${r.stdout}'.toLowerCase();
      if (out.isEmpty) return false;
      // 默认路由走 wlan0 → WiFi；走 rmnet/ccmni → 蜂窝
      if (out.contains('wlan')) return false;
      if (out.contains('rmnet') ||
          out.contains('ccmni') ||
          out.contains('wwan')) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 下载前检查：需要提醒则返回要提示的文案，否则返回 null
  static Future<String?> confirmMessage(int sizeBytes) async {
    if (allowMobileThisSession) return null;
    if (!await isMobile()) return null;
    // 小于 20MB 不提醒
    if (sizeBytes > 0 && sizeBytes < 20 * 1024 * 1024) return null;
    final mb = sizeBytes > 0
        ? '${(sizeBytes / 1048576).toStringAsFixed(1)} MB'
        : '较大的';
    return '当前是移动数据网络，安装包约 $mb\n继续下载会消耗流量';
  }
}
