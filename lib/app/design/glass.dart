import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_theme.dart';

/// 全局液态玻璃弹窗/底部弹层（iOS 26 液态玻璃风格）
///
/// ★ 1027 接入 GlassTheme + GlassPerfGuard 自动降级链路：
/// - GlassPerfGuard 实测连续长帧 → GlassTheme.degrade() 降档 → sigma 变小/关闭
/// - 设备能力探测（低端机）启动时就压低档位
/// 本组件按 GlassTheme.current 档位取效果，无需任何页面改动。

/// 弹窗/弹层外观策略 —— 1028 定型（浅色实底 / 深色轻玻璃）
///
/// 浅色：不做磨砂。浅色页面本来就亮，再叠磨砂只会糊成一片灰，
///       用户实测「周围一片灰、卡片像贴在灰纸上」。改成实底白卡 + 柔影。
/// 深色：保留轻磨砂（sigma 12，比重 26 减半）+ 深底卡 + 柔影，留住透光层次。
class PanelLook {
  const PanelLook({
    required this.blur,
    required this.fill,
    required this.border,
    required this.shadow,
    required this.highlight,
  });

  final bool blur;
  final Color fill;
  final Color border;
  final List<BoxShadow> shadow;
  final Color highlight;

  /// 深色磨砂强度（原档位 26 的一半，实测这个值还能看出底层形状）
  static const double darkSigma = 12;

  static PanelLook of(bool dark) => dark
      ? const PanelLook(
          blur: true,
          fill: Color(0xE0161A24),
          border: Color(0x3DFFFFFF),
          highlight: Color(0x33FFFFFF),
          shadow: [
            BoxShadow(
              color: Color(0x7A000000),
              blurRadius: 34,
              offset: Offset(0, 16),
              spreadRadius: -4,
            ),
          ],
        )
      : const PanelLook(
          blur: false,
          fill: Color(0xFFFFFFFF),
          border: Color(0x14000000),
          highlight: Color(0x00FFFFFF),
          shadow: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 30,
              offset: Offset(0, 14),
              spreadRadius: -4,
            ),
          ],
        );
}

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
    final look = PanelLook.of(d);

    // 只有「深色 + 玻璃开 + 档位允许」才真模糊；浅色一律实底
    final sigma = (GlassTheme.enabled && GlassTheme.bigBlur && look.blur)
        ? PanelLook.darkSigma
        : 0.0;

    Widget card = Container(
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: look.border, width: 0.8),
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
                      look.highlight.withAlpha(0),
                      look.highlight,
                      look.highlight.withAlpha(0),
                    ]),
                  ),
                ),
              ),
              child,
            ])
          : child,
    );

    if (sigma > 0) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: card,
        ),
      );
    }

    // ★ 投影必须画在 ClipRRect 外面：放在被裁剪的 Container 上会被裁掉，
    //   弹窗看起来就是「贴在纸上的一张纸」（1028 用户截图里的硬边就是这个原因）。
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: look.shadow,
      ),
      child: card,
    );
  }
}

/// 自绘弹窗底板（写评论 / 分享海报等自定义排版用）
///
/// 统一走 PanelLook：浅色实底白卡 + 柔影，深色轻磨砂 + 柔影。
/// 调用方用透明 Dialog 承载它，保证任何模式下都只有一层背景。
class PanelSurface extends StatelessWidget {
  const PanelSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.clip = true,
  });

  final Widget child;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final look = PanelLook.of(d);

    if (GlassTheme.enabled && look.blur) {
      return GlassShell(
        radius: radius,
        dark: d,
        topHighlight: false,
        child: clip
            ? ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: child,
              )
            : child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: look.border, width: 0.8),
        boxShadow: look.shadow,
      ),
      child: clip
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            )
          : child,
    );
  }
}

/// 底部弹层底板（showModalBottomSheet / Get.bottomSheet 用）
///
/// 与弹窗同一套策略：浅色实底 + 柔影，深色轻磨砂 + 柔影。
/// 不改调用方的内边距/圆角/配色，只替换「白卡还是磨砂」这一层。
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.child,
    required this.color,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.radius = 22,
    this.onlyTop = true,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double radius;
  final bool onlyTop;

  @override
  Widget build(BuildContext context) {
    final br = onlyTop
        ? BorderRadius.vertical(top: Radius.circular(radius))
        : BorderRadius.circular(radius);
    final d = Theme.of(context).brightness == Brightness.dark;
    final look = PanelLook.of(d);

    if (GlassTheme.enabled && look.blur) {
      return Container(
        margin: margin,
        child: GlassShell(
          radius: radius,
          dark: d,
          child: ClipRRect(
            borderRadius: br,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }

    // 浅色（或玻璃关）：实底 + 顶部柔影，弹层边缘不再「一刀切」
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: br),
        child: child,
      ),
    );
  }
}


