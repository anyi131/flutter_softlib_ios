import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 手机可用存储（MB）。拿不到返回 -1（未知）。
///
/// ★ 1029：原来 [app_details_logic] 里用 `Directory.systemTemp.statSync().size`，
///   那是「目录本身的 inode 大小」（4096 字节），算出来永远是 0 MB，
///   下载失败上报到后台就被判成「存储不足」，把真正的线路问题掩盖了。
class DiskSpace {
  static const _ch = MethodChannel('com.soft.anyi/device');

  static int _mb = -2;
  static DateTime _at = DateTime.fromMillisecondsSinceEpoch(0);

  /// 结果缓存 30 秒，避免同一批上报反复过通道。
  static Future<int> freeMb() async {
    final now = DateTime.now();
    if (_mb != -2 && now.difference(_at).inSeconds < 30) return _mb;
    var v = -1;
    try {
      final r = await _ch.invokeMethod<int>('freeMb');
      if (r != null && r >= 0) v = r;
    } catch (e) {
      debugPrint('[Softlib] freeMb 取不到: $e');
    }
    _mb = v;
    _at = now;
    return v;
  }

  /// 清掉缓存（下载结束、安装前后调用，保证上报的是当时的值）。
  static void invalidate() {
    _mb = -2;
  }
}
