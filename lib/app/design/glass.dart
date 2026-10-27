import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_theme.dart';

/// 全局液态玻璃弹窗/底部弹层（iOS 26 液态玻璃风格）
///
/// ★ 1027 接入 GlassTheme + GlassPerfGuard 自动降级链路：
/// - GlassPerfGuard 实测连续长帧 → GlassTheme.degrade() 降档 → sigma 变小/关闭
/// - 设备能力探测（低端机）启动时就压低档位
/// 本组件按 GlassTheme.current 档位取效果，无需任何页面改动。

/// 毛玻璃容器（BackdropFilter + 高光描边，卡顿自动降级为实底）
class GlassShell extends StatelessWidget {
  const GlassShell({
    super.key,
    required this.child,
    this.dark = false,
    this.radius = 22,
    this.topHighlight = true,
  });
  final Widget child;
  final bool dark;
  final double radius;
  final bool topHighlight;

  @override
  Widget build(BuildContext context) {
    final d = dark || Theme.of(context).brightness == Brightness.dark;
    final border = d
        ? Colors.white.withAlpha(26)
        : Colors.black.withAlpha(12);
    final hl = d ? Colors.white.withAlpha(38) : Colors.white.withAlpha(150);

    // ★ 档位驱动：enabled 才开真模糊，sigma 跟随档位（高 26 / 中 22 / 低 0）
    final blur = GlassTheme.bigBlur ? GlassTheme.sigma : 0.0;
    final glass = blur > 0;
    final bg = d
        ? (glass ? const Color(0xB3171A24) : const Color(0xFF1A1E29))
        : (glass ? const Color(0xC0FFFFFF) : Colors.white);
    final container = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(d ? 90 : 40),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: topHighlight
          ? Stack(children: [
              Positioned(
                top: 0,
                left: radius * 0.6,
                right: radius * 0.6,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      hl.withAlpha(0),
                      hl,
                      hl.withAlpha(0),
                    ]),
                  ),
                ),
              ),
              child,
            ])
          : child,
    );
    if (!glass) return container;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: container,
      ),
    );
  }
}

/// 液态玻璃 Dialog（替代 showDialog）
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool dark = false,
}) {
  final d = dark || Theme.of(context).brightness == Brightness.dark;
  return showGeneralDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black.withAlpha(d ? 120 : 80),
    pageBuilder: (ctx, _, __) => Center(
      child: GlassShell(dark: d, child: Dialog(child: builder(ctx))),
    ),
  );
}

/// 液态玻璃 BottomSheet（替代 showModalBottomSheet）
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
}) {
  final d = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(d ? 120 : 70),
    builder: (ctx) => GlassShell(
      dark: d,
      radius: 24,
      topHighlight: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 8),
        child: builder(ctx),
      ),
    ),
  );
}
