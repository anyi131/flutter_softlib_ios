import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../design/kit.dart';
import '../design/ui.dart';

/// 全屏阻塞等待框
///
/// ★ 1020（用户反馈 #2）：绑定 QQ / QQ 登录这类「有原生 Activity 在前面跑」的
///   流程，之前只弹一个能穿透的 loading，用户可以返回上一页或切到其它 Tab，
///   结果回调打到已经销毁的页面 → 状态错乱、按钮永远转圈（用户说的「未知问题」）。
///
///   这里提供一个「挡住整页、不可返回、不可点击背后内容」的等待层：
///   - barrierDismissible = false（点遮罩不会关）
///   - PopScope 拦返回键（防误触退出流程）
///   - 文案可换，让人知道正在等什么、别乱点
class BlockingDialog {
  BlockingDialog._();

  static bool _open = false;
  static bool get isOpen => _open;

  /// 显示等待层（重复调用会被忽略）
  static void show({String text = '处理中…', String? sub}) {
    if (_open) return;
    _open = true;
    Get.dialog<void>(
      PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: C.bg2.withAlpha(242),
                borderRadius: BorderRadius.circular(R.lg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(102),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(C.brand),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(179),
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(204),
    );
  }

  /// 关闭等待层（未显示时安全忽略）
  static void hide() {
    if (!_open) return;
    _open = false;
    // 用 rootNavigator 关，避免误关掉用户自己打开的其它页面
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) nav.pop();
  }
}