/// ★ 1027 玻璃组件总开关：glass_mode=off 时弹窗/弹层回退原生样式。
/// glass_mode 只控制页面毛玻璃档位，不经过这里——必须独立判断，
/// 否则服务器关闭玻璃后弹窗仍是玻璃渲染（1027 真机翻车根因）。
bool get _glassUiEnabled => GlassTheme.enabled;

/// 自带底板的弹窗内容（AppDialog 等）。
///
/// ★ 1028 双层弹窗修复：
/// showGlassDialog 原来只用 `child is Dialog` 判断，而
///   · AppDialog 是 StatelessWidget（内部才返回 Dialog）
///   · splash / 更新弹窗是 PopScope(Dialog(...))
/// 两者都判不出来 → 外层又套一个 GlassShell 白卡，
/// 于是「玻璃壳白卡 + 弹窗白卡」叠在一起，真机就是「套了两个弹窗」。
/// 自己带底板的内容打上这个标记（或解包后仍是 Dialog），外层不再加壳。
mixin GlassOwnSurface {}

/// 剥掉只做拦截的透明包装（PopScope / 旧 WillPopScope），取出真正的内容
Widget _peelSurface(Widget w) {
  var cur = w;
  // 包装层可能嵌套多层
  for (var i = 0; i < 4; i++) {
    if (cur is PopScope) {
      cur = cur.child;
      continue;
    }
    // ignore: deprecated_member_use
    if (cur is WillPopScope) {
      // ignore: deprecated_member_use
      cur = cur.child;
      continue;
    }
    break;
  }
  return cur;
}

/// 内容是否自带底板（自带的话外层绝不能再加玻璃壳）
bool _ownsSurface(Widget w) {
  final c = _peelSurface(w);
  return c is Dialog || c is AlertDialog || c is GlassOwnSurface;
}

/// 液态玻璃 Dialog（替代 showDialog）
/// ★ glass_mode=off 时完全回退原生 showDialog（1027 真机翻车修复）
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool dark = false,
}) {
  if (!_glassUiEnabled) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: builder,
    );
  }
  final d = dark || Theme.of(context).brightness == Brightness.dark;
  return showGeneralDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black.withAlpha(d ? 31 : 51),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final child = builder(ctx);
      // ★ 1027 根治：内容自己就是 Dialog/AlertDialog（自己管尺寸、padding、背景），
      // 再套一层 Dialog + GlassShell 会变成「Dialog 套 Dialog 套白卡」——
      // 白底叠白底、文字飘在整屏中间（权限弹窗/公告弹窗真机翻车根因）。直接透传。
      // ★ 1028 补：PopScope(Dialog) 与 AppDialog 同样自带底板，也要透传，
      // 否则外层玻璃壳 + 内层卡片 = 「套了两个弹窗」（比上面的情况更隐蔽）。
      if (_ownsSurface(child)) return child;
      // 普通内容：玻璃壳承载，但限制最大尺寸，避免被撑满全屏
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(ctx).size.width * 0.92,
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          child: GlassShell(dark: d, child: child),
        ),
      );
    },
  );
}

/// 液态玻璃 BottomSheet（替代 showModalBottomSheet）
/// ★ glass_mode=off 时完全回退原生 showModalBottomSheet
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
}) {
  // ★ 1028「两个横杠」根因：主题里 bottomSheetTheme.showDragHandle = true，
  // M3 会在弹层顶部画一条 32×4 的把手。showGlassSheet 的 bottom sheet 背景是
  // 透明的（由 GlassShell 自己画卡），这条把手于是悬在半空、压在遮罩上，
  // 而公告 sheet 模板的内容里又手画了一条 44×5 的把手 → 用户看到两条横杠。
  // 这里统一关掉 M3 的，把手由内容自己决定画不画。
  if (!_glassUiEnabled) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      showDragHandle: false,
      builder: builder,
    );
  }
  final d = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(d ? 31 : 51),
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
