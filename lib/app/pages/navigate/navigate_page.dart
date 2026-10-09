import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'navigate_logic.dart';

/// 主框架 —— iOS 26/27 风格玻璃底部 Tab
///
/// 特征：
///  · 完全通透的玻璃胶囊（无实色底，强模糊 + 高光描边）
///  · 选中项为独立的渐变浮岛（带光晕），未选中仅图标
///  · 沉浸式延伸（内容穿过 Tab 显示）
class NavigatePage extends StatefulWidget {
  const NavigatePage({super.key});

  @override
  State<NavigatePage> createState() => _NavigatePageState();
}

class _NavigatePageState extends State<NavigatePage> {
  final NavigateLogic logic = Get.find<NavigateLogic>();
  DateTime? _lastBack;

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
          init: NavigateLogic(),
          builder: (logic) => Stack(
            children: [
              Deco.pageBackground(context),
              PageView(
                physics: const NeverScrollableScrollPhysics(),
                controller: logic.pageController,
                children: logic.pages,
              ),
            ],
          ),
        ),
        bottomNavigationBar: GetBuilder<NavigateLogic>(
          id: 'navigate',
          builder: (logic) => _glassBar(context, logic, inset),
        ),
      ),
    );
  }

  /// iOS 26/27 玻璃 Tab
  Widget _glassBar(BuildContext context, NavigateLogic logic, double inset) {
    final isDark = context.isDark;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, (inset > 0 ? inset : 8) + 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.full),
        child: BackdropFilter(
          // 强模糊 + 极低不透明度 = iOS 26 的"液态玻璃"
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              // 几乎完全透明，只保留一点点底色让图标可辨识
              color: isDark
                  ? Colors.white.withAlpha(20)
                  : Colors.white.withAlpha(120),
              borderRadius: BorderRadius.circular(R.full),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(38)
                    : Colors.white.withAlpha(220),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 90 : 26),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: List.generate(
                logic.labels.length,
                (i) => Expanded(child: _item(context, logic, i)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 单个 Tab 项
  Widget _item(BuildContext context, NavigateLogic logic, int i) {
    final sel = logic.currentIndex == i;
    final dest = logic.labels[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => logic.changePage(i),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: sel ? 15 : 11, vertical: 8),
          decoration: BoxDecoration(
            gradient: sel ? Deco.brandGradient : null,
            borderRadius: BorderRadius.circular(R.full),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: C.brand.withAlpha(110),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(
                  size: 21,
                  color: sel ? Colors.white : context.t2,
                ),
                child:
                    (sel ? dest.selectedIcon : dest.icon) ??
                    const SizedBox.shrink(),
              ),
              if (sel) ...[
                const SizedBox(width: 6),
                Text(
                  dest.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
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
