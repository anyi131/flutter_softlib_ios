import 'dart:ui';

import 'glass_theme.dart';

import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
///  全新设计语言 v2 —— 「沉浸式玻璃拟态」
///
///  设计理念：
///   · 深色为主基调，用渐变光晕营造空间感
///   · 玻璃拟态卡片（半透明 + 模糊 + 细描边），替代纯色卡片堆叠
///   · 大圆角（20-28）、大留白，信息层级靠排版对比而非分割线
///   · 强调色作为「光」使用（渐变、光晕、描边），而非大面积填充
/// ═══════════════════════════════════════════════════════════════

/// ─────────── 配色 ───────────
/// ★ 唯一配色真源（Single Source of Truth）
///   全项目所有色值必须从这里取；其它文件（如 app_theme.dart 的 AppColor）
///   只是本类的转发别名，禁止再定义独立的色值。
class C {
  C._();

  // 品牌色（默认极光蓝紫）★ 与主题、旧 AppColor.primary 对齐
  //
  // ★ 需求（v43 #1）：外观修改要全局生效。
  //   品牌色改为「可变静态量」，由 ThemeController 在切换配色方案时统一改写，
  //   这样全 App 的按钮/渐变/光晕/选中态都会跟着变（无需逐页改代码）。
  static Color brand = const Color(0xFF4B5EF5);
  static Color brandBright = const Color(0xFF6E7DFF);
  static Color brandDeep = const Color(0xFF3A4BD8);

  /// 次要强调色（渐变第二色），同样可被配色方案改写
  static Color accent = const Color(0xFFA78BFA);

  /// 应用一套配色方案（由 ThemeController 调用）
  static void applyPalette({
    required Color b,
    required Color bb,
    required Color bd,
    required Color ac,
  }) {
    brand = b;
    brandBright = bb;
    brandDeep = bd;
    accent = ac;
  }

  /// 品牌渐变（跟随当前配色方案）
  static LinearGradient get brandGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, accent],
  );

  // 强调色
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFFA78BFA);
  static const pink = Color(0xFFF472B6);
  static const amber = Color(0xFFFBBF24);
  static const mint = Color(0xFF34D399);
  static const rose = Color(0xFFFB7185);
  static const accentOrange = Color(0xFFFF6B35);

  // 语义色（成功/警告/危险/会员金）
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const gold = Color(0xFFC9A227);

  // 深色底（三层景深）—— 仅深色模式用
  static const bg0 = Color(0xFF0E1016);
  static const bg1 = Color(0xFF141721);
  static const bg2 = Color(0xFF1A1E29);
  static const bg3 = Color(0xFF232838);

  // 浅色底（默认）
  static const lbg0 = Color(0xFFF6F7FB); // 页面底（浅灰带蓝调）
  static const lbg1 = Color(0xFFFFFFFF); // 卡片
  static const lbg2 = Color(0xFFEFF2F9); // 次级块
  static const lbg3 = Color(0xFFFFFFFF); // 悬浮

  // 文字（深色模式）
  static const t1 = Color(0xFFF6F7FB);
  static const t2 = Color(0xFFA8AEC1);
  static const t3 = Color(0xFF6B7288);

  // 文字（浅色模式，默认）
  static const lt1 = Color(0xFF14161E);
  static const lt2 = Color(0xFF5C6273);
  static const lt3 = Color(0xFF9BA1B0);

  // 玻璃描边
  static const stroke = Color(0xFFFFFFFF);
}

/// ─────────── 圆角 ───────────
class R {
  R._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;
  static const double xxl = 32;
  static const double full = 999;
}

/// ─────────── 间距（统一 4 的倍数，禁止页面内写魔法数字）───────────
class G {
  G._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

/// ─────────── 字号（全站只用这 7 档）───────────
class F {
  F._();
  static const double tiny = 11; // 角标、辅助说明
  static const double small = 12; // 副标题、时间
  static const double body = 13; // 正文
  static const double medium = 14; // 强调正文、按钮
  static const double title = 16; // 卡片标题、分区标题
  static const double big = 20; // 页面标题
  static const double display = 26; // 主视觉标题
}

/// ─────────── 玻璃 / 渐变 装饰 ───────────
class Deco {
  Deco._();

  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  /// 主背景：浅色页面底 + 柔和彩色光晕（浅色为主）
  /// ★ fit: expand 保证无论父级约束如何都铺满，避免转场/首帧露出底色
  /// ★ RepaintBoundary：光晕是静态的，隔离后滚动/动画时不会跟着重绘
  /// 柔光斑（径向渐变的实心圆，无模糊，性能友好）
  static Widget _glowBlob(Color c, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: RadialGradient(colors: [c, c.withAlpha(0)], radius: 0.9),
      shape: BoxShape.circle,
    ),
  );

