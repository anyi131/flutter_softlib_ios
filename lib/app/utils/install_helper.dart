import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'share_util.dart';
import 'toast_util.dart';

/// **iOS 专用**：安装包的打开 / 分享动作
///
/// iOS 系统不允许安装 APK，也不存在「安装未知应用」权限，
/// 所以「安装」按钮在 iOS 上降级为：
///   ① 存储 / 分享到其它 App（share_plus → 可存 iCloud「文件」/ AirDrop / 微信…）
///   ② 用其他 App 打开（UIDocumentInteractionController）
///
/// ★ 安卓端不使用本类，安卓仍走 `ApkInstaller` + `OpenFilex` 原有链路。
class InstallHelper {
  InstallHelper._();

  /// 弹出 iOS 动作面板（下载完成 / 点「安装」时调用）
  static Future<void> openOnIos(String path, {String? name}) async {
    if (path.isEmpty) {
      ToastUtil.error('未找到下载文件');
      return;
    }
    if (!File(path).existsSync()) {
      ToastUtil.error('文件不存在或已被清理');
      return;
    }

    final ctx = Get.context;
    if (ctx == null) {
      await share(path, name: name);
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                (name == null || name.isEmpty) ? '已下载文件' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'iOS 不支持安装安卓安装包，可将其保存/分享到「文件」或发送到其它设备',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('存储 / 分享到其它 App'),
              onTap: () => Navigator.of(c).pop('share'),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('用其他应用打开'),
              onTap: () => Navigator.of(c).pop('open'),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Center(child: Text('取消')),
              onTap: () => Navigator.of(c).pop(),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (action == 'share') {
      await share(path, name: name);
    } else if (action == 'open') {
      try {
        final r = await OpenFilex.open(path);
        if (r.type != ResultType.done) {
          ToastUtil.info('没有可打开该文件的应用，试试「存储 / 分享」');
        }
      } catch (_) {
        ToastUtil.error('打开失败');
      }
    }
  }

  /// 直接调起系统分享面板
  static Future<void> share(String path, {String? name}) async {
    try {
      await Share.shareXFiles(
        [XFile(path)],
        text: (name == null || name.isEmpty) ? null : name,
        sharePositionOrigin: ShareUtil.origin(),
      );
    } catch (e) {
      ToastUtil.error('分享失败：$e');
    }
  }
}
