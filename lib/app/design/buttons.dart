import 'package:flutter/material.dart';

import 'lucide.dart';
import 'ui.dart';
import 'adaptive.dart';

/// 1109：全局按钮体系 —— 统一替代散落各处的「裸 Container + Text」小按钮
///   · AppChip  小操作（编辑/置顶/删除…）：带图标、带描边、按压回弹
///   · AppBtn   主操作（发布/保存/确认）：渐变填充 + 投影
class AppChip extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;

  /// 危险操作（删除）
  final bool danger;

  /// 主操作（查看）
  final bool primary;

  /// 更紧凑（列表内）
  final bool dense;

  const AppChip(
    this.text, {
    super.key,
    this.onTap,
    this.icon,
    this.danger = false,
    this.primary = false,
    this.dense = false,
  });

  /// 按文案自动配图标（中文关键字）
  static IconData iconOf(String s) {
    if (s.contains('删除')) return Lz.trash2;
    if (s.contains('编辑')) return Lz.pencil;
    if (s.contains('查看')) return Lz.eye;
    if (s.contains('置顶')) return Lz.pin;
    if (s.contains('隐藏')) return Lz.eyeOff;
    if (s.contains('恢复')) return Lz.eye;
    if (s.contains('保存')) return Lz.check;
    if (s.contains('新增') || s.contains('添加')) return Lz.plus;
    return Lz.chevronRight;
  }

  @override
  State<AppChip> createState() => _AppChipState();
}

class _AppChipState extends State<AppChip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final danger = widget.danger;
    final primary = widget.primary;
    final hue = danger
        ? C.danger
        : (primary ? C.brand : (context.isDark ? Colors.white : C.lt1));

    final bg = primary
        ? C.brand
        : hue.withAlpha(danger ? 22 : (context.isDark ? 16 : 10));
    final fg = primary ? Colors.white : hue;
    final border = primary
        ? Colors.transparent
        : hue.withAlpha(danger ? 70 : (context.isDark ? 44 : 34));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: widget.onTap == null ? 0.45 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: widget.dense ? 26 : 30,
            padding: EdgeInsets.symmetric(
                horizontal: widget.dense ? 8 : 10, vertical: 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.dense ? 8 : 9),
              border: Border.all(color: border, width: 1),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: C.brand.withAlpha(70),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon ?? AppChip.iconOf(widget.text),
                    size: widget.dense ? 12 : 13, color: fg),
                SizedBox(width: widget.dense ? 4 : 5),
                Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: widget.dense ? 11 : 12,
                    height: 1.1,
                    color: fg,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 主按钮：渐变填充 + 按压缩放
class AppBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool danger;
  final bool ghost;
  final bool wide;

  const AppBtn(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.danger = false,
    this.ghost = false,
    this.wide = false,
  });

  @override
  State<AppBtn> createState() => _AppBtnState();
}

class _AppBtnState extends State<AppBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.danger
        ? const [Color(0xFFFF7A8A), Color(0xFFE11D48)]
        : [C.brand, C.violet];

    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: widget.wide ? double.infinity : null,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: widget.ghost ? null : LinearGradient(colors: g),
            color: widget.ghost
                ? (context.isDark ? Colors.white.withAlpha(14) : const Color(0xFFF1F4F9))
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.ghost
                ? null
                : [
                    BoxShadow(
                      color: g.last.withAlpha(90),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: widget.wide ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 16,
                    color: widget.ghost ? context.t1 : Colors.white),
                const SizedBox(width: 7),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: widget.ghost ? context.t1 : Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1109：图片右上角的「移除」角标 —— 替代原来 12px 黑圆点 + 细叉
class AppRemoveBadge extends StatefulWidget {
  final VoidCallback? onTap;
  final double size;

  const AppRemoveBadge({super.key, this.onTap, this.size = 22});

  @override
  State<AppRemoveBadge> createState() => _AppRemoveBadgeState();
}

class _AppRemoveBadgeState extends State<AppRemoveBadge> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? const Color(0xFF2A2F3A) : Colors.white,
            border: Border.all(
              color: dark ? Colors.white.withAlpha(30) : const Color(0xFF0F172A).withAlpha(16),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(dark ? 120 : 40),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.close_rounded,
            size: widget.size * 0.58,
            color: C.danger,
          ),
        ),
      ),
    );
  }
}
