import 'package:flutter/material.dart';

/// 为「延伸到 Tab 栏下方」的页面提供正确的底部留白
///
/// 主框架用了 `extendBody: true`（毛玻璃 Tab 需要），所以各 Tab 页
/// 必须自己留出 Tab 高度 + 底部安全区，否则最后一条内容会被 Tab 遮住。
double tabBottomPadding(BuildContext context) {
  final inset = MediaQuery.of(context).padding.bottom;
  // 60 = Tab 内容高度，inset = Home Indicator 安全区
  return 60 + inset;
}
