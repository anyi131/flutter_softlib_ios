import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// 工具箱公共件（v3.3.4）：图标映射 + 页面骨架 + 卡片/按钮/输入框/胶囊
/// ═══════════════════════════════════════════════════════════════

/// 工具图标映射（后台未填 emoji 时按 kind/route 兜底）
class ToolIcons {
  ToolIcons._();

  static IconData of(String kind, [String route = '']) {
    switch (kind.isNotEmpty ? kind : route) {
      case 'hotsearch':
        return Icons.local_fire_department_rounded;
      case 'news':
        return Icons.newspaper_rounded;
      case 'epic':
        return Icons.videogame_asset_rounded;
      case 'earthquake':
        return Icons.public_rounded;
      case 'poem':
        return Icons.auto_stories_rounded;
      case 'hitokoto':
        return Icons.format_quote_rounded;
      case 'movie':
      case 'moviesearch':
        return Icons.movie_rounded;
      case 'music':
        return Icons.library_music_rounded;
      case 'shortvideo':
      case 'drama':
        return Icons.smart_display_rounded;
      case 'comic':
        return Icons.menu_book_rounded;
      case 'heroes':
      case 'herogallery':
        return Icons.sports_martial_arts_rounded;
      case 'wallpaper':
        return Icons.wallpaper_rounded;
      case 'translate':
        return Icons.translate_rounded;
      case 'exchange':
        return Icons.currency_exchange_rounded;
      case 'ipquery':
        return Icons.location_on_rounded;
      case 'weather':
        return Icons.wb_sunny_rounded;
      case 'qrcode':
        return Icons.qr_code_2_rounded;
      case 'stopwatch':
        return Icons.timer_rounded;
      case 'countdown':
        return Icons.hourglass_bottom_rounded;
      case 'unit':
        return Icons.swap_horiz_rounded;
      case 'bmi':
        return Icons.monitor_weight_rounded;
      case 'loan':
        return Icons.home_work_rounded;
      case 'base64':
        return Icons.code_rounded;
      case 'random':
        return Icons.casino_rounded;
      case 'password':
        return Icons.key_rounded;
      case 'relative':
        return Icons.family_restroom_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  /// 分类图标（按分类中文名映射）
  static IconData cat(String name) {
    switch (name) {
      case '实时热榜':
        return Icons.local_fire_department_rounded;
      case '影视动漫画':
        return Icons.movie_filter_rounded;
      case '实用查询':
        return Icons.travel_explore_rounded;
      case '效率小工具':
        return Icons.build_circle_rounded;
      case '趣味娱乐':
        return Icons.sports_esports_rounded;
      case '资源解析':
        return Icons.inventory_2_rounded;
      case '美图壁纸':
        return Icons.image_rounded;
      case '生活便捷':
        return Icons.work_rounded;
      case '信息资讯':
        return Icons.newspaper_rounded;
      case '图片处理':
        return Icons.auto_fix_high_rounded;
      case '文本工具':
        return Icons.text_fields_rounded;
      case '计算换算':
        return Icons.calculate_rounded;
      case '查询工具':
        return Icons.search_rounded;
      case '系统工具':
        return Icons.settings_suggest_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }
}

/// 二级工具页统一骨架
class ToolScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool scrollable;

  const ToolScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding - 10,
                    6,
                    context.pagePadding - 10,
                    2,
                  ),
                  child: Row(
                    children: [
                      AppPressable(
                        onTap: () => Get.back(),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: context.t1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ty.h2.copyWith(color: context.t1),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ty.tiny.copyWith(color: context.t3),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
                Expanded(
                  child: scrollable
                      ? SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            10,
                            context.pagePadding,
                            30,
                          ),
                          child: child,
                        )
                      : Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            10,
                            context.pagePadding,
                            24,
                          ),
                          child: child,
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

/// 工具页白卡
class ToolCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  /// ★ 1015：长按（图片保存等）
  final VoidCallback? onLongPress;

  const ToolCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(R.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(context.isDark ? 44 : 12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return AppPressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}

/// 工具页主按钮
class ToolButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outline;
  final double height;

  const ToolButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.outline = false,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    return AppPressable(
      onTap: disabled ? null : onPressed,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: outline ? null : Deco.brandGradient,
          borderRadius: BorderRadius.circular(R.full),
          border: outline ? Border.all(color: C.brand.withAlpha(120)) : null,
          boxShadow: outline || disabled
              ? null
              : [
                  BoxShadow(
                    color: C.brand.withAlpha(70),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Opacity(
          opacity: disabled && !loading ? 0.55 : 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 18, color: outline ? C.brand : Colors.white),
              if (loading || icon != null) const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: outline ? C.brand : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 工具页输入框
class ToolField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboard;
  final int lines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const ToolField({
    super.key,
    required this.controller,
    this.hint = '',
    this.label,
    this.icon,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboard,
    this.lines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(R.md),
      borderSide: BorderSide(
        color: context.isDark
            ? Colors.white.withAlpha(20)
            : Colors.black.withAlpha(10),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(fontSize: 14.5, color: context.t1),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          isDense: true,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 19, color: context.t3),
          suffixIcon: suffixIcon == null
              ? null
              : AppPressable(
                  onTap: onSuffixTap,
                  child: Icon(suffixIcon, size: 19, color: context.t3),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          labelStyle: TextStyle(fontSize: 13.5, color: context.t3),
          hintStyle: TextStyle(fontSize: 13, color: context.t3),
          filled: true,
          fillColor: context.isDark ? Colors.white.withAlpha(10) : Colors.white,
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(R.md),
            borderSide: BorderSide(color: C.brand.withAlpha(150), width: 1.3),
          ),
        ),
      ),
    );
  }
}

/// 胶囊选择条
class ToolChips<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T current;
  final ValueChanged<T> onPick;
  final double height;

  const ToolChips({
    super.key,
    required this.items,
    required this.current,
    required this.onPick,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final sel = current == items[i].$1;
          return AppPressable(
            onTap: () => onPick(items[i].$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel ? Deco.brandGradient : null,
                color: sel
                    ? null
                    : (context.isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.white),
                borderRadius: BorderRadius.circular(R.full),
              ),
              child: Text(
                items[i].$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                  color: sel ? Colors.white : context.t2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
