import 'dart:io';

import 'package:flutter/services.dart';

/// 调用系统安装器安装 APK
///
/// 说明：open_filex 走的是通用「查看文件」意图，系统会弹「打开方式」选择器。
/// 这里改用原生 PackageInstaller 意图，只有真正的安装器能响应。
class ApkInstaller {
  ApkInstaller._();

  static const MethodChannel _ch = MethodChannel('softlib/installer');

  /// 是否已获得「安装未知应用」权限
  static Future<bool> canInstall() async {
    if (!Platform.isAndroid) return true;
    try {
      final ok = await _ch.invokeMethod<bool>('canRequestPackageInstalls');
      return ok ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 打开系统「安装未知应用」权限设置页
  static Future<void> openInstallSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// 安装 APK（返回是否成功唤起安装器）
  static Future<bool> install(String path) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod<bool>('installApk', {'path': path});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// ★ 1102a：判断一个 apk 文件是不是「本 App 自更新包」。
  ///
  /// 更新流程下载的更新包（softlib_update_<ts>.apk）与业务软件包落在
  /// 同一个公共下载目录。历史上「找包兜底 = 扫目录里最新的 .apk」会把
  /// 刚下完的自更新包误当成业务软件包装出去 —— 用户点「小黄库·安装」
  /// 弹出的却是「安逸软件汇 29.23MB/3.10.30」本体安装界面。
  /// 所有按文件名找包的兜底都必须先过这个过滤器。
  static bool isOwnUpdatePackage(String path) {
    final name = path.split('/').last.toLowerCase();
    return name.startsWith('softlib_update_') && name.endsWith('.apk');
  }

  /// 从一批 apk 路径里按「目标应用名」挑选最匹配的一个（找不到则返回 null）。
  ///
  /// 匹配策略：文件名（去扩展名、去尾部 _<时间戳>）与应用名/下载名
  /// 的前缀或包含关系；都不匹配时返回 null —— 宁可不装也不能装错包。
  static String? pickMatchingApk(
    Iterable<String> paths,
    String? targetName,
  ) {
    final candidates = paths
        .where((p) => p.toLowerCase().endsWith('.apk'))
        .where((p) => !isOwnUpdatePackage(p))
        .toList();
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;
    if (targetName == null || targetName.trim().isEmpty) return null;

    String norm(String s) => s
        .replaceAll(RegExp(r'[^0-9a-zA-Z\u4e00-\u9fa5]'), '')
        .toLowerCase();
    final target = norm(targetName);
    if (target.isEmpty) return null;

    String base(String p) {
      var n = p.split('/').last;
      n = n.substring(0, n.length - 4); // 去 .apk
      n = n.replaceFirst(RegExp(r'_\d{10,}$'), ''); // 去尾部时间戳
      return norm(n);
    }

    // 前缀匹配 > 包含匹配，各按文件修改时间倒序（同分取最新）
    int score(String p) {
      final b = base(p);
      if (b == target) return 4;
      if (b.startsWith(target) || target.startsWith(b)) return 3;
      if (b.contains(target) || target.contains(b)) return 2;
      return 0;
    }

    String? best;
    DateTime? bestTime;
    int bestScore = 0;
    for (final p in candidates) {
      final s = score(p);
      if (s == 0) continue;
      DateTime t;
      try {
        t = File(p).statSync().modified;
      } catch (_) {
        t = DateTime.fromMillisecondsSinceEpoch(0);
      }
      if (best == null ||
          s > bestScore ||
          (s == bestScore && t.isAfter(bestTime!))) {
        best = p;
        bestTime = t;
        bestScore = s;
      }
    }
    return best;
  }
}
