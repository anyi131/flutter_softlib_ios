import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 下载目录统一入口：
///  · Android → 公共 Download 目录（保持原行为）
///  · iOS     → 应用 Documents/downloads（原代码硬编码 Android 路径，
///              在 iOS 上 enqueue 必然失败 → 软件下载功能双端不一致）
class DownloadDir {
  DownloadDir._();

  static Future<String> path() async {
    if (Platform.isAndroid) return '/storage/emulated/0/Download';
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/downloads');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }

  /// 找已下载文件时的兜底扫描目录
  static Future<List<String>> fallbackDirs() async {
    if (Platform.isAndroid) {
      return const [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Android/data/com.soft.anyi/files',
      ];
    }
    final docs = await getApplicationDocumentsDirectory();
    return ['${docs.path}/downloads', docs.path];
  }
}
