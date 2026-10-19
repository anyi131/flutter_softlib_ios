import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../design/ui.dart';

/// 统一轻提示（替代原生 Toast）
///
/// ★ 1020 重做：
///   原来的 fluttertoast 是**系统原生 Toast**：红绿纯色、字号固定、
///   错误提示还从屏幕顶部弹 —— 与 App 的玻璃风格完全不搭。
///
///   现在：底部滑入的圆角卡片，带语义图标，自动消失。
///   特点：
///     · 不用第三方 Toast 库（少一个依赖）
///     · 跟随深浅色主题
///     · 同屏只显示一条（新的替换旧的，不叠成一片）
///     · 有图标区分语义：✓成功 ✕错误 !提示
class ToastUtil {
  ToastUtil._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void success(String message) => _show(message, _Tone.success);

  static void error(String message) => _show(message, _Tone.error);

  static void info(String message) => _show(message, _Tone.info);

  static void _show(String message, _Tone tone) {
    if (message.trim().isEmpty) return;
    final ctx = Get.context;
    final overlay = ctx?.overlay;
    if (overlay == null) return;

    _dismiss();

    _entry = OverlayEntry(
      builder: (c) => _ToastWidget(message: message, tone: tone),
    );
    overlay.insert(_entry!);

    _timer = Timer(
      Duration(milliseconds: tone == _Tone.error ? 2600 : 1800),
      _dismiss,
    );
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    try {
      _entry?.remove();
    } catch (_) {}
    _entry = null;
  }

  /// 手动关闭（页面销毁时调用，避免 Overlay 残留）
  static void hide() => _dismiss();
}

enum _Tone { success, error, info }

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.tone});

  final String message;
  final _Tone tone;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (widget.tone) {
      _Tone.success => (C.mint, Icons.check_circle_rounded),
      _Tone.error => (C.danger, Icons.error_rounded),
      _Tone.info => (C.brand, Icons.info_rounded),
    };

    return Positioned(
      left: 20,
      right: 20,
      bottom: MediaQuery.of(context).padding.bottom + 90,
      child: IgnorePointer(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: _c,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? const Color(0xF21A1D26)
                        : const Color(0xF2FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color.withAlpha(context.isDark ? 90 : 70),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(
                          context.isDark ? 120 : 34,
                        ),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: context.t1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
