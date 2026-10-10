import 'dart:ui';

import 'package:flutter/material.dart';

import '../../api/soft_service.dart';
import '../../design/ui.dart';
import 'navigate_logic.dart';

/// ═══════════════════════════════════════════════════════════════
/// 底部导航栏模板（v55）：classic / glass / float / dock / curve / liquid
///
/// 由 ui_config.nav_template 下发，App 启动 / 后台保存后热切换。
/// 各模板为骨架级差异：
///   classic —— 现有 iOS 玻璃岛（选中渐变胶囊浮岛）
///   glass   —— 毛玻璃悬浮胶囊（全宽模糊浮条，每项图标+文字常显）
///   float   —— 分离凸起（选中项大图标上浮出栏外 + 栏内标签）
///   dock    —— 纯图标行无文字，选中上方浮小标签气泡
///   curve   —— 底部凹陷缺口（Notch 居中托住选中 FAB 风格）
///   liquid  —— 液态玻璃（iOS 26 Liquid Glass 风：重模糊+白高光+斜向反光）
/// ═══════════════════════════════════════════════════════════════
class NavTemplates {
  NavTemplates._();

  static String _tpl = 'classic';

  /// 从缓存的 ui_config 读取模板（后台保存后 fetchConfig 会刷新缓存）
  static String get current =>
      SoftService.instance.cachedConfig?.uiConfig.navTemplate ?? 'classic';

  static Widget bar(BuildContext context, NavigateLogic logic, double inset) {
    _tpl = current;
    switch (_tpl) {
      case 'glass':
        return _glassCapsule(context, logic, inset);
      case 'float':
        return _floatBar(context, logic, inset);
      case 'dock':
        return _dockBar(context, logic, inset);
      case 'curve':
        return _curveBar(context, logic, inset);
      case 'liquid':
        return _liquidBar(context, logic, inset);
      default:
        return _classicBar(context, logic, inset);
    }
  }

