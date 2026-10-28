////////////////////////////////////////////////////////////////////////////////
// 即存 · 当前是否在移动网络
//
// 「仅 Wi-Fi 下载」开关需要一个判断依据。项目里没有 connectivity_plus，
// 这里用 dart:io 的网卡列表做启发式判断（不需要任何插件/权限）：
//   · Wi-Fi / 有线：en0/en1(iOS/macOS)、wlan*、eth*、ap*
//   · 蜂窝：pdp_ip*(iOS)、rmnet*、ccmni*、wwan*、radio*
// 判不准（比如只剩 dummy0/lo）返回 null，调用方应「放行」而不是拦下来。
////////////////////////////////////////////////////////////////////////////////
import 'dart:io';

/// 从网卡名推断网络类型：true=蜂窝，false=Wi-Fi/有线，null=判断不了。
///
/// 只要存在一块非蜂窝接口就按 Wi-Fi 处理——双栈时蜂窝网卡常常也挂在列表里。
bool? jicunCellularFromInterfaces(Iterable<String> names) {
  var hasWifi = false;
  var hasCell = false;
  for (final raw in names) {
    final name = raw.trim().toLowerCase();
    if (name.isEmpty) continue;
    if (name.startsWith('en0') ||
        name.startsWith('en1') ||
        name.startsWith('wlan') ||
        name.startsWith('eth') ||
        name.startsWith('ap')) {
      hasWifi = true;
      continue;
    }
    if (name.startsWith('pdp_ip') ||
        name.startsWith('rmnet') ||
        name.startsWith('ccmni') ||
        name.startsWith('wwan') ||
        name.startsWith('radio')) {
      hasCell = true;
    }
  }
  if (hasWifi) return false;
  if (hasCell) return true;
  return null;
}

/// 读本机网卡判断当前是否移动网络；读不到（权限/异常）返回 null。
Future<bool?> jicunIsCellular() async {
  try {
    final list = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    return jicunCellularFromInterfaces(list.map((e) => e.name));
  } catch (_) {
    return null;
  }
}
