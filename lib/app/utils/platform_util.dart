import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 跨平台能力封装 —— Android / iOS 的差异集中在这里
///
/// ★ 原则：**安卓端行为保持不变**。本文件所有分支在 Android 上都返回与
///   适配前完全一致的取值，iOS 才走新的分支。
///
/// iOS 适配要点：
///  1. iOS 沙盒不允许写 `Download/` 公共目录，下载目录必须是 App 沙盒内的路径
///     （`Documents/Download`，用户可在「文件」App 里看到「软件库」文件夹）。
///  2. iOS 系统层面**不允许安装 APK**，也不存在「安装未知应用」权限，
///     因此 iOS 端「安装」动作降级为**分享 / 用其他 App 打开 / 存到文件**。
///  3. `saveInPublicStorage`、`openFileFromNotification` 均为 Android 专属参数，
///     iOS 上传 true 会导致下载失败。
class PlatUtil {
  PlatUtil._();

  static bool get isAndroid => Platform.isAndroid;

  static bool get isIOS => Platform.isIOS;

  /// 是否能安装 APK（只有 Android 可以）
  static bool get canInstallApk => Platform.isAndroid;

  /// 下载任务保存目录
  ///
  /// - Android：公共下载目录 `/storage/emulated/0/Download`（与适配前完全一致）
  /// - iOS：`<沙盒>/Documents/Download`（iOS 无法写入沙盒外）
  static Future<String> downloadDir() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/Download');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir.path;
    } catch (e) {
      debugPrint('[Softlib] downloadDir fallback: $e');
      try {
        return (await getTemporaryDirectory()).path;
      } catch (_) {
        return Directory.systemTemp.path;
      }
    }
  }

  /// 是否把文件存入公共存储（Android 专属；iOS 无此概念）
  static bool get saveInPublicStorage => Platform.isAndroid;

  /// 下载完成后点击通知栏直接打开文件（Android 专属）
  static bool get openFileFromNotification => Platform.isAndroid;
}