  // ─────────── classic：现有 iOS 玻璃岛 ───────────
  static Widget _classicBar(
    BuildContext context,
    NavigateLogic logic,
    double inset,
  ) {
    final isDark = context.isDark;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, (inset > 0 ? inset : 8) + 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
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
                (i) => Expanded(child: _classicItem(context, logic, i)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _classicItem(BuildContext context, NavigateLogic logic, int i) {
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

  // ─────────── glass：毛玻璃悬浮胶囊（全宽，图标+文字常显） ───────────
  static Widget _glassCapsule(
    BuildContext context,
    NavigateLogic logic,
    double inset,
  ) {
    final isDark = context.isDark;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, (inset > 0 ? inset : 8) + 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.xxl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(16)
                  : Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(R.xxl),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(30)
                    : Colors.white.withAlpha(235),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: List.generate(logic.labels.length, (i) {
                final sel = logic.currentIndex == i;
                final dest = logic.labels[i];
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => logic.changePage(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconTheme(
                          data: IconThemeData(
                            size: 21,
                            color: sel ? C.brand : context.t3,
                          ),
                          child:
                              (sel ? dest.selectedIcon : dest.icon) ??
                              const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                            color: sel ? C.brand : context.t3,
                          ),
                          child: Text(dest.label, maxLines: 1),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────── float：分离凸起（选中大图标上浮 + 栏内标签） ───────────
  static Widget _floatBar(
    BuildContext context,
    NavigateLogic logic,
    double inset,
  ) {
    final isDark = context.isDark;
    // v55 修复：上浮裁切——顶部留足空间（26px），凸出图标位移收窄到 -12，
    // 整个凸起都落在 bottomNavigationBar 自身布局范围内，不再被裁掉
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 26, 18, (inset > 0 ? inset : 8) + 8),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(R.xxl),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(18)
                : Colors.black.withAlpha(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 110 : 34),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: List.generate(logic.labels.length, (i) {
            final sel = logic.currentIndex == i;
            final dest = logic.labels[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => logic.changePage(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 选中项大图标凸出栏外（Stack 不裁剪，安全上浮）
                    Transform.translate(
                      offset: Offset(0, sel ? -12 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        width: sel ? 44 : 40,
                        height: sel ? 44 : 40,
                        decoration: BoxDecoration(
                          gradient: sel ? Deco.brandGradient : null,
                          color: sel
                              ? null
                              : (isDark
                                    ? Colors.white.withAlpha(10)
                                    : Colors.black.withAlpha(6)),
                          shape: BoxShape.circle,
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: C.brand.withAlpha(110),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        child: IconTheme(
                          data: IconThemeData(
                            size: sel ? 23 : 19,
                            color: sel ? Colors.white : context.t3,
                          ),
                          child:
                              (sel ? dest.selectedIcon : dest.icon) ??
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    Text(
                      dest.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                        color: sel ? C.brand : context.t3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────── dock：纯图标行，选中上方浮小标签气泡 ───────────
  static Widget _dockBar(
    BuildContext context,
    NavigateLogic logic,
    double inset,
  ) {
    final isDark = context.isDark;
    // v55 修复：气泡裁剪——顶部预留 34px，选中上浮气泡（top:-30）完整落在
    // bottomNavigationBar 布局范围内，不再被 Scaffold 裁掉
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 34, 24, (inset > 0 ? inset : 8) + 8),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(18)
                : Colors.black.withAlpha(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 100 : 28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(logic.labels.length, (i) {
            final sel = logic.currentIndex == i;
            final dest = logic.labels[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => logic.changePage(i),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // 图标
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: sel
                            ? C.brand.withAlpha(isDark ? 42 : 24)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: IconTheme(
                        data: IconThemeData(
                          size: 21,
                          color: sel ? C.brand : context.t3,
                        ),
                        child:
                            (sel ? dest.selectedIcon : dest.icon) ??
                            const SizedBox.shrink(),
                      ),
                    ),
                    // 选中上方浮出的小标签气泡
                    if (sel)
                      Positioned(
                        top: -30,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          constraints: const BoxConstraints(maxWidth: 120),
                          decoration: BoxDecoration(
                            color: isDark ? C.t1 : const Color(0xFF20242E),
                            borderRadius: BorderRadius.circular(R.sm),
                          ),
                          child: Text(
                            dest.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────── curve：底部凹陷缺口 + 居中 FAB（Notch 风格） ───────────
  static Widget _curveBar(
    BuildContext context,
    NavigateLogic logic,
    double inset,
  ) {
    final isDark = context.isDark;
    final n = logic.labels.length;
    final mid = n ~/ 2; // 中缝位置：该槽位由 FAB 托住，隐藏原项
    final fabDest = logic.labels[mid];
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 26, 0, (inset > 0 ? inset : 8) + 6),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 带缺口凹槽的底栏
          PhysicalShape(
            color: isDark ? C.bg2 : Colors.white,
            elevation: 12,
            shadowColor: Colors.black.withAlpha(70),
            clipper: _NotchClipper(),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: List.generate(n, (i) {
                  if (i == mid) {
                    // v55 修复：中缝槽位不再空置——整块作为 FAB 的热区，
                    // 点击即切到该 Tab（之前只有 52px 的圆钮可点，热区过小）
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => logic.changePage(mid),
                        child: const SizedBox.expand(),
                      ),
                    );
                  }
                  final sel = logic.currentIndex == i;
                  final dest = logic.labels[i];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => logic.changePage(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconTheme(
                            data: IconThemeData(
                              size: 21,
                              color: sel ? C.brand : context.t3,
                            ),
                            child:
                                (sel ? dest.selectedIcon : dest.icon) ??
                                const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dest.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: sel
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: sel ? C.brand : context.t3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // 居中 FAB（托在缺口上）
          // v55：外扩 8px 透明热区，边缘点击也可靠触发
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => logic.changePage(mid),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: Deco.brandGradient,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? C.bg2 : Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: C.brand.withAlpha(120),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: IconTheme(
                  data: const IconThemeData(size: 23, color: Colors.white),
                  child: fabDest.selectedIcon ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── liquid：液态玻璃（iOS 26 Liquid Glass 风） ───────────
  static Widget _liquidBar(
    BuildContext context,
    NavigateLogic logic,
    double inset,
  ) {
    final isDark = context.isDark;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, (inset > 0 ? inset : 8) + 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.full),
        child: BackdropFilter(
          // 重模糊：Liquid Glass 的「折射」底
          filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              // 暗色：深色半透明玻璃体；浅色：白色高透玻璃体
              color: isDark
                  ? const Color(0xD90E1119)
                  : Colors.white.withAlpha(196),
              borderRadius: BorderRadius.circular(R.full),
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withAlpha(30),
                        Colors.white.withAlpha(6),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withAlpha(230),
                        Colors.white.withAlpha(120),
                      ],
                    ),
              // 白高光描边
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(52)
                    : Colors.white.withAlpha(245),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 110 : 34),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withAlpha(isDark ? 14 : 160),
                  blurRadius: 1,
                  offset: const Offset(0, -0.6),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.full),
                // 内侧斜向反光渐变：左上→中下扫过一道白色高光
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: const Alignment(0.4, 1.1),
                  colors: [
                    Colors.white.withAlpha(isDark ? 42 : 150),
                    Colors.white.withAlpha(isDark ? 8 : 40),
                    Colors.white.withAlpha(0),
                  ],
                  stops: const [0.0, 0.42, 0.75],
                ),
              ),
              child: Row(
                children: List.generate(logic.labels.length, (i) {
                  final sel = logic.currentIndex == i;
                  final dest = logic.labels[i];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => logic.changePage(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 选中项放大 1.15
                          AnimatedScale(
                            scale: sel ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 40,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sel
                                    ? C.brand.withAlpha(isDark ? 56 : 30)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(R.lg),
                              ),
                              child: IconTheme(
                                data: IconThemeData(
                                  size: 21,
                                  color: sel
                                      ? (isDark ? Colors.white : C.brand)
                                      : context.t3,
                                ),
                                child:
                                    (sel ? dest.selectedIcon : dest.icon) ??
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          Text(
                            dest.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: sel
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: sel
                                  ? (isDark ? Colors.white : C.brand)
                                  : context.t3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          // 选中项底部小圆点
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            width: sel ? 4 : 0,
                            height: 4,
                            decoration: BoxDecoration(
                              color: sel
                                  ? (isDark ? Colors.white : C.brand)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部栏凹陷缺口裁剪（中顶部半圆凹槽）
class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 24)
      ..quadraticBezierTo(0, 0, 24, 0)
      ..lineTo(size.width / 2 - 34, 0)
      ..quadraticBezierTo(size.width / 2, 0, size.width / 2, 26)
      ..quadraticBezierTo(size.width / 2, 0, size.width / 2 + 34, 0)
      ..lineTo(size.width - 24, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 24)
      ..lineTo(size.width, size.height - 24)
      ..quadraticBezierTo(size.width, size.height, size.width - 24, size.height)
      ..lineTo(24, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 24)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
