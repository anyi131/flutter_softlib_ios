import 'dart:ui';
import 'package:flutter/material.dart';
import '../../design/ui.dart';
import 'navigate_logic.dart';

/// ★ 1027 新增第 8 套底栏模板 liquid26 —— iOS 26 液态玻璃
/// 借鉴 whynotmake-it/flutter_liquid_glass 与 sdegenaar/liquid_glass_widgets（MIT）：
/// - BackdropFilter 真实背景折射（模糊+饱和提升）
/// - 选中项弹性胶囊（spring 动画 + 缩放果冻感）
/// - 内外双层高光描边（玻璃厚度感）
/// - 点击涟漪从触点扩散（液滴感）
class Liquid26Bar {
  Liquid26Bar._();

  static Widget build(
    BuildContext context,
    NavigateLogic logic,
    double inset,
  ) {
    final isDark = context.isDark;
    final n = logic.labels.length;
    final bottom = (inset > 0 ? inset : 8) + 10;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, bottom + 0.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          // 真实液态玻璃折射层：模糊 + 饱和（iOS 26 特征）
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.white)
                  .withAlpha(isDark ? 18 : 165),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(38)
                    : Colors.white.withAlpha(210),
                width: 1.2,
              ),
              // 顶部内侧高光：玻璃厚度感
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withAlpha(isDark ? 26 : 130),
                  Colors.white.withAlpha(isDark ? 6 : 30),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 90 : 40),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(
                n,
                (i) => Expanded(
                  child: _Liquid26Item(
                    selected: logic.currentIndex == i,
                    label: logic.labels[i].label,
                    icon: (logic.labels[i].icon as Icon).icon,
                    activeIcon:
                        ((logic.labels[i].selectedIcon ?? logic.labels[i].icon)
                                as Icon)
                            .icon,
                    isDark: isDark,
                    onTap: () => logic.changePage(i),
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

class _Liquid26Item extends StatefulWidget {
  const _Liquid26Item({
    required this.selected,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isDark,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData? icon;
  final IconData? activeIcon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_Liquid26Item> createState() => _Liquid26ItemState();
}

class _Liquid26ItemState extends State<_Liquid26Item>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jc = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  // 果冻弹簧：过冲回弹（jelly 感）
  late final Animation<double> _jelly = CurvedAnimation(
    parent: _jc,
    curve: Curves.elasticOut,
    reverseCurve: Curves.easeOutCubic,
  );
  // 涟漪
  double _rippleT = -1;

  @override
  void didUpdateWidget(covariant _Liquid26Item old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _jc.forward(from: 0);
  }

  @override
  void dispose() {
    _jc.dispose();
    super.dispose();
  }

  void _tapDown(TapDownDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      setState(() {
        _rippleT = (d.localPosition.dy / box.size.height).clamp(0.0, 1.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final fg = sel
        ? C.brand
        : (widget.isDark ? Colors.white70 : Colors.black54);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _tapDown,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _jelly,
        builder: (context, child) {
          final j = _jelly.value;
          // 果冻缩放：横向拉伸→回弹
          final sx = 1.0 + (sel ? 0.16 * (1 - j) * (j > 0.4 ? -0.35 : 1) : 0);
          final sy = 1.0 + (sel ? 0.10 * j * (1 - j) * 2 : 0);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              sel ? sx : 1.0,
              sel ? sy : 1.0,
              1,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 选中胶囊（液态高亮块）
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              C.brand.withAlpha(230),
                              C.brand.withAlpha(160),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: C.brand.withAlpha(120),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                            // 顶部内侧高光
                            BoxShadow(
                              color: Colors.white.withAlpha(90),
                              blurRadius: 4,
                              offset: const Offset(0, -1),
                            ),
                          ]
                        : const [],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sel ? (widget.activeIcon ?? widget.icon) : widget.icon,
                          size: sel ? 24 : 22,
                          color: sel ? Colors.white : fg,
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 240),
                          style: TextStyle(
                            fontSize: sel ? 10.5 : 10,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? Colors.white : fg,
                            height: 1.0,
                          ),
                          child: Text(widget.label, maxLines: 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // 触点涟漪（液滴扩散）
                if (_rippleT >= 0)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 520),
                    onEnd: () => setState(() => _rippleT = -1),
                    builder: (context, t, _) {
                      final box = context.findRenderObject() as RenderBox?;
                      final w = box?.size.width ?? 60;
                      return Positioned(
                        top: _rippleT * 64 - 30,
                        left: w / 2 - 30,
                        child: Opacity(
                          opacity: (1 - t) * 0.35,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withAlpha(200),
                                width: 1.5 * (1 - t),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
