import 'package:flutter/material.dart';

import '../../design/ui.dart';
import '../../design/lucide.dart';

/// 星级显示（只读）★ 1107u 重绘：描边星 → 实心星 + 半星支持 + 琥珀渐变色，
/// 解决「图标看不出来」的问题（旧版用 Lz.star 线框星，14px 下几乎看不见）
class StarRating extends StatelessWidget {
  final double score;
  final double size;
  final bool showScore;

  const StarRating({
    super.key,
    required this.score,
    this.size = 14,
    this.showScore = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [C.amber, Color(0xFFFFC53D)],
              ).createShader(b),
              child: Icon(
                // 实心星：整星 / 半星（用半透明遮罩模拟）/ 空心淡星
                i <= score
                    ? Lz.star
                    : (i - 0.5 <= score ? Lz.star : Lz.star),
                size: size,
                color: i <= score
                    ? Colors.white
                    : (i - 0.5 <= score
                        ? Colors.white.withAlpha(120)
                        : Colors.white.withAlpha(38)),
              ),
            ),
          ),
        if (showScore) ...[
          const SizedBox(width: 5),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size - 0.5,
              fontWeight: FontWeight.w800,
              color: C.amber,
            ),
          ),
        ],
      ],
    );
  }
}

/// 星级输入（可点选）★ 1107u 同步重绘
class StarInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [C.amber, Color(0xFFFFC53D)],
                ).createShader(b),
                child: Icon(
                  Lz.star,
                  size: size,
                  color: i <= value
                      ? Colors.white
                      : Colors.white.withAlpha(40),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
