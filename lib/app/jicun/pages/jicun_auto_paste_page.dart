////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 自动粘贴设置页
// 一个开关：进入即存页时读取剪贴板首条链接并解析。
// 隐私口径写死在副标题里：只在打开页面时读一次，不上传。
////////////////////////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../jicun_prefs.dart';

/// 「自动粘贴」二级页。
class JicunAutoPastePage extends StatefulWidget {
  const JicunAutoPastePage({super.key});

  @override
  State<JicunAutoPastePage> createState() => _JicunAutoPastePageState();
}

class _JicunAutoPastePageState extends State<JicunAutoPastePage> {
  bool _on = JicunPrefs.instance.autoPaste;

  @override
  void initState() {
    super.initState();
    _syncFromDisk();
  }

  /// 启动时若没 load 过，这里补一次（幂等）；有盘上值就以盘上值为准。
  Future<void> _syncFromDisk() async {
    await JicunPrefs.instance.load();
    if (!mounted) return;
    final v = JicunPrefs.instance.autoPaste;
    if (v != _on) setState(() => _on = v);
  }

  void _toggle(bool v) {
    setState(() => _on = v);
    // 先改内存缓存（getter 立刻可见），写盘在后台完成。
    JicunPrefs.instance.setAutoPaste(v);
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
                _topBar(context, '自动粘贴'),
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
                            child: SwitchListTile(
                              value: _on,
                              onChanged: _toggle,
                              activeThumbColor: C.brand,
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                6,
                                10,
                                6,
                              ),
                              title: Text(
                                '进入即存页自动解析剪贴板链接',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.t1,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  '打开后，进入即存页时自动读取剪贴板里的链接并解析。\n'
                                  '只在你打开页面时读取一次，不会后台上传。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: context.t3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _hint(context),
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

  Widget _hint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: context.t3),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '开关状态只保存在这台设备上；剪贴板只在进入页面时读取一次，'
              '不会在后台轮询。',
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
  Widget _topBar(BuildContext context, String title) {
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
              title,
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
