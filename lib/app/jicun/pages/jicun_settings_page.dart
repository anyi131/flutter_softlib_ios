////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 设置主页
// 三段式入口：自动粘贴 / 存储位置 / 通知管理。
// 只读本机偏好（JicunPrefs），不依赖网络。
////////////////////////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../jicun_prefs.dart';
import 'jicun_auto_paste_page.dart';
import 'jicun_notify_page.dart';
import 'jicun_storage_page.dart';

/// 「即存设置」主页。
class JicunSettingsPage extends StatelessWidget {
  const JicunSettingsPage({super.key});

  /// 版本号只取一次，避免每次重建都走一次平台通道。
  static Future<String>? _versionFuture;

  static Future<String> _version() {
    return _versionFuture ??= _readVersion();
  }

  static Future<String> _readVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      // 取不到版本号（例如平台通道不可用）时不挡页面展示。
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 幂等：万一启动时没调用过 load，这里补一次；
    // 读到新值会 bump revision，下面的 ValueListenableBuilder 自动刷新。
    if (!JicunPrefs.instance.isLoaded) JicunPrefs.instance.load();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _topBar(context),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 自定义顶栏：左返回 + 居中标题（与即存其它页面一致）。
  Widget _topBar(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: context.t1,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              '即存设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: context.t1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: JicunPrefs.instance.revision,
      builder: (context, _, __) {
        final prefs = JicunPrefs.instance;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            4,
            context.pagePadding,
            32 + context.safeBottom,
          ),
          children: [
            KitCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(R.lg),
                child: Column(
                  children: [
                    _row(
                      context,
                      icon: Icons.content_paste_rounded,
                      title: '自动粘贴',
                      subtitle: prefs.autoPaste ? '已开启' : '已关闭',
                      onTap: () => _open(context, const JicunAutoPastePage()),
                    ),
                    _divider(context),
                    _row(
                      context,
                      icon: Icons.folder_rounded,
                      title: '存储位置',
                      subtitle: prefs.saveDirName,
                      onTap: () => _open(context, const JicunStoragePage()),
                    ),
                    _divider(context),
                    _row(
                      context,
                      icon: Icons.notifications_active_rounded,
                      title: '通知管理',
                      subtitle: '下载完成、失败提醒',
                      onTap: () => _open(context, const JicunNotifyPage()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _footer(context),
          ],
        );
      },
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: C.brand.withAlpha(context.isDark ? 34 : 20),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: C.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.t3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.t3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      height: 0.6,
      margin: const EdgeInsets.only(left: 62),
      color: context.isDark
          ? Colors.white.withAlpha(14)
          : Colors.black.withAlpha(8),
    );
  }

  Widget _footer(BuildContext context) {
    return FutureBuilder<String>(
      future: _version(),
      builder: (context, snapshot) {
        final version = snapshot.data ?? '';
        final text = version.isEmpty
            ? '以上设置仅保存在本机'
            : '版本 $version · 以上设置仅保存在本机';
        return Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.5,
            color: context.t3,
          ),
        );
      },
    );
  }
}