  static Widget pageBackground(BuildContext context, {Widget? child}) {
    final isDark = dark(context);
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: isDark ? C.bg0 : C.lbg0),
          // 顶部品牌光晕
          Positioned(
            top: -180,
            left: -100,
            right: -100,
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    C.brand.withAlpha(isDark ? 62 : 34),
                    C.brand.withAlpha(0),
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          // 右上青色副光晕
          Positioned(
            top: 180,
            right: -140,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    C.cyan.withAlpha(isDark ? 34 : 20),
                    C.cyan.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          // 左下紫罗兰光晕
          Positioned(
            bottom: 60,
            left: -150,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    C.violet.withAlpha(isDark ? 30 : 18),
                    C.violet.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          // ★ 1020 玻璃模式：再加两处柔光斑
          //   半透明卡片需要「底下有东西可透」才像玻璃；
          //   只有纯色底时玻璃卡片看起来会发灰、显脏。
          //   这里只加极淡的光斑（不模糊、不耗性能），卡片透过去就有层次了。
          if (GlassTheme.enabled) ...[
            Positioned(
              top: 320,
              left: -120,
              child: _glowBlob(C.mint.withAlpha(isDark ? 26 : 16), 300),
            ),
            Positioned(
              bottom: 220,
              right: -130,
              child: _glowBlob(C.brand.withAlpha(isDark ? 30 : 14), 320),
            ),
          ],
          if (child != null) Positioned.fill(child: child),
        ],
      ),
    );
  }

  /// 玻璃卡片
  static Widget glass(
    BuildContext context, {
    required Widget child,
    double radius = R.lg,
    double blur = 18,
    double alpha = 0.06,
    EdgeInsets? padding,
    EdgeInsets? margin,
    VoidCallback? onTap,
    Color? glow,
    Gradient? gradient,
  }) {
    final isDark = dark(context);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? (isDark
                  ? Colors.white.withAlpha((alpha * 255).round())
                  : Colors.white.withAlpha(215))
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark ? C.stroke.withAlpha(20) : Colors.white.withAlpha(230),
          width: 0.9,
        ),
        boxShadow: glow != null
            ? [
                BoxShadow(
                  color: glow.withAlpha(isDark ? 58 : 30),
                  blurRadius: 24,
                  offset: const Offset(0, 9),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF2C3550).withAlpha(isDark ? 0 : 16),
                  blurRadius: 22,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: child,
    );

    // ★ 性能：不再对每张卡片做 BackdropFilter（GPU 最贵的操作之一，
    //   信息流滚动时会让帧率腰斩）。卡片本身已是 84% 不透明的白色，
    //   模糊效果肉眼几乎不可见，改用纯色 + 阴影，视觉几乎一致但帧率大幅提升。
    //   注意：GlassCard 用于固定元素（Tab 栏/顶栏）时仍走真实模糊，见 Deco.blur。
    Widget wrapped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );
    if (margin != null) {
      wrapped = Padding(padding: margin, child: wrapped);
    }
    if (onTap != null) {
      wrapped = GestureDetector(onTap: onTap, child: wrapped);
    }
    return wrapped;
  }

  /// 真实背景模糊（仅用于固定的悬浮元素：底部 Tab 栏、顶部导航栏）
  /// 这些元素数量少且不随滚动重建，代价可接受
  static Widget blur(
    BuildContext context, {
    required Widget child,
    double radius = R.full,
    double sigma = 24,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }

  /// 品牌渐变（跟随配色方案，改为 getter 以支持动态品牌色）
  static LinearGradient get brandGradient => LinearGradient(
    colors: [C.brandBright, C.brand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 极光渐变（多色）
  static LinearGradient aurora({double a = 1}) => LinearGradient(
    colors: [
      C.brand.withAlpha((255 * a).round()),
      C.accent.withAlpha((255 * a).round()),
      C.brandBright.withAlpha((255 * a).round()),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 金色（会员）
  static const goldGradient = LinearGradient(
    colors: [Color(0xFFF7D57A), Color(0xFFC9A227)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 渐变描边容器（1px 光边）
  static Widget gradientBorder({
    required Widget child,
    double radius = R.lg,
    Gradient? gradient,
    double width = 1.2,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient ?? brandGradient,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: C.bg2,
          borderRadius: BorderRadius.circular(radius - width),
        ),
        child: child,
      ),
    );
  }

  /// 光晕圆点（装饰）
  static Widget orb(Color color, double size, {double alpha = 0.35}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withAlpha((255 * alpha).round()), color.withAlpha(0)],
        ),
      ),
    );
  }
}

/// ─────────── 排版 ───────────
class Ty {
  Ty._();
  static const display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    height: 1.15,
    letterSpacing: -1,
  );
  static const h1 = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w900,
    height: 1.2,
    letterSpacing: -0.6,
  );
  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.3,
  );
  static const h3 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );
  static const body = TextStyle(fontSize: 14, height: 1.62);
  static const small = TextStyle(fontSize: 12.5, height: 1.5);
  static const tiny = TextStyle(fontSize: 11, height: 1.4);
}

/// 主题
ThemeData buildNewTheme({required bool dark}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.brand,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: C.brand,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? C.bg0 : C.lbg0,
    canvasColor: dark ? C.bg1 : C.lbg1,
    cardColor: dark ? C.bg2 : Colors.white,
    // ★ 全局页面过渡统一为 iOS 风格（与 GetX 的 cupertino 过渡保持一致）
    //   否则直接调用 Navigator.push 的页面仍是 Android 默认缩放动画，观感割裂
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    dividerColor: dark
        ? Colors.white.withAlpha(16)
        : Colors.black.withAlpha(10),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: dark ? C.t1 : C.lt1,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: dark ? C.t1 : C.lt1,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.brand,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.full),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Colors.white.withAlpha(10) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: BorderSide(
          color: dark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: BorderSide(color: C.brand, width: 1.5),
      ),
      hintStyle: TextStyle(fontSize: 13.5, color: dark ? C.t3 : C.lt3),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.label,
      indicatorColor: C.brand,
      labelColor: C.brand,
      unselectedLabelColor: dark ? C.t2 : C.lt2,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      unselectedLabelStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? C.bg2 : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.xl)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? C.bg1 : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xxl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? C.bg3 : const Color(0xFF22252E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
    ),
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

/// 便捷取色扩展
extension CX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get t1 => isDark ? C.t1 : C.lt1;
  Color get t2 => isDark ? C.t2 : C.lt2;
  Color get t3 => isDark ? C.t3 : C.lt3;
  Color get cardBg => isDark ? C.bg2 : Colors.white;
}
