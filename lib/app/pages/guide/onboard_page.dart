import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/adaptive.dart';
import '../../design/ui.dart';
import '../../routes/app_pages.dart';

/// 首次启动引导
///
/// ★ 1020：新用户不知道「下载流程 = 解析 → 安装」，容易卡在详情页以为坏了。
///   这里用 3 屏讲清楚：找软件 → 点解析下载 → 允许安装。
///
/// 只显示一次（SharedPreferences 记忆）。
class OnboardPage extends StatefulWidget {
  const OnboardPage({super.key, required this.nextRoute});

  final String nextRoute;

  @override
  State<OnboardPage> createState() => _OnboardPageState();
}

class _OnboardPageState extends State<OnboardPage> {
  final _pc = PageController();
  int _i = 0;

  // ★ C.brand 等是 static var，不能进 const 列表 → 改为 getter
  static List<({IconData icon, Color color, String title, String desc})>
  get _pages => [
    (
      icon: Icons.search_rounded,
      color: C.brand,
      title: '找到你要的软件',
      desc: '顶部搜索框输入名字，或按分类浏览。\n支持拼音首字母，输入 wx 就能找到微信。',
    ),
    (
      icon: Icons.download_rounded,
      color: C.mint,
      title: '点一下就能下载',
      desc: '详情页点「解析并下载」，系统会自动解析\n蓝奏云直链并开始下载，不需要跳浏览器。',
    ),
    (
      icon: Icons.verified_user_rounded,
      color: C.amber,
      title: '允许安装未知来源',
      desc: '首次安装需要允许本应用安装软件：\n设置 → 应用 → 特殊权限 → 安装未知应用。\n只需设置一次。',
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('onboard_done', true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(widget.nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      '跳过',
                      style: TextStyle(fontSize: 13, color: context.t3),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _i = i),
                    itemBuilder: (c, i) {
                      final p = _pages[i];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.pagePadding + 16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    p.color.withAlpha(context.isDark ? 90 : 44),
                                    p.color.withAlpha(0),
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: p.color.withAlpha(
                                    context.isDark ? 60 : 30,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(p.icon, size: 38, color: p.color),
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              p.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: context.t1,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              p.desc,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.85,
                                color: context.t2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final on = i == _i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: on ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: on ? C.brand : context.t3.withAlpha(70),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    0,
                    context.pagePadding,
                    30,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        if (last) {
                          _finish();
                        } else {
                          _pc.nextPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: C.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        last ? '开始使用' : '下一步',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 是否需要展示引导（只显示一次）
Future<bool> shouldShowOnboard() async {
  try {
    final sp = await SharedPreferences.getInstance();
    return !(sp.getBool('onboard_done') ?? false);
  } catch (_) {
    return false;
  }
}
