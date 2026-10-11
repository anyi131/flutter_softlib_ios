import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'navigate_logic.dart';
import 'nav_templates.dart';

/// 主框架 —— 底部导航栏由 ui_config.nav_template 决定（5 套模板，见 nav_templates.dart）
///
///  classic 玻璃岛 / glass 毛玻璃胶囊 / float 分离凸起 / dock 纯图标气泡 / curve 缺口FAB
class NavigatePage extends StatefulWidget {
  const NavigatePage({super.key});

  @override
  State<NavigatePage> createState() => _NavigatePageState();
}

class _NavigatePageState extends State<NavigatePage> {
  final NavigateLogic logic = Get.find<NavigateLogic>();
  DateTime? _lastBack;
  /// v331c 分段挂载：逐页挂载（每 400ms 一页），冻结在挂载第几页一目了然
  int _mountedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mountNext();
    });
  }

  void _mountNext() {
    if (!mounted) return;
    if (_mountedCount == 0) {
      setState(() => _mountedCount = 1); // 先挂首页
      _mountNext();
      return;
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_mountedCount < logic.pages.length) {
        setState(() => _mountedCount++);
        _mountNext();
      }
    });
  }

  Future<bool> _onBack() async {
    if (logic.currentIndex != 0) {
      logic.changePage(0);
      return false;
    }
    final now = DateTime.now();
    if (_lastBack == null ||
        now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      ToastUtil.info('再按一次退出应用');
      return false;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFFFB7185), size: 22),
            SizedBox(width: 9),
            Text(
              '退出应用',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: const Text(
          '确定要退出「安逸软件汇」吗？',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFB7185),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    return go == true;
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onBack()) SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: GetBuilder<NavigateLogic>(
          // v52i #1：Tab 开关后 PageView 必须跟着重建（之前只有底栏重建）
          id: 'navigate',
          builder: (logic) => Stack(
            children: [
              Deco.pageBackground(context),
              // v331c 分段挂载诊断：先显示外壳（证明 Scaffold/底栏正常），
              // 首帧后再挂 PageView——若冻结则锁死在首页构建
              if (_mountedCount >= logic.pages.length)
                PageView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: logic.pageController,
                  children: logic.pages,
                )
              else ...[
                // v331d 真挂载：take(count) 只构建已挂载页，冻在哪个页名一目了然
                PageView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: logic.pageController,
                  children: logic.pages.take(_mountedCount).toList(),
                ),
                Center(
                  child: Text(
                    'next: ${_mountedCount < logic.labels.length ? logic.labels[_mountedCount].label : '?'} ($_mountedCount/${logic.pages.length})',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: GetBuilder<NavigateLogic>(
          // v331c：去掉 init: NavigateLogic()（build 中构造控制器是反模式）
          id: 'navigate',
          // v54：底部导航模板（classic/glass/float/dock/curve/liquid）
          builder: (logic) => NavTemplates.bar(context, logic, inset),
        ),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<NavigateLogic>();
    super.dispose();
  }
}
