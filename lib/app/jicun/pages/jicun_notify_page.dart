////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 通知管理设置页
// 三个本机开关：下载完成提醒 / 失败提醒 / 仅 Wi-Fi 下载。
// 改动立刻写 JicunPrefs（先改内存再异步落盘），不需要「保存」按钮。
////////////////////////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../jicun_prefs.dart';

/// 「通知管理」二级页。
class JicunNotifyPage extends StatefulWidget {
  const JicunNotifyPage({super.key});

  @override
  State<JicunNotifyPage> createState() => _JicunNotifyPageState();
}

class _JicunNotifyPageState extends State<JicunNotifyPage> {
  bool _done = JicunPrefs.instance.notifyOnDone;
  bool _fail = JicunPrefs.instance.notifyOnFail;
  bool _wifiOnly = JicunPrefs.instance.wifiOnly;

  @override
  void initState() {
    super.initState();
    _syncFromDisk();
  }

  /// 启动时若没 load 过，补读一次（幂等），读到盘上值再刷新开关。
  Future<void> _syncFromDisk() async {
    await JicunPrefs.instance.load();
    if (!mounted) return;
    final prefs = JicunPrefs.instance;
    if (prefs.notifyOnDone == _done &&
        prefs.notifyOnFail == _fail &&
        prefs.wifiOnly == _wifiOnly) {
      return;
    }
    setState(() {
      _done = prefs.notifyOnDone;
      _fail = prefs.notifyOnFail;
      _wifiOnly = prefs.wifiOnly;
    });
  }

  void _setDone(bool v) {
    setState(() => _done = v);
    JicunPrefs.instance.setNotifyOnDone(v);
  }

  void _setFail(bool v) {
    setState(() => _fail = v);
    JicunPrefs.instance.setNotifyOnFail(v);
  }

  void _setWifiOnly(bool v) {
    setState(() => _wifiOnly = v);
    JicunPrefs.instance.setWifiOnly(v);
  }

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      6,
                      context.pagePadding,
                      32 + context.safeBottom,
                    ),
                    children: [
                      KitCard(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(R.lg),
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                _switchTile(
                                  context,
                                  title: '下载完成提醒',
                                  subtitle: '每个任务保存成功后提醒一次',
                                  value: _done,
                                  onChanged: _setDone,
                                ),
                                _divider(context),
                                _switchTile(
                                  context,
                                  title: '失败提醒',
                                  subtitle: '解析失败或下载出错时提醒，免得白等',
                                  value: _fail,
                                  onChanged: _setFail,
                                ),
                                _divider(context),
                                _switchTile(
                                  context,
                                  title: '仅 Wi-Fi 下载',
                                  subtitle: '移动网络下不开始新任务，避免消耗流量',
                                  value: _wifiOnly,
                                  onChanged: _setWifiOnly,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _note(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: C.brand,
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: context.t1,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: context.t3,
          ),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      height: 0.6,
      margin: const EdgeInsets.only(left: 16),
      color: context.isDark
          ? Colors.white.withAlpha(14)
          : Colors.black.withAlpha(8),
    );
  }

  Widget _note(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: context.t3),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '提醒在下载页内以轻提示呈现；关闭后仍会正常下载，只是不再弹出提醒。'
              '仅 Wi-Fi 开关只影响新任务，不会中断正在下载的任务。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.55,
                color: context.t3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶栏：左返回 + 居中标题。
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
              '通知管理',
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
}
