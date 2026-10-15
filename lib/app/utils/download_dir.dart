import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 下载目录统一入口：
///  · Android → 公共目录 /storage/emulated/0/安逸软件汇（无则自动创建）
///              拿不到「所有文件访问」权限时退回系统 Download 目录
///  · iOS     → 应用 Documents/安逸软件汇
///
/// ★ 1015 修复：之前写死了 /storage/emulated/0/Download（系统默认目录），
///   把后台/即存已统一的「安逸软件汇」目录给丢了，用户找不到下载的文件。
class DownloadDir {
  DownloadDir._();

  /// 公共下载文件夹名（与即存模块保持一致）
  static const String folderName = '安逸软件汇';

  static Future<String> path() async {
    if (Platform.isAndroid) {
      try {
        final dir = Directory('/storage/emulated/0/$folderName');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir.path;
      } catch (_) {
        // 没有「所有文件访问」权限 → 退回系统 Download，保证下载不失败
        return '/storage/emulated/0/Download';
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/$folderName');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }

  /// 找已下载文件时的兜底扫描目录（先新目录，再老目录）
  static Future<List<String>> fallbackDirs() async {
    if (Platform.isAndroid) {
      return [
        '/storage/emulated/0/$folderName',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Android/data/com.soft.anyi/files',
      ];
    }
    final docs = await getApplicationDocumentsDirectory();
    return ['${docs.path}/$folderName', '${docs.path}/downloads', docs.path];
  }
}
