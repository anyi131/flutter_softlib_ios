import 'package:flutter/material.dart';

import 'ui.dart';

/// ★ 171 骨架屏：按内容形状铺灰块 + 微光扫过（替代系统转圈）
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 12,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.isDark ? C.bg3 : C.lbg2;
    final hi = context.isDark ? Colors.white.withAlpha(22) : Colors.white;
    return AnimatedBuilder(
      animation: _c,
      builder: (c, _) {
        final t = _c.value * 2 - 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [base, hi, base],
            ),
          ),
        );
      },
    );
  }
}

/// 帖子列表骨架
class SkeletonPosts extends StatelessWidget {
  const SkeletonPosts({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.isDark ? C.bg2 : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(children: [
                  SkeletonBox(width: 26, height: 26, radius: 13),
                  SizedBox(width: 8),
                  SkeletonBox(width: 90, height: 10),
                ]),
                SizedBox(height: 12),
                SkeletonBox(width: 220, height: 14),
                SizedBox(height: 8),
                SkeletonBox(height: 12),
                SizedBox(height: 6),
                SkeletonBox(width: 160, height: 12),
              ],
            ),
          ),
      ],
    );
  }
}
